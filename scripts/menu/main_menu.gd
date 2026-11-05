extends Node3D
## Menú principal: fondo 3D animado (estadio de noche y jugador protagonista mirando al campo
## desde la boca del túnel), pila de pantallas con transiciones suaves y música.

var stadium: StadiumBuilder
var protagonist: PlayerModel
var cam: Camera3D
var ui: Control
var stack: Array[Control] = []
var _t := 0.0
var _toast: Label
var _toast_tween: Tween
var _loading: Label


func _ready() -> void:
	GameSettings.time_of_day = GameSettings.TimeOfDay.NIGHT
	stadium = StadiumBuilder.new()
	add_child(stadium)
	stadium.build({"name": "Golazo Arena", "capacity": 70000, "roof": true, "seat_color": "#14306b", "pattern": 1})
	stadium.apply_time_of_day(GameSettings.TimeOfDay.NIGHT)
	stadium.set_crowd_excitement(0.35)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	protagonist = PlayerModel.new()
	protagonist.shirt_color = UITheme.NAVY_2
	protagonist.shirt_color2 = UITheme.YELLOW
	protagonist.shorts_color = UITheme.NAVY
	protagonist.socks_color = UITheme.NAVY
	protagonist.number = 10
	protagonist.shirt_name = "LEYENDA"
	protagonist.hair_style = 1
	protagonist.detail = 2
	add_child(protagonist)
	protagonist.build_model()
	protagonist.position = Vector3(-2.2, 0, PitchDims.HALF_WIDTH + 1.8)
	protagonist.rotation_degrees.y = 0.0
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = UITheme.build()
	layer.add_child(ui)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position = Vector2(-400, -90)
	_toast.size = Vector2(800, 60)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_shadow_color", Color.BLACK)
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_toast)
	Audio.stop_match_ambience()
	Audio.music_on = GameSettings.music
	Audio.play_music()
	if not DB.is_loaded:
		_loading = Label.new()
		_loading.text = "Cargando base de datos…"
		_loading.set_anchors_preset(Control.PRESET_CENTER)
		_loading.position = Vector2(-200, 0)
		_loading.size = Vector2(400, 40)
		_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_loading.add_theme_font_size_override("font_size", 24)
		ui.add_child(_loading)
		await DB.loaded
		_loading.queue_free()
	push(load("res://scripts/menu/screen_main.gd").new())
	# Volver a la pantalla del modo tras un partido
	match Game.return_screen:
		"league", "cup", "world":
			push(load("res://scripts/menu/screen_competition.gd").new(Game.return_screen, true))
		"master":
			push(load("res://scripts/menu/screen_master.gd").new(true))
		"legend":
			push(load("res://scripts/menu/screen_legend.gd").new(true))
		"friendly":
			push(load("res://scripts/menu/screen_friendly.gd").new())
		"training":
			push(load("res://scripts/menu/screen_training.gd").new())
	Game.return_screen = "main"


func _process(delta: float) -> void:
	_t += delta
	# Cámara detrás del protagonista mirando al campo iluminado, con un vaivén suave
	var sway := sin(_t * 0.18)
	cam.global_position = Vector3(-4.0 + sway * 0.5, 1.75 + sin(_t * 0.3) * 0.05, PitchDims.HALF_WIDTH + 5.3)
	cam.look_at(Vector3(2.0 + sway * 3.0, 1.8, 0), Vector3.UP)
	protagonist.anim_speed = 0.0
	protagonist.rotation.y = sin(_t * 0.25) * 0.08


func push(screen: Control) -> void:
	screen.set("menu", self)
	if not stack.is_empty():
		var prev: Control = stack[stack.size() - 1]
		var tw := create_tween()
		tw.tween_property(prev, "modulate:a", 0.0, 0.15)
		tw.tween_callback(func() -> void: prev.visible = false)
	stack.append(screen)
	ui.add_child(screen)
	screen.modulate.a = 0.0
	screen.position.x = 40
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(screen, "modulate:a", 1.0, 0.25)
	tw2.tween_property(screen, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func pop() -> void:
	if stack.size() <= 1:
		return
	var top: Control = stack.pop_back()
	var tw := create_tween()
	tw.tween_property(top, "modulate:a", 0.0, 0.15)
	tw.tween_callback(top.queue_free)
	var prev: Control = stack[stack.size() - 1]
	prev.visible = true
	prev.modulate.a = 0.0
	create_tween().tween_property(prev, "modulate:a", 1.0, 0.2)
	if prev.has_method("on_shown"):
		prev.on_shown()


func pop_to_root() -> void:
	while stack.size() > 1:
		var top: Control = stack.pop_back()
		top.queue_free()
	stack[0].visible = true
	stack[0].modulate.a = 1.0


func toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast.modulate.a = 1.0
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func set_protagonist_look(data: Dictionary, kit: Dictionary = {}) -> void:
	var ap: Dictionary = data.get("appearance", {})
	protagonist.skin_color = Color.html(str(ap.get("skin", "#e0ac83")))
	protagonist.hair_color = Color.html(str(ap.get("hair_color", "#2b1d14")))
	protagonist.hair_style = int(ap.get("hair_style", 1))
	protagonist.beard = int(ap.get("beard", 0))
	protagonist.build = float(ap.get("build", 0.5))
	protagonist.boots_color = Color.html(str(ap.get("boots", "#111111")))
	protagonist.height_m = float(data.get("height", 180)) / 100.0
	protagonist.shirt_name = str(data.get("name", "LEYENDA"))
	protagonist.number = int(data.get("number", 10))
	if not kit.is_empty():
		protagonist.shirt_color = Color.html(str(kit.get("shirt", "#14306b")))
		protagonist.shirt_color2 = Color.html(str(kit.get("shirt2", "#ffd200")))
		protagonist.shorts_color = Color.html(str(kit.get("shorts", "#0a1430")))
		protagonist.socks_color = Color.html(str(kit.get("socks", "#0a1430")))
	protagonist.build_model()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if stack.size() > 1:
			Audio.ui("back")
			var top: Control = stack[stack.size() - 1]
			if top.has_method("go_back"):
				top.go_back()
			else:
				pop()
