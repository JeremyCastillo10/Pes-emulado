class_name MatchHUD
extends CanvasLayer
## HUD del partido (estilo limpio azul oscuro / amarillo): marcador y reloj arriba,
## radar abajo, jugador controlado con resistencia y potencia, mensajes, menú de pausa,
## opciones y estadísticas de medio tiempo / final.

var match_node: Node = null
var touch: TouchControls

var _root: Control
var _msg: Label
var _msg_tween: Tween
var _fps: Label
var _home_lbl: Label
var _away_lbl: Label
var _score_lbl: Label
var _clock_lbl: Label
var _name_lbl: Label
var _stamina: ProgressBar
var _power: ProgressBar
var _radar: Radar
var _pause: PanelContainer
var _options: PanelContainer
var _stats: PanelContainer
var _stats_box: VBoxContainer
var _done_btn: Button
var _cam_lbl: Label
var _loading: PanelContainer
var _loading_bar: ProgressBar
var _replay_rect: ColorRect
var _replay_lbl: Label
var _skip_lbl: Label
var _skip := false
var _shootout_lbl: Label
var _subs: PanelContainer
var _subs_box: VBoxContainer
var _strat: PanelContainer
var _strat_box: VBoxContainer
var _sub_out: FootballPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.build()
	add_child(_root)
	touch = TouchControls.new()
	_root.add_child(touch)
	_build_scoreboard()
	_build_player_panel()
	_radar = Radar.new()
	_radar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_radar.size = Vector2(210, 136)
	_radar.position = Vector2(-105, -146)
	_root.add_child(_radar)
	var pause_btn := _button("II", toggle_pause)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.position = Vector2(-78, 12)
	pause_btn.custom_minimum_size = Vector2(62, 52)
	_root.add_child(pause_btn)
	_msg = Label.new()
	_msg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_msg.position = Vector2(-450, 120)
	_msg.size = Vector2(900, 140)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadowed(_msg, 46)
	_msg.modulate.a = 0.0
	_root.add_child(_msg)
	_fps = Label.new()
	_fps.position = Vector2(18, 96)
	_shadowed(_fps, 14)
	_root.add_child(_fps)
	_build_pause()
	_build_options()
	_build_stats()
	_build_overlays()
	_done_btn = _button(Lang.t("edit_controls_done"), func() -> void:
		touch.set_editing(false)
		_done_btn.visible = false)
	_done_btn.set_anchors_preset(Control.PRESET_CENTER)
	_done_btn.position = Vector2(-60, -30)
	_done_btn.visible = false
	_root.add_child(_done_btn)


func _build_overlays() -> void:
	_replay_rect = ColorRect.new()
	_replay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_replay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/replay_blur.gdshader")
	_replay_rect.material = sm
	_replay_rect.visible = false
	_root.add_child(_replay_rect)
	_root.move_child(_replay_rect, 0)
	_replay_lbl = Label.new()
	_replay_lbl.text = Lang.t("replay")
	_replay_lbl.position = Vector2(20, 100)
	_shadowed(_replay_lbl, 30)
	_replay_lbl.add_theme_color_override("font_color", UITheme.YELLOW)
	_replay_lbl.visible = false
	_root.add_child(_replay_lbl)
	_skip_lbl = Label.new()
	_skip_lbl.text = Lang.t("skip")
	_skip_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_skip_lbl.position = Vector2(-120, -40)
	_skip_lbl.size = Vector2(240, 30)
	_skip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadowed(_skip_lbl, 18)
	_skip_lbl.visible = false
	_root.add_child(_skip_lbl)
	_shootout_lbl = Label.new()
	_shootout_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_shootout_lbl.position = Vector2(-300, 70)
	_shootout_lbl.size = Vector2(600, 40)
	_shootout_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadowed(_shootout_lbl, 24)
	_shootout_lbl.visible = false
	_root.add_child(_shootout_lbl)
	_loading = PanelContainer.new()
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.NAVY
	_loading.add_theme_stylebox_override("panel", sb)
	var cc := CenterContainer.new()
	_loading.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 420
	cc.add_child(v)
	var t := _label("GOLAZO PRO", 46)
	t.add_theme_color_override("font_color", UITheme.YELLOW)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := _label(Lang.t("loading"), 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	_loading_bar = _bar(UITheme.YELLOW, 10)
	_loading_bar.custom_minimum_size.x = 420
	v.add_child(_loading_bar)
	_root.add_child(_loading)
	_subs = _overlay()
	var cc2 := CenterContainer.new()
	_subs.add_child(cc2)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(900, 600)
	cc2.add_child(sc)
	_subs_box = VBoxContainer.new()
	_subs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_subs_box)
	_strat = _overlay()
	var cc3 := CenterContainer.new()
	_strat.add_child(cc3)
	_strat_box = VBoxContainer.new()
	_strat_box.custom_minimum_size.x = 460
	_strat_box.add_theme_constant_override("separation", 10)
	cc3.add_child(_strat_box)


