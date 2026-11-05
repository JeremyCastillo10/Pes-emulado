class_name MasterLeague
## Liga Máster: dirige un club durante varias temporadas. Liga + copa nacional por temporada,
## presupuesto, fichajes, cesiones, ventas, contratos, cantera, evolución y retiro de jugadores
## y objetivos de la directiva. Los datos se guardan en Game.session y en la base de datos.


static func new_career(club_id: String) -> Dictionary:
	var t := DB.team(club_id)
	var s := {"type": "master", "club": club_id, "season": int(DB.data.get("season", 2026)),
		"budget": float(t.get("budget", 20.0)), "board": {}, "news": [], "history": [], "loans": [],
		"since_cup": 0, "morale": 70, "fired": false, "pending": ""}
	_new_season_comps(s)
	_add_news(s, "¡Bienvenido a %s! La directiva espera %s." % [t.get("name", ""), objective_text(s)])
	return s


static func _new_season_comps(s: Dictionary) -> void:
	var t := DB.team(s["club"])
	var lg := DB.league(str(t.get("league", "")))
	s["comp"] = Competition.create_league(str(lg.get("name", "Liga")), lg.get("teams", []), [s["club"]])
	s["cup"] = Competition.create_cup("Copa " + str(lg.get("name", "")), lg.get("teams", []), [s["club"]], false)
	s["since_cup"] = 0
	# Objetivo según la fuerza relativa del club en su liga
	var ids: Array = lg.get("teams", []).duplicate()
	ids.sort_custom(func(a, b) -> bool: return DB.team_strength(a) > DB.team_strength(b))
	var rank := ids.find(s["club"]) + 1
	s["board"] = {"target": clampi(rank + 1, 1, ids.size()), "confidence": int(s["board"].get("confidence", 70)) if s["board"] is Dictionary and s["board"].has("confidence") else 70}


static func objective_text(s: Dictionary) -> String:
	var tg := int(s["board"].get("target", 10))
	if tg <= 1:
		return "ganar la liga"
	if tg <= 4:
		return "terminar entre los %d primeros" % tg
	return "terminar en el puesto %d o mejor" % tg


static func _add_news(s: Dictionary, text: String) -> void:
	s["news"].push_front(text)
	if s["news"].size() > 30:
		s["news"].resize(30)


## Qué competición toca ahora: "league", "cup" o "season_end".
static func current_key(s: Dictionary) -> String:
	var lg: Dictionary = s["comp"]
	var cup: Dictionary = s["cup"]
	_auto_progress(cup)
	var cup_ready := not Competition.is_finished(cup) and not Competition.human_fixture(cup).is_empty()
	if cup_ready and (int(s["since_cup"]) >= 4 or Competition.is_finished(lg)):
		return "cup"
	if not Competition.is_finished(lg):
		return "league"
	if cup_ready:
		return "cup"
	return "season_end"


## Si el humano ya fue eliminado de una copa, se simula sola.
static func _auto_progress(c: Dictionary) -> void:
	var guard := 0
	while not Competition.is_finished(c) and Competition.human_fixture(c).is_empty() and guard < 20:
		Competition.simulate_round_others(c)
		if not Competition.advance(c):
			break
		guard += 1


static func next_match_config(s: Dictionary) -> Dictionary:
	var key := current_key(s)
	if key == "season_end":
		return {}
	s["pending"] = key
	var c: Dictionary = s[key if key == "cup" else "comp"]
	var cfg := ModeFlow.next_match_config(c, c["name"])
	cfg["mode"] = "master"
	return cfg


