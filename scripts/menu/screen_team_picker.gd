extends MenuScreen
## Selector de equipo: ligas, selecciones por confederación y buscador.

var on_pick: Callable
var only_nations := false
var only_clubs := false
var _category := ""


func _init(cb: Callable, nations_only := false, clubs_only := false) -> void:
	super(Lang.t("choose_team"))
	on_pick = cb
	only_nations = nations_only
	only_clubs = clubs_only


func build() -> void:
	line_edit(Lang.t("search"), "", func(t: String) -> void: _search(t))
	if _category == "":
		if not only_nations:
			section(Lang.t("leagues"))
			for l in DB.leagues:
				var lid: String = l["id"]
				big_button("%s  (%d)" % [l["name"], l["teams"].size()], func() -> void:
					_category = "L:" + lid
					rebuild())
		if not only_clubs:
			section(Lang.t("national_teams"))
			for conf in ["UEFA", "CONMEBOL", "CONCACAF", "CAF", "AFC", "OFC"]:
				var c: String = conf
				big_button(Lang.t("selections_of") + " " + conf, func() -> void:
					_category = "N:" + c
					rebuild())
	else:
		button(Lang.t("all_categories"), func() -> void:
			_category = ""
			rebuild(), null, 260)
		var ids: Array = []
		if _category.begins_with("L:"):
			ids = DB.league(_category.substr(2)).get("teams", [])
		else:
			for n in DB.nations:
				if n.get("confed", "") == _category.substr(2):
					ids.append(n["id"])
			ids.sort_custom(func(a, b) -> bool: return DB.team_strength(a) > DB.team_strength(b))
		for id in ids:
			var tid: String = id
			team_row(tid, func() -> void: _choose(tid))


var _results: VBoxContainer


func _search(t: String) -> void:
	if _results == null:
		_results = VBoxContainer.new()
		content.add_child(_results)
		content.move_child(_results, 1)
	for c in _results.get_children():
		c.queue_free()
	if t.length() < 2:
		return
	var q := t.to_lower()
	var n := 0
	for tm in DB.teams.values():
		if (only_nations and not DB.is_nation(tm["id"])) or (only_clubs and DB.is_nation(tm["id"])):
			continue
		if str(tm["name"]).to_lower().contains(q):
			var tid: String = tm["id"]
			team_row(tid, func() -> void: _choose(tid), _results)
			n += 1
			if n >= 12:
				break


func _choose(tid: String) -> void:
	menu.pop()
	on_pick.call(tid)


func go_back() -> void:
	if _category != "":
		_category = ""
		rebuild()
	else:
		menu.pop()
