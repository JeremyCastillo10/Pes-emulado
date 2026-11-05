class_name StadiumBuilder
extends Node3D
## Construye el estadio de forma procedural: césped, porterías con red,
## vallas publicitarias genéricas, banquillos, gradas, techo, torres de luz,
## público (MultiMesh con LOD por calidad) e iluminación según la hora.

const ADS := ["GOLAZO PRO", "FÚTBOL TOTAL", "DEPORTES 24", "SUPER REFRESCO", "TU MARCA AQUÍ",
	"BANCO DEL GOL", "ZAPATILLAS RAYO", "TELE CANCHA", "AEROLÍNEAS SOL", "LLANTAS VELOZ"]
const AD_COLORS := [Color(0.05, 0.2, 0.6), Color(0.75, 0.08, 0.08), Color(0.05, 0.05, 0.05),
	Color(0.95, 0.75, 0.05), Color(0.1, 0.5, 0.2), Color(0.45, 0.1, 0.55)]

var pitch_material: ShaderMaterial
var net_materials: Array[ShaderMaterial] = []   # [portería +X, portería -X]
var crowd_material: ShaderMaterial
var sun: DirectionalLight3D
var env: WorldEnvironment
var lamp_material: StandardMaterial3D
var _net_age := [10.0, 10.0]
var stadium_cfg: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func build(cfg: Dictionary = {}) -> void:
	stadium_cfg = cfg
	_rng.seed = hash(str(cfg.get("name", "Golazo")))
	_build_environment()
	_build_pitch()
	_build_goal(1)
	_build_goal(-1)
	_build_ad_boards()
	_build_benches()
	_build_stands()
	_build_floodlights()
	_build_crowd()
	apply_time_of_day(GameSettings.time_of_day)
	set_wet(GameSettings.wet_pitch)


## Construcción por partes, repartida en varios fotogramas (carga en segundo plano).
func build_async(cfg: Dictionary, progress: Callable) -> void:
	stadium_cfg = cfg
	_rng.seed = hash(str(cfg.get("name", "Golazo")))
	var steps := [_build_environment, _build_pitch, func() -> void: _build_goal(1), func() -> void: _build_goal(-1),
		_build_ad_boards, _build_benches, _build_stands, _build_floodlights, _build_crowd]
	for i in steps.size():
		steps[i].call()
		progress.call(float(i + 1) / steps.size())
		await get_tree().process_frame


func _process(delta: float) -> void:
	for i in 2:
		if _net_age[i] < 5.0:
			_net_age[i] += delta
			net_materials[i].set_shader_parameter("impact_age", _net_age[i])


func net_impact(pos: Vector3, strength: float) -> void:
	var i := 0 if pos.x > 0.0 else 1
	_net_age[i] = 0.0
	net_materials[i].set_shader_parameter("impact_pos", pos)
	net_materials[i].set_shader_parameter("impact_strength", clampf(strength / 25.0, 0.15, 1.0))
	net_materials[i].set_shader_parameter("impact_age", 0.0)


func set_crowd_excitement(v: float) -> void:
	if crowd_material:
		crowd_material.set_shader_parameter("excitement", clampf(v, 0.0, 1.0))


func set_wet(wet: bool) -> void:
	pitch_material.set_shader_parameter("wetness", 0.85 if wet else 0.0)


func set_shadows(on: bool) -> void:
	if sun:
		sun.shadow_enabled = on


# ----------------------------------------------------------- Entorno

func _build_environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_energy = 0.55
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.fog_enabled = false
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = GameSettings.shadows_enabled()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_blur = 1.0
	add_child(sun)


