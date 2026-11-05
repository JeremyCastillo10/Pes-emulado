extends Node3D
## Partido 11 contra 11. Monta estadio, balón, equipos, cámara y HUD y dirige el flujo:
## saque inicial, juego, saques de banda / esquina / meta, goles, medio tiempo y final.
## Lleva las estadísticas (posesión, tiros, a puerta, córners, pases).

signal stats_changed

enum Phase { KICKOFF, PLAYING, RESTART, GOAL, HALFTIME, FULLTIME }

const BallScene := preload("res://scenes/match/ball.tscn")
const HUDScene := preload("res://scenes/ui/hud.tscn")

var stadium: StadiumBuilder
var ball: Ball
var teams: Array[Team] = []
var human: HumanController
var cam: CameraRig
var hud: MatchHUD

var phase: Phase = Phase.KICKOFF
var half := 1
var clock := 0.0                 # segundos de juego simulados (0..90*60)
var score := [0, 0]
var stats := {}
var events: Array = []           # [{minute, team, kind, player}]
var kickoff_team := 0
var restart_kind := ""
var restart_team := 0
var restart_taker: FootballPlayer = null
var _phase_t := 0.0
var _last_owner: Node = null
var _pending_pass_team := -1
var _contact_cd := {}
var _rng := RandomNumberGenerator.new()

# Pruebas automáticas
var _autotest := false
var _shots_dir := ""
var _autotest_quit := 0.0


func _ready() -> void:
	_rng.randomize()
	var args := OS.get_cmdline_user_args()
	_autotest = "--autotest" in args
	for a in args:
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
			_autotest = true
		if a.begins_with("--half="):
			GameSettings.half_minutes = float(a.substr(7))
		if a.begins_with("--quit-after-min="):
			_autotest_quit = float(a.substr(17))
	if _autotest:
		var custom_half := false
		for a in args:
			custom_half = custom_half or a.begins_with("--half=")
		if not custom_half:
			GameSettings.half_minutes = 2.0
		Engine.set_meta("debug", true)
	stadium = StadiumBuilder.new()
	stadium.name = "Stadium"
	add_child(stadium)
	stadium.build()

	ball = BallScene.instantiate()
	add_child(ball)
	ball.place(Vector3.ZERO)
	ball.goal_scored.connect(_on_goal)
	ball.post_hit.connect(_on_post)
	ball.out_of_play.connect(_on_out)
	ball.kicked.connect(_on_ball_kicked)
	ball.net_hit.connect(func(pos: Vector3, s: float) -> void: stadium.net_impact(pos, s))

	cam = CameraRig.new()
	cam.name = "Camera"
	add_child(cam)
	cam.current = true
	cam.ball = ball

	_create_teams()

	hud = HUDScene.instantiate()
	add_child(hud)
	hud.setup(self)

	GameSettings.quality_changed.connect(_on_quality_changed)
	_on_quality_changed(GameSettings.quality)
	_reset_stats()
	start_kickoff(0)


func _create_teams() -> void:
	var db := _load_json("res://data/teams/demo.json")
	var list: Array = db.get("teams", [])
	var home: Dictionary = list[0]
	var away: Dictionary = list[1]
	var away_kit := "home"
	if _kits_clash(home, away):
		away_kit = "away"
	var t0 := Team.new()
	t0.name = "TeamHome"
	add_child(t0)
	t0.setup(home, 1, not _autotest, ball, "home", 2, self)
	var t1 := Team.new()
	t1.name = "TeamAway"
	add_child(t1)
	t1.setup(away, -1, false, ball, away_kit, GameSettings.difficulty, self)
	t0.opponent = t1
	t1.opponent = t0
	for t in [t0, t1]:
		t.process_physics_priority = -10
		for p in t.players:
			p.opponents = t.opponent
			p.kicked.connect(_on_player_kicked)
			p.saved.connect(_on_save)
			p.tackled.connect(func(_w: FootballPlayer, _l: FootballPlayer) -> void: pass)
	teams = [t0, t1]
	human = HumanController.new()
	human.name = "Human"
	add_child(human)
	human.team = t0
	human.cam = cam
	human.ball = ball
	human.enabled = t0.human
	if t0.human:
		human.set_controlled(t0.nearest_to(Vector3.ZERO))
	cam.player = t0.controlled if t0.controlled else t0.players[9]
	cam.attack_side = t0.side
	human.switched.connect(func(p: FootballPlayer) -> void: cam.player = p)


