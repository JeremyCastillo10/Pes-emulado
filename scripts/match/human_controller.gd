class_name HumanController
extends Node
## Control humano de un equipo. device = -1: táctil + teclado + mandos (acciones globales);
## device >= 0: un mando concreto (modo 2 jugadores en el mismo teléfono).
## Combinaciones: mantener Largo + Tiro = globo; mantener Regate + Tiro = tiro colocado.
## Con el balón en el aire cerca: Tiro/Pase = remate de primera (cabezazo, volea o chilena).

signal switched(p: FootballPlayer)
signal message(text: String)

const CHARGE_TIME_SHOT := 1.0
const CHARGE_TIME_PASS := 0.75
const ACTIONS := ["act_pass", "act_shoot", "act_lob", "act_through", "act_trick", "act_sprint"]
const JOY := {"act_pass": JOY_BUTTON_A, "act_shoot": JOY_BUTTON_B, "act_lob": JOY_BUTTON_X,
	"act_through": JOY_BUTTON_Y, "act_trick": JOY_BUTTON_LEFT_SHOULDER, "act_sprint": JOY_BUTTON_RIGHT_SHOULDER}

var team: Team
var cam: Camera3D
var ball: Ball
var enabled := true
var device := -1
var locked: FootballPlayer = null     # modo Ser una Leyenda
var _last_owner: Node = null
var _switch_cooldown := 0.0
var _cur := {}
var _prev := {}
var _trick_held := false
var _trick_used := false
var _style := ""


func _ready() -> void:
	process_physics_priority = -20
	if device < 0:
		InputHub.swipe.connect(_on_swipe)


func set_controlled(p: FootballPlayer) -> void:
	if p == null or p.is_gk or p == team.controlled or not p.active:
		return
	if locked != null and p != locked:
		return
	if team.controlled != null:
		team.controlled.set_controlled(false)
		team.controlled.move_intent = Vector3.ZERO
		team.controlled.sprint_intent = false
	team.controlled = p
	p.set_controlled(true)
	_switch_cooldown = 0.25
	switched.emit(p)


# ---------------------------------------------------------- Entrada

func _poll() -> void:
	for a in ACTIONS:
		_prev[a] = _cur.get(a, false)
		if device < 0:
			_cur[a] = Input.is_action_pressed(a)
		else:
			var pressed := Input.is_joy_button_pressed(device, JOY[a])
			if a == "act_sprint":
				pressed = pressed or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.5
			_cur[a] = pressed


func pressed(a: String) -> bool:
	return _cur.get(a, false)


func just_pressed(a: String) -> bool:
	return _cur.get(a, false) and not _prev.get(a, false)


func just_released(a: String) -> bool:
	return not _cur.get(a, false) and _prev.get(a, false)


func read_move() -> Vector3:
	var v := Vector2.ZERO
	if device < 0:
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.15)
	else:
		v = Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if v.length() < 0.2:
			v = Vector2.ZERO
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT): v.x = -1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT): v.x = 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP): v.y = -1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN): v.y = 1.0
	if cam == null:
		return Vector3(v.x, 0, v.y)
	var f := -cam.global_basis.z
	f.y = 0.0
	var r := cam.global_basis.x
	r.y = 0.0
	var d := r.normalized() * v.x + f.normalized() * (-v.y)
	return d.limit_length(1.0)


func screen_dir_to_world(sd: Vector2) -> Vector3:
	var f := -cam.global_basis.z
	f.y = 0.0
	var r := cam.global_basis.x
	r.y = 0.0
	return (r.normalized() * sd.x + f.normalized() * (-sd.y)).normalized()


# ----------------------------------------------------------- Bucle