var _training_lbl: Label


func set_training_text(t: String) -> void:
	if _training_lbl == null:
		_training_lbl = Label.new()
		_training_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_training_lbl.position = Vector2(-300, 16)
		_training_lbl.size = Vector2(600, 40)
		_training_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shadowed(_training_lbl, 22)
		_training_lbl.add_theme_color_override("font_color", UITheme.YELLOW)
		_root.add_child(_training_lbl)
	_training_lbl.text = t


func show_loading(on: bool) -> void:
	_loading.visible = on


func set_loading(v: float) -> void:
	_loading_bar.value = v * 100.0


func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed):
		_skip = true


func consume_skip() -> bool:
	var s := _skip
	_skip = false
	return s


func show_replay(on: bool) -> void:
	_replay_rect.visible = on
	_replay_lbl.visible = on
	_skip_lbl.visible = on
	touch.visible = not on
	_skip = false


func refresh_shootout(so: Dictionary) -> void:
	_shootout_lbl.visible = true
	var marks := ["", ""]
	for i in 2:
		for k in so["kicks"][i]:
			marks[i] += "O " if k else "X "
	_shootout_lbl.text = "%s  %s|  %s  %s" % [match_node.teams[0].info.get("short", ""), marks[0], marks[1], match_node.teams[1].info.get("short", "")]


func _human_team() -> Team:
	if match_node and match_node.human:
		return match_node.human.team
	return null


func _open_subs() -> void:
	_pause.visible = false
	_sub_out = null
	_fill_subs()
	_subs.visible = true


func _fill_subs() -> void:
	for c in _subs_box.get_children():
		c.queue_free()
	var t := _human_team()
	if t == null:
		return
	var head := _label(Lang.t("subs") + " · " + Lang.t("subs_left") % (Team.MAX_SUBS - t.subs_made), 26)
	head.add_theme_color_override("font_color", UITheme.YELLOW)
	_subs_box.add_child(head)
	_subs_box.add_child(_label(Lang.t("choose_out") if _sub_out == null else Lang.t("choose_in"), 18))
	if _sub_out == null:
		for p in t.players:
			var txt := "%2d  %-4s %s   %d%%%s" % [int(p.data.get("number", 0)), p.role, p.display_name(), int(p.stamina * p.fitness * 100.0), "  +" if p.injured else ""]
			var pp := p
			var b := _button(txt, func() -> void:
				_sub_out = pp
				_fill_subs())
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_subs_box.add_child(b)
	else:
		for d in t.bench:
			var txt2 := "%2d  %-4s %s   %d" % [int(d.get("number", 0)), str(d.get("position", "")), str(d.get("name", "")), int(d.get("ovr", 0))]
			var dd: Dictionary = d
			var b2 := _button(txt2, func() -> void:
				if t.subs_made < Team.MAX_SUBS:
					match_node.human_substitution(t, _sub_out, dd)
				_sub_out = null
				_fill_subs())
			b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_subs_box.add_child(b2)
	_subs_box.add_child(_button(Lang.t("close"), func() -> void:
		_subs.visible = false
		_pause.visible = true))


