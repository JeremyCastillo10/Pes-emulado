class_name FootballPlayer
extends Node3D
## Jugador (de campo o portero). No lee la entrada directamente: lo mueven "intenciones"
## (move_intent, sprint_intent) y peticiones de acción (request_kick, request_slide...)
## que envían el control humano (HumanController) o la IA (TeamAI).
## Movimiento cinemático con inercia; todo depende de las valoraciones (0-99).

signal action_message(text: String)
signal kicked(player: FootballPlayer, kind: String, power: float)
signal tackled(winner: FootballPlayer, loser: FootballPlayer)
signal saved(keeper: FootballPlayer, caught: bool)

enum State { MOVE, KICK, SLIDE, TRICK, STUMBLE, CELEBRATE, TACKLE, DIVE, LYING, HOLD, THROW, FROZEN }

const ARENA_X := 60.0
const ARENA_Z := 40.0
const RADIUS := 0.38

var data: Dictionary = {}
var team: Node = null          # Team
var opponents: Node = null     # Team rival
var slot_index := 0
var role := "CMF"
var is_gk := false
var ball: Ball
var human := false             # lo controla un humano ahora mismo

# Intenciones (las escribe el control humano o la IA)
var move_intent := Vector3.ZERO
var sprint_intent := false
var face_point = null          # Vector3 o null: hacia dónde mirar al estar parado

var velocity := Vector3.ZERO
var heading := Vector3(1, 0, 0)
var speed := 0.0
var stamina := 1.0
var state := State.MOVE
var state_t := 0.0
var has_ball := false
var charge := 0.0              # lo usa el HUD (carga del golpeo humano)
var charging_action := ""
var tackle_cooldown := 0.0
var possess_time := 0.0        # segundos desde que ganó el balón
var stat_mult := 1.0           # multiplicador por dificultad (IA)
var error_mult := 1.0

var model: PlayerModel
var marker: Node3D
var _shadow: MeshInstance3D
var _dust: CPUParticles3D
var _touch_timer := 0.0
var _kick := {}
var _kick_done := false
var _trick_kind := ""
var _trick_side := 1.0
var _trick_done := false
var _slide_hit := false
var _tackle_target: FootballPlayer = null
var _tackle_done := false
var _dive_vel := Vector3.ZERO
var _dive_done := false
var _hold_time := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_data: Dictionary, kit: Dictionary, p_ball: Ball) -> void:
	data = p_data
	set_meta("kit", kit)
	ball = p_ball
	is_gk = str(data.get("position", "")) == "GK"


func _ready() -> void:
	_rng.randomize()
	model = PlayerModel.new()
	model.number = int(data.get("number", 10))
	model.shirt_name = str(data.get("name", ""))
	model.height_m = float(data.get("height", 180)) / 100.0
	var ap: Dictionary = data.get("appearance", {})
	model.skin_color = Color.html(str(ap.get("skin", "#e0ac83")))
	model.hair_color = Color.html(str(ap.get("hair_color", "#2b1d14")))
	model.hair_style = int(ap.get("hair_style", 1))
	model.beard = int(ap.get("beard", 0))
	model.build = float(ap.get("build", 0.5))
	model.boots_color = Color.html(str(ap.get("boots", "#111111")))
	model.detail = GameSettings.quality
	if has_meta("kit"):
		var kit: Dictionary = get_meta("kit")
		model.shirt_color = Color.html(str(kit.get("shirt", "#ffffff")))
		model.shirt_color2 = Color.html(str(kit.get("shirt2", "#000000")))
		model.shorts_color = Color.html(str(kit.get("shorts", "#ffffff")))
		model.socks_color = Color.html(str(kit.get("socks", "#ffffff")))
	model.gloves = is_gk
	add_child(model)
	model.build_model()
	_shadow = Ball.make_blob_shadow(1.1)
	add_child(_shadow)
	_dust = _make_dust()
	add_child(_dust)
	marker = _make_marker()
	add_child(marker)
	marker.visible = false
	set_shadows(GameSettings.shadows_enabled())


