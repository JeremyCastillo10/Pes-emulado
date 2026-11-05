extends Node3D
## Escena de partido (Fase 1: práctica libre con un jugador).
## Monta estadio, balón, jugador, cámara y HUD, y gestiona goles y balones fuera.

const BallScene := preload("res://scenes/match/ball.tscn")
const PlayerScene := preload("res://scenes/match/player.tscn")
const HUDScene := preload("res://scenes/ui/hud.tscn")

var stadium: StadiumBuilder
var ball: Ball
var player: FootballPlayer
var cam: CameraRig
var hud: MatchHUD
var _restart_timer := -1.0
var _excitement := 0.15
var _autotest := false
var _shots_dir := ""
var _autotest_t := 0.0


func _ready() -> void:
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
			_autotest = true
	stadium = StadiumBuilder.new()
	stadium.name = "Stadium"
	add_child(stadium)
	stadium.build()

	ball = BallScene.instantiate()
	add_child(ball)
	ball.place(Vector3(1.0, 0, 0))
	ball.goal_scored.connect(_on_goal)
	ball.post_hit.connect(_on_post)
	ball.out_of_play.connect(_on_out)
	ball.net_hit.connect(func(pos: Vector3, s: float) -> void: stadium.net_impact(pos, s))

	cam = CameraRig.new()
	cam.name = "Camera"
	add_child(cam)
	cam.current = true

	player = PlayerScene.instantiate()
	player.ball = ball
	player.cam = cam
	add_child(player)
	player.reset_at(Vector3(0, 0, 0), Vector3(1, 0, 0))
	player.action_message.connect(func(t: String) -> void: hud.show_message(t, 0.6))
	player.shot_fired.connect(func(_p: float) -> void: _excitement = maxf(_excitement, 0.5))

	cam.ball = ball
	cam.player = player

	hud = HUDScene.instantiate()
	add_child(hud)
	hud.player = player
	hud.touch.player = player
	hud.camera_cycle_requested.connect(_cycle_camera)
	hud.reset_ball_requested.connect(_reset_ball)
	hud.time_of_day_changed.connect(func(t: int) -> void: stadium.apply_time_of_day(t))
	hud.wet_changed.connect(func(w: bool) -> void:
		stadium.set_wet(w)
		ball.set_wet(w))
	hud.pattern_changed.connect(func(p: int) -> void: stadium.set_pitch_pattern(p))
	GameSettings.quality_changed.connect(_on_quality_changed)
	_on_quality_changed(GameSettings.quality)


func _on_quality_changed(_q: int) -> void:
	stadium.set_shadows(GameSettings.shadows_enabled())
	if player and player.model:
		player.set_shadows(GameSettings.shadows_enabled())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_cycle"):
		_cycle_camera()
	elif event.is_action_pressed("pause"):
		if get_tree().paused:
			hud.close_options()
		else:
			hud.open_options()


func _notification(what: int) -> void:
	# Botón "atrás" de Android: abre/cierra opciones en lugar de salir
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_tree().paused:
			hud.close_options()
		else:
			hud.open_options()
	elif what == NOTIFICATION_APPLICATION_PAUSED and not get_tree().paused:
		hud.open_options()


func _cycle_camera() -> void:
	cam.cycle_mode()
	hud.on_camera_changed()


func _process(delta: float) -> void:
	# El público se calma poco a poco; se emociona cerca del área rival
	var near_goal := absf(ball.position.x) > PitchDims.HALF_LENGTH - 20.0 and absf(ball.position.z) < 20.0
	var base := 0.35 if near_goal else 0.12
	_excitement = move_toward(_excitement, base, delta * 0.25)
	stadium.set_crowd_excitement(_excitement)
	if _restart_timer > 0.0:
		_restart_timer -= delta
		if _restart_timer <= 0.0:
			_reset_ball()
	if _autotest:
		_run_autotest(delta)


func _on_goal(side: int) -> void:
	_excitement = 1.0
	hud.show_message(Lang.t("goal"), 2.2, Color(1.0, 0.9, 0.2))
	InputHub.vibrate(350)
	cam.shake = 0.5
	player.celebrate()
	_restart_timer = 3.5
	print("GOL en la portería ", side)


func _on_post(is_crossbar: bool, spd: float) -> void:
	if spd > 3.0:
		hud.show_message(Lang.t("crossbar" if is_crossbar else "post"), 1.0)
		_excitement = maxf(_excitement, 0.8)
		print("Poste ", is_crossbar)


