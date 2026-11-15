extends Control
## New game of the development build: character creation (name, occupation, traits bought with points,
## PZ-style) on the left, sandbox settings of the world on the right, "Продолжить" if a save exists.
## Test flags (--autotest, --tour, --shot=, --poses, --m78, --v04, --continue, --loadcheck) skip into the game.

const MAIN := "res://scenes/main/main.tscn"
const TEST_FLAGS := ["--autotest", "--tour", "--poses", "--no-zombies", "--m78", "--v04", "--gallery", "--fps", "--fpvm", "--fpgallery", "--probe-admin", "--profile-interactions", "--test-hot-update"]

## label, Settings property, [[option label, value], ...], default index
const OPTIONS := [
	["Зомби в городе", "zombie_count", [["Нет", 0], ["Мало (15)", 15], ["Обычно (35)", 35], ["Много (60)", 60], ["Орда (100)", 100]], 2],
	["Скорость зомби", "zombie_speed", [["Медленные", 0.75], ["Обычные", 1.0], ["Быстрые", 1.35]], 1],
	["Урон зомби", "zombie_damage", [["Слабый", 0.6], ["Обычный", 1.0], ["Сильный", 1.5]], 1],
	["Заражение от укуса", "infection_chance_bite", [["Выключено", 0.0], ["Низкое (15%)", 0.15], ["Обычное (35%)", 0.35], ["Всегда (100%)", 1.0]], 2],
	["От заражения до смерти", "infection_hours_to_death", [["1 игровой день", 24.0], ["3 дня", 72.0], ["Неделя", 168.0]], 1],
	["Длина игрового дня", "day_length_minutes", [["24 минуты", 24.0], ["48 минут", 48.0], ["96 минут", 96.0]], 1],
	["Свет, газ и вода пропадут", "utilities_off_day", [["В 1-й день", 1], ["На 3-й день", 3], ["Через неделю", 7], ["Никогда", 0]], 1],
	["Дожди", "weather", [["Да", true], ["Нет", false]], 0],
	["Вертолёт (2–3 день)", "helicopter", [["Да", true], ["Нет", false]], 0],
	["Тестовая будка с ящиками", "test_room", [["Есть", true], ["Нет", false]], 0],
	["Вид камеры", "first_person", [["От первого лица", true], ["Изометрия (как в v0.4)", false]], 0],
	["Обучение (подсказки новичку)", "tutorial", [["Да", true], ["Нет", false]], 0],
	["Начало", "start_hour", [["Утро, 8:30", 8.5], ["Вечер, 19:00", 19.0], ["Ночь, 23:30", 23.5]], 0],
]

var _pickers: Array[OptionButton] = []
var _name: LineEdit
var _prof := "unemployed"
var _traits: Array = []
var _prof_buttons := {}
var _prof_desc: Label
var _points: Label
var _start: Button


func _ready() -> void:
	get_tree().paused = false
	GameOptions.ensure_loaded()
	theme = UiTheme.theme()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a in TEST_FLAGS or a.begins_with("--shot="):
			get_tree().change_scene_to_file.call_deferred(MAIN)
			return
	if ("--continue" in args or "--loadcheck" in args) and SaveGame.exists():
		_continue()
		return
	_build()
	UiTheme.fit(self)
	if "--newgame-shot" in args:
		for i in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/screens/30_new_game.png"))
		get_tree().quit()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color(0.05, 0.05, 0.045)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.modulate = Color(0.32, 0.32, 0.31)
	bg.texture = load("res://assets/ui/menu_bg.png")
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 28
	root.offset_right = -28
	root.offset_top = 18
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var title := _label(root, "НОВАЯ ИГРА", 28, UiTheme.TEXT)
	title.add_theme_font_override("font", UiTheme.font(true))
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)
	cols.add_child(_character_panel())
	cols.add_child(_sandbox_panel())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	root.add_child(foot)
	var back := Button.new()
	back.text = "Назад в меню"
	back.custom_minimum_size = Vector2(200, 44)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://launcher/main_menu.tscn"))
	foot.add_child(back)
	var sum := SaveGame.summary()
	if not sum.is_empty():
		var c := Button.new()
		c.text = "Продолжить (день %d, %s)" % [sum["day"], sum["clock"]]
		c.custom_minimum_size = Vector2(280, 44)
		c.add_theme_font_size_override("font_size", 18)
		c.pressed.connect(_continue)
		foot.add_child(c)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	if not sum.is_empty():
		_label(foot, "Новая игра перезапишет сохранение  ", 15, UiTheme.ACCENT)
	_start = Button.new()
	_start.text = "НАЧАТЬ"
	_start.custom_minimum_size = Vector2(240, 44)
	_start.add_theme_font_override("font", UiTheme.font(true))
	_start.add_theme_font_size_override("font_size", 22)
	_start.pressed.connect(_start_new)
	foot.add_child(_start)
	_refresh()


