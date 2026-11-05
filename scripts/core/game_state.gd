extends Node
## Estado global (autoload "Game"): configuración del próximo partido, cambio de escena con
## transición (logo del torneo), resultado del último partido y partidas guardadas de los modos.

signal match_finished(result: Dictionary)

const MATCH_SCENE := "res://scenes/match/match.tscn"
const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const SAVE_DIR := "user://saves"

## Configuración del partido (ver default_match_config()).
var match_config: Dictionary = {}
var last_result: Dictionary = {}
## Partida activa del modo actual (liga, copa, Liga Máster, Leyenda...).
var session: Dictionary = {}
var session_slot := ""
## Pantalla de menú a la que volver al terminar el partido.
var return_screen := "main"

var _fade: CanvasLayer
var _fade_rect: ColorRect
var _fade_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = CanvasLayer.new()
	_fade.layer = 100
	add_child(_fade)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(UITheme.NAVY, 1.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0
	_fade.add_child(_fade_rect)
	_fade_label = Label.new()
	_fade_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fade_label.add_theme_font_size_override("font_size", 54)
	_fade_label.add_theme_color_override("font_color", UITheme.YELLOW)
	_fade_label.text = "GOLAZO PRO"
	_fade_rect.add_child(_fade_label)


func default_match_config() -> Dictionary:
	return {
		"mode": "friendly",              # friendly, league, cup, world, master, legend, training
		"home": "", "away": "",
		"home_kit": "home", "away_kit": "away",
		"human_home": true, "human_away": false, "two_players": false,
		"home_lineup": [], "away_lineup": [], "home_formation": "", "away_formation": "",
		"home_strategy": "normal", "away_strategy": "normal",
		"difficulty": GameSettings.difficulty, "half_minutes": GameSettings.half_minutes,
		"time_of_day": GameSettings.time_of_day, "weather": "clear",
		"stadium": {}, "needs_winner": false, "extra_time": true, "penalties": true,
		"competition_name": "Amistoso", "legend_player": "", "training": "",
		"presentation": true,
	}


func start_match(cfg: Dictionary) -> void:
	var c := default_match_config()
	c.merge(cfg, true)
	match_config = c
	change_scene(MATCH_SCENE, str(c.get("competition_name", "")))


func finish_match(result: Dictionary) -> void:
	last_result = result
	if not session.is_empty() and str(result.get("mode", "")) != "friendly" and str(result.get("mode", "")) != "training":
		ModeFlow.apply(session, result)
		save_session()
	match_finished.emit(result)


func back_to_menu(screen := "") -> void:
	if screen != "":
		return_screen = screen
	get_tree().paused = false
	change_scene(MENU_SCENE, "")


## Cambio de escena con fundido y el logo del torneo.
func change_scene(path: String, title: String) -> void:
	_fade_label.text = title.to_upper() if title != "" else "GOLAZO PRO"
	var tw := create_tween()
	tw.tween_property(_fade_rect, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(path))
	tw.tween_interval(0.5)
	tw.tween_property(_fade_rect, "modulate:a", 0.0, 0.45)


func flash_logo(title: String, duration := 0.9) -> void:
	_fade_label.text = title
	var tw := create_tween()
	tw.tween_property(_fade_rect, "modulate:a", 0.95, 0.2)
	tw.tween_interval(duration)
	tw.tween_property(_fade_rect, "modulate:a", 0.0, 0.3)


# ------------------------------------------------------------ Guardado

func save_session() -> void:
	if session.is_empty() or session_slot == "":
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(SAVE_DIR.path_join(session_slot + ".json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(session))
	# Las carreras modifican la base (fichajes, evolución): se guarda también
	if str(session.get("type", "")) in ["master", "legend"]:
		DB.save()


func load_session(slot: String) -> bool:
	var f := FileAccess.open(SAVE_DIR.path_join(slot + ".json"), FileAccess.READ)
	if f == null:
		return false
	var v: Variant = JSON.parse_string(f.get_as_text())
	if v is Dictionary:
		session = v
		session_slot = slot
		return true
	return false


func list_saves(prefix: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(SAVE_DIR)
	if d == null:
		return out
	for fn in d.get_files():
		if fn.begins_with(prefix) and fn.ends_with(".json"):
			out.append(fn.trim_suffix(".json"))
	out.sort()
	return out


func delete_save(slot: String) -> void:
	DirAccess.remove_absolute(SAVE_DIR.path_join(slot + ".json"))