func _kits_clash(a: Dictionary, b: Dictionary) -> bool:
	var ca := Color.html(str(a.get("kits", {}).get("home", {}).get("shirt", "#fff")))
	var cb := Color.html(str(b.get("kits", {}).get("home", {}).get("shirt", "#000")))
	return Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length() < 0.35


static func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir " + path)
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


func _on_quality_changed(_q: int) -> void:
	stadium.set_shadows(GameSettings.shadows_enabled())
	for t in teams:
		for p in t.players:
			p.set_shadows(GameSettings.shadows_enabled())


func _reset_stats() -> void:
	stats = {"possession": [0.0, 0.0], "shots": [0, 0], "on_target": [0, 0], "corners": [0, 0],
		"passes": [0, 0], "passes_ok": [0, 0], "fouls": [0, 0], "offsides": [0, 0]}


func team_index(t: Node) -> int:
	return teams.find(t)


func minute() -> int:
	return int(clock / 60.0)


# --------------------------------------------------------------- Flujo

func _set_phase(p: Phase) -> void:
	phase = p
	_phase_t = 0.0


func start_kickoff(team_idx: int) -> void:
	_set_phase(Phase.KICKOFF)
	kickoff_team = team_idx
	ball.place(Vector3.ZERO)
	ball.dead = true
	for ti in 2:
		var t := teams[ti]
		t.ai_active = false
		for p in t.players:
			var s: Array = Formations.slots(t.formation)[p.slot_index]
			var x_rel := -48.0 if p.is_gk else (-36.0 + float(s[1]) * 32.0)
			x_rel = minf(x_rel, -1.0 if ti == team_idx else -9.8)
			var z: float = float(s[2]) * 22.0 * t.side
			p.reset_at(Vector3(x_rel * t.side, 0, z), Vector3(t.side, 0, 0))
			p.freeze(true)
			p.face_point = Vector3.ZERO
	var kt := teams[team_idx]
	var fw := _forwards(kt)
	restart_taker = fw[0]
	restart_taker.reset_at(Vector3(-0.6 * kt.side, 0, 0.05), Vector3(kt.side, 0, 0))
	restart_taker.freeze(true)
	if fw.size() > 1:
		fw[1].reset_at(Vector3(-1.0 * kt.side, 0, 3.0), Vector3(kt.side, 0, 0))
		fw[1].freeze(true)
	restart_kind = "kickoff"
	restart_team = team_idx
	if kt.human:
		human.set_controlled(restart_taker)
	elif teams[0].human:
		human.set_controlled(teams[0].nearest_to(Vector3.ZERO))
	hud.show_message(Lang.t("kickoff"), 1.0)


func _forwards(t: Team) -> Array:
	var list: Array = []
	for p in t.players:
		if Formations.role_group(p.role) == "FWD":
			list.append(p)
	for p in t.players:
		if Formations.role_group(p.role) == "MID" and list.size() < 2:
			list.append(p)
	list.sort_custom(func(a: FootballPlayer, b: FootballPlayer) -> bool: return absf(a.global_position.z) < absf(b.global_position.z))
	return list


