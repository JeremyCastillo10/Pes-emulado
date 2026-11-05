class_name CameraRig
extends Camera3D
## Cámaras del partido: Transmisión (por defecto), Amplia, Cercana y Detrás del jugador.
## Sigue al balón con suavizado y anticipación.

var ball: Node3D
var player: Node3D
var attack_side := 1
var mode: int = 0
var shake := 0.0
var override := ""      # "intro", "replay" o vacío
var _ot := 0.0

var _focus := Vector3.ZERO
var _pos_smooth := Vector3(0, 25, 60)
var _initialized := false


func _ready() -> void:
	mode = GameSettings.camera_mode
	near = 0.3
	far = 600.0


func cycle_mode() -> int:
	mode = (mode + 1) % 4
	GameSettings.camera_mode = mode
	GameSettings.save_settings()
	return mode


func set_mode(m: int) -> void:
	mode = m


func _process(delta: float) -> void:
	if ball == null:
		return
	mode = GameSettings.camera_mode
	if override != "":
		_cinematic(delta)
		return
	var bp := ball.global_position
	var target_focus := bp
	if ball.get("velocity") != null:
		var bv: Vector3 = ball.velocity
		target_focus += Vector3(bv.x, 0, bv.z) * 0.25
	target_focus.y = minf(bp.y * 0.4, 2.0)
	var desired_pos := Vector3.ZERO
	var fov_target := 32.0
	var hl := PitchDims.HALF_LENGTH
	match mode:
		GameSettings.CameraMode.BROADCAST:
			target_focus.x = clampf(target_focus.x, -hl + 8.0, hl - 8.0)
			target_focus.z = clampf(target_focus.z * 0.65, -22.0, 22.0)
			desired_pos = Vector3(target_focus.x * 0.82, 21.0, 58.0)
			fov_target = 30.0
		GameSettings.CameraMode.WIDE:
			target_focus.x = clampf(target_focus.x, -hl + 18.0, hl - 18.0)
			target_focus.z = clampf(target_focus.z * 0.4, -12.0, 12.0)
			desired_pos = Vector3(target_focus.x * 0.75, 38.0, 70.0)
			fov_target = 40.0
		GameSettings.CameraMode.CLOSE:
			target_focus.z = clampf(target_focus.z, -30.0, 30.0)
			desired_pos = Vector3(target_focus.x * 0.95, 11.0, target_focus.z + 26.0)
			fov_target = 34.0
		_:
			var p := player.global_position if player != null else bp
			var dir := Vector3(attack_side, 0, 0)
			target_focus = p + dir * 14.0
			target_focus.y = 0.5
			desired_pos = p - dir * 10.0 + Vector3(0, 5.0, 0)
			fov_target = 55.0
	var k := 1.0 - exp(-4.0 * delta)
	var kp := 1.0 - exp(-3.0 * delta)
	if not _initialized:
		_initialized = true
		k = 1.0
		kp = 1.0
	_focus = _focus.lerp(target_focus, k)
	_pos_smooth = _pos_smooth.lerp(desired_pos, kp)
	fov = lerpf(fov, fov_target, kp)
	var off := Vector3.ZERO
	if shake > 0.0:
		shake = maxf(shake - delta, 0.0)
		off = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.3
	global_position = _pos_smooth + off
	look_at(_focus, Vector3.UP)


func _cinematic(delta: float) -> void:
	_ot += delta
	var target := Vector3.ZERO
	var pos := Vector3.ZERO
	if override == "intro":
		target = Vector3(sin(_ot * 0.25) * 6.0, 1.5, 6.0)
		pos = Vector3(sin(_ot * 0.25) * 9.0, 2.6 + _ot * 0.15, 15.0 - _ot * 0.25)
		fov = lerpf(fov, 45.0, 0.05)
	else:
		# Repetición: cámara baja que gira alrededor del balón
		var bp := ball.global_position
		target = bp + Vector3(0, 0.6, 0)
		pos = bp + Vector3(cos(_ot * 0.35) * 9.0, 2.2, sin(_ot * 0.35) * 9.0 + 2.0)
		fov = lerpf(fov, 38.0, 0.05)
	var k := 1.0 - exp(-3.0 * delta)
	_pos_smooth = _pos_smooth.lerp(pos, k)
	_focus = _focus.lerp(target, k)
	global_position = _pos_smooth
	look_at(_focus, Vector3.UP)
