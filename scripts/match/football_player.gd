class_name FootballPlayer
extends Node3D
## Jugador de campo controlable. Movimiento cinemático con inercia (velocidad y
## rumbo separados), conducción por toques, pases, tiros con carga, regates y barrida.
## Todas las acciones dependen de las valoraciones del jugador (0-99).

signal action_message(text: String)
signal shot_fired(power: float)

enum State { MOVE, KICK, SLIDE, TRICK, STUMBLE, CELEBRATE }

const CHARGE_TIME_SHOT := 1.0
const CHARGE_TIME_PASS := 0.75
const ARENA_X := 58.0
const ARENA_Z := 38.0

## Datos del jugador (normalmente vienen de data/*.json en fases posteriores).
var data: Dictionary = {
	"name": "Ramírez", "number": 10, "foot": "right", "height": 178,
	"speed": 84, "acceleration": 86, "shot_accuracy": 82, "shot_power": 80,
	"short_pass": 81, "long_pass": 76, "dribbling": 85, "ball_control": 84,
	"defense": 45, "heading": 62, "physical": 68, "stamina": 82, "curl": 80, "agility": 84,
}

var ball: Ball
var cam: Camera3D
var human := true
var attack_side := 1

var velocity := Vector3.ZERO
var heading := Vector3(1, 0, 0)
var speed := 0.0
var stamina := 1.0            # energía actual 0..1
var state := State.MOVE
var state_t := 0.0
var has_ball := false
var charge := 0.0
var charging_action := ""

var model: PlayerModel
var _shadow: MeshInstance3D
var _dust: CPUParticles3D
var _touch_timer := 0.0
var _kick := {}
var _kick_done := false
var _trick_kind := ""
var _trick_side := 1.0
var _trick_done := false
var _slide_hit := false
var _last_input := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	model = PlayerModel.new()
	model.number = int(data.get("number", 10))
	model.shirt_name = str(data.get("name", ""))
	model.height_m = float(data.get("height", 180)) / 100.0
	add_child(model)
	model.build_model()
	_shadow = Ball.make_blob_shadow(1.1)
	add_child(_shadow)
	set_shadows(GameSettings.shadows_enabled())
	_dust = _make_dust()
	add_child(_dust)
	InputHub.swipe.connect(_on_swipe)


## Sombras dinámicas en Alta; sombra circular barata en Baja/Media.
func set_shadows(on: bool) -> void:
	model.set_shadows(on)
	_shadow.visible = not on


func attr(key: String) -> float:
	return float(data.get(key, 70)) / 99.0


func _make_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 24
	p.lifetime = 0.7
	p.one_shot = false
	p.explosiveness = 0.0
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
	var input := _read_input() if human else Vector3.ZERO
	var prev_speed := speed
	_handle_actions(input, dt)
	match state:
		State.MOVE:
			_locomotion(input, dt)
		State.KICK:
			_brake(dt, 9.0)
			if not _kick_done and state_t >= float(_kick["contact"]):
				_execute_kick()
			if state_t >= 0.45:
				_set_state(State.MOVE)
		State.SLIDE:
			_slide(dt)
		State.TRICK:
			_trick(dt, input)
		State.STUMBLE:
			_brake(dt, 6.0)
			if state_t > 0.7:
				_set_state(State.MOVE)
		State.CELEBRATE:
			_brake(dt, 5.0)
	velocity = heading * speed
	position += velocity * dt
	position.y = 0.0
	position.x = clampf(position.x, -ARENA_X, ARENA_X)
	position.z = clampf(position.z, -ARENA_Z, ARENA_Z)
	basis = Basis.looking_at(heading, Vector3.UP)
	_update_stamina(dt)
	_update_ball(dt)
	if human:
		InputHub.set_context(has_ball or _ball_close(1.3))
	# Datos para la animación procedural
	model.anim_speed = speed
	model.anim_sprint = Input.is_action_pressed("act_sprint") and human and speed > 6.0
	model.anim_accel = (speed - prev_speed) / maxf(dt, 0.0001)
	_shadow.global_position = global_position + Vector3(0, 0.012, 0)


