class_name TouchControls
extends Control
## Controles táctiles: joystick flotante a la izquierda y botones contextuales a la
## derecha. Los botones pulsan acciones del InputMap (Input.action_press), así que el
## juego trata igual el táctil, el teclado y el mando Bluetooth.
## - Arrastrar el dedo horizontalmente mientras se carga Tiro/Pase = efecto (curl).
## - Deslizar rápido en la zona derecha libre = pase en profundidad.
## - Modo edición: arrastrar botones para recolocarlos (se guarda en ajustes).

signal edit_finished

const REF_SIZE := Vector2(1280, 720)
const JOY_RADIUS := 85.0
const SWIPE_MIN_PX := 70.0
const SWIPE_MAX_TIME := 0.4

## name, action, etiqueta con balón, etiqueta sin balón, offset desde esquina inferior derecha, radio
var buttons: Array = [
	{"name": "shoot", "action": "act_shoot", "on": "btn_shoot", "off": "btn_slide", "base": Vector2(-110, -135), "r": 64.0},
	{"name": "pass", "action": "act_pass", "on": "btn_pass", "off": "btn_press", "base": Vector2(-245, -75), "r": 54.0},
	{"name": "lob", "action": "act_lob", "on": "btn_lob", "off": "btn_double_press", "base": Vector2(-250, -210), "r": 48.0},
	{"name": "through", "action": "act_through", "on": "btn_through", "off": "btn_keeper_out", "base": Vector2(-110, -285), "r": 48.0},
	{"name": "trick", "action": "act_trick", "on": "btn_trick", "off": "btn_switch", "base": Vector2(-380, -95), "r": 44.0},
	{"name": "sprint", "action": "act_sprint", "on": "btn_sprint", "off": "btn_sprint", "base": Vector2(-385, -225), "r": 46.0},
]

var player: Node = null
var editing := false

var _held := {}            # touch index -> button index
var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _swipes := {}          # touch index -> {start, time}
var _drag_edit := {}       # touch index -> button index (modo edición)
var _has_ball := true
var _font: Font
var _hidden_by_pad := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	InputHub.context_changed.connect(func(hb: bool) -> void:
		_has_ball = hb
		queue_redraw())
	GameSettings.settings_changed.connect(queue_redraw)
	# En escritorio sin pantalla táctil igualmente se muestran (se pueden usar con el ratón).


func _process(_delta: float) -> void:
	if player != null and player.get("charging_action") != "":
		queue_redraw()


func button_center(i: int) -> Vector2:
	var b: Dictionary = buttons[i]
	var sz := get_viewport_rect().size
	var s := GameSettings.controls_scale
	var off: Vector2 = GameSettings.button_offsets.get(b["name"], Vector2.ZERO)
	return sz + (b["base"] as Vector2) * s + off


func button_radius(i: int) -> float:
	return float(buttons[i]["r"]) * GameSettings.controls_scale


func _button_at(pos: Vector2) -> int:
	for i in buttons.size():
		if pos.distance_to(button_center(i)) <= button_radius(i) * 1.15:
			return i
	return -1


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		if not _hidden_by_pad:
			_hidden_by_pad = true
			visible = false
		return
	if event is InputEventScreenTouch:
		if _hidden_by_pad:
			_hidden_by_pad = false
			visible = true
		if not is_visible_in_tree():
			return
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touch_down(st.index, st.position)
		else:
			_touch_up(st.index, st.position)
	elif event is InputEventScreenDrag:
		if not is_visible_in_tree():
			return
		var sd := event as InputEventScreenDrag
		_touch_move(sd.index, sd.position)


func _touch_down(idx: int, pos: Vector2) -> void:
	var bi := _button_at(pos)
	if editing:
		if bi >= 0:
			_drag_edit[idx] = bi
		return
	if bi >= 0:
		_held[idx] = bi
		Input.action_press(buttons[bi]["action"])
		InputHub.curl = 0.0
		queue_redraw()
		return
	var sz := get_viewport_rect().size
	if pos.x < sz.x * 0.45:
		if _joy_index == -1 and pos.y > sz.y * 0.18:
			_joy_index = idx
			_joy_origin = pos
			_joy_pos = pos
			queue_redraw()
	elif pos.y > sz.y * 0.15:
		_swipes[idx] = {"start": pos, "time": Time.get_ticks_msec() / 1000.0}


func _touch_move(idx: int, pos: Vector2) -> void:
	if editing and _drag_edit.has(idx):
		var bi: int = _drag_edit[idx]
		var b: Dictionary = buttons[bi]
		var sz := get_viewport_rect().size
		var base_pos := sz + (b["base"] as Vector2) * GameSettings.controls_scale
		GameSettings.button_offsets[b["name"]] = pos - base_pos
		queue_redraw()
		return
	if idx == _joy_index:
		_joy_pos = pos
		_update_joystick()
		queue_redraw()
	elif _held.has(idx):
		var bi2: int = _held[idx]
		var c := button_center(bi2)
		var dx := pos.x - c.x
		var r := button_radius(bi2)
		if absf(dx) > r * 0.4:
			InputHub.curl = clampf((dx - signf(dx) * r * 0.4) / (r * 1.6), -1.0, 1.0)
		else:
			InputHub.curl = 0.0
		queue_redraw()


