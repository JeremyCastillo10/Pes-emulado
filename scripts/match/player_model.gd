class_name PlayerModel
extends Node3D
## Modelo humano procedural con esqueleto (Skeleton3D) y una sola malla con "skinning":
## 1 llamada de dibujo por jugador, apto para 22 jugadores en móviles.
## Las animaciones son procedurales: cada frame se calcula una pose objetivo según el
## estado del jugador y la pose real se mezcla suavemente hacia ella.
## Frente del modelo = -Z local, derecha = +X.

const BLEND_RATE := 14.0
const LEG_LEN := 0.88

## [nombre, padre, posición de reposo relativa al padre]
const BONES := [
	["hips", "", Vector3(0, 0.96, 0)],
	["spine", "hips", Vector3(0, 0.08, 0)],
	["head", "spine", Vector3(0, 0.66, 0)],
	["shoulder_l", "spine", Vector3(-0.2, 0.49, 0)],
	["shoulder_r", "spine", Vector3(0.2, 0.49, 0)],
	["elbow_l", "shoulder_l", Vector3(0, -0.28, 0)],
	["elbow_r", "shoulder_r", Vector3(0, -0.28, 0)],
	["hip_l", "hips", Vector3(-0.1, -0.06, 0)],
	["hip_r", "hips", Vector3(0.1, -0.06, 0)],
	["knee_l", "hip_l", Vector3(0, -0.44, 0)],
	["knee_r", "hip_r", Vector3(0, -0.44, 0)],
]

# Aspecto
var skin_color := Color(0.87, 0.69, 0.53)
var hair_color := Color(0.12, 0.08, 0.05)
var hair_style := 1        # 0 rapado, 1 corto, 2 largo, 3 cresta, 4 afro, 5 moño
var beard := 0             # 0 nada, 1 barba corta, 2 barba completa, 3 bigote
var height_m := 1.80
var build := 0.5           # 0 delgado .. 1 corpulento
var shirt_color := Color(0.8, 0.1, 0.12)
var shirt_color2 := Color(1, 1, 1)
var shorts_color := Color(1, 1, 1)
var socks_color := Color(0.8, 0.1, 0.12)
var boots_color := Color(0.1, 0.1, 0.1)
var gloves := false
var gloves_color := Color(0.95, 0.95, 0.2)
var number := 10
var shirt_name := "JUGADOR"
var detail := 1            # 0 bajo, 1 medio, 2 alto (segmentos de las piezas)

var skel: Skeleton3D
var mesh_instance: MeshInstance3D
var _bi := {}              # nombre de hueso -> índice
var _labels: Array[Label3D] = []

# Pose actual (ángulos en radianes)
var pose := {}
var _run_phase := 0.0

# Entradas de animación que escribe el jugador
var anim_speed := 0.0
var anim_sprint := false
var anim_accel := 0.0
var anim_turn := 0.0
var anim_state := "move"   # move, kick, slide, trick_stepover, trick_cut, stumble, celebrate,
						   # gk_ready, dive, gk_hold, throw, tackle, lament
var anim_t := 0.0
var anim_kick_kind := "pass"
var anim_touch := 0.0
var anim_dive_side := 1.0
var anim_dive_high := 0.0

static var _shared_material: StandardMaterial3D


func build_model() -> void:
	for c in get_children():
		c.queue_free()
	_labels.clear()
	scale = Vector3.ONE * (height_m / 1.80)
	skel = Skeleton3D.new()
	add_child(skel)
	var rest_global := {}
	for b in BONES:
		var idx := skel.add_bone(b[0])
		_bi[b[0]] = idx
		var parent_name: String = b[1]
		var rest := Transform3D(Basis(), b[2])
		if parent_name != "":
			skel.set_bone_parent(idx, _bi[parent_name])
			rest_global[b[0]] = (rest_global[parent_name] as Transform3D) * rest
		else:
			rest_global[b[0]] = rest
		skel.set_bone_rest(idx, rest)
	skel.reset_bone_poses()
	_build_mesh(rest_global)
	_build_back_print()
	_reset_pose()