func _open_strategy() -> void:
	_pause.visible = false
	for c in _strat_box.get_children():
		c.queue_free()
	var t := _human_team()
	var head := _label(Lang.t("strategy"), 30)
	head.add_theme_color_override("font_color", UITheme.YELLOW)
	_strat_box.add_child(head)
	if t != null:
		for key in Team.STRATEGIES.keys():
			var k: String = key
			var b := _menu_button(("> " if t.strategy == k else "   ") + Lang.t("strat_" + k), func() -> void:
				t.strategy = k
				_open_strategy())
			_strat_box.add_child(b)
	_strat_box.add_child(_menu_button(Lang.t("close"), func() -> void:
		_strat.visible = false
		_pause.visible = true))
	_strat.visible = true


func setup(m: Node) -> void:
	match_node = m
	_radar.match_node = m
	var t0: Team = m.teams[0]
	var t1: Team = m.teams[1]
	_home_lbl.text = str(t0.info.get("short", "LOC"))
	_away_lbl.text = str(t1.info.get("short", "VIS"))
	_home_lbl.get_parent().get_child(0).color = Color.html(str(t0.kit.get("shirt", "#fff")))
	_away_lbl.get_parent().get_child(_away_lbl.get_index() + 1).color = Color.html(str(t1.kit.get("shirt", "#fff")))
	refresh_score()


# ------------------------------------------------------------ Marcador

func _build_scoreboard() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(16, 12)
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	col.add_child(row)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UITheme.NAVY, 0.9)
	var strip_h := ColorRect.new()
	strip_h.custom_minimum_size = Vector2(6, 38)
	var p1 := PanelContainer.new()
	p1.add_theme_stylebox_override("panel", bg)
	var h1 := HBoxContainer.new()
	h1.add_theme_constant_override("separation", 8)
	h1.add_child(strip_h)
	_home_lbl = _label("LOC", 22)
	h1.add_child(_home_lbl)
	_score_lbl = _label("0 - 0", 24)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.WHITE
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", sb)
	_score_lbl.add_theme_color_override("font_color", UITheme.NAVY)
	sp.add_child(_score_lbl)
	h1.add_child(sp)
	_away_lbl = _label("VIS", 22)
	h1.add_child(_away_lbl)
	var strip_a := ColorRect.new()
	strip_a.custom_minimum_size = Vector2(6, 38)
	h1.add_child(strip_a)
	p1.add_child(h1)
	row.add_child(p1)
	var cb := StyleBoxFlat.new()
	cb.bg_color = UITheme.YELLOW
	cb.content_margin_left = 12
	cb.content_margin_right = 12
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", cb)
	_clock_lbl = _label("00:00", 20)
	_clock_lbl.add_theme_color_override("font_color", UITheme.NAVY)
	cp.add_child(_clock_lbl)
	cp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(cp)


func refresh_score() -> void:
	if match_node:
		_score_lbl.text = "%d - %d" % [match_node.score[0], match_node.score[1]]


func _build_player_panel() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	v.position = Vector2(16, -70)
	v.size = Vector2(250, 60)
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(v)
	_power = _bar(UITheme.YELLOW, 8)
	v.add_child(_power)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UITheme.NAVY, 0.85)
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", bg)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_lbl = _label("", 18)
	pc.add_child(_name_lbl)
	v.add_child(pc)
	_stamina = _bar(Color(0.25, 0.85, 0.95), 7)
	v.add_child(_stamina)


func _process(_delta: float) -> void:
	_fps.visible = GameSettings.show_fps
	if GameSettings.show_fps:
		_fps.text = "FPS %d · %s" % [Engine.get_frames_per_second(), Lang.t(GameSettings.QUALITY_KEYS[GameSettings.quality])]
	if match_node == null:
		return
	var c: float = match_node.clock
	_clock_lbl.text = "%02d:%02d" % [int(c / 60.0), int(fmod(c, 60.0))]
	var ht := _human_team()
	var p: FootballPlayer = ht.controlled if ht else null
	if p != null:
		_name_lbl.text = "%d   %s" % [int(p.data.get("number", 0)), p.display_name()]
		_stamina.value = p.stamina * 100.0
		_power.value = p.charge * 100.0
		_power.modulate.a = 1.0 if p.charging_action != "" else 0.0
	touch.player = p


