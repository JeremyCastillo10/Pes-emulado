class_name Team
extends Node
## Un equipo en el partido: alineación, formación dinámica (bloque que se mueve con el
## balón), asistencia de pase e IA por roles (portero, defensas, medios, delanteros).
## La IA solo mueve a los jugadores que no controla un humano.

const PlayerScene := preload("res://scenes/match/player.tscn")

## Dificultades: tiempo de reacción, multiplicador de valoraciones, error de golpeo, presión
const DIFFICULTY := [
	{"name": "diff_beginner", "react": 0.6, "stat": 0.84, "err": 1.7, "press": 0.35, "gk": 0.8},
	{"name": "diff_amateur", "react": 0.45, "stat": 0.91, "err": 1.35, "press": 0.55, "gk": 0.9},
	{"name": "diff_pro", "react": 0.32, "stat": 1.0, "err": 1.0, "press": 0.75, "gk": 1.0},
	{"name": "diff_superstar", "react": 0.22, "stat": 1.05, "err": 0.85, "press": 0.9, "gk": 1.06},
	{"name": "diff_legend", "react": 0.15, "stat": 1.1, "err": 0.7, "press": 1.0, "gk": 1.12},
]

var info: Dictionary = {}
var side := 1                  # +1 ataca hacia +X
var players: Array[FootballPlayer] = []
var opponent: Team
var ball: Ball
var human := false
var controlled: FootballPlayer = null
var formation := "4-3-3"
var diff: Dictionary = DIFFICULTY[2]
var kit: Dictionary = {}
var match_node: Node = null
var ai_active := true          # se desactiva durante saques/celebraciones
var last_possession := false   # tuvo la posesión por última vez (balón suelto)
var double_press := false      # el humano pide doble presión
var keeper_rush := false       # el humano pide la salida del portero

var _next_decision := {}       # jugador -> tiempo
var _dribble_dir := {}         # jugador -> dirección de conducción decidida
var _rng := RandomNumberGenerator.new()
var _time := 0.0


func setup(p_info: Dictionary, p_side: int, p_human: bool, p_ball: Ball, kit_key: String, difficulty: int, parent: Node) -> void:
	_rng.randomize()
	info = p_info
	side = p_side
	human = p_human
	ball = p_ball
	match_node = parent
	formation = str(info.get("formation", "4-3-3"))
	diff = DIFFICULTY[clampi(difficulty, 0, 4)]
	var kits: Dictionary = info.get("kits", {})
	kit = kits.get(kit_key, kits.get("home", {}))
	var gk_kit: Dictionary = kits.get("gk", kit)
	var all: Array = info.get("players", [])
	var by_id := {}
	for p in all:
		by_id[p["id"]] = p
	var lineup: Array = []
	for id in info.get("lineup", []):
		if by_id.has(id):
			lineup.append(by_id[id])
	for p in all:
		if lineup.size() >= 11:
			break
		if not lineup.has(p):
			lineup.append(p)
	var slots := Formations.slots(formation)
	var assigned := _assign_slots(lineup, slots)
	for i in slots.size():
		var pdata: Dictionary = assigned[i]
		var fp: FootballPlayer = PlayerScene.instantiate()
		var is_gk_slot: bool = slots[i][0] == "GK"
		fp.setup(pdata, gk_kit if is_gk_slot else kit, ball)
		fp.is_gk = is_gk_slot
		fp.team = self
		fp.slot_index = i
		fp.role = slots[i][0]
		fp.name = "%s_%d" % [str(info.get("short", "T")), int(pdata.get("number", i))]
		if not human:
			fp.stat_mult = diff["stat"]
			fp.error_mult = diff["err"]
		parent.add_child(fp)
		players.append(fp)