func apply_time_of_day(t: int) -> void:
	var e := env.environment
	var sm := e.sky.sky_material as ProceduralSkyMaterial
	match t:
		GameSettings.TimeOfDay.SUNSET:
			sun.rotation_degrees = Vector3(-14, -60, 0)
			sun.light_color = Color(1.0, 0.68, 0.42)
			sun.light_energy = 1.1
			sm.sky_top_color = Color(0.22, 0.28, 0.5)
			sm.sky_horizon_color = Color(0.98, 0.58, 0.32)
			sm.ground_horizon_color = Color(0.5, 0.35, 0.25)
			sm.ground_bottom_color = Color(0.1, 0.08, 0.08)
			e.ambient_light_energy = 0.6
			lamp_material.emission_energy_multiplier = 1.5
		GameSettings.TimeOfDay.NIGHT:
			# Focos: luz cenital fuerte y fría, cielo oscuro
			sun.rotation_degrees = Vector3(-62, 30, 0)
			sun.light_color = Color(0.92, 0.95, 1.0)
			sun.light_energy = 1.0
			sm.sky_top_color = Color(0.01, 0.015, 0.04)
			sm.sky_horizon_color = Color(0.06, 0.07, 0.12)
			sm.ground_horizon_color = Color(0.05, 0.05, 0.07)
			sm.ground_bottom_color = Color(0.0, 0.0, 0.0)
			e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			e.ambient_light_color = Color(0.3, 0.33, 0.4)
			e.ambient_light_energy = 0.7
			lamp_material.emission_energy_multiplier = 6.0
			return
		_:
			sun.rotation_degrees = Vector3(-52, -35, 0)
			sun.light_color = Color(1.0, 0.97, 0.9)
			sun.light_energy = 1.25
			sm.sky_top_color = Color(0.25, 0.45, 0.8)
			sm.sky_horizon_color = Color(0.68, 0.78, 0.9)
			sm.ground_horizon_color = Color(0.55, 0.6, 0.6)
			sm.ground_bottom_color = Color(0.2, 0.2, 0.2)
			e.ambient_light_energy = 0.55
			lamp_material.emission_energy_multiplier = 0.3
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = sm.sky_horizon_color.lerp(sm.sky_top_color, 0.5)


# ------------------------------------------------------------ Césped

func _build_pitch() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(PitchDims.HALF_LENGTH * 2.0 + 24.0, PitchDims.HALF_WIDTH * 2.0 + 22.0)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	pitch_material = ShaderMaterial.new()
	pitch_material.shader = load("res://shaders/pitch.gdshader")
	pitch_material.set_shader_parameter("pattern", int(stadium_cfg.get("pattern", _rng.randi_range(0, 4))))
	mi.material_override = pitch_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Pista exterior (tartán / cemento)
	var ring := PlaneMesh.new()
	ring.size = Vector2(170, 130)
	var rmi := MeshInstance3D.new()
	rmi.mesh = ring
	rmi.position.y = -0.02
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.32, 0.3, 0.28)
	rm.roughness = 1.0
	rmi.material_override = rm
	add_child(rmi)


func set_pitch_pattern(p: int) -> void:
	pitch_material.set_shader_parameter("pattern", p)


# ---------------------------------------------------------- Porterías