func show_message(text: String, duration := 1.6, color := Color.WHITE) -> void:
	_msg.text = text
	_msg.modulate = color
	_msg.scale = Vector2(0.6, 0.6)
	_msg.pivot_offset = _msg.size * 0.5
	if _msg_tween:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(_msg, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(_msg, "modulate:a", 0.0, 0.4)


func on_camera_changed() -> void:
	if _cam_lbl:
		_cam_lbl.text = Lang.t("camera") + ": " + Lang.t(GameSettings.CAMERA_KEYS[GameSettings.camera_mode])
	show_message(Lang.t(GameSettings.CAMERA_KEYS[GameSettings.camera_mode]), 0.6)


# --------------------------------------------------------------- Pausa

func toggle_pause() -> void:
	if _stats.visible:
		return
	if _subs.visible or _strat.visible:
		_subs.visible = false
		_strat.visible = false
		_pause.visible = true
		return
	if _options.visible:
		_options.visible = false
		_pause.visible = true
		return
	if _pause.visible:
		_pause.visible = false
		get_tree().paused = false
	else:
		touch.release_all()
		_pause.visible = true
		get_tree().paused = true


func _build_pause() -> void:
	_pause = _overlay()
	var v := _center_column(_pause, 420)
	var title := _label(Lang.t("pause"), 34)
	title.add_theme_color_override("font_color", UITheme.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_menu_button(Lang.t("resume"), toggle_pause))
	_cam_lbl = _label("", 16)
	v.add_child(_menu_button(Lang.t("camera"), func() -> void:
		match_node.cam.cycle_mode()
		on_camera_changed()))
	v.add_child(_cam_lbl)
	v.add_child(_menu_button(Lang.t("subs"), _open_subs))
	v.add_child(_menu_button(Lang.t("strategy"), _open_strategy))
	v.add_child(_menu_button(Lang.t("replay_menu"), func() -> void:
		_pause.visible = false
		match_node.pause_replay()))
	v.add_child(_menu_button(Lang.t("stats"), func() -> void:
		_pause.visible = false
		show_stats(Lang.t("stats"), false, true)))
	v.add_child(_menu_button(Lang.t("settings"), func() -> void:
		_pause.visible = false
		_options.visible = true))
	v.add_child(_menu_button(Lang.t("restart_match"), func() -> void: match_node.restart_match()))
	v.add_child(_menu_button(Lang.t("abandon"), func() -> void:
		get_tree().paused = false
		match_node.leave_match()))


func _overlay() -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.03, 0.08, 0.86)
	p.add_theme_stylebox_override("panel", sb)
	p.visible = false
	_root.add_child(p)
	return p


func _center_column(parent: Control, width: float) -> VBoxContainer:
	var cc := CenterContainer.new()
	parent.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = width
	v.add_theme_constant_override("separation", 10)
	cc.add_child(v)
	return v


func _menu_button(text: String, cb: Callable) -> Button:
	var b := _button(text, cb)
	b.custom_minimum_size = Vector2(380, 56)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


# --------------------------------------------------------- Estadísticas

func _build_stats() -> void:
	_stats = _overlay()
	var cc := CenterContainer.new()
	_stats.add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	cc.add_child(panel)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 6)
	panel.add_child(_stats_box)


