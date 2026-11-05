extends Node3D
## Partido completo. Monta estadio (carga por partes), balón, equipos desde la base de datos,
## cámara, HUD, narración, árbitro y repeticiones, y dirige el reglamento: saque inicial,
## banda, córner, meta, faltas con ventaja, tarjetas, lesiones, fuera de juego, tiros libres
## con barrera, penales, cambios, prórroga y tanda de penales. Al final envía el resultado al
## modo de juego (Game.finish_match).

enum Phase { LOADING, INTRO, KICKOFF, PLAYING, RESTART, GOAL, HALFTIME, FULLTIME, PENALTY, SHOOTOUT, REPLAY, TRAINING }

const BallScene := preload("res://scenes/match/ball.tscn")
const HUDScene := preload("res://scenes/ui/hud.tscn")
const PERIOD_END := [45.0, 90.0, 105.0, 120.0]

var cfg: Dictionary = {}
var stadium: StadiumBuilder
var ball: Ball
var teams: Array[Team] = []
var human: HumanController
var human2: HumanController
var cam: CameraRig
var hud: MatchHUD
var commentary: Commentary
var referee: Referee
var replay: ReplaySystem
var weather: Weather
var training: Node = null

var phase: Phase = Phase.LOADING
var period := 1
var clock := 0.0                 # segundos de juego (0..120*60)
var score := [0, 0]
var stats := {}
var events: Array = []
var restart_kind := ""
var restart_team := 0
var restart_taker: FootballPlayer = null
var shootout := {"kicks": [[], []], "turn": 0, "taker_idx": [0, 0], "pending": false, "t": 0.0}
var _phase_t := 0.0
var _last_owner: Node = null
var _pending_pass_team := -1
var _contact_cd := {}
var _pending_foul := {}
var _offside_cands: Array = []
var _offside_team := -1
var _last_touch_seen: Node = null
var _last_pass := {}
var _queued: Array = []
var _after_replay := ""
var _sub_check_min := 0
var _rng := RandomNumberGenerator.new()
var _late_said := false
var _lead_history: Array = []    # para detectar remontadas

# Pruebas automáticas
var _autotest := false
var _shots_dir := ""
var _autotest_quit := 0.0


func _ready() -> void:
	_rng.randomize()
	var args := OS.get_cmdline_user_args()
	_autotest = "--autotest" in args
	for a in args:
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
			_autotest = true
		if a.begins_with("--quit-after-min="):
			_autotest_quit = float(a.substr(17))
	if not DB.is_loaded:
		DB.load_now()
	cfg = Game.match_config.duplicate(true)
	if cfg.is_empty() or str(cfg.get("home", "")) == "":
		cfg = _default_config()
	if _autotest:
		cfg["human_home"] = "--humantest" in args
		cfg["human_away"] = false
		cfg["presentation"] = false
		var custom_half := false
		for a in args:
			if a.begins_with("--half="):
				cfg["half_minutes"] = float(a.substr(7))
				custom_half = true
		if not custom_half:
			cfg["half_minutes"] = 2.0
		Engine.set_meta("debug", true)
	GameSettings.time_of_day = int(cfg.get("time_of_day", GameSettings.time_of_day))
	GameSettings.wet_pitch = str(cfg.get("weather", "clear")) == "rain"
	_reset_stats()
	_build()


func _default_config() -> Dictionary:
	var c := Game.default_match_config()
	var big: Array = []
	for t in DB.teams.values():
		if int(t.get("prestige", 0)) >= 5:
			big.append(t["id"])
	big.shuffle()
	c["home"] = big[0] if big.size() > 0 else DB.teams.keys()[0]
	c["away"] = big[1] if big.size() > 1 else DB.teams.keys()[1]
	c["stadium"] = DB.team(c["home"]).get("stadium", {})
	return c


func _build() -> void:
	hud = HUDScene.instantiate()
	add_child(hud)
	hud.show_loading(true)
	stadium = StadiumBuilder.new()
	stadium.name = "Stadium"
	add_child(stadium)
	var st: Dictionary = cfg.get("stadium", {})
	if st.is_empty():
		st = DB.team(cfg["home"]).get("stadium", {"name": "Estadio Golazo"})
	cfg["stadium"] = st
	await stadium.build_async(st, func(v: float) -> void: hud.set_loading(v * 0.8))
	stadium.apply_time_of_day(GameSettings.time_of_day)
	stadium.set_wet(GameSettings.wet_pitch)
	ball = BallScene.instantiate()
	add_child(ball)
	ball.place(Vector3.ZERO)
	ball.process_physics_priority = 10
	ball.goal_scored.connect(_on_goal)
	ball.post_hit.connect(_on_post)
	ball.out_of_play.connect(_on_out)
	ball.kicked.connect(_on_ball_kicked)
	ball.net_hit.connect(func(pos: Vector3, s: float) -> void:
		stadium.net_impact(pos, s)
		Audio.play("net", -4.0))
	cam = CameraRig.new()
	cam.name = "Camera"
	add_child(cam)
	cam.current = true
	cam.ball = ball
	weather = Weather.new()
	add_child(weather)
	weather.setup(cam, GameSettings.wet_pitch)
	await get_tree().process_frame
	_create_teams()
	hud.set_loading(0.95)
	referee = Referee.new()
	add_child(referee)
	referee.ball = ball
	referee.position = Vector3(-5, 0, -8)
	commentary = Commentary.new()
	add_child(commentary)
	commentary.ctx_base = {"local": teams[0].info.get("name", ""), "visitante": teams[1].info.get("name", ""),
		"estadio": str(st.get("name", "estadio"))}
	replay = ReplaySystem.new()
	replay.match_node = self
	add_child(replay)
	for t in teams:
		replay.register(t.players)
	hud.setup(self)
	hud.show_loading(false)
	GameSettings.quality_changed.connect(_on_quality_changed)
	_on_quality_changed(GameSettings.quality)
	Audio.start_match_ambience()
	if str(cfg.get("mode", "")) == "training":
		training = load("res://scripts/match/training.gd").new()
		add_child(training)
		training.setup(self, str(cfg.get("training", "free")))
		return
	if bool(cfg.get("presentation", true)) and not _autotest:
		_start_intro()
	else:
		start_kickoff(0)