## Sombras dinámicas en Alta; sombra circular barata en Baja/Media.
func set_shadows(on: bool) -> void:
	model.set_shadows(on)
	_shadow.visible = not on


func attr(key: String) -> float:
	return clampf(float(data.get(key, 70)) / 99.0 * stat_mult, 0.0, 1.05)


func display_name() -> String:
	return str(data.get("name", ""))


func _make_marker() -> Node3D:
	# Indicador del jugador controlado: flecha amarilla sobre la cabeza y aro en el suelo
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 10
	var cone := CylinderMesh.new()
	cone.top_radius = 0.22
	cone.bottom_radius = 0.0
	cone.height = 0.35
	cone.radial_segments = 3
	var arrow := MeshInstance3D.new()
	arrow.mesh = cone
	arrow.material_override = mat
	arrow.position = Vector3(0, 2.45, 0)
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(arrow)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.5
	ring.outer_radius = 0.6
	ring.rings = 24
	ring.ring_segments = 4
	var rmat := mat.duplicate() as StandardMaterial3D
	rmat.no_depth_test = false
	rmat.albedo_color = Color(1.0, 0.85, 0.1, 0.8)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rmi := MeshInstance3D.new()
	rmi.mesh = ring
	rmi.material_override = rmat
	rmi.scale = Vector3(1, 0.05, 1)
	rmi.position = Vector3(0, 0.03, 0)
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rmi)
	root.top_level = true
	return root


func _make_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 24
	p.lifetime = 0.7
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, -1.5, 0)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.7
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.47, 0.35, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	p.mesh = q
	p.position = Vector3(0, 0.1, 0)
	p.local_coords = false
	return p


# ------------------------------------------------------------------ Bucle

func _physics_process(dt: float) -> void:
	state_t += dt
	tackle_cooldown = maxf(tackle_cooldown - dt, 0.0)
	if has_ball:
		possess_time += dt
	var prev_speed := speed
	match state:
		State.MOVE:
			_locomotion(move_intent, dt)
		State.KICK:
			_brake(dt, 9.0)
			if not _kick_done and state_t >= float(_kick["contact"]):
				_execute_kick()
			if state_t >= 0.42:
				_set_state(State.MOVE)
		State.SLIDE:
			_slide(dt)
		State.TRICK:
			_trick(dt, move_intent)
		State.STUMBLE:
			_brake(dt, 7.0)
			if state_t > 0.75:
				_set_state(State.MOVE)
		State.CELEBRATE, State.FROZEN:
			_brake(dt, 6.0)
			if state == State.FROZEN and face_point != null:
				_turn_towards(face_point, dt, 6.0)
		State.TACKLE:
			_tackle(dt)
		State.DIVE:
			_dive(dt)
		State.LYING:
			_brake(dt, 10.0)
			if state_t > 0.7:
				_set_state(State.MOVE)
		State.HOLD:
			_locomotion(move_intent * 0.6, dt)
			_hold_time += dt
		State.THROW:
			_brake(dt, 10.0)
			if not _kick_done and state_t >= 0.25:
				_execute_kick()
			if state_t > 0.5:
				_set_state(State.MOVE)
	velocity = heading * speed if state != State.DIVE else _dive_vel
	position += velocity * dt
	position.y = 0.0
	position.x = clampf(position.x, -ARENA_X, ARENA_X)
	position.z = clampf(position.z, -ARENA_Z, ARENA_Z)
	basis = Basis.looking_at(heading, Vector3.UP)
	_update_stamina(dt)
	_update_ball(dt)
	# Datos para la animación procedural
	model.anim_speed = speed if state != State.DIVE else 0.0
	model.anim_sprint = sprint_intent and speed > 6.0
	model.anim_accel = (speed - prev_speed) / maxf(dt, 0.0001)
	if state == State.MOVE:
		model.play("gk_ready" if is_gk and _in_own_area() else "move")
	_shadow.global_position = global_position + Vector3(0, 0.012, 0)
	if marker.visible:
		marker.global_position = global_position


