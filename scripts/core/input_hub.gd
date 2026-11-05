extends Node
## Centraliza la entrada: crea el mapa de acciones (teclado + mando Bluetooth)
## y recibe los gestos de los controles táctiles. Los botones táctiles usan
## Input.action_press/release, así el juego lee todo con la misma API.
##
## Las acciones son contextuales (como en los juegos clásicos):
##   act_pass    Con balón: Pase            Sin balón: Presión
##   act_lob     Con balón: Pase largo      Sin balón: Doble presión
##   act_through Con balón: Profundidad     Sin balón: Salida del portero
##   act_shoot   Con balón: Tiro (cargar)   Sin balón: Barrida
##   act_trick   Con balón: Regate/Truco    Sin balón: Cambiar jugador
##   act_sprint  Sprint

signal swipe(screen_dir: Vector2, strength: float)
signal context_changed(has_ball: bool)

const ACTIONS := ["act_pass", "act_lob", "act_through", "act_shoot", "act_trick", "act_sprint"]

## Efecto aportado por gesto (-1 izquierda .. 1 derecha) durante la carga de tiro/pase.
var curl: float = 0.0
var has_ball_context: bool = true


func _ready() -> void:
	_build_input_map()


func set_context(has_ball: bool) -> void:
	if has_ball != has_ball_context:
		has_ball_context = has_ball
		context_changed.emit(has_ball)


func vibrate(ms: int) -> void:
	if GameSettings.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func emit_swipe(dir: Vector2, strength: float) -> void:
	swipe.emit(dir, strength)


## Modo 2 jugadores: los mandos del jugador 1 quedan limitados al mando 0 (el 2 usa el mando 1).
func set_two_player(on: bool) -> void:
	for a in InputMap.get_actions():
		if str(a).begins_with("ui_"):
			continue
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				InputMap.action_erase_event(a, e)
				e.device = 0 if on else -1
				InputMap.action_add_event(a, e)


func _build_input_map() -> void:
	_add("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _btn(JOY_BUTTON_DPAD_LEFT)])
	_add("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _btn(JOY_BUTTON_DPAD_RIGHT)])
	_add("move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _btn(JOY_BUTTON_DPAD_UP)])
	_add("move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _btn(JOY_BUTTON_DPAD_DOWN)])
	_add("act_pass", [_key(KEY_J), _btn(JOY_BUTTON_A)])
	_add("act_shoot", [_key(KEY_K), _btn(JOY_BUTTON_B)])
	_add("act_lob", [_key(KEY_U), _btn(JOY_BUTTON_X)])
	_add("act_through", [_key(KEY_I), _btn(JOY_BUTTON_Y)])
	_add("act_trick", [_key(KEY_Q), _btn(JOY_BUTTON_LEFT_SHOULDER)])
	_add("act_sprint", [_key(KEY_SHIFT), _key(KEY_L), _btn(JOY_BUTTON_RIGHT_SHOULDER), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add("cam_cycle", [_key(KEY_C), _btn(JOY_BUTTON_BACK)])
	_add("pause", [_key(KEY_ESCAPE), _key(KEY_P), _btn(JOY_BUTTON_START)])


func _add(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for e in events:
		InputMap.action_add_event(action, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.device = -1
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = -1
	return e