static func on_match(s: Dictionary, result: Dictionary) -> void:
	var key := str(s.get("pending", "league"))
	var c: Dictionary = s["cup"] if key == "cup" else s["comp"]
	ModeFlow._apply_comp(c, result)
	s["since_cup"] = 0 if key == "cup" else int(s["since_cup"]) + 1
	var club: String = s["club"]
	var my_goals: int = result["hg"] if result["home"] == club else result["ag"]
	var their: int = result["ag"] if result["home"] == club else result["hg"]
	var t := DB.team(club)
	# Finanzas: taquilla, premios y salarios
	var prestige := int(t.get("prestige", 2))
	var income := 0.4 + prestige * 0.35 + (0.6 if my_goals > their else (0.2 if my_goals == their else 0.0))
	var wages := 0.0
	for p in DB.team_players(club):
		wages += float(p.get("wage", 0.1)) / 38.0
	s["budget"] = snappedf(float(s["budget"]) + income - wages, 0.01)
	s["morale"] = clampi(int(s["morale"]) + (6 if my_goals > their else (-1 if my_goals == their else -6)), 10, 100)
	# Evolución durante la temporada según la nota del partido
	for pid in result.get("ratings", {}).keys():
		var p: Dictionary = DB.players.get(pid, {})
		if p.is_empty() or p.get("team") != club:
			continue
		var r: float = result["ratings"][pid]
		if int(p.get("age", 25)) <= 24 and r >= 7.0 and randf() < 0.35 and int(p["ovr"]) < int(p.get("potential", 80)):
			_grow(p, 1)
	# Lesiones: algunos partidos de baja
	for pid in result.get("injuries", []):
		if DB.players.has(pid):
			DB.players[pid]["injured"] = randi_range(1, 4)
	for p in DB.team_players(club):
		if int(p.get("injured", 0)) > 0 and not result.get("injuries", []).has(p["id"]):
			p["injured"] = int(p["injured"]) - 1
	_add_news(s, "%s %d-%d %s" % [DB.team(result["home"]).get("short", ""), result["hg"], result["ag"], DB.team(result["away"]).get("short", "")])


static func _grow(p: Dictionary, amount: int) -> void:
	for k in ["speed", "acceleration", "shot_accuracy", "shot_power", "short_pass", "long_pass", "dribbling", "ball_control",
		"defense", "heading", "physical", "stamina", "curl", "agility", "reflexes", "positioning"]:
		if randf() < 0.55:
			p[k] = clampi(int(p.get(k, 60)) + amount, 25, 99)
	DB.recompute_ovr(p)
	p["value"] = _value_of(int(p["ovr"]), int(p.get("age", 25)))


static func _value_of(ovr: int, age: int) -> float:
	var af := 1.6 if age <= 21 else 1.3 if age <= 24 else 1.0 if age <= 28 else 0.65 if age <= 31 else 0.35
	return snappedf(maxf(0.2, 0.06 * pow(1.28, ovr - 60) * af), 0.1)


# --------------------------------------------------------- Mercado

static func market(s: Dictionary, position := "", max_value := 9999.0, text := "", limit := 80) -> Array:
	var out: Array = []
	for p in DB.players.values():
		if p.get("team") == s["club"]:
			continue
		if position != "" and p["position"] != position:
			continue
		if float(p.get("value", 0)) > max_value:
			continue
		if text != "" and not str(p["name"]).to_lower().contains(text.to_lower()):
			continue
		out.append(p)
	out.sort_custom(func(a, b) -> bool: return int(a["ovr"]) > int(b["ovr"]))
	return out.slice(0, limit)


## Oferta de compra. Devuelve "" si se cierra el fichaje o el motivo del rechazo.
static func buy(s: Dictionary, pid: String, fee: float) -> String:
	var p: Dictionary = DB.players.get(pid, {})
	if p.is_empty():
		return "Jugador no encontrado"
	if fee > float(s["budget"]):
		return "No hay presupuesto suficiente"
	var from = p.get("team")
	var my_pres := int(DB.team(s["club"]).get("prestige", 1))
	var his_pres := int(DB.team(from).get("prestige", 1)) if from != null else 0
	var needed := float(p.get("value", 1.0)) * (1.0 + maxf(0, his_pres - 2) * 0.12)
	if fee < needed * 0.92:
		return "El club rechaza la oferta (pide unos %.1f M)" % needed
	if his_pres - my_pres >= 2 and randf() < 0.7:
		return "El jugador no quiere bajar de nivel"
	DB.transfer(pid, s["club"])
	s["budget"] = snappedf(float(s["budget"]) - fee, 0.01)
	p["contract"] = int(s["season"]) + 4
	p["wage"] = snappedf(float(p.get("wage", 0.1)) * 1.15, 0.01)
	_add_news(s, "Fichaje: %s llega por %.1f M." % [p["name"], fee])
	return ""


