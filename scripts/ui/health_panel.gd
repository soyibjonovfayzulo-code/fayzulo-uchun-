extends PanelContainer
## Health window (H): a body diagram with every wound on its body part (bleeding, bandaged, disinfected,
## festering), one-click treatment with the best carried item, and the overall condition (temperature,
## wetness, infection symptoms, poisoning, panic).

const C_TEXT := Color(0.88, 0.85, 0.76)
const C_DIM := Color(0.62, 0.6, 0.54)
const C_OK := Color("#7a9a5a")
const C_BAD := Color("#d0503a")
## Body diagram layout: part -> rect on a 120x220 figure.
const FIGURE := {
	"Голова": Rect2(45, 0, 30, 30), "Шея": Rect2(52, 30, 16, 10), "Торс": Rect2(36, 40, 48, 70),
	"Левая рука": Rect2(84, 42, 16, 76), "Правая рука": Rect2(20, 42, 16, 76),
	"Левая нога": Rect2(61, 112, 21, 100), "Правая нога": Rect2(38, 112, 21, 100),
}

var player: Player
var _figure: Control
var _list: VBoxContainer
var _state: Label
var _selected := ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -330
	offset_right = 330
	offset_top = -230
	offset_bottom = 230
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	add_child(h)
	var left := VBoxContainer.new()
	h.add_child(left)
	var title := Label.new()
	title.text = "Здоровье"
	title.add_theme_font_size_override("font_size", 20)
	left.add_child(title)
	_figure = Control.new()
	_figure.custom_minimum_size = Vector2(120, 220)
	_figure.draw.connect(_draw_figure)
	_figure.gui_input.connect(_on_figure_input)
	_figure.mouse_filter = Control.MOUSE_FILTER_STOP
	left.add_child(_figure)
	var hint := Label.new()
	hint.text = "Клик по части тела —\nтолько её раны"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", C_DIM)
	left.add_child(hint)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	h.add_child(right)
	_state = Label.new()
	_state.add_theme_font_size_override("font_size", 14)
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state.custom_minimum_size = Vector2(440, 0)
	right.add_child(_state)
	var sep := HSeparator.new()
	right.add_child(sep)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 270)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var close := Button.new()
	close.text = "Закрыть (H)"
	close.pressed.connect(func() -> void: visible = false)
	right.add_child(close)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func _process(_delta: float) -> void:
	if visible and Engine.get_process_frames() % 15 == 0:
		refresh()


func refresh() -> void:
	if player == null:
		return
	_figure.queue_redraw()
	var st := player.stats
	var bt := player.body_temp
	var lines: Array[String] = []
	lines.append("Здоровье: %d%%   Температура тела: %.1f °C   Ощущается: %+d °C" % [
		roundi(player.health.ratio() * 100.0), bt.temp, roundi(bt.felt)])
	var cond: Array[String] = []
	if bt.wetness > 0.1:
		cond.append("промокли (%d%%)" % roundi(bt.wetness * 100.0))
	var sym := player.wounds.symptoms()
	if sym != "":
		cond.append(sym.to_lower())
	if player.wounds.has_festering():
		cond.append("воспаление раны" + (" (лечится антибиотиком)" if player.wounds.antibiotic_hours > 0.0 else ""))
	if st.poison > 0.05:
		cond.append("пищевое отравление")
	if st.panic > 0.25:
		cond.append("паника")
	if player.wounds.painkiller_hours > 0.0:
		cond.append("обезболивающее ещё действует")
	lines.append("Состояние: " + (", ".join(cond) if not cond.is_empty() else "в норме"))
	_state.text = "\n".join(lines)
	for c in _list.get_children():
		c.queue_free()
	var shown := 0
	for part in Wounds.PARTS:
		if _selected != "" and part != _selected:
			continue
		for w in player.wounds.on_part(part):
			_add_wound_row(part, w)
			shown += 1
	if shown == 0:
		var l := Label.new()
		l.text = "Ран нет." if _selected == "" else "%s: ран нет." % _selected
		l.add_theme_color_override("font_color", C_DIM)
		_list.add_child(l)