func _set_state(s: State) -> void:
	state = s
	state_t = 0.0
	_dust.emitting = false
	if s == State.MOVE:
		model.play("move")


func set_controlled(on: bool) -> void:
	human = on
	marker.visible = on
	if not on:
		charging_action = ""
		charge = 0.0


func freeze(on: bool) -> void:
	if on:
		_set_state(State.FROZEN)
		model.play("move")
	elif state == State.FROZEN:
		_set_state(State.MOVE)


func can_act() -> bool:
	return state in [State.MOVE, State.TRICK, State.HOLD, State.FROZEN]


func ball_distance() -> float:
	var to := ball.global_position - global_position
	to.y = 0.0
	return to.length()


func ball_close(d: float) -> bool:
	return ball_distance() < d and ball.position.y < 1.3


func _in_own_area() -> bool:
	if not is_gk or team == null:
		return false
	var own_x: float = -PitchDims.HALF_LENGTH * team.side
	return absf(position.x - own_x) < PitchDims.PENALTY_AREA_DEPTH and absf(position.z) < PitchDims.PENALTY_AREA_HALF_WIDTH


# ----------------------------------------------------------- Movimiento

func top_speed(sprint: bool) -> float:
	var spd := attr("speed")
	var top := (6.6 + spd * 2.7) if sprint else (4.4 + spd * 1.0)
	if has_ball:
		top *= 0.9 + 0.07 * attr("dribbling")
	top *= lerpf(0.78, 1.0, clampf(stamina * 1.6, 0.0, 1.0))
	return top


func _turn_towards(p: Vector3, dt: float, rate: float) -> void:
	var to := p - global_position
	to.y = 0.0
	if to.length() < 0.1:
		return
	var ang := heading.signed_angle_to(to.normalized(), Vector3.UP)
	heading = heading.rotated(Vector3.UP, clampf(ang, -rate * dt, rate * dt)).normalized()


func _locomotion(input: Vector3, dt: float) -> void:
	var sprint := sprint_intent and stamina > 0.03
	var mag := minf(input.length(), 1.0)
	var target := mag * top_speed(sprint)
	model.anim_turn = 0.0
	if mag > 0.12:
		var desired := input / maxf(input.length(), 0.0001)
		var ang := heading.signed_angle_to(desired, Vector3.UP)
		var t := clampf(speed / 9.0, 0.0, 1.0)
		var turn_rate := lerpf(13.0, 3.0 + 3.0 * attr("agility"), t)
		if has_ball:
			turn_rate *= 0.7 + 0.4 * attr("dribbling")
		# Los jugadores pesados giran algo peor
		turn_rate *= lerpf(1.08, 0.92, float(data.get("appearance", {}).get("build", 0.5)))
		var step := clampf(ang, -turn_rate * dt, turn_rate * dt)
		heading = heading.rotated(Vector3.UP, step).normalized()
		model.anim_turn = step / maxf(dt, 0.0001)
		var align := cos(absf(ang))
		target *= clampf(0.3 + 0.7 * maxf(align, 0.0), 0.0, 1.0)
	elif face_point != null:
		_turn_towards(face_point, dt, 5.0)
	var acc := 0.0
	if target > speed:
		acc = 3.8 + 7.5 * attr("acceleration")
	else:
		acc = 10.0 + 4.0 * attr("agility")
	speed = move_toward(speed, target, acc * dt)


func _brake(dt: float, decel: float) -> void:
	speed = move_toward(speed, 0.0, decel * dt)


func _update_stamina(dt: float) -> void:
	if sprint_intent and speed > 6.0:
		stamina -= 0.045 * (1.35 - 0.6 * attr("stamina")) * dt
	elif speed > 5.0:
		stamina -= 0.003 * dt
	else:
		stamina += 0.03 * (0.6 + 0.4 * attr("stamina")) * dt
	stamina = clampf(stamina, 0.0, 1.0)