# ------------------------------------------------------------ Malla

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _cols := PackedColorArray()
var _bones := PackedInt32Array()
var _weights := PackedFloat32Array()
var _idx := PackedInt32Array()
var _rest_global := {}


func _build_mesh(rest_global: Dictionary) -> void:
	_rest_global = rest_global
	_verts = PackedVector3Array()
	_norms = PackedVector3Array()
	_cols = PackedColorArray()
	_bones = PackedInt32Array()
	_weights = PackedFloat32Array()
	_idx = PackedInt32Array()
	var w := lerpf(0.9, 1.14, build)
	var shirt := shirt_color
	var trim := shirt_color2
	var skin := skin_color
	var lip := skin_color.darkened(0.25)
	var hands := gloves_color if gloves else skin
	# Cadera / pantalón
	_capsule("hips", Vector3(0, -0.05, 0), 0.16, 0.3, shorts_color, Vector3(1.05 * w, 1, 0.78 * w))
	# Torso (camiseta)
	_capsule("spine", Vector3(0, 0.14, 0), 0.155, 0.36, shirt, Vector3(1.0 * w, 1, 0.72 * w))
	_capsule("spine", Vector3(0, 0.35, 0), 0.19, 0.4, shirt, Vector3(1.1 * w, 1, 0.66 * w))
	_sphere("spine", Vector3(-0.19 * w, 0.46, 0), 0.075, shirt)
	_sphere("spine", Vector3(0.19 * w, 0.46, 0), 0.075, shirt)
	_capsule("spine", Vector3(0, 0.555, 0), 0.068, 0.12, trim)   # cuello de la camiseta
	_capsule("spine", Vector3(0, 0.6, 0), 0.054, 0.16, skin)     # cuello
	# Cabeza y rostro
	_sphere("head", Vector3(0, 0.035, 0), 0.105, skin, Vector3(0.9, 1.1, 1.0))
	_sphere("head", Vector3(0, -0.03, -0.028), 0.074, skin, Vector3(1.0, 0.92, 1.0))  # mandíbula
	_capsule("head", Vector3(0, 0.018, -0.104), 0.016, 0.05, skin.darkened(0.05))      # nariz
	for sx in [-1.0, 1.0]:
		_sphere("head", Vector3(sx * 0.094, 0.03, 0.005), 0.026, skin, Vector3(0.5, 1.0, 0.8))   # oreja
		_sphere("head", Vector3(sx * 0.037, 0.047, -0.089), 0.015, Color(0.95, 0.95, 0.95))     # ojo
		_sphere("head", Vector3(sx * 0.037, 0.047, -0.1), 0.0085, Color(0.12, 0.08, 0.05))      # pupila
		_box("head", Vector3(sx * 0.038, 0.071, -0.097), Vector3(0.042, 0.009, 0.012), hair_color.darkened(0.2))  # ceja
	_box("head", Vector3(0, -0.034, -0.099), Vector3(0.036, 0.007, 0.01), lip)   # boca
	_add_hair()
	_add_beard()
	# Brazos
	for side in ["l", "r"]:
		_capsule("shoulder_" + side, Vector3(0, -0.14, 0), 0.052 * w, 0.3, skin)
		_capsule("shoulder_" + side, Vector3(0, -0.07, 0), 0.066 * w, 0.17, shirt)
		_capsule("elbow_" + side, Vector3(0, -0.13, 0), 0.044 * w, 0.27, skin)
		_sphere("elbow_" + side, Vector3(0, -0.285, 0), 0.047, hands, Vector3(0.85, 1.15, 0.7))
	# Piernas
	for side in ["l", "r"]:
		_capsule("hip_" + side, Vector3(0, -0.24, 0), 0.08 * w, 0.4, skin)
		_capsule("hip_" + side, Vector3(0, -0.09, 0), 0.098 * w, 0.22, shorts_color)
		_capsule("knee_" + side, Vector3(0, -0.2, 0), 0.058 * w, 0.4, socks_color)
		_sphere("knee_" + side, Vector3(0, -0.12, 0.022), 0.062 * w, socks_color, Vector3(1, 1.7, 1))   # gemelo
		_box("knee_" + side, Vector3(0, -0.43, -0.045), Vector3(0.1, 0.075, 0.27), boots_color)
		_box("knee_" + side, Vector3(0, -0.465, -0.045), Vector3(0.102, 0.012, 0.272), boots_color.lightened(0.5))  # suela
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _norms
	arrays[Mesh.ARRAY_COLOR] = _cols
	arrays[Mesh.ARRAY_BONES] = _bones
	arrays[Mesh.ARRAY_WEIGHTS] = _weights
	arrays[Mesh.ARRAY_INDEX] = _idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = am
	mesh_instance.material_override = PlayerModel.shared_material()
	skel.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	mesh_instance.skin = skel.create_skin_from_rest_transforms()


