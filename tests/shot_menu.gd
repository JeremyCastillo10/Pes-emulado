extends Node
## Capturas del menú: godot --path . res://tests/shot_menu.tscn -- --out=<carpeta>

func _ready() -> void:
	var out := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DB.load_now()
	var m: Node = load("res://scenes/menu/main_menu.tscn").instantiate()
	add_child(m)
	await get_tree().create_timer(4.0).timeout
	var scr: Control = m.stack[0]
	print("hijos contenido=", scr.content.get_child_count(), " tamaño scroll=", scr._scroll.size, " contenido=", scr.content.size, " pantalla=", scr.size, " visible=", scr.visible, " mod=", scr.modulate)
	get_viewport().get_texture().get_image().save_png(out.path_join("menu_main.png"))
	m.push(load("res://scripts/menu/screen_friendly.gd").new())
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(out.path_join("menu_friendly.png"))
	m.push(load("res://scripts/menu/screen_lineup.gd").new(DB.leagues[1]["teams"][0]))
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(out.path_join("menu_lineup.png"))
	m.push(load("res://scripts/menu/screen_legend.gd").new())
	await get_tree().create_timer(0.5).timeout
	var leg: Node = m.stack[m.stack.size() - 1]
	leg.view = "create"
	leg.rebuild()
	m.set_protagonist_look(leg.pdata)
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(out.path_join("menu_legend.png"))
	print("capturas ok")
	get_tree().quit()
