extends MenuScreen
## Editor: jugadores (crear, editar, borrar, traspasar), equipos (nombre, uniformes, escudo,
## formación, estadio) e importación/exportación de la base de datos.

const POSITIONS := ["GK", "CB", "RB", "LB", "DMF", "CMF", "AMF", "RMF", "LMF", "RWF", "LWF", "SS", "CF"]
const RATINGS := ["speed", "acceleration", "shot_accuracy", "shot_power", "short_pass", "long_pass", "dribbling", "ball_control",
	"defense", "heading", "physical", "stamina", "curl", "agility", "reflexes", "positioning"]

var view := "home"
var query := ""
var pid := ""
var tid := ""


func _init() -> void:
	super(Lang.t("m_editor"))


func go_back() -> void:
	if view == "player" or view == "team":
		DB.save()
	if view != "home":
		view = "home" if view in ["players", "teams", "data"] else ("players" if view == "player" else "teams")
		rebuild()
	else:
		menu.pop()


func build() -> void:
	match view:
		"players":
			_players()
		"player":
			_player()
		"teams":
			_teams()
		"team":
			_team()
		"data":
			_data()
		_:
			big_button(Lang.t("ed_players"), func() -> void:
				view = "players"
				rebuild())
			big_button(Lang.t("ed_teams"), func() -> void:
				view = "teams"
				rebuild())
			big_button(Lang.t("ed_data"), func() -> void:
				view = "data"
				rebuild())


# ----------------------------------------------------------- Jugadores

func _players() -> void:
	line_edit(Lang.t("search"), query, func(t: String) -> void: query = t)
	var r := row()
	button(Lang.t("search"), rebuild, r, 160)
	button(Lang.t("create_player"), func() -> void:
		menu.push(load("res://scripts/menu/screen_team_picker.gd").new(func(team_id: String) -> void:
			var p := DB.create_player(team_id)
			pid = p["id"]
			view = "player"
			rebuild())), r, 240)
	for p in DB.search_players(query, 60):
		var id: String = p["id"]
		button("%s  ·  %s  ·  %d  ·  %s" % [p["name"], p["position"], int(p["ovr"]), DB.team(str(p.get("team", ""))).get("name", Lang.t("no_club"))], func() -> void:
			pid = id
			view = "player"
			rebuild(), null, 760)


func _player() -> void:
	var p: Dictionary = DB.players.get(pid, {})
	if p.is_empty():
		view = "players"
		rebuild()
		return
	line_edit(Lang.t("name"), str(p["name"]), func(t: String) -> void: p["name"] = t)
	slider(Lang.t("number"), 1, 99, 1, int(p.get("number", 10)), func(v: float) -> void: p["number"] = int(v))
	cycler(Lang.t("position"), POSITIONS, maxi(POSITIONS.find(str(p["position"])), 0), func(i: int) -> void: p["position"] = POSITIONS[i])
	cycler(Lang.t("foot"), [Lang.t("foot_right"), Lang.t("foot_left")], 1 if p.get("foot", "right") == "left" else 0, func(i: int) -> void:
		p["foot"] = "left" if i == 1 else "right")
	slider(Lang.t("age"), 15, 45, 1, int(p.get("age", 25)), func(v: float) -> void: p["age"] = int(v))
	slider(Lang.t("height"), 155, 205, 1, int(p.get("height", 180)), func(v: float) -> void: p["height"] = int(v))
	var codes: Array = []
	var names: Array = []
	for n in DB.nations:
		codes.append(n["code"])
		names.append(n["name"])
	cycler(Lang.t("nation"), names, maxi(codes.find(str(p.get("nation", "ESP"))), 0), func(i: int) -> void: p["nation"] = codes[i])
	section(Lang.t("attributes") + "  (" + Lang.t("overall") + " %d)" % int(p["ovr"]))
	for k in RATINGS:
		var key: String = k
		slider(Lang.t("a_" + key), 20, 99, 1, int(p.get(key, 50)), func(v: float) -> void: p[key] = int(v))
	slider(Lang.t("overall"), 40, 99, 1, int(p.get("ovr", 60)), func(v: float) -> void: p["ovr"] = int(v))
	button(Lang.t("recalc_ovr"), func() -> void:
		DB.recompute_ovr(p)
		rebuild(), null, 260)
	section(Lang.t("appearance"))
	var ap: Dictionary = p.get("appearance", {})
	p["appearance"] = ap
	color_button(Lang.t("skin"), str(ap.get("skin", "#e0ac83")), func(c: String) -> void: ap["skin"] = c)
	cycler(Lang.t("hairstyle"), [Lang.t("hair_0"), Lang.t("hair_1"), Lang.t("hair_2"), Lang.t("hair_3"), Lang.t("hair_4"), Lang.t("hair_5")], int(ap.get("hair_style", 1)), func(i: int) -> void: ap["hair_style"] = i)
	color_button(Lang.t("hair_color"), str(ap.get("hair_color", "#2b1d14")), func(c: String) -> void: ap["hair_color"] = c)
	cycler(Lang.t("beard"), [Lang.t("beard_0"), Lang.t("beard_1"), Lang.t("beard_2"), Lang.t("beard_3")], int(ap.get("beard", 0)), func(i: int) -> void: ap["beard"] = i)
	slider(Lang.t("build"), 0.0, 1.0, 0.05, float(ap.get("build", 0.5)), func(v: float) -> void: ap["build"] = v)
	color_button(Lang.t("boots"), str(ap.get("boots", "#111111")), func(c: String) -> void: ap["boots"] = c)
	section(Lang.t("club"))
	label(str(DB.team(str(p.get("team", ""))).get("name", Lang.t("no_club"))), 20)
	var r := row()
	button(Lang.t("transfer"), func() -> void:
		menu.push(load("res://scripts/menu/screen_team_picker.gd").new(func(team_id: String) -> void:
			DB.transfer(pid, team_id)
			toast(Lang.t("transferred"))
			rebuild(), false, true)), r, 220)
	button(Lang.t("release"), func() -> void:
		DB.transfer(pid, "")
		rebuild(), r, 220)
	button(Lang.t("delete_player"), func() -> void:
		DB.delete_player(pid)
		DB.save()
		view = "players"
		rebuild(), r, 240)
	button(Lang.t("save"), func() -> void:
		DB.save()
		toast(Lang.t("saved")), null, 220)