func _set_state(s: State) -> void:
	state = s
	state_t = 0.0
	_dust.emitting = false
	if s == State.MOVE:
		model.play("move")


func _read_input() -> Vector3:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.15)
	if cam == null:
		return Vector3(v.x, 0, v.y)
	var f := -cam.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var r := cam.global_basis.x
	r.y = 0.0
	r = r.normalized()
	var d := r * v.x + f * (-v.y)
	if d.length() > 1.0:
		d = d.normalized()
	return d


func screen_dir_to_world(sd: Vector2) -> Vector3:
	if cam == null:
		return Vector3(sd.x, 0, sd.y).normalized()
	var f := -cam.global_basis.z
	f.y = 0.0
	var r := cam.global_basis.x
	r.y = 0.0
	return (r.normalized() * sd.x + f.normalized() * (-sd.y)).normalized()


# ------------------------------------------------------------- Acciones

func _ball_close(d: float) -> bool:
	if ball == null:
		return false
	var to := ball.global_position - global_position
	to.y = 0.0
	return to.length() < d and ball.position.y < 1.2


func _handle_actions(input: Vector3, dt: float) -> void:
	if not human or state == State.CELEBRATE:
		return
	if input.length() > 0.2:
		_last_input = input.normalized()
	var with_ball := has_ball or _ball_close(1.3)
	# Inicio de carga de golpeo
	for a in ["act_shoot", "act_pass", "act_lob", "act_through"]:
		if Input.is_action_just_pressed(a):
			if with_ball and state in [State.MOVE, State.TRICK]:
				charging_action = a
				charge = 0.0
				InputHub.curl = 0.0
			elif not with_ball:
				_defensive_action(a)
	if charging_action != "":
		var ct := CHARGE_TIME_SHOT if charging_action == "act_shoot" else CHARGE_TIME_PASS
		charge = minf(charge + dt / ct, 1.0)
		if not Input.is_action_pressed(charging_action):
			var kind: String = {"act_shoot": "shot", "act_pass": "pass", "act_lob": "lob", "act_through": "through"}[charging_action]
			var dir := input.normalized() if input.length() > 0.2 else heading
			if _ball_close(1.6) and state in [State.MOVE, State.TRICK]:
				_start_kick(kind, maxf(charge, 0.08), dir, input.length() > 0.2)
			charging_action = ""
			charge = 0.0
	if Input.is_action_just_pressed("act_trick"):
		if with_ball and state == State.MOVE:
			_start_trick(input)
		elif not with_ball:
			action_message.emit(Lang.t("not_available_phase1"))


func _defensive_action(a: String) -> void:
	match a:
		"act_shoot":
			if state == State.MOVE:
				_start_slide()
		"act_through":
			action_message.emit(Lang.t("not_available_phase1"))
		_:
			pass  # Presión / doble presión se resuelven en la locomoción mientras se mantienen


func _on_swipe(screen_dir: Vector2, strength: float) -> void:
	if not human or state != State.MOVE:
		return
	if has_ball or _ball_close(1.3):
		_start_kick("through", clampf(strength, 0.2, 1.0), screen_dir_to_world(screen_dir), true)


# ----------------------------------------------------------- Movimiento

func _top_speed(sprint: bool) -> float:
	var spd := attr("speed")
	var top := (6.6 + spd * 2.7) if sprint else (4.6 + spd * 1.0)
	if has_ball:
		top *= 0.9 + 0.07 * attr("dribbling")
	top *= lerpf(0.8, 1.0, clampf(stamina * 1.6, 0.0, 1.0))
	return top