static func loan_in(s: Dictionary, pid: String) -> String:
	var p: Dictionary = DB.players.get(pid, {})
	if p.is_empty() or p.get("team") == null:
		return "No disponible para cesión"
	var fee := snappedf(float(p.get("value", 1.0)) * 0.1, 0.1)
	if fee > float(s["budget"]):
		return "No hay presupuesto suficiente"
	if int(p.get("age", 25)) > 30 and randf() < 0.5:
		return "El club no lo cede"
	s["loans"].append({"pid": pid, "from": p["team"], "until": int(s["season"])})
	DB.transfer(pid, s["club"])
	s["budget"] = snappedf(float(s["budget"]) - fee, 0.01)
	_add_news(s, "Cesión: llega %s hasta final de temporada." % p["name"])
	return ""


static func sell(s: Dictionary, pid: String) -> String:
	var p: Dictionary = DB.players.get(pid, {})
	if p.is_empty() or p.get("team") != s["club"]:
		return "No es de tu club"
	if DB.team_players(s["club"]).size() <= 16:
		return "La plantilla quedaría demasiado corta"
	var buyers: Array = []
	for t in DB.data["teams"]:
		if t["id"] != s["club"] and float(t.get("budget", 0)) >= float(p.get("value", 0)) * 0.8:
			buyers.append(t)
	if buyers.is_empty():
		return "Nadie puede pagarlo ahora"
	var b: Dictionary = buyers[randi() % buyers.size()]
	var fee := snappedf(float(p.get("value", 1.0)) * randf_range(0.85, 1.2), 0.1)
	DB.transfer(pid, b["id"])
	s["budget"] = snappedf(float(s["budget"]) + fee, 0.01)
	_add_news(s, "Venta: %s se va a %s por %.1f M." % [p["name"], b["name"], fee])
	return ""


static func renew(s: Dictionary, pid: String, years: int) -> String:
	var p: Dictionary = DB.players.get(pid, {})
	if p.is_empty():
		return "Jugador no encontrado"
	if int(p.get("age", 25)) >= 34 and years > 1:
		return "Solo acepta un año más"
	p["contract"] = int(s["season"]) + years
	p["wage"] = snappedf(float(p.get("wage", 0.1)) * 1.2, 0.01)
	return ""


# --------------------------------------------------- Fin de temporada

## Cierra la temporada: premios, directiva, evolución por edad, retiros, contratos, cantera.
static func end_season(s: Dictionary) -> Array:
	var report: Array = []
	var club: String = s["club"]
	var st := Competition.standings(s["comp"]["table"])
	var pos := st.find(club) + 1
	var target := int(s["board"]["target"])
	var prize := maxf(1.0, (st.size() - pos + 1) * 0.8)
	s["budget"] = snappedf(float(s["budget"]) + prize, 0.01)
	report.append("Posición final: %dº (objetivo: %dº). Premio: %.1f M" % [pos, target, prize])
	var cup_w: String = s["cup"].get("winner", "")
	if cup_w == club:
		report.append("¡Campeón de copa!")
		s["budget"] = float(s["budget"]) + 3.0
	if st[0] == club:
		report.append("¡CAMPEÓN DE LIGA!")
	var conf := int(s["board"].get("confidence", 70)) + (target - pos) * 6
	conf = clampi(conf, 0, 100)
	s["board"]["confidence"] = conf
	if conf <= 15:
		s["fired"] = true
		report.append("La directiva ha decidido prescindir de ti.")
	s["history"].append({"season": s["season"], "pos": pos, "cup": cup_w == club})
	# Cesiones que terminan
	for l in s["loans"]:
		if DB.players.has(l["pid"]):
			DB.transfer(l["pid"], l["from"])
	s["loans"] = []
	# Edad, evolución y retiros (toda la base)
	var retired := 0
	for p in DB.players.values().duplicate():
		var age := int(p.get("age", 25)) + 1
		p["age"] = age
		p["injured"] = 0
		var delta := 0
		if age <= 21:
			delta = randi_range(1, 4)
		elif age <= 24:
			delta = randi_range(0, 3)
		elif age <= 29:
			delta = randi_range(-1, 1)
		elif age <= 32:
			delta = randi_range(-2, 0)
		else:
			delta = randi_range(-4, -1)
		if delta > 0 and int(p["ovr"]) >= int(p.get("potential", 80)):
			delta = 0
		if delta != 0:
			_grow(p, delta)
		if age >= 38 or (age >= 34 and randf() < (age - 33) * 0.18):
			if p.get("team") == club:
				report.append("Se retira %s (%d años)." % [p["name"], age])
			_retire(p)
			retired += 1
	# Contratos que vencen en tu club
	for p in DB.team_players(club).duplicate():
		if int(p.get("contract", 9999)) <= int(s["season"]):
			report.append("%s termina contrato y se marcha." % p["name"])
			DB.transfer(p["id"], "")
	# Cantera
	for i in randi_range(2, 3):
		var pos_name: String = ["CB", "CMF", "RWF", "CF", "LB", "GK", "AMF"][randi() % 7]
		var y := DB.create_player(club, {"name": _youth_name(), "position": pos_name, "age": randi_range(16, 18),
			"nation": DB.team(club).get("country", "ESP"), "potential": randi_range(70, 90), "generic": true})
		var base := randi_range(52, 64)
		for k in ["speed", "acceleration", "shot_accuracy", "shot_power", "short_pass", "long_pass", "dribbling", "ball_control",
			"defense", "heading", "physical", "stamina", "curl", "agility"]:
			y[k] = clampi(base + randi_range(-8, 8), 30, 80)
		if pos_name == "GK":
			y["reflexes"] = base + 5
			y["positioning"] = base + 3
		DB.recompute_ovr(y)
		report.append("Cantera: sube %s (%s, %d años, %d)." % [y["name"], pos_name, y["age"], y["ovr"]])
	# Movimientos entre clubes de la IA
	_ai_transfers(club, report)
	s["season"] = int(s["season"]) + 1
	DB.data["season"] = s["season"]
	_new_season_comps(s)
	report.append("Retirados en todo el mundo: %d. Nueva temporada %d. Objetivo: %s." % [retired, s["season"], objective_text(s)])
	for r in report:
		_add_news(s, r)
	return report


