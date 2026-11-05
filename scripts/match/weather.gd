class_name Weather
extends Node3D
## Lluvia: partículas que siguen a la cámara (cantidad según la calidad) y ambiente húmedo.

var cam: Camera3D
var _rain: CPUParticles3D


func setup(camera: Camera3D, rain: bool) -> void:
	cam = camera
	if not rain:
		return
	_rain = CPUParticles3D.new()
	_rain.amount = [350, 800, 1500][GameSettings.quality]
	_rain.lifetime = 1.1
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(28, 1, 28)
	_rain.direction = Vector3(0.1, -1, 0)
	_rain.spread = 3.0
	_rain.initial_velocity_min = 22.0
	_rain.initial_velocity_max = 28.0
	_rain.gravity = Vector3(0, -9.8, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.55)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 0.85, 0.95, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = m
	_rain.mesh = q
	_rain.local_coords = false
	add_child(_rain)


func _process(_d: float) -> void:
	if _rain and cam:
		var fwd := -cam.global_basis.z
		_rain.global_position = cam.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 18.0 + Vector3(0, 12, 0)