## Asigna a cada casilla de la formación el jugador más adecuado por posición.
func _assign_slots(lineup: Array, slots: Array) -> Array:
	var result := []
	result.resize(slots.size())
	var free := lineup.duplicate()
	for pass_i in 3:
		for i in slots.size():
			if result[i] != null:
				continue
			var role: String = slots[i][0]
			var wanted: Array = Formations.SIMILAR.get(role, [role])
			for p in free:
				var pos := str(p.get("position", ""))
				if (pass_i == 0 and pos == role) or (pass_i == 1 and wanted.has(pos)) or (pass_i == 2 and (pos != "GK" or role == "GK")):
					result[i] = p
					free.erase(p)
					break
	for i in slots.size():
		if result[i] == null and not free.is_empty():
			result[i] = free.pop_front()
	return result


func goalkeeper() -> FootballPlayer:
	for p in players:
		if p.is_gk:
			return p
	return null


func own_goal() -> Vector3:
	return Vector3(-PitchDims.HALF_LENGTH * side, 0, 0)


func target_goal() -> Vector3:
	return Vector3(PitchDims.HALF_LENGTH * side, 0, 0)


func has_ball() -> bool:
	var o := ball.owner_player
	if o == null:
		o = ball.held_by
	return o != null and players.has(o)


func in_possession() -> bool:
	if has_ball():
		return true
	if opponent.has_ball():
		return false
	return last_possession


func carrier() -> FootballPlayer:
	for p in players:
		if p.has_ball or ball.held_by == p:
			return p
	return null


func nearest_to(point: Vector3, include_gk := false, exclude: FootballPlayer = null) -> FootballPlayer:
	var best: FootballPlayer = null
	var bd := INF
	for p in players:
		if (p.is_gk and not include_gk) or p == exclude:
			continue
		var d := p.global_position.distance_squared_to(point)
		if d < bd:
			bd = d
			best = p
	return best


## Rival más adelantado hacia nuestra portería (línea defensiva rival, en coordenada de ataque).
func opponent_last_line() -> float:
	var xs: Array = []
	for o in opponent.players:
		xs.append(o.global_position.x * side)
	xs.sort()
	return xs[xs.size() - 2] if xs.size() > 1 else 50.0


# ------------------------------------------------------------ Formación

func slot_target(p: FootballPlayer) -> Vector3:
	var slots := Formations.slots(formation)
	var s: Array = slots[p.slot_index]
	var depth: float = s[1]
	var width: float = s[2]
	var bx := ball.position.x * side
	var attacking := in_possession()
	var def_line := 0.0
	var length := 0.0
	var width_m := 0.0
	if attacking:
		def_line = clampf(bx - 30.0, -36.0, 6.0)
		length = 38.0
		width_m = 29.0
	else:
		def_line = clampf(bx - 20.0, -41.0, -4.0)
		length = 26.0
		width_m = 21.0
	var x_rel := def_line + depth * length
	if attacking and Formations.role_group(p.role) == "FWD":
		# Los delanteros se quedan en la línea del último defensor (fuera de juego en Fase 3)
		x_rel = minf(x_rel, opponent_last_line() - 0.5)
	x_rel = clampf(x_rel, -48.0, 47.0)
	var z := width * width_m * side + ball.position.z * (0.18 if attacking else 0.32)
	return Vector3(x_rel * side, 0, clampf(z, -32.0, 32.0))


# ------------------------------------------------------ Asistencia de pase

