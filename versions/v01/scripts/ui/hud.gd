extends Control
## In-game HUD (Project Zomboid-like layout): clock, status bars, moodles, interaction prompt,
## right-click action menu, toasts, district map (M), pause menu (Esc), controls help (F1), death screen.

const C_BG := Color(0.07, 0.07, 0.065, 0.82)
const C_BORDER := Color(0.36, 0.34, 0.29, 0.9)
const C_TEXT := Color(0.88, 0.85, 0.76)
const C_DIM := Color(0.62, 0.6, 0.54)
const WEEKDAYS := ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]

var player: V01Player
var _clock: Label
var _date: Label
var _location: Label
var _bars := {}
var _moodles: VBoxContainer
var _prompt: PanelContainer
var _prompt_label: Label
var _toasts: VBoxContainer
var _menu: PopupMenu
var _menu_target: V01Interactable
var _menu_actions: Array = []
var _map: Control
var _pause: Control
var _help: PanelContainer
var _death: Control
var _mode_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _make_theme()
	_build_top_left()
	_build_status()
	_build_prompt()
	_build_toasts()
	_build_menu()
	_build_help()
	_map = preload("res://versions/v01/scripts/ui/map_view.gd").new()
	_map.visible = false
	add_child(_map)
	_build_pause()
	_build_death()
	V01Events.toast.connect(_on_toast)
	V01Events.context_menu_requested.connect(_on_context_menu)
	V01Events.player_location_changed.connect(_on_location)
	V01Events.container_opened.connect(_on_container_opened)
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player") as V01Player
	if player:
		player.died.connect(_on_player_died)
	_on_toast("Вы проснулись в пустом дворе. Город молчит. [F1] — управление.")


func _make_theme() -> Theme:
	var t := Theme.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.border_color = C_BORDER
	sb.set_border_width_all(1)
	sb.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", sb)
	t.set_color("font_color", "Label", C_TEXT)
	t.set_font_size("font_size", "Label", 15)
	var btn := sb.duplicate() as StyleBoxFlat
	btn.bg_color = Color(0.14, 0.135, 0.12, 0.95)
	var btn_h := btn.duplicate() as StyleBoxFlat
	btn_h.bg_color = Color(0.26, 0.24, 0.19, 0.95)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_h)
	t.set_stylebox("pressed", "Button", btn_h)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", C_TEXT)
	t.set_font_size("font_size", "Button", 17)
	var pm := sb.duplicate() as StyleBoxFlat
	pm.set_content_margin_all(4)
	t.set_stylebox("panel", "PopupMenu", pm)
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(0.3, 0.27, 0.2, 1)
	t.set_stylebox("hover", "PopupMenu", hov)
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 0.95, 0.8))
	t.set_font_size("font_size", "PopupMenu", 15)
	return t


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _label(parent: Control, text := "", font_size := 15, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_top_left() -> void:
	var p := _panel(self)
	p.position = Vector2(14, 14)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	_clock = _label(v, "08:30", 26)
	_date = _label(v, "", 13, C_DIM)
	_location = _label(v, "Улица", 13, C_DIM)


func _build_status() -> void:
	var p := _panel(self)
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = 14
	p.offset_top = -150
	p.offset_bottom = -14
	p.offset_right = 250
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	_mode_label = _label(v, "Шаг", 13, C_DIM)
	for spec in [["health", "Здоровье", Color("#a8403a")], ["endurance", "Выносливость", Color("#c8a040")],
			["fatigue", "Усталость", Color("#b8743a")], ["drowsy", "Сонливость", Color("#5a78a8")]]:
		var row := HBoxContainer.new()
		v.add_child(row)
		var l := _label(row, spec[1], 13)
		l.custom_minimum_size = Vector2(96, 0)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(120, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.001
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.15, 0.14, 0.12)
		bg.border_color = C_BORDER
		bg.set_border_width_all(1)
		var fg := StyleBoxFlat.new()
		fg.bg_color = spec[2]
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fg)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		_bars[spec[0]] = bar
	_moodles = VBoxContainer.new()
	_moodles.anchor_left = 1.0
	_moodles.anchor_right = 1.0
	_moodles.offset_left = -190
	_moodles.offset_right = -14
	_moodles.offset_top = 14
	_moodles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_moodles)


