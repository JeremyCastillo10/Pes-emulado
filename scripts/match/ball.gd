class_name Ball
extends Node3D
## Balón con física propia (integración manual, más barata y controlable que RigidBody):
## gravedad, resistencia del aire, efecto Magnus, bote según superficie, rodadura,
## choque con postes y travesaño, red y detección de gol / fuera.

signal goal_scored(side: int)            # side = +1 portería en +X, -1 en -X
signal post_hit(is_crossbar: bool, speed: float)
signal out_of_play(kind: String, position: Vector3)
signal net_hit(position: Vector3, strength: float)
signal kicked(by: Node, speed: float)

const RADIUS := 0.11
const GRAVITY := 9.81
const AIR_DRAG := 0.012          # a = -k |v| v
const MAGNUS := 0.0048           # a = k (w x v)
const SPIN_DECAY_AIR := 0.25
const SUBSTEPS := 2

var velocity := Vector3.ZERO
var spin := Vector3.ZERO          # velocidad angular (rad/s, mundo)
var restitution := 0.62           # bote (césped seco)
var rolling_decel := 1.15         # m/s² de frenado por rodadura
var owner_player: Node = null     # jugador que la conduce
var last_touch: Node = null
var in_goal := 0                  # 0 en juego, ±1 dentro de una portería
var dead := false                 # balón parado (fuera / gol)
var claim_block_time := 0.0       # tiempo en que el último pateador no puede recuperarla
var claim_block_by: Node = null

var _mesh: Node3D
var _shadow: MeshInstance3D


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 20
	sphere.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ball.gdshader")
	mi.material_override = mat
	add_child(mi)
	_mesh = mi
	_shadow = Ball.make_blob_shadow(0.5)
	add_child(_shadow)
	set_wet(GameSettings.wet_pitch)