func _locomotion(input: Vector3, dt: float) -> void:
	var pressing := not has_ball and human and (Input.is_action_pressed("act_pass") or Input.is_action_pressed("act_lob"))
	if pressing and ball != null:
		var to := ball.global_position - global_position
		to.y = 0.0
		if to.length() > 0.4:
			input = to.normalized()
	var sprint := human and Input.is_action_pressed("act_sprint") and stamina > 0.03
	var mag := minf(input.length(), 1.0)
	var target := mag * _top_speed(sprint)
	model.anim_turn = 0.0
	if mag > 0.12:
		var desired := input / maxf(input.length(), 0.0001)
		var ang := heading.signed_angle_to(desired, Vector3.UP)
		var t := clampf(speed / 9.0, 0.0, 1.0)
		var turn_rate := lerpf(13.0, 3.0 + 3.0 * attr("agility"), t)
		if has_ball:
			turn_rate *= 0.7 + 0.4 * attr("dribbling")
		var step := clampf(ang, -turn_rate * dt, turn_rate * dt)
		heading = heading.rotated(Vector3.UP, step).normalized()
		model.anim_turn = step / maxf(dt, 0.0001)
		# Giro brusco a alta velocidad = frenada
		var align := cos(absf(ang))
		target *= clampf(0.3 + 0.7 * maxf(align, 0.0), 0.0, 1.0)
	var acc := 0.0
	if target > speed:
		acc = 4.0 + 7.5 * attr("acceleration")
	else:
		acc = 11.0 + 4.0 * attr("agility")
	speed = move_toward(speed, target, acc * dt)


func _brake(dt: float, decel: float) -> void:
	speed = move_toward(speed, 0.0, decel * dt)


func _update_stamina(dt: float) -> void:
	var sprinting := human and Input.is_action_pressed("act_sprint") and speed > 6.0
	if sprinting:
		stamina -= 0.05 * (1.35 - 0.6 * attr("stamina")) * dt
	elif speed > 5.0:
		stamina -= 0.004 * dt
	else:
		stamina += 0.035 * (0.6 + 0.4 * attr("stamina")) * dt
	stamina = clampf(stamina, 0.0, 1.0)


# --------------------------------------------------------- Conducción

func _update_ball(dt: float) -> void:
	if ball == null:
		return
	var to := ball.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if has_ball:
		if ball.owner_player != self or dist > 2.6 or ball.position.y > 1.3 or ball.dead:
			has_ball = false
			return
		if state in [State.KICK, State.SLIDE]:
			return
		if state == State.TRICK:
			# Durante el regate el balón queda pegado al pie
			var hold := global_position + heading * 0.55
			var corr := (hold - ball.global_position) * 10.0
			ball.velocity = Vector3(velocity.x + corr.x, 0.0, velocity.z + corr.z)
			return
		_touch_timer -= dt
		# Si el balón queda detrás por un giro, tocarlo antes
		if dist > 0.45 and heading.dot(to / maxf(dist, 0.001)) < 0.3:
			_touch_timer = minf(_touch_timer, 0.0)
		if _touch_timer <= 0.0 and dist < 1.6:
			_dribble_touch()
		return
	if state != State.MOVE and state != State.TRICK:
		return
	if not ball.can_be_claimed_by(self):
		return
	var ctrl := attr("ball_control")
	if dist < 0.7 + 0.25 * ctrl and ball.position.y < 0.9:
		var rel := ball.velocity - velocity
		rel.y = 0.0
		var max_rel := 9.0 + 14.0 * ctrl
		if rel.length() < max_rel:
			has_ball = true
			ball.owner_player = self
			ball.last_touch = self
			_touch_timer = 0.0
			_dribble_touch()
		else:
			# Control fallido: el balón rebota
			var n := -to.normalized()
			ball.velocity = ball.velocity.bounce(n) * 0.35 + Vector3(_rng.randf_range(-1, 1), 0.5, _rng.randf_range(-1, 1))
			ball.claim_block_time = 0.4
			ball.claim_block_by = self


func _dribble_touch() -> void:
	var t := clampf(speed / 9.0, 0.0, 1.0)
	var drib := attr("dribbling")
	var ctrl := attr("ball_control")
	var interval := lerpf(0.32, 0.58, t)
	# Conducción larga al esprintar, cerca al ir despacio
	var lead := lerpf(0.5, 1.7, t * t) * (1.15 - 0.3 * drib)
	var target := global_position + velocity * interval + heading * lead
	var v := (target - ball.global_position) / interval
	v.y = 0.0
	# Compensa el frenado por rodadura
	if v.length() > 0.01:
		v += v.normalized() * ball.rolling_decel * interval * 0.5
	# Error de control
	var err := (1.0 - ctrl) * 0.25 * t
	v = v.rotated(Vector3.UP, _rng.randfn(0.0, err))
	ball.velocity = v
	ball.position.y = Ball.RADIUS
	ball.spin = Vector3.ZERO
	ball.last_touch = self
	_touch_timer = interval
	model.anim_touch = 0.12