# --------------------------------------------------------- Conducción

func _update_ball(dt: float) -> void:
	if ball == null:
		return
	if state == State.HOLD:
		if ball.held_by != self:
			_set_state(State.MOVE)
		return
	var to := ball.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if has_ball:
		if ball.owner_player != self or dist > 2.6 or ball.position.y > 1.3 or ball.dead:
			if Engine.has_meta("debug"):
				print("    pierde ", name, " owner=", ball.owner_player == self, " dist=%.1f" % dist, " x=%.0f" % (position.x * team.side))
			has_ball = false
			return
		if state in [State.KICK, State.SLIDE, State.STUMBLE, State.THROW]:
			return
		if state == State.TRICK or state == State.FROZEN:
			var hold := global_position + heading * 0.55
			var corr := (hold - ball.global_position) * 10.0
			ball.velocity = Vector3(velocity.x + corr.x, 0.0, velocity.z + corr.z)
			return
		_touch_timer -= dt
		if dist > 0.45 and heading.dot(to / maxf(dist, 0.001)) < 0.3:
			_touch_timer = minf(_touch_timer, 0.0)
		if _touch_timer <= 0.0 and dist < 1.6:
			_dribble_touch()
		return
	if not (state in [State.MOVE, State.TRICK, State.DIVE]):
		return
	if not ball.can_be_claimed_by(self):
		return
	if ball.owner_player != null:
		return
	var ctrl := attr("ball_control")
	# Portero dentro de su área: puede atrapar con las manos (balones altos también)
	if is_gk and _in_own_area() and state != State.DIVE:
		if dist < 1.0 + 0.3 * attr("reflexes") and ball.position.y < 2.5:
			var spd := ball.velocity.length()
			if spd < 16.0 + 10.0 * attr("reflexes") or _rng.randf() < 0.5 * attr("reflexes"):
				catch_ball()
			else:
				_parry(1.0)
			return
	var reach := 0.7 + 0.25 * ctrl + (0.35 if ball.intended_receiver == self else 0.0)
	if dist < reach and ball.position.y < 0.9:
		var rel := ball.velocity - velocity
		rel.y = 0.0
		var max_rel := 9.0 + 14.0 * ctrl
		if rel.length() < max_rel:
			gain_possession()
		else:
			var n := -to.normalized()
			ball.velocity = ball.velocity.bounce(n) * 0.35 + Vector3(_rng.randf_range(-1, 1), 0.5, _rng.randf_range(-1, 1))
			ball.last_touch = self
			ball.claim_block_time = 0.4
			ball.claim_block_by = self


func gain_possession() -> void:
	if Engine.has_meta("debug"):
		print("    gana ", name, " x=%.0f" % (position.x * team.side))
	has_ball = true
	possess_time = 0.0
	ball.owner_player = self
	ball.last_touch = self
	ball.intended_receiver = null
	_touch_timer = 0.0
	_dribble_touch()


func _dribble_touch() -> void:
	var t := clampf(speed / 9.0, 0.0, 1.0)
	var drib := attr("dribbling")
	var ctrl := attr("ball_control")
	var interval := lerpf(0.32, 0.58, t)
	var lead := lerpf(0.5, 1.7, t * t) * (1.15 - 0.3 * drib)
	var target := global_position + velocity * interval + heading * lead
	var v := (target - ball.global_position) / interval
	v.y = 0.0
	if v.length() > 0.01:
		v += v.normalized() * ball.rolling_decel * interval * 0.5
	var err := (1.0 - ctrl) * 0.25 * t
	v = v.rotated(Vector3.UP, _rng.randfn(0.0, err))
	ball.velocity = v
	ball.position.y = Ball.RADIUS
	ball.spin = Vector3.ZERO
	ball.last_touch = self
	_touch_timer = interval
	model.anim_touch = 0.12