func _physics_process(dt: float) -> void:
	if team == null or not enabled:
		return
	_poll()
	_switch_cooldown = maxf(_switch_cooldown - dt, 0.0)
	if locked == null:
		_auto_switch()
	elif team.controlled != locked and locked.active:
		set_controlled(locked)
	var p := team.controlled
	if p == null or not p.active:
		return
	var input := read_move()
	var airborne_near := ball.position.y > 0.5 and p._ball_reachable() and ball.owner_player == null and ball.held_by == null
	var with_ball := p.has_ball or p.ball_close(1.3) or airborne_near
	if device < 0:
		InputHub.set_context(with_ball)
	team.double_press = false
	team.keeper_rush = false
	p.sprint_intent = pressed("act_sprint")
	p.face_point = null
	if p.state == FootballPlayer.State.FROZEN and input.length() > 0.2:
		p.face_point = p.global_position + input * 5.0
	# Regate / Cambiar: el regate se ejecuta al soltar (si no se usó para tiro colocado)
	if just_pressed("act_trick"):
		if with_ball:
			_trick_held = true
			_trick_used = false
		elif locked == null:
			set_controlled(team.nearest_to(ball.global_position, false, p))
			return
	if just_released("act_trick") and _trick_held:
		_trick_held = false
		if not _trick_used and p.has_ball:
			p.request_trick(input)
	# Remate de primera con el balón en el aire
	if airborne_near and not p.has_ball:
		for a in ["act_shoot", "act_pass", "act_lob"]:
			if just_pressed(a):
				var kind: String = {"act_shoot": "shot", "act_pass": "pass", "act_lob": "lob"}[a]
				var dir := input.normalized() if input.length() > 0.2 else (team.target_goal() - p.global_position).normalized()
				_kick(p, kind, 0.65, dir)
				return
	# Inicio de carga
	for a in ["act_shoot", "act_pass", "act_lob", "act_through"]:
		if just_pressed(a):
			if with_ball and p.can_act():
				_style = ""
				if a == "act_shoot" and pressed("act_lob"):
					_style = "chip"
				elif a == "act_shoot" and _trick_held:
					_style = "finesse"
					_trick_used = true
				p.charging_action = a
				p.charge = 0.0
				InputHub.curl = 0.0
			elif not with_ball and a == "act_shoot":
				p.request_slide()
	if p.charging_action != "":
		var ct := CHARGE_TIME_SHOT if p.charging_action == "act_shoot" else CHARGE_TIME_PASS
		p.charge = minf(p.charge + dt / ct, 1.0)
		if not pressed(p.charging_action):
			var kind: String = {"act_shoot": "shot", "act_pass": "pass", "act_lob": "lob", "act_through": "through"}[p.charging_action]
			var dir := input.normalized() if input.length() > 0.2 else p.heading
			_kick(p, kind, maxf(p.charge, 0.08), dir, _style)
			p.charging_action = ""
			p.charge = 0.0
			_style = ""
	# Presión, doble presión, carga y salida del portero
	if not with_ball and p.state == FootballPlayer.State.MOVE:
		var opp_c := team.opponent.carrier()
		if pressed("act_pass") or pressed("act_lob"):
			var tgt := ball.global_position
			if opp_c != null:
				var gs := (team.own_goal() - opp_c.global_position).normalized()
				tgt = opp_c.global_position + gs * 0.8
				var dist := p.global_position.distance_to(opp_c.global_position)
				var side_by_side := absf(p.heading.dot(opp_c.heading)) > 0.6 and absf((p.global_position - opp_c.global_position).normalized().dot(opp_c.heading)) < 0.5
				if dist < 1.2 and side_by_side:
					p.request_charge(opp_c)
				elif dist < 1.4:
					p.request_tackle(opp_c)
			var to := tgt - p.global_position
			to.y = 0.0
			if to.length() > 0.3:
				input = to.normalized()
			team.double_press = pressed("act_lob")
		team.keeper_rush = pressed("act_through")
	p.move_intent = input


func _kick(p: FootballPlayer, kind: String, power: float, dir: Vector3, style := "") -> void:
	if kind == "shot":
		p.request_kick("shot", power, dir, null, null, style)
		return
	var opt := team.find_pass_target(p, dir, kind, power)
	if opt.is_empty():
		p.request_kick(kind, power, dir)
	else:
		var pt: Vector3 = opt["point"]
		p.request_kick(kind, power, (pt - p.global_position).normalized(), opt["player"], pt)


func _on_swipe(screen_dir: Vector2, strength: float) -> void:
	var p := team.controlled if team != null else null
	if p == null or not p.can_act() or not enabled:
		return
	if p.has_ball or p.ball_close(1.3):
		_kick(p, "through", clampf(strength, 0.2, 1.0), screen_dir_to_world(screen_dir))


## Cambio automático: al recibir un compañero, al perder el balón, en pases.
func _auto_switch() -> void:
	var owner: Node = ball.owner_player
	if owner != _last_owner:
		_last_owner = owner
		if owner != null and team.players.has(owner) and owner != team.controlled:
			set_controlled(owner)
			return
		if owner != null and not team.players.has(owner):
			var n := team.nearest_to(ball.global_position, false)
			if n != team.controlled and _switch_cooldown <= 0.0:
				set_controlled(n)
			return
	var r := ball.intended_receiver as FootballPlayer
	if owner == null and r != null and team.players.has(r) and r != team.controlled and not r.is_gk:
		set_controlled(r)
		return
	if owner == null and ball.held_by == null and team.controlled != null and _switch_cooldown <= 0.0:
		var n2 := team.nearest_to(ball.global_position, false)
		if n2 != null and n2 != team.controlled and team.controlled.global_position.distance_to(ball.global_position) > n2.global_position.distance_to(ball.global_position) + 12.0:
			set_controlled(n2)