func _create_teams() -> void:
	var home_info := DB.match_team(cfg["home"], cfg.get("home_lineup", []), str(cfg.get("home_formation", "")))
	var away_info := DB.match_team(cfg["away"], cfg.get("away_lineup", []), str(cfg.get("away_formation", "")))
	var away_kit := str(cfg.get("away_kit", "away"))
	if away_kit == "auto" or away_kit == "":
		away_kit = "away" if _kits_clash(home_info, away_info, "home") else "home"
	var diff := int(cfg.get("difficulty", 2))
	var t0 := Team.new()
	t0.name = "TeamHome"
	add_child(t0)
	t0.setup(home_info, 1, bool(cfg.get("human_home", true)), ball, str(cfg.get("home_kit", "home")), 2 if cfg.get("human_home", true) else diff, self)
	var t1 := Team.new()
	t1.name = "TeamAway"
	add_child(t1)
	t1.setup(away_info, -1, bool(cfg.get("human_away", false)), ball, away_kit, 2 if cfg.get("human_away", false) else diff, self)
	t0.opponent = t1
	t1.opponent = t0
	t0.strategy = str(cfg.get("home_strategy", "normal"))
	t1.strategy = str(cfg.get("away_strategy", "normal"))
	teams = [t0, t1]
	for t in teams:
		t.process_physics_priority = -10
		for p in t.players:
			_wire_player(p)
	var two := bool(cfg.get("two_players", false)) and t0.human and t1.human
	InputHub.set_two_player(two)
	human = null
	human2 = null
	for ti in 2:
		if not teams[ti].human:
			continue
		var hc := HumanController.new()
		hc.name = "Human%d" % ti
		hc.team = teams[ti]
		hc.cam = cam
		hc.ball = ball
		hc.device = 1 if (two and ti == 1) else -1
		add_child(hc)
		hc.switched.connect(func(p: FootballPlayer) -> void:
			if hc == human:
				cam.player = p)
		if human == null:
			human = hc
		else:
			human2 = hc
	# Ser una Leyenda: el humano solo controla a su jugador
	var legend_id := str(cfg.get("legend_player", ""))
	if legend_id != "" and human != null:
		for p in human.team.players:
			if str(p.data.get("id", "")) == legend_id:
				human.locked = p
				cam.player = p
				human.set_controlled(p)
	if human != null and human.team.controlled == null:
		human.set_controlled(human.team.nearest_to(Vector3.ZERO))
	if human2 != null:
		human2.set_controlled(human2.team.nearest_to(Vector3.ZERO))
	cam.attack_side = human.team.side if human else 1
	if cam.player == null:
		cam.player = t0.players[mini(9, t0.players.size() - 1)]


func _wire_player(p: FootballPlayer) -> void:
	p.opponents = p.team.opponent
	if not p.kicked.is_connected(_on_player_kicked):
		p.kicked.connect(_on_player_kicked)
		p.saved.connect(_on_save)
		p.foul_committed.connect(_on_foul)
		p.tackled.connect(func(w: FootballPlayer, _l: FootballPlayer) -> void: _say("tackle", {"jugador": w.display_name(), "equipo": _tname(w.team)}))
		p.trick_done.connect(func(pl: FootballPlayer, _k: String) -> void: _say("dribble", {"jugador": pl.display_name(), "equipo": _tname(pl.team)}))


func _kits_clash(a: Dictionary, b: Dictionary, bk: String) -> bool:
	var ca := Color.html(str(a.get("kits", {}).get("home", {}).get("shirt", "#fff")))
	var cb := Color.html(str(b.get("kits", {}).get(bk, {}).get("shirt", "#000")))
	return Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length() < 0.4


func _on_quality_changed(_q: int) -> void:
	stadium.set_shadows(GameSettings.shadows_enabled())
	for t in teams:
		for p in t.players:
			p.set_shadows(GameSettings.shadows_enabled())


func _reset_stats() -> void:
	stats = {"possession": [0.0, 0.0], "shots": [0, 0], "on_target": [0, 0], "corners": [0, 0],
		"passes": [0, 0], "passes_ok": [0, 0], "fouls": [0, 0], "offsides": [0, 0], "yellows": [0, 0], "reds": [0, 0]}


func team_index(t: Node) -> int:
	return teams.find(t)


func minute() -> int:
	return int(clock / 60.0)


func _tname(t: Node) -> String:
	return str(t.info.get("name", "")) if t else ""


func _score_text() -> String:
	return "%s %d, %s %d" % [teams[0].info.get("name", ""), score[0], teams[1].info.get("name", ""), score[1]]


func _say(event: String, ctx := {}) -> void:
	if commentary == null:
		return
	var c := {"marcador": _score_text(), "minuto": str(minute())}
	c.merge(ctx, true)
	commentary.say(event, c)


# ------------------------------------------------------------- Flujo

func _set_phase(p: Phase) -> void:
	phase = p
	_phase_t = 0.0


func _start_intro() -> void:
	_set_phase(Phase.INTRO)
	ball.place(Vector3(0, 0, -40))
	ball.dead = true
	for ti in 2:
		var t := teams[ti]
		t.ai_active = false
		for i in t.players.size():
			var p := t.players[i]
			var x := (-13.5 + i * 1.15) if ti == 0 else (1.5 + i * 1.15)
			p.reset_at(Vector3(x, 0, PitchDims.HALF_WIDTH + 4.0 + i * 0.3), Vector3(0, 0, -1))
			p.set_meta("intro_target", Vector3(x, 0, 6.0))
	referee.position = Vector3(0, 0, PitchDims.HALF_WIDTH + 3.0)
	cam.override = "intro"
	_say("intro")
	hud.show_message(str(cfg.get("competition_name", "")) + "\n" + _tname(teams[0]) + "  vs  " + _tname(teams[1]), 3.0)


func _update_intro(dt: float) -> void:
	for t in teams:
		for p in t.players:
			var tgt: Vector3 = p.get_meta("intro_target", p.position)
			var to := tgt - p.global_position
			to.y = 0.0
			if to.length() > 0.3:
				p.move_intent = to.normalized() * 0.45
			else:
				p.move_intent = Vector3.ZERO
				p.face_point = p.global_position + Vector3(0, 0, 5)
				if p.model.anim_state == "move" and _phase_t > 3.5 and _rng.randf() < 0.02:
					p.model.play("wave")
	if _phase_t > 7.5 or (_phase_t > 1.0 and hud.consume_skip()):
		cam.override = ""
		Audio.whistle(false)
		start_kickoff(0)


func start_kickoff(team_idx: int) -> void:
	_set_phase(Phase.KICKOFF)
	ball.place(Vector3.ZERO)
	ball.dead = true
	_pending_foul = {}
	_offside_cands = []
	for ti in 2:
		var t := teams[ti]
		t.ai_active = false
		for p in t.players:
			var s: Array = Formations.slots(t.formation)[p.slot_index]
			var x_rel := -48.0 if p.is_gk else (-36.0 + float(s[1]) * 32.0)
			x_rel = minf(x_rel, -1.0 if ti == team_idx else -9.8)
			var z: float = float(s[2]) * 22.0 * t.side
			p.reset_at(Vector3(x_rel * t.side, 0, z), Vector3(t.side, 0, 0))
			p.freeze(true)
			p.face_point = Vector3.ZERO
			p.model.play("move")
	var kt := teams[team_idx]
	var fw := _forwards(kt)
	restart_taker = fw[0]
	restart_taker.reset_at(Vector3(-0.6 * kt.side, 0, 0.05), Vector3(kt.side, 0, 0))
	restart_taker.freeze(true)
	if fw.size() > 1:
		fw[1].reset_at(Vector3(-1.0 * kt.side, 0, 3.0), Vector3(kt.side, 0, 0))
		fw[1].freeze(true)
	restart_kind = "kickoff"
	restart_team = team_idx
	for hc in [human, human2]:
		if hc == null:
			continue
		if hc.team == kt and hc.locked == null:
			hc.set_controlled(restart_taker)
		elif hc.locked == null:
			hc.set_controlled(hc.team.nearest_to(Vector3.ZERO))
	referee.position = Vector3(-6, 0, -10)
	if period == 1 and clock < 1.0:
		_say("kickoff", {"equipo": _tname(kt)})
	elif period == 2 and absf(clock - 45 * 60) < 1.0:
		_say("second_half")
	hud.refresh_score()