func _build_prompt() -> void:
	_prompt = _panel(self)
	_prompt.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.05, 0.78)
	sb.border_color = Color(0.7, 0.6, 0.35, 0.8)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(5)
	_prompt.add_theme_stylebox_override("panel", sb)
	_prompt_label = _label(_prompt, "", 14)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 0.5
	_toasts.anchor_right = 0.5
	_toasts.anchor_top = 1.0
	_toasts.anchor_bottom = 1.0
	_toasts.offset_left = -330
	_toasts.offset_right = 330
	_toasts.offset_top = -190
	_toasts.offset_bottom = -40
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


func _build_menu() -> void:
	_menu = PopupMenu.new()
	add_child(_menu)
	_menu.id_pressed.connect(func(id: int) -> void:
		if is_instance_valid(_menu_target) and id < _menu_actions.size() and player:
			player.interactor.use_action(_menu_target, _menu_actions[id]["id"]))


func _build_help() -> void:
	_help = _panel(self)
	_help.anchor_left = 1.0
	_help.anchor_right = 1.0
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = -300
	_help.offset_right = -14
	_help.offset_top = -300
	_help.offset_bottom = -14
	_help.visible = false
	var v := VBoxContainer.new()
	_help.add_child(v)
	_label(v, "Управление", 17)
	for line in ["WASD — движение (8 направлений)", "Shift — бег", "Ctrl — присесть / красться", "E — действие",
			"ПКМ — меню действий", "ЛКМ — удар", "Колесо мыши — масштаб", "M — карта района", "Tab — инвентарь (M4)",
			"Esc — пауза", "F1 — скрыть подсказки"]:
		_label(v, line, 13, C_DIM)


