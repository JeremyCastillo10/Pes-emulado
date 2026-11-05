extends MenuScreen
## Liga / Copa / Torneo de selecciones: creación, partidas guardadas y centro de la competición.

var kind := "league"      # league, cup, world
var view := "home"        # home, new, hub
var tab := "table"
var _cup_groups := false
var _cup_scope := "league"
var _league_id := ""


func _init(p_kind: String, resume := false) -> void:
	kind = p_kind
	super(Lang.t({"league": "m_league", "cup": "m_cup", "world": "m_world"}[p_kind]))
	if resume and Game.session.get("type", "") == kind:
		view = "hub"


func build() -> void:
	match view:
		"hub":
			_build_hub()
		"new":
			_build_new()
		_:
			_build_home()


func go_back() -> void:
	if view == "new":
		view = "home"
		rebuild()
	else:
		menu.pop()


func _build_home() -> void:
	big_button(Lang.t("new_game"), func() -> void:
		view = "new"
		rebuild())
	var saves := Game.list_saves(kind + "_")
	if not saves.is_empty():
		section(Lang.t("saved_games"))
	for slot in saves:
		var sl: String = slot
		var r := row()
		button(sl.replace(kind + "_", "").replace("_", " "), func() -> void:
			if Game.load_session(sl):
				view = "hub"
				rebuild(), r, 520)
		button(Lang.t("delete"), func() -> void:
			Game.delete_save(sl)
			rebuild(), r, 140)


func _build_new() -> void:
	match kind:
		"league":
			section(Lang.t("choose_league"))
			for l in DB.leagues:
				var lid: String = l["id"]
				big_button(l["name"], func() -> void: _pick_team_in(lid))
		"cup":
			cycler(Lang.t("cup_scope"), [Lang.t("cup_league"), Lang.t("cup_champions")], 0 if _cup_scope == "league" else 1, func(i: int) -> void:
				_cup_scope = "league" if i == 0 else "champions")
			cycler(Lang.t("cup_format"), [Lang.t("cup_ko"), Lang.t("cup_groups")], 1 if _cup_groups else 0, func(i: int) -> void: _cup_groups = i == 1)
			big_button(Lang.t("continue"), func() -> void:
				if _cup_scope == "league":
					for c in content.get_children():
						c.queue_free()
					section(Lang.t("choose_league"))
					for l in DB.leagues:
						var lid2: String = l["id"]
						big_button(l["name"], func() -> void: _pick_team_in(lid2))
				else:
					_pick_champions_team())
		"world":
			big_button(Lang.t("choose_nation"), func() -> void:
				menu.push(load("res://scripts/menu/screen_team_picker.gd").new(func(id: String) -> void: _create_world(id), true)))


func _pick_team_in(league_id: String) -> void:
	_league_id = league_id
	for c in content.get_children():
		c.queue_free()
	section(Lang.t("choose_your_team"))
	for tid in DB.league(league_id).get("teams", []):
		var t: String = tid
		team_row(t, func() -> void: _create_from_league(t))


func _create_from_league(team_id: String) -> void:
	var lg := DB.league(_league_id)
	if kind == "league":
		Game.session = {"type": "league", "comp": Competition.create_league(lg["name"], lg["teams"], [team_id])}
	else:
		Game.session = {"type": "cup", "comp": Competition.create_cup("Copa " + str(lg["name"]), lg["teams"], [team_id], _cup_groups)}
	_start_session(team_id)


func _top_clubs(n: int) -> Array:
	var ids: Array = []
	for t in DB.data["teams"]:
		ids.append(t["id"])
	ids.sort_custom(func(a, b) -> bool: return DB.team_strength(a) > DB.team_strength(b))
	return ids.slice(0, n)


