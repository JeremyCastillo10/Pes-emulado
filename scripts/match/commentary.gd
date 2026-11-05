class_name Commentary
extends Node
## Narración del partido: narrador + comentarista con frases de data/lang/narracion_es.json.
## Usa la síntesis de voz (TTS) del teléfono en español. Si hay clips grabados para un evento
## (audio/narracion/<evento>_N.ogg dentro del juego o user://narracion/<evento>_N.ogg, que se
## puede copiar desde el teléfono), se reproducen en su lugar.

const PRIORITY := {"goal": 3, "own_goal": 3, "red": 3, "penalty": 3, "full_time": 3, "half_time": 3, "trophy": 3,
	"intro": 2, "kickoff": 2, "second_half": 2, "save": 2, "post": 2, "yellow": 2, "offside": 2, "comeback": 2,
	"rout": 2, "extra_time": 2, "shootout": 2, "shootout_goal": 2, "shootout_miss": 2, "penalty_miss": 2,
	"shot": 1, "shot_wide": 1, "foul": 1, "corner": 1, "free_kick": 1, "sub": 1, "injury": 1, "win_end": 2,
	"draw_end": 2, "advantage": 1, "tackle": 1, "chance": 1, "dribble": 0, "pass": 0, "long_ball": 0,
	"through": 0, "pressure": 0, "crowd": 0, "time_late": 1}

var phrases: Dictionary = {}
var enabled := true
var ctx_base: Dictionary = {}
var _clips: Dictionary = {}      # evento -> [rutas]
var _voices: PackedStringArray = []
var _busy_until := 0.0
var _last_event_time := {}
var _player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _recent: Array = []


func _ready() -> void:
	_rng.randomize()
	enabled = GameSettings.commentary
	var f := FileAccess.open("res://data/lang/narracion_es.json", FileAccess.READ)
	if f:
		var v: Variant = JSON.parse_string(f.get_as_text())
		if v is Dictionary:
			phrases = v
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_scan_clips("res://audio/narracion")
	_scan_clips("user://narracion")
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		_voices = DisplayServer.tts_get_voices_for_language("es")


func _scan_clips(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for fn in d.get_files():
		var lower := fn.to_lower()
		if lower.ends_with(".ogg") or lower.ends_with(".ogg.import"):
			var clean := fn.trim_suffix(".import")
			var key := clean.get_basename()
			var us := key.rfind("_")
			if us > 0 and key.substr(us + 1).is_valid_int():
				key = key.substr(0, us)
			if not _clips.has(key):
				_clips[key] = []
			var full := dir_path.path_join(clean)
			if not _clips[key].has(full):
				_clips[key].append(full)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Narra un evento. ctx: {equipo, rival, jugador, portero, marcador, minuto}
func say(event: String, ctx: Dictionary = {}) -> void:
	if not enabled or not phrases.has(event):
		return
	var prio: int = PRIORITY.get(event, 1)
	var now := _now()
	# Eventos menores: no saturar la narración
	if prio == 0 and (_rng.randf() > 0.25 or now < _busy_until):
		return
	if prio == 1 and now < _busy_until - 0.5:
		return
	if now - float(_last_event_time.get(event, -100.0)) < (8.0 if prio <= 1 else 0.0):
		return
	_last_event_time[event] = now
	var c := ctx_base.duplicate()
	c.merge(ctx, true)
	var interrupt := prio >= 3
	if _clips.has(event):
		_play_clip(_clips[event][_rng.randi() % _clips[event].size()], interrupt)
		return
	var text := _pick(phrases[event].get("n", []), c)
	if text == "":
		return
	_speak(text, false, interrupt)
	var dur := 1.0 + text.length() * 0.065
	_busy_until = now + dur
	# Comentario del comentarista en eventos importantes
	var cl: Array = phrases[event].get("c", [])
	if not cl.is_empty() and prio >= 2 and _rng.randf() < 0.55:
		var t2 := _pick(cl, c)
		if t2 != "":
			_speak(t2, true, false)
			_busy_until += 1.0 + t2.length() * 0.065


func _pick(list: Array, c: Dictionary) -> String:
	if list.is_empty():
		return ""
	var choice: String = list[_rng.randi() % list.size()]
	for i in 3:
		if not _recent.has(choice):
			break
		choice = list[_rng.randi() % list.size()]
	_recent.append(choice)
	if _recent.size() > 25:
		_recent.pop_front()
	var out := choice
	for k in c:
		out = out.replace("{" + str(k) + "}", str(c[k]))
	return out


func _speak(text: String, commentator: bool, interrupt: bool) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var voice := ""
	if _voices.size() > 0:
		voice = _voices[0]
		if commentator and _voices.size() > 1:
			voice = _voices[1]
	var vol := int(GameSettings.commentary_volume * 100.0)
	var pitch := 0.82 if commentator else 1.05
	var rate := 1.0 if commentator else 1.15
	if text.begins_with("¡GO") or text.begins_with("¡Y es GO"):
		rate = 0.95
		pitch = 1.15
	DisplayServer.tts_speak(text, voice, vol, pitch, rate, 0, interrupt)


func _play_clip(path: String, interrupt: bool) -> void:
	if _player.playing and not interrupt:
		return
	var st: AudioStream = null
	if path.begins_with("res://"):
		st = load(path)
	else:
		st = AudioStreamOggVorbis.load_from_file(path)
	if st:
		_player.stream = st
		_player.volume_db = linear_to_db(maxf(GameSettings.commentary_volume, 0.01))
		_player.play()
		_busy_until = _now() + st.get_length()


func stop() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()
	_player.stop()
