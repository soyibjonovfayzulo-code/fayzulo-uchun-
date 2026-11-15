extends Control
## Start screen of the development build: "Продолжить" (loads the save), "Новая игра" with sandbox
## settings (zombies, infection, day length, utilities, weather, test shed, start time) and back to the
## version launcher. Test flags (--autotest, --tour, --shot=, --poses, --continue) skip straight into the game.

const MAIN := "res://versions/v03/scenes/main/main.tscn"
const C_TEXT := Color(0.88, 0.85, 0.76)
const C_DIM := Color(0.62, 0.6, 0.54)
const C_ACCENT := Color(0.78, 0.36, 0.26)
const TEST_FLAGS := ["--autotest", "--tour", "--poses", "--no-zombies", "--m78"]

## label, Settings property, [[option label, value], ...], default index
const OPTIONS := [
	["Зомби в районе", "zombie_count", [["Нет", 0], ["Мало (25)", 25], ["Обычно (60)", 60], ["Орда (110)", 110]], 2],
	["Скорость зомби", "zombie_speed", [["Медленные", 0.75], ["Обычные", 1.0], ["Быстрые", 1.35]], 1],
	["Урон зомби", "zombie_damage", [["Слабый", 0.6], ["Обычный", 1.0], ["Сильный", 1.5]], 1],
	["Заражение от укуса", "infection_chance_bite", [["Выключено", 0.0], ["Низкое (15%)", 0.15], ["Обычное (35%)", 0.35], ["Всегда (100%)", 1.0]], 2],
	["От заражения до смерти", "infection_hours_to_death", [["1 игровой день", 24.0], ["3 дня", 72.0], ["Неделя", 168.0]], 1],
	["Длина игрового дня", "day_length_minutes", [["24 минуты", 24.0], ["48 минут", 48.0], ["96 минут", 96.0]], 1],
	["Свет, газ и вода пропадут", "utilities_off_day", [["В 1-й день", 1], ["На 3-й день", 3], ["Через неделю", 7], ["Никогда", 0]], 1],
	["Дожди", "weather", [["Да", true], ["Нет", false]], 0],
	["Тестовая будка с ящиками", "test_room", [["Есть", true], ["Нет", false]], 0],
	["Начало", "start_hour", [["Утро, 8:30", 8.5], ["Вечер, 19:00", 19.0], ["Ночь, 23:30", 23.5]], 0],
]

var _main_box: VBoxContainer
var _settings_box: VBoxContainer
var _pickers: Array[OptionButton] = []


func _ready() -> void:
	get_tree().paused = false
	V03GameOptions.ensure_loaded()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a in TEST_FLAGS or a.begins_with("--shot="):
			get_tree().change_scene_to_file.call_deferred(MAIN)
			return
	if ("--continue" in args or "--loadcheck" in args) and V03SaveGame.exists():
		_continue()
		return
	_build()
	if "--newgame-shot" in args:
		_show_settings(true)
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
	bg.modulate = Color(0.45, 0.45, 0.43)
	bg.texture = load("res://versions/v03/assets/ui/menu_bg.png")
	add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.45)
	add_child(shade)
	_main_box = VBoxContainer.new()
	_main_box.position = Vector2(70, 70)
	_main_box.add_theme_constant_override("separation", 8)
	add_child(_main_box)
	_label(_main_box, "RUSSIAN ZOMBIE SURVIVAL", 40, C_TEXT)
	_label(_main_box, "v0.3 — Выживание · микрорайон «Строитель», сентябрь", 17, C_DIM)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	_main_box.add_child(gap)
	var sum := V03SaveGame.summary()
	if not sum.is_empty():
		var c := _button(_main_box, "  Продолжить — день %d, %s   (убито: %d)" % [sum["day"], sum["clock"], sum["kills"]])
		c.pressed.connect(_continue)
		c.grab_focus.call_deferred()
	var n := _button(_main_box, "  Новая игра")
	n.pressed.connect(func() -> void: _show_settings(true))
	if sum.is_empty():
		n.grab_focus.call_deferred()
	var back := _button(_main_box, "  Назад к версиям")
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://launcher/main_menu.tscn"))
	_label(_main_box, "Сохранение: Esc → «Сохранить игру». Смерть удаляет сохранение.", 13, C_DIM)

	_settings_box = VBoxContainer.new()
	_settings_box.position = Vector2(70, 70)
	_settings_box.add_theme_constant_override("separation", 6)
	_settings_box.visible = false
	add_child(_settings_box)
	_label(_settings_box, "НОВАЯ ИГРА — НАСТРОЙКИ ПЕСОЧНИЦЫ", 24, C_TEXT)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	_settings_box.add_child(gap2)
	for o in OPTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_settings_box.add_child(row)
		var l := _label(row, o[0], 17, C_TEXT)
		l.custom_minimum_size = Vector2(300, 0)
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(260, 34)
		ob.add_theme_font_size_override("font_size", 16)
		for opt in o[2]:
			ob.add_item(opt[0])
		ob.select(o[3])
		row.add_child(ob)
		_pickers.append(ob)
	var gap3 := Control.new()
	gap3.custom_minimum_size = Vector2(0, 14)
	_settings_box.add_child(gap3)
	var start := _button(_settings_box, "  Начать")
	start.pressed.connect(_start_new)
	var cancel := _button(_settings_box, "  Назад")
	cancel.pressed.connect(func() -> void: _show_settings(false))
	if not V03SaveGame.summary().is_empty():
		_label(_settings_box, "Новая игра перезапишет текущее сохранение.", 13, C_ACCENT)


func _show_settings(on: bool) -> void:
	_main_box.visible = not on
	_settings_box.visible = on


func _start_new() -> void:
	for i in OPTIONS.size():
		var o: Array = OPTIONS[i]
		V03Settings.set(o[1], o[2][_pickers[i].selected][1])
	V03Settings.world_seed = 1993
	V03Settings.load_save = false
	V03SaveGame.delete()
	get_tree().change_scene_to_file(MAIN)


func _continue() -> void:
	V03SaveGame.apply_settings()
	V03Settings.load_save = true
	get_tree().change_scene_to_file.call_deferred(MAIN)


func _label(parent: Node, text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(520, 46)
	b.add_theme_font_size_override("font_size", 19)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.1, 0.1, 0.09, 0.85)
	n.border_color = Color(0.3, 0.28, 0.24)
	n.set_border_width_all(1)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.24, 0.2, 0.15, 0.95)
	h.border_color = C_ACCENT
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_color", C_DIM)
	b.add_theme_color_override("font_focus_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", C_TEXT)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	parent.add_child(b)
	return b