func _pick_champions_team() -> void:
	for c in content.get_children():
		c.queue_free()
	section(Lang.t("choose_your_team"))
	for tid in _top_clubs(32):
		var t: String = tid
		team_row(t, func() -> void:
			Game.session = {"type": "cup", "comp": Competition.create_cup(Lang.t("champions_cup"), _top_clubs(32), [t], _cup_groups)}
			_start_session(t))


func _create_world(nat_id: String) -> void:
	var ids: Array = []
	for n in DB.nations:
		ids.append(n["id"])
	ids.sort_custom(func(a, b) -> bool: return DB.team_strength(a) > DB.team_strength(b))
	var chosen := ids.slice(0, 32)
	if not chosen.has(nat_id):
		chosen[31] = nat_id
	Game.session = {"type": "world", "comp": Competition.create_world(Lang.t("world_cup_name"), chosen, [nat_id])}
	_start_session(nat_id)


func _start_session(team_id: String) -> void:
	Game.session["team"] = team_id
	Game.session_slot = "%s_%s_%d" % [kind, DB.team(team_id).get("short", "X"), Time.get_unix_time_from_system()]
	Game.save_session()
	view = "hub"
	rebuild()


# ------------------------------------------------------------- Centro

func _comp() -> Dictionary:
	return Game.session.get("comp", {})


func _build_hub() -> void:
	var c := _comp()
	if c.is_empty():
		view = "home"
		rebuild()
		return
	label(str(c["name"]) + "  ·  " + Competition.round_title(c), 22, null, UITheme.YELLOW)
	if Competition.is_finished(c):
		var w: String = c["winner"]
		var champ := label(Lang.t("champion") + ": " + str(DB.team(w).get("name", w)), 30, null, UITheme.YELLOW)
		champ.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if c["human"].has(w):
			label(Lang.t("congrats"), 22)
	else:
		var f := Competition.human_fixture(c)
		if f.is_empty():
			label(Lang.t("eliminated"), 20)
			button(Lang.t("simulate_rest"), func() -> void:
				var guard := 0
				while not Competition.is_finished(c) and guard < 60:
					Competition.simulate_round_others(c)
					Competition.advance(c)
					guard += 1
				Game.save_session()
				rebuild(), null, 300)
		else:
			var r := row(null, 16)
			r.add_child(CrestView.new(DB.team(f["h"]).get("crest", {}), 64))
			label("%s  vs  %s" % [DB.team(f["h"]).get("name", ""), DB.team(f["a"]).get("name", "")], 26, r)
			r.add_child(CrestView.new(DB.team(f["a"]).get("crest", {}), 64))
			var acts := row()
			var go := button(Lang.t("play"), _play, acts, 200)
			go.add_theme_color_override("font_color", UITheme.YELLOW)
			button(Lang.t("simulate"), _simulate, acts, 200)
			var mine: String = f["h"] if c["human"].has(f["h"]) else f["a"]
			button(Lang.t("lineup"), func() -> void: menu.push(load("res://scripts/menu/screen_lineup.gd").new(mine)), acts, 200)
	var tabs := row()
	var tab_list := [["table", "tab_table"], ["round", "tab_round"], ["scorers", "tab_scorers"], ["assists", "tab_assists"], ["cards", "tab_suspensions"]]
	if c.get("stage", "") != "league":
		tab_list.insert(1, ["bracket", "tab_bracket"])
	for tb in tab_list:
		var key: String = tb[0]
		var b := button(Lang.t(tb[1]), func() -> void:
			tab = key
			rebuild(), tabs, 150)
		if key == tab:
			b.add_theme_color_override("font_color", UITheme.YELLOW)
	match tab:
		"table":
			if c["type"] == "league":
				_table(c["table"], c["human"])
			else:
				for g in c.get("groups", {}):
					label(Lang.t("group") + " " + str(g), 18, null, UITheme.YELLOW)
					_table(c["groups"][g]["table"], c["human"])
				if c.get("groups", {}).is_empty():
					label(Lang.t("no_table"), 18)
		"round":
			var fx := Competition.current_fixtures(c)
			if fx.is_empty() and c["current_round"] > 0:
				fx = c["rounds"][c["current_round"] - 1]
			for f2 in fx:
				_fixture_line(f2)
			if c["current_round"] > 0:
				label(Lang.t("last_results"), 18, null, UITheme.YELLOW)
				for f3 in c["rounds"][c["current_round"] - 1]:
					_fixture_line(f3)
		"bracket":
			for ri in c["rounds"].size():
				var rd: Array = c["rounds"][ri]
				if rd.is_empty() or str(rd[0]["stage"]).begins_with("group_") or rd[0]["stage"] == "league":
					continue
				label(str(rd[0]["stage"]), 18, null, UITheme.YELLOW)
				for f4 in rd:
					_fixture_line(f4)
		"scorers":
			for pid in Competition.top_list(c["scorers"]):
				_player_line(pid, c["scorers"][pid])
		"assists":
			for pid in Competition.top_list(c["assists"]):
				_player_line(pid, c["assists"][pid])
		"cards":
			for pid in c["suspensions"]:
				if int(c["suspensions"][pid]) > 0:
					_player_line(pid, "%d %s" % [c["suspensions"][pid], Lang.t("matches_ban")])
			for pid in c["cards"]:
				var cd: Dictionary = c["cards"][pid]
				_player_line(pid, "A:%d  R:%d" % [cd.get("y", 0), cd.get("r", 0)])


