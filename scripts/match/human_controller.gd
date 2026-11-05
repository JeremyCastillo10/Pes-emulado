class_name HumanController
extends Node
## Control humano de un equipo: lee joystick/botones/mando (acciones de InputHub),
## gestiona la carga de golpeos, la asistencia de pase, el cambio de jugador y los gestos.

signal switched(p: FootballPlayer)
signal message(text: String)

const CHARGE_TIME_SHOT := 1.0
const CHARGE_TIME_PASS := 0.75

var team: Team
var cam: Camera3D
var ball: Ball
var enabled := true
var _last_owner: Node = null
var _switch_cooldown := 0.0


func _ready() -> void:
	process_physics_priority = -20
	InputHub.swipe.connect(_on_swipe)


func set_controlled(p: FootballPlayer) -> void:
	if p == null or p.is_gk or p == team.controlled:
		return
	if team.controlled != null:
		team.controlled.set_controlled(false)
		team.controlled.move_intent = Vector3.ZERO
		team.controlled.sprint_intent = false
	team.controlled = p
	p.set_controlled(true)
	_switch_cooldown = 0.25
	switched.emit(p)


func read_move() -> Vector3:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.15)
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


func _physics_process(dt: float) -> void:
	if team == null or not enabled:
		return
	_switch_cooldown = maxf(_switch_cooldown - dt, 0.0)
	_auto_switch()
	var p := team.controlled
	if p == null:
		return
	var input := read_move()
	var with_ball := p.has_ball or p.ball_close(1.3)
	InputHub.set_context(with_ball)
	team.double_press = false
	team.keeper_rush = false
	p.sprint_intent = Input.is_action_pressed("act_sprint")
	p.face_point = null
	# Saque (jugador congelado): el joystick apunta
	if p.state == FootballPlayer.State.FROZEN:
		if input.length() > 0.2:
			p.face_point = p.global_position + input * 5.0
	# Inicio de carga
	for a in ["act_shoot", "act_pass", "act_lob", "act_through"]:
		if Input.is_action_just_pressed(a):
			if with_ball and p.can_act():
				p.charging_action = a
				p.charge = 0.0
				InputHub.curl = 0.0
			elif not with_ball and a == "act_shoot":
				p.request_slide()
	if p.charging_action != "":
		var ct := CHARGE_TIME_SHOT if p.charging_action == "act_shoot" else CHARGE_TIME_PASS
		p.charge = minf(p.charge + dt / ct, 1.0)
		if not Input.is_action_pressed(p.charging_action):
			var kind: String = {"act_shoot": "shot", "act_pass": "pass", "act_lob": "lob", "act_through": "through"}[p.charging_action]
			var dir := input.normalized() if input.length() > 0.2 else p.heading
			_kick(p, kind, maxf(p.charge, 0.08), dir)
			p.charging_action = ""
			p.charge = 0.0
	if Input.is_action_just_pressed("act_trick"):
		if with_ball:
			p.request_trick(input)
		else:
			var n := team.nearest_to(ball.global_position, false, p)
			set_controlled(n)
			return
	# Movimiento / presión
	if not with_ball and p.state == FootballPlayer.State.MOVE:
		var opp_c := team.opponent.carrier()
		if Input.is_action_pressed("act_pass") or Input.is_action_pressed("act_lob"):
			var tgt := ball.global_position
			if opp_c != null:
				var gs := (team.own_goal() - opp_c.global_position).normalized()
				tgt = opp_c.global_position + gs * 0.8
				if p.global_position.distance_to(opp_c.global_position) < 1.4:
					p.request_tackle(opp_c)
			var to := tgt - p.global_position
			to.y = 0.0
			if to.length() > 0.3:
				input = to.normalized()
			team.double_press = Input.is_action_pressed("act_lob")
		team.keeper_rush = Input.is_action_pressed("act_through")
	p.move_intent = input


func _kick(p: FootballPlayer, kind: String, power: float, dir: Vector3) -> void:
	if kind == "shot":
		p.request_kick("shot", power, dir)
		return
	var opt := team.find_pass_target(p, dir, kind, power)
	if opt.is_empty():
		p.request_kick(kind, power, dir)
	else:
		var pt: Vector3 = opt["point"]
		p.request_kick(kind, power, (pt - p.global_position).normalized(), opt["player"], pt)


func _on_swipe(screen_dir: Vector2, strength: float) -> void:
	var p := team.controlled if team != null else null
	if p == null or not p.can_act():
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
	# Pase en vuelo hacia un compañero
	var r := ball.intended_receiver as FootballPlayer
	if owner == null and r != null and team.players.has(r) and r != team.controlled and not r.is_gk:
		set_controlled(r)
		return
	# Balón suelto muy lejos del controlado
	if owner == null and ball.held_by == null and team.controlled != null and _switch_cooldown <= 0.0:
		var n2 := team.nearest_to(ball.global_position, false)
		if n2 != team.controlled and team.controlled.global_position.distance_to(ball.global_position) > n2.global_position.distance_to(ball.global_position) + 12.0:
			set_controlled(n2)