func _forwards(t: Team) -> Array:
	var list: Array = []
	for p in t.players:
		if Formations.role_group(p.role) == "FWD":
			list.append(p)
	for p in t.players:
		if Formations.role_group(p.role) == "MID" and list.size() < 2:
			list.append(p)
	if list.is_empty():
		list = t.players.duplicate()
	list.sort_custom(func(a: FootballPlayer, b: FootballPlayer) -> bool: return absf(a.global_position.z) < absf(b.global_position.z))
	return list


func _start_restart(kind: String, team_idx: int, pos: Vector3) -> void:
	_set_phase(Phase.RESTART)
	restart_kind = kind
	restart_team = team_idx
	var t := teams[team_idx]
	pos.y = 0.0
	pos.x = clampf(pos.x, -PitchDims.HALF_LENGTH + 0.3, PitchDims.HALF_LENGTH - 0.3)
	pos.z = clampf(pos.z, -PitchDims.HALF_WIDTH + 0.3, PitchDims.HALF_WIDTH - 0.3)
	if kind == "throw_in":
		pos.z = signf(pos.z) * PitchDims.HALF_WIDTH
	ball.place(pos)
	ball.dead = true
	var taker: FootballPlayer
	if kind == "goal_kick":
		taker = t.goalkeeper()
	elif kind == "free_kick" and absf(pos.x - t.target_goal().x) < 35.0:
		taker = _best_by(t, "curl", pos)
	else:
		taker = t.nearest_to(pos, false)
	if taker == null:
		taker = t.players[0]
	restart_taker = taker
	var look := (Vector3(t.target_goal().x * 0.6, 0, 0) - pos).normalized()
	if kind == "goal_kick":
		look = Vector3(t.side, 0, 0)
	elif kind == "corner":
		look = Vector3(-signf(pos.x), 0, -signf(pos.z) * 1.4).normalized()
	elif kind == "throw_in":
		look = Vector3(t.side * 0.4, 0, -signf(pos.z)).normalized()
	taker.reset_at(pos - look * 0.55, look)
	taker.freeze(true)
	for tt in teams:
		tt.ai_active = true
		for p in tt.players:
			if p != taker and p.state == FootballPlayer.State.FROZEN:
				p.freeze(false)
	var min_d := 9.15 if kind != "throw_in" else 2.0
	for o in teams[1 - team_idx].players:
		var d := o.global_position - pos
		d.y = 0.0
		if d.length() < min_d:
			var np := pos + (d.normalized() if d.length() > 0.1 else Vector3(0, 0, -signf(pos.z))) * min_d
			np.x = clampf(np.x, -PitchDims.HALF_LENGTH, PitchDims.HALF_LENGTH)
			np.z = clampf(np.z, -PitchDims.HALF_WIDTH, PitchDims.HALF_WIDTH)
			o.position = np
	if kind == "free_kick" and absf(pos.x - t.target_goal().x) < 33.0:
		_build_wall(1 - team_idx, pos, t.target_goal())
		_say("free_kick", {"equipo": _tname(t), "jugador": taker.display_name()})
	for hc in [human, human2]:
		if hc != null and hc.team == t and not taker.is_gk and hc.locked == null:
			hc.set_controlled(taker)
	if kind == "corner":
		stats["corners"][team_idx] += 1
		_say("corner", {"equipo": _tname(t)})
	hud.show_message(Lang.t("out_" + kind), 1.2)
	if _autotest:
		print("  saque ", kind, " equipo ", team_idx)


func _best_by(t: Team, attr_key: String, near: Vector3) -> FootballPlayer:
	var best: FootballPlayer = null
	for p in t.players:
		if p.is_gk:
			continue
		var score_v := p.attr(attr_key) - p.global_position.distance_to(near) * 0.004
		if best == null or score_v > best.attr(attr_key) - best.global_position.distance_to(near) * 0.004:
			best = p
	return best


## Barrera: 3-5 rivales a 9,15 m entre el balón y el centro de la portería.
func _build_wall(def_idx: int, pos: Vector3, goal: Vector3) -> void:
	var t := teams[def_idx]
	var to_goal := (goal - pos).normalized()
	var dist := pos.distance_to(goal)
	var n := 5 if dist < 22.0 else (4 if dist < 28.0 else 3)
	var right := to_goal.cross(Vector3.UP)
	var center := pos + to_goal * 9.15 + right * signf(pos.z) * -0.4
	var cands: Array = []
	for p in t.players:
		if not p.is_gk:
			cands.append(p)
	cands.sort_custom(func(a: FootballPlayer, b: FootballPlayer) -> bool: return a.global_position.distance_to(center) < b.global_position.distance_to(center))
	for i in mini(n, cands.size()):
		var p: FootballPlayer = cands[i]
		p.reset_at(center + right * ((i - (n - 1) * 0.5) * 0.62), -to_goal)
		p.freeze(true)
		p.set_meta("wall", true)


func _ai_take_restart() -> void:
	var t := teams[restart_team]
	var p := restart_taker
	if p == null or not p.active:
		return
	if p.human and t.human:
		return
	var wait := 1.4 if restart_kind != "kickoff" else 1.0
	if _phase_t < wait:
		return
	var from := p.global_position
	match restart_kind:
		"corner":
			var box := Vector3(t.target_goal().x - t.side * _rng.randf_range(5.0, 11.0), 0, _rng.randf_range(-5.0, 5.0))
			p.request_kick("cross", 0.7, (box - from).normalized(), t.nearest_to(box, false, p), box)
		"goal_kick":
			var opt := t.find_pass_target(p, Vector3.ZERO, "pass")
			if not opt.is_empty() and float(opt["lane"]) > 4.0 and float(opt["dist"]) < 25.0:
				p.request_kick("pass", 0.5, ((opt["point"] as Vector3) - from).normalized(), opt["player"], opt["point"])
			else:
				var tgt := Vector3(t.side * _rng.randf_range(-5.0, 10.0), 0, _rng.randf_range(-20.0, 20.0))
				p.request_kick("lob", 0.8, (tgt - from).normalized(), t.nearest_to(tgt, false), tgt)
		"kickoff":
			var mate := t.nearest_to(from + Vector3(-t.side * 8.0, 0, 0), false, p)
			var pt := mate.global_position
			p.request_kick("pass", 0.4, (pt - from).normalized(), mate, pt)
		"free_kick":
			var goal := t.target_goal()
			var dist := from.distance_to(goal)
			if dist < 30.0 and absf(from.z) < 20.0:
				p.ai_curl = _rng.randf_range(-0.8, 0.8)
				p.request_kick("shot", clampf(0.55 + dist / 80.0, 0.5, 0.85), (Vector3(goal.x, 0, _rng.randf_range(-3, 3)) - from).normalized())
			elif dist < 40.0:
				var box2 := Vector3(goal.x - t.side * 8.0, 0, _rng.randf_range(-6.0, 6.0))
				p.request_kick("cross", 0.7, (box2 - from).normalized(), t.nearest_to(box2, false, p), box2)
			else:
				_ai_simple_pass(t, p, from)
		_:
			_ai_simple_pass(t, p, from)