static func shared_material() -> StandardMaterial3D:
	if _shared_material == null:
		_shared_material = StandardMaterial3D.new()
		_shared_material.vertex_color_use_as_albedo = true
		_shared_material.vertex_color_is_srgb = true
		_shared_material.roughness = 0.78
	return _shared_material


func _add_hair() -> void:
	var hc := hair_color
	match hair_style:
		1:
			_sphere("head", Vector3(0, 0.07, 0.012), 0.108, hc, Vector3(0.94, 0.68, 1.02))
		2:
			_sphere("head", Vector3(0, 0.06, 0.02), 0.114, hc, Vector3(1.0, 0.8, 1.06))
			_box("head", Vector3(0, -0.035, 0.075), Vector3(0.2, 0.17, 0.06), hc)
		3:
			_sphere("head", Vector3(0, 0.06, 0.012), 0.106, hc.lerp(skin_color, 0.5), Vector3(0.93, 0.6, 1.0))
			_box("head", Vector3(0, 0.13, 0.0), Vector3(0.045, 0.07, 0.21), hc)
		4:
			_sphere("head", Vector3(0, 0.09, 0.012), 0.138, hc, Vector3(1.0, 0.85, 1.0))
		5:
			_sphere("head", Vector3(0, 0.068, 0.012), 0.108, hc, Vector3(0.94, 0.68, 1.02))
			_sphere("head", Vector3(0, 0.12, 0.08), 0.045, hc)
		_:
			_sphere("head", Vector3(0, 0.065, 0.012), 0.107, skin_color.darkened(0.12), Vector3(0.93, 0.62, 1.0))


func _add_beard() -> void:
	match beard:
		1:
			_sphere("head", Vector3(0, -0.045, -0.035), 0.072, hair_color.lerp(skin_color, 0.35), Vector3(1.03, 0.8, 0.95))
		2:
			_sphere("head", Vector3(0, -0.05, -0.035), 0.08, hair_color, Vector3(1.05, 0.85, 0.95))
		3:
			_box("head", Vector3(0, -0.02, -0.1), Vector3(0.05, 0.012, 0.012), hair_color)
		_:
			pass


func _seg() -> Vector2i:
	return [Vector2i(6, 2), Vector2i(9, 3), Vector2i(12, 4)][clampi(detail, 0, 2)]


func _capsule(bone: String, pos: Vector3, r: float, h: float, c: Color, scl := Vector3.ONE) -> void:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	var s := _seg()
	m.radial_segments = s.x
	m.rings = s.y
	_append(bone, m.get_mesh_arrays(), pos, scl, c)


func _sphere(bone: String, pos: Vector3, r: float, c: Color, scl := Vector3.ONE) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	var s := _seg()
	m.radial_segments = s.x + 1
	m.rings = s.y + 2
	_append(bone, m.get_mesh_arrays(), pos, scl, c)


func _box(bone: String, pos: Vector3, size: Vector3, c: Color) -> void:
	var m := BoxMesh.new()
	m.size = size
	_append(bone, m.get_mesh_arrays(), pos, Vector3.ONE, c)