## Busca el mejor compañero para un pase. dir = dirección deseada (o Vector3.ZERO = cualquiera).
## Devuelve {player, point, score, kind} o {} si no hay opción.
func find_pass_target(from: FootballPlayer, dir: Vector3, kind: String, power := -1.0) -> Dictionary:
	var best := {}
	var best_score := -INF
	var origin := from.global_position
	var preferred := lerpf(8.0, 42.0, power) if power >= 0.0 else -1.0
	for m in players:
		if m == from:
			continue
		var lead := m.velocity * 0.45
		if kind == "through":
			lead = m.velocity * 0.9 + Vector3(side * 6.0, 0, 0)
		var point := m.global_position + lead
		point.x = clampf(point.x, -PitchDims.HALF_LENGTH + 1.0, PitchDims.HALF_LENGTH - 1.0)
		point.z = clampf(point.z, -PitchDims.HALF_WIDTH + 1.0, PitchDims.HALF_WIDTH - 1.0)
		var to := point - origin
		to.y = 0.0
		var d := to.length()
		if d < 4.0 or d > 60.0:
			continue
		var n := to / d
		var score := 0.0
		if dir.length() > 0.1:
			var align := dir.normalized().dot(n)
			if align < 0.55:
				continue
			score += align * 3.0
		else:
			if m.is_gk:
				score -= 2.0
		var lane := _lane_clearance(origin, point)
		var space := _space_at(point)
		score += clampf(lane / 3.0, 0.0, 1.0) * 1.5 + clampf(space / 7.0, 0.0, 1.0) * 1.0
		score += (to.x * side) / 18.0
		if from.global_position.x * side > 20.0 and to.x * side < -3.0:
			score -= 1.0  # en el último tercio, no retroceder
		if preferred > 0.0:
			score -= absf(d - preferred) / 25.0
		if kind in ["pass", "through"] and lane < 1.2:
			score -= 1.0
		if score > best_score:
			best_score = score
			best = {"player": m, "point": point, "score": score, "dist": d, "lane": lane}
	return best


func _lane_clearance(a: Vector3, b: Vector3) -> float:
	var best := 99.0
	for o in opponent.players:
		var p := o.global_position
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var c := a + ab * t
		best = minf(best, Vector2(p.x - c.x, p.z - c.z).length())
	return best


func _space_at(point: Vector3) -> float:
	var best := 99.0
	for o in opponent.players:
		best = minf(best, Vector2(o.global_position.x - point.x, o.global_position.z - point.z).length())
	return best


func nearest_opponent(p: FootballPlayer) -> FootballPlayer:
	var best: FootballPlayer = null
	var bd := INF
	for o in opponent.players:
		var d := o.global_position.distance_squared_to(p.global_position)
		if d < bd:
			bd = d
			best = o
	return best


# ------------------------------------------------------------------- IA

func _physics_process(dt: float) -> void:
	_time += dt
	if has_ball():
		last_possession = true
	elif opponent != null and opponent.has_ball():
		last_possession = false
	if not ai_active or opponent == null:
		return
	var chaser := _choose_chaser()
	var presser: FootballPlayer = null
	var cover: FootballPlayer = null
	var opp_carrier := opponent.carrier()
	if opp_carrier != null and ball.held_by == null:
		presser = nearest_to(opp_carrier.global_position, false)
		cover = nearest_to(opp_carrier.global_position, false, presser)
	for p in players:
		if p.human or not p.can_act() or p.state == FootballPlayer.State.FROZEN:
			continue
		if p.is_gk:
			_ai_keeper(p, dt)
		elif p.has_ball:
			_ai_carrier(p)
		elif ball.intended_receiver == p and ball.owner_player == null:
			_ai_receive(p)
		elif p == chaser:
			var pred := ball.global_position + Vector3(ball.velocity.x, 0, ball.velocity.z) * 0.35
			_go_to(p, pred, true)
		elif p == presser and opp_carrier != null:
			_ai_press(p, opp_carrier)
		elif p == cover and opp_carrier != null and double_press:
			_ai_press(p, opp_carrier)
		elif p == cover and opp_carrier != null and diff["press"] > 0.5 and opp_carrier.global_position.x * side < -15.0:
			var gs := (own_goal() - opp_carrier.global_position).normalized()
			_go_to(p, opp_carrier.global_position + gs * 4.0, true)
		else:
			_ai_position(p)