func _ai_simple_pass(t: Team, p: FootballPlayer, from: Vector3) -> void:
	var opt2 := t.find_pass_target(p, Vector3.ZERO, "pass")
	if opt2.is_empty():
		p.request_kick("pass", 0.5, p.heading)
	else:
		p.request_kick("pass", 0.5, ((opt2["point"] as Vector3) - from).normalized(), opt2["player"], opt2["point"])


func _on_ball_kicked(by: Node, spd: float) -> void:
	Audio.kick(clampf(spd / 28.0, 0.1, 1.0))
	var was_restart := phase == Phase.KICKOFF or phase == Phase.RESTART
	if was_restart:
		_set_phase(Phase.PLAYING)
		for t in teams:
			t.ai_active = true
			for p in t.players:
				if p.state == FootballPlayer.State.FROZEN:
					p.freeze(false)
				if p.has_meta("wall"):
					p.remove_meta("wall")
		restart_taker = null
	elif phase == Phase.PENALTY:
		_set_phase(Phase.PLAYING)
		for t in teams:
			t.ai_active = true
			for p in t.players:
				if p.state == FootballPlayer.State.FROZEN:
					p.freeze(false)
		_penalty_keeper_reaction(by)
	elif phase == Phase.SHOOTOUT:
		_penalty_keeper_reaction(by)
		shootout["pending"] = true
		shootout["t"] = 0.0
	if was_restart and restart_kind in ["throw_in", "corner", "goal_kick"]:
		_offside_cands = []


func _on_player_kicked(p: FootballPlayer, kind: String, _power: float) -> void:
	var ti := team_index(p.team)
	if ti < 0:
		return
	if kind == "shot":
		stats["shots"][ti] += 1
		stadium.set_crowd_excitement(0.75)
		Audio.excite(0.6)
		_say("shot", {"jugador": p.display_name(), "equipo": _tname(p.team)})
	else:
		stats["passes"][ti] += 1
		_pending_pass_team = ti
		_last_pass = {"player": p, "time": clock}
		if kind == "through":
			_say("through", {"jugador": p.display_name()})
		elif kind in ["lob", "cross"]:
			_say("long_ball", {"jugador": p.display_name()})
		else:
			_say("pass", {"jugador": p.display_name(), "equipo": _tname(p.team)})
		if phase == Phase.PLAYING:
			_mark_offside_candidates(p)


func _on_save(keeper: FootballPlayer, caught: bool) -> void:
	var shooter := ball.shot_by as FootballPlayer
	if shooter != null and shooter.team != keeper.team:
		stats["on_target"][team_index(shooter.team)] += 1
		keeper.stats["saves"] += 1
	ball.shot_by = null
	hud.show_message(Lang.t("save_catch" if caught else "save_parry"), 1.0)
	Audio.play("ooh", -3.0)
	Audio.excite(0.75)
	_say("save", {"portero": keeper.display_name(), "equipo": _tname(keeper.team)})


func _on_goal(side: int) -> void:
	if phase == Phase.SHOOTOUT:
		return
	if phase != Phase.PLAYING:
		return
	var ti := 0 if teams[0].side == side else 1
	score[ti] += 1
	var scorer := ball.last_touch as FootballPlayer
	var own_goal := scorer != null and team_index(scorer.team) != ti
	if ball.shot_by != null and team_index(ball.shot_by.team) == ti:
		stats["on_target"][ti] += 1
	var assist: FootballPlayer = null
	if not own_goal and scorer != null and not _last_pass.is_empty():
		var lp: FootballPlayer = _last_pass["player"]
		if lp != scorer and lp.team == scorer.team and clock - float(_last_pass["time"]) < 600.0:
			assist = lp
	if scorer != null and not own_goal:
		scorer.stats["goals"] += 1
	if assist:
		assist.stats["assists"] += 1
	var gk := teams[1 - ti].goalkeeper()
	if gk:
		gk.stats["conceded"] += 1
	events.append({"minute": minute() + 1, "team": ti, "kind": "goal", "player": scorer.display_name() if scorer else "",
		"pid": str(scorer.data.get("id", "")) if scorer and not own_goal else "", "assist": str(assist.data.get("id", "")) if assist else "",
		"own_goal": own_goal})
	_set_phase(Phase.GOAL)
	_pending_foul = {}
	stadium.set_crowd_excitement(1.0)
	Audio.excite(1.0)
	cam.shake = 0.5
	var human_scored := teams[ti].human
	InputHub.vibrate(350 if human_scored else 120)
	for p in teams[ti].players:
		if p == scorer or p.global_position.distance_to(ball.global_position) < 25.0:
			p.celebrate()
	for p in teams[1 - ti].players:
		if p.global_position.distance_to(ball.global_position) < 20.0:
			p.lament()
	for t in teams:
		t.ai_active = false
	var who := ""
	if scorer:
		who = scorer.display_name() + (" (" + Lang.t("own_goal") + ")" if own_goal else "")
	hud.show_message(Lang.t("goal") + "\n" + who, 2.6, UITheme.YELLOW)
	hud.refresh_score()
	if own_goal:
		_say("own_goal", {"rival": _tname(teams[1 - ti])})
	else:
		_say("goal", {"jugador": who, "equipo": _tname(teams[ti]), "rival": _tname(teams[1 - ti])})
	# Remontada / goleada
	var diff: int = score[ti] - score[1 - ti]
	if diff >= 3 and score[ti] >= 4:
		_say("rout", {"equipo": _tname(teams[ti]), "rival": _tname(teams[1 - ti])})
	_lead_history.append(signi(score[0] - score[1]))
	if _lead_history.size() >= 2 and _lead_history.has(-1 if ti == 0 else 1) and signi(score[0] - score[1]) == (1 if ti == 0 else -1):
		_say("comeback", {"equipo": _tname(teams[ti])})
	if _autotest:
		print("GOL %s %d-%d (%s) min %d" % [teams[ti].info.get("short"), score[0], score[1], who, minute() + 1])
	# Guardar el gol para el visor de repeticiones
	if not _autotest and GameSettings.save_goal_replays:
		replay.save_clip(9.0, "%s %d-%d %s · %s %d'" % [teams[0].info.get("short"), score[0], score[1], teams[1].info.get("short"), who, minute() + 1])


func _on_post(is_crossbar: bool, spd: float) -> void:
	Audio.play("post", -2.0)
	if spd > 3.0 and phase == Phase.PLAYING:
		hud.show_message(Lang.t("crossbar" if is_crossbar else "post"), 1.0)
		stadium.set_crowd_excitement(0.85)
		Audio.play("ooh", -2.0)
		var lt := ball.last_touch as FootballPlayer
		_say("post", {"jugador": lt.display_name() if lt else "", "rival": _tname(lt.opponents) if lt else ""})