func _on_out(kind: String, pos: Vector3) -> void:
	var key := "out_throw_in"
	if kind == "goal_line":
		key = "out_corner" if (ball.last_touch == player and signf(pos.x) == -player.attack_side) else "out_goal_kick"
		if signf(pos.x) == player.attack_side:
			key = "out_goal_kick"
	hud.show_message(Lang.t(key), 1.2)
	_restart_timer = 1.6
	print("Fuera: ", kind)


func _reset_ball() -> void:
	_restart_timer = -1.0
	var p := player.global_position + player.heading * 1.2
	p.x = clampf(p.x, -PitchDims.HALF_LENGTH + 2.0, PitchDims.HALF_LENGTH - 2.0)
	p.z = clampf(p.z, -PitchDims.HALF_WIDTH + 2.0, PitchDims.HALF_WIDTH - 2.0)
	if ball.in_goal != 0 or absf(player.global_position.x) > PitchDims.HALF_LENGTH - 1.0:
		player.reset_at(Vector3(0, 0, 0), Vector3(player.attack_side, 0, 0))
		p = Vector3(1.0, 0, 0)
	elif player.state == FootballPlayer.State.CELEBRATE:
		player.reset_at(player.global_position, player.heading)
	ball.place(p)


# Prueba automática (sin pantalla): conduce, regatea, tira, pase largo y barrida.
# Ejecutar: godot --headless --path . -- --autotest
const AUTOTEST := [
	[0.0, "press", "move_right"], [2.0, "press", "act_trick"], [2.1, "release", "act_trick"],
	[4.2, "press", "act_shoot"], [4.75, "release", "act_shoot"], [4.8, "release", "move_right"],
	[9.0, "reset", ""], [9.2, "press", "move_up"], [10.5, "press", "act_trick"], [10.6, "release", "act_trick"],
	[11.0, "release", "move_up"], [11.0, "press", "move_left"], [11.8, "press", "act_lob"], [12.4, "release", "act_lob"],
	[12.5, "release", "move_left"], [15.0, "press", "act_shoot"], [15.1, "release", "act_shoot"],
	[17.0, "quit", ""],
]
var _autotest_step := 0


func _run_autotest(delta: float) -> void:
	_autotest_t += delta
	var t := _autotest_t
	while _autotest_step < AUTOTEST.size() and t >= float(AUTOTEST[_autotest_step][0]):
		var ev: Array = AUTOTEST[_autotest_step]
		_autotest_step += 1
		print("  >> %s %s" % [ev[1], ev[2]])
		match ev[1]:
			"press": Input.action_press(ev[2])
			"release": Input.action_release(ev[2])
			"reset": _reset_ball()
			"quit": get_tree().quit()
	if _shots_dir != "":
		_shots(t, delta)
	if int(t * 4.0) != int((t - delta) * 4.0):
		print("t=%.2f jug=%s balón=%s v=%.1f pos=%s est=%d res=%.2f" % [t, str(player.global_position.snapped(Vector3.ONE * 0.1)), str(ball.position.snapped(Vector3.ONE * 0.1)), ball.velocity.length(), player.has_ball, player.state, player.stamina])


# Capturas de pantalla para revisar el aspecto (requiere un renderizador real).
const SHOTS := [
	[2.2, 0, 0, "broadcast_day"], [3.0, 2, 0, "close_day"], [4.4, 1, 1, "wide_sunset"],
	[5.6, 3, 2, "behind_night"], [6.2, 0, 2, "goal_night"],
]
var _shot_step := 0


func _shots(t: float, _delta: float) -> void:
	if _shot_step >= SHOTS.size():
		return
	var sh: Array = SHOTS[_shot_step]
	# Ajusta cámara/hora un poco antes de la captura
	if t >= float(sh[0]) - 0.8 and GameSettings.camera_mode != int(sh[1]):
		GameSettings.camera_mode = int(sh[1])
	if t >= float(sh[0]) - 0.8 and GameSettings.time_of_day != int(sh[2]):
		GameSettings.time_of_day = int(sh[2])
		stadium.apply_time_of_day(int(sh[2]))
	if t >= float(sh[0]):
		_shot_step += 1
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shots_dir.path_join(str(sh[3]) + ".png"))
		print("captura ", sh[3])
