class_name ReplaySystem
extends Node
## Repeticiones: graba a 20 Hz los últimos segundos (balón + jugadores con su estado de
## animación) y los reproduce con cámara lenta. Los goles se pueden guardar en user://replays.

const HZ := 20.0
const KEEP_SECONDS := 14.0
const ANIMS := ["move", "kick", "slide", "trick_stepover", "trick_cut", "stumble", "celebrate", "gk_ready", "dive",
	"gk_hold", "throw", "tackle", "lament", "header", "volley", "bicycle", "backheel", "punch", "charge", "fall",
	"protest", "wave", "card", "airplane", "knee_slide", "jump_punch", "point_sky"]

var match_node: Node
var frames: Array = []     # [t, bx, by, bz, qx, qy, qz, qw, [jugadores...]]
var actors: Array = []     # FootballPlayer registrados (orden fijo)
var playing := false
var play_t := 0.0
var play_start := 0.0
var play_end := 0.0
var play_speed := 0.5
var _acc := 0.0
var _time := 0.0
var _models: Array = []    # modelos usados en la reproducción (los mismos nodos de los jugadores)


func register(players: Array) -> void:
	for p in players:
		if not actors.has(p):
			actors.append(p)


func _physics_process(dt: float) -> void:
	if playing:
		return
	_time += dt
	_acc += dt
	if _acc < 1.0 / HZ:
		return
	_acc = 0.0
	var b: Ball = match_node.ball
	var q := b.mesh_quat()
	var row: Array = [_time, b.position.x, b.position.y, b.position.z, q.x, q.y, q.z, q.w]
	var pl: Array = []
	for p in actors:
		var fp := p as FootballPlayer
		var m := fp.model
		pl.append([snappedf(fp.position.x, 0.01), snappedf(fp.position.z, 0.01), snappedf(atan2(fp.heading.x, fp.heading.z), 0.01),
			ANIMS.find(m.anim_state), snappedf(m.anim_t, 0.01), snappedf(m.anim_speed, 0.01), 1 if m.anim_sprint else 0,
			m.anim_dive_side, snappedf(m.anim_dive_high, 0.01), 1 if fp.visible else 0])
	row.append(pl)
	frames.append(row)
	while frames.size() > 0 and _time - float(frames[0][0]) > KEEP_SECONDS:
		frames.pop_front()


func start(seconds_back: float, speed := 0.5) -> bool:
	if frames.size() < 4:
		return false
	playing = true
	play_end = float(frames[frames.size() - 1][0])
	play_start = maxf(float(frames[0][0]), play_end - seconds_back)
	play_t = play_start
	play_speed = speed
	_set_live(false)
	return true


func stop() -> void:
	if not playing:
		return
	playing = false
	_apply_time(play_end)
	_set_live(true)


func _set_live(on: bool) -> void:
	for p in actors:
		if (p as FootballPlayer).active:
			p.set_physics_process(on)
	match_node.ball.set_physics_process(on)
	for t in match_node.teams:
		t.set_physics_process(on)
	if match_node.human:
		match_node.human.set_physics_process(on)
	if match_node.human2:
		match_node.human2.set_physics_process(on)


func _process(delta: float) -> void:
	if not playing:
		return
	play_t += delta * play_speed
	_apply_time(minf(play_t, play_end))


func finished() -> bool:
	return play_t >= play_end


func _apply_time(t: float) -> void:
	# Busca los dos fotogramas que rodean t e interpola
	var i := 0
	while i < frames.size() - 2 and float(frames[i + 1][0]) < t:
		i += 1
	var a: Array = frames[i]
	var b2: Array = frames[mini(i + 1, frames.size() - 1)]
	var span := maxf(float(b2[0]) - float(a[0]), 0.0001)
	var k := clampf((t - float(a[0])) / span, 0.0, 1.0)
	var ball: Ball = match_node.ball
	ball.position = Vector3(lerpf(a[1], b2[1], k), lerpf(a[2], b2[2], k), lerpf(a[3], b2[3], k))
	ball.set_mesh_quat(Quaternion(a[4], a[5], a[6], a[7]).slerp(Quaternion(b2[4], b2[5], b2[6], b2[7]), k))
	var pa: Array = a[8]
	var pb: Array = b2[8]
	for j in mini(actors.size(), pa.size()):
		var fp := actors[j] as FootballPlayer
		var s0: Array = pa[j]
		var s1: Array = pb[j] if j < pb.size() else s0
		fp.position = Vector3(lerpf(s0[0], s1[0], k), 0, lerpf(s0[1], s1[1], k))
		var yaw := lerp_angle(float(s0[2]), float(s1[2]), k)
		fp.basis = Basis.looking_at(Vector3(sin(yaw), 0, cos(yaw)), Vector3.UP)
		fp.visible = int(s0[9]) == 1
		var m := fp.model
		var ai: int = s0[3]
		m.anim_state = ANIMS[ai] if ai >= 0 else "move"
		m.anim_t = lerpf(s0[4], s1[4], k)
		m.anim_speed = lerpf(s0[5], s1[5], k)
		m.anim_sprint = int(s0[6]) == 1
		m.anim_dive_side = s0[7]
		m.anim_dive_high = s0[8]


# --------------------------------------------------------- Guardado

## Guarda los últimos `seconds` segundos con la información para reconstruir la escena.
func save_clip(seconds: float, title: String) -> String:
	if frames.is_empty():
		return ""
	var end_t := float(frames[frames.size() - 1][0])
	var clip: Array = []
	for f in frames:
		if float(f[0]) >= end_t - seconds:
			clip.append(f)
	var players_info: Array = []
	for p in actors:
		var fp := p as FootballPlayer
		var kit: Dictionary = fp.get_meta("kit", {})
		players_info.append({"data": {"name": fp.data.get("name", ""), "number": fp.data.get("number", 0), "height": fp.data.get("height", 180),
			"appearance": fp.data.get("appearance", {})}, "kit": kit, "gk": fp.is_gk})
	var out := {"title": title, "date": Time.get_datetime_string_from_system(), "players": players_info, "frames": clip,
		"stadium": match_node.cfg.get("stadium", {}), "time_of_day": match_node.cfg.get("time_of_day", 0)}
	DirAccess.make_dir_recursive_absolute("user://replays")
	var name := "user://replays/gol_%d.json" % Time.get_unix_time_from_system()
	var f := FileAccess.open(name, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(out))
	_trim_saved(30)
	return name


static func _trim_saved(max_files: int) -> void:
	var d := DirAccess.open("user://replays")
	if d == null:
		return
	var files := Array(d.get_files())
	files.sort()
	while files.size() > max_files:
		d.remove(files.pop_front())


static func list_saved() -> Array:
	var d := DirAccess.open("user://replays")
	if d == null:
		return []
	var files := Array(d.get_files())
	files.sort()
	files.reverse()
	var out: Array = []
	for fn in files:
		out.append("user://replays/" + fn)
	return out
