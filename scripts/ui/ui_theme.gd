class_name UITheme
## Identidad visual: azul oscuro, blanco y amarillo.

const NAVY := Color(0.04, 0.09, 0.2)
const NAVY_2 := Color(0.07, 0.15, 0.32)
const YELLOW := Color(1.0, 0.82, 0.1)
const WHITE := Color(0.96, 0.97, 1.0)
const DIM := Color(0.7, 0.76, 0.9)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	var normal := _box(Color(NAVY_2, 0.92), 6, Color(1, 1, 1, 0.08))
	var hover := _box(Color(0.1, 0.22, 0.45, 0.95), 6, YELLOW)
	var pressed := _box(YELLOW, 6, YELLOW)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 6, YELLOW))
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_color("font_color", "Button", WHITE)
	t.set_color("font_hover_color", "Button", YELLOW)
	t.set_color("font_pressed_color", "Button", NAVY)
	t.set_color("font_hover_pressed_color", "Button", NAVY)
	t.set_color("font_focus_color", "Button", YELLOW)
	t.set_color("font_color", "Label", WHITE)
	t.set_stylebox("panel", "PanelContainer", _box(Color(NAVY, 0.94), 10, Color(1, 1, 1, 0.06)))
	return t


static func _box(c: Color, r: int, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.border_color = border
	s.set_border_width_all(2 if border.a > 0.0 else 0)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