func _on_out(kind: String, pos: Vector3) -> void:
	if phase == Phase.SHOOTOUT:
		return
	if phase != Phase.PLAYING:
		return
	var lt := ball.last_touch as FootballPlayer
	var last_team := team_index(lt.team) if lt != null else 0
	var other := 1 - last_team
	if ball.shot_by != null:
		_say("shot_wide", {"jugador": (ball.shot_by as FootballPlayer).display_name()})
		Audio.play("ooh", -6.0)
		ball.shot_by = null
	if kind == "touch_line":
		_queue_restart("throw_in", other, Vector3(pos.x, 0, signf(pos.z) * PitchDims.HALF_WIDTH))
		return
	var s := int(signf(pos.x))
	var defending := 0 if teams[0].side == -s else 1
	if last_team == defending:
		_queue_restart("corner", 1 - defending, Vector3(s * (PitchDims.HALF_LENGTH - 0.3), 0, signf(pos.z) * (PitchDims.HALF_WIDTH - 0.3)))
	else:
		_queue_restart("goal_kick", defending, Vector3(s * (PitchDims.HALF_LENGTH - 5.5), 0, signf(pos.z) * 5.0))


func _queue_restart(kind: String, ti: int, pos: Vector3, delay := 1.2) -> void:
	_queued = [kind, ti, pos, delay]
	_set_phase(Phase.RESTART)
	restart_taker = null
	_offside_cands = []
	for t in teams:
		t.ai_active = true


# ---------------------------------------------------------- Reglamento

func _mark_offside_candidates(passer: FootballPlayer) -> void:
	var t: Team = passer.team
	var s := t.side
	var xs: Array = []
	for o in t.opponent.players:
		xs.append(o.global_position.x * s)
	xs.sort()
	var second_last: float = xs[xs.size() - 2] if xs.size() > 1 else 52.5
	var bx := ball.global_position.x * s
	_offside_cands = []
	_offside_team = team_index(t)
	for m in t.players:
		if m == passer:
			continue
		var mx := m.global_position.x * s
		if mx > 0.0 and mx > maxf(bx, second_last) + 0.4:
			_offside_cands.append(m)


func _check_offside() -> void:
	var lt := ball.last_touch
	if lt == _last_touch_seen:
		return
	_last_touch_seen = lt
	if _offside_cands.is_empty():
		return
	if _offside_cands.has(lt):
		var p := lt as FootballPlayer
		stats["offsides"][_offside_team] += 1
		hud.show_message(Lang.t("offside"), 1.4)
		Audio.whistle(false)
		_say("offside", {"jugador": p.display_name()})
		_offside_cands = []
		ball.dead = true
		_queue_restart("free_kick", 1 - _offside_team, p.global_position, 1.0)
	elif lt != null:
		_offside_cands = []


func _on_foul(off: FootballPlayer, victim: FootballPlayer, severity: float) -> void:
	if phase != Phase.PLAYING or not _pending_foul.is_empty():
		return
	var ti := team_index(off.team)
	stats["fouls"][ti] += 1
	off.stats["fouls"] += 1
	_pending_foul = {"off": off, "victim": victim, "sev": severity, "pos": victim.global_position, "t": 0.0}
	# Lesión ocasional
	if severity > 0.55 and _rng.randf() < 0.12:
		victim.injured = true
		_say("injury", {"jugador": victim.display_name()})
		if victim.team.human:
			hud.show_message(Lang.t("injured_sub") % victim.display_name(), 2.0)
	# Penal: falta dentro del área del infractor
	var own_x: float = -PitchDims.HALF_LENGTH * off.team.side
	var p := victim.global_position
	if absf(p.x - own_x) < PitchDims.PENALTY_AREA_DEPTH and absf(p.z) < PitchDims.PENALTY_AREA_HALF_WIDTH:
		_pending_foul["t"] = 99.0


func _resolve_pending_foul(dt: float) -> void:
	if _pending_foul.is_empty():
		return
	_pending_foul["t"] = float(_pending_foul["t"]) + dt
	var off: FootballPlayer = _pending_foul["off"]
	var victim: FootballPlayer = _pending_foul["victim"]
	var sev: float = _pending_foul["sev"]
	var vt: Team = victim.team
	var is_pen := float(_pending_foul["t"]) > 50.0
	if not is_pen and float(_pending_foul["t"]) < 0.9:
		return
	var foul_pos: Vector3 = _pending_foul["pos"]
	_pending_foul = {}
	# Ventaja
	var vt_ball := vt.has_ball()
	var bx := ball.global_position.x * vt.side
	if not is_pen and vt_ball and bx > -5.0 and sev < 0.85:
		hud.show_message(Lang.t("advantage"), 1.0)
		_say("advantage")
		_give_card(off, sev, false)
		return
	Audio.whistle(false)
	_say("foul", {"jugador": off.display_name(), "equipo": _tname(off.team)})
	off.play_anim("protest")
	_give_card(off, sev, true)
	if is_pen:
		_start_penalty(team_index(vt), victim)
	else:
		_queue_restart("free_kick", team_index(vt), foul_pos, 1.4)


func _give_card(p: FootballPlayer, sev: float, stopped: bool) -> void:
	var roll := sev + _rng.randf() * 0.25
	var ti := team_index(p.team)
	var red := false
	if roll > 1.05 and _rng.randf() < 0.35:
		red = true
	elif roll > 0.7:
		p.yellow += 1
		stats["yellows"][ti] += 1
		events.append({"minute": minute() + 1, "team": ti, "kind": "yellow", "player": p.display_name(), "pid": str(p.data.get("id", ""))})
		if p.yellow >= 2:
			red = true
			hud.show_message(Lang.t("second_yellow") % p.display_name(), 1.6, Color(1, 0.3, 0.2))
		else:
			hud.show_message(Lang.t("yellow_card") % p.display_name(), 1.4, Color(1, 0.85, 0.1))
			_say("yellow", {"jugador": p.display_name()})
		referee.show_card(red)
	else:
		return
	if red:
		stats["reds"][ti] += 1
		events.append({"minute": minute() + 1, "team": ti, "kind": "red", "player": p.display_name(), "pid": str(p.data.get("id", ""))})
		referee.show_card(true)
		hud.show_message(Lang.t("red_card") % p.display_name(), 1.8, Color(1, 0.2, 0.2))
		_say("red", {"jugador": p.display_name(), "equipo": _tname(p.team)})
		p.team.remove_player(p)
		for hc in [human, human2]:
			if hc != null and hc.team == p.team and hc.team.controlled == null and hc.locked != p:
				hc.set_controlled(hc.team.nearest_to(ball.global_position))


# ------------------------------------------------------------- Penales

func _start_penalty(team_idx: int, victim: FootballPlayer) -> void:
	var t := teams[team_idx]
	_set_phase(Phase.PENALTY)
	restart_team = team_idx
	restart_kind = "penalty"
	var spot := Vector3((PitchDims.HALF_LENGTH - PitchDims.PENALTY_SPOT) * t.side, 0, 0)
	ball.place(spot)
	ball.dead = true
	var taker := _best_by(t, "shot_accuracy", spot)
	if victim != null and victim.active and victim.attr("shot_accuracy") > taker.attr("shot_accuracy") - 0.05:
		taker = victim
	_setup_penalty_kick(t, taker)
	hud.show_message(Lang.t("penalty"), 1.6, UITheme.YELLOW)
	_say("penalty", {"equipo": _tname(t)})