func _build_goal(side: int) -> void:
	var gx := PitchDims.HALF_LENGTH * side
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.97, 0.97, 0.97)
	white.roughness = 0.3
	var r := PitchDims.POST_RADIUS
	var h := PitchDims.GOAL_HEIGHT
	var w := PitchDims.GOAL_HALF_WIDTH
	var d := PitchDims.GOAL_DEPTH
	for z in [-w, w]:
		_cyl(Vector3(gx + side * r, h * 0.5, z), r, h + r, white, Vector3.ZERO)
	_cyl(Vector3(gx + side * r, h, 0), r, w * 2.0 + r * 2.0, white, Vector3(90, 0, 0))
	# Soportes traseros
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.75, 0.75, 0.75)
	for z in [-w, w]:
		_cyl(Vector3(gx + side * d, h * 0.5, z), 0.03, h, grey, Vector3.ZERO)
		_cyl(Vector3(gx + side * d * 0.5, h, z), 0.03, d, grey, Vector3(0, 0, 90))
	_cyl(Vector3(gx + side * d, 0.03, 0), 0.03, w * 2.0, grey, Vector3(90, 0, 0))
	# Red
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/net.gdshader")
	net_materials.append(mat)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := gx + side * 0.02
	var x1 := gx + side * d
	# Fondo
	_grid(st, Vector3(x1, 0, -w), Vector3(0, 0, 2.0 * w), Vector3(0, h, 0), Vector3(side, 0, 0))
	# Laterales
	_grid(st, Vector3(x0, 0, -w), Vector3(x1 - x0, 0, 0), Vector3(0, h, 0), Vector3(0, 0, -1))
	_grid(st, Vector3(x0, 0, w), Vector3(x1 - x0, 0, 0), Vector3(0, h, 0), Vector3(0, 0, 1))
	# Techo
	_grid(st, Vector3(x0, h, -w), Vector3(x1 - x0, 0, 0), Vector3(0, 0, 2.0 * w), Vector3(0, 1, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _grid(st: SurfaceTool, origin: Vector3, u: Vector3, v: Vector3, normal: Vector3) -> void:
	var nu := maxi(2, int(u.length() / 0.3))
	var nv := maxi(2, int(v.length() / 0.3))
	for i in nu:
		for j in nv:
			var a := float(i) / nu
			var b := float(j) / nv
			var a2 := float(i + 1) / nu
			var b2 := float(j + 1) / nv
			var pts := [origin + u * a + v * b, origin + u * a2 + v * b, origin + u * a2 + v * b2, origin + u * a + v * b2]
			var uvs := [Vector2(a * u.length(), b * v.length()), Vector2(a2 * u.length(), b * v.length()),
				Vector2(a2 * u.length(), b2 * v.length()), Vector2(a * u.length(), b2 * v.length())]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(normal)
				st.set_uv(uvs[idx])
				st.add_vertex(pts[idx])


func _cyl(pos: Vector3, r: float, h: float, mat: Material, rot_deg: Vector3) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)


func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


# ------------------------------------------------- Vallas publicitarias

func _build_ad_boards() -> void:
	var bd := PitchDims.BOARD_DISTANCE
	var hl := PitchDims.HALF_LENGTH + bd
	var hw := PitchDims.HALF_WIDTH + bd
	var seg := 12.0
	var idx := 0
	# Laterales (lado de cámara incluido)
	for zs in [-1, 1]:
		var x := -hl
		while x < hl - 0.1:
			var seg_len := minf(seg, hl - x)
			_ad_board(Vector3(x + seg_len * 0.5, 0.45, hw * zs), Vector3(seg_len, 0.9, 0.12), 0.0 if zs < 0 else 180.0, idx)
			idx += 1
			x += seg_len
	# Fondos
	for xs in [-1, 1]:
		var z := -hw
		while z < hw - 0.1:
			var len2 := minf(seg, hw - z)
			_ad_board(Vector3(hl * xs, 0.45, z + len2 * 0.5), Vector3(len2, 0.9, 0.12), -90.0 * xs, idx)
			idx += 1
			z += len2


func _ad_board(pos: Vector3, size: Vector3, yaw: float, idx: int) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	var mat := StandardMaterial3D.new()
	var c: Color = AD_COLORS[idx % AD_COLORS.size()]
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c * 0.4
	_box(Vector3.ZERO, size, mat, root)
	var lbl := Label3D.new()
	lbl.text = ADS[idx % ADS.size()]
	lbl.font_size = 72
	lbl.pixel_size = 0.009
	lbl.outline_size = 0
	lbl.modulate = Color(1, 1, 1) if c.get_luminance() < 0.6 else Color(0.05, 0.05, 0.1)
	lbl.position = Vector3(0, 0, 0.07)
	lbl.double_sided = false
	root.add_child(lbl)


func _build_benches() -> void:
	var z := PitchDims.HALF_WIDTH + 3.5
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.85, 0.85, 0.88)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.75, 0.85, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var seat := StandardMaterial3D.new()
	seat.albedo_color = Color(0.1, 0.2, 0.5)
	for xs in [-1, 1]:
		var x: float = xs * 9.0
		_box(Vector3(x, 0.45, z + 0.6), Vector3(7.0, 0.5, 0.6), seat)
		_box(Vector3(x, 1.0, z + 1.0), Vector3(7.0, 2.0, 0.08), frame)
		_box(Vector3(x, 2.0, z + 0.4), Vector3(7.0, 0.06, 1.3), glass)
		for ex in [-3.5, 3.5]:
			_box(Vector3(x + ex, 1.0, z + 0.4), Vector3(0.06, 2.0, 1.3), glass)


# ----------------------------------------------------------- Gradas

const ROWS := 22
const ROW_DEPTH := 0.85
const ROW_RISE := 0.48
const STAND_GAP := 9.0

var _stand_rows: Array = []   # [{origin, along, out, length, yaw}]