func _append(bone: String, arr: Array, pos: Vector3, scl: Vector3, c: Color) -> void:
	var bt: Transform3D = _rest_global[bone]
	var local := Transform3D(Basis.from_scale(scl), pos)
	var t := bt * local
	var nb := t.basis.inverse().transposed()
	var base := _verts.size()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var bidx: int = _bi[bone]
	for i in v.size():
		_verts.append(t * v[i])
		_norms.append((nb * n[i]).normalized())
		_cols.append(c)
		_bones.append_array([bidx, 0, 0, 0])
		_weights.append_array([1.0, 0.0, 0.0, 0.0])
	for i in ind.size():
		_idx.append(base + ind[i])


func _build_back_print() -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = "spine"
	skel.add_child(att)
	var num := Label3D.new()
	num.text = str(number)
	num.font_size = 96
	num.pixel_size = 0.0027
	num.outline_size = 10
	num.modulate = shirt_color2
	num.outline_modulate = shirt_color.darkened(0.6)
	num.position = Vector3(0, 0.25, 0.132 * lerpf(0.9, 1.14, build))
	num.double_sided = false
	num.shaded = true
	num.visibility_range_end = 40.0
	att.add_child(num)
	var nm := Label3D.new()
	nm.text = shirt_name.to_upper()
	nm.font_size = 38
	nm.pixel_size = 0.0027
	nm.outline_size = 6
	nm.modulate = shirt_color2
	nm.outline_modulate = shirt_color.darkened(0.6)
	nm.position = Vector3(0, 0.42, 0.124 * lerpf(0.9, 1.14, build))
	nm.double_sided = false
	nm.shaded = true
	nm.visibility_range_end = 30.0
	att.add_child(nm)
	_labels = [num, nm]


func set_shadows(on: bool) -> void:
	if mesh_instance:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for l in _labels:
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- Animación

func _reset_pose() -> void:
	pose = {
		"hip_l": 0.0, "hip_r": 0.0, "knee_l": 0.1, "knee_r": 0.1,
		"hip_side_l": 0.0, "hip_side_r": 0.0,
		"sh_l": 0.0, "sh_r": 0.0, "sh_side_l": 0.15, "sh_side_r": 0.15,
		"el_l": 0.3, "el_r": 0.3,
		"lean": 0.05, "roll": 0.0, "twist": 0.0, "height": 0.0,
		"body_pitch": 0.0, "head_pitch": 0.0, "head_yaw": 0.0,
	}


func play(state: String) -> void:
	if state != anim_state:
		anim_t = 0.0
	anim_state = state