## Muestra el panel de estadísticas. final = fin del partido; from_pause = solo consulta.
func show_stats(title: String, final: bool, from_pause := false) -> void:
	for c in _stats_box.get_children():
		c.queue_free()
	var m := match_node
	var t0: Team = m.teams[0]
	var t1: Team = m.teams[1]
	var head := _label(title, 30)
	head.add_theme_color_override("font_color", UITheme.YELLOW)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_box.add_child(head)
	var pen: Array = m._pen_score()
	var sc := _label("%s   %d - %d   %s%s" % [t0.info.get("name"), m.score[0], m.score[1], t1.info.get("name"), ("   (%d-%d %s)" % [pen[0], pen[1], Lang.t("pen_short")]) if pen.size() == 2 else ""], 24)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_box.add_child(sc)
	for e in m.events:
		if e.get("kind", "") == "goal":
			var gl := _label("%d'  %s%s" % [e["minute"], e["player"], " (p.p.)" if e.get("own_goal", false) else ""], 16)
			gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if e["team"] == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			_stats_box.add_child(gl)
	var st: Dictionary = m.stats
	var pos_total: float = st["possession"][0] + st["possession"][1]
	var pos0 := 50 if pos_total <= 0.0 else int(round(st["possession"][0] / pos_total * 100.0))
	_stat_row(Lang.t("st_possession"), "%d%%" % pos0, "%d%%" % (100 - pos0))
	_stat_row(Lang.t("st_shots"), str(st["shots"][0]), str(st["shots"][1]))
	_stat_row(Lang.t("st_on_target"), str(st["on_target"][0]), str(st["on_target"][1]))
	_stat_row(Lang.t("st_corners"), str(st["corners"][0]), str(st["corners"][1]))
	_stat_row(Lang.t("st_fouls"), str(st["fouls"][0]), str(st["fouls"][1]))
	var p0 := "%d/%d" % [st["passes_ok"][0], st["passes"][0]]
	var p1 := "%d/%d" % [st["passes_ok"][1], st["passes"][1]]
	_stat_row(Lang.t("st_passes"), p0, p1)
	var btn: Button
	if from_pause:
		btn = _button(Lang.t("close"), func() -> void:
			_stats.visible = false
			_pause.visible = true)
	elif final:
		btn = _button(Lang.t("continue"), func() -> void:
			_stats.visible = false
			get_tree().paused = false
			match_node.leave_match())
	else:
		btn = _button(Lang.t("continue"), func() -> void:
			_stats.visible = false
			get_tree().paused = false
			match_node.start_next_period())
	btn.custom_minimum_size = Vector2(300, 56)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stats_box.add_child(btn)
	touch.release_all()
	_stats.visible = true
	get_tree().paused = true


func _stat_row(name: String, a: String, b: String) -> void:
	var h := HBoxContainer.new()
	var la := _label(a, 20)
	la.custom_minimum_size.x = 120
	la.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ln := _label(name, 18)
	ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ln.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ln.add_theme_color_override("font_color", UITheme.DIM)
	var lb := _label(b, 20)
	lb.custom_minimum_size.x = 120
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(la)
	h.add_child(ln)
	h.add_child(lb)
	_stats_box.add_child(h)


# ------------------------------------------------------------ Opciones

