class_name MatchHUD
extends CanvasLayer
## HUD de la Fase 1: nombre del jugador, barras de resistencia y potencia,
## mensajes grandes (gol, poste, fuera), FPS y panel de opciones.

signal camera_cycle_requested
signal reset_ball_requested
signal time_of_day_changed(t: int)
signal wet_changed(wet: bool)
signal pattern_changed(p: int)
signal quality_changed(q: int)

var player: Node = null
var touch: TouchControls

var _msg: Label
var _msg_tween: Tween
var _fps: Label
var _cam_label: Label
var _name_label: Label
var _stamina_bar: ProgressBar
var _power_bar: ProgressBar
var _options: PanelContainer
var _done_btn: Button
var _theme: Theme


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_theme = Theme.new()
	_theme.default_font_size = 22
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme
	add_child(root)

	touch = TouchControls.new()
	root.add_child(touch)

	# Título y FPS
	var title := Label.new()
	title.text = Lang.t("phase1_title")
	title.position = Vector2(16, 10)
	_shadowed(title, 20)
	root.add_child(title)
	_fps = Label.new()
	_fps.position = Vector2(16, 40)
	_shadowed(_fps, 16)
	root.add_child(_fps)

	# Botones superiores derechos
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.position = Vector2(-330, 10)
	top.size = Vector2(320, 50)
	top.alignment = BoxContainer.ALIGNMENT_END
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	var cam_btn := _button(Lang.t("camera"), func() -> void: camera_cycle_requested.emit())
	top.add_child(cam_btn)
	var opt_btn := _button(Lang.t("settings"), open_options)
	top.add_child(opt_btn)
	_cam_label = Label.new()
	_cam_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_cam_label.position = Vector2(-330, 64)
	_cam_label.size = Vector2(320, 30)
	_cam_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shadowed(_cam_label, 16)
	root.add_child(_cam_label)

	# Mensaje central
	_msg = Label.new()
	_msg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_msg.position = Vector2(-400, 110)
	_msg.size = Vector2(800, 80)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadowed(_msg, 48)
	_msg.modulate.a = 0.0
	root.add_child(_msg)

	# Panel inferior: nombre + resistencia + potencia
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-150, -98)
	bottom.size = Vector2(300, 90)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadowed(_name_label, 20)
	bottom.add_child(_name_label)
	_stamina_bar = _bar(Color(0.2, 0.85, 0.3))
	bottom.add_child(_stamina_bar)
	_power_bar = _bar(Color(1.0, 0.75, 0.1))
	_power_bar.custom_minimum_size.y = 14
	bottom.add_child(_power_bar)

	_build_options(root)
	_done_btn = _button(Lang.t("edit_controls_done"), func() -> void:
		touch.set_editing(false)
		_done_btn.visible = false)
	_done_btn.set_anchors_preset(Control.PRESET_CENTER)
	_done_btn.position = Vector2(-60, -30)
	_done_btn.visible = false
	root.add_child(_done_btn)
	_update_cam_label()


func _process(_delta: float) -> void:
	_fps.visible = GameSettings.show_fps
	if GameSettings.show_fps:
		_fps.text = "FPS %d · %s" % [Engine.get_frames_per_second(), Lang.t(GameSettings.QUALITY_KEYS[GameSettings.quality])]
	if player != null:
		var d: Dictionary = player.get("data")
		_name_label.text = "%d  %s" % [int(d.get("number", 0)), str(d.get("name", ""))]
		_stamina_bar.value = float(player.get("stamina")) * 100.0
		var ch: float = player.get("charge")
		_power_bar.value = ch * 100.0
		_power_bar.modulate.a = 1.0 if player.get("charging_action") != "" else 0.25