func _process(delta: float) -> void:
	if skel == null:
		return
	anim_t += delta
	anim_touch = maxf(anim_touch - delta, 0.0)
	var target := _target_pose(delta)
	var rate := BLEND_RATE
	if anim_state in ["kick", "dive", "throw", "volley", "bicycle", "header", "backheel", "punch"]:
		rate = 24.0
	var k := 1.0 - exp(-rate * delta)
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
		"tackle":
			_pose_locomotion(t, delta)
			t["hip_r"] = 0.9
			t["knee_r"] = 0.2
			t["lean"] = 0.25
			t["height"] = -0.08
		"stumble":
			_pose_locomotion(t, delta)
			var s := clampf(anim_t / 0.8, 0.0, 1.0)
			t["lean"] = 0.7 * (1.0 - s)
			t["height"] = -0.15 * (1.0 - s)
			t["sh_l"] = 1.0
			t["sh_r"] = 1.0
			t["sh_side_l"] = 0.9
			t["sh_side_r"] = 0.9
		"header":
			_pose_stand(t)
			var a3 := clampf(anim_t / 0.4, 0.0, 1.0)
			t["height"] = sin(a3 * PI) * 0.38
			t["head_pitch"] = lerpf(-0.5, 0.6, a3)
			t["lean"] = lerpf(-0.3, 0.35, a3)
			t["sh_l"] = 0.9
			t["sh_r"] = 0.9
			t["sh_side_l"] = 0.6
			t["sh_side_r"] = 0.6
			t["knee_l"] = 0.6
			t["knee_r"] = 0.6
		"volley":
			_pose_kick(t)
			t["hip_r"] = clampf(t["hip_r"] * 1.35, -1.0, 1.9)
			t["knee_r"] = 0.1 if t["hip_r"] > 0.0 else 1.2
			t["roll"] = -0.35
			t["sh_side_l"] = 1.2
		"bicycle":
			var a4 := clampf(anim_t / 0.6, 0.0, 1.0)
			t["body_pitch"] = lerpf(0.0, -2.5, a4)
			t["height"] = sin(a4 * PI) * 0.6
			t["hip_r"] = lerpf(0.5, 2.2, a4)
			t["hip_l"] = lerpf(0.8, -0.2, a4)
			t["knee_r"] = 0.1
			t["knee_l"] = 1.0
			t["sh_l"] = -0.8
			t["sh_r"] = -0.8
			t["sh_side_l"] = 1.3
			t["sh_side_r"] = 1.3
			t["lean"] = 0.0
			t["roll"] = 0.0
		"backheel":
			_pose_stand(t)
			var a5 := clampf(anim_t / 0.3, 0.0, 1.0)
			t["hip_r"] = lerpf(0.3, -0.9, a5)
			t["knee_r"] = lerpf(0.6, 0.3, a5)
			t["lean"] = 0.2
		"punch":
			_pose_stand(t)
			var a6 := clampf(anim_t / 0.35, 0.0, 1.0)
			t["height"] = sin(a6 * PI) * 0.45
			t["sh_l"] = lerpf(1.0, 3.0, a6)
			t["sh_r"] = lerpf(1.0, 3.0, a6)
			t["el_l"] = lerpf(1.5, 0.0, a6)
			t["el_r"] = lerpf(1.5, 0.0, a6)
			t["hip_l"] = 0.6
			t["knee_l"] = 1.0
		"charge":
			_pose_locomotion(t, delta)
			t["roll"] = 0.35
			t["sh_side_r"] = 0.1
			t["sh_r"] = 0.2
			t["el_r"] = 1.4
		"fall":
			var a7 := clampf(anim_t / 0.5, 0.0, 1.0)
			t["body_pitch"] = lerpf(0.0, 1.45, a7)
			t["height"] = lerpf(0.0, -0.78, a7)
			t["sh_l"] = lerpf(0.5, 1.6, a7)
			t["sh_r"] = lerpf(0.5, 1.6, a7)
			t["sh_side_l"] = 0.8
			t["sh_side_r"] = 0.8
			t["hip_l"] = -0.2
			t["hip_r"] = 0.1
			t["knee_l"] = 0.3
			t["knee_r"] = 0.5
			t["lean"] = 0.0
			t["roll"] = 0.1
		"protest":
			_pose_stand(t)
			t["sh_l"] = 0.9 + sin(anim_t * 6.0) * 0.2
			t["sh_r"] = 0.9 + sin(anim_t * 6.0 + 1.0) * 0.2
			t["sh_side_l"] = 0.9
			t["sh_side_r"] = 0.9
			t["el_l"] = 0.3
			t["el_r"] = 0.3
			t["head_pitch"] = -0.2
		"wave":
			_pose_stand(t)
			t["sh_r"] = 2.6
			t["sh_side_r"] = 0.6 + sin(anim_t * 7.0) * 0.35
			t["el_r"] = 0.4
		"card":
			_pose_stand(t)
			t["sh_r"] = 3.0
			t["sh_side_r"] = 0.15
			t["el_r"] = 0.0
		"airplane":
			_pose_locomotion(t, delta)
			t["sh_l"] = 0.1
			t["sh_r"] = 0.1
			t["sh_side_l"] = 1.5
			t["sh_side_r"] = 1.5
			t["el_l"] = 0.0
			t["el_r"] = 0.0
			t["roll"] = sin(anim_t * 2.5) * 0.35
		"knee_slide":
			var a8 := clampf(anim_t / 0.5, 0.0, 1.0)
			t["hip_l"] = -0.2
			t["hip_r"] = -0.2
			t["knee_l"] = lerpf(0.2, 1.7, a8)
			t["knee_r"] = lerpf(0.2, 1.7, a8)
			t["height"] = lerpf(0.0, -0.45, a8)
			t["lean"] = -0.45
			t["sh_l"] = 2.6
			t["sh_r"] = 2.6
			t["sh_side_l"] = 0.6
			t["sh_side_r"] = 0.6
			t["head_pitch"] = -0.5
			t["body_pitch"] = 0.0
			t["roll"] = 0.0
		"jump_punch":
			_pose_stand(t)
			var ph := fmod(anim_t, 0.9) / 0.9
			t["height"] = sin(ph * PI) * 0.4
			t["sh_r"] = 3.0
			t["el_r"] = 0.0
			t["sh_side_r"] = 0.1
			t["knee_l"] = 0.4 + sin(ph * PI) * 0.6
			t["knee_r"] = 0.4 + sin(ph * PI) * 0.6
		"point_sky":
			_pose_stand(t)
			t["sh_l"] = 2.9
			t["sh_r"] = 2.9
			t["sh_side_l"] = 0.25
			t["sh_side_r"] = 0.25
			t["el_l"] = 0.0
			t["el_r"] = 0.0
			t["head_pitch"] = -0.6
		"celebrate":
			_pose_stand(t)
			t["sh_l"] = 2.8
			t["sh_r"] = 2.8
			t["sh_side_l"] = 0.4
			t["sh_side_r"] = 0.4
			t["el_l"] = 0.2
			t["el_r"] = 0.2
			t["lean"] = -0.2
			t["height"] = maxf(sin(anim_t * 9.0), 0.0) * 0.12
		"lament":
			_pose_stand(t)
			t["lean"] = 0.35
			t["head_pitch"] = 0.5
			t["sh_l"] = 0.3
			t["sh_r"] = 0.3
			t["el_l"] = 2.0
			t["el_r"] = 2.0
		"gk_ready":
			_pose_locomotion(t, delta)
			if anim_speed < 1.5:
				t["hip_l"] = 0.35
				t["hip_r"] = 0.35
				t["knee_l"] = 0.65
				t["knee_r"] = 0.65
				t["hip_side_l"] = 0.18
				t["hip_side_r"] = 0.18
				t["height"] = -0.12
				t["lean"] = 0.35
			t["sh_l"] = 0.6
			t["sh_r"] = 0.6
			t["sh_side_l"] = 0.55
			t["sh_side_r"] = 0.55
			t["el_l"] = 0.7
			t["el_r"] = 0.7
		"dive":
			_pose_dive(t)
		"gk_hold":
			_pose_locomotion(t, delta)
			t["sh_l"] = 1.0
			t["sh_r"] = 1.0
			t["sh_side_l"] = -0.15
			t["sh_side_r"] = -0.15
			t["el_l"] = 1.4
			t["el_r"] = 1.4
		"throw":
			_pose_stand(t)
			var a2 := clampf(anim_t / 0.45, 0.0, 1.0)
			t["sh_r"] = lerpf(3.0, 0.6, a2)
			t["el_r"] = 0.2
			t["sh_l"] = 0.8
			t["hip_l"] = 0.4
			t["lean"] = lerpf(-0.2, 0.3, a2)
		_:
			_pose_locomotion(t, delta)
	return t


