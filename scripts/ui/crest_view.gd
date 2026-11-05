class_name CrestView
extends Control
## Escudo genérico dibujado: forma (escudo, círculo, escudo redondo, rombo), dos colores e iniciales.

var crest: Dictionary = {}


func _init(c: Dictionary = {}, sz := 48.0) -> void:
	crest = c
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_crest(c: Dictionary) -> void:
	crest = c
	queue_redraw()


func _draw() -> void:
	var s := size
	var c1 := Color.html(str(crest.get("c1", "#203070")))
	var c2 := Color.html(str(crest.get("c2", "#ffffff")))
	var shape := str(crest.get("shape", "shield"))
	var pts := PackedVector2Array()
	match shape:
		"circle":
			for i in 32:
				var a := TAU * i / 32.0
				pts.append(s * 0.5 + Vector2(cos(a), sin(a)) * s.x * 0.47)
		"diamond":
			pts = PackedVector2Array([Vector2(s.x * 0.5, 0), Vector2(s.x, s.y * 0.5), Vector2(s.x * 0.5, s.y), Vector2(0, s.y * 0.5)])
		"round_shield":
			pts.append(Vector2(s.x * 0.06, s.y * 0.06))
			pts.append(Vector2(s.x * 0.94, s.y * 0.06))
			for i in 17:
				var a := PI * i / 16.0
				pts.append(Vector2(s.x * 0.5 + cos(a) * s.x * 0.44, s.y * 0.45 + sin(a) * s.y * 0.52))
		_:
			pts = PackedVector2Array([Vector2(s.x * 0.08, s.y * 0.05), Vector2(s.x * 0.92, s.y * 0.05), Vector2(s.x * 0.92, s.y * 0.5),
				Vector2(s.x * 0.5, s.y * 0.97), Vector2(s.x * 0.08, s.y * 0.5)])
	draw_colored_polygon(pts, c1)
	# Franja diagonal con el segundo color
	var band := PackedVector2Array([Vector2(s.x * 0.3, s.y * 0.05), Vector2(s.x * 0.48, s.y * 0.05), Vector2(s.x * 0.7, s.y * 0.95), Vector2(s.x * 0.52, s.y * 0.95)])
	var clipped := Geometry2D.intersect_polygons(band, pts)
	for poly in clipped:
		draw_colored_polygon(poly, Color(c2, 0.55))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, c2, maxf(2.0, s.x * 0.05), true)
	var txt := str(crest.get("text", ""))
	var font := ThemeDB.fallback_font
	var fs := int(s.y * (0.34 if txt.length() <= 3 else 0.26))
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, Vector2((s.x - w) * 0.5, s.y * 0.58), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2((s.x - w) * 0.5, s.y * 0.58), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