func _touch_up(idx: int, pos: Vector2) -> void:
	if editing:
		_drag_edit.erase(idx)
		return
	if _held.has(idx):
		var bi: int = _held[idx]
		_held.erase(idx)
		# No soltar si otro dedo mantiene el mismo botón
		if not _held.values().has(bi):
			Input.action_release(buttons[bi]["action"])
		queue_redraw()
	if idx == _joy_index:
		_joy_index = -1
		for a in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
		queue_redraw()
	if _swipes.has(idx):
		var sw: Dictionary = _swipes[idx]
		_swipes.erase(idx)
		var d: Vector2 = pos - (sw["start"] as Vector2)
		var dt: float = Time.get_ticks_msec() / 1000.0 - float(sw["time"])
		if d.length() > SWIPE_MIN_PX and dt < SWIPE_MAX_TIME:
			InputHub.emit_swipe(d.normalized(), clampf(d.length() / 320.0, 0.2, 1.0))


func _update_joystick() -> void:
	var r := JOY_RADIUS * GameSettings.controls_scale
	var v := (_joy_pos - _joy_origin) / r
	if v.length() > 1.0:
		# Joystick flotante: la base sigue al dedo si se aleja demasiado
		_joy_origin = _joy_pos - v.normalized() * r
		v = v.normalized()
	_set_axis("move_right", maxf(v.x, 0.0))
	_set_axis("move_left", maxf(-v.x, 0.0))
	_set_axis("move_down", maxf(v.y, 0.0))
	_set_axis("move_up", maxf(-v.y, 0.0))


func _set_axis(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func release_all() -> void:
	for idx in _held.keys():
		Input.action_release(buttons[_held[idx]]["action"])
	_held.clear()
	_joy_index = -1
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	queue_redraw()


func set_editing(on: bool) -> void:
	release_all()
	editing = on
	queue_redraw()
	if not on:
		GameSettings.save_settings()
		edit_finished.emit()


func reset_layout() -> void:
	GameSettings.button_offsets = {}
	GameSettings.save_settings()
	queue_redraw()


# ------------------------------------------------------------- Dibujo

func _draw() -> void:
	var alpha := GameSettings.controls_opacity
	var s := GameSettings.controls_scale
	# Joystick
	var sz := get_viewport_rect().size
	if _joy_index >= 0:
		var r := JOY_RADIUS * s
		draw_circle(_joy_origin, r, Color(1, 1, 1, 0.12 * alpha / 0.55))
		draw_arc(_joy_origin, r, 0, TAU, 48, Color(1, 1, 1, alpha * 0.8), 3.0, true)
		draw_circle(_joy_pos, r * 0.42, Color(1, 1, 1, alpha * 0.85))
	else:
		# Indicador de dónde aparece el joystick
		var hint := Vector2(sz.x * 0.13, sz.y * 0.72)
		draw_arc(hint, JOY_RADIUS * s, 0, TAU, 48, Color(1, 1, 1, alpha * 0.25), 2.0, true)
		draw_circle(hint, JOY_RADIUS * s * 0.38, Color(1, 1, 1, alpha * 0.2))
	var fs := int(17 * s)
	for i in buttons.size():
		var b: Dictionary = buttons[i]
		var c := button_center(i)
		var r2 := button_radius(i)
		var pressed := _held.values().has(i)
		var base_col := Color(UITheme.NAVY, alpha * (0.9 if pressed else 0.55))
		var ring := Color(1, 1, 1, alpha * 0.75)
		if b["name"] == "shoot":
			ring = Color(1.0, 0.45, 0.2, alpha + 0.2)
		elif b["name"] == "sprint":
			ring = Color(0.3, 0.95, 0.5, alpha + 0.2)
		elif b["name"] == "through":
			ring = Color(UITheme.YELLOW, alpha + 0.2)
		elif b["name"] == "pass":
			ring = Color(0.35, 0.7, 1.0, alpha + 0.2)
		if pressed:
			ring = Color(UITheme.YELLOW, 1.0)
		draw_circle(c, r2, base_col)
		draw_arc(c, r2, 0, TAU, 40, ring, 3.0 if not editing else 5.0, true)
		var label := Lang.t(b["on"] if _has_ball else b["off"])
		var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(_font, c + Vector2(-tw * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, minf(1.0, alpha + 0.35)))
		# Arco de carga
		if player != null and player.get("charging_action") == b["action"]:
			var ch: float = player.get("charge")
			draw_arc(c, r2 + 6.0, -PI * 0.5, -PI * 0.5 + TAU * ch, 40, Color(1.0, lerpf(0.9, 0.2, ch), 0.1, 0.95), 6.0, true)
			if absf(InputHub.curl) > 0.05:
				var cx := c + Vector2(InputHub.curl * r2 * 1.4, -r2 - 14.0)
				draw_line(c + Vector2(0, -r2 - 14.0), cx, Color(0.4, 0.9, 1.0, 0.9), 4.0, true)
	if editing:
		var hint_text := Lang.t("edit_controls_hint")
		var hw := _font.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(_font, Vector2((sz.x - hw) * 0.5, sz.y * 0.4), hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 0.6))
