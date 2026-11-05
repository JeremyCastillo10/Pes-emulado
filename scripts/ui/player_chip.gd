class_name PlayerChip
extends Button
## Ficha de jugador para la alineación: se puede arrastrar y soltar sobre otra ficha (intercambio).

signal dropped_on(src: Dictionary, dst: PlayerChip)

var pid := ""
var slot := -1          # -1 = suplente
var role := ""


func setup(p: Dictionary, p_slot: int, p_role: String) -> void:
	pid = str(p.get("id", ""))
	slot = p_slot
	role = p_role
	var short := str(p.get("name", ""))
	if short.length() > 12:
		short = short.substr(0, 11) + "."
	var mismatch: bool = role != "" and str(p.get("position", "")) != role and not Formations.SIMILAR.get(role, []).has(str(p.get("position", "")))
	text = "%s  %s\n%s %d%s" % [str(p.get("number", "")), short, str(p.get("position", "")), int(p.get("ovr", 0)), " !" if mismatch else ""]
	custom_minimum_size = Vector2(150, 58)
	add_theme_font_size_override("font_size", 15)
	focus_mode = Control.FOCUS_NONE
	if int(p.get("injured", 0)) > 0:
		modulate = Color(1, 0.6, 0.6)


func _get_drag_data(_pos: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = text
	preview.add_theme_color_override("font_color", UITheme.YELLOW)
	set_drag_preview(preview)
	return {"pid": pid, "slot": slot}


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("pid")


func _drop_data(_pos: Vector2, data: Variant) -> void:
	dropped_on.emit(data, self)