func _build_stands() -> void:
	var concrete := StandardMaterial3D.new()
	concrete.vertex_color_use_as_albedo = true
	concrete.roughness = 0.95
	var hl := PitchDims.HALF_LENGTH + STAND_GAP
	var hw := PitchDims.HALF_WIDTH + STAND_GAP
	# Laterales: largo 2*hl, fondos: largo 2*hw
	var seat := Color.html(str(stadium_cfg.get("seat_color", "#b01a22")))
	var seat2 := seat.darkened(0.25) if seat.get_luminance() > 0.3 else seat.lightened(0.25)
	_stand(Vector3(0, 0, -hw), Vector3(1, 0, 0), Vector3(0, 0, -1), hl * 2.0, concrete, seat)
	_stand(Vector3(0, 0, hw), Vector3(-1, 0, 0), Vector3(0, 0, 1), hl * 2.0, concrete, seat2)
	_stand(Vector3(hl, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0), hw * 2.0, concrete, seat)
	_stand(Vector3(-hl, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), hw * 2.0, concrete, seat2)
	# Esquinas (bloques simples)
	var corner := StandardMaterial3D.new()
	corner.albedo_color = Color(0.45, 0.45, 0.48)
	var top := ROWS * ROW_RISE
	var depth := ROWS * ROW_DEPTH
	for xs in [-1, 1]:
		for zs in [-1, 1]:
			_box(Vector3(xs * (hl + depth * 0.5), top * 0.5, zs * (hw + depth * 0.5)), Vector3(depth, top, depth), corner)
	if bool(stadium_cfg.get("roof", true)):
		_build_roofs(hl, hw, top, depth)


func _stand(origin: Vector3, along: Vector3, out: Vector3, length: float, mat: Material, seat_color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := length * 0.5
	var a := along * half
	var front_wall := 1.2
	# Muro frontal
	_quad(st, origin - a, origin + a, origin + a + Vector3.UP * front_wall, origin - a + Vector3.UP * front_wall, -out, Color(0.35, 0.35, 0.38))
	for r in ROWS:
		var y := front_wall + r * ROW_RISE
		var o := origin + out * (r * ROW_DEPTH)
		var c := seat_color if (r / 4) % 2 == 0 else seat_color.darkened(0.3)
		# Huella (asientos)
		_quad(st, o - a + Vector3.UP * y, o + a + Vector3.UP * y, o + a + out * ROW_DEPTH + Vector3.UP * y, o - a + out * ROW_DEPTH + Vector3.UP * y, Vector3.UP, c)
		# Contrahuella
		var o2 := o + out * ROW_DEPTH
		_quad(st, o2 - a + Vector3.UP * y, o2 + a + Vector3.UP * y, o2 + a + Vector3.UP * (y + ROW_RISE), o2 - a + Vector3.UP * (y + ROW_RISE), -out, Color(0.4, 0.4, 0.42))
		_stand_rows.append({"pos": o + out * (ROW_DEPTH * 0.55) + Vector3.UP * y, "along": along, "out": out, "length": length})
	# Muro trasero
	var back := origin + out * (ROWS * ROW_DEPTH)
	var topy := front_wall + ROWS * ROW_RISE
	_quad(st, back - a + Vector3.UP * topy, back + a + Vector3.UP * topy, back + a + Vector3.UP * (topy + 3.0), back - a + Vector3.UP * (topy + 3.0), -out, Color(0.3, 0.3, 0.33))
	_quad(st, back + a, back - a, back - a + Vector3.UP * (topy + 3.0), back + a + Vector3.UP * (topy + 3.0), out, Color(0.3, 0.3, 0.33))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, c: Color) -> void:
	# Orden de vértices según la normal para que la cara mire hacia fuera
	var face_n := (p1 - p0).cross(p2 - p0)
	var pts := [p0, p1, p2, p3]
	if face_n.dot(n) > 0.0:
		pts = [p0, p3, p2, p1]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(c)
		st.set_normal(n)
		st.add_vertex(pts[idx])


