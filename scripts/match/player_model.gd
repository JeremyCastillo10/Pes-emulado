class_name PlayerModel
extends Node3D
## Modelo humano procedural (sin assets externos) con articulaciones como pivotes.
## Las animaciones son procedurales: cada frame se calcula una "pose objetivo"
## según el estado del jugador y la pose real se mezcla suavemente hacia ella.
## Frente del modelo = -Z local.

const BLEND_RATE := 16.0

# Aspecto
var skin_color := Color(0.87, 0.69, 0.53)
var hair_color := Color(0.12, 0.08, 0.05)
var hair_style := 1        # 0 rapado, 1 corto, 2 largo, 3 cresta, 4 afro
var beard := 0             # 0 nada, 1 barba corta, 2 barba completa
var height_m := 1.80
var build := 0.5           # 0 delgado .. 1 corpulento
var shirt_color := Color(0.8, 0.1, 0.12)
var shirt_color2 := Color(1, 1, 1)
var shorts_color := Color(1, 1, 1)
var socks_color := Color(0.8, 0.1, 0.12)
var boots_color := Color(0.1, 0.1, 0.1)
var number := 10
var shirt_name := "JUGADOR"

# Articulaciones
var hips: Node3D
var torso: Node3D
var head: Node3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var knee_l: Node3D
var knee_r: Node3D

# Pose actual (ángulos en radianes)
var pose := {}
var _run_phase := 0.0

# Entradas de animación que escribe el jugador
var anim_speed := 0.0
var anim_sprint := false
var anim_accel := 0.0
var anim_turn := 0.0
var anim_state := "move"   # move, kick, slide, trick_stepover, trick_cut, stumble, celebrate
var anim_t := 0.0          # tiempo dentro del estado actual
var anim_kick_kind := "pass"
var anim_touch := 0.0      # >0 justo tras un toque de conducción

var _mats := {}


func build_model() -> void:
	for c in get_children():
		c.queue_free()
	var s := height_m / 1.80
	var w := lerpf(0.88, 1.15, build)
	scale = Vector3(w, s, w)
	_mats.clear()
	var skin := _mat("skin", skin_color, 0.7)
	var shirt := _mat("shirt", shirt_color, 0.8)
	var shorts := _mat("shorts", shorts_color, 0.8)
	var socks := _mat("socks", socks_color, 0.9)
	var boots := _mat("boots", boots_color, 0.35)
	var hair := _mat("hair", hair_color, 0.9)

	hips = _pivot(self, Vector3(0, 0.96, 0))
	_capsule(hips, Vector3(0, -0.04, 0), 0.165, 0.34, shorts, Vector3(1.0, 1.0, 0.75))
	torso = _pivot(hips, Vector3(0, 0.08, 0))
	_capsule(torso, Vector3(0, 0.26, 0), 0.19, 0.58, shirt, Vector3(1.0, 1.0, 0.62))
	# Cuello y cabeza
	_capsule(torso, Vector3(0, 0.58, 0), 0.055, 0.16, skin)
	head = _pivot(torso, Vector3(0, 0.68, 0))
	_sphere(head, Vector3(0, 0.03, 0), 0.105, skin, Vector3(0.92, 1.08, 1.0))
	_sphere(head, Vector3(0, 0.03, -0.1), 0.02, skin)  # nariz
	_add_hair(hair)
	_add_beard(hair)
	# Brazos
	shoulder_l = _pivot(torso, Vector3(-0.22, 0.48, 0))
	shoulder_r = _pivot(torso, Vector3(0.22, 0.48, 0))
	for sh in [shoulder_l, shoulder_r]:
		_capsule(sh, Vector3(0, -0.07, 0), 0.06, 0.16, shirt)
		_capsule(sh, Vector3(0, -0.17, 0), 0.045, 0.2, skin)
	elbow_l = _pivot(shoulder_l, Vector3(0, -0.28, 0))
	elbow_r = _pivot(shoulder_r, Vector3(0, -0.28, 0))
	for el in [elbow_l, elbow_r]:
		_capsule(el, Vector3(0, -0.13, 0), 0.04, 0.26, skin)
		_sphere(el, Vector3(0, -0.27, 0), 0.045, skin)
	# Piernas
	hip_l = _pivot(hips, Vector3(-0.1, -0.06, 0))
	hip_r = _pivot(hips, Vector3(0.1, -0.06, 0))
	for hp in [hip_l, hip_r]:
		_capsule(hp, Vector3(0, -0.1, 0), 0.085, 0.22, shorts)
		_capsule(hp, Vector3(0, -0.28, 0), 0.07, 0.24, skin)
	knee_l = _pivot(hip_l, Vector3(0, -0.44, 0))
	knee_r = _pivot(hip_r, Vector3(0, -0.44, 0))
	for kn in [knee_l, knee_r]:
		_capsule(kn, Vector3(0, -0.2, 0), 0.06, 0.4, socks)
		_box(kn, Vector3(0, -0.43, -0.04), Vector3(0.1, 0.07, 0.26), boots)
	# Dorsal y nombre en la espalda (+Z)
	var num := Label3D.new()
	num.text = str(number)
	num.font_size = 96
	num.pixel_size = 0.0028
	num.outline_size = 10
	num.modulate = shirt_color2
	num.outline_modulate = shirt_color.darkened(0.6)
	num.position = Vector3(0, 0.24, 0.125)
	num.double_sided = false
	num.shaded = true
	torso.add_child(num)
	var nm := Label3D.new()
	nm.text = shirt_name.to_upper()
	nm.font_size = 40
	nm.pixel_size = 0.0028
	nm.outline_size = 6
	nm.modulate = shirt_color2
	nm.outline_modulate = shirt_color.darkened(0.6)
	nm.position = Vector3(0, 0.42, 0.122)
	nm.double_sided = false
	nm.shaded = true
	torso.add_child(nm)
	_reset_pose()