## Jugador que va a por un balón suelto (el que llega antes).
func _choose_chaser() -> FootballPlayer:
	if ball.owner_player != null or ball.held_by != null or ball.dead:
		return null
	if ball.intended_receiver != null and players.has(ball.intended_receiver):
		return null
	var best: FootballPlayer = null
	var bt := INF
	for p in players:
		if p.is_gk:
			continue
		var d := p.global_position.distance_to(ball.global_position)
		var t := d / (p.top_speed(true) + 0.1)
		if t < bt:
			bt = t
			best = p
	# Si el rival llega mucho antes, no persigas con todos: solo el más cercano igualmente
	return best


func _go_to(p: FootballPlayer, target: Vector3, urgent: bool) -> void:
	var to := target - p.global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.4:
		p.move_intent = Vector3.ZERO
	else:
		p.move_intent = to / d * clampf(d / 3.0, 0.25, 1.0)
	p.sprint_intent = urgent and d > 5.0 and p.stamina > 0.25
	p.face_point = ball.global_position


func _ai_position(p: FootballPlayer) -> void:
	var t := slot_target(p)
	if not in_possession():
		# Marcaje: defender el lado de la portería del atacante más cercano a su zona
		var mark: FootballPlayer = null
		var md := 11.0
		for o in opponent.players:
			if o.is_gk:
				continue
			var d := o.global_position.distance_to(t)
			if d < md:
				md = d
				mark = o
		if mark != null and Formations.role_group(p.role) != "FWD":
			var gs := (own_goal() - mark.global_position).normalized()
			t = t.lerp(mark.global_position + gs * 1.8, 0.65)
	else:
		# Desmarque: los delanteros atacan el espacio a la espalda cuando el portador mira al frente
		var c := carrier()
		if c != null and c != p and Formations.role_group(p.role) == "FWD":
			var cx := c.global_position.x * side
			if cx > -10.0 and fmod(_time + p.slot_index * 1.7, 6.0) < 2.2:
				t.x = (opponent_last_line() + 6.0) * side
	var urgent := p.global_position.distance_to(t) > 12.0
	_go_to(p, t, urgent)


func _ai_receive(p: FootballPlayer) -> void:
	# Ir al punto de la trayectoria del balón más cercano
	var bv := Vector3(ball.velocity.x, 0, ball.velocity.z)
	var bp := Vector3(ball.position.x, 0, ball.position.z)
	var target := bp
	if bv.length() > 0.5:
		var t := clampf((p.global_position - bp).dot(bv) / bv.length_squared(), 0.0, 3.0)
		target = bp + bv * t
	_go_to(p, target, true)


func _ai_press(p: FootballPlayer, c: FootballPlayer) -> void:
	var d := p.global_position.distance_to(c.global_position)
	var gs := (own_goal() - c.global_position).normalized()
	# Interponerse entre el portador y la portería; entrar cuando está cerca
	var t := c.global_position + gs * clampf(d * 0.3, 0.6, 2.0)
	_go_to(p, t, d > 3.0)
	if d < 1.4 and _decide(p) and _rng.randf() < diff["press"] * 0.5:
		if _rng.randf() < 0.12 * diff["press"]:
			p.heading = (c.global_position - p.global_position).normalized()
			p.request_slide()
		else:
			p.request_tackle(c)


func _decide(p: FootballPlayer) -> bool:
	var nt: float = _next_decision.get(p, 0.0)
	if _time < nt:
		return false
	_next_decision[p] = _time + diff["react"] * _rng.randf_range(0.7, 1.3)
	return true


