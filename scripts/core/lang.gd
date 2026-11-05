extends Node
## Textos traducibles. Se cargan desde data/lang/<idioma>.json.
## Uso: Lang.t("clave") o Lang.t("clave_con_{x}", {"x": 3}).

var language := "es"
var _texts: Dictionary = {}


func _ready() -> void:
	load_language(language)


func load_language(code: String) -> void:
	var path := "res://data/lang/%s.json" % code
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("No se encontró el archivo de idioma: " + path)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_texts = parsed
		language = code


func t(key: String, args: Dictionary = {}) -> String:
	var s: String = str(_texts.get(key, key))
	if not args.is_empty():
		s = s.format(args)
	return s