func _add_hair(mat: Material) -> void:
	match hair_style:
		1:
			_sphere(head, Vector3(0, 0.07, 0.01), 0.108, mat, Vector3(0.95, 0.7, 1.0))
		2:
			_sphere(head, Vector3(0, 0.06, 0.02), 0.115, mat, Vector3(1.0, 0.8, 1.05))
			_box(head, Vector3(0, -0.04, 0.07), Vector3(0.2, 0.18, 0.06), mat)
		3:
			_box(head, Vector3(0, 0.13, 0.0), Vector3(0.04, 0.07, 0.2), mat)
		4:
			_sphere(head, Vector3(0, 0.09, 0.01), 0.14, mat, Vector3(1.0, 0.85, 1.0))
		_:
			pass


func _add_beard(mat: Material) -> void:
	if beard == 0:
		return
	var sz := 0.075 if beard == 1 else 0.09
	_sphere(head, Vector3(0, -0.05, -0.04), sz, mat, Vector3(1.0, 0.75, 0.9))


func _mat(key: String, c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_mats[key] = m
	return m


func set_team_colors(shirt: Color, shirt2: Color, shorts_c: Color, socks_c: Color) -> void:
	shirt_color = shirt
	shirt_color2 = shirt2
	shorts_color = shorts_c
	socks_color = socks_c


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _capsule(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, scl := Vector3.ONE) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 8
	m.rings = 2
	return _mesh_inst(parent, m, pos, mat, scl)


func _sphere(parent: Node3D, pos: Vector3, r: float, mat: Material, scl := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 6
	return _mesh_inst(parent, m, pos, mat, scl)


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh_inst(parent, m, pos, mat, Vector3.ONE)


func _mesh_inst(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func set_shadows(on: bool) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = mode


# ---------------------------------------------------------------- Animación

func _reset_pose() -> void:
	pose = {
		"hip_l": 0.0, "hip_r": 0.0, "knee_l": 0.1, "knee_r": 0.1,
		"hip_side_l": 0.0, "hip_side_r": 0.0,
		"sh_l": 0.0, "sh_r": 0.0, "sh_side_l": 0.15, "sh_side_r": 0.15,
		"el_l": 0.3, "el_r": 0.3,
		"lean": 0.05, "roll": 0.0, "twist": 0.0, "height": 0.0,
		"body_pitch": 0.0, "head_pitch": 0.0,
	}


func play(state: String) -> void:
	anim_state = state
	anim_t = 0.0


func _process(delta: float) -> void:
	if hips == null:
		return
	anim_t += delta
	anim_touch = maxf(anim_touch - delta, 0.0)
	var target := _target_pose(delta)
	var k := 1.0 - exp(-BLEND_RATE * delta)
	for key in target:
		pose[key] = lerpf(pose[key], target[key], k)
	_apply_pose()


func _target_pose(delta: float) -> Dictionary:
	var t := pose.duplicate()
	match anim_state:
		"kick":
			_pose_kick(t)
		"slide":
			_pose_slide(t)
		"trick_stepover":
			_pose_locomotion(t, delta)
			var a := clampf(anim_t / 0.45, 0.0, 1.0)
			var side := sin(a * TAU)
			t["hip_side_r"] = 0.6 * maxf(side, 0.0)
			t["hip_side_l"] = 0.6 * maxf(-side, 0.0)
			t["hip_r"] = 0.5 * maxf(side, 0.0)
			t["hip_l"] = 0.5 * maxf(-side, 0.0)
			t["roll"] = side * 0.18
		"trick_cut":
			_pose_locomotion(t, delta)
			t["roll"] = 0.25
			t["hip_side_r"] = 0.5
			t["lean"] = 0.25
		"stumble":
			_pose_locomotion(t, delta)
			t["lean"] = 0.6 * (1.0 - clampf(anim_t / 0.8, 0.0, 1.0))
			t["sh_side_l"] = 1.0
			t["sh_side_r"] = 1.0
		"celebrate":
			t["hip_l"] = 0.0
			t["hip_r"] = 0.0
			t["knee_l"] = 0.1
			t["knee_r"] = 0.1
			t["sh_l"] = 2.8
			t["sh_r"] = 2.8
			t["sh_side_l"] = 0.4
			t["sh_side_r"] = 0.4
			t["el_l"] = 0.2
			t["el_r"] = 0.2
			t["lean"] = -0.2
			t["height"] = maxf(sin(anim_t * 9.0), 0.0) * 0.12
		_:
			_pose_locomotion(t, delta)
	return t


func _pose_locomotion(t: Dictionary, delta: float) -> void:
	var spd := anim_speed
	# Frecuencia de zancada: más larga al esprintar
	var stride := 1.5 + clampf(spd / 9.0, 0.0, 1.0) * 1.0
	_run_phase = fmod(_run_phase + delta * spd / stride * TAU, TAU)
	var amp := clampf(spd / 7.5, 0.0, 1.0)
	var run_amp := lerpf(0.0, 0.85, amp) + (0.15 if anim_sprint else 0.0)
	var s := sin(_run_phase)
	t["hip_l"] = s * run_amp
	t["hip_r"] = -s * run_amp
	t["knee_l"] = 0.12 + maxf(-sin(_run_phase + 0.9), 0.0) * (0.3 + 1.2 * amp)
	t["knee_r"] = 0.12 + maxf(sin(_run_phase + 0.9), 0.0) * (0.3 + 1.2 * amp)
	t["sh_l"] = -s * run_amp * 0.8
	t["sh_r"] = s * run_amp * 0.8
	t["sh_side_l"] = 0.12 + 0.06 * amp
	t["sh_side_r"] = 0.12 + 0.06 * amp
	t["el_l"] = 0.25 + amp * 1.1
	t["el_r"] = 0.25 + amp * 1.1
	t["height"] = absf(cos(_run_phase)) * 0.045 * amp - 0.03 * amp
	# Inclinación hacia delante con velocidad/aceleración; hacia atrás al frenar
	t["lean"] = 0.04 + amp * 0.14 + clampf(anim_accel * 0.03, -0.3, 0.2) + (0.08 if anim_sprint else 0.0)
	t["roll"] = clampf(-anim_turn * 0.08 * amp, -0.3, 0.3)
	t["twist"] = s * 0.12 * amp
	t["hip_side_l"] = 0.0
	t["hip_side_r"] = 0.0
	t["body_pitch"] = 0.0
	if anim_touch > 0.0:
		# Pequeño toque con el pie derecho al conducir
		t["hip_r"] = 0.55
		t["knee_r"] = 0.25


func _pose_kick(t: Dictionary) -> void:
	var a := anim_t
	var power := 1.0 if anim_kick_kind in ["shot", "lob"] else 0.7
	var back := -0.9 * power
	var fwd := 1.4 * power
	var leg := 0.0
	if a < 0.14:
		leg = lerpf(0.0, back, a / 0.14)
	elif a < 0.24:
		leg = lerpf(back, fwd, (a - 0.14) / 0.1)
	else:
		leg = lerpf(fwd, 0.2, clampf((a - 0.24) / 0.3, 0.0, 1.0))
	t["hip_r"] = leg
	t["knee_r"] = 1.3 if leg < 0.0 else 0.15
	t["hip_l"] = -0.1
	t["knee_l"] = 0.3
	t["sh_l"] = 0.4
	t["sh_r"] = -0.3
	t["sh_side_l"] = 0.9
	t["sh_side_r"] = 0.5
	t["el_l"] = 0.4
	t["el_r"] = 0.4
	t["lean"] = -0.12 if anim_kick_kind == "lob" else 0.12
	t["twist"] = 0.25 if a < 0.2 else -0.2
	t["height"] = -0.04
	t["roll"] = -0.1


func _pose_slide(t: Dictionary) -> void:
	t["body_pitch"] = -1.15
	t["height"] = -0.62
	t["hip_r"] = 0.35
	t["knee_r"] = 0.05
	t["hip_l"] = -0.1
	t["knee_l"] = 1.2
	t["sh_l"] = -0.6
	t["sh_r"] = 0.3
	t["sh_side_l"] = 0.9
	t["sh_side_r"] = 0.6
	t["el_l"] = 0.2
	t["el_r"] = 0.6
	t["lean"] = 0.0
	t["roll"] = 0.2
	t["twist"] = 0.0


func _apply_pose() -> void:
	hips.position.y = 0.96 + pose["height"]
	hips.rotation = Vector3(-pose["body_pitch"], pose["twist"] * 0.5, pose["roll"])
	torso.rotation = Vector3(-pose["lean"], -pose["twist"], 0)
	head.rotation = Vector3(pose["lean"] * 0.6 - pose["head_pitch"], 0, 0)
	hip_l.rotation = Vector3(pose["hip_l"], 0, -pose["hip_side_l"])
	hip_r.rotation = Vector3(pose["hip_r"], 0, pose["hip_side_r"])
	knee_l.rotation = Vector3(-pose["knee_l"], 0, 0)
	knee_r.rotation = Vector3(-pose["knee_r"], 0, 0)
	shoulder_l.rotation = Vector3(pose["sh_l"], 0, -pose["sh_side_l"])
	shoulder_r.rotation = Vector3(pose["sh_r"], 0, pose["sh_side_r"])
	elbow_l.rotation = Vector3(pose["el_l"], 0, 0)
	elbow_r.rotation = Vector3(pose["el_r"], 0, 0)