func _ai_carrier(p: FootballPlayer) -> void:
	var pos := p.global_position
	var goal := target_goal()
	var to_goal := goal - pos
	to_goal.y = 0.0
	var dist_goal := to_goal.length()
	var opp := nearest_opponent(p)
	var pressure := opp.global_position.distance_to(pos) if opp != null else 99.0
	var dir: Vector3 = _dribble_dir.get(p, to_goal.normalized())
	if _decide(p):
		var x_rel := pos.x * side
		# Tiro
		var angle_ok := absf(pos.z) < 18.0 or dist_goal < 14.0
		if dist_goal < 31.0 and angle_ok:
			var lane := _lane_clearance(pos, goal)
			var chance := 0.9 if dist_goal < 18.0 else (0.55 if dist_goal < 24.0 else 0.25)
			if pressure < 2.0:
				chance = maxf(chance, 0.5)  # presionado en zona de tiro: dispara
			if lane < 1.0:
				chance *= 0.6
			if _rng.randf() < chance:
				var aim := Vector3(goal.x, 0, _rng.randf_range(-3.0, 3.0)) - pos
				p.request_kick("shot", clampf(0.45 + dist_goal / 50.0 + _rng.randf_range(-0.1, 0.1), 0.35, 0.9), aim.normalized())
				return
		# Centro desde la banda
		if x_rel > 36.0 and absf(pos.z) > 13.0 and _rng.randf() < 0.6:
			var box := Vector3(goal.x - side * _rng.randf_range(6.0, 12.0), 0, _rng.randf_range(-6.0, 6.0))
			var mate := nearest_to(box, false, p)
			p.request_kick("cross", 0.7, (box - pos).normalized(), mate, box)
			return
		# Pase
		var opt := find_pass_target(p, Vector3.ZERO, "pass")
		# Espacio por delante: si lo hay, conducir
		var space_ahead := 99.0
		for o in opponent.players:
			var rel := o.global_position - pos
			if rel.x * side > 0.0:
				space_ahead = minf(space_ahead, rel.length())
		var progress := 0.0
		if not opt.is_empty():
			progress = ((opt["point"] as Vector3).x - pos.x) * side
		var good_forward := progress > 8.0 and float(opt["score"]) > 2.0
		var settled := p.possess_time > 0.7
		if x_rel > 18.0 and pressure < 2.2 and _rng.randf() < 0.45:
			var lat := to_goal.normalized().cross(Vector3.UP) * (1.0 if pos.z * side < 0.0 else -1.0)
			p.request_trick(lat)
			return
		var want_pass := pressure < 1.8 or (settled and space_ahead < 5.0 and _rng.randf() < 0.4) or (settled and good_forward and _rng.randf() < 0.2) or (settled and _rng.randf() < 0.04)
		if not opt.is_empty() and want_pass and float(opt["score"]) > 0.6:
			var kind := "pass"
			if float(opt["dist"]) > 28.0 or float(opt["lane"]) < 1.2:
				kind = "lob"
			p.request_kick(kind, 0.6, ((opt["point"] as Vector3) - pos).normalized(), opt["player"], opt["point"])
			if Engine.has_meta("debug"):
				print("    pase ", p.name, "->", opt["player"].name, " x=%.0f press=%.1f sc=%.1f" % [x_rel, pressure, opt["score"]])
			return
		# Pase en profundidad a un delantero que corre
		if x_rel > -5.0 and _rng.randf() < 0.15:
			var th := find_pass_target(p, to_goal.normalized(), "through")
			if not th.is_empty() and float(th["lane"]) > 1.5:
				p.request_kick("through", 0.6, ((th["point"] as Vector3) - pos).normalized(), th["player"], th["point"])
				return
		# Regate si hay un rival delante
		if opp != null and pressure < 3.0 and _rng.randf() < p.attr("dribbling") * 0.35:
			var lateral := to_goal.normalized().cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
			p.request_trick(lateral)
			return
		# Conducir hacia portería esquivando rivales
		dir = to_goal.normalized()
		for o in opponent.players:
			var off := pos - o.global_position
			off.y = 0.0
			var od := off.length()
			if od < 6.0 and od > 0.01:
				dir += off / od * (6.0 - od) / 6.0 * 0.9
		dir.y = 0.0
		dir = dir.normalized()
		_dribble_dir[p] = dir
	p.move_intent = dir
	p.sprint_intent = pressure > 3.0 and p.stamina > 0.25
	p.face_point = null


