class_name LegendMode
## Ser una Leyenda: crea tu jugador, empieza en un club pequeño, sube sus valoraciones con
## buenas actuaciones, recibe ofertas de clubes mejores y llega a la selección.

const ATTRS := ["speed", "acceleration", "shot_accuracy", "shot_power", "short_pass", "long_pass", "dribbling",
	"ball_control", "defense", "heading", "physical", "stamina", "curl", "agility"]
const FOCUS := {
	"CF": ["shot_accuracy", "shot_power", "heading", "ball_control", "acceleration"],
	"RWF": ["speed", "dribbling", "acceleration", "shot_accuracy", "curl"], "LWF": ["speed", "dribbling", "acceleration", "shot_accuracy", "curl"],
	"AMF": ["short_pass", "dribbling", "ball_control", "curl", "shot_accuracy"], "CMF": ["short_pass", "long_pass", "stamina", "ball_control", "defense"],
	"DMF": ["defense", "short_pass", "physical", "stamina", "heading"], "CB": ["defense", "heading", "physical", "speed", "short_pass"],
	"RB": ["speed", "stamina", "defense", "short_pass", "acceleration"], "LB": ["speed", "stamina", "defense", "short_pass", "acceleration"],
}


static func new_legend(player_name: String, position: String, nation: String, appearance: Dictionary, height: int, league_id: String) -> Dictionary:
	var lg := DB.league(league_id)
	var clubs: Array = lg.get("teams", []).duplicate()
	clubs.sort_custom(func(a, b) -> bool: return DB.team_strength(a) < DB.team_strength(b))
	var club: String = clubs[randi() % mini(4, clubs.size())]
	var base := 62
	var p := DB.create_player(club, {"name": player_name, "position": position, "nation": nation, "age": 18, "height": height,
		"appearance": appearance, "potential": 95, "number": 99})
	for k in ATTRS:
		p[k] = base + randi_range(-4, 4)
	for k in FOCUS.get(position, []):
		p[k] = base + 6
	DB.recompute_ovr(p)
	var s := {"type": "legend", "player": p["id"], "club": club, "season": int(DB.data.get("season", 2026)), "xp": 0,
		"ratings": [], "offers": [], "caps": 0, "matches": 0, "goals": 0, "assists": 0, "national": false, "nat_goals": 0,
		"news": ["Firmas tu primer contrato profesional con %s." % DB.team(club).get("name", "")], "pending": "league", "since_intl": 0}
	s["comp"] = Competition.create_league(str(lg.get("name", "Liga")), lg.get("teams", []), [club])
	return s


static func player(s: Dictionary) -> Dictionary:
	return DB.players.get(s["player"], {})


static func next_match_config(s: Dictionary) -> Dictionary:
	var p := player(s)
	# Partido internacional cada 8 jornadas si estás convocado
	if bool(s.get("national", false)) and int(s.get("since_intl", 0)) >= 8:
		s["pending"] = "intl"
		var nat_id := "nat_" + str(p.get("nation", "ESP"))
		var rivals: Array = []
		for n in DB.nations:
			if absf(float(n.get("strength", 50)) - float(DB.team(nat_id).get("strength", 60))) < 10 and n["id"] != nat_id:
				rivals.append(n["id"])
		var rival: String = rivals[randi() % rivals.size()] if not rivals.is_empty() else DB.nations[0]["id"]
		return {"mode": "legend", "home": nat_id, "away": rival, "human_home": true, "legend_player": s["player"],
			"home_lineup": _with_player(nat_id, s["player"]), "competition_name": "Amistoso internacional",
			"stadium": {"name": "Estadio Nacional", "capacity": 60000, "roof": true}, "away_kit": "auto"}
	if Competition.is_finished(s["comp"]):
		return {}
	s["pending"] = "league"
	var cfg := ModeFlow.next_match_config(s["comp"], s["comp"]["name"])
	cfg["mode"] = "legend"
	cfg["legend_player"] = s["player"]
	var club: String = s["club"]
	if cfg.get("home") == club:
		cfg["home_lineup"] = _with_player(club, s["player"])
	else:
		cfg["away_lineup"] = _with_player(club, s["player"])
		cfg["human_away"] = true
		cfg["human_home"] = false
	return cfg


## Alineación del equipo asegurando que el jugador leyenda es titular.
static func _with_player(team_id: String, pid: String) -> Array:
	var t := DB.team(team_id)
	var lineup: Array = t.get("lineup", []).duplicate()
	if lineup.has(pid):
		return lineup
	var pos := str(DB.players[pid]["position"])
	var replace_i := -1
	for i in lineup.size():
		var q: Dictionary = DB.players.get(lineup[i], {})
		if str(q.get("position", "")) == pos or Formations.SIMILAR.get(pos, []).has(str(q.get("position", ""))):
			replace_i = i
	if replace_i < 0:
		replace_i = lineup.size() - 1
	lineup[replace_i] = pid
	if not t["players"].has(pid):
		t["players"].append(pid)
	return lineup