static func make_blob_shadow(size: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/blob_shadow.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	return mi


func set_wet(wet: bool) -> void:
	# Césped mojado: el balón bota menos pero corre más (patina).
	restitution = 0.5 if wet else 0.62
	rolling_decel = 0.8 if wet else 1.15


func is_on_ground() -> bool:
	return position.y <= RADIUS + 0.02 and absf(velocity.y) < 0.6


## Aplica un golpeo. vel en m/s, spin en rad/s.
func kick(vel: Vector3, spin_vec: Vector3, by: Node) -> void:
	velocity = vel
	spin = spin_vec
	owner_player = null
	last_touch = by
	claim_block_time = 0.25
	claim_block_by = by
	kicked.emit(by, vel.length())


func place(pos: Vector3) -> void:
	position = Vector3(pos.x, RADIUS, pos.z)
	velocity = Vector3.ZERO
	spin = Vector3.ZERO
	owner_player = null
	in_goal = 0
	dead = false


func can_be_claimed_by(p: Node) -> bool:
	if dead or in_goal != 0:
		return false
	if claim_block_time > 0.0 and p == claim_block_by:
		return false
	return true


func _physics_process(delta: float) -> void:
	claim_block_time = maxf(claim_block_time - delta, 0.0)
	var dt := delta / SUBSTEPS
	for i in SUBSTEPS:
		_step(dt)
	# Rotación visual a partir del giro
	var w := spin.length()
	if w > 0.01:
		_mesh.rotate(spin / w, w * delta)
		_mesh.transform.basis = _mesh.transform.basis.orthonormalized()
	_shadow.global_position = Vector3(position.x, 0.015, position.z)
	var h := clampf(position.y / 6.0, 0.0, 1.0)
	_shadow.scale = Vector3.ONE * (1.0 + h)
	_shadow.transparency = h * 0.8


func _step(dt: float) -> void:
	var on_ground := position.y <= RADIUS + 0.001 and velocity.y <= 0.05
	if not on_ground:
		var spd := velocity.length()
		var acc := Vector3(0, -GRAVITY, 0)
		acc -= velocity * spd * AIR_DRAG
		acc += spin.cross(velocity) * MAGNUS
		velocity += acc * dt
		spin *= 1.0 - SPIN_DECAY_AIR * dt
	else:
		# Rodadura
		position.y = RADIUS
		velocity.y = 0.0
		var hv := Vector3(velocity.x, 0, velocity.z)
		var s := hv.length()
		if s > 0.0:
			var dec := (rolling_decel + s * 0.06) * dt
			hv = hv * maxf(s - dec, 0.0) / s
			# Un poco de efecto lateral también al rodar
			hv += Vector3(spin.cross(hv).x, 0, spin.cross(hv).z) * MAGNUS * 0.15 * dt
		velocity = hv
		# Giro de rodadura sin deslizamiento: w = (n x v) / r
		var roll := Vector3.UP.cross(hv) / RADIUS
		spin = spin.lerp(roll, minf(1.0, 10.0 * dt))
	var prev := position
	position += velocity * dt
	# Contacto con el suelo
	if position.y < RADIUS:
		position.y = RADIUS
		if velocity.y < -0.9:
			var vy := -velocity.y * restitution
			var hv2 := Vector3(velocity.x, 0, velocity.z)
			# El efecto liftado/cortado cambia el bote
			var spin_push := Vector3(spin.z, 0, -spin.x) * RADIUS * -0.25
			hv2 = hv2 * 0.86 + spin_push
			velocity = Vector3(hv2.x, vy, hv2.z)
			spin *= 0.6
		else:
			velocity.y = 0.0
	if not dead:
		_goal_collisions(prev)
		_check_lines()
	elif in_goal != 0:
		_goal_collisions(prev)


func _goal_collisions(prev: Vector3) -> void:
	for side in [1, -1]:
		var gx: float = PitchDims.HALF_LENGTH * side
		if absf(position.x - gx) > 3.0:
			continue
		# Postes verticales
		for pz in [PitchDims.GOAL_HALF_WIDTH, -PitchDims.GOAL_HALF_WIDTH]:
			if position.y < PitchDims.GOAL_HEIGHT + RADIUS:
				var d := Vector2(position.x - gx, position.z - pz)
				var min_d := RADIUS + PitchDims.POST_RADIUS
				if d.length() < min_d and d.length() > 0.0001:
					var n2 := d.normalized()
					var n := Vector3(n2.x, 0, n2.y)
					_bounce_off(n, min_d - d.length(), 0.75)
					post_hit.emit(false, velocity.length())
		# Travesaño (cilindro a lo largo de Z)
		if absf(position.z) < PitchDims.GOAL_HALF_WIDTH + RADIUS:
			var d2 := Vector2(position.x - gx, position.y - PitchDims.GOAL_HEIGHT)
			var min_d2 := RADIUS + PitchDims.POST_RADIUS
			if d2.length() < min_d2 and d2.length() > 0.0001:
				var n2b := d2.normalized()
				_bounce_off(Vector3(n2b.x, n2b.y, 0), min_d2 - d2.length(), 0.7)
				post_hit.emit(true, velocity.length())
		_net_collision(side, gx, prev)


func _bounce_off(n: Vector3, depth: float, rest: float) -> void:
	position += n * depth
	var vn := velocity.dot(n)
	if vn < 0.0:
		velocity -= n * vn * (1.0 + rest)
		spin *= 0.5


## Red: la caja de la portería es "sólida" desde fuera (salvo por la boca) y
## retiene el balón desde dentro.
func _net_collision(side: int, gx: float, prev: Vector3) -> void:
	var depth := PitchDims.GOAL_DEPTH
	var x_in := (position.x - gx) * side            # >0 detrás de la línea
	var inside_now := x_in > 0.0 and x_in < depth and absf(position.z) < PitchDims.GOAL_HALF_WIDTH and position.y < PitchDims.GOAL_HEIGHT
	if in_goal == side:
		# Dentro: rebotar contra la red con mucha amortiguación
		var hit := false
		if x_in > depth - RADIUS:
			position.x = gx + side * (depth - RADIUS)
			if velocity.x * side > 0.0:
				hit = true
				velocity.x *= -0.15
		if absf(position.z) > PitchDims.GOAL_HALF_WIDTH - RADIUS:
			position.z = signf(position.z) * (PitchDims.GOAL_HALF_WIDTH - RADIUS)
			if velocity.z * signf(position.z) > 0.0:
				hit = true
				velocity.z *= -0.15
		if position.y > PitchDims.GOAL_HEIGHT - RADIUS:
			position.y = PitchDims.GOAL_HEIGHT - RADIUS
			if velocity.y > 0.0:
				hit = true
				velocity.y *= -0.1
		if hit:
			var s := velocity.length() + 4.0
			velocity *= 0.5
			net_hit.emit(position, s)
		return
	# Desde fuera: entrar por los laterales, techo o fondo no está permitido
	var px_in := (prev.x - gx) * side
	var was_inside := px_in > 0.0 and px_in < depth and absf(prev.z) < PitchDims.GOAL_HALF_WIDTH and prev.y < PitchDims.GOAL_HEIGHT
	if inside_now and not was_inside:
		if px_in <= 0.0:
			return  # entró por la boca: es gol (lo resuelve _check_lines)
		if absf(prev.z) >= PitchDims.GOAL_HALF_WIDTH:
			position.z = signf(prev.z) * (PitchDims.GOAL_HALF_WIDTH + RADIUS)
			velocity.z *= -0.2
		elif prev.y >= PitchDims.GOAL_HEIGHT:
			position.y = PitchDims.GOAL_HEIGHT + RADIUS
			velocity.y = absf(velocity.y) * 0.2
		else:
			position.x = gx + side * (depth + RADIUS)
			velocity.x *= -0.2
		velocity *= 0.6
		net_hit.emit(position, velocity.length() * 0.5 + 1.0)


func _check_lines() -> void:
	var hl := PitchDims.HALF_LENGTH
	var hw := PitchDims.HALF_WIDTH
	# Gol: el balón entero cruza la línea entre los postes y bajo el travesaño
	if absf(position.x) > hl + RADIUS:
		var side := int(signf(position.x))
		if absf(position.z) < PitchDims.GOAL_HALF_WIDTH - RADIUS * 0.5 and position.y < PitchDims.GOAL_HEIGHT and absf(position.x) < hl + PitchDims.GOAL_DEPTH:
			in_goal = side
			dead = true
			owner_player = null
			goal_scored.emit(side)
			return
		dead = true
		owner_player = null
		out_of_play.emit("goal_line", position)
		return
	if absf(position.z) > hw + RADIUS:
		dead = true
		owner_player = null
		out_of_play.emit("touch_line", position)
