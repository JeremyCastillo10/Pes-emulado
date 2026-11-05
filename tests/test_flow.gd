extends Node
## Prueba de flujo completo: liga -> partido (IA vs IA, con presentación) -> resultado -> menú.

var _state := 0
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DB.load_now()
	var lg: Dictionary = DB.leagues[1]
	var team: String = lg["teams"][0]
	Game.session = {"type": "league", "team": team, "comp": Competition.create_league(lg["name"], lg["teams"], [team])}
	Game.session_slot = "league_TEST_1"
	var cfg := ModeFlow.next_match_config(Game.session["comp"], lg["name"])
	cfg["human_home"] = false
	cfg["human_away"] = false
	cfg["half_minutes"] = 0.6
	cfg["presentation"] = true
	Game.return_screen = "league"
	print("Partido: ", cfg["home"], " vs ", cfg["away"])
	_detach.call_deferred()
	Game.start_match(cfg)


func _detach() -> void:
	# Este nodo deja de ser la escena actual para sobrevivir al cambio de escena
	var holder := Node.new()
	holder.name = "Holder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	reparent(get_tree().root)


func _process(delta: float) -> void:
	_t += delta
	var scene := get_tree().current_scene
	if scene == null:
		return
	if int(_t) != int(_t - delta) and int(_t) % 10 == 0:
		print("t=%d real=%d ms escena=%s fase=%s" % [_t, Time.get_ticks_msec(), scene.name, str(scene.get("phase"))])
	if _state == 0 and scene.name == "Match" and scene.get("phase") != null:
		if scene.phase == scene.Phase.HALFTIME:
			print("Medio tiempo ", scene.score)
			scene.hud._stats.visible = false
			get_tree().paused = false
			scene.start_next_period()
		elif scene.phase == scene.Phase.FULLTIME:
			print("Final ", scene.score, " eventos ", scene.events.size())
			_state = 1
			get_tree().paused = false
			scene.leave_match()
	elif _state == 1 and scene.name == "MainMenu" and _t > 1.0:
		var c: Dictionary = Game.session["comp"]
		print("Vuelta al menú. Jornada actual: ", c["current_round"], " partidos jugados en tabla: ", c["table"][Game.session["team"]]["p"])
		print("PRUEBA FLUJO OK")
		Game.delete_save("league_TEST_1")
		get_tree().quit()
	if _t > 400.0:
		print("TIEMPO AGOTADO estado ", _state)
		get_tree().quit()