func _start_restart(kind: String, team_idx: int, pos: Vector3) -> void:
	_set_phase(Phase.RESTART)
	restart_kind = kind
	restart_team = team_idx
	var t := teams[team_idx]
	pos.y = 0.0
	ball.place(pos)
	ball.dead = true
	var taker: FootballPlayer
	if kind == "goal_kick":
		taker = t.goalkeeper()
	else:
		taker = t.nearest_to(pos, false)
	restart_taker = taker
	# Mirando hacia el campo
	var look := Vector3(-pos.x * 0.3, 0, -pos.z).normalized()
	if kind == "goal_kick":
		look = Vector3(t.side, 0, 0)
	elif kind == "corner":
		look = Vector3(-signf(pos.x), 0, -signf(pos.z) * 1.4).normalized()
	elif kind == "throw_in":
		look = Vector3(t.side * 0.4, 0, -signf(pos.z)).normalized()
	taker.reset_at(pos - look * 0.55, look)
	taker.freeze(true)
	for tt in teams:
		tt.ai_active = true
		for p in tt.players:
			if p != taker and p.state == FootballPlayer.State.FROZEN:
				p.freeze(false)
	# Rivales a distancia reglamentaria
	var min_d := 9.15 if kind != "throw_in" else 2.0
	for o in teams[1 - team_idx].players:
		var d := o.global_position - pos
		d.y = 0.0
		if d.length() < min_d:
			var np := pos + (d.normalized() if d.length() > 0.1 else Vector3(0, 0, -signf(pos.z))) * min_d
			np.x = clampf(np.x, -PitchDims.HALF_LENGTH, PitchDims.HALF_LENGTH)
			np.z = clampf(np.z, -PitchDims.HALF_WIDTH, PitchDims.HALF_WIDTH)
			o.position = np
	if t.human and not taker.is_gk:
		human.set_controlled(taker)
	if _autotest:
		print("  saque ", kind, " equipo ", team_idx, " en ", pos)
	if kind == "corner":
		stats["corners"][team_idx] += 1
	hud.show_message(Lang.t("out_" + kind), 1.2)


func _ai_take_restart() -> void:
	var t := teams[restart_team]
	var p := restart_taker
	if p == null:
		return
	if t.human and p.human:
		return  # lo saca el jugador humano
	var wait := 1.4 if restart_kind != "kickoff" else 1.0
	if _phase_t < wait:
		return
	var from := p.global_position
	match restart_kind:
		"corner":
			var box := Vector3(t.target_goal().x - t.side * _rng.randf_range(5.0, 11.0), 0, _rng.randf_range(-5.0, 5.0))
			p.request_kick("cross", 0.7, (box - from).normalized(), t.nearest_to(box, false, p), box)
		"goal_kick":
			var opt := t.find_pass_target(p, Vector3.ZERO, "pass")
			if not opt.is_empty() and float(opt["lane"]) > 4.0 and float(opt["dist"]) < 25.0:
				p.request_kick("pass", 0.5, ((opt["point"] as Vector3) - from).normalized(), opt["player"], opt["point"])
			else:
				var tgt := Vector3(t.side * _rng.randf_range(-5.0, 10.0), 0, _rng.randf_range(-20.0, 20.0))
				p.request_kick("lob", 0.8, (tgt - from).normalized(), t.nearest_to(tgt, false), tgt)
		"kickoff":
			var mate := t.nearest_to(from + Vector3(-t.side * 8.0, 0, 0), false, p)
			var pt := mate.global_position
			p.request_kick("pass", 0.4, (pt - from).normalized(), mate, pt)
		_:
			var opt2 := t.find_pass_target(p, Vector3.ZERO, "pass")
			if opt2.is_empty():
				p.request_kick("pass", 0.5, p.heading)
			else:
				p.request_kick("pass", 0.5, ((opt2["point"] as Vector3) - from).normalized(), opt2["player"], opt2["point"])


func _on_ball_kicked(_by: Node, _spd: float) -> void:
	if phase == Phase.KICKOFF or phase == Phase.RESTART:
		_set_phase(Phase.PLAYING)
		for t in teams:
			t.ai_active = true
			for p in t.players:
				if p.state == FootballPlayer.State.FROZEN:
					p.freeze(false)
		restart_taker = null


func _on_player_kicked(p: FootballPlayer, kind: String, _power: float) -> void:
	var ti := team_index(p.team)
	if kind == "shot":
		stats["shots"][ti] += 1
		stadium.set_crowd_excitement(0.7)
	else:
		stats["passes"][ti] += 1
		_pending_pass_team = ti