# ------------------------------------------------------------- Golpeos

## kind: pass, through, lob, cross, shot, clear. point: destino (Vector3) o null.
func request_kick(kind: String, power: float, dir: Vector3, receiver: FootballPlayer = null, point = null) -> bool:
	if not can_act():
		return false
	if state == State.HOLD:
		# El portero saca con la mano (raso) o con el pie (largo)
		_kick = {"kind": "throw" if kind in ["pass", "through"] else "punt", "power": power,
			"dir": dir.normalized(), "receiver": receiver, "point": point, "curl": 0.0, "contact": 0.25}
		_kick_done = false
		_set_state(State.THROW)
		model.play("throw" if _kick["kind"] == "throw" else "kick")
		model.anim_kick_kind = "lob"
		if point != null:
			heading = _flat_dir_to(point)
		return true
	if not ball_close(1.7) and state != State.FROZEN:
		return false
	_set_state(State.KICK)
	_kick = {"kind": kind, "power": power, "dir": dir.normalized(), "receiver": receiver, "point": point,
		"contact": 0.2 if kind == "shot" else 0.14, "curl": InputHub.curl if human else 0.0}
	_kick_done = false
	var face := dir.normalized() if point == null else _flat_dir_to(point)
	heading = heading.slerp(face, 0.65).normalized()
	model.anim_kick_kind = kind
	model.play("kick")
	return true


func _flat_dir_to(p: Vector3) -> Vector3:
	var d: Vector3 = p - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else heading


func _execute_kick() -> void:
	_kick_done = true
	var kind: String = _kick["kind"]
	if kind == "throw" or kind == "punt":
		if ball.held_by != self:
			return
		ball.held_by = null
		ball.position = global_position + heading * 0.6 + Vector3(0, 1.0 if kind == "throw" else 0.4, 0)
	elif not ball_close(1.7):
		return  # golpeo al aire
	var power: float = _kick["power"]
	var dir: Vector3 = _kick["dir"]
	var curl: float = _kick["curl"]
	var point = _kick["point"]
	var right := dir.cross(Vector3.UP).normalized()
	var fatigue := 1.0 - stamina
	var moving := clampf(speed / 9.0, 0.0, 1.0)
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var em := error_mult
	match kind:
		"pass", "through", "throw":
			var acc := attr("short_pass")
			var err := (0.01 + (1.0 - acc) * 0.07 + fatigue * 0.02 + moving * 0.012) * em
			if point != null:
				vel = _ground_velocity_to(point, 11.0 if kind == "through" else 9.0)
				vel = vel.rotated(Vector3.UP, _rng.randfn(0.0, err))
			else:
				var spd := lerpf(8.0, 23.0, power) if kind != "through" else lerpf(12.0, 26.0, power)
				vel = dir.rotated(Vector3.UP, _rng.randfn(0.0, err)) * spd * (0.92 + 0.08 * acc)
			vel.y = 0.5 if kind != "throw" else 1.5
			spin = -vel.cross(Vector3.UP).normalized() * vel.length() / Ball.RADIUS * 0.3
		"lob", "cross", "punt", "clear":
			var acc2 := attr("long_pass")
			var err2 := (0.012 + (1.0 - acc2) * 0.07 + fatigue * 0.03) * em
			var theta := deg_to_rad(30.0 if kind == "lob" else (20.0 if kind == "cross" else 38.0))
			var target: Vector3
			if point != null:
				target = point
			else:
				target = global_position + dir * lerpf(14.0, 58.0, power) * (0.9 + 0.1 * acc2)
			var flat := target - ball.global_position
			flat.y = 0.0
			var d := flat.length()
			var s := sqrt(maxf(d, 3.0) * Ball.GRAVITY / sin(2.0 * theta)) * (1.04 + d * 0.0035)
			var d3 := flat.normalized().rotated(Vector3.UP, _rng.randfn(0.0, err2))
			vel = d3 * s * cos(theta) + Vector3.UP * s * sin(theta) * _rng.randf_range(0.96, 1.04)
			var r3 := d3.cross(Vector3.UP).normalized()
			spin = r3 * 22.0 - Vector3.UP * curl * 20.0
		"shot":
			var res := _compute_shot(power, dir, true)
			vel = res[0]
			spin = res[1] - Vector3.UP * curl * 38.0 * (0.5 + 0.5 * attr("curl"))
			if human:
				InputHub.vibrate(45)
	ball.position.y = maxf(ball.position.y, Ball.RADIUS)
	ball.kick(vel, spin, self)
	ball.intended_receiver = _kick["receiver"]
	ball.shot_by = self if kind == "shot" else null
	has_ball = false
	kicked.emit(self, kind, power)