func _table(t: Dictionary, human: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 18)
	content.add_child(grid)
	for h in ["#", Lang.t("team"), "PJ", "G", "E", "P", "GF", "GC", "PTS"]:
		var l := Label.new()
		l.text = h
		l.add_theme_color_override("font_color", UITheme.DIM)
		grid.add_child(l)
	var st := Competition.standings(t)
	for i in st.size():
		var id: String = st[i]
		var r: Dictionary = t[id]
		var vals := [str(i + 1), str(DB.team(id).get("name", id)), r["p"], r["w"], r["d"], r["l"], r["gf"], r["ga"], r["pts"]]
		for v in vals:
			var l2 := Label.new()
			l2.text = str(v)
			if human.has(id):
				l2.add_theme_color_override("font_color", UITheme.YELLOW)
			grid.add_child(l2)


func _fixture_line(f: Dictionary) -> void:
	var a := str(DB.team(f["a"]).get("name", "-")) if f["a"] != "" else Lang.t("bye")
	var res := "  vs  "
	if f["played"]:
		res = "  %d - %d  " % [f["hg"], f["ag"]]
		if f.get("pen", []).size() == 2:
			res += "(%d-%d p) " % [f["pen"][0], f["pen"][1]]
	label(str(DB.team(f["h"]).get("name", "")) + res + a, 18)


func _player_line(pid: String, val: Variant) -> void:
	var p: Dictionary = DB.players.get(pid, {})
	label("%s  (%s)   %s" % [p.get("name", pid), DB.team(str(p.get("team", ""))).get("short", ""), str(val)], 18)


func _play() -> void:
	var c := _comp()
	var cfg := ModeFlow.next_match_config(c, c["name"])
	if cfg.is_empty():
		return
	cfg["difficulty"] = GameSettings.difficulty
	cfg["half_minutes"] = GameSettings.half_minutes
	Game.return_screen = kind
	Game.start_match(cfg)


func _simulate() -> void:
	var c := _comp()
	var f := Competition.human_fixture(c)
	if f.is_empty():
		return
	Competition.apply_result(c, f, Competition.simulate(f["h"], f["a"], Competition.is_knockout(f)))
	Competition.simulate_round_others(c)
	Competition.advance(c)
	Game.save_session()
	toast("%s %d - %d %s" % [DB.team(f["h"]).get("short", ""), f["hg"], f["ag"], DB.team(f["a"]).get("short", "")])
	rebuild()