func show_message(text: String, duration := 1.6, color := Color.WHITE) -> void:
	_msg.text = text
	_msg.modulate = color
	_msg.scale = Vector2(0.6, 0.6)
	_msg.pivot_offset = _msg.size * 0.5
	if _msg_tween:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(_msg, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(_msg, "modulate:a", 0.0, 0.4)


func _update_cam_label() -> void:
	_cam_label.text = Lang.t("camera") + ": " + Lang.t(GameSettings.CAMERA_KEYS[GameSettings.camera_mode])


func on_camera_changed() -> void:
	_update_cam_label()


# ------------------------------------------------------------ Opciones

func open_options() -> void:
	touch.release_all()
	_options.visible = true
	get_tree().paused = true


func close_options() -> void:
	_options.visible = false
	get_tree().paused = false


func _build_options(root: Control) -> void:
	_options = PanelContainer.new()
	_options.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.12, 0.92)
	_options.add_theme_stylebox_override("panel", sb)
	_options.visible = false
	root.add_child(_options)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_options.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(margin)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)
	var title := Label.new()
	title.text = Lang.t("settings")
	title.add_theme_font_size_override("font_size", 32)
	v.add_child(title)

	_choice_row(v, Lang.t("quality"), ["quality_auto", "quality_low", "quality_medium", "quality_high"],
		0 if GameSettings.auto_quality else GameSettings.quality + 1,
		func(i: int) -> void:
			if i == 0:
				GameSettings.set_quality(0, true)
			else:
				GameSettings.set_quality(i - 1, false)
			quality_changed.emit(GameSettings.quality))
	_choice_row(v, Lang.t("camera"), GameSettings.CAMERA_KEYS, GameSettings.camera_mode,
		func(i: int) -> void:
			GameSettings.camera_mode = i
			GameSettings.save_settings()
			_update_cam_label())
	_choice_row(v, Lang.t("time_of_day"), GameSettings.TIME_KEYS, GameSettings.time_of_day,
		func(i: int) -> void:
			GameSettings.time_of_day = i
			GameSettings.save_settings()
			time_of_day_changed.emit(i))
	_choice_row(v, Lang.t("pitch_state"), ["pitch_dry", "pitch_wet"], 1 if GameSettings.wet_pitch else 0,
		func(i: int) -> void:
			GameSettings.wet_pitch = i == 1
			GameSettings.save_settings()
			wet_changed.emit(i == 1))
	_choice_row(v, "Corte del césped", ["Franjas", "Cuadros", "Círculos", "Diagonal", "Finas"], -1,
		func(i: int) -> void: pattern_changed.emit(i), false)
	_slider_row(v, Lang.t("controls_opacity"), 0.15, 1.0, GameSettings.controls_opacity,
		func(val: float) -> void:
			GameSettings.controls_opacity = val
			GameSettings.save_settings())
	_slider_row(v, Lang.t("controls_scale"), 0.7, 1.4, GameSettings.controls_scale,
		func(val: float) -> void:
			GameSettings.controls_scale = val
			GameSettings.save_settings())
	_choice_row(v, Lang.t("vibration"), ["on", "off"], 0 if GameSettings.vibration else 1,
		func(i: int) -> void:
			GameSettings.vibration = i == 0
			GameSettings.save_settings())
	_choice_row(v, Lang.t("show_fps"), ["on", "off"], 0 if GameSettings.show_fps else 1,
		func(i: int) -> void:
			GameSettings.show_fps = i == 0
			GameSettings.save_settings())
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	v.add_child(actions)
	actions.add_child(_button(Lang.t("edit_controls"), func() -> void:
		close_options()
		touch.set_editing(true)
		_done_btn.visible = true))
	actions.add_child(_button(Lang.t("reset_controls"), func() -> void: touch.reset_layout()))
	actions.add_child(_button(Lang.t("reset_ball"), func() -> void:
		close_options()
		reset_ball_requested.emit()))
	actions.add_child(_button(Lang.t("quit_game"), func() -> void: get_tree().quit()))
	var close := _button(Lang.t("close"), close_options)
	close.custom_minimum_size = Vector2(220, 60)
	v.add_child(close)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	help.add_theme_font_size_override("font_size", 16)
	help.text = "Mando: stick izq. mover · A pase/presión · B tiro/barrida · X pase largo · Y profundidad · LB regate · RB sprint · Back cámara · Start opciones.\nTeclado: WASD · J pase · K tiro · U largo · I profundidad · Q regate · Shift sprint · C cámara · Esc opciones.\nTáctil: arrastra el dedo a los lados mientras cargas un tiro para darle efecto; desliza rápido en la zona derecha para un pase en profundidad."
	v.add_child(help)


func _choice_row(parent: Control, label: String, keys: Array, selected: int, cb: Callable, toggle := true) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 260
	h.add_child(l)
	var group := ButtonGroup.new()
	for i in keys.size():
		var b := Button.new()
		b.text = Lang.t(keys[i])
		b.custom_minimum_size = Vector2(120, 52)
		if toggle:
			b.toggle_mode = true
			b.button_group = group
			b.button_pressed = i == selected
		var idx := i
		b.pressed.connect(func() -> void: cb.call(idx))
		h.add_child(b)


func _slider_row(parent: Control, label: String, mn: float, mx: float, val: float, cb: Callable) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 260
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(360, 52)
	s.value_changed.connect(func(x: float) -> void: cb.call(x))
	h.add_child(s)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 52)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _bar(c: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(300, 18)
	p.show_percentage = false
	p.max_value = 100
	var fg := StyleBoxFlat.new()
	fg.bg_color = c
	fg.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(4)
	p.add_theme_stylebox_override("fill", fg)
	p.add_theme_stylebox_override("background", bg)
	return p


func _shadowed(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
