extends Node
## Base de datos del juego (autoload "DB"). Carga data/db/database.json (o la copia editada
## del usuario en user://db/database.json) en un hilo aparte, indexa jugadores/equipos/
## selecciones y ofrece edición, traspasos, importación y exportación.

signal loaded
signal changed

const BASE_PATH := "res://data/db/database.json"
const USER_PATH := "user://db/database.json"
const EXPORT_DIR_NAME := "GolazoPro"

var data: Dictionary = {}
var players: Dictionary = {}     # id -> jugador
var teams: Dictionary = {}       # id -> club o selección
var leagues: Array = []
var nations: Array = []
var is_loaded := false
var load_error := ""
var _thread: Thread


func _ready() -> void:
	load_async()


func load_async() -> void:
	is_loaded = false
	_thread = Thread.new()
	_thread.start(_load_thread)


func _load_thread() -> void:
	var path := USER_PATH if FileAccess.file_exists(USER_PATH) else BASE_PATH
	var d := _read_json(path)
	if d.is_empty() and path == USER_PATH:
		d = _read_json(BASE_PATH)
	call_deferred("_finish_load", d)


func _finish_load(d: Dictionary) -> void:
	if _thread:
		_thread.wait_to_finish()
		_thread = null
	_set_data(d)
	is_loaded = true
	loaded.emit()


## Carga síncrona (pruebas sin pantalla).
func load_now() -> void:
	var path := USER_PATH if FileAccess.file_exists(USER_PATH) else BASE_PATH
	_set_data(_read_json(path))
	is_loaded = true


func _set_data(d: Dictionary) -> void:
	data = d
	players.clear()
	teams.clear()
	for p in data.get("players", []):
		players[p["id"]] = p
	for t in data.get("teams", []):
		teams[t["id"]] = t
	for n in data.get("nations", []):
		teams[n["id"]] = n
	leagues = data.get("leagues", [])
	nations = data.get("nations", [])
	if data.is_empty():
		load_error = "No se pudo leer la base de datos"


static func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


# ------------------------------------------------------------ Consultas

func league(id: String) -> Dictionary:
	for l in leagues:
		if l["id"] == id:
			return l
	return {}


func team(id: String) -> Dictionary:
	return teams.get(id, {})


func is_nation(id: String) -> bool:
	return id.begins_with("nat_")


func team_players(id: String) -> Array:
	var out: Array = []
	for pid in team(id).get("players", []):
		if players.has(pid):
			out.append(players[pid])
	return out


func team_strength(id: String) -> float:
	var t := team(id)
	var ids: Array = t.get("lineup", [])
	if ids.is_empty():
		ids = t.get("players", [])
	var sum := 0.0
	var n := 0
	for pid in ids:
		if players.has(pid):
			sum += float(players[pid].get("ovr", 60))
			n += 1
	return sum / maxf(n, 1.0)


## Equipo listo para el partido: {name, short, formation, kits, lineup, players:[dicts], crest, stadium}
func match_team(id: String, lineup_override: Array = [], formation_override := "") -> Dictionary:
	var t := team(id).duplicate(true)
	t["players"] = team_players(id)
	if not lineup_override.is_empty():
		t["lineup"] = lineup_override
	if formation_override != "":
		t["formation"] = formation_override
	return t


func search_players(text: String, limit := 60) -> Array:
	var out: Array = []
	var q := text.to_lower()
	for p in players.values():
		if q == "" or str(p["name"]).to_lower().contains(q):
			out.append(p)
			if out.size() >= limit:
				break
	return out


func best_lineup(team_id: String, formation: String) -> Array:
	var t := team(team_id)
	var pls := team_players(team_id)
	var slots := Formations.slots(formation)
	var used := {}
	var out: Array = []
	for s in slots:
		var role: String = s[0]
		var best: Dictionary = {}
		for pass_i in 3:
			for p in pls:
				if used.has(p["id"]) or int(p.get("injured", 0)) > 0 or int(p.get("suspended", 0)) > 0:
					continue
				var pos := str(p["position"])
				var ok: bool = (pass_i == 0 and pos == role) or (pass_i == 1 and Formations.SIMILAR.get(role, [role]).has(pos)) or (pass_i == 2 and (pos == "GK") == (role == "GK"))
				if ok and (best.is_empty() or int(p["ovr"]) > int(best["ovr"])):
					best = p
			if not best.is_empty():
				break
		if best.is_empty():
			for p in pls:
				if not used.has(p["id"]):
					best = p
					break
		if not best.is_empty():
			used[best["id"]] = true
			out.append(best["id"])
	t["lineup"] = out
	return out


# ------------------------------------------------------------- Edición

func new_id(prefix: String) -> String:
	var i := 1
	while players.has("%s_%d" % [prefix, i]) or teams.has("%s_%d" % [prefix, i]):
		i += 1
	return "%s_%d" % [prefix, i]


