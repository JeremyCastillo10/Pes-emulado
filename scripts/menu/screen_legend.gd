extends MenuScreen
## Ser una Leyenda: creación del jugador (con vista previa 3D en el fondo del menú) y carrera.

var view := "home"
var pdata := {"name": "Tu Nombre", "position": "CF", "nation": "ESP", "height": 180,
	"appearance": {"skin": "#e0ac83", "hair_style": 1, "hair_color": "#2b1d14", "beard": 0, "build": 0.5, "boots": "#ff6a00"}}
var league_idx := 0
const SKINS := ["#f3d2b6", "#e0ac83", "#c68b5e", "#a26a42", "#7b4b2a", "#5a3620"]
const HAIRS := ["#111111", "#2b1d14", "#6b4423", "#a8784a", "#d9c27a", "#7a7a7a"]
const BOOTS := ["#111111", "#f5f5f5", "#ff6a00", "#1e90ff", "#ffd400", "#e0115f", "#32cd32"]
const POSITIONS := ["CF", "RWF", "LWF", "AMF", "CMF", "DMF", "CB", "RB", "LB"]


func _init(resume := false) -> void:
	super(Lang.t("m_legend"))
	if resume and Game.session.get("type", "") == "legend":
		view = "hub"


func go_back() -> void:
	if view == "create":
		view = "home"
		rebuild()
	else:
		menu.pop()


func build() -> void:
	match view:
		"hub":
			_hub()
		"create":
			_create()
		_:
			big_button(Lang.t("create_legend"), func() -> void:
				view = "create"
				rebuild()
				menu.set_protagonist_look(pdata))
			var saves := Game.list_saves("legend_")
			if not saves.is_empty():
				section(Lang.t("saved_games"))
			for slot in saves:
				var sl: String = slot
				var r := row()
				button(sl.replace("legend_", "").replace("_", " "), func() -> void:
					if Game.load_session(sl):
						view = "hub"
						rebuild(), r, 520)
				button(Lang.t("delete"), func() -> void:
					Game.delete_save(sl)
					rebuild(), r, 140)


func _preview() -> void:
	menu.set_protagonist_look(pdata)


func _create() -> void:
	label(Lang.t("legend_help"), 16, null, UITheme.DIM)
	line_edit(Lang.t("name"), pdata["name"], func(t: String) -> void: pdata["name"] = t)
	cycler(Lang.t("position"), POSITIONS, POSITIONS.find(pdata["position"]), func(i: int) -> void: pdata["position"] = POSITIONS[i])
	var codes: Array = []
	var names: Array = []
	for n in DB.nations:
		codes.append(n["code"])
		names.append(n["name"])
	cycler(Lang.t("nation"), names, maxi(codes.find(pdata["nation"]), 0), func(i: int) -> void: pdata["nation"] = codes[i])
	var ap: Dictionary = pdata["appearance"]
	cycler(Lang.t("skin"), [1, 2, 3, 4, 5, 6], maxi(SKINS.find(ap["skin"]), 0), func(i: int) -> void:
		ap["skin"] = SKINS[i]
		_preview())
	cycler(Lang.t("hairstyle"), [Lang.t("hair_0"), Lang.t("hair_1"), Lang.t("hair_2"), Lang.t("hair_3"), Lang.t("hair_4"), Lang.t("hair_5")], int(ap["hair_style"]), func(i: int) -> void:
		ap["hair_style"] = i
		_preview())
	cycler(Lang.t("hair_color"), [1, 2, 3, 4, 5, 6], maxi(HAIRS.find(ap["hair_color"]), 0), func(i: int) -> void:
		ap["hair_color"] = HAIRS[i]
		_preview())
	cycler(Lang.t("beard"), [Lang.t("beard_0"), Lang.t("beard_1"), Lang.t("beard_2"), Lang.t("beard_3")], int(ap["beard"]), func(i: int) -> void:
		ap["beard"] = i
		_preview())
	slider(Lang.t("height"), 160, 200, 1, pdata["height"], func(v: float) -> void:
		pdata["height"] = int(v)
		_preview())
	slider(Lang.t("build"), 0.0, 1.0, 0.05, ap["build"], func(v: float) -> void:
		ap["build"] = v
		_preview())
	cycler(Lang.t("boots"), [1, 2, 3, 4, 5, 6, 7], maxi(BOOTS.find(ap["boots"]), 0), func(i: int) -> void:
		ap["boots"] = BOOTS[i]
		_preview())
	var lnames: Array = DB.leagues.map(func(l): return l["name"])
	cycler(Lang.t("start_league"), lnames, league_idx, func(i: int) -> void: league_idx = i)
	big_button(Lang.t("start_career"), func() -> void:
		Game.session = LegendMode.new_legend(pdata["name"], pdata["position"], pdata["nation"], ap.duplicate(), int(pdata["height"]), DB.leagues[league_idx]["id"])
		Game.session_slot = "legend_%s_%d" % [str(pdata["name"]).replace(" ", ""), Time.get_unix_time_from_system()]
		Game.save_session()
		view = "hub"
		rebuild())


