extends MenuScreen
## Pantalla principal: modos de juego.


func _init() -> void:
	super("")


func build() -> void:
	var logo := VBoxContainer.new()
	content.add_child(logo)
	var t1 := Label.new()
	t1.text = "GOLAZO"
	t1.add_theme_font_size_override("font_size", 64)
	t1.add_theme_color_override("font_color", UITheme.WHITE)
	logo.add_child(t1)
	var t2 := Label.new()
	t2.text = "PRO 3D"
	t2.add_theme_font_size_override("font_size", 36)
	t2.add_theme_color_override("font_color", UITheme.YELLOW)
	logo.add_child(t2)
	var items := [
		[Lang.t("m_friendly"), "res://scripts/menu/screen_friendly.gd", []],
		[Lang.t("m_league"), "res://scripts/menu/screen_competition.gd", ["league", false]],
		[Lang.t("m_cup"), "res://scripts/menu/screen_competition.gd", ["cup", false]],
		[Lang.t("m_world"), "res://scripts/menu/screen_competition.gd", ["world", false]],
		[Lang.t("m_master"), "res://scripts/menu/screen_master.gd", [false]],
		[Lang.t("m_legend"), "res://scripts/menu/screen_legend.gd", [false]],
		[Lang.t("m_training"), "res://scripts/menu/screen_training.gd", []],
		[Lang.t("m_editor"), "res://scripts/menu/screen_editor.gd", []],
		[Lang.t("m_replays"), "res://scripts/menu/screen_replays.gd", []],
		[Lang.t("m_options"), "res://scripts/menu/screen_options.gd", []],
	]
	for it in items:
		var path: String = it[1]
		var args: Array = it[2]
		big_button(it[0], func() -> void:
			var scr: Object = load(path).new.callv(args)
			menu.push(scr))
	var foot := label("Juego de uso personal · base de datos editable · v1.0", 14, null, UITheme.DIM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func go_back() -> void:
	pass