# ------------------------------------------------------------- Golpeos

func _start_kick(kind: String, power: float, dir: Vector3, has_dir: bool) -> void:
	_set_state(State.KICK)
	_kick = {"kind": kind, "power": power, "dir": dir.normalized(), "has_dir": has_dir,
		"contact": 0.2 if kind == "shot" else 0.15, "curl": InputHub.curl}
	_kick_done = false
	# Orientar el cuerpo hacia el golpeo
	heading = heading.slerp(dir.normalized(), 0.6).normalized()
	model.anim_kick_kind = kind
	model.play("kick")


func _execute_kick() -> void:
	_kick_done = true
	if not _ball_close(1.7):
		return  # golpeo al aire
	var kind: String = _kick["kind"]
	var power: float = _kick["power"]
	var dir: Vector3 = _kick["dir"]
	var curl: float = _kick["curl"]
	var right := dir.cross(Vector3.UP).normalized()
	var fatigue := 1.0 - stamina
	var moving := clampf(speed / 9.0, 0.0, 1.0)
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	match kind:
		"pass":
			var spd := lerpf(8.0, 23.0, power) * (0.92 + 0.08 * attr("short_pass"))
			var err := 0.01 + (1.0 - attr("short_pass")) * 0.07 + fatigue * 0.02 + moving * 0.015
			vel = dir.rotated(Vector3.UP, _rng.randfn(0.0, err)) * spd + Vector3(0, 0.4, 0)
			spin = -right * spd / Ball.RADIUS * 0.3
		"through":
			var spd2 := lerpf(12.0, 26.0, power) * (0.92 + 0.08 * attr("short_pass"))
			var err2 := 0.015 + (1.0 - attr("short_pass")) * 0.08 + fatigue * 0.02
			vel = dir.rotated(Vector3.UP, _rng.randfn(0.0, err2)) * spd2 + Vector3(0, 0.6, 0)
			spin = -right * spd2 / Ball.RADIUS * 0.3
		"lob":
			var dist := lerpf(14.0, 58.0, power) * (0.9 + 0.1 * attr("long_pass"))
			var theta := deg_to_rad(lerpf(24.0, 34.0, power))
			var s := sqrt(dist * Ball.GRAVITY / sin(2.0 * theta)) * 1.1
			var err3 := 0.012 + (1.0 - attr("long_pass")) * 0.07 + fatigue * 0.03
			var d3 := dir.rotated(Vector3.UP, _rng.randfn(0.0, err3))
			vel = d3 * s * cos(theta) + Vector3.UP * s * sin(theta) * _rng.randf_range(0.95, 1.05)
			spin = right * 25.0 - Vector3.UP * curl * 20.0
		"shot":
			var res := _compute_shot(power, dir, bool(_kick["has_dir"]))
			vel = res[0]
			spin = res[1] - Vector3.UP * curl * 38.0 * (0.5 + 0.5 * attr("curl"))
			shot_fired.emit(power)
			InputHub.vibrate(45)
	ball.position.y = maxf(ball.position.y, Ball.RADIUS)
	ball.kick(vel, spin, self)
	has_ball = false