func _hub() -> void:
	var s := Game.session
	var p := LegendMode.player(s)
	if p.is_empty():
		label("Jugador no encontrado", 20)
		return
	var club := DB.team(s["club"])
	menu.set_protagonist_look(p, club.get("kits", {}).get("home", {}))
	var head := row(null, 14)
	head.add_child(CrestView.new(club.get("crest", {}), 60))
	var info := VBoxContainer.new()
	head.add_child(info)
	label("%s  ·  %s  ·  %d" % [p["name"], p["position"], int(p["ovr"])], 26, info, UITheme.YELLOW)
	label("%s · %d años · %s %d · %s: %d PJ, %d G, %d A · XP %d/100%s" % [club.get("name", ""), int(p.get("age", 18)), Lang.t("season"), int(s["season"]), Lang.t("stats"), int(s["matches"]), int(s["goals"]), int(s["assists"]), int(s["xp"]), ("  ·  " + Lang.t("national_player") + " (%d)" % int(s["caps"])) if bool(s["national"]) else ""], 16, info)
	var cfg_preview := LegendMode.next_match_config(s.duplicate(true))
	if cfg_preview.is_empty():
		label(Lang.t("season_over"), 20)
		big_button(Lang.t("next_season"), func() -> void:
			LegendMode.end_season(s)
			Game.save_session()
			rebuild())
	else:
		label("%s: %s vs %s" % [cfg_preview.get("competition_name", ""), DB.team(cfg_preview["home"]).get("name", ""), DB.team(cfg_preview["away"]).get("name", "")], 20)
		var go := big_button(Lang.t("play"), func() -> void:
			var cfg := LegendMode.next_match_config(s)
			cfg["difficulty"] = GameSettings.difficulty
			cfg["half_minutes"] = GameSettings.half_minutes
			cfg["presentation"] = false
			Game.save_session()
			Game.return_screen = "legend"
			Game.start_match(cfg))
		go.add_theme_color_override("font_color", UITheme.YELLOW)
	if not s["offers"].is_empty():
		section(Lang.t("offers"))
		for o in s["offers"]:
			var oid: String = o
			team_row(oid, func() -> void:
				LegendMode.accept_offer(s, oid)
				Game.save_session()
				toast(Lang.t("offer_accepted"))
				rebuild())
	section(Lang.t("attributes"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 30)
	content.add_child(grid)
	for k in LegendMode.ATTRS:
		var l := Label.new()
		l.text = "%s: %d" % [Lang.t("a_" + k), int(p.get(k, 0))]
		grid.add_child(l)
	section(Lang.t("tab_news"))
	for n in s["news"]:
		label("· " + str(n), 16)
