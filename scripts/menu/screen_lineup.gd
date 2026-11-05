extends MenuScreen
## Alineación: arrastrar y soltar entre el campo y el banquillo, formación (incluida la
## personalizada moviendo posiciones), rol de cada puesto y estrategia. Se guarda en la base.

const ROLES := ["GK", "CB", "RB", "LB", "DMF", "CMF", "AMF", "RMF", "LMF", "RWF", "LWF", "SS", "CF"]
const FORMS := ["4-4-2", "4-3-3", "4-2-3-1", "3-5-2", "5-3-2", "custom"]

var team_id := ""
var t: Dictionary
var pitch: Control
var bench_box: VBoxContainer
var on_close: Callable


func _init(tid: String, cb: Callable = Callable()) -> void:
	super(Lang.t("lineup"))
	team_id = tid
	on_close = cb


func build() -> void:
	t = DB.team(team_id)
	if t.get("lineup", []).size() < 11:
		DB.best_lineup(team_id, str(t.get("formation", "4-3-3")))
	var head := row()
	head.add_child(CrestView.new(t.get("crest", {}), 44))
	label(str(t.get("name", "")), 24, head, UITheme.YELLOW)
	var fidx := FORMS.find(_form_key())
	cycler(Lang.t("formation"), [Lang.t("f_442"), "4-3-3", "4-2-3-1", "3-5-2", "5-3-2", Lang.t("custom")], maxi(fidx, 0), func(i: int) -> void:
		if FORMS[i] == "custom":
			t["custom_slots"] = Formations.slots(str(t.get("formation", "4-3-3"))).duplicate(true)
			t["formation"] = "custom_" + team_id
		else:
			t["formation"] = FORMS[i]
		if FORMS[i] != "custom":
			DB.best_lineup(team_id, t["formation"])
		_register()
		_refresh())
	var skeys: Array = Team.STRATEGIES.keys()
	cycler(Lang.t("strategy"), skeys.map(func(k): return Lang.t("strat_" + k)), maxi(skeys.find(str(t.get("strategy", "normal"))), 0), func(i: int) -> void:
		t["strategy"] = skeys[i])
	var actions := row()
	button(Lang.t("best_eleven"), func() -> void:
		DB.best_lineup(team_id, str(t.get("formation", "4-3-3")))
		_refresh(), actions, 220)
	button(Lang.t("save"), func() -> void:
		DB.save()
		toast(Lang.t("saved"))
		go_back(), actions, 160)
	label(Lang.t("lineup_help"), 15, null, UITheme.DIM)
	var h := row(null, 18)
	pitch = Control.new()
	pitch.custom_minimum_size = Vector2(640, 470)
	pitch.draw.connect(_draw_pitch)
	h.add_child(pitch)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 330
	h.add_child(right)
	label(Lang.t("bench"), 20, right, UITheme.YELLOW)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(330, 430)
	right.add_child(sc)
	bench_box = VBoxContainer.new()
	sc.add_child(bench_box)
	_register()
	_refresh()


func _form_key() -> String:
	var f := str(t.get("formation", "4-3-3"))
	return "custom" if f.begins_with("custom") else f


func _register() -> void:
	if str(t.get("formation", "")).begins_with("custom") and t.has("custom_slots"):
		Formations.register_custom(t["formation"], t["custom_slots"])


func _slots() -> Array:
	return Formations.slots(str(t.get("formation", "4-3-3")))


func _draw_pitch() -> void:
	var s := pitch.size
	pitch.draw_rect(Rect2(Vector2.ZERO, s), Color(0.1, 0.38, 0.16))
	for i in 8:
		if i % 2 == 0:
			pitch.draw_rect(Rect2(0, s.y * i / 8.0, s.x, s.y / 8.0), Color(0.12, 0.42, 0.18))
	var w := Color(1, 1, 1, 0.6)
	pitch.draw_rect(Rect2(Vector2(4, 4), s - Vector2(8, 8)), w, false, 2.0)
	pitch.draw_line(Vector2(4, s.y * 0.5), Vector2(s.x - 4, s.y * 0.5), w, 2.0)
	pitch.draw_arc(s * 0.5, s.y * 0.12, 0, TAU, 32, w, 2.0)
	pitch.draw_rect(Rect2(s.x * 0.25, s.y - s.y * 0.17, s.x * 0.5, s.y * 0.17 - 4), w, false, 2.0)
	pitch.draw_rect(Rect2(s.x * 0.25, 4, s.x * 0.5, s.y * 0.17), w, false, 2.0)