func _build_options() -> void:
	_options = _overlay()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_options.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(margin)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)
	var title := _label(Lang.t("settings"), 32)
	title.add_theme_color_override("font_color", UITheme.YELLOW)
	v.add_child(title)
	_choice_row(v, Lang.t("quality"), ["quality_auto", "quality_low", "quality_medium", "quality_high"],
		0 if GameSettings.auto_quality else GameSettings.quality + 1,
		func(i: int) -> void:
			if i == 0:
				GameSettings.set_quality(0, true)
			else:
				GameSettings.set_quality(i - 1, false))
	_choice_row(v, Lang.t("camera"), GameSettings.CAMERA_KEYS, GameSettings.camera_mode,
		func(i: int) -> void:
			GameSettings.camera_mode = i
			GameSettings.save_settings())
	_choice_row(v, Lang.t("difficulty") + " *", ["diff_beginner", "diff_amateur", "diff_pro", "diff_superstar", "diff_legend"], GameSettings.difficulty,
		func(i: int) -> void:
			GameSettings.difficulty = i
			GameSettings.save_settings())
	_choice_row(v, Lang.t("half_length") + " *", ["2 min", "4 min", "6 min", "8 min", "10 min"], [2, 4, 6, 8, 10].find(int(GameSettings.half_minutes)),
		func(i: int) -> void:
			GameSettings.half_minutes = [2.0, 4.0, 6.0, 8.0, 10.0][i]
			GameSettings.save_settings())
	_choice_row(v, Lang.t("time_of_day"), GameSettings.TIME_KEYS, GameSettings.time_of_day,
		func(i: int) -> void:
			GameSettings.time_of_day = i
			GameSettings.save_settings()
			match_node.stadium.apply_time_of_day(i))
	_choice_row(v, Lang.t("pitch_state"), ["pitch_dry", "pitch_wet"], 1 if GameSettings.wet_pitch else 0,
		func(i: int) -> void:
			GameSettings.wet_pitch = i == 1
			GameSettings.save_settings()
			match_node.stadium.set_wet(i == 1)
			match_node.ball.set_wet(i == 1))
	_choice_row(v, Lang.t("mow_pattern"), ["mow_0", "mow_1", "mow_2", "mow_3", "mow_4"], -1,
		func(i: int) -> void: match_node.stadium.set_pitch_pattern(i), false)
	_slider_row(v, Lang.t("controls_opacity"), 0.15, 1.0, GameSettings.controls_opacity,
		func(val: float) -> void:
			GameSettings.controls_opacity = val
			GameSettings.save_settings())
	_slider_row(v, Lang.t("controls_scale"), 0.7, 1.4, GameSettings.controls_scale,
		func(val: float) -> void:
			GameSettings.controls_scale = val
			GameSettings.save_settings())
	_choice_row(v, Lang.t("vibration"), ["on", "off"], 0 if GameSettings.vibration else 1,
		func(i: int) -> void:
			GameSettings.vibration = i == 0
			GameSettings.save_settings())
	_choice_row(v, Lang.t("show_fps"), ["on", "off"], 0 if GameSettings.show_fps else 1,
		func(i: int) -> void:
			GameSettings.show_fps = i == 0
			GameSettings.save_settings())
	var note := _label(Lang.t("applies_next_match"), 15)
	note.add_theme_color_override("font_color", UITheme.DIM)
	v.add_child(note)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	v.add_child(actions)
	actions.add_child(_button(Lang.t("edit_controls"), func() -> void:
		_options.visible = false
		get_tree().paused = false
		touch.set_editing(true)
		_done_btn.visible = true))
	actions.add_child(_button(Lang.t("reset_controls"), func() -> void: touch.reset_layout()))
	var close := _button(Lang.t("close"), toggle_pause)
	close.custom_minimum_size = Vector2(220, 60)
	v.add_child(close)
	var help := _label(Lang.t("controls_help"), 15)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(help)


func _choice_row(parent: Control, label: String, keys: Array, selected: int, cb: Callable, toggle := true) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	var l := _label(label, 20)
	l.custom_minimum_size.x = 250
	h.add_child(l)
	var group := ButtonGroup.new()
	for i in keys.size():
		var b := Button.new()
		b.text = Lang.t(keys[i])
		b.custom_minimum_size = Vector2(112, 50)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 17)
		if toggle:
			b.toggle_mode = true
			b.button_group = group
			b.button_pressed = i == selected
		var idx := i
		b.pressed.connect(func() -> void: cb.call(idx))
		h.add_child(b)


func _slider_row(parent: Control, label: String, mn: float, mx: float, val: float, cb: Callable) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := _label(label, 20)
	l.custom_minimum_size.x = 250
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(360, 50)
	s.value_changed.connect(func(x: float) -> void: cb.call(x))
	h.add_child(s)


# -------------------------------------------------------------- Helpers

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 52)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _bar(c: Color, h: float) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(250, h)
	p.show_percentage = false
	p.max_value = 100
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fg := StyleBoxFlat.new()
	fg.bg_color = c
	fg.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(3)
	p.add_theme_stylebox_override("fill", fg)
	p.add_theme_stylebox_override("background", bg)
	return p


func _shadowed(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
