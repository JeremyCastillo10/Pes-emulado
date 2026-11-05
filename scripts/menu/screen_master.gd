extends MenuScreen
## Liga Máster: crear/continuar carrera y centro del club.

var view := "home"
var tab := "club"
var _filter_pos := ""
var _filter_text := ""
var _league_id := ""


func _init(resume := false) -> void:
	super(Lang.t("m_master"))
	if resume and Game.session.get("type", "") == "master":
		view = "hub"


func build() -> void:
	match view:
		"hub":
			_hub()
		"new":
			section(Lang.t("choose_league"))
			for l in DB.leagues:
				var lid: String = l["id"]
				big_button(l["name"], func() -> void:
					_league_id = lid
					view = "club"
					rebuild())
		"club":
			section(Lang.t("choose_your_club"))
			for tid in DB.league(_league_id).get("teams", []):
				var t: String = tid
				team_row(t, func() -> void:
					Game.session = MasterLeague.new_career(t)
					Game.session_slot = "master_%s_%d" % [DB.team(t).get("short", "X"), Time.get_unix_time_from_system()]
					Game.save_session()
					view = "hub"
					rebuild(), null, Lang.t("budget_short") + " %.0f M" % float(DB.team(t).get("budget", 0)))
		_:
			big_button(Lang.t("new_career"), func() -> void:
				view = "new"
				rebuild())
			var saves := Game.list_saves("master_")
			if not saves.is_empty():
				section(Lang.t("saved_games"))
			for slot in saves:
				var sl: String = slot
				var r := row()
				button(sl.replace("master_", "").replace("_", " "), func() -> void:
					if Game.load_session(sl):
						view = "hub"
						rebuild(), r, 520)
				button(Lang.t("delete"), func() -> void:
					Game.delete_save(sl)
					rebuild(), r, 140)


func go_back() -> void:
	if view in ["new", "club"]:
		view = "home"
		rebuild()
	else:
		menu.pop()


func _hub() -> void:
	var s := Game.session
	var club: String = s["club"]
	var t := DB.team(club)
	var head := row(null, 16)
	head.add_child(CrestView.new(t.get("crest", {}), 64))
	var info := VBoxContainer.new()
	head.add_child(info)
	label(str(t.get("name", "")) + "  ·  " + Lang.t("season") + " %d" % int(s["season"]), 24, info, UITheme.YELLOW)
	label("%s: %.1f M   ·   %s: %s   ·   %s: %d%%" % [Lang.t("budget"), float(s["budget"]), Lang.t("objective"), MasterLeague.objective_text(s), Lang.t("board_conf"), int(s["board"].get("confidence", 70))], 17, info)
	if bool(s.get("fired", false)):
		label(Lang.t("fired"), 22, null, Color(1, 0.4, 0.3))
		return
	var key := MasterLeague.current_key(s)
	if key == "season_end":
		label(Lang.t("season_over"), 22)
		big_button(Lang.t("close_season"), func() -> void:
			var rep := MasterLeague.end_season(s)
			Game.save_session()
			for line in rep:
				toast(line)
			tab = "news"
			rebuild())
	else:
		var c: Dictionary = s["cup"] if key == "cup" else s["comp"]
		var f := Competition.human_fixture(c)
		if not f.is_empty():
			label(str(c["name"]) + " · " + Competition.round_title(c), 18, null, UITheme.DIM)
			var r := row(null, 14)
			r.add_child(CrestView.new(DB.team(f["h"]).get("crest", {}), 52))
			label("%s  vs  %s" % [DB.team(f["h"]).get("name", ""), DB.team(f["a"]).get("name", "")], 22, r)
			r.add_child(CrestView.new(DB.team(f["a"]).get("crest", {}), 52))
			var acts := row()
			var go := button(Lang.t("play"), _play, acts, 180)
			go.add_theme_color_override("font_color", UITheme.YELLOW)
			button(Lang.t("simulate"), func() -> void:
				var res := Competition.simulate(f["h"], f["a"], Competition.is_knockout(f))
				s["pending"] = key
				res["home"] = f["h"]
				res["away"] = f["a"]
				res["ratings"] = {}
				MasterLeague.on_match(s, res)
				Game.save_session()
				rebuild(), acts, 180)
			button(Lang.t("lineup"), func() -> void: menu.push(load("res://scripts/menu/screen_lineup.gd").new(club)), acts, 180)
	var tabs := row()
	for tb in [["club", "tab_squad"], ["table", "tab_table"], ["market", "tab_market"], ["news", "tab_news"], ["history", "tab_history"]]:
		var k: String = tb[0]
		var b := button(Lang.t(tb[1]), func() -> void:
			tab = k
			rebuild(), tabs, 160)
		if k == tab:
			b.add_theme_color_override("font_color", UITheme.YELLOW)
	match tab:
		"club":
			_squad(s)
		"table":
			var st := Competition.standings(s["comp"]["table"])
			for i in st.size():
				var id: String = st[i]
				var rr: Dictionary = s["comp"]["table"][id]
				var l := label("%2d. %s   %d pts  (%d-%d-%d)  %d:%d" % [i + 1, DB.team(id).get("name", ""), rr["pts"], rr["w"], rr["d"], rr["l"], rr["gf"], rr["ga"]], 17)
				if id == club:
					l.add_theme_color_override("font_color", UITheme.YELLOW)
		"market":
			_market(s)
		"news":
			for n in s["news"]:
				label("· " + str(n), 17)
		"history":
			for h in s["history"]:
				label("%s %d: %dº%s" % [Lang.t("season"), h["season"], h["pos"], "  + Copa" if h.get("cup", false) else ""], 18)