func create_player(team_id: String, base: Dictionary = {}) -> Dictionary:
	var p := {
		"id": new_id("custom"), "name": "Nuevo Jugador", "nation": "ESP", "position": "CMF", "number": 99,
		"foot": "right", "age": 20, "height": 178, "ovr": 65, "speed": 65, "acceleration": 65, "shot_accuracy": 60,
		"shot_power": 62, "short_pass": 65, "long_pass": 62, "dribbling": 64, "ball_control": 65, "defense": 50,
		"heading": 55, "physical": 62, "stamina": 70, "curl": 58, "agility": 66, "reflexes": 40, "positioning": 40,
		"appearance": {"skin": "#e0ac83", "hair_style": 1, "hair_color": "#2b1d14", "beard": 0, "build": 0.5, "boots": "#111111"},
		"team": team_id if team_id != "" else null, "value": 0.5, "wage": 0.05, "contract": int(data.get("season", 2026)) + 3, "potential": 75,
	}
	p.merge(base, true)
	data["players"].append(p)
	players[p["id"]] = p
	if team_id != "" and teams.has(team_id):
		teams[team_id]["players"].append(p["id"])
	changed.emit()
	return p


func delete_player(pid: String) -> void:
	if not players.has(pid):
		return
	for t in teams.values():
		t["players"].erase(pid)
		t.get("lineup", []).erase(pid)
	data["players"].erase(players[pid])
	players.erase(pid)
	changed.emit()


## Traspasa un jugador de su club a otro (las selecciones no cambian).
func transfer(pid: String, to_team: String) -> void:
	var p: Dictionary = players.get(pid, {})
	if p.is_empty():
		return
	var from = p.get("team")
	if from != null and teams.has(from):
		teams[from]["players"].erase(pid)
		teams[from].get("lineup", []).erase(pid)
		if teams[from].get("lineup", []).size() < 11:
			best_lineup(from, teams[from].get("formation", "4-3-3"))
	p["team"] = to_team if to_team != "" else null
	if to_team != "" and teams.has(to_team):
		teams[to_team]["players"].append(pid)
	changed.emit()


func recompute_ovr(p: Dictionary) -> void:
	var pos := str(p.get("position", "CMF"))
	var w: Dictionary = {"GK": {"reflexes": 3, "positioning": 3, "physical": 1},
		"CB": {"defense": 3, "heading": 2, "physical": 2, "speed": 1},
		"RB": {"defense": 2, "speed": 2, "stamina": 1, "short_pass": 1}, "LB": {"defense": 2, "speed": 2, "stamina": 1, "short_pass": 1},
		"DMF": {"defense": 2, "short_pass": 2, "stamina": 1, "physical": 1}, "CMF": {"short_pass": 3, "long_pass": 1, "ball_control": 1, "stamina": 1},
		"AMF": {"short_pass": 2, "dribbling": 2, "ball_control": 2, "shot_accuracy": 1},
		"RMF": {"speed": 2, "dribbling": 2, "short_pass": 1}, "LMF": {"speed": 2, "dribbling": 2, "short_pass": 1},
		"RWF": {"speed": 2, "dribbling": 2, "shot_accuracy": 1, "acceleration": 1}, "LWF": {"speed": 2, "dribbling": 2, "shot_accuracy": 1, "acceleration": 1},
		"SS": {"shot_accuracy": 2, "dribbling": 2, "ball_control": 1}, "CF": {"shot_accuracy": 3, "shot_power": 1, "heading": 1, "ball_control": 1}}.get(pos, {"short_pass": 1})
	var sum := 0.0
	var tw := 0.0
	for k in w:
		sum += float(p.get(k, 60)) * w[k]
		tw += w[k]
	p["ovr"] = int(round(sum / tw))


func save() -> bool:
	DirAccess.make_dir_recursive_absolute("user://db")
	var f := FileAccess.open(USER_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


func reset_to_original() -> void:
	if FileAccess.file_exists(USER_PATH):
		DirAccess.remove_absolute(USER_PATH)
	load_now()
	changed.emit()


# --------------------------------------------------- Importar / exportar

## Carpeta pública del teléfono (Documentos/GolazoPro). En Android pide permisos.
func export_dir() -> String:
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs == "":
		docs = OS.get_user_data_dir()
	return docs.path_join(EXPORT_DIR_NAME)


func request_storage_permission() -> void:
	if OS.get_name() == "Android":
		OS.request_permissions()


func export_database(file_name := "database.json") -> String:
	request_storage_permission()
	var dir := export_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(file_name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	return path


func list_importable() -> Array:
	request_storage_permission()
	var out: Array = []
	var d := DirAccess.open(export_dir())
	if d == null:
		return out
	for fn in d.get_files():
		if fn.to_lower().ends_with(".json"):
			out.append(export_dir().path_join(fn))
	return out


## Importa una base completa o parcial. Una base parcial (solo "players" y/o "teams")
## actualiza o añade esos registros por id (útil para actualizar fichajes).
func import_database(path: String) -> String:
	var d := _read_json(path)
	if d.is_empty():
		return "El archivo no es un JSON válido"
	if d.has("leagues") and d.has("teams") and d.has("players") and d.has("nations"):
		_set_data(d)
	else:
		for p in d.get("players", []):
			if not p.has("id"):
				continue
			if players.has(p["id"]):
				var old: Dictionary = players[p["id"]]
				if p.has("team") and p["team"] != old.get("team"):
					transfer(p["id"], str(p["team"]) if p["team"] != null else "")
				old.merge(p, true)
			else:
				data["players"].append(p)
				players[p["id"]] = p
				if p.get("team") != null and teams.has(p["team"]):
					teams[p["team"]]["players"].append(p["id"])
		for t in d.get("teams", []):
			if t.has("id") and teams.has(t["id"]):
				teams[t["id"]].merge(t, true)
	save()
	changed.emit()
	return ""
