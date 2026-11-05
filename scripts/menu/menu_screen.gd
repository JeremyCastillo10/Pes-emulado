class_name MenuScreen
extends Control
## Pantalla base de los menús: cabecera con título y botón Atrás, contenido desplazable y
## utilidades para construir la interfaz (botones grandes, filas, selectores, deslizadores).

var menu: Node
var title := ""
var content: VBoxContainer
var _scroll: ScrollContainer


func _init(p_title := "") -> void:
	title = p_title


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.03, 0.09, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 34)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	if title != "":
		var back := Button.new()
		back.text = "< " + Lang.t("back")
		back.custom_minimum_size = Vector2(150, 52)
		back.focus_mode = Control.FOCUS_NONE
		back.pressed.connect(func() -> void:
			Audio.ui("back")
			go_back())
		head.add_child(back)
		var t := Label.new()
		t.text = title.to_upper()
		t.add_theme_font_size_override("font_size", 30)
		t.add_theme_color_override("font_color", UITheme.YELLOW)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(t)
		var strip := ColorRect.new()
		strip.color = UITheme.YELLOW
		strip.custom_minimum_size = Vector2(0, 3)
		v.add_child(strip)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	_scroll.add_child(content)
	build()


## Las pantallas concretas construyen aquí su contenido.
func build() -> void:
	pass


func rebuild() -> void:
	for c in content.get_children():
		c.queue_free()
	build()


func go_back() -> void:
	menu.pop()


func on_shown() -> void:
	pass


# ------------------------------------------------------------- Ayudas

func big_button(text: String, cb: Callable, parent: Control = null, width := 520.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 62)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 24)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		Audio.ui("select")
		cb.call())
	(parent if parent else content).add_child(b)
	return b


func button(text: String, cb: Callable, parent: Control = null, w := 170.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		Audio.ui("click")
		cb.call())
	(parent if parent else content).add_child(b)
	return b


func label(text: String, size := 20, parent: Control = null, color := UITheme.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if parent == null:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	(parent if parent else content).add_child(l)
	return l


func row(parent: Control = null, sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	(parent if parent else content).add_child(h)
	return h


func section(text: String) -> void:
	var l := label(text, 22, null, UITheme.YELLOW)
	l.add_theme_constant_override("line_spacing", 0)


## Selector con flechas: muestra options[idx]; cb(idx) al cambiar.
func cycler(text: String, options: Array, idx: int, cb: Callable, parent: Control = null) -> void:
	var h := row(parent)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 260
	l.add_theme_font_size_override("font_size", 20)
	h.add_child(l)
	var val := Label.new()
	val.custom_minimum_size.x = 300
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 20)
	val.add_theme_color_override("font_color", UITheme.YELLOW)
	var state := [idx]
	var refresh := func() -> void: val.text = str(options[state[0]])
	refresh.call()
	var left := Button.new()
	left.text = "<"
	left.custom_minimum_size = Vector2(60, 50)
	left.pressed.connect(func() -> void:
		Audio.ui("click")
		state[0] = (state[0] - 1 + options.size()) % options.size()
		refresh.call()
		cb.call(state[0]))
	var right := Button.new()
	right.text = ">"
	right.custom_minimum_size = Vector2(60, 50)
	right.pressed.connect(func() -> void:
		Audio.ui("click")
		state[0] = (state[0] + 1) % options.size()
		refresh.call()
		cb.call(state[0]))
	h.add_child(left)
	h.add_child(val)
	h.add_child(right)


func slider(text: String, mn: float, mx: float, step: float, val: float, cb: Callable, parent: Control = null) -> HSlider:
	var h := row(parent)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 260
	l.add_theme_font_size_override("font_size", 19)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(340, 44)
	var v := Label.new()
	v.custom_minimum_size.x = 60
	v.text = str(val)
	s.value_changed.connect(func(x: float) -> void:
		v.text = str(int(x)) if step >= 1.0 else str(snappedf(x, 0.01))
		cb.call(x))
	h.add_child(s)
	h.add_child(v)
	return s


func line_edit(text: String, value: String, cb: Callable, parent: Control = null) -> LineEdit:
	var h := row(parent)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 260
	l.add_theme_font_size_override("font_size", 19)
	h.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.custom_minimum_size = Vector2(400, 48)
	e.text_changed.connect(func(t: String) -> void: cb.call(t))
	h.add_child(e)
	return e


func color_button(text: String, color: String, cb: Callable, parent: Control = null) -> void:
	var h := row(parent)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 180
	h.add_child(l)
	var cp := ColorPickerButton.new()
	cp.color = Color.html(color)
	cp.custom_minimum_size = Vector2(110, 44)
	cp.edit_alpha = false
	cp.color_changed.connect(func(c: Color) -> void: cb.call("#" + c.to_html(false)))
	h.add_child(cp)


func team_row(team_id: String, cb: Callable, parent: Control = null, extra := "") -> Button:
	var t := DB.team(team_id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 58)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		Audio.ui("select")
		cb.call())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.add_child(CrestView.new(t.get("crest", {}), 46))
	var l := Label.new()
	l.text = "%s   %s" % [t.get("name", team_id), extra]
	l.add_theme_font_size_override("font_size", 20)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var st := Label.new()
	st.text = "  " + stars(DB.team_strength(team_id))
	st.add_theme_color_override("font_color", UITheme.YELLOW)
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	st.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(st)
	(parent if parent else content).add_child(b)
	return b


static func stars(strength: float) -> String:
	return "Media %d" % int(round(strength))


func toast(text: String) -> void:
	if menu:
		menu.toast(text)