func _squad(s: Dictionary) -> void:
	label(Lang.t("squad_help"), 15, null, UITheme.DIM)
	var pls := DB.team_players(s["club"])
	pls.sort_custom(func(a, b) -> bool: return int(a["ovr"]) > int(b["ovr"]))
	for p in pls:
		var pid: String = p["id"]
		var r := row()
		var l := label("%2s %-4s %s  ·  %d  ·  %d años  ·  %.1f M  ·  contrato %d%s" % [str(p.get("number", "")), p["position"], p["name"], int(p["ovr"]), int(p.get("age", 0)), float(p.get("value", 0)), int(p.get("contract", 0)), "  (lesionado)" if int(p.get("injured", 0)) > 0 else ""], 16, r)
		l.custom_minimum_size.x = 700
		button(Lang.t("renew"), func() -> void:
			var e := MasterLeague.renew(s, pid, 3)
			toast(e if e != "" else Lang.t("renewed"))
			Game.save_session()
			rebuild(), r, 130)
		button(Lang.t("sell"), func() -> void:
			var e := MasterLeague.sell(s, pid)
			toast(e if e != "" else Lang.t("sold"))
			Game.save_session()
			rebuild(), r, 120)


func _market(s: Dictionary) -> void:
	var f := row()
	var poss := ["", "GK", "CB", "RB", "LB", "DMF", "CMF", "AMF", "RWF", "LWF", "CF"]
	cycler(Lang.t("position"), poss.map(func(x): return Lang.t("all") if x == "" else x), maxi(poss.find(_filter_pos), 0), func(i: int) -> void:
		_filter_pos = poss[i]
		rebuild(), f)
	line_edit(Lang.t("search"), _filter_text, func(t: String) -> void: _filter_text = t)
	button(Lang.t("search"), rebuild, null, 160)
	for p in MasterLeague.market(s, _filter_pos, float(s["budget"]) * 1.5, _filter_text, 60):
		var pid: String = p["id"]
		var r := row()
		var l := label("%-4s %s (%s) · %d · %d años · %.1f M" % [p["position"], p["name"], DB.team(str(p.get("team", ""))).get("short", "libre"), int(p["ovr"]), int(p.get("age", 0)), float(p.get("value", 0))], 16, r)
		l.custom_minimum_size.x = 640
		var price := float(p.get("value", 1.0))
		button(Lang.t("offer") + " %.1f" % price, func() -> void:
			var e := MasterLeague.buy(s, pid, price)
			toast(e if e != "" else Lang.t("signed"))
			Game.save_session()
			rebuild(), r, 160)
		button(Lang.t("loan"), func() -> void:
			var e := MasterLeague.loan_in(s, pid)
			toast(e if e != "" else Lang.t("loaned"))
			Game.save_session()
			rebuild(), r, 120)


func _play() -> void:
	var cfg := MasterLeague.next_match_config(Game.session)
	if cfg.is_empty():
		return
	cfg["difficulty"] = GameSettings.difficulty
	cfg["half_minutes"] = GameSettings.half_minutes
	Game.save_session()
	Game.return_screen = "master"
	Game.start_match(cfg)