func _setup_penalty_kick(t: Team, taker: FootballPlayer) -> void:
	var spot := ball.global_position
	var gx := PitchDims.HALF_LENGTH * t.side
	for tt in teams:
		tt.ai_active = false
		for p in tt.players:
			if p == taker:
				continue
			if p.is_gk and tt != t:
				p.reset_at(Vector3(gx - t.side * 0.2, 0, 0), Vector3(-t.side, 0, 0))
				p.freeze(true)
				continue
			# Fuera del área, detrás del punto
			var i := tt.players.find(p)
			p.reset_at(Vector3(gx - t.side * (PitchDims.PENALTY_AREA_DEPTH + 2.0 + (i % 3) * 1.5), 0, -14.0 + i * 2.6), Vector3(t.side, 0, 0))
			p.freeze(true)
	taker.reset_at(spot - Vector3(t.side * 2.2, 0, 0), Vector3(t.side, 0, 0))
	taker.freeze(true)
	restart_taker = taker
	for hc in [human, human2]:
		if hc != null and hc.team == t:
			hc.set_controlled(taker)


func _ai_take_penalty() -> void:
	var p := restart_taker
	if p == null or (p.human and p.team.human):
		return
	if _phase_t < 1.6:
		return
	var t: Team = p.team
	var aim := Vector3(t.target_goal().x, 0, [-2.6, -1.8, 0.0, 1.8, 2.6][_rng.randi() % 5])
	p.request_kick("shot", _rng.randf_range(0.55, 0.85), (aim - p.global_position).normalized())


## Reacción del portero en un penal: el humano elige lado con el joystick; la IA adivina.
func _penalty_keeper_reaction(kicker: Node) -> void:
	var kt: Team = kicker.team if kicker else teams[restart_team]
	var gk := kt.opponent.goalkeeper()
	if gk == null:
		return
	gk.freeze(false)
	var z := 0.0
	var hc: HumanController = null
	for h in [human, human2]:
		if h != null and h.team == kt.opponent:
			hc = h
	if hc != null:
		var mv := hc.read_move()
		z = clampf(mv.z * 3.0, -3.0, 3.0) if absf(mv.z) > 0.3 else 0.0
	else:
		var t_line := 0.45
		var real_z := ball.position.z + ball.velocity.z * t_line
		z = real_z if _rng.randf() < 0.3 + gk.attr("reflexes") * 0.25 else [-2.4, 0.0, 2.4][_rng.randi() % 3]
	if absf(z) > 0.6:
		gk.request_dive(Vector3(gk.global_position.x, _rng.randf_range(0.4, 1.6), z), 0.45)


func _start_shootout() -> void:
	_set_phase(Phase.SHOOTOUT)
	_say("shootout")
	hud.show_message(Lang.t("shootout"), 2.0, UITheme.YELLOW)
	shootout = {"kicks": [[], []], "turn": 0, "taker_idx": [0, 0], "pending": false, "t": 0.0, "setup": false}
	for t in teams:
		t.ai_active = false
	# Ambos equipos tiran sobre la misma portería (la de +X)
	_next_shootout_kick()


func _shootout_order(t: Team) -> Array:
	var list := t.players.duplicate()
	list.sort_custom(func(a: FootballPlayer, b: FootballPlayer) -> bool:
		if a.is_gk != b.is_gk:
			return b.is_gk
		return a.attr("shot_accuracy") + a.attr("shot_power") > b.attr("shot_accuracy") + b.attr("shot_power"))
	return list


func _next_shootout_kick() -> void:
	var ti: int = shootout["turn"]
	var t := teams[ti]
	t.side = 1
	t.opponent.side = -1
	var order := _shootout_order(t)
	var idx: int = shootout["taker_idx"][ti] % order.size()
	shootout["taker_idx"][ti] = idx + 1
	var spot := Vector3(PitchDims.HALF_LENGTH - PitchDims.PENALTY_SPOT, 0, 0)
	ball.place(spot)
	ball.dead = true
	shootout["pending"] = false
	shootout["t"] = 0.0
	_phase_t = 0.0
	restart_team = ti
	_setup_penalty_kick(t, order[idx])
	hud.refresh_shootout(shootout)


func _update_shootout(dt: float) -> void:
	if not shootout["pending"]:
		_ai_take_penalty()
		return
	shootout["t"] = float(shootout["t"]) + dt
	var decided := ""
	if ball.in_goal != 0:
		decided = "goal"
	elif float(shootout["t"]) > 2.6 or ball.dead or (ball.held_by != null):
		decided = "miss"
	if decided == "":
		return
	var ti: int = shootout["turn"]
	shootout["kicks"][ti].append(decided == "goal")
	_say("shootout_goal" if decided == "goal" else "shootout_miss")
	Audio.excite(1.0 if decided == "goal" else 0.6)
	hud.refresh_shootout(shootout)
	var a: Array = shootout["kicks"][0]
	var b: Array = shootout["kicks"][1]
	var ga := a.count(true)
	var gb := b.count(true)
	var winner := -1
	if a.size() <= 5 and b.size() <= 5:
		var rem_a := 5 - a.size()
		var rem_b := 5 - b.size()
		if ga > gb + rem_b:
			winner = 0
		elif gb > ga + rem_a:
			winner = 1
	elif a.size() == b.size() and ga != gb:
		winner = 0 if ga > gb else 1
	if winner >= 0:
		events.append({"kind": "shootout", "pen": [ga, gb]})
		_end_match()
		return
	shootout["turn"] = 1 - ti
	_next_shootout_kick()


# ---------------------------------------------------------- Bucle

func _physics_process(dt: float) -> void:
	if phase == Phase.LOADING:
		return
	_phase_t += dt
	match phase:
		Phase.INTRO:
			_update_intro(dt)
		Phase.PLAYING:
			_advance_clock(dt)
			_track_stats(dt)
			_check_offside()
			_resolve_pending_foul(dt)
			_update_fitness()
			_auto_subs()
		Phase.RESTART:
			_advance_clock(dt)
			if not _queued.is_empty() and _phase_t > float(_queued[3]):
				var q := _queued
				_queued = []
				_start_restart(q[0], q[1], q[2])
			elif _queued.is_empty():
				_ai_take_restart()
		Phase.KICKOFF:
			_ai_take_restart()
		Phase.PENALTY:
			_ai_take_penalty()
		Phase.SHOOTOUT:
			_update_shootout(dt)
		Phase.GOAL:
			if _phase_t > 2.0 and _after_replay == "" and not _autotest and GameSettings.auto_replay:
				if replay.start(7.0, 0.55):
					_after_replay = "kickoff"
					_set_phase(Phase.REPLAY)
					cam.override = "replay"
					hud.show_replay(true)
					Game.flash_logo(Lang.t("replay"), 0.25)
			elif _phase_t > 3.5:
				_kickoff_after_goal()
		Phase.REPLAY:
			if replay.finished() or hud.consume_skip():
				replay.stop()
				cam.override = ""
				hud.show_replay(false)
				var next := _after_replay
				_after_replay = ""
				if next == "kickoff":
					_kickoff_after_goal()
				else:
					_set_phase(Phase.PLAYING)
					get_tree().paused = false
		_:
			pass
	if phase != Phase.REPLAY:
		_separate_players()
		_ball_body_collisions()
	if _autotest and Engine.get_physics_frames() % 600 == 0:
		print("min %d fase %d marcador %d-%d" % [minute(), phase, score[0], score[1]])