func _on_save(keeper: FootballPlayer, caught: bool) -> void:
	var shooter := ball.shot_by as FootballPlayer
	if shooter != null and shooter.team != keeper.team:
		stats["on_target"][team_index(shooter.team)] += 1
	ball.shot_by = null
	hud.show_message(Lang.t("save_catch" if caught else "save_parry"), 1.0)


func _on_goal(side: int) -> void:
	if phase != Phase.PLAYING:
		return
	var ti := 0 if teams[0].side == side else 1
	score[ti] += 1
	var scorer := ball.last_touch as FootballPlayer
	var own_goal := scorer != null and team_index(scorer.team) != ti
	if ball.shot_by != null and team_index(ball.shot_by.team) == ti:
		stats["on_target"][ti] += 1
	events.append({"minute": minute() + 1, "team": ti, "kind": "goal", "player": scorer.display_name() if scorer else "", "own_goal": own_goal})
	_set_phase(Phase.GOAL)
	stadium.set_crowd_excitement(1.0)
	cam.shake = 0.5
	InputHub.vibrate(350 if teams[ti].human else 120)
	for p in teams[ti].players:
		if p == scorer or p.global_position.distance_to(ball.global_position) < 25.0:
			p.celebrate()
	for p in teams[1 - ti].players:
		if p.global_position.distance_to(ball.global_position) < 20.0:
			p.lament()
	for t in teams:
		t.ai_active = false
	var who := ""
	if scorer:
		who = scorer.display_name() + (" (" + Lang.t("own_goal") + ")" if own_goal else "")
	hud.show_message(Lang.t("goal") + "\n" + who, 2.6, Color(1.0, 0.85, 0.15))
	hud.refresh_score()
	print("GOL %s %d-%d (%s) min %d" % [teams[ti].info.get("short"), score[0], score[1], who, minute() + 1])


func _on_post(is_crossbar: bool, spd: float) -> void:
	if spd > 3.0 and phase == Phase.PLAYING:
		hud.show_message(Lang.t("crossbar" if is_crossbar else "post"), 1.0)
		stadium.set_crowd_excitement(0.85)


func _on_out(kind: String, pos: Vector3) -> void:
	if phase != Phase.PLAYING:
		return
	if _autotest:
		print("    FUERA ", kind, " pending=", _pending_pass_team)
	var lt := ball.last_touch as FootballPlayer
	var last_team := team_index(lt.team) if lt != null else 0
	var other := 1 - last_team
	if kind == "touch_line":
		_queue_restart("throw_in", other, Vector3(clampf(pos.x, -PitchDims.HALF_LENGTH + 0.5, PitchDims.HALF_LENGTH - 0.5), 0, signf(pos.z) * PitchDims.HALF_WIDTH))
		return
	var s := int(signf(pos.x))
	# Equipo que defiende esa portería: el que ataca hacia el lado contrario
	var defending := 0 if teams[0].side == -s else 1
	if last_team == defending:
		_queue_restart("corner", 1 - defending, Vector3(s * (PitchDims.HALF_LENGTH - 0.3), 0, signf(pos.z) * (PitchDims.HALF_WIDTH - 0.3)))
	else:
		_queue_restart("goal_kick", defending, Vector3(s * (PitchDims.HALF_LENGTH - 5.5), 0, signf(pos.z) * 5.0))


var _queued: Array = []


func _queue_restart(kind: String, ti: int, pos: Vector3) -> void:
	_queued = [kind, ti, pos]
	_set_phase(Phase.RESTART)
	restart_taker = null
	for t in teams:
		t.ai_active = true


func _physics_process(dt: float) -> void:
	_phase_t += dt
	match phase:
		Phase.PLAYING:
			_advance_clock(dt)
			_track_stats(dt)
		Phase.RESTART:
			_advance_clock(dt)
			if not _queued.is_empty() and _phase_t > 1.2:
				var q := _queued
				_queued = []
				_start_restart(q[0], q[1], q[2])
			elif _queued.is_empty():
				_ai_take_restart()
		Phase.KICKOFF:
			_ai_take_restart()
		Phase.GOAL:
			if _phase_t > 3.5:
				var conceded := 1 if score_changed_last() == 0 else 0
				start_kickoff(conceded)
		_:
			pass
	_separate_players()
	if _autotest and Engine.get_physics_frames() % 300 == 0:
		var o: Node = ball.owner_player if ball.owner_player else ball.held_by
		print("min %d fase %d balón %s v=%.1f dueño %s" % [minute(), phase, str(ball.position.snapped(Vector3.ONE * 0.1)), ball.velocity.length(), o.name if o else "-"])
		if o:
			print("   estado=%d has_ball=%s dist=%.2f human=%s ai=%s intent=%s" % [o.state, o.has_ball, o.ball_distance(), o.human, o.team.ai_active, str(o.move_intent)])