func _character_panel() -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	_label(v, "ПЕРСОНАЖ", 17, UiTheme.ACCENT)
	var nrow := HBoxContainer.new()
	v.add_child(nrow)
	_label(nrow, "Имя", 17, UiTheme.TEXT).custom_minimum_size = Vector2(70, 0)
	_name = LineEdit.new()
	_name.text = Settings.char_name
	_name.custom_minimum_size = Vector2(260, 34)
	_name.add_theme_font_size_override("font_size", 17)
	nrow.add_child(_name)
	_label(v, "Профессия", 17, UiTheme.TEXT)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for id in Profession.LIST:
		var b := Button.new()
		b.text = Profession.LIST[id]["name"]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(132, 34)
		b.add_theme_font_size_override("font_size", 15)
		var pid: String = id
		b.pressed.connect(func() -> void:
			_prof = pid
			_refresh())
		grid.add_child(b)
		_prof_buttons[id] = b
	_prof_desc = _label(v, "", 15, UiTheme.DIM)
	_prof_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prof_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prof_desc.custom_minimum_size = Vector2(460, 36)
	var trow := HBoxContainer.new()
	v.add_child(trow)
	_label(trow, "Черты характера", 17, UiTheme.TEXT)
	var spc := Control.new()
	spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(spc)
	_points = _label(trow, "", 17, UiTheme.ACCENT)
	var tg := GridContainer.new()
	tg.columns = 2
	tg.add_theme_constant_override("h_separation", 8)
	tg.add_theme_constant_override("v_separation", 4)
	v.add_child(tg)
	for id in Profession.TRAITS:
		var spec: Array = Profession.TRAITS[id]
		var c := CheckBox.new()
		var cost: int = spec[1]
		c.text = "%s (%s%d) — %s" % [spec[0], "−" if cost > 0 else "+", absi(cost), spec[2]]
		c.add_theme_font_size_override("font_size", 15)
		c.add_theme_color_override("font_color", UiTheme.TEXT if cost > 0 else Color("#d8a080"))
		c.custom_minimum_size = Vector2(240, 0)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var tid: String = id
		c.toggled.connect(func(on: bool) -> void:
			if on and not tid in _traits:
				_traits.append(tid)
			elif not on:
				_traits.erase(tid)
			_refresh())
		tg.add_child(c)
	var hint := _label(v, "Положительные черты стоят очков, отрицательные — дают их. Начать можно, если очков ≥ 0.", 14, UiTheme.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.custom_minimum_size = Vector2(460, 0)
	return p


func _sandbox_panel() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(460, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 5)
	sc.add_child(v)
	_label(v, "МИР (ПЕСОЧНИЦА)", 17, UiTheme.ACCENT)
	for o in OPTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var l := _label(row, o[0], 16, UiTheme.TEXT)
		l.custom_minimum_size = Vector2(220, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(205, 32)
		ob.add_theme_font_size_override("font_size", 16)
		for opt in o[2]:
			ob.add_item(opt[0])
		ob.select(o[3])
		row.add_child(ob)
		_pickers.append(ob)
	return p


func _refresh() -> void:
	for id in _prof_buttons:
		(_prof_buttons[id] as Button).button_pressed = id == _prof
	var d: Dictionary = Profession.LIST[_prof]
	_prof_desc.text = d["desc"]
	var left := Profession.points_left(_prof, _traits)
	_points.text = "Очки: %d" % left
	_points.add_theme_color_override("font_color", UiTheme.GOOD if left >= 0 else UiTheme.BAD)
	_start.disabled = left < 0


func _start_new() -> void:
	for i in OPTIONS.size():
		var o: Array = OPTIONS[i]
		Settings.set(o[1], o[2][_pickers[i].selected][1])
	Settings.char_name = _name.text.strip_edges() if _name.text.strip_edges() != "" else "Иван"
	Settings.profession = _prof
	Settings.traits = _traits.duplicate()
	Settings.world_seed = 1993
	Settings.load_save = false
	SaveGame.delete()
	get_tree().change_scene_to_file(MAIN)


func _continue() -> void:
	SaveGame.apply_settings()
	Settings.load_save = true
	get_tree().change_scene_to_file.call_deferred(MAIN)


func _label(parent: Node, text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