func _slot_pos(sl: Array) -> Vector2:
	var s := pitch.custom_minimum_size
	var depth: float = sl[1]
	var width: float = sl[2]
	if sl[0] == "GK":
		depth = -0.18
	var y := s.y * (0.9 - (depth + 0.18) / 1.2 * 0.85)
	var x := s.x * (0.5 + width * 0.42)
	return Vector2(x, y) - Vector2(75, 29)


func _refresh() -> void:
	for c in pitch.get_children():
		c.queue_free()
	for c in bench_box.get_children():
		c.queue_free()
	pitch.queue_redraw()
	var lineup: Array = t.get("lineup", [])
	var slots := _slots()
	for i in mini(slots.size(), lineup.size()):
		var p: Dictionary = DB.players.get(lineup[i], {})
		if p.is_empty():
			continue
		var chip := PlayerChip.new()
		chip.setup(p, i, slots[i][0])
		chip.position = _slot_pos(slots[i])
		chip.dropped_on.connect(_on_drop)
		var idx := i
		chip.pressed.connect(func() -> void: _change_role(idx))
		pitch.add_child(chip)
		var rl := Label.new()
		rl.text = slots[i][0]
		rl.position = chip.position + Vector2(0, -18)
		rl.add_theme_color_override("font_color", UITheme.YELLOW)
		rl.add_theme_font_size_override("font_size", 14)
		pitch.add_child(rl)
	for pid in t.get("players", []):
		if lineup.has(pid):
			continue
		var p2: Dictionary = DB.players.get(pid, {})
		if p2.is_empty():
			continue
		var chip2 := PlayerChip.new()
		chip2.setup(p2, -1, "")
		chip2.custom_minimum_size = Vector2(310, 52)
		chip2.dropped_on.connect(_on_drop)
		bench_box.add_child(chip2)


## Intercambio entre dos fichas (titular-titular, titular-suplente).
func _on_drop(src: Dictionary, dst: PlayerChip) -> void:
	var lineup: Array = t["lineup"]
	var a: String = src["pid"]
	var b: String = dst.pid
	if a == b:
		return
	var ia := lineup.find(a)
	var ib := lineup.find(b)
	if ia >= 0 and ib >= 0:
		lineup[ia] = b
		lineup[ib] = a
	elif ia >= 0:
		lineup[ia] = b
	elif ib >= 0:
		lineup[ib] = a
	Audio.ui("click")
	_refresh()


## Pulsar una ficha del campo cambia el rol de ese puesto (formación personalizada).
func _change_role(i: int) -> void:
	if not str(t.get("formation", "")).begins_with("custom"):
		t["custom_slots"] = _slots().duplicate(true)
		t["formation"] = "custom_" + team_id
	var cs: Array = t["custom_slots"]
	if i == 0:
		return
	var r := ROLES.find(str(cs[i][0]))
	r = (r + 1) % ROLES.size()
	if ROLES[r] == "GK":
		r = (r + 1) % ROLES.size()
	cs[i][0] = ROLES[r]
	# Ajusta la profundidad/anchura típicas del nuevo rol
	var typical := {"CB": 0.0, "RB": 0.06, "LB": 0.06, "DMF": 0.3, "CMF": 0.45, "AMF": 0.66, "RMF": 0.5, "LMF": 0.5, "RWF": 0.85, "LWF": 0.85, "SS": 0.8, "CF": 0.92}
	cs[i][1] = typical.get(ROLES[r], cs[i][1])
	if ROLES[r] in ["RB", "RMF", "RWF"]:
		cs[i][2] = absf(float(cs[i][2])) if absf(float(cs[i][2])) > 0.5 else 0.8
	elif ROLES[r] in ["LB", "LMF", "LWF"]:
		cs[i][2] = -absf(float(cs[i][2])) if absf(float(cs[i][2])) > 0.5 else -0.8
	_register()
	_refresh()


func go_back() -> void:
	DB.save()
	menu.pop()
	if on_close.is_valid():
		on_close.call()
