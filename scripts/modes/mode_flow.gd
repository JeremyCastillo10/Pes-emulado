class_name ModeFlow
## Aplica el resultado de un partido jugado al modo activo (liga, copa, torneo, Liga Máster,
## Ser una Leyenda) y hace avanzar el calendario. Todo trabaja sobre Game.session.


static func apply(session: Dictionary, result: Dictionary) -> void:
	var t := str(session.get("type", ""))
	match t:
		"league", "cup", "world":
			_apply_comp(session["comp"], result)
		"master":
			MasterLeague.on_match(session, result)
		"legend":
			LegendMode.on_match(session, result)


## Busca el partido del humano en la jornada actual, lo registra, simula el resto y avanza.
static func _apply_comp(c: Dictionary, result: Dictionary) -> void:
	var f := Competition.human_fixture(c)
	if f.is_empty():
		return
	var res := {"hg": result["hg"], "ag": result["ag"], "pen": result.get("pen", []),
		"scorers": result.get("scorers", []), "cards": result.get("cards", [])}
	# Si el humano jugaba como visitante en el calendario pero el partido se jugó invertido
	if f["h"] != result.get("home", f["h"]):
		res = {"hg": result["ag"], "ag": result["hg"], "pen": (result.get("pen", []) as Array).duplicate(),
			"scorers": result.get("scorers", []), "cards": result.get("cards", [])}
		if res["pen"].size() == 2:
			res["pen"].reverse()
	Competition.apply_result(c, f, res)
	Competition.simulate_round_others(c)
	Competition.advance(c)


## Configuración del siguiente partido del humano en una competición.
static func next_match_config(c: Dictionary, title: String) -> Dictionary:
	var f := Competition.human_fixture(c)
	if f.is_empty():
		return {}
	var hum: Array = c["human"]
	var h_is_human: bool = hum.has(f["h"])
	var a_is_human: bool = hum.has(f["a"])
	var cfg := {
		"mode": c["type"], "home": f["h"], "away": f["a"], "human_home": h_is_human, "human_away": a_is_human,
		"two_players": h_is_human and a_is_human,
		"needs_winner": Competition.is_knockout(f), "competition_name": title + " · " + Competition.round_title(c),
		"stadium": DB.team(f["h"]).get("stadium", {}), "away_kit": "auto",
	}
	# Sancionados y lesionados fuera de la alineación
	for side in ["h", "a"]:
		var tid: String = f[side]
		var formation := str(DB.team(tid).get("formation", "4-3-3"))
		var lineup: Array = []
		var susp: Dictionary = c.get("suspensions", {})
		var pls := DB.team_players(tid)
		var ok := true
		for pid in DB.team(tid).get("lineup", []):
			if int(susp.get(pid, 0)) > 0 or int(DB.players.get(pid, {}).get("injured", 0)) > 0:
				ok = false
		if not ok:
			for p in pls:
				p["suspended"] = int(susp.get(p["id"], 0))
			lineup = DB.best_lineup(tid, formation)
			for p in pls:
				p.erase("suspended")
			cfg["home_lineup" if side == "h" else "away_lineup"] = lineup
	return cfg
