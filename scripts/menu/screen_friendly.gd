extends MenuScreen
## Partido amistoso: equipos, quién controla cada uno (contra la IA o 2 jugadores con mando),
## dificultad, duración, estadio, hora, clima, uniformes y alineaciones.

var home := ""
var away := ""
var sides := 0          # 0 Tú vs IA, 1 IA vs Tú, 2 dos jugadores, 3 IA vs IA
var home_kit := 0
var away_kit := 1
var weather := 0
var stadium_from := 0   # 0 local, 1 visitante, 2 neutral
const KITS := ["home", "away", "third"]


func _init() -> void:
	super(Lang.t("m_friendly"))
	_defaults()


func _defaults() -> void:
	var big: Array = []
	for t in DB.data.get("teams", []):
		if int(t.get("prestige", 0)) >= 5:
			big.append(t["id"])
	big.shuffle()
	if big.size() >= 2:
		home = big[0]
		away = big[1]


func build() -> void:
	section(Lang.t("teams"))
	var r := row(null, 20)
	var hb := VBoxContainer.new()
	r.add_child(hb)
	label(Lang.t("home_team"), 16, hb, UITheme.DIM)
	team_row(home, func() -> void: menu.push(load("res://scripts/menu/screen_team_picker.gd").new(func(id: String) -> void:
		home = id
		rebuild())), hb).custom_minimum_size.x = 470
	button(Lang.t("lineup"), func() -> void: menu.push(load("res://scripts/menu/screen_lineup.gd").new(home)), hb, 200)
	var ab := VBoxContainer.new()
	r.add_child(ab)
	label(Lang.t("away_team"), 16, ab, UITheme.DIM)
	team_row(away, func() -> void: menu.push(load("res://scripts/menu/screen_team_picker.gd").new(func(id: String) -> void:
		away = id
		rebuild())), ab).custom_minimum_size.x = 470
	button(Lang.t("lineup"), func() -> void: menu.push(load("res://scripts/menu/screen_lineup.gd").new(away)), ab, 200)
	section(Lang.t("settings_match"))
	cycler(Lang.t("control"), [Lang.t("sides_0"), Lang.t("sides_1"), Lang.t("sides_2"), Lang.t("sides_3")], sides, func(i: int) -> void: sides = i)
	cycler(Lang.t("difficulty"), [Lang.t("diff_beginner"), Lang.t("diff_amateur"), Lang.t("diff_pro"), Lang.t("diff_superstar"), Lang.t("diff_legend")], GameSettings.difficulty, func(i: int) -> void:
		GameSettings.difficulty = i
		GameSettings.save_settings())
	var durs := [2.0, 4.0, 6.0, 8.0, 10.0, 15.0]
	cycler(Lang.t("half_length"), durs.map(func(d): return "%d min" % int(d)), maxi(durs.find(GameSettings.half_minutes), 0), func(i: int) -> void:
		GameSettings.half_minutes = durs[i]
		GameSettings.save_settings())
	cycler(Lang.t("stadium"), [Lang.t("st_home"), Lang.t("st_away"), Lang.t("st_neutral")], stadium_from, func(i: int) -> void: stadium_from = i)
	cycler(Lang.t("time_of_day"), [Lang.t("time_day"), Lang.t("time_sunset"), Lang.t("time_night")], GameSettings.time_of_day, func(i: int) -> void:
		GameSettings.time_of_day = i)
	cycler(Lang.t("weather"), [Lang.t("weather_clear"), Lang.t("weather_rain")], weather, func(i: int) -> void: weather = i)
	cycler(Lang.t("home_kit"), [Lang.t("kit_home"), Lang.t("kit_away"), Lang.t("kit_third")], home_kit, func(i: int) -> void: home_kit = i)
	cycler(Lang.t("away_kit"), [Lang.t("kit_home"), Lang.t("kit_away"), Lang.t("kit_third")], away_kit, func(i: int) -> void: away_kit = i)
	if sides == 2 and Input.get_connected_joypads().size() < 1:
		label(Lang.t("two_players_hint"), 15, null, UITheme.DIM)
	var go := big_button(Lang.t("play"), _play)
	go.add_theme_color_override("font_color", UITheme.YELLOW)


func _play() -> void:
	if home == "" or away == "":
		return
	var st: Dictionary = DB.team(home).get("stadium", {})
	if stadium_from == 1:
		st = DB.team(away).get("stadium", {})
	elif stadium_from == 2:
		st = {"name": "Estadio Neutral", "capacity": 55000, "roof": true, "seat_color": "#1d3c8f", "pattern": randi() % 5}
	if DB.is_nation(home) and stadium_from == 0:
		st = {"name": "Estadio Nacional", "capacity": 65000, "roof": true, "seat_color": DB.team(home).get("crest", {}).get("c1", "#203070")}
	Game.session = {}
	Game.return_screen = "friendly"
	Game.start_match({"mode": "friendly", "home": home, "away": away,
		"human_home": sides in [0, 2], "human_away": sides in [1, 2], "two_players": sides == 2,
		"home_kit": KITS[home_kit], "away_kit": KITS[away_kit], "stadium": st, "weather": "rain" if weather == 1 else "clear",
		"time_of_day": GameSettings.time_of_day, "difficulty": GameSettings.difficulty, "half_minutes": GameSettings.half_minutes,
		"home_strategy": str(DB.team(home).get("strategy", "normal")), "away_strategy": str(DB.team(away).get("strategy", "normal")),
		"competition_name": Lang.t("m_friendly")})