func _pose_stand(t: Dictionary) -> void:
	for k in ["hip_l", "hip_r", "hip_side_l", "hip_side_r", "twist", "roll", "body_pitch", "head_pitch", "head_yaw"]:
		t[k] = 0.0
	t["knee_l"] = 0.1
	t["knee_r"] = 0.1
	t["height"] = 0.0
	t["lean"] = 0.03


func _pose_locomotion(t: Dictionary, delta: float) -> void:
	var spd := anim_speed
	var amp := clampf(spd / 7.5, 0.0, 1.0)
	var run_amp := lerpf(0.0, 0.8, amp) + (0.15 if anim_sprint else 0.0)
	# Cadencia derivada de la longitud de zancada: los pies no "patinan"
	var swing := maxf(run_amp, 0.28)
	var stride := 4.0 * LEG_LEN * sin(swing) * (1.0 + 0.45 * clampf((spd - 3.5) / 5.0, 0.0, 1.0))
	stride *= scale.y
	_run_phase = fmod(_run_phase + delta * spd / maxf(stride, 0.4) * TAU, TAU)
	var s := sin(_run_phase)
	t["hip_l"] = s * run_amp
	t["hip_r"] = -s * run_amp
	t["knee_l"] = 0.12 + maxf(-sin(_run_phase + 0.9), 0.0) * (0.25 + 1.25 * amp)
	t["knee_r"] = 0.12 + maxf(sin(_run_phase + 0.9), 0.0) * (0.25 + 1.25 * amp)
	t["sh_l"] = -s * run_amp * 0.8
	t["sh_r"] = s * run_amp * 0.8
	t["sh_side_l"] = 0.12 + 0.06 * amp
	t["sh_side_r"] = 0.12 + 0.06 * amp
	t["el_l"] = 0.25 + amp * 1.1
	t["el_r"] = 0.25 + amp * 1.1
	# Rebote del cuerpo: transmite peso al apoyar cada pie
	t["height"] = absf(cos(_run_phase)) * 0.05 * amp - 0.04 * amp
	# Inclinación: delante al acelerar/esprintar, hacia atrás al frenar
	t["lean"] = 0.04 + amp * 0.14 + clampf(anim_accel * 0.035, -0.35, 0.22) + (0.08 if anim_sprint else 0.0)
	t["roll"] = clampf(-anim_turn * 0.09 * amp, -0.32, 0.32)
	t["twist"] = s * 0.12 * amp
	t["hip_side_l"] = 0.0
	t["hip_side_r"] = 0.0
	t["body_pitch"] = 0.0
	t["head_pitch"] = 0.0
	if anim_touch > 0.0:
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
	t["hip_side_l"] = 0.0
	t["hip_side_r"] = 0.0
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
	t["body_pitch"] = 0.0


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


