extends MenuScreen
## Entrenamiento: libre, tiros libres, penales y desafío de puntería.

var team := ""


func _init() -> void:
	super(Lang.t("m_training"))
	for t in DB.data.get("teams", []):
		if int(t.get("prestige", 0)) >= 5:
			team = t["id"]
			break


func build() -> void:
	team_row(team, func() -> void: menu.push(load("res://scripts/menu/screen_team_picker.gd").new(func(id: String) -> void:
		team = id
		rebuild())))
	for m in [["free", "tr_free"], ["freekick", "tr_freekick"], ["penalty", "tr_penalty"], ["challenge", "tr_challenge"]]:
		var mode: String = m[0]
		big_button(Lang.t(m[1]), func() -> void:
			var opp := ""
			for t in DB.data["teams"]:
				if t["id"] != team:
					opp = t["id"]
					break
			Game.session = {}
			Game.return_screen = "training"
			Game.start_match({"mode": "training", "training": mode, "home": team, "away": opp, "human_home": true,
				"presentation": false, "competition_name": Lang.t("m_training"), "stadium": DB.team(team).get("stadium", {})}))
	label(Lang.t("training_help"), 15, null, UITheme.DIM)
