extends Node
## Entrenamiento: "free" (libre con tu equipo contra el portero), "freekick" (tiros libres
## con barrera), "penalty" (penales) y "challenge" (desafío de puntería: dianas en la
## portería durante 60 segundos).

var m: Node
var mode := "free"
var attempts := 0
var goals := 0
var points := 0
var timer := 60.0
var _wait := -1.0
var _kicked := false
var _targets: Array = []
var _rng := RandomNumberGenerator.new()


func setup(match_node: Node, p_mode: String) -> void:
	_rng.randomize()
	m = match_node
	mode = p_mode
	m.phase = m.Phase.TRAINING
	var home: Team = m.teams[0]
	var away: Team = m.teams[1]
	away.side = -1
	home.side = 1
	# Rivales: solo el portero (y una barrera en tiros libres)
	var keep := 4 if mode == "freekick" else 0
	for p in away.players.duplicate():
		if p.is_gk:
			continue
		if keep > 0:
			keep -= 1
			p.set_meta("wall_dummy", true)
			continue
		away.remove_player(p)
	home.ai_active = true
	away.ai_active = true
	m.ball.goal_scored.connect(_on_goal)
	m.ball.out_of_play.connect(func(_k: String, _p: Vector3) -> void: _schedule_next(1.2))
	m.ball.kicked.connect(_on_kicked)
	if mode == "challenge":
		_make_targets()
	_next()


func _make_targets() -> void:
	var gx := PitchDims.HALF_LENGTH
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for spot in [Vector2(-2.8, 2.0), Vector2(2.8, 2.0), Vector2(-2.8, 0.5), Vector2(2.8, 0.5), Vector2(0, 2.1)]:
		var t := TorusMesh.new()
		t.inner_radius = 0.42
		t.outer_radius = 0.5
		var mi := MeshInstance3D.new()
		mi.mesh = t
		mi.material_override = mat
		mi.position = Vector3(gx + 0.05, spot.y, spot.x)
		mi.rotation_degrees = Vector3(0, 0, 90)
		m.add_child(mi)
		_targets.append(mi)


func _next() -> void:
	_kicked = false
	_wait = -1.0
	var home: Team = m.teams[0]
	var gk: FootballPlayer = m.teams[1].goalkeeper()
	if gk:
		gk.reset_at(Vector3(PitchDims.HALF_LENGTH - 0.3, 0, 0), Vector3(-1, 0, 0))
	var taker: FootballPlayer = m.human.team.controlled if m.human else home.players[9]
	if taker == null or taker.is_gk:
		taker = home.players[home.players.size() - 1]
	match mode:
		"penalty":
			var spot := Vector3(PitchDims.HALF_LENGTH - PitchDims.PENALTY_SPOT, 0, 0)
			m.ball.place(spot)
			m.ball.dead = true
			taker.reset_at(spot - Vector3(2.2, 0, 0), Vector3(1, 0, 0))
			taker.freeze(true)
			if gk:
				gk.freeze(true)
		"freekick", "challenge":
			var pos := Vector3(PitchDims.HALF_LENGTH - _rng.randf_range(18.0, 28.0), 0, _rng.randf_range(-14.0, 14.0))
			m.ball.place(pos)
			m.ball.dead = true
			var to_goal := (Vector3(PitchDims.HALF_LENGTH, 0, 0) - pos).normalized()
			taker.reset_at(pos - to_goal * 0.6, to_goal)
			taker.freeze(true)
			if mode == "freekick":
				var right := to_goal.cross(Vector3.UP)
				var i := 0
				for p in m.teams[1].players:
					if p.has_meta("wall_dummy"):
						p.reset_at(pos + to_goal * 9.15 + right * ((i - 1.5) * 0.62), -to_goal)
						p.freeze(true)
						i += 1
		_:
			var p0 := taker.global_position + taker.heading * 1.0
			p0.y = 0.0
			p0.x = clampf(p0.x, -50.0, 50.0)
			p0.z = clampf(p0.z, -32.0, 32.0)
			m.ball.place(p0)
	if m.human:
		m.human.set_controlled(taker)
	_update_text()


func _on_kicked(_by: Node, _spd: float) -> void:
	if mode in ["penalty", "freekick", "challenge"] and not _kicked:
		_kicked = true
		attempts += 1
		if mode == "penalty":
			m._penalty_keeper_reaction(_by)
		var gk: FootballPlayer = m.teams[1].goalkeeper()
		if gk:
			gk.freeze(false)
		_schedule_next(3.0)
	Audio.kick(clampf(_spd / 28.0, 0.1, 1.0))


func _on_goal(_side: int) -> void:
	goals += 1
	Audio.excite(0.9)
	if mode == "challenge":
		var b: Vector3 = m.ball.position
		var hit := false
		for t in _targets:
			if Vector2(b.z - t.position.z, b.y - t.position.y).length() < 0.7:
				hit = true
		points += 3 if hit else 1
		m.hud.show_message(("¡DIANA! +3" if hit else "Gol +1"), 1.0, UITheme.YELLOW)
	else:
		m.hud.show_message(Lang.t("goal"), 1.0, UITheme.YELLOW)
	_schedule_next(1.5)


func _schedule_next(t: float) -> void:
	if _wait < 0.0:
		_wait = t


func _physics_process(dt: float) -> void:
	if mode == "challenge":
		timer -= dt
		if timer <= 0.0:
			timer = 0.0
			m.hud.set_training_text("Desafío terminado: %d puntos en %d tiros" % [points, attempts])
			return
	if _wait >= 0.0:
		_wait -= dt
		if _wait < 0.0:
			_next()
	elif mode == "free" and m.ball.dead:
		_schedule_next(1.0)
	_update_text()


func _update_text() -> void:
	var t := ""
	match mode:
		"penalty":
			t = "Penales: %d / %d" % [goals, attempts]
		"freekick":
			t = "Tiros libres: %d / %d" % [goals, attempts]
		"challenge":
			t = "Desafío de puntería · %d s · %d puntos" % [int(timer), points]
		_:
			t = "Entrenamiento libre · Goles: %d" % goals
	m.hud.set_training_text(t)