func _kickoff_after_goal() -> void:
	var last := score_changed_last()
	start_kickoff(1 - last)


func score_changed_last() -> int:
	for i in range(events.size() - 1, -1, -1):
		if events[i].get("kind", "") == "goal":
			return int(events[i]["team"])
	return 0


func _advance_clock(dt: float) -> void:
	var scale := 45.0 / maxf(float(cfg.get("half_minutes", 4.0)), 0.5)
	clock += dt * scale
	var end: float = PERIOD_END[period - 1] * 60.0
	if not _late_said and period == 2 and clock > 85.0 * 60.0:
		_late_said = true
		_say("time_late")
	if clock >= end and phase == Phase.PLAYING and _pending_foul.is_empty():
		clock = end
		_end_period()


func _end_period() -> void:
	Audio.whistle(true)
	match period:
		1:
			_set_phase(Phase.HALFTIME)
			_freeze_all()
			hud.show_message(Lang.t("half_time"), 2.0)
			_say("half_time")
			if _autotest:
				start_next_period()
				return
			hud.show_stats(Lang.t("half_time"), false)
		2, 4:
			var need: bool = cfg.get("needs_winner", false)
			if need and score[0] == score[1]:
				if period == 2 and cfg.get("extra_time", true):
					_say("extra_time")
					hud.show_message(Lang.t("extra_time"), 2.0, UITheme.YELLOW)
					_set_phase(Phase.HALFTIME)
					_freeze_all()
					if _autotest:
						start_next_period()
					else:
						hud.show_stats(Lang.t("extra_time"), false)
				else:
					_start_shootout()
			else:
				_end_match()
		3:
			_set_phase(Phase.HALFTIME)
			_freeze_all()
			if _autotest:
				start_next_period()
			else:
				hud.show_stats(Lang.t("et_half"), false)


func start_next_period() -> void:
	period += 1
	clock = PERIOD_END[period - 2] * 60.0
	for t in teams:
		t.side *= -1
	cam.attack_side = human.team.side if human else teams[0].side
	start_kickoff(1 if period % 2 == 0 else 0)


## Compatibilidad con el HUD (botón "Segundo tiempo").
func start_second_half() -> void:
	start_next_period()


func _end_match() -> void:
	_set_phase(Phase.FULLTIME)
	_freeze_all()
	Audio.whistle(true)
	var pen := _pen_score()
	var w := 0 if score[0] > score[1] else (1 if score[1] > score[0] else -1)
	if w < 0 and pen.size() == 2:
		w = 0 if pen[0] > pen[1] else 1
	for ti in 2:
		for p in teams[ti].players:
			if w == ti:
				p.celebrate()
			elif w >= 0:
				p.lament()
	hud.show_message(Lang.t("full_time"), 2.0)
	_say("full_time")
	if w >= 0:
		_say("win_end", {"equipo": _tname(teams[w])})
	else:
		_say("draw_end")
	if _autotest:
		print("FINAL %d-%d %s" % [score[0], score[1], str(pen)])
		print("ESTADÍSTICAS ", stats)
		_finish_and_report()
		get_tree().quit()
		return
	hud.show_stats(Lang.t("full_time"), true)


func _pen_score() -> Array:
	for e in events:
		if e.get("kind", "") == "shootout":
			return e["pen"]
	return []


## Construye el resultado y lo entrega al modo de juego.
func build_result() -> Dictionary:
	var scorers: Array = []
	var cards: Array = []
	for e in events:
		match e.get("kind", ""):
			"goal":
				if str(e.get("pid", "")) != "":
					scorers.append({"pid": e["pid"], "team": cfg["home"] if e["team"] == 0 else cfg["away"], "assist": e.get("assist", ""), "minute": e["minute"]})
			"yellow":
				cards.append({"pid": e["pid"], "red": false})
			"red":
				cards.append({"pid": e["pid"], "red": true})
	var ratings := {}
	var pstats := {}
	var injuries: Array = []
	for ti in 2:
		var t := teams[ti]
		var won: bool = score[ti] > score[1 - ti]
		var lost: bool = score[ti] < score[1 - ti]
		for p in t.players:
			var pid := str(p.data.get("id", ""))
			var s: Dictionary = p.stats
			var r: float = 6.0 + s["goals"] * 1.0 + s["assists"] * 0.6 + s["tackles"] * 0.15 + s["passes_ok"] * 0.03 + s["saves"] * 0.35
			r -= s["conceded"] * 0.35 + s["fouls"] * 0.1 + p.yellow * 0.3
			r += 0.3 if won else (-0.3 if lost else 0.0)
			r += _rng.randf_range(-0.3, 0.3)
			ratings[pid] = snappedf(clampf(r, 3.0, 10.0), 0.1)
			pstats[pid] = s
			if p.injured:
				injuries.append(pid)
	return {"home": cfg["home"], "away": cfg["away"], "hg": score[0], "ag": score[1], "pen": _pen_score(),
		"scorers": scorers, "cards": cards, "ratings": ratings, "player_stats": pstats, "injuries": injuries,
		"stats": stats, "mode": cfg.get("mode", "friendly")}


func _finish_and_report() -> void:
	Game.finish_match(build_result())


## Botón "Continuar" del final del partido.
func leave_match() -> void:
	Audio.stop_match_ambience()
	if commentary:
		commentary.stop()
	InputHub.set_two_player(false)
	_finish_and_report()
	Game.back_to_menu()


func _freeze_all() -> void:
	for t in teams:
		t.ai_active = false
		for p in t.players:
			p.move_intent = Vector3.ZERO


func _track_stats(dt: float) -> void:
	for ti in 2:
		if teams[ti].has_ball() or (teams[ti].last_possession and not teams[1 - ti].has_ball()):
			stats["possession"][ti] += dt
			break
	var owner: Node = ball.owner_player if ball.owner_player != null else ball.held_by
	if owner != _last_owner:
		_last_owner = owner
		if owner != null and _pending_pass_team >= 0:
			if team_index(owner.team) == _pending_pass_team:
				stats["passes_ok"][_pending_pass_team] += 1
				if not _last_pass.is_empty():
					(_last_pass["player"] as FootballPlayer).stats["passes_ok"] += 1
			_pending_pass_team = -1
	# Ocasión: balón cerca del área rival
	if absf(ball.position.x) > PitchDims.HALF_LENGTH - 18.0 and absf(ball.position.z) < 18.0 and _rng.randf() < 0.004:
		var att := 0 if signf(ball.position.x) == teams[0].side else 1
		_say("chance", {"equipo": _tname(teams[att])})
		Audio.excite(0.55)