func _build_pause() -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0, 0, 0, 0.55)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -130
	box.offset_right = 130
	box.offset_top = -120
	box.offset_bottom = 120
	box.add_theme_constant_override("separation", 10)
	_pause.add_child(box)
	var title := _label(box, "ПАУЗА", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for spec in [["Продолжить", _toggle_pause], ["Управление", func() -> void: _help.visible = not _help.visible],
			["Выйти в меню версий", _to_menu], ["Выйти из игры", func() -> void: get_tree().quit()]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(260, 40)
		b.pressed.connect(spec[1])
		box.add_child(b)


func _build_death() -> void:
	_death = ColorRect.new()
	(_death as ColorRect).color = Color(0.1, 0.0, 0.0, 0.6)
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.visible = false
	add_child(_death)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -200
	box.offset_right = 200
	box.offset_top = -80
	box.offset_bottom = 80
	_death.add_child(box)
	var l := _label(box, "ВЫ ПОГИБЛИ", 36, Color("#d8b0a0"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(box, "", 15, C_DIM)
	sub.name = "Sub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := Button.new()
	b.text = "Начать заново"
	b.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	box.add_child(b)


# ------------------------------------------------------------------------------------------------ runtime
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _map.visible:
			_map.visible = false
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and not get_tree().paused:
		_map.visible = not _map.visible
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F1:
		_help.visible = not _help.visible


func _to_menu() -> void:
	get_tree().paused = false
	V01Sfx.stop_ambient()
	get_tree().change_scene_to_file("res://launcher/main_menu.tscn")


func _toggle_pause() -> void:
	if _death.visible:
		return
	get_tree().paused = not get_tree().paused
	_pause.visible = get_tree().paused


func _process(delta: float) -> void:
	if player == null:
		return
	var day := V01GameTime.get_day()
	_clock.text = V01GameTime.get_clock_text()
	_date.text = "День %d · %s, %d июля" % [day, WEEKDAYS[(day + 2) % 7], 8 + day]
	_bars["health"].value = player.health.ratio()
	_bars["endurance"].value = player.stats.endurance
	_bars["fatigue"].value = player.stats.fatigue
	_bars["drowsy"].value = player.stats.drowsiness
	var mode := "Бег" if player.running else ("Крадётесь" if player.crouching else "Шаг")
	if player.state == V01Player.State.SEATED:
		mode = "Отдых"
	_mode_label.text = mode
	_update_moodles()
	_update_prompt()
	for t in _toasts.get_children():
		var life: float = t.get_meta("life") - delta
		t.set_meta("life", life)
		t.modulate.a = clampf(life, 0.0, 1.0)
		if life <= 0.0:
			t.queue_free()


func _update_moodles() -> void:
	var want: Array = []
	if player.stats.exhausted:
		want.append(["Запыхались", Color("#c8a040")])
	if player.stats.fatigue > 0.45:
		want.append(["Утомление", Color("#b8743a")])
	if player.stats.drowsiness > 0.6:
		want.append(["Хочется спать", Color("#5a78a8")])
	if player.health.ratio() < 0.6:
		want.append(["Ранены", Color("#a8403a")])
	var key := str(want)
	if _moodles.get_meta("key", "") == key:
		return
	_moodles.set_meta("key", key)
	for c in _moodles.get_children():
		c.queue_free()
	for m in want:
		var p := _panel(_moodles)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.08, 0.07, 0.85)
		sb.border_color = m[1]
		sb.set_border_width_all(2)
		sb.set_content_margin_all(5)
		p.add_theme_stylebox_override("panel", sb)
		_label(p, m[0], 14, m[1])


func _update_prompt() -> void:
	var it := player.interactor.focused
	if it == null or player.camera == null or player.state != V01Player.State.NORMAL:
		_prompt.visible = false
		return
	var actions := it.get_actions(player)
	if actions.is_empty():
		_prompt.visible = false
		return
	var fp := it.get_focus_point()
	if player.camera.is_position_behind(fp):
		_prompt.visible = false
		return
	var view := get_node("../../GameView") as SubViewportContainer
	var sp := player.camera.unproject_position(fp) * float(view.stretch_shrink)
	var more := "   ПКМ: ещё" if actions.size() > 1 else ""
	_prompt_label.text = "[E] %s%s" % [actions[0]["label"], more]
	_prompt.visible = true
	_prompt.reset_size()
	_prompt.position = (sp + Vector2(-_prompt.size.x * 0.5, -54)).round()


func _on_toast(text: String) -> void:
	var p := _panel(_toasts)
	_label(p, text, 15)
	p.set_meta("life", 4.5)
	while _toasts.get_child_count() > 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()


func _on_context_menu(target: Node, actions: Array) -> void:
	_menu.clear()
	_menu_target = target as V01Interactable
	_menu_actions = actions
	_menu.add_separator((target as V01Interactable).display_name)
	for i in actions.size():
		_menu.add_item(actions[i]["label"], i)
	_menu.reset_size()
	_menu.position = Vector2i(get_viewport().get_mouse_position()) + Vector2i(4, 4)
	_menu.popup()


func _on_location(building: Node, level: int) -> void:
	if building == null:
		_location.text = "Улица"
	else:
		var b := building as V01Building
		_location.text = "%s%s" % [b.display_name, (", %d этаж" % (level + 1)) if b.levels.size() > 1 else ""]


func _on_container_opened(container: Node) -> void:
	var c := container as V01LootContainer
	V01Events.show_toast("%s: обыскано. Предметы и лут появятся в Milestone 4." % c.display_name)


func _on_player_died() -> void:
	_death.visible = true
	var sub := _death.find_child("Sub", true, false) as Label
	sub.text = "Прожито: %d дн. %s" % [V01GameTime.get_day() - V01GameTime.START_DAY, V01GameTime.get_clock_text()]