static func on_match(s: Dictionary, result: Dictionary) -> void:
	var pid: String = s["player"]
	var p := player(s)
	if str(s.get("pending", "")) == "intl":
		s["since_intl"] = 0
		s["caps"] = int(s["caps"]) + 1
	else:
		ModeFlow._apply_comp(s["comp"], result)
		s["since_intl"] = int(s.get("since_intl", 0)) + 1
	var r: float = float(result.get("ratings", {}).get(pid, 6.0))
	var st: Dictionary = result.get("player_stats", {}).get(pid, {})
	var g := int(st.get("goals", 0))
	var a := int(st.get("assists", 0))
	s["matches"] = int(s["matches"]) + 1
	s["goals"] = int(s["goals"]) + g
	s["assists"] = int(s["assists"]) + a
	s["ratings"].append(r)
	s["xp"] = int(s["xp"]) + int((r - 5.0) * 12.0) + g * 15 + a * 10
	var ups := 0
	while int(s["xp"]) >= 100:
		s["xp"] = int(s["xp"]) - 100
		ups += 1
		var focus: Array = FOCUS.get(str(p["position"]), ATTRS)
		for i in 3:
			var k: String = focus[randi() % focus.size()] if randf() < 0.75 else ATTRS[randi() % ATTRS.size()]
			p[k] = clampi(int(p.get(k, 60)) + 1, 30, 99)
		DB.recompute_ovr(p)
	if ups > 0:
		s["news"].push_front("¡Mejoras! Tu media sube a %d." % int(p["ovr"]))
	s["news"].push_front("Nota del partido: %.1f  (%d goles, %d asistencias)" % [r, g, a])
	# Ofertas de clubes mejores
	var last: Array = s["ratings"].slice(maxi(0, s["ratings"].size() - 6))
	if last.size() >= 6 and int(s["matches"]) % 6 == 0:
		var avg := 0.0
		for x in last:
			avg += float(x)
		avg /= last.size()
		if avg >= 6.9:
			var my_pres := int(DB.team(s["club"]).get("prestige", 1))
			var cands: Array = []
			for t in DB.data["teams"]:
				if int(t.get("prestige", 0)) == mini(my_pres + 1, 5) and t["id"] != s["club"]:
					cands.append(t["id"])
			if not cands.is_empty():
				var offer: String = cands[randi() % cands.size()]
				if not s["offers"].has(offer):
					s["offers"].append(offer)
					s["news"].push_front("¡Oferta de %s! Puedes aceptarla en tu carrera." % DB.team(offer).get("name", ""))
	# Convocatoria con la selección
	if not bool(s["national"]):
		var nat := DB.team("nat_" + str(p.get("nation", "")))
		var worst := 99
		for q in DB.team_players(nat.get("id", "")):
			worst = mini(worst, int(q.get("ovr", 99)))
		if not nat.is_empty() and int(p["ovr"]) >= worst + 2:
			s["national"] = true
			var weakest := ""
			for q in DB.team_players(nat["id"]):
				if q["position"] == p["position"] and (weakest == "" or int(q["ovr"]) < int(DB.players[weakest]["ovr"])):
					weakest = q["id"]
			if weakest != "":
				nat["players"].erase(weakest)
			nat["players"].append(pid)
			s["news"].push_front("¡Convocado por %s!" % nat.get("name", ""))
	if s["news"].size() > 30:
		s["news"].resize(30)


static func accept_offer(s: Dictionary, team_id: String) -> void:
	DB.transfer(s["player"], team_id)
	s["club"] = team_id
	s["offers"] = []
	var lg := DB.league(str(DB.team(team_id).get("league", "")))
	s["comp"] = Competition.create_league(str(lg.get("name", "Liga")), lg.get("teams", []), [team_id])
	s["news"].push_front("Fichas por %s. ¡Nueva etapa!" % DB.team(team_id).get("name", ""))


static func end_season(s: Dictionary) -> void:
	var p := player(s)
	p["age"] = int(p.get("age", 18)) + 1
	s["season"] = int(s["season"]) + 1
	var lg := DB.league(str(DB.team(s["club"]).get("league", "")))
	s["comp"] = Competition.create_league(str(lg.get("name", "Liga")), lg.get("teams", []), [s["club"]])
	s["news"].push_front("Comienza la temporada %d." % s["season"])
