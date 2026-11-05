class_name Radar
extends Control
## Radar del campo: jugadores de ambos equipos, balón y jugador controlado.

var match_node: Node = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if match_node == null:
		return
	var sz := size
	var hl := PitchDims.HALF_LENGTH
	var hw := PitchDims.HALF_WIDTH
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.25, 0.1, 0.45))
	var line := Color(1, 1, 1, 0.45)
	draw_rect(Rect2(Vector2.ZERO, sz), line, false, 1.5)
	draw_line(Vector2(sz.x * 0.5, 0), Vector2(sz.x * 0.5, sz.y), line, 1.0)
	draw_arc(sz * 0.5, sz.y * 9.15 / (hw * 2.0), 0, TAU, 24, line, 1.0)
	var pa := Vector2(sz.x * 16.5 / (hl * 2.0), sz.y * 40.3 / (hw * 2.0))
	draw_rect(Rect2(Vector2(0, (sz.y - pa.y) * 0.5), pa), line, false, 1.0)
	draw_rect(Rect2(Vector2(sz.x - pa.x, (sz.y - pa.y) * 0.5), pa), line, false, 1.0)
	var teams: Array = match_node.teams
	for ti in teams.size():
		var t: Team = teams[ti]
		var c := Color.html(str(t.kit.get("shirt", "#ffffff")))
		for p in t.players:
			var pos := _map(p.global_position, sz)
			if p.human:
				draw_circle(pos, 6.5, UITheme.YELLOW)
			draw_circle(pos, 4.5, c)
			draw_arc(pos, 4.5, 0, TAU, 10, Color(0, 0, 0, 0.6), 1.0)
	var bpos := _map(match_node.ball.global_position, sz)
	draw_circle(bpos, 3.5, Color.WHITE)
	draw_arc(bpos, 3.5, 0, TAU, 8, Color.BLACK, 1.0)


func _map(p: Vector3, sz: Vector2) -> Vector2:
	# Siempre de izquierda a derecha como la cámara de transmisión (Z hacia abajo)
	return Vector2((p.x / (PitchDims.HALF_LENGTH * 2.0) + 0.5) * sz.x, (p.z / (PitchDims.HALF_WIDTH * 2.0) + 0.5) * sz.y)
