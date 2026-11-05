extends Node
## Prueba automática de los modos (sin pantalla): godot --headless --path . res://tests/test_modes.tscn


func _ready() -> void:
	DB.load_now()
	print("DB: ", DB.players.size(), " jugadores, ", DB.teams.size(), " equipos")
	# Liga
	var lg: Dictionary = DB.leagues[0]
	var c := Competition.create_league(lg["name"], lg["teams"], [lg["teams"][0]])
	var guard := 0
	while not Competition.is_finished(c) and guard < 100:
		var f := Competition.human_fixture(c)
		if not f.is_empty():
			Competition.apply_result(c, f, Competition.simulate(f["h"], f["a"], false))
		Competition.simulate_round_others(c)
		Competition.advance(c)
		guard += 1
	var st := Competition.standings(c["table"])
	print("LIGA campeón: ", DB.team(c["winner"])["name"], " pts ", c["table"][st[0]]["pts"], " goleador: ", DB.players[Competition.top_list(c["scorers"], 1)[0]]["name"])
	# Copa con grupos
	var cup := Competition.create_cup("Copa", DB.leagues[1]["teams"], [DB.leagues[1]["teams"][2]], true)
	guard = 0
	while not Competition.is_finished(cup) and guard < 100:
		var f2 := Competition.human_fixture(cup)
		if not f2.is_empty():
			Competition.apply_result(cup, f2, Competition.simulate(f2["h"], f2["a"], Competition.is_knockout(f2)))
		Competition.simulate_round_others(cup)
		Competition.advance(cup)
		guard += 1
	print("COPA campeón: ", DB.team(cup["winner"])["name"], " rondas ", cup["rounds"].size())
	# Mundial
	var ids: Array = []
	for n in DB.nations:
		ids.append(n["id"])
	ids.sort_custom(func(a, b) -> bool: return DB.team_strength(a) > DB.team_strength(b))
	var w := Competition.create_world("Mundial", ids.slice(0, 32), [ids[0]])
	guard = 0
	while not Competition.is_finished(w) and guard < 100:
		var f3 := Competition.human_fixture(w)
		if not f3.is_empty():
			Competition.apply_result(w, f3, Competition.simulate(f3["h"], f3["a"], Competition.is_knockout(f3)))
		Competition.simulate_round_others(w)
		Competition.advance(w)
		guard += 1
	print("MUNDIAL campeón: ", DB.team(w["winner"])["name"], " rondas ", w["rounds"].size())
	# Liga Máster: una temporada simulada + cierre
	var club: String = DB.leagues[0]["teams"][5]
	var s := MasterLeague.new_career(club)
	print("ML objetivo: ", MasterLeague.objective_text(s), " presupuesto ", s["budget"])
	var e := MasterLeague.buy(s, MasterLeague.market(s, "CF", 50.0)[3]["id"], 50.0)
	print("ML fichaje: ", "ok" if e == "" else e)
	guard = 0
	while MasterLeague.current_key(s) != "season_end" and guard < 120:
		var cfg := MasterLeague.next_match_config(s)
		var res := Competition.simulate(cfg["home"], cfg["away"], cfg.get("needs_winner", false))
		res["home"] = cfg["home"]
		res["away"] = cfg["away"]
		res["ratings"] = {}
		MasterLeague.on_match(s, res)
		guard += 1
	print("ML partidos: ", guard)
	var rep := MasterLeague.end_season(s)
	for r in rep.slice(0, 6):
		print("  ", r)
	# Leyenda
	var leg := LegendMode.new_legend("Prueba Leyenda", "CF", "ARG", {}, 180, "esp")
	for i in 12:
		var cfg2 := LegendMode.next_match_config(leg)
		var pid: String = leg["player"]
		LegendMode.on_match(leg, {"home": cfg2["home"], "away": cfg2["away"], "hg": 2, "ag": 1, "pen": [], "scorers": [], "cards": [],
			"ratings": {pid: 8.0}, "player_stats": {pid: {"goals": 1, "assists": 1}}})
	print("LEYENDA media: ", LegendMode.player(leg)["ovr"], " ofertas: ", leg["offers"].size(), " convocado: ", leg["national"])
	print("PRUEBA MODOS OK")
	# Menús: abrir cada pantalla
	var menu_scene: Node = load("res://scenes/menu/main_menu.tscn").instantiate()
	add_child(menu_scene)
	await get_tree().create_timer(1.0).timeout
	for path in ["res://scripts/menu/screen_friendly.gd", "res://scripts/menu/screen_training.gd", "res://scripts/menu/screen_editor.gd",
		"res://scripts/menu/screen_replays.gd", "res://scripts/menu/screen_options.gd"]:
		menu_scene.push(load(path).new())
		await get_tree().process_frame
	menu_scene.push(load("res://scripts/menu/screen_competition.gd").new("league", false))
	menu_scene.push(load("res://scripts/menu/screen_master.gd").new(false))
	menu_scene.push(load("res://scripts/menu/screen_legend.gd").new(false))
	menu_scene.push(load("res://scripts/menu/screen_lineup.gd").new(DB.leagues[0]["teams"][0]))
	menu_scene.push(load("res://scripts/menu/screen_team_picker.gd").new(func(_id: String) -> void: pass))
	Game.session = s
	menu_scene.push(load("res://scripts/menu/screen_master.gd").new(true))
	Game.session = leg
	menu_scene.push(load("res://scripts/menu/screen_legend.gd").new(true))
	Game.session = {"type": "world", "comp": w}
	menu_scene.push(load("res://scripts/menu/screen_competition.gd").new("world", true))
	await get_tree().create_timer(0.5).timeout
	print("PRUEBA MENÚS OK")
	get_tree().quit()