static func _retire(p: Dictionary) -> void:
	var team_id = p.get("team")
	var pos := str(p.get("position", "CMF"))
	DB.delete_player(p["id"])
	# Reemplazo genérico en clubes de la IA para no vaciar plantillas
	if team_id != null and DB.teams.has(team_id):
		var r := DB.create_player(team_id, {"name": _youth_name(), "position": pos, "age": randi_range(18, 22), "generic": true,
			"potential": randi_range(65, 82)})
		var base := int(DB.team_strength(team_id)) - randi_range(6, 12)
		for k in ["speed", "acceleration", "shot_accuracy", "shot_power", "short_pass", "long_pass", "dribbling", "ball_control",
			"defense", "heading", "physical", "stamina", "curl", "agility"]:
			r[k] = clampi(base + randi_range(-8, 8), 30, 85)
		if pos == "GK":
			r["reflexes"] = base + 6
			r["positioning"] = base + 4
		DB.recompute_ovr(r)


static func _youth_name() -> String:
	var first := ["A.", "B.", "C.", "D.", "E.", "F.", "G.", "J.", "L.", "M.", "N.", "P.", "R.", "S.", "T."]
	var last := ["Rivera", "Costa", "Mendes", "Kovač", "Okafor", "Silva", "Novak", "Ruiz", "Lindqvist", "Moreau", "Rossi", "Weber", "Tanaka", "Haddad"]
	return first[randi() % first.size()] + " " + last[randi() % last.size()]


static func _ai_transfers(my_club: String, report: Array) -> void:
	var stars: Array = []
	for p in DB.players.values():
		if p.get("team") != null and p.get("team") != my_club and int(p["ovr"]) >= 78 and int(p.get("age", 30)) <= 27:
			stars.append(p)
	stars.shuffle()
	var big: Array = []
	for t in DB.data["teams"]:
		if int(t.get("prestige", 0)) >= 4 and t["id"] != my_club:
			big.append(t["id"])
	for i in mini(8, stars.size()):
		var p: Dictionary = stars[i]
		var to: String = big[randi() % big.size()]
		if to != p.get("team") and int(DB.team(to).get("prestige", 0)) >= int(DB.team(p["team"]).get("prestige", 0)):
			DB.transfer(p["id"], to)
			report.append("Mercado: %s ficha por %s." % [p["name"], DB.team(to).get("name", "")])
