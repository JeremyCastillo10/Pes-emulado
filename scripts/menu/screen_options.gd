extends MenuScreen
## Opciones generales del juego.


func _init() -> void:
	super(Lang.t("m_options"))


func build() -> void:
	section(Lang.t("graphics"))
	cycler(Lang.t("quality"), [Lang.t("quality_auto"), Lang.t("quality_low"), Lang.t("quality_medium"), Lang.t("quality_high")],
		0 if GameSettings.auto_quality else GameSettings.quality + 1, func(i: int) -> void:
			if i == 0:
				GameSettings.set_quality(0, true)
			else:
				GameSettings.set_quality(i - 1, false))
	cycler(Lang.t("camera"), GameSettings.CAMERA_KEYS.map(func(k): return Lang.t(k)), GameSettings.camera_mode, func(i: int) -> void:
		GameSettings.camera_mode = i
		GameSettings.save_settings())
	cycler(Lang.t("show_fps"), [Lang.t("on"), Lang.t("off")], 0 if GameSettings.show_fps else 1, func(i: int) -> void:
		GameSettings.show_fps = i == 0
		GameSettings.save_settings())
	section(Lang.t("game"))
	cycler(Lang.t("difficulty"), [Lang.t("diff_beginner"), Lang.t("diff_amateur"), Lang.t("diff_pro"), Lang.t("diff_superstar"), Lang.t("diff_legend")], GameSettings.difficulty, func(i: int) -> void:
		GameSettings.difficulty = i
		GameSettings.save_settings())
	var durs := [2.0, 4.0, 6.0, 8.0, 10.0, 15.0]
	cycler(Lang.t("half_length"), durs.map(func(d): return "%d min" % int(d)), maxi(durs.find(GameSettings.half_minutes), 0), func(i: int) -> void:
		GameSettings.half_minutes = durs[i]
		GameSettings.save_settings())
	cycler(Lang.t("auto_replay"), [Lang.t("on"), Lang.t("off")], 0 if GameSettings.auto_replay else 1, func(i: int) -> void:
		GameSettings.auto_replay = i == 0
		GameSettings.save_settings())
	cycler(Lang.t("save_goals"), [Lang.t("on"), Lang.t("off")], 0 if GameSettings.save_goal_replays else 1, func(i: int) -> void:
		GameSettings.save_goal_replays = i == 0
		GameSettings.save_settings())
	section(Lang.t("audio"))
	cycler(Lang.t("commentary"), [Lang.t("on"), Lang.t("off")], 0 if GameSettings.commentary else 1, func(i: int) -> void:
		GameSettings.commentary = i == 0
		GameSettings.save_settings())
	slider(Lang.t("commentary_volume"), 0.0, 1.0, 0.05, GameSettings.commentary_volume, func(v: float) -> void:
		GameSettings.commentary_volume = v
		GameSettings.save_settings())
	cycler(Lang.t("music"), [Lang.t("on"), Lang.t("off")], 0 if GameSettings.music else 1, func(i: int) -> void:
		GameSettings.music = i == 0
		Audio.music_on = GameSettings.music
		if GameSettings.music:
			Audio.play_music()
		else:
			Audio.stop_music()
		GameSettings.save_settings())
	slider(Lang.t("sfx_volume"), -20.0, 6.0, 1.0, GameSettings.sfx_volume_db, func(v: float) -> void:
		GameSettings.sfx_volume_db = v
		Audio.sfx_volume = v
		GameSettings.save_settings())
	label(Lang.t("narration_help"), 15, null, UITheme.DIM)
	section(Lang.t("controls"))
	slider(Lang.t("controls_opacity"), 0.15, 1.0, 0.05, GameSettings.controls_opacity, func(v: float) -> void:
		GameSettings.controls_opacity = v
		GameSettings.save_settings())
	slider(Lang.t("controls_scale"), 0.7, 1.4, 0.05, GameSettings.controls_scale, func(v: float) -> void:
		GameSettings.controls_scale = v
		GameSettings.save_settings())
	cycler(Lang.t("vibration"), [Lang.t("on"), Lang.t("off")], 0 if GameSettings.vibration else 1, func(i: int) -> void:
		GameSettings.vibration = i == 0
		GameSettings.save_settings())
	button(Lang.t("reset_controls"), func() -> void:
		GameSettings.button_offsets = {}
		GameSettings.save_settings()
		toast(Lang.t("saved")), null, 300)
	label(Lang.t("controls_help"), 15, null, UITheme.DIM)
	label(Lang.t("controls_extra_help"), 15, null, UITheme.DIM)
