extends Node3D
## Visor de repeticiones guardadas: reconstruye estadio, jugadores y balón y reproduce en bucle.

var data: Dictionary = {}
var frames: Array = []
var models: Array = []
var ball_mesh: Node3D
var cam: Camera3D
var t := 0.0
var speed := 0.6
var cam_mode := 0
var _lbl: Label


func _ready() -> void:
	var path := str(Game.match_config.get("replay_file", ""))
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var v: Variant = JSON.parse_string(f.get_as_text())
		if v is Dictionary:
			data = v
	frames = data.get("frames", [])
	var st := StadiumBuilder.new()
	add_child(st)
	GameSettings.time_of_day = int(data.get("time_of_day", 0))
	st.build(data.get("stadium", {}))
	st.set_crowd_excitement(0.9)
	for info in data.get("players", []):
		var m := PlayerModel.new()
		var pd: Dictionary = info.get("data", {})
		var kit: Dictionary = info.get("kit", {})
		var ap: Dictionary = pd.get("appearance", {})
		m.number = int(pd.get("number", 0))
		m.shirt_name = str(pd.get("name", ""))
		m.height_m = float(pd.get("height", 180)) / 100.0
		m.skin_color = Color.html(str(ap.get("skin", "#e0ac83")))
		m.hair_color = Color.html(str(ap.get("hair_color", "#2b1d14")))
		m.hair_style = int(ap.get("hair_style", 1))
		m.beard = int(ap.get("beard", 0))
		m.build = float(ap.get("build", 0.5))
		m.boots_color = Color.html(str(ap.get("boots", "#111111")))
		m.shirt_color = Color.html(str(kit.get("shirt", "#ffffff")))
		m.shirt_color2 = Color.html(str(kit.get("shirt2", "#000000")))
		m.shorts_color = Color.html(str(kit.get("shorts", "#ffffff")))
		m.socks_color = Color.html(str(kit.get("socks", "#ffffff")))
		m.gloves = bool(info.get("gk", false))
		m.detail = GameSettings.quality
		var root := Node3D.new()
		add_child(root)
		root.add_child(m)
		m.build_model()
		models.append(m)
	var sphere := SphereMesh.new()
	sphere.radius = Ball.RADIUS
	sphere.height = Ball.RADIUS * 2.0
	var bm := MeshInstance3D.new()
	bm.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ball.gdshader")
	bm.material_override = mat
	add_child(bm)
	ball_mesh = bm
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = UITheme.build()
	layer.add_child(ui)
	_lbl = Label.new()
	_lbl.text = str(data.get("title", ""))
	_lbl.position = Vector2(20, 16)
	_lbl.add_theme_font_size_override("font_size", 24)
	_lbl.add_theme_color_override("font_color", UITheme.YELLOW)
	ui.add_child(_lbl)
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.position = Vector2(-330, -80)
	bar.add_theme_constant_override("separation", 10)
	ui.add_child(bar)
	for b in [["0.25x", func() -> void: speed = 0.25], ["0.5x", func() -> void: speed = 0.5], ["1x", func() -> void: speed = 1.0],
		[Lang.t("camera"), func() -> void: cam_mode = (cam_mode + 1) % 3], [Lang.t("back"), func() -> void: Game.back_to_menu("main")]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(120, 54)
		btn.pressed.connect(b[1])
		bar.add_child(btn)


func _process(delta: float) -> void:
	if frames.size() < 2:
		return
	var t0 := float(frames[0][0])
	var t1 := float(frames[frames.size() - 1][0])
	t += delta * speed
	if t0 + t > t1 + 1.0:
		t = 0.0
	var tt := minf(t0 + t, t1)
	var i := 0
	while i < frames.size() - 2 and float(frames[i + 1][0]) < tt:
		i += 1
	var a: Array = frames[i]
	var b: Array = frames[i + 1]
	var k := clampf((tt - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
	var bp := Vector3(lerpf(a[1], b[1], k), lerpf(a[2], b[2], k), lerpf(a[3], b[3], k))
	ball_mesh.position = bp
	ball_mesh.quaternion = Quaternion(a[4], a[5], a[6], a[7]).slerp(Quaternion(b[4], b[5], b[6], b[7]), k)
	var pa: Array = a[8]
	var pb: Array = b[8]
	for j in mini(models.size(), pa.size()):
		var s0: Array = pa[j]
		var s1: Array = pb[j] if j < pb.size() else s0
		var m: PlayerModel = models[j]
		var root: Node3D = m.get_parent()
		root.position = Vector3(lerpf(s0[0], s1[0], k), 0, lerpf(s0[1], s1[1], k))
		var yaw := lerp_angle(float(s0[2]), float(s1[2]), k)
		root.basis = Basis.looking_at(Vector3(sin(yaw), 0, cos(yaw)), Vector3.UP)
		root.visible = int(s0[9]) == 1
		var ai: int = s0[3]
		m.anim_state = ReplaySystem.ANIMS[ai] if ai >= 0 else "move"
		m.anim_t = lerpf(s0[4], s1[4], k)
		m.anim_speed = lerpf(s0[5], s1[5], k)
		m.anim_sprint = int(s0[6]) == 1
		m.anim_dive_side = s0[7]
		m.anim_dive_high = s0[8]
	match cam_mode:
		0:
			cam.global_position = bp + Vector3(cos(t * 0.3) * 9.0, 2.2, sin(t * 0.3) * 9.0 + 2.0)
		1:
			cam.global_position = Vector3(bp.x * 0.8, 20.0, 55.0)
		_:
			cam.global_position = Vector3(bp.x - signf(bp.x + 0.01) * 14.0, 3.0, bp.z * 0.5)
	cam.look_at(bp + Vector3(0, 0.5, 0), Vector3.UP)