## Devuelve [velocidad, giro] de un tiro dirigido a la portería.
func _compute_shot(power: float, dir: Vector3, has_dir: bool) -> Array:
	var side := attack_side
	if absf(dir.x) > 0.25:
		side = int(signf(dir.x))
	var gx := PitchDims.HALF_LENGTH * side
	var from := ball.global_position
	var dx := gx - from.x
	var aim_z := 0.0
	var assisted := absf(dx) < 45.0 and dx * side > 0.0
	if assisted and has_dir and absf(dir.x) > 0.05:
		var z_int := from.z + dir.z / dir.x * dx
		if absf(z_int) > 22.0:
			assisted = false
		aim_z = clampf(z_int, -3.3, 3.3)
	elif assisted:
		aim_z = _rng.randf_range(-2.0, 2.0)
	var spd := lerpf(15.0, 31.0, power) * (0.82 + 0.18 * attr("shot_power"))
	var accuracy := attr("shot_accuracy")
	var fatigue := 1.0 - stamina
	var sigma := 0.012 + (1.0 - accuracy) * 0.06 + fatigue * 0.03 + clampf(speed / 9.0, 0.0, 1.0) * 0.02 + pow(power, 3.0) * 0.035
	if not assisted:
		var v0 := dir * spd + Vector3.UP * lerpf(1.0, 6.0, power)
		return [v0, -dir.cross(Vector3.UP) * 20.0]
	var target := Vector3(gx, 0, aim_z)
	var flat := target - Vector3(from.x, 0, from.z)
	var d := flat.length()
	var h := lerpf(0.25, 2.1, power)
	if power > 0.9:
		h += (power - 0.9) * 22.0 * (1.2 - accuracy)  # demasiada potencia: se va alto
	var t := d / spd
	var vy := (h - from.y) / t + 0.5 * Ball.GRAVITY * t
	vy *= 1.06
	var hdir := flat / d
	hdir = hdir.rotated(Vector3.UP, _rng.randfn(0.0, sigma))
	vy += _rng.randfn(0.0, sigma * spd * 0.5)
	var v := hdir * spd + Vector3.UP * vy
	var right := hdir.cross(Vector3.UP).normalized()
	var topspin := -right * lerpf(5.0, 25.0, power)
	return [v, topspin]


# ------------------------------------------------------------- Regates

func _start_trick(input: Vector3) -> void:
	var ang := 0.0
	if input.length() > 0.3:
		ang = heading.signed_angle_to(input.normalized(), Vector3.UP)
	_set_state(State.TRICK)
	_trick_done = false
	if absf(ang) > deg_to_rad(50.0):
		_trick_kind = "cut"
		_trick_side = signf(ang)
		model.play("trick_cut")
		action_message.emit(Lang.t("trick_cut"))
	else:
		_trick_kind = "stepover"
		_trick_side = signf(ang) if absf(ang) > 0.1 else (1.0 if _rng.randf() > 0.5 else -1.0)
		model.play("trick_stepover")
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
			speed = minf(speed + 2.0 + 1.5 * drib, _top_speed(true))
		if state_t > 0.55:
			_set_state(State.MOVE)
			if has_ball:
				ball.velocity = heading * (speed + 1.2)
				ball.velocity.y = 0.0
	_touch_timer = 0.3


# ------------------------------------------------------------- Barrida

func _start_slide() -> void:
	_set_state(State.SLIDE)
	_slide_hit = false
	speed = maxf(speed + 2.0, 7.0)
	model.play("slide")
	_dust.emitting = true


func _slide(dt: float) -> void:
	_brake(dt, 7.5)
	if not _slide_hit and ball != null and state_t < 0.6:
		var foot := global_position + heading * 0.9
		var d := ball.global_position - foot
		d.y = 0.0
		if d.length() < 0.85 and ball.position.y < 0.6:
			_slide_hit = true
			var lateral := heading.cross(Vector3.UP) * _rng.randf_range(-3.0, 3.0)
			ball.kick(heading * (speed + 3.0) + lateral + Vector3(0, 1.0, 0), Vector3.ZERO, self)
	if state_t > 0.45:
		_dust.emitting = false
	if state_t > 1.0:
		_set_state(State.MOVE)


func celebrate() -> void:
	charging_action = ""
	has_ball = false
	_set_state(State.CELEBRATE)
	model.play("celebrate")


func reset_at(pos: Vector3, dir: Vector3) -> void:
	position = pos
	heading = dir.normalized()
	speed = 0.0
	has_ball = false
	charging_action = ""
	_set_state(State.MOVE)