## Velocidad inicial para que un pase raso llegue al punto con cierta velocidad.
func _ground_velocity_to(point: Vector3, arrive: float) -> Vector3:
	var flat: Vector3 = point - ball.global_position
	flat.y = 0.0
	var d := flat.length()
	var v0 := sqrt(arrive * arrive + 2.0 * 1.6 * d)
	for i in 2:
		var avg := (v0 + arrive) * 0.5
		v0 = sqrt(arrive * arrive + 2.0 * (ball.rolling_decel + 0.06 * avg) * d)
	return flat.normalized() * minf(v0, 30.0)


## Devuelve [velocidad, giro] de un tiro dirigido a la portería rival.
func _compute_shot(power: float, dir: Vector3, has_dir: bool) -> Array:
	var side: int = team.side if team != null else 1
	var gx := PitchDims.HALF_LENGTH * side
	var from := ball.global_position
	var dx := gx - from.x
	var aim_z := 0.0
	var assisted := absf(dx) < 45.0 and dx * side > 0.0
	if assisted and has_dir and absf(dir.x) > 0.05 and dir.x * side > 0.0:
		var z_int := from.z + dir.z / dir.x * dx
		if absf(z_int) > 25.0:
			assisted = false
		aim_z = clampf(z_int, -3.3, 3.3)
	elif assisted:
		aim_z = _rng.randf_range(-2.8, 2.8)
	var spd := lerpf(15.0, 31.0, power) * (0.82 + 0.18 * attr("shot_power"))
	var accuracy := attr("shot_accuracy")
	var fatigue := 1.0 - stamina
	var sigma := (0.012 + (1.0 - accuracy) * 0.06 + fatigue * 0.03 + clampf(speed / 9.0, 0.0, 1.0) * 0.02 + pow(power, 3.0) * 0.035) * error_mult
	if not assisted:
		var v0 := dir * spd + Vector3.UP * lerpf(1.0, 6.0, power)
		return [v0, -dir.cross(Vector3.UP) * 20.0]
	var target := Vector3(gx, 0, aim_z)
	var flat := target - Vector3(from.x, 0, from.z)
	var d := flat.length()
	var h := lerpf(0.25, 2.1, power)
	if power > 0.9:
		h += (power - 0.9) * 22.0 * (1.2 - accuracy)
	var t := d / spd
	var vy := (h - from.y) / t + 0.5 * Ball.GRAVITY * t
	vy *= 1.06
	var hdir := flat / d
	hdir = hdir.rotated(Vector3.UP, _rng.randfn(0.0, sigma))
	vy += _rng.randfn(0.0, sigma * spd * 0.5)
	var v := hdir * spd + Vector3.UP * vy
	var right := hdir.cross(Vector3.UP).normalized()
	return [v, -right * lerpf(5.0, 25.0, power)]


# ------------------------------------------------------------- Regates