func _ai_keeper(p: FootballPlayer, _dt: float) -> void:
	var goal := own_goal()
	var bp := ball.global_position
	if keeper_rush and p.state != FootballPlayer.State.HOLD:
		_go_to(p, bp, true)
		if opponent.carrier() != null and p.global_position.distance_to(bp) < 1.3:
			p.request_slide()
		return
	if p.state == FootballPlayer.State.HOLD:
		p.move_intent = Vector3.ZERO
		if p._hold_time > 1.4 + _rng.randf() * 0.8 and ai_active:
			var opt := find_pass_target(p, Vector3.ZERO, "pass")
			if not opt.is_empty() and float(opt["lane"]) > 3.0 and float(opt["dist"]) < 30.0:
				p.request_kick("pass", 0.5, ((opt["point"] as Vector3) - p.global_position).normalized(), opt["player"], opt["point"])
			else:
				var tgt := Vector3(side * _rng.randf_range(0.0, 15.0), 0, _rng.randf_range(-18.0, 18.0))
				var m := nearest_to(tgt, false)
				p.request_kick("punt", 0.8, (tgt - p.global_position).normalized(), m, tgt)
		return
	# ¿Tiro hacia nuestra portería?
	var vx := ball.velocity.x * -side
	if ball.owner_player == null and ball.held_by == null and vx > 6.0:
		var t := (absf(ball.position.x - goal.x) - 0.3) / vx
		if t > 0.0 and t < 1.3:
			var z := ball.position.z + ball.velocity.z * t
			var y := ball.position.y + ball.velocity.y * t - 0.5 * Ball.GRAVITY * t * t
			y = absf(y)
			if absf(z) < PitchDims.GOAL_HALF_WIDTH + 1.2 and y < 3.2:
				var target := Vector3(p.global_position.x, y, z)
				var lateral := absf(z - p.global_position.z)
				if (lateral > 0.8 or y > 1.8) and t < 0.45 + 0.25 * p.attr("reflexes") * diff["gk"]:
					p.request_dive(target, t)
					return
				_go_to(p, Vector3(p.global_position.x, 0, z), true)
				return
	# Salir a por balones sueltos cercanos en el área
	var in_area := absf(bp.x - goal.x) < PitchDims.PENALTY_AREA_DEPTH and absf(bp.z) < PitchDims.PENALTY_AREA_HALF_WIDTH
	var opp_c := opponent.carrier()
	if in_area and ball.owner_player == null and ball.held_by == null and not ball.dead:
		var mine := nearest_to(bp, false)
		var their := opponent.nearest_to(bp, false)
		var dme := p.global_position.distance_to(bp)
		if their == null or dme < their.global_position.distance_to(bp) * 1.2 or mine == null or dme < mine.global_position.distance_to(bp):
			_go_to(p, bp, true)
			return
	# Salida a los pies en un mano a mano
	if opp_c != null and in_area and opp_c.global_position.distance_to(goal) < 14.0:
		var defenders_between := 0
		for m in players:
			if not m.is_gk and m.global_position.distance_to(goal) < opp_c.global_position.distance_to(goal):
				defenders_between += 1
		if defenders_between == 0:
			_go_to(p, opp_c.global_position.lerp(goal, 0.25), true)
			if p.global_position.distance_to(opp_c.global_position) < 1.3:
				p.request_slide()
			return
	# Colocación: en la bisectriz balón-portería
	var to_ball := bp - goal
	to_ball.y = 0.0
	var depth := clampf(to_ball.length() * 0.1, 0.8, 5.0) * (0.8 + 0.4 * p.attr("positioning"))
	var tgt2 := goal + to_ball.normalized() * depth
	tgt2.z = clampf(tgt2.z, -PitchDims.GOAL_HALF_WIDTH + 0.4, PitchDims.GOAL_HALF_WIDTH - 0.4)
	_go_to(p, tgt2, false)
	p.face_point = bp