func score_changed_last() -> int:
	for i in range(events.size() - 1, -1, -1):
		if events[i]["kind"] == "goal":
			return int(events[i]["team"])
	return 0


func _advance_clock(dt: float) -> void:
	var scale := 45.0 / maxf(GameSettings.half_minutes, 0.5)
	clock += dt * scale
	var end := 45.0 * 60.0 * half
	if clock >= end and phase == Phase.PLAYING:
		clock = end
		if half == 1:
			_end_half()
		else:
			_end_match()


func _end_half() -> void:
	_set_phase(Phase.HALFTIME)
	_freeze_all()
	hud.show_message(Lang.t("half_time"), 2.0)
	print("MEDIO TIEMPO %d-%d" % [score[0], score[1]])
	if _autotest:
		start_second_half()
		return
	hud.show_stats(Lang.t("half_time"), false)


func start_second_half() -> void:
	half = 2
	clock = 45.0 * 60.0
	for t in teams:
		t.side *= -1
	cam.attack_side = teams[0].side
	start_kickoff(1)


func _end_match() -> void:
	_set_phase(Phase.FULLTIME)
	_freeze_all()
	var w := 0 if score[0] > score[1] else (1 if score[1] > score[0] else -1)
	for ti in 2:
		for p in teams[ti].players:
			if w == ti:
				p.celebrate()
			elif w >= 0:
				p.lament()
	hud.show_message(Lang.t("full_time"), 2.0)
	if not _autotest:
		hud.show_stats(Lang.t("full_time"), true)
	print("FINAL %d-%d" % [score[0], score[1]])
	print("ESTADÍSTICAS ", stats)
	if _autotest:
		get_tree().quit()


func _freeze_all() -> void:
	for t in teams:
		t.ai_active = false
		for p in t.players:
			p.move_intent = Vector3.ZERO


func _track_stats(dt: float) -> void:
	for ti in 2:
		if teams[ti].has_ball() or (teams[ti].last_possession and not teams[1 - ti].has_ball()):
			stats["possession"][ti] += dt
			break
	var owner: Node = ball.owner_player if ball.owner_player != null else ball.held_by
	if owner != _last_owner:
		_last_owner = owner
		if owner != null and _pending_pass_team >= 0:
			if team_index(owner.team) == _pending_pass_team:
				stats["passes_ok"][_pending_pass_team] += 1
			elif _autotest:
				var ir := ball.intended_receiver
				print("    PASE PERDIDO a ", owner.name, " receptor=", ir.name if ir else "-")
			_pending_pass_team = -1


## Choques entre jugadores: se empujan según su físico; el más fuerte gana el cuerpo a cuerpo.
func _separate_players() -> void:
	var all: Array[FootballPlayer] = []
	for t in teams:
		all.append_array(t.players)
	var n := all.size()
	for i in n:
		var a := all[i]
		for j in range(i + 1, n):
			var b := all[j]
			var d := Vector2(b.position.x - a.position.x, b.position.z - a.position.z)
			var l := d.length()
			var min_d := FootballPlayer.RADIUS * 2.0
			if l >= min_d or l < 0.0001:
				continue
			var nrm := d / l
			var pa := a.attr("physical") + 0.2
			var pb := b.attr("physical") + 0.2
			var wa := pb / (pa + pb)
			var push := min_d - l
			a.position -= Vector3(nrm.x, 0, nrm.y) * push * wa
			b.position += Vector3(nrm.x, 0, nrm.y) * push * (1.0 - wa)
			# Carga hombro con hombro: el portador puede perder el balón
			if a.team != b.team and (a.has_ball or b.has_ball) and phase == Phase.PLAYING:
				var key := str(a.get_instance_id()) + ":" + str(b.get_instance_id())
				if _contact_cd.get(key, 0) < Engine.get_physics_frames():
					_contact_cd[key] = Engine.get_physics_frames() + 45
					var c := a if a.has_ball else b
					var o := b if c == a else a
					var prob := clampf(0.12 + (o.attr("physical") - c.attr("physical")) * 0.9, 0.03, 0.5)
					if _rng.randf() < prob:
						if _autotest:
							print("    carga ", o.name, " sobre ", c.name)
						c.has_ball = false
						ball.owner_player = null
						c.stumble()


