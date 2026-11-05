class_name Competition
## Motor de competiciones sobre diccionarios serializables (para guardar en JSON):
## liga a doble vuelta, copa (eliminatoria directa o grupos + eliminatoria), torneo de
## selecciones de 32 equipos. Tabla, goleadores, asistencias, tarjetas y sanciones.
## Los partidos sin humanos se simulan según la fuerza de los equipos.

const STAGE_NAMES := {1: "Final", 2: "Semifinales", 4: "Cuartos de final", 8: "Octavos de final", 16: "Dieciseisavos", 32: "Treintaidosavos"}


static func create_league(name: String, team_ids: Array, human_ids: Array, double_round := true) -> Dictionary:
	var c := _base("league", name, team_ids, human_ids)
	c["rounds"] = _round_robin(team_ids, double_round)
	c["table"] = _new_table(team_ids)
	return c


static func create_cup(name: String, team_ids: Array, human_ids: Array, with_groups := false) -> Dictionary:
	var c := _base("cup", name, team_ids, human_ids)
	c["needs_winner"] = true
	if with_groups and team_ids.size() >= 8:
		_setup_groups(c, team_ids)
	else:
		c["rounds"] = [_ko_round(_shuffled(team_ids))]
	return c


static func create_world(name: String, nation_ids: Array, human_ids: Array) -> Dictionary:
	var c := _base("world", name, nation_ids, human_ids)
	c["needs_winner"] = true
	# Bombos por fuerza
	var sorted := nation_ids.duplicate()
	sorted.sort_custom(func(a, b) -> bool: return DB.team_strength(a) > DB.team_strength(b))
	var pots := [sorted.slice(0, 8), sorted.slice(8, 16), sorted.slice(16, 24), sorted.slice(24, 32)]
	for pot in pots:
		pot.shuffle()
	var ordered: Array = []
	for g in 8:
		for pot in pots:
			if g < pot.size():
				ordered.append(pot[g])
	_setup_groups(c, ordered, 4, false)
	return c


static func _base(type: String, name: String, team_ids: Array, human_ids: Array) -> Dictionary:
	return {"type": type, "name": name, "teams": team_ids.duplicate(), "human": human_ids.duplicate(),
		"rounds": [], "current_round": 0, "table": {}, "groups": {}, "scorers": {}, "assists": {},
		"cards": {}, "suspensions": {}, "winner": "", "needs_winner": false, "stage": "league", "history": []}


static func _shuffled(a: Array) -> Array:
	var b := a.duplicate()
	b.shuffle()
	return b