func request_trick(input: Vector3) -> void:
	if state != State.MOVE or not has_ball:
		return
	var ang := 0.0
	if input.length() > 0.3:
		ang = heading.signed_angle_to(input.normalized(), Vector3.UP)
	_set_state(State.TRICK)
	_trick_done = false
	if absf(ang) > deg_to_rad(50.0):
		_trick_kind = "cut"
		_trick_side = signf(ang)
		model.play("trick_cut")
		if human:
			action_message.emit(Lang.t("trick_cut"))
	else:
		_trick_kind = "stepover"
		_trick_side = signf(ang) if absf(ang) > 0.1 else (1.0 if _rng.randf() > 0.5 else -1.0)
		model.play("trick_stepover")
		if human:
			action_message.emit(Lang.t("trick_stepover"))


func _trick(dt: float, input: Vector3) -> void:
	var drib := attr("dribbling")
	if _trick_kind == "cut":
		if not _trick_done:
			_trick_done = true
			var nd := input.normalized() if input.length() > 0.3 else heading.rotated(Vector3.UP, _trick_side * PI * 0.5)
			heading = nd
			speed *= 0.55 + 0.15 * drib
		if state_t > 0.28:
			_set_state(State.MOVE)
			if has_ball:
				ball.velocity = heading * (speed + 1.5)
				ball.velocity.y = 0.0
	else:
		_brake(dt, 4.0)
		if not _trick_done and state_t > 0.42:
			_trick_done = true
			heading = heading.rotated(Vector3.UP, _trick_side * deg_to_rad(32.0)).normalized()
			speed = minf(speed + 2.0 + 1.5 * drib, top_speed(true))
		if state_t > 0.55:
			_set_state(State.MOVE)
			if has_ball:
				ball.velocity = heading * (speed + 1.2)
				ball.velocity.y = 0.0
	_touch_timer = 0.3


# ------------------------------------------------- Entradas y barridas

func request_slide() -> void:
	if state != State.MOVE:
		return
	_set_state(State.SLIDE)
	_slide_hit = false
	speed = maxf(speed + 2.0, 7.0)
	model.play("slide")
	_dust.emitting = true


func _slide(dt: float) -> void:
	_brake(dt, 7.5)
	if not _slide_hit and state_t < 0.6:
		var foot := global_position + heading * 0.9
		var d := ball.global_position - foot
		d.y = 0.0
		if d.length() < 0.85 and ball.position.y < 0.6 and ball.held_by == null:
			_slide_hit = true
			var carrier := ball.owner_player as FootballPlayer
			var lateral := heading.cross(Vector3.UP) * _rng.randf_range(-3.0, 3.0)
			ball.kick(heading * (speed + 3.0) + lateral + Vector3(0, 1.0, 0), Vector3.ZERO, self)
			if carrier != null and carrier != self:
				carrier.stumble()
				tackled.emit(self, carrier)
		elif opponents != null:
			# Llega tarde: derriba al rival (las faltas se pitan en la Fase 3)
			for o in opponents.players:
				if o.has_ball and o.global_position.distance_to(foot) < 0.7:
					_slide_hit = true
					o.stumble()
	if state_t > 0.45:
		_dust.emitting = false
	if state_t > 1.0:
		_set_state(State.MOVE)


## Entrada de pie a un rival con balón cercano.
func request_tackle(target: FootballPlayer) -> void:
	if state != State.MOVE or tackle_cooldown > 0.0 or target == null:
		return
	_set_state(State.TACKLE)
	_tackle_target = target
	_tackle_done = false
	tackle_cooldown = 0.9
	model.play("tackle")


func _tackle(dt: float) -> void:
	_brake(dt, 6.0)
	if _tackle_target != null:
		_turn_towards(_tackle_target.global_position, dt, 10.0)
	if not _tackle_done and state_t > 0.15:
		_tackle_done = true
		var c := _tackle_target
		if c != null and c.has_ball and c.global_position.distance_to(global_position) < 1.5:
			var p := 0.3 + (attr("defense") - c.attr("dribbling")) * 0.8 + (attr("physical") - c.attr("physical")) * 0.25
			p = clampf(p, 0.1, 0.88)
			if _rng.randf() < p:
				c.has_ball = false
				ball.owner_player = null
				var away := (global_position - c.global_position).normalized()
				ball.kick(away.rotated(Vector3.UP, _rng.randf_range(-0.8, 0.8)) * _rng.randf_range(2.5, 5.0), Vector3.ZERO, self)
				ball.claim_block_time = 0.0
				c.stumble()
				tackled.emit(self, c)
				if Engine.has_meta("debug"):
					print("    entrada ", name, " roba a ", c.name, " x=%.0f" % (c.position.x * c.team.side))
			else:
				stumble(0.35)
	if state_t > 0.4 and state == State.TACKLE:
		_set_state(State.MOVE)