func _add_wound_row(part: String, w: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_list.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var spec: Dictionary = Wounds.TYPES[w["type"]]
	var flags: Array[String] = []
	flags.append("перевязана" if w["bandaged"] else "КРОВОТОЧИТ")
	if w["disinfected"]:
		flags.append("обработана")
	if w["festering"]:
		flags.append("ВОСПАЛЕНИЕ")
	var heal: float = clampf(float(w["age"]) / float(spec["heal_h"]), 0.0, 1.0)
	var l := Label.new()
	l.text = "%s — %s: %s · заживление %d%%" % [part, spec["name"], ", ".join(flags), roundi(heal * 100.0)]
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", C_BAD if (not w["bandaged"] or w["festering"]) else C_TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	box.add_child(row)
	if not w["bandaged"]:
		var b := _treat_button("Перевязать", _best_item(["stops_bleeding"], w["type"] == "scratch"))
		b.pressed.connect(func() -> void: _treat(b.get_meta("stack"), part))
		row.add_child(b)
	if not w["disinfected"]:
		var b2 := _treat_button("Обработать", _best_item(["disinfects"], false))
		b2.pressed.connect(func() -> void: _treat(b2.get_meta("stack"), part, true))
		row.add_child(b2)


func _treat_button(label: String, s: ItemStack) -> Button:
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size = Vector2(0, 26)
	b.text = label + (": " + s.item.display_name if s else " (нечем)")
	b.disabled = s == null
	b.set_meta("stack", s)
	return b


## Best carried item with the given flag (bandage before plaster unless the wound is a scratch).
func _best_item(flags: Array, scratch_ok: bool) -> ItemStack:
	var best: ItemStack = null
	for s in player.inventory.main.stacks:
		var d := s.item
		var ok := false
		for f in flags:
			ok = ok or bool(d.get(f))
		if not ok:
			continue
		if d.minor_wounds_only and not scratch_ok:
			continue
		if d.id == "vodka" and best != null:
			continue
		if best == null or (best.item.id == "vodka") or (best.item.minor_wounds_only and not d.minor_wounds_only):
			best = s
	return best


func _treat(s: ItemStack, part: String, disinfect := false) -> void:
	if s == null or not player.inventory.main.has(s):
		return
	var verb := "Обрабатываем" if disinfect else "Перевязываем"
	player.start_timed_action("%s: %s..." % [verb, part.to_lower()], 2.5 if disinfect else 3.0, func() -> void:
		if not player.inventory.main.has(s):
			return
		if disinfect:
			player.wounds.disinfect(part)
		else:
			var wname := player.wounds.bandage(s.item.minor_wounds_only, part)
			if s.item.disinfects:
				player.wounds.disinfect(part)
			if s.item.heal > 0.0:
				player.health.heal(s.item.heal)
			if wname != "":
				Events.show_toast("Перевязано: %s." % wname)
		player.spend_use(s)
		refresh())


func _on_figure_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := ""
		for part in FIGURE:
			if (FIGURE[part] as Rect2).has_point(event.position):
				hit = part
		_selected = "" if hit == _selected else hit
		refresh()


func _draw_figure() -> void:
	if player == null:
		return
	for part in FIGURE:
		var r: Rect2 = FIGURE[part]
		var ws := player.wounds.on_part(part)
		var col := Color(0.32, 0.3, 0.26)
		if not ws.is_empty():
			col = Color("#8a6a3a")
			for w in ws:
				if not w["bandaged"] or w["festering"]:
					col = Color("#a8302a")
					break
			if col != Color("#a8302a") and ws.all(func(w: Dictionary) -> bool: return w["bandaged"]):
				col = Color("#c8c0a8")
		if part == _selected:
			_figure.draw_rect(r.grow(2), Color(0.9, 0.8, 0.5), false, 2.0)
		_figure.draw_rect(r, col)
		_figure.draw_rect(r, Color(0, 0, 0, 0.6), false, 1.0)
