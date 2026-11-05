class_name Referee
extends Node3D
## Árbitro: sigue la jugada en diagonal manteniendo distancia, pita y muestra tarjetas.

var ball: Ball
var model: PlayerModel
var _speed := 0.0
var _heading := Vector3(0, 0, -1)
var _card_t := 0.0
var _card_mesh: MeshInstance3D


func _ready() -> void:
	model = PlayerModel.new()
	model.number = 0
	model.shirt_name = ""
	model.shirt_color = Color(0.08, 0.08, 0.08)
	model.shirt_color2 = Color(0.9, 0.9, 0.9)
	model.shorts_color = Color(0.08, 0.08, 0.08)
	model.socks_color = Color(0.08, 0.08, 0.08)
	model.skin_color = Color(0.85, 0.65, 0.5)
	model.hair_style = 0
	model.detail = mini(GameSettings.quality, 1)
	add_child(model)
	model.build_model()
	model.set_shadows(GameSettings.shadows_enabled())
	var q := BoxMesh.new()
	q.size = Vector3(0.07, 0.1, 0.01)
	_card_mesh = MeshInstance3D.new()
	_card_mesh.mesh = q
	_card_mesh.visible = false
	add_child(_card_mesh)


func show_card(red: bool) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.05, 0.05) if red else Color(1.0, 0.85, 0.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_card_mesh.material_override = m
	_card_mesh.visible = true
	_card_t = 1.8
	model.play("card")
	Audio.whistle(false)


func _physics_process(dt: float) -> void:
	if ball == null:
		return
	if _card_t > 0.0:
		_card_t -= dt
		_card_mesh.position = Vector3(0.22, 2.12, 0.0)
		if _card_t <= 0.0:
			_card_mesh.visible = false
			model.play("move")
		_speed = move_toward(_speed, 0.0, 8.0 * dt)
	else:
		var bp := ball.global_position
		var target := bp + Vector3(-signf(bp.x + 0.01) * 9.0, 0, -signf(bp.z + 0.01) * 7.0)
		target.y = 0.0
		target.x = clampf(target.x, -50.0, 50.0)
		target.z = clampf(target.z, -32.0, 32.0)
		var to := target - global_position
		to.y = 0.0
		var d := to.length()
		var want := clampf(d * 0.6, 0.0, 7.0)
		_speed = move_toward(_speed, want, 5.0 * dt)
		if d > 0.5:
			_heading = _heading.slerp(to / d, minf(1.0, 4.0 * dt)).normalized()
		elif true:
			var tb := bp - global_position
			tb.y = 0.0
			if tb.length() > 0.1:
				_heading = _heading.slerp(tb.normalized(), minf(1.0, 3.0 * dt)).normalized()
	position += _heading * _speed * dt
	position.y = 0.0
	basis = Basis.looking_at(_heading, Vector3.UP)
	model.anim_speed = _speed
