extends MenuScreen
## Repeticiones guardadas de goles.


func _init() -> void:
	super(Lang.t("m_replays"))


func build() -> void:
	var files := ReplaySystem.list_saved()
	if files.is_empty():
		label(Lang.t("no_replays"), 20)
		return
	for path in files:
		var p: String = path
		var title := p.get_file()
		var f := FileAccess.open(p, FileAccess.READ)
		if f:
			var head := f.get_buffer(400).get_string_from_utf8()
			var i := head.find("\"title\":\"")
			if i >= 0:
				var j := head.find("\"", i + 9)
				title = head.substr(i + 9, j - i - 9)
		var r := row()
		button(title, func() -> void:
			Game.match_config = {"replay_file": p}
			Game.change_scene("res://scenes/menu/replay_viewer.tscn", Lang.t("replay")), r, 640)
		button(Lang.t("delete"), func() -> void:
			DirAccess.remove_absolute(p)
			rebuild(), r, 140)