func stumble(_t := 0.75) -> void:
	if state == State.HOLD or state == State.DIVE:
		return
	has_ball = false
	_set_state(State.STUMBLE)
	model.play("stumble")


# ------------------------------------------------------------- Portero

func catch_ball() -> void:
	ball.held_by = self
	ball.owner_player = null
	ball.velocity = Vector3.ZERO
	ball.last_touch = self
	ball.intended_receiver = null
	has_ball = false
	_hold_time = 0.0
	_set_state(State.HOLD)
	model.play("gk_hold")


func hand_position() -> Vector3:
	return global_position + heading * 0.35 + Vector3(0, 1.05, 0)


## Estirada hacia un punto (sobre la línea de gol) que se espera que alcance el balón.
func request_dive(target: Vector3, time_left: float) -> void:
	if not (state in [State.MOVE]):
		return
	var to := target - global_position
	to.y = 0.0
	var reach := 1.1 + 2.0 * attr("reflexes")
	var lateral := to.limit_length(reach)
	var dur := clampf(time_left, 0.25, 0.6)
	_dive_vel = lateral / dur
	_dive_done = false
	var right := heading.cross(Vector3.UP)
	model.anim_dive_side = 1.0 if lateral.dot(right) > 0.0 else -1.0
	model.anim_dive_high = clampf((target.y - 0.4) / 1.8, 0.0, 1.0)
	_set_state(State.DIVE)
	model.play("dive")


func _dive(dt: float) -> void:
	if state_t > 0.55:
		_dive_vel = _dive_vel.move_toward(Vector3.ZERO, 12.0 * dt)
	if not _dive_done:
		var high := model.anim_dive_high
		var body := global_position + Vector3(0, lerpf(0.35, 1.6, high), 0)
		var d := ball.global_position.distance_to(body)
		var reach := 0.75 + 0.45 * attr("reflexes")
		if d < reach and ball.held_by == null:
			_dive_done = true
			var spd := ball.velocity.length()
			var catch_p := clampf(0.85 - spd * 0.025 + attr("reflexes") * 0.3, 0.05, 0.9)
			if _rng.randf() < catch_p:
				catch_ball()
				saved.emit(self, true)
			else:
				_parry(0.6)
				saved.emit(self, false)
	if state_t > 0.9:
		_set_state(State.LYING if ball.held_by != self else State.HOLD)


func _parry(strength: float) -> void:
	var out := Vector3(float(team.side), 0, 0)
	var lateral := Vector3(0, 0, signf(ball.position.z + 0.001))
	var spd := ball.velocity.length() * 0.35 * strength + 3.0
	ball.kick((out * 0.7 + lateral * _rng.randf_range(0.4, 1.0)).normalized() * spd + Vector3.UP * _rng.randf_range(1.0, 4.0), Vector3.ZERO, self)
	ball.claim_block_time = 0.5


func celebrate() -> void:
	charging_action = ""
	has_ball = false
	_set_state(State.CELEBRATE)
	model.play("celebrate")


func lament() -> void:
	_set_state(State.CELEBRATE)
	model.play("lament")


func reset_at(pos: Vector3, dir: Vector3) -> void:
	position = pos
	heading = dir.normalized()
	speed = 0.0
	has_ball = false
	charging_action = ""
	move_intent = Vector3.ZERO
	_set_state(State.MOVE)