func _build_roofs(hl: float, hw: float, top: float, depth: float) -> void:
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color(0.82, 0.83, 0.86)
	roof.metallic = 0.3
	roof.roughness = 0.5
	var pillar := StandardMaterial3D.new()
	pillar.albedo_color = Color(0.6, 0.6, 0.62)
	var y := top + 9.0
	# Techo lateral (solo la tribuna de enfrente: la principal es donde está la cámara)
	for zs in [-1]:
		var r := _box(Vector3(0, y, zs * (hw + depth * 0.45)), Vector3(hl * 2.0 + depth * 2.0, 0.5, depth * 1.1), roof)
		r.rotation_degrees.x = 8.0 * zs
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in 7:
			var px := -hl + i * (hl * 2.0 / 6.0)
			_box(Vector3(px, y * 0.5 + 1.0, zs * (hw + depth + 1.0)), Vector3(0.6, y, 0.6), pillar)
	# Techos de fondo (más cortos)
	for xs in [-1, 1]:
		var r2 := _box(Vector3(xs * (hl + depth * 0.5), y - 1.0, 0), Vector3(depth * 0.9, 0.5, hw * 2.0), roof)
		r2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_floodlights() -> void:
	lamp_material = StandardMaterial3D.new()
	lamp_material.albedo_color = Color(0.95, 0.95, 1.0)
	lamp_material.emission_enabled = true
	lamp_material.emission = Color(1, 1, 0.95)
	lamp_material.emission_energy_multiplier = 0.3
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.5, 0.5, 0.55)
	steel.metallic = 0.5
	var hl := PitchDims.HALF_LENGTH + STAND_GAP + ROWS * ROW_DEPTH + 4.0
	var hw := PitchDims.HALF_WIDTH + STAND_GAP + ROWS * ROW_DEPTH + 4.0
	for xs in [-1, 1]:
		for zs in [-1, 1]:
			var base := Vector3(xs * hl, 0, zs * hw)
			var tower := _box(base + Vector3(0, 22, 0), Vector3(1.4, 44, 1.4), steel)
			tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var panel_root := Node3D.new()
			panel_root.position = base + Vector3(0, 45, 0)
			add_child(panel_root)
			panel_root.look_at_from_position(panel_root.position, Vector3(0, 0, 0), Vector3.UP)
			_box(Vector3.ZERO, Vector3(8, 4.5, 0.6), steel, panel_root)
			for i in 4:
				for j in 3:
					var lamp := _box(Vector3(-3.0 + i * 2.0, -1.4 + j * 1.4, -0.35), Vector3(1.6, 1.1, 0.1), lamp_material, panel_root)
					lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ----------------------------------------------------------- Público

func _build_crowd() -> void:
	var density := GameSettings.crowd_density() * clampf(float(stadium_cfg.get("capacity", 50000)) / 55000.0 + 0.25, 0.35, 1.0)
	var spacing := 0.62
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var palette := [Color(0.85, 0.1, 0.1), Color(0.1, 0.25, 0.75), Color(0.95, 0.95, 0.95),
		Color(0.95, 0.8, 0.1), Color(0.1, 0.1, 0.1), Color(0.2, 0.6, 0.3), Color(0.6, 0.3, 0.6)]
	for row in _stand_rows:
		var along: Vector3 = row["along"]
		var out: Vector3 = row["out"]
		var length: float = row["length"]
		var n := int(length / spacing)
		var face_basis := Basis.looking_at(out, Vector3.UP)  # el quad mira hacia el campo (-out)
		for i in n:
			if _rng.randf() > density * 0.85:
				continue
			var p: Vector3 = row["pos"] + along * (-length * 0.5 + (i + 0.5) * spacing)
			p += along * _rng.randf_range(-0.12, 0.12)
			var s := _rng.randf_range(0.92, 1.1)
			var t := Transform3D(face_basis.scaled(Vector3(s, s, s)), p + Vector3(0, 0.55 * s, 0))
			transforms.append(t)
			var c: Color = palette[_rng.randi() % palette.size()]
			colors.append(c.lerp(Color(_rng.randf(), _rng.randf(), _rng.randf()), 0.3))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 1.1)
	mm.mesh = q
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
		mm.set_instance_custom_data(i, Color(_rng.randf(), _rng.randf(), _rng.randf(), 0))
	crowd_material = ShaderMaterial.new()
	crowd_material.shader = load("res://shaders/crowd.gdshader")
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = crowd_material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