static func _new_table(ids: Array) -> Dictionary:
	var t := {}
	for id in ids:
		t[id] = {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
	return t


static func _fixture(h: String, a: String, stage: String) -> Dictionary:
	return {"h": h, "a": a, "hg": -1, "ag": -1, "pen": [], "played": false, "stage": stage, "events": []}


## Calendario todos contra todos (método del círculo).
static func _round_robin(ids: Array, double_round: bool, stage := "league") -> Array:
	var teams := ids.duplicate()
	if teams.size() % 2 == 1:
		teams.append("")
	var n := teams.size()
	var rounds: Array = []
	for r in n - 1:
		var round: Array = []
		for i in n / 2:
			var h: String = teams[i]
			var a: String = teams[n - 1 - i]
			if h == "" or a == "":
				continue
			if r % 2 == 1:
				round.append(_fixture(a, h, stage))
			else:
				round.append(_fixture(h, a, stage))
		rounds.append(round)
		teams.insert(1, teams.pop_back())
	if double_round:
		var second: Array = []
		for round in rounds:
			var r2: Array = []
			for f in round:
				r2.append(_fixture(f["a"], f["h"], stage))
			second.append(r2)
		rounds.append_array(second)
	return rounds


static func _setup_groups(c: Dictionary, ids: Array, size := 4, shuffle := true) -> void:
	var list := _shuffled(ids) if shuffle else ids.duplicate()
	var letters := "ABCDEFGHIJKLMNOP"
	var groups := {}
	var g := 0
	while list.size() > 0:
		var key := letters[g]
		groups[key] = list.slice(0, size)
		list = list.slice(size)
		g += 1
	c["groups"] = {}
	var rounds: Array = []
	for key in groups:
		c["groups"][key] = {"teams": groups[key], "table": _new_table(groups[key])}
		var rr := _round_robin(groups[key], false, "group_" + key)
		for i in rr.size():
			if rounds.size() <= i:
				rounds.append([])
			rounds[i].append_array(rr[i])
	c["rounds"] = rounds
	c["stage"] = "groups"
	c["group_rounds"] = rounds.size()


static func _ko_round(ids: Array) -> Array:
	var n := 1
	while n < ids.size():
		n *= 2
	var stage: String = STAGE_NAMES.get(n / 2, "Eliminatoria")
	var round: Array = []
	var list := ids.duplicate()
	# Exentos (byes) si no es potencia de 2: pasan directamente
	var byes := n - list.size()
	var bye_teams: Array = list.slice(0, byes)
	list = list.slice(byes)
	for i in range(0, list.size(), 2):
		round.append(_fixture(list[i], list[i + 1], stage))
	for b in bye_teams:
		var f := _fixture(b, "", stage)
		f["played"] = true
		f["hg"] = 1
		f["ag"] = 0
		round.append(f)
	return round


# --------------------------------------------------------------- Juego

static func current_fixtures(c: Dictionary) -> Array:
	var r: int = c["current_round"]
	if r >= c["rounds"].size():
		return []
	return c["rounds"][r]


static func human_fixture(c: Dictionary) -> Dictionary:
	for f in current_fixtures(c):
		if not f["played"] and (c["human"].has(f["h"]) or c["human"].has(f["a"])):
			return f
	return {}


static func is_finished(c: Dictionary) -> bool:
	return c.get("winner", "") != ""


## Simula todos los partidos pendientes de la jornada salvo los de humanos.
static func simulate_round_others(c: Dictionary) -> void:
	for f in current_fixtures(c):
		if not f["played"] and not (c["human"].has(f["h"]) or c["human"].has(f["a"])):
			apply_result(c, f, simulate(f["h"], f["a"], is_knockout(f)))


static func is_knockout(f: Dictionary) -> bool:
	var s := str(f.get("stage", ""))
	return not (s == "league" or s.begins_with("group_"))


## Resultado simulado: {hg, ag, pen:[], scorers:[{pid,team,assist}], cards:[{pid,red}]}
static func simulate(h: String, a: String, knockout: bool) -> Dictionary:
	var sh := DB.team_strength(h)
	var sa := DB.team_strength(a)
	var lh := clampf(1.4 * pow((sh + 1.5) / maxf(sa, 1.0), 4.0), 0.2, 4.5)
	var la := clampf(1.1 * pow(sa / maxf(sh + 1.5, 1.0), 4.0), 0.15, 4.0)
	var res := {"hg": _poisson(lh), "ag": _poisson(la), "pen": [], "scorers": [], "cards": []}
	if knockout and res["hg"] == res["ag"]:
		# Prórroga y penales
		res["hg"] += _poisson(lh * 0.3)
		res["ag"] += _poisson(la * 0.3)
		if res["hg"] == res["ag"]:
			var ph := randi_range(2, 5)
			var pa := ph + (1 if randf() < 0.5 else -1)
			res["pen"] = [ph, maxi(pa, 0)]
	for side in [[h, res["hg"]], [a, res["ag"]]]:
		for i in int(side[1]):
			var sc := _pick_scorer(side[0])
			var asst := _pick_scorer(side[0], true)
			if not sc.is_empty():
				res["scorers"].append({"pid": sc["id"], "team": side[0], "assist": asst.get("id", "") if asst.get("id", "") != sc["id"] else ""})
		if randf() < 0.85:
			for i in randi_range(0, 3):
				var pl := _random_player(side[0])
				if not pl.is_empty():
					res["cards"].append({"pid": pl["id"], "red": randf() < 0.04})
	return res


static func _poisson(l: float) -> int:
	var L := exp(-l)
	var k := 0
	var p := 1.0
	while true:
		p *= randf()
		if p <= L:
			break
		k += 1
	return k


static func _pick_scorer(team_id: String, assist := false) -> Dictionary:
	var t := DB.team(team_id)
	var ids: Array = t.get("lineup", t.get("players", []))
	var total := 0.0
	var weights: Array = []
	for pid in ids:
		var p: Dictionary = DB.players.get(pid, {})
		var w := 0.0
		if p.is_empty():
			weights.append(0.0)
			continue
		var pos := str(p["position"])
		if assist:
			w = {"AMF": 4.0, "RWF": 3.5, "LWF": 3.5, "CMF": 2.5, "RMF": 3.0, "LMF": 3.0, "CF": 2.0, "SS": 3.0, "RB": 1.5, "LB": 1.5}.get(pos, 0.4)
		else:
			w = {"CF": 6.0, "SS": 4.5, "RWF": 3.5, "LWF": 3.5, "AMF": 3.0, "RMF": 2.0, "LMF": 2.0, "CMF": 1.2, "DMF": 0.6, "CB": 0.5, "RB": 0.4, "LB": 0.4}.get(pos, 0.0)
		w *= pow(float(p.get("ovr", 60)) / 70.0, 3.0)
		weights.append(w)
		total += w
	if total <= 0.0:
		return {}
	var x := randf() * total
	for i in ids.size():
		x -= weights[i]
		if x <= 0.0:
			return DB.players.get(ids[i], {})
	return {}


static func _random_player(team_id: String) -> Dictionary:
	var ids: Array = DB.team(team_id).get("lineup", [])
	if ids.is_empty():
		return {}
	return DB.players.get(ids[randi() % ids.size()], {})


## Aplica un resultado (jugado o simulado) a la competición.
static func apply_result(c: Dictionary, f: Dictionary, res: Dictionary) -> void:
	f["hg"] = int(res["hg"])
	f["ag"] = int(res["ag"])
	f["pen"] = res.get("pen", [])
	f["played"] = true
	f["events"] = res.get("scorers", [])
	var stage := str(f["stage"])
	if stage == "league":
		_update_table(c["table"], f)
	elif stage.begins_with("group_"):
		_update_table(c["groups"][stage.substr(6)]["table"], f)
	for s in res.get("scorers", []):
		c["scorers"][s["pid"]] = int(c["scorers"].get(s["pid"], 0)) + 1
		if str(s.get("assist", "")) != "":
			c["assists"][s["assist"]] = int(c["assists"].get(s["assist"], 0)) + 1
	# Sanciones: se cumplen en el siguiente partido de su equipo
	for tid in [f["h"], f["a"]]:
		for pid in c["suspensions"].keys():
			var p: Dictionary = DB.players.get(pid, {})
			if not p.is_empty() and p.get("team") == tid and int(c["suspensions"][pid]) > 0:
				c["suspensions"][pid] = int(c["suspensions"][pid]) - 1
	for card in res.get("cards", []):
		var pid: String = card["pid"]
		var rec: Dictionary = c["cards"].get(pid, {"y": 0, "r": 0})
		if card.get("red", false):
			rec["r"] += 1
			c["suspensions"][pid] = int(c["suspensions"].get(pid, 0)) + (1 if randf() < 0.7 else 2)
		else:
			rec["y"] += 1
			if rec["y"] % 5 == 0:
				c["suspensions"][pid] = int(c["suspensions"].get(pid, 0)) + 1
		c["cards"][pid] = rec


static func _update_table(t: Dictionary, f: Dictionary) -> void:
	for side in [["h", "hg", "ag"], ["a", "ag", "hg"]]:
		var id: String = f[side[0]]
		if not t.has(id):
			continue
		var r: Dictionary = t[id]
		var gf: int = f[side[1]]
		var ga: int = f[side[2]]
		r["p"] += 1
		r["gf"] += gf
		r["ga"] += ga
		if gf > ga:
			r["w"] += 1
			r["pts"] += 3
		elif gf == ga:
			r["d"] += 1
			r["pts"] += 1
		else:
			r["l"] += 1


static func standings(table: Dictionary) -> Array:
	var ids := table.keys()
	ids.sort_custom(func(a, b) -> bool:
		var ra: Dictionary = table[a]
		var rb: Dictionary = table[b]
		if ra["pts"] != rb["pts"]:
			return ra["pts"] > rb["pts"]
		var da: int = ra["gf"] - ra["ga"]
		var db: int = rb["gf"] - rb["ga"]
		if da != db:
			return da > db
		return ra["gf"] > rb["gf"])
	return ids


static func winner_of(f: Dictionary) -> String:
	if f["a"] == "":
		return f["h"]
	if f["hg"] != f["ag"]:
		return f["h"] if f["hg"] > f["ag"] else f["a"]
	var pen: Array = f.get("pen", [])
	if pen.size() == 2:
		return f["h"] if pen[0] > pen[1] else f["a"]
	return f["h"]


## Pasa de jornada cuando todo está jugado. Devuelve true si avanzó.
static func advance(c: Dictionary) -> bool:
	for f in current_fixtures(c):
		if not f["played"]:
			return false
	c["current_round"] += 1
	if c["current_round"] < c["rounds"].size():
		return true
	# Fin de las jornadas programadas
	match c["type"]:
		"league":
			var st := standings(c["table"])
			c["winner"] = st[0]
		_:
			if c["stage"] == "groups":
				var qualified: Array = []
				var seconds: Array = []
				for key in c["groups"]:
					var st2 := standings(c["groups"][key]["table"])
					qualified.append(st2[0])
					if st2.size() > 1:
						seconds.append(st2[1])
				# Cruces: 1º de un grupo contra 2º del siguiente
				var order: Array = []
				for i in qualified.size():
					order.append(qualified[i])
					order.append(seconds[(i + 1) % seconds.size()])
				c["stage"] = "ko"
				c["rounds"].append(_ko_round(order))
			else:
				var last: Array = c["rounds"][c["rounds"].size() - 1]
				var winners: Array = []
				for f in last:
					winners.append(winner_of(f))
				if winners.size() == 1:
					c["winner"] = winners[0]
				else:
					c["rounds"].append(_pair_round(winners))
	return true


static func _pair_round(ids: Array) -> Array:
	var stage: String = STAGE_NAMES.get(ids.size() / 2, "Eliminatoria")
	var round: Array = []
	for i in range(0, ids.size() - 1, 2):
		round.append(_fixture(ids[i], ids[i + 1], stage))
	return round


static func top_list(d: Dictionary, n := 15) -> Array:
	var ids := d.keys()
	ids.sort_custom(func(a, b) -> bool: return int(d[a]) > int(d[b]))
	return ids.slice(0, n)


static func round_title(c: Dictionary) -> String:
	var f := current_fixtures(c)
	if f.is_empty():
		return "Finalizada"
	var stage := str(f[0]["stage"])
	if stage == "league":
		return "Jornada %d de %d" % [c["current_round"] + 1, c["rounds"].size()]
	if stage.begins_with("group_"):
		return "Fase de grupos · Jornada %d" % [c["current_round"] + 1]
	return stage