func _update_fitness() -> void:
	var f := clock / (90.0 * 60.0)
	for t in teams:
		for p in t.players:
			p.fitness = clampf(1.0 - f * 0.33 * (1.25 - p.attr("stamina")) - (0.15 if p.injured else 0.0), 0.45, 1.0)


func _auto_subs() -> void:
	var m := minute()
	if m < _sub_check_min:
		return
	_sub_check_min = m + 4
	for t in teams:
		var done: Array = t.ai_substitutions(m)
		for pair in done:
			_after_sub(t, pair[0], pair[1])
		# Equipo humano: cambio automático del lesionado si no lo hizo el jugador
		if t.human:
			for p in t.players.duplicate():
				if p.injured and p.has_meta("injury_wait") and m - int(p.get_meta("injury_wait")) >= 8:
					var b := _best_bench_for(t, p)
					if not b.is_empty():
						var np := t.substitute(p, b)
						if np:
							_after_sub(t, p, np)
				elif p.injured and not p.has_meta("injury_wait"):
					p.set_meta("injury_wait", m)


func _best_bench_for(t: Team, p: FootballPlayer) -> Dictionary:
	var best: Dictionary = {}
	for b in t.bench:
		if (p.is_gk) != (str(b.get("position", "")) == "GK"):
			continue
		if best.is_empty() or int(b.get("ovr", 0)) > int(best.get("ovr", 0)):
			best = b
	return best


## Cambio pedido desde el menú de pausa.
func human_substitution(t: Team, out_p: FootballPlayer, in_data: Dictionary) -> bool:
	var np := t.substitute(out_p, in_data)
	if np == null:
		return false
	_after_sub(t, out_p, np)
	return true


func _after_sub(t: Team, out_p: FootballPlayer, np: FootballPlayer) -> void:
	_wire_player(np)
	np.set_shadows(GameSettings.shadows_enabled())
	replay.register([np])
	hud.show_message(Lang.t("sub_msg") % [np.display_name(), out_p.display_name()], 1.6)
	_say("sub", {"equipo": _tname(t), "jugador": np.display_name()})
	for hc in [human, human2]:
		if hc != null and hc.team == t and hc.team.controlled == null:
			hc.set_controlled(np if not np.is_gk else t.nearest_to(ball.global_position))


func set_strategy(t: Team, key: String) -> void:
	t.strategy = key


## Choques entre jugadores: se empujan según su físico; el más fuerte gana el cuerpo a cuerpo.
func _separate_players() -> void:
	var all: Array[FootballPlayer] = []
	for t in teams:
		all.append_array(t.players)
	var n := all.size()
	for i in n:
		var a := all[i]
		for j in range(i + 1, n):
			var b := all[j]
			var d := Vector2(b.position.x - a.position.x, b.position.z - a.position.z)
			var l := d.length()
			var min_d := FootballPlayer.RADIUS * 2.0
			if l >= min_d or l < 0.0001:
				continue
			if a.state == FootballPlayer.State.LYING or b.state == FootballPlayer.State.LYING:
				continue
			var nrm := d / l
			var pa := a.attr("physical") + 0.2
			var pb := b.attr("physical") + 0.2
			var wa := pb / (pa + pb)
			if a.state == FootballPlayer.State.FROZEN:
				wa = 0.0
			elif b.state == FootballPlayer.State.FROZEN:
				wa = 1.0
			var push := min_d - l
			a.position -= Vector3(nrm.x, 0, nrm.y) * push * wa
			b.position += Vector3(nrm.x, 0, nrm.y) * push * (1.0 - wa)
			if a.team != b.team and (a.has_ball or b.has_ball) and phase == Phase.PLAYING:
				var key := str(a.get_instance_id()) + ":" + str(b.get_instance_id())
				if _contact_cd.get(key, 0) < Engine.get_physics_frames():
					_contact_cd[key] = Engine.get_physics_frames() + 45
					var c := a if a.has_ball else b
					var o := b if c == a else a
					var prob := clampf(0.12 + (o.attr("physical") - c.attr("physical")) * 0.9, 0.03, 0.5)
					if _rng.randf() < prob:
						c.has_ball = false
						ball.owner_player = null
						c.stumble()


## El balón rebota en el cuerpo de los jugadores (tiros bloqueados, barrera).
func _ball_body_collisions() -> void:
	if ball.owner_player != null or ball.held_by != null or ball.dead:
		return
	var v := ball.velocity
	if v.length() < 7.0 or ball.position.y > 1.9:
		return
	for t in teams:
		for p in t.players:
			if p == ball.last_touch and ball.claim_block_time > 0.0:
				continue
			if p.is_gk and p.state == FootballPlayer.State.DIVE:
				continue
			var d := Vector2(ball.position.x - p.position.x, ball.position.z - p.position.z)
			if d.length() < 0.36:
				var nrm := Vector3(d.x, 0, d.y).normalized() if d.length() > 0.01 else -v.normalized()
				var vn := v.dot(nrm)
				if vn < 0.0:
					ball.velocity = (v - nrm * vn * 1.4) * 0.45
					ball.last_touch = p
					ball.claim_block_time = 0.15
					ball.claim_block_by = p
					Audio.play("kick_soft", -8.0)
					return


# ----------------------------------------------------------- Entradas

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_cycle"):
		cam.cycle_mode()
		hud.on_camera_changed()
	elif event.is_action_pressed("pause"):
		hud.toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if hud:
			hud.toggle_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED and hud != null and not get_tree().paused:
		hud.toggle_pause()


func restart_match() -> void:
	get_tree().paused = false
	Audio.stop_match_ambience()
	if commentary:
		commentary.stop()
	get_tree().reload_current_scene()


## Repetición desde el menú de pausa (últimos 10 s).
func pause_replay() -> void:
	if replay.start(10.0, 0.6):
		get_tree().paused = false
		_after_replay = "resume"
		_set_phase(Phase.REPLAY)
		cam.override = "replay"
		hud.show_replay(true)


func _process(delta: float) -> void:
	if _shots_dir != "":
		_shots(delta)
	if _autotest and _autotest_quit > 0.0 and clock / 60.0 >= _autotest_quit:
		print("FIN PRUEBA min %d marcador %d-%d" % [minute(), score[0], score[1]])
		get_tree().quit()


var _shot_t := 0.0
var _shot_step := 0
const SHOTS := [[3.0, 0, 0, "broadcast_day"], [6.0, 2, 0, "close_day"], [9.0, 1, 1, "wide_sunset"], [12.0, 3, 2, "behind_night"]]


func _shots(delta: float) -> void:
	_shot_t += delta
	if _shot_step >= SHOTS.size():
		return
	var sh: Array = SHOTS[_shot_step]
	if _shot_t >= float(sh[0]) - 1.0:
		GameSettings.camera_mode = int(sh[1])
		if GameSettings.time_of_day != int(sh[2]):
			GameSettings.time_of_day = int(sh[2])
			stadium.apply_time_of_day(int(sh[2]))
	if _shot_t >= float(sh[0]):
		_shot_step += 1
		get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(str(sh[3]) + ".png"))
		print("captura ", sh[3])
		if _shot_step >= SHOTS.size():
			get_tree().quit()