func _pose_dive(t: Dictionary) -> void:
	var a := clampf(anim_t / 0.35, 0.0, 1.0)
	var side := anim_dive_side
	var high := anim_dive_high
	t["roll"] = -side * lerpf(0.2, 1.35, a)
	t["height"] = lerpf(-0.1, lerpf(-0.55, 0.15, high), a)
	t["body_pitch"] = 0.0
	t["lean"] = 0.0
	t["twist"] = 0.0
	# Brazos estirados hacia el lado del vuelo
	t["sh_l"] = lerpf(0.6, 2.9, a)
	t["sh_r"] = lerpf(0.6, 2.9, a)
	t["sh_side_l"] = 0.2
	t["sh_side_r"] = 0.2
	t["el_l"] = 0.1
	t["el_r"] = 0.1
	t["hip_l"] = 0.2
	t["hip_r"] = 0.2
	t["knee_l"] = 0.5
	t["knee_r"] = 0.3
	t["hip_side_l"] = 0.25 if side < 0 else 0.0
	t["hip_side_r"] = 0.25 if side > 0 else 0.0


func _rot(bone: String, e: Vector3) -> void:
	skel.set_bone_pose_rotation(_bi[bone], Quaternion.from_euler(e))


func _apply_pose() -> void:
	skel.set_bone_pose_position(_bi["hips"], Vector3(0, 0.96 + pose["height"], 0))
	_rot("hips", Vector3(-pose["body_pitch"], pose["twist"] * 0.5, pose["roll"]))
	_rot("spine", Vector3(-pose["lean"], -pose["twist"], 0))
	_rot("head", Vector3(pose["lean"] * 0.6 - pose["head_pitch"], pose["head_yaw"], 0))
	_rot("hip_l", Vector3(pose["hip_l"], 0, -pose["hip_side_l"]))
	_rot("hip_r", Vector3(pose["hip_r"], 0, pose["hip_side_r"]))
	_rot("knee_l", Vector3(-pose["knee_l"], 0, 0))
	_rot("knee_r", Vector3(-pose["knee_r"], 0, 0))
	_rot("shoulder_l", Vector3(pose["sh_l"], 0, -pose["sh_side_l"]))
	_rot("shoulder_r", Vector3(pose["sh_r"], 0, pose["sh_side_r"]))
	_rot("elbow_l", Vector3(pose["el_l"], 0, 0))
	_rot("elbow_r", Vector3(pose["el_r"], 0, 0))
