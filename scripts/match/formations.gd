class_name Formations
## Formaciones: 11 casillas [rol, profundidad 0..1 (0 = línea defensiva, 1 = delantera),
## anchura -1..1 (positivo = derecha según la dirección de ataque)].

const DATA := {
	"4-4-2": [["GK", 0.0, 0.0], ["RB", 0.06, 0.82], ["CB", 0.0, 0.28], ["CB", 0.0, -0.28], ["LB", 0.06, -0.82],
		["RMF", 0.5, 0.8], ["CMF", 0.42, 0.24], ["CMF", 0.42, -0.24], ["LMF", 0.5, -0.8],
		["CF", 0.9, 0.2], ["CF", 0.9, -0.2]],
	"4-3-3": [["GK", 0.0, 0.0], ["RB", 0.06, 0.82], ["CB", 0.0, 0.28], ["CB", 0.0, -0.28], ["LB", 0.06, -0.82],
		["DMF", 0.3, 0.0], ["CMF", 0.48, 0.38], ["CMF", 0.48, -0.38],
		["RWF", 0.85, 0.75], ["CF", 0.95, 0.0], ["LWF", 0.85, -0.75]],
	"4-2-3-1": [["GK", 0.0, 0.0], ["RB", 0.06, 0.82], ["CB", 0.0, 0.28], ["CB", 0.0, -0.28], ["LB", 0.06, -0.82],
		["DMF", 0.3, 0.22], ["DMF", 0.3, -0.22], ["RMF", 0.66, 0.72], ["AMF", 0.66, 0.0], ["LMF", 0.66, -0.72],
		["CF", 0.95, 0.0]],
	"3-5-2": [["GK", 0.0, 0.0], ["CB", 0.0, 0.45], ["CB", 0.0, 0.0], ["CB", 0.0, -0.45],
		["RMF", 0.5, 0.88], ["DMF", 0.32, 0.0], ["CMF", 0.48, 0.32], ["CMF", 0.48, -0.32], ["LMF", 0.5, -0.88],
		["CF", 0.9, 0.2], ["CF", 0.9, -0.2]],
	"5-3-2": [["GK", 0.0, 0.0], ["RB", 0.12, 0.88], ["CB", 0.0, 0.42], ["CB", 0.0, 0.0], ["CB", 0.0, -0.42],
		["LB", 0.12, -0.88], ["CMF", 0.45, 0.4], ["CMF", 0.4, 0.0], ["CMF", 0.45, -0.4],
		["CF", 0.88, 0.2], ["CF", 0.88, -0.2]],
}

## Afinidad de posiciones para elegir quién ocupa cada casilla.
const SIMILAR := {
	"GK": ["GK"], "CB": ["CB", "DMF"], "RB": ["RB", "RMF", "CB"], "LB": ["LB", "LMF", "CB"],
	"DMF": ["DMF", "CMF", "CB"], "CMF": ["CMF", "DMF", "AMF"], "AMF": ["AMF", "CMF", "SS"],
	"RMF": ["RMF", "RWF", "RB"], "LMF": ["LMF", "LWF", "LB"], "RWF": ["RWF", "RMF", "CF"],
	"LWF": ["LWF", "LMF", "CF"], "CF": ["CF", "SS", "RWF", "LWF"], "SS": ["SS", "CF", "AMF"],
}


## Formaciones personalizadas registradas en tiempo de ejecución (nombre -> casillas).
static var custom: Dictionary = {}


static func slots(name: String) -> Array:
	if custom.has(name):
		return custom[name]
	return DATA.get(name, DATA["4-3-3"])


static func register_custom(name: String, s: Array) -> void:
	custom[name] = s


static func names() -> Array:
	return DATA.keys()


static func role_group(role: String) -> String:
	match role:
		"GK": return "GK"
		"CB", "RB", "LB": return "DEF"
		"DMF", "CMF", "AMF", "RMF", "LMF": return "MID"
		_: return "FWD"