# ----------------------------------------------------------- Entradas

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_cycle"):
		cam.cycle_mode()
		hud.on_camera_changed()
	elif event.is_action_pressed("pause"):
		hud.toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		hud.toggle_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED and hud != null and not get_tree().paused:
		hud.toggle_pause()


func restart_match() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


var _ht := 0.0
const HUMAN_TEST := [[0.5, "press", "act_pass"], [0.7, "release", "act_pass"], [2.0, "press", "move_right"],
	[3.0, "press", "act_sprint"], [5.0, "press", "act_pass"], [5.3, "release", "act_pass"],
	[7.0, "press", "act_trick"], [7.1, "release", "act_trick"], [8.0, "press", "act_lob"], [8.6, "release", "act_lob"],
	[10.0, "press", "act_pass"], [14.0, "release", "act_pass"], [14.5, "press", "act_shoot"], [14.6, "release", "act_shoot"],
	[16.0, "press", "act_shoot"], [16.7, "release", "act_shoot"], [20.0, "quit", ""]]
var _ht_step := 0


func _human_test(delta: float) -> void:
	_ht += delta
	while _ht_step < HUMAN_TEST.size() and _ht >= float(HUMAN_TEST[_ht_step][0]):
		var ev: Array = HUMAN_TEST[_ht_step]
		_ht_step += 1
		match ev[1]:
			"press": Input.action_press(ev[2])
			"release": Input.action_release(ev[2])
			"quit":
				print("ESTADÍSTICAS ", stats)
				get_tree().quit()
	if int(_ht * 2.0) != int((_ht - delta) * 2.0):
		var c := teams[0].controlled
		print("t=%.1f fase=%d control=%s balón_de=%s estado=%d" % [_ht, phase, c.name if c else "-", ball.owner_player.name if ball.owner_player else "-", c.state if c else -1])


func _process(delta: float) -> void:
	if "--humantest" in OS.get_cmdline_user_args():
		_human_test(delta)
	if _shots_dir != "":
		_shots(delta)
	if _autotest and _autotest_quit > 0.0 and clock / 60.0 >= _autotest_quit:
		print("FIN PRUEBA min %d marcador %d-%d" % [minute(), score[0], score[1]])
		print("ESTADÍSTICAS ", stats)
		get_tree().quit()


# Capturas de pantalla para revisar el aspecto (requiere un renderizador real).
var _shot_t := 0.0
var _shot_step := 0
const SHOTS := [[3.0, 0, 0, "broadcast_day"], [6.0, 2, 0, "close_day"], [9.0, 1, 1, "wide_sunset"], [12.0, 3, 2, "behind_night"]]


func _shots(delta: float) -> void:
	_shot_t += delta
	if _shot_step >= SHOTS.size():
		return
	var sh: Array = SHOTS[_shot_step]
	if _shot_t >= float(sh[0]) - 1.0:
		GameSettings.camera_mode = int(sh[1])
		if GameSettings.time_of_day != int(sh[2]):
			GameSettings.time_of_day = int(sh[2])
			stadium.apply_time_of_day(int(sh[2]))
	if _shot_t >= float(sh[0]):
		_shot_step += 1
		get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(str(sh[3]) + ".png"))
		print("captura ", sh[3])
		if _shot_step >= SHOTS.size():
			get_tree().quit()