# ------------------------------------------------------------- Equipos

func _teams() -> void:
	button(Lang.t("choose_team"), func() -> void:
		menu.push(load("res://scripts/menu/screen_team_picker.gd").new(func(team_id: String) -> void:
			tid = team_id
			view = "team"
			rebuild())), null, 300)


func _team() -> void:
	var t := DB.team(tid)
	var head := row()
	var crest_view := CrestView.new(t.get("crest", {}), 72)
	head.add_child(crest_view)
	label(str(t.get("name", "")), 26, head, UITheme.YELLOW)
	line_edit(Lang.t("name"), str(t.get("name", "")), func(s: String) -> void: t["name"] = s)
	line_edit(Lang.t("short_name"), str(t.get("short", "")), func(s: String) -> void:
		t["short"] = s.substr(0, 4).to_upper())
	button(Lang.t("lineup") + " / " + Lang.t("formation"), func() -> void: menu.push(load("res://scripts/menu/screen_lineup.gd").new(tid)), null, 360)
	section(Lang.t("kits"))
	var kits: Dictionary = t.get("kits", {})
	for kk in ["home", "away", "third", "gk"]:
		var kit: Dictionary = kits.get(kk, {})
		kits[kk] = kit
		label(Lang.t("kit_" + kk), 18, null, UITheme.DIM)
		var r := row()
		for part in ["shirt", "shirt2", "shorts", "socks"]:
			var pt: String = part
			color_button(Lang.t("k_" + part), str(kit.get(pt, "#ffffff")), func(c: String) -> void: kit[pt] = c, r)
	section(Lang.t("crest"))
	var crest: Dictionary = t.get("crest", {})
	t["crest"] = crest
	var shapes := ["shield", "circle", "round_shield", "diamond"]
	cycler(Lang.t("shape"), [Lang.t("sh_shield"), Lang.t("sh_circle"), Lang.t("sh_round"), Lang.t("sh_diamond")], maxi(shapes.find(str(crest.get("shape", "shield"))), 0), func(i: int) -> void:
		crest["shape"] = shapes[i]
		crest_view.set_crest(crest))
	var r2 := row()
	color_button(Lang.t("color1"), str(crest.get("c1", "#203070")), func(c: String) -> void:
		crest["c1"] = c
		crest_view.set_crest(crest), r2)
	color_button(Lang.t("color2"), str(crest.get("c2", "#ffffff")), func(c: String) -> void:
		crest["c2"] = c
		crest_view.set_crest(crest), r2)
	line_edit(Lang.t("crest_text"), str(crest.get("text", "")), func(s: String) -> void:
		crest["text"] = s.substr(0, 4)
		crest_view.set_crest(crest))
	if not DB.is_nation(tid):
		section(Lang.t("stadium"))
		var st: Dictionary = t.get("stadium", {})
		t["stadium"] = st
		line_edit(Lang.t("name"), str(st.get("name", "")), func(s: String) -> void: st["name"] = s)
		slider(Lang.t("capacity"), 5000, 100000, 1000, int(st.get("capacity", 40000)), func(v: float) -> void: st["capacity"] = int(v))
		cycler(Lang.t("roof"), [Lang.t("on"), Lang.t("off")], 0 if st.get("roof", true) else 1, func(i: int) -> void: st["roof"] = i == 0)
		color_button(Lang.t("seat_color"), str(st.get("seat_color", "#b01a22")), func(c: String) -> void: st["seat_color"] = c)
		cycler(Lang.t("mow_pattern"), [Lang.t("mow_0"), Lang.t("mow_1"), Lang.t("mow_2"), Lang.t("mow_3"), Lang.t("mow_4")], int(st.get("pattern", 0)), func(i: int) -> void: st["pattern"] = i)
		slider(Lang.t("budget") + " (M)", 1, 900, 1, float(t.get("budget", 20)), func(v: float) -> void: t["budget"] = v)
	button(Lang.t("save"), func() -> void:
		DB.save()
		toast(Lang.t("saved")), null, 220)


# ---------------------------------------------------------------- Datos

func _data() -> void:
	label(Lang.t("data_help") % DB.export_dir(), 16, null, UITheme.DIM)
	big_button(Lang.t("export_db"), func() -> void:
		var path := DB.export_database()
		toast(Lang.t("exported") + " " + path if path != "" else Lang.t("export_failed")))
	section(Lang.t("import_db"))
	var files := DB.list_importable()
	if files.is_empty():
		label(Lang.t("no_import_files"), 17)
	for f in files:
		var path2: String = f
		button(path2.get_file(), func() -> void:
			var err := DB.import_database(path2)
			toast(err if err != "" else Lang.t("imported")), null, 520)
	big_button(Lang.t("restore_db"), func() -> void:
		DB.reset_to_original()
		toast(Lang.t("restored")))
