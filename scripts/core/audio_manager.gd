extends Node
## Audio (autoload "Audio"). Todo se sintetiza por código al iniciar (no hay grabaciones):
## silbato, golpeos, poste, red, público (murmullo, ovación, "uyyy", cánticos con palmas y
## bombo), sonidos de menú y una música original de estilo futbolero de 2012.
## Si existen archivos .ogg en audio/sfx/ con el mismo nombre (o en user://audio/sfx/), se usan
## en su lugar.

const RATE := 22050

var streams: Dictionary = {}
var music_on := true
var sfx_volume := 0.0
var _pool: Array[AudioStreamPlayer] = []
var _crowd: AudioStreamPlayer
var _crowd_cheer: AudioStreamPlayer
var _chant: AudioStreamPlayer
var _music: AudioStreamPlayer
var _excitement := 0.2
var _target_excitement := 0.2
var _chant_timer := 20.0
var _thread: Thread
var ready_streams := false
var in_match := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_crowd = AudioStreamPlayer.new()
	_crowd_cheer = AudioStreamPlayer.new()
	_chant = AudioStreamPlayer.new()
	_music = AudioStreamPlayer.new()
	for p in [_crowd, _crowd_cheer, _chant, _music]:
		add_child(p)
	_thread = Thread.new()
	_thread.start(_generate_all)


func _generate_all() -> void:
	var s := {}
	s["kick"] = _kick(0.9)
	s["kick_soft"] = _kick(0.45)
	s["whistle"] = _whistle(0.32)
	s["whistle_long"] = _whistle(1.1)
	s["post"] = _post()
	s["net"] = _net()
	s["click"] = _blip(1100.0, 0.05)
	s["back"] = _blip(700.0, 0.07)
	s["select"] = _blip(1500.0, 0.09, 1900.0)
	s["crowd"] = _crowd_loop(6.0, 0.0)
	s["cheer"] = _crowd_loop(4.0, 1.0)
	s["ooh"] = _ooh()
	s["chant"] = _chant_loop()
	s["music"] = _music_loop()
	call_deferred("_streams_ready", s)


func _streams_ready(s: Dictionary) -> void:
	_thread.wait_to_finish()
	streams = s
	for key in streams.keys():
		for base in ["user://audio/sfx/", "res://audio/sfx/"]:
			var path: String = base + key + ".ogg"
			if FileAccess.file_exists(path):
				var st := AudioStreamOggVorbis.load_from_file(path)
				if st:
					streams[key] = st
					break
	ready_streams = true
	if not in_match:
		play_music()


func _process(delta: float) -> void:
	if not ready_streams or not in_match:
		return
	_excitement = move_toward(_excitement, _target_excitement, delta * 0.6)
	_target_excitement = move_toward(_target_excitement, 0.2, delta * 0.08)
	_crowd.volume_db = linear_to_db(0.35 + _excitement * 0.35) + sfx_volume
	_crowd_cheer.volume_db = linear_to_db(maxf(_excitement - 0.35, 0.001) * 1.4) + sfx_volume
	_chant_timer -= delta
	if _chant_timer <= 0.0:
		_chant_timer = randf_range(25.0, 50.0)
		if not _chant.playing:
			_chant.stream = streams["chant"]
			_chant.volume_db = -9.0 + sfx_volume
			_chant.play()
			get_tree().create_timer(randf_range(8.0, 14.0)).timeout.connect(func() -> void: _chant.stop())


# ---------------------------------------------------------------- API

func play(key: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not streams.has(key):
		return
	for p in _pool:
		if not p.playing:
			p.stream = streams[key]
			p.volume_db = volume_db + sfx_volume
			p.pitch_scale = pitch
			p.play()
			return


func ui(key := "click") -> void:
	play(key, -6.0)


func kick(power: float) -> void:
	play("kick" if power > 0.5 else "kick_soft", lerpf(-10.0, 0.0, clampf(power, 0.0, 1.0)), randf_range(0.9, 1.1))


func whistle(long := false) -> void:
	play("whistle_long" if long else "whistle", -3.0)


func excite(level: float) -> void:
	_target_excitement = maxf(_target_excitement, clampf(level, 0.0, 1.0))
	if level >= 0.95:
		_excitement = 1.0


func start_match_ambience() -> void:
	in_match = true
	stop_music()
	if not ready_streams:
		await get_tree().create_timer(0.5).timeout
		if not ready_streams:
			return
	_crowd.stream = streams["crowd"]
	_crowd.play()
	_crowd_cheer.stream = streams["cheer"]
	_crowd_cheer.volume_db = -60.0
	_crowd_cheer.play()


func stop_match_ambience() -> void:
	in_match = false
	for p in [_crowd, _crowd_cheer, _chant]:
		p.stop()


func play_music() -> void:
	if not music_on or not ready_streams or _music.playing:
		return
	_music.stream = streams["music"]
	_music.volume_db = -8.0
	_music.play()


func stop_music() -> void:
	_music.stop()


# -------------------------------------------------------------- Síntesis

func _make(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _kick(power: float) -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(140.0, 55.0, minf(t / 0.08, 1.0))
		ph += TAU * f / RATE
		var thump := sin(ph) * exp(-t * 28.0)
		var noise := (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.6
		s[i] = (thump * 0.9 + noise) * power
	return _make(s)


func _whistle(dur: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var p1 := 0.0
	var p2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var trill := 0.65 + 0.35 * sin(TAU * 32.0 * t)
		p1 += TAU * 2650.0 / RATE
		p2 += TAU * 2930.0 / RATE
		var env := minf(t / 0.02, 1.0) * minf((dur - t) / 0.05, 1.0)
		s[i] = (sin(p1) * 0.6 + sin(p2) * 0.4) * trill * env * 0.5
	return _make(s)


func _post() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var s := PackedFloat32Array()
	s.resize(n)
	var partials := [[880.0, 1.0, 5.0], [1385.0, 0.6, 7.0], [2210.0, 0.4, 9.0], [3170.0, 0.25, 12.0]]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for pp in partials:
			v += sin(TAU * pp[0] * t) * pp[1] * exp(-t * pp[2])
		v += (randf() * 2.0 - 1.0) * exp(-t * 120.0) * 0.5
		s[i] = v * 0.35
	return _make(s)


func _net() -> AudioStreamWAV:
	var n := int(RATE * 0.45)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.25)
		s[i] = lp * exp(-t * 7.0) * minf(t / 0.03, 1.0) * 0.8
	return _make(s)


func _blip(f: float, dur: float, f2 := -1.0) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var ff := f if f2 < 0.0 else lerpf(f, f2, t / dur)
		ph += TAU * ff / RATE
		s[i] = sin(ph) * exp(-t * 30.0) * 0.5
	return _make(s)


## Público: ruido filtrado con "olas" lentas. bright=0 murmullo, 1 ovación.
func _crowd_loop(dur: float, bright: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	var a := lerpf(0.06, 0.25, bright)
	for i in n:
		var t := float(i) / RATE
		var w := randf() * 2.0 - 1.0
		lp1 = lerpf(lp1, w, a)
		lp2 = lerpf(lp2, lp1, a * 1.5)
		var wave := 0.7 + 0.3 * sin(TAU * t / dur * 2.0) * sin(TAU * t / dur * 3.0 + 1.0)
		# Voces sueltas: pequeñas ráfagas tonales
		var voice := sin(TAU * (180.0 + 60.0 * sin(t * 3.0)) * t) * 0.05 * (1.0 if fmod(t * 1.7, 1.0) < 0.25 else 0.0) * (1.0 - bright)
		var fade := minf(minf(t, dur - t) / 0.3, 1.0)
		s[i] = (lp2 * (2.2 + bright) * wave + voice) * lerpf(1.0, fade, 0.0) * 0.8
	# Hacer el bucle continuo: fundido cruzado del final con el principio
	var xf := int(RATE * 0.3)
	for i in xf:
		var k := float(i) / xf
		s[i] = s[i] * k + s[n - xf + i] * (1.0 - k)
	s.resize(n - xf)
	return _make(s, true)


func _ooh() -> AudioStreamWAV:
	var n := int(RATE * 1.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.12)
		var env := minf(t / 0.25, 1.0) * exp(-maxf(t - 0.4, 0.0) * 2.5)
		var tone := 0.0
		for k in 6:
			tone += sin(TAU * (220.0 + k * 7.0) * t * (1.0 - t * 0.12)) / 6.0
		s[i] = (lp * 1.8 + tone * 0.3) * env * 0.7
	return _make(s)


## Cántico genérico: bombo y palmas al ritmo "tan, tan, ta-ta-tan" con coro de vocales.
func _chant_loop() -> AudioStreamWAV:
	var bpm := 120.0
	var beat := 60.0 / bpm
	var dur := beat * 8.0
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var hits := [0.0, 1.0, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 6.5, 7.0]
	var notes := [196.0, 196.0, 220.0, 220.0, 247.0, 196.0, 196.0, 220.0, 220.0, 175.0]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for h in hits:
			var dt: float = t - h * beat
			if dt >= 0.0 and dt < 0.25:
				v += sin(TAU * 60.0 * dt) * exp(-dt * 18.0) * 0.8
				v += (randf() * 2.0 - 1.0) * exp(-dt * 60.0) * 0.35
		var idx := int(t / beat * 1.25) % notes.size()
		var f: float = notes[idx]
		var choir := 0.0
		for k in 5:
			var ff := f * (1.0 + (k - 2) * 0.008)
			choir += (sin(TAU * ff * t) + 0.5 * sin(TAU * ff * 2.0 * t) + 0.3 * sin(TAU * ff * 3.0 * t)) / 5.0
		s[i] = v * 0.6 + choir * 0.18
	return _make(s, true)


## Música de menú original: 124 bpm, progresión I-V-vi-IV, bajo, acordes, arpegio y batería.
func _music_loop() -> AudioStreamWAV:
	var bpm := 124.0
	var beat := 60.0 / bpm
	var bars := 8
	var dur := beat * 4.0 * bars
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	# A mayor: A, E, F#m, D
	var chords := [[220.0, 277.18, 329.63], [164.81, 207.65, 246.94], [185.0, 220.0, 277.18], [146.83, 185.0, 220.0]]
	var bass := [110.0, 82.41, 92.5, 73.42]
	var lead := [659.25, 554.37, 659.25, 739.99, 659.25, 554.37, 493.88, 554.37]
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var b := t / beat
		var bar := int(b / 4.0) % 4
		var in_beat := fmod(b, 1.0)
		var ch: Array = chords[bar]
		var v := 0.0
		# Pad (sierra suave)
		for f in ch:
			var ph := fmod(t * f, 1.0)
			v += (ph * 2.0 - 1.0) * 0.05
		lp = lerpf(lp, v, 0.18)
		var out := lp
		# Bajo en corcheas
		var bf: float = bass[bar]
		var bph := fmod(t * bf, 1.0)
		out += (1.0 - 2.0 * absf(bph * 2.0 - 1.0)) * 0.22 * (0.6 + 0.4 * exp(-fmod(b * 2.0, 1.0) * 4.0))
		# Arpegio/lead cuadrado en semicorcheas (segunda mitad del bucle)
		if int(b / 16.0) % 2 == 1:
			var li := int(b * 2.0) % lead.size()
			var lf: float = lead[li]
			var sq := 1.0 if fmod(t * lf, 1.0) < 0.5 else -1.0
			out += sq * 0.05 * exp(-fmod(b * 2.0, 1.0) * 3.0)
		else:
			var ai := int(b * 4.0) % 3
			var af: float = ch[ai] * 2.0
			out += sin(TAU * af * t) * 0.06 * exp(-fmod(b * 4.0, 1.0) * 5.0)
		# Batería
		var kt := in_beat * beat
		out += sin(TAU * lerpf(110.0, 45.0, minf(kt / 0.1, 1.0)) * kt) * exp(-kt * 22.0) * 0.45
		var bi := int(b) % 4
		if bi == 1 or bi == 3:
			out += (randf() * 2.0 - 1.0) * exp(-kt * 25.0) * 0.22
		var ht := fmod(b * 2.0, 1.0) * beat * 0.5
		out += (randf() * 2.0 - 1.0) * exp(-ht * 120.0) * 0.06
		s[i] = out * 0.8
	return _make(s, true)
