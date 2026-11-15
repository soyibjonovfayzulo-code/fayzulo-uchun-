extends Control
## In-game HUD (Project Zomboid-like layout): clock, status bars, moodles, interaction prompt,
## right-click action menu, toasts, district map (M), health window (H), pause menu with saving and volume (Esc),
## controls help (F1), sleep overlay and the death screen.

const C_BG := Color(0.07, 0.07, 0.065, 0.82)
const C_BORDER := Color(0.36, 0.34, 0.29, 0.9)
const C_TEXT := Color(0.88, 0.85, 0.76)
const C_DIM := Color(0.62, 0.6, 0.54)
const WEEKDAYS := ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]

var player: Player
var _clock: Label
var _date: Label
var _location: Label
var _bars := {}
var _moodles: VBoxContainer
var _prompt: PanelContainer
var _prompt_label: Label
var _toasts: VBoxContainer
var _menu: PopupMenu
var _menu_target: Interactable
var _menu_actions: Array = []
var _map: Control
var _pause: Control
var _help: PanelContainer
var _death: Control
var _mode_label: Label
var _inventory: Control
var _weapon_panel: PanelContainer
var _weapon_icon: TextureRect
var _weapon_label: Label
var _weapon_bar: ProgressBar
var _action_panel: PanelContainer
var _action_label: Label
var _action_bar: ProgressBar
var _flash: ColorRect
var _weather: Label
var _utilities: Label
var _temp_label: Label
var _sleep_overlay: ColorRect
var _sleep_label: Label
var _health_panel: Control
var _death_title: Label
var _death_sub: Label
var _vignette: ColorRect
var _admin: Control
var _minimap: Control
var _car_panel: PanelContainer
var _car_label: Label
var _car_bar: ProgressBar
var _skills: PanelContainer
var _skills_box: VBoxContainer
var _who: Label
var _crosshair: Crosshair
var _view_btn: Button
var _status_panel: Control
var _touch: Control


func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.theme()
	_build_top_left()
	_build_status()
	_build_prompt()
	_build_toasts()
	_build_menu()
	_build_help()
	_map = preload("res://scripts/ui/map_view.gd").new()
	_map.visible = false
	add_child(_map)
	_build_weapon_panel()
	_build_action_panel()
	_crosshair = Crosshair.new()
	_crosshair.visible = false
	add_child(_crosshair)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.6, 0.0, 0.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.material = _vignette_material()
	add_child(_vignette)
	_inventory = preload("res://scripts/ui/inventory_ui.gd").new()
	add_child(_inventory)
	_health_panel = preload("res://scripts/ui/health_panel.gd").new()
	add_child(_health_panel)
	_minimap = preload("res://scripts/ui/minimap.gd").new()
	_minimap.anchor_left = 1.0
	_minimap.anchor_right = 1.0
	_minimap.offset_left = -214
	_minimap.offset_top = 14
	add_child(_minimap)
	_build_car_panel()
	_build_skills()
	_admin = preload("res://scripts/ui/admin_panel.gd").new()
	add_child(_admin)
	_build_sleep_overlay()
	_build_pause()
	UiTheme.fit(self)
	_menu.content_scale_factor = GameOptions.ui_scale
	_build_death()
	_touch = preload("res://scripts/ui/touch_controls.gd").new()
	_touch.set("hud", self)
	add_child(_touch)
	Events.player_hurt.connect(func(_a: float) -> void:
		_flash.color.a = 0.35
		if player and player.fp_active() and player.last_hit_from.length() > 0.1:
			var f := player.fp.forward()
			var from := -player.last_hit_from
			var ang := atan2(f.x * from.z - f.z * from.x, f.x * from.x + f.z * from.z)
			_crosshair.hurt(ang))
	Events.view_changed.connect(func(on: bool) -> void:
		if _view_btn:
			_view_btn.text = "Вид: от первого лица" if on else "Вид: изометрия")
	Events.toast.connect(_on_toast)
	Events.context_menu_requested.connect(_on_context_menu)
	Events.player_location_changed.connect(_on_location)
	Events.container_opened.connect(_on_container_opened)
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player") as Player
	if player:
		player.died.connect(_on_player_died)
		player.combat.attack_landed.connect(func(_t: Node, _d: float, killed: bool) -> void:
			if player.fp_active():
				_crosshair.hit(killed))
		_health_panel.set("player", player)
		_admin.set("player", player)
		if Settings.tutorial and not "--autotest" in OS.get_cmdline_user_args():
			var tut := preload("res://scripts/ui/tutorial.gd").new()
			tut.name = "Tutorial"
			add_child(tut)
			tut.call("bind", player)
		var prof: Dictionary = Profession.LIST.get(Settings.profession, Profession.LIST["unemployed"])
		_who.text = "%s · %s" % [Settings.char_name, prof["name"]]
	_on_toast("Вы проснулись в пустом дворе. Город молчит. [F1] — управление, [H] — здоровье.")


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
	p.position = Vector2(12, 10)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)
	_clock = _label(v, "08:30", 28)
	_clock.add_theme_font_override("font", UiTheme.font(true))
	_date = _label(v, "", 14, C_TEXT)
	_weather = _label(v, "", 14, C_TEXT)
	_location = _label(v, "Улица", 14, C_DIM)
	_utilities = _label(v, "", 14, Color("#c8784a"))
	_utilities.visible = false


func _build_status() -> void:
	var p := _panel(self)
	_status_panel = p
	p.position = Vector2(12, 124)
	p.custom_minimum_size = Vector2(252, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	_who = _label(v, "", 16, UiTheme.TEXT)
	_who.add_theme_font_override("font", UiTheme.font(true))
	_mode_label = _label(v, "Шаг", 14, C_DIM)
	for spec in [["health", "Здоровье", Color("#b8443e")], ["endurance", "Выносливость", Color("#d0a844")],
			["hunger", "Голод", Color("#9a7642")], ["thirst", "Жажда", Color("#4288aa")],
			["fatigue", "Усталость", Color("#c07c40")], ["drowsy", "Сонливость", Color("#6484b4")]]:
		var row := HBoxContainer.new()
		v.add_child(row)
		var l := _label(row, spec[1], 15)
		l.custom_minimum_size = Vector2(106, 0)
		var bar := UiTheme.bar(spec[2], 124.0, 13.0)
		row.add_child(bar)
		_bars[spec[0]] = bar
	var trow := HBoxContainer.new()
	v.add_child(trow)
	var tl := _label(trow, "Температура", 15)
	tl.custom_minimum_size = Vector2(106, 0)
	_temp_label = _label(trow, "36.6 °C", 15)
	_moodles = VBoxContainer.new()
	_moodles.anchor_left = 1.0
	_moodles.anchor_right = 1.0
	_moodles.offset_left = -390
	_moodles.offset_right = -216
	_moodles.offset_top = 54
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
	_toasts.offset_top = -220
	_toasts.offset_bottom = -82
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
	_help.offset_top = -390
	_help.offset_bottom = -14
	_help.visible = false
	var v := VBoxContainer.new()
	_help.add_child(v)
	_label(v, "Управление", 17)
	for line in ["WASD — движение, мышь — обзор", "V — от первого лица / изометрия", "Shift — бег", "Ctrl — присесть / красться", "E — действие",
				"ПКМ — меню действий (с оружием — прицелиться)", "ПКМ по пустому месту — спать, костёр", "ЛКМ — удар / выстрел по прицелу",
				"R — перезарядить, F — фонарик", "Колесо мыши — масштаб", "M — карта района", "Tab — инвентарь",
				"H — здоровье и раны, K — навыки", "Машина: W/S, A/D, Пробел, Q — сигнал", "Esc — пауза, F9 — админка",
				"F1 — скрыть подсказки"]:
		_label(v, line, 13, C_DIM)


func _build_pause() -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0, 0, 0, 0.65)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -150
	box.offset_right = 150
	box.offset_top = -295
	box.offset_bottom = 295
	box.add_theme_constant_override("separation", 6)
	_pause.add_child(box)
	var title := _label(box, "ПАУЗА", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for spec in [["Продолжить", _toggle_pause], ["Сохранить игру", _save_game],
			["Управление", func() -> void: _help.visible = not _help.visible],
			["Сохранить и выйти в меню", func() -> void:
				_save_game()
				_to_menu()],
			["Выйти в главное меню", _to_menu], ["Выйти из игры", func() -> void: get_tree().quit()]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(280, 34)
		b.pressed.connect(spec[1])
		box.add_child(b)
	var vol_row := HBoxContainer.new()
	box.add_child(vol_row)
	_label(vol_row, "Громкость", 14).custom_minimum_size = Vector2(90, 0)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = GameOptions.volume
	vol.custom_minimum_size = Vector2(170, 24)
	vol.value_changed.connect(func(v: float) -> void: GameOptions.set_volume(v))
	vol_row.add_child(vol)
	var sc_row := HBoxContainer.new()
	box.add_child(sc_row)
	_label(sc_row, "Интерфейс", 14).custom_minimum_size = Vector2(90, 0)
	var sc := OptionButton.new()
	for nm in GameOptions.UI_SCALE_NAMES:
		sc.add_item(nm)
	sc.select(GameOptions.ui_scale_index())
	sc.custom_minimum_size = Vector2(170, 30)
	sc.item_selected.connect(func(i: int) -> void:
		GameOptions.ui_scale = GameOptions.UI_SCALES[i]
		GameOptions.save()
		UiTheme.fit(self)
		_menu.content_scale_factor = GameOptions.ui_scale)
	sc_row.add_child(sc)
	_view_btn = Button.new()
	_view_btn.text = "Вид: от первого лица" if Settings.first_person else "Вид: изометрия"
	_view_btn.custom_minimum_size = Vector2(260, 36)
	_view_btn.pressed.connect(func() -> void:
		if player and player.get_parent().has_method("toggle_view"):
			player.get_parent().call("toggle_view"))
	box.add_child(_view_btn)
	var tc_btn := Button.new()
	tc_btn.text = "Сенсорные кнопки: ВКЛ" if (_touch and bool(_touch.get("enabled"))) else "Сенсорные кнопки: АВТО"
	tc_btn.custom_minimum_size = Vector2(260, 36)
	tc_btn.pressed.connect(func() -> void:
		if _touch:
			var next := not bool(_touch.get("enabled"))
			_touch.call("set_enabled", next)
			tc_btn.text = "Сенсорные кнопки: ВКЛ" if next else "Сенсорные кнопки: ВЫКЛ")
	box.add_child(tc_btn)
	var ms_row := HBoxContainer.new()
	box.add_child(ms_row)
	_label(ms_row, "Мышь", 14).custom_minimum_size = Vector2(90, 0)
	var ms := HSlider.new()
	ms.min_value = 0.3
	ms.max_value = 2.5
	ms.step = 0.05
	ms.value = GameOptions.mouse_sens
	ms.custom_minimum_size = Vector2(170, 24)
	ms.value_changed.connect(func(v: float) -> void:
		GameOptions.mouse_sens = v
		GameOptions.save())
	ms_row.add_child(ms)
	var fov_row := HBoxContainer.new()
	box.add_child(fov_row)
	_label(fov_row, "Обзор (FOV)", 14).custom_minimum_size = Vector2(90, 0)
	var fv := HSlider.new()
	fv.min_value = 70.0
	fv.max_value = 110.0
	fv.step = 1.0
	fv.value = GameOptions.fov
	fv.custom_minimum_size = Vector2(170, 24)
	fv.value_changed.connect(func(v: float) -> void:
		GameOptions.fov = v
		GameOptions.save())
	fov_row.add_child(fv)


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
	box.offset_top = -120
	box.offset_bottom = 120
	box.add_theme_constant_override("separation", 10)
	_death_title = _label(box, "ВЫ ПОГИБЛИ", 36, Color("#d8b0a0"))
	_death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_sub = _label(box, "", 15, C_DIM)
	_death_sub.name = "Sub"
	_death_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := Button.new()
	b.text = "Начать заново"
	b.pressed.connect(func() -> void:
		get_tree().paused = false
		GameTime.time_scale = 1.0
		get_tree().reload_current_scene())
	box.add_child(b)
	var b2 := Button.new()
	b2.text = "Выйти в меню версий"
	b2.pressed.connect(_to_menu)
	box.add_child(b2)


func _build_sleep_overlay() -> void:
	_sleep_overlay = ColorRect.new()
	_sleep_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sleep_overlay.color = Color(0.02, 0.02, 0.04, 0.0)
	_sleep_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sleep_overlay.visible = false
	add_child(_sleep_overlay)
	_sleep_label = Label.new()
	_sleep_label.set_anchors_preset(Control.PRESET_CENTER)
	_sleep_label.offset_left = -300
	_sleep_label.offset_right = 300
	_sleep_label.offset_top = -40
	_sleep_label.offset_bottom = 40
	_sleep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sleep_label.add_theme_font_size_override("font_size", 22)
	_sleep_label.add_theme_color_override("font_color", C_TEXT)
	_sleep_overlay.add_child(_sleep_label)


## Darkened screen edges when exhausted, sleepy, hurt or freezing.
func _vignette_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
void fragment() {
	vec2 d = UV - 0.5;
	float v = smoothstep(0.25, 0.75, length(d * vec2(1.2, 1.0)));
	COLOR = vec4(tint.rgb, v * strength);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _save_game() -> void:
	if player == null or player.state == Player.State.DEAD:
		return
	var world := player.get_parent() as Node3D
	if SaveGame.save(world):
		_on_toast("Игра сохранена: день %d, %s." % [GameTime.get_day(), GameTime.get_clock_text()])
	else:
		_on_toast("Не удалось сохранить игру.")


# ------------------------------------------------------------------------------------------------ runtime
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _inventory.visible:
			return
		if _map.visible:
			_map.visible = false
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and not get_tree().paused:
		_map.visible = not _map.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("health") and not get_tree().paused:
		_health_panel.call("toggle")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("admin"):
		_admin.call("toggle")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skills") and not get_tree().paused:
		_skills.visible = not _skills.visible
		_refresh_skills()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F1:
		_help.visible = not _help.visible


func _to_menu() -> void:
	get_tree().paused = false
	Sfx.stop_ambient()
	get_tree().change_scene_to_file("res://launcher/main_menu.tscn")


func _toggle_pause() -> void:
	if _death.visible:
		return
	get_tree().paused = not get_tree().paused
	_pause.visible = get_tree().paused


func _process(delta: float) -> void:
	if player == null:
		return
	var day := GameTime.get_day()
	_clock.text = GameTime.get_clock_text()
	_date.text = "День %d · %s, %d сентября" % [day, WEEKDAYS[(day + 2) % 7], 8 + day]
	_update_weather()
	_bars["health"].value = player.health.ratio()
	_bars["endurance"].value = player.stats.endurance
	_bars["fatigue"].value = player.stats.fatigue
	_bars["drowsy"].value = player.stats.drowsiness
	_bars["hunger"].value = player.stats.hunger
	_bars["thirst"].value = player.stats.thirst
	var bt := player.body_temp
	_temp_label.text = "%.1f °C%s" % [bt.temp, "  · мокрый" if bt.wetness > 0.3 else ""]
	_temp_label.add_theme_color_override("font_color", Color("#7aa8d8") if bt.temp < 36.1 else (Color("#d8785a") if bt.temp > 37.3 else C_TEXT))
	_update_sleep(delta)
	var vig := 0.0
	vig = maxf(vig, (player.stats.drowsiness - 0.75) * 2.4)
	vig = maxf(vig, (0.35 - player.health.ratio()) * 2.0)
	vig = maxf(vig, (35.6 - bt.temp) * 0.6)
	vig = maxf(vig, player.stats.panic * 0.5)
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", clampf(vig, 0.0, 0.85))
	(_vignette.material as ShaderMaterial).set_shader_parameter("tint",
		Color(0.25, 0.0, 0.0) if player.health.ratio() < 0.35 else (Color(0.1, 0.16, 0.25) if bt.temp < 35.6 else Color(0, 0, 0)))
	_flash.color.a = maxf(_flash.color.a - delta * 0.9, 0.0)
	_update_weapon()
	_update_action()
	_update_crosshair()
	_status_panel.modulate.a = 1.0
	var mode := "Бег" if player.running else ("Крадётесь" if player.crouching else "Шаг")
	if player.state == Player.State.SEATED:
		mode = "Сон" if player.is_sleeping() else "Отдых"
	elif player.state == Player.State.DRIVING:
		mode = "За рулём"
	_mode_label.text = mode
	_update_moodles()
	_update_prompt()
	_update_car()
	if _skills.visible and Engine.get_process_frames() % 30 == 0:
		_refresh_skills()
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
		want.append(["Хочется спать" if player.stats.drowsiness < 0.85 else "Засыпаете на ходу", Color("#5a78a8")])
	if player.stats.panic > 0.25:
		want.append(["Страх" if player.stats.panic < 0.6 else "Паника", Color("#c8c050")])
	if player.stats.poison > 0.05:
		want.append(["Отравление", Color("#8aa03a")])
	if player.wounds.has_festering():
		want.append(["Воспаление", Color("#b86a3a")])
	var ts := player.body_temp.state_name()
	if ts != "":
		want.append([ts, Color("#7aa8d8") if player.body_temp.temp < 36.6 else Color("#d8785a")])
	if player.body_temp.wetness > 0.3:
		want.append(["Промокли" if player.body_temp.wetness < 0.8 else "Насквозь мокрый", Color("#5a8ab0")])
	if player.health.ratio() < 0.6:
		want.append(["Ранены", Color("#a8403a")])
	if player.wounds.is_bleeding():
		want.append(["Кровотечение", Color("#d0302a")])
	if player.wounds.pain() > 0.25:
		want.append(["Боль", Color("#c86a4a")])
	var sym := player.wounds.symptoms()
	if sym != "":
		want.append([sym, Color("#7aa04a")])
	if player.stats.hunger > 0.6:
		want.append(["Голод" if player.stats.hunger < 0.85 else "Истощение", Color("#a8843a")])
	if player.stats.thirst > 0.6:
		want.append(["Жажда" if player.stats.thirst < 0.85 else "Обезвоживание", Color("#4a8ab0")])
	if player.inventory.load_ratio() > 1.0:
		want.append(["Перегруз", Color("#9a8a6a")])
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


func _build_weapon_panel() -> void:
	_weapon_panel = _panel(self)
	_weapon_panel.anchor_left = 0.5
	_weapon_panel.anchor_right = 0.5
	_weapon_panel.anchor_top = 1.0
	_weapon_panel.anchor_bottom = 1.0
	_weapon_panel.offset_left = -150
	_weapon_panel.offset_right = 150
	_weapon_panel.offset_top = -72
	_weapon_panel.offset_bottom = -10
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_weapon_panel.add_child(h)
	_weapon_icon = TextureRect.new()
	_weapon_icon.custom_minimum_size = Vector2(44, 44)
	_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(_weapon_icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_weapon_label = _label(v, "Голые руки", 16)
	_weapon_bar = ProgressBar.new()
	_weapon_bar.custom_minimum_size = Vector2(150, 8)
	_weapon_bar.show_percentage = false
	_weapon_bar.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.14, 0.12)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("#8aa060")
	_weapon_bar.add_theme_stylebox_override("background", bg)
	_weapon_bar.add_theme_stylebox_override("fill", fg)
	v.add_child(_weapon_bar)


func _update_weapon() -> void:
	var w := player.inventory.weapon()
	if w == null:
		_weapon_icon.texture = null
		_weapon_label.text = "Голые руки (толчок)"
		_weapon_bar.visible = false
		return
	_weapon_icon.texture = w.item.icon
	var extra := ""
	if w.item.magazine > 0:
		extra = "   %d/%d  (+%d)" % [w.loaded, w.item.magazine, player.inventory.main.count_of(w.item.ammo_id)]
	_weapon_label.text = w.get_name() + extra
	_weapon_bar.visible = w.item.max_durability > 0.0
	_weapon_bar.value = w.durability / maxf(w.item.max_durability, 1.0)


func _build_action_panel() -> void:
	_action_panel = _panel(self)
	_action_panel.visible = false
	var v := VBoxContainer.new()
	_action_panel.add_child(v)
	_action_label = _label(v, "", 13)
	_action_bar = ProgressBar.new()
	_action_bar.custom_minimum_size = Vector2(180, 8)
	_action_bar.show_percentage = false
	_action_bar.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.14, 0.12)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("#c8a860")
	_action_bar.add_theme_stylebox_override("background", bg)
	_action_bar.add_theme_stylebox_override("fill", fg)
	v.add_child(_action_bar)


func _update_action() -> void:
	var p := player.action_progress()
	if p < 0.0 or player.camera == null:
		_action_panel.visible = false
		return
	_action_panel.visible = true
	_action_label.text = player.action_label()
	_action_bar.value = p
	var view := get_node("../../GameView") as SubViewportContainer
	var sp := UiTheme.to_ui(player.camera.unproject_position(player.global_position + Vector3.UP * 2.1) * float(view.stretch_shrink))
	if player.fp_active():
		sp = size * 0.5 + Vector2(0, 92)
	_action_panel.reset_size()
	_action_panel.position = (sp - Vector2(_action_panel.size.x * 0.5, _action_panel.size.y)).round()


func _update_prompt() -> void:
	var it := player.interactor.focused
	if _inventory.visible or not player.action_label().is_empty():
		_prompt.visible = false
		return
	if it == null or player.camera == null or player.state != Player.State.NORMAL:
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
	var sp := UiTheme.to_ui(player.camera.unproject_position(fp) * float(view.stretch_shrink))
	if player.fp_active():
		sp = size * 0.5 + Vector2(0, 100)
	var more := "   ПКМ: ещё" if actions.size() > 1 else ""
	_prompt_label.text = "[E] %s%s" % [actions[0]["label"], more]
	_prompt.visible = true
	_prompt.reset_size()
	_prompt.position = (sp + Vector2(-_prompt.size.x * 0.5, -54)).round()


func _on_toast(text: String) -> void:
	var p := _panel(_toasts)
	_label(p, text, 17)
	p.set_meta("life", 4.5)
	while _toasts.get_child_count() > 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()


func _on_context_menu(target: Node, actions: Array) -> void:
	_menu.clear()
	_menu_target = target as Interactable
	_menu_actions = actions
	_menu.add_separator((target as Interactable).display_name)
	for i in actions.size():
		_menu.add_item(actions[i]["label"], i)
	_menu.reset_size()
	_menu.position = Vector2i(get_viewport().get_mouse_position()) + Vector2i(4, 4)
	if player and player.fp_active():
		_menu.position = Vector2i(get_viewport().get_visible_rect().size * 0.5) + Vector2i(18, 12)
	_menu.popup()


func _on_location(building: Node, level: int) -> void:
	if building == null:
		_location.text = "Улица"
	else:
		var b := building as Building
		_location.text = "%s%s" % [b.display_name, (", %d этаж" % (level + 1)) if b.levels.size() > 1 else ""]


func _on_container_opened(_container: Node) -> void:
	pass


func _update_weather() -> void:
	var c := Climate.instance
	if c == null:
		_weather.text = ""
		return
	var sky := "Ясно"
	if c.rain > 0.7:
		sky = "Ливень"
	elif c.rain > 0.05:
		sky = "Дождь"
	elif DayNight.night > 0.5:
		sky = "Ночь"
	_weather.text = "%+d °C · %s" % [roundi(c.outside_temp()), sky]
	var off: Array[String] = []
	if not c.power_on():
		off.append("света")
	if not c.water_on():
		off.append("воды")
	if not c.gas_on():
		off.append("газа")
	_utilities.visible = not off.is_empty()
	_utilities.text = "Нет " + ", ".join(off)


func _update_sleep(delta: float) -> void:
	var sleeping := player.is_sleeping()
	if sleeping:
		_sleep_overlay.visible = true
		_sleep_overlay.color.a = minf(_sleep_overlay.color.a + delta * 1.5, 0.88)
		_sleep_label.text = "Сон...  %s\n\n[E] — проснуться" % GameTime.get_clock_text()
	elif _sleep_overlay.visible:
		_sleep_overlay.color.a = maxf(_sleep_overlay.color.a - delta * 2.5, 0.0)
		_sleep_label.text = ""
		if _sleep_overlay.color.a <= 0.0:
			_sleep_overlay.visible = false


func _on_player_died() -> void:
	SaveGame.delete()
	var turned := player.wounds.infected
	if turned:
		await player.reanimated
	else:
		await get_tree().create_timer(1.5).timeout
	_death.visible = true
	_death_title.text = "ВЫ ОБРАТИЛИСЬ" if turned else "ВЫ ПОГИБЛИ"
	var hours := GameTime.total_minutes / 60.0 - GameTime.START_HOUR
	var cause := "Зомби-вирус" if turned else (player.health.last_cause if player.health.last_cause != "" else "Неизвестно")
	_death_sub.text = "Причина: %s\nПрожито: %d дн. %d ч.   Убито зомби: %d" % [cause, int(hours / 24.0), int(fmod(hours, 24.0)), player.kills]


# ------------------------------------------------------------------------------------------------ car, skills
func _build_car_panel() -> void:
	_car_panel = _panel(self)
	_car_panel.anchor_left = 0.5
	_car_panel.anchor_right = 0.5
	_car_panel.anchor_top = 1.0
	_car_panel.anchor_bottom = 1.0
	_car_panel.offset_left = -200
	_car_panel.offset_right = 200
	_car_panel.offset_top = -230
	_car_panel.offset_bottom = -196
	_car_panel.visible = false
	var v := VBoxContainer.new()
	_car_panel.add_child(v)
	_car_label = _label(v, "", 15)
	_car_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_car_bar = UiTheme.bar(Color("#c8a040"), 380.0, 8.0)
	v.add_child(_car_bar)


func _update_car() -> void:
	var v := player.vehicle
	_car_panel.visible = v != null
	if v == null:
		return
	var state := "двигатель заглушен — [R] завести без ключа" if not v.engine_on else ("фары вкл" if v.headlights else "фары выкл")
	_car_label.text = "%s · %d км/ч · бензин %d/%d л · состояние %d%% · %s" % [v.display_name, v.kmh(), roundi(v.fuel),
		roundi(Vehicle.FUEL_MAX), roundi(v.health), state]
	_car_bar.value = v.fuel / Vehicle.FUEL_MAX


func _build_skills() -> void:
	_skills = _panel(self)
	_skills.mouse_filter = Control.MOUSE_FILTER_STOP
	_skills.anchor_left = 0.5
	_skills.anchor_right = 0.5
	_skills.anchor_top = 0.5
	_skills.anchor_bottom = 0.5
	_skills.offset_left = -230
	_skills.offset_right = 230
	_skills.offset_top = -210
	_skills.offset_bottom = 210
	_skills.visible = false
	_skills_box = VBoxContainer.new()
	_skills_box.add_theme_constant_override("separation", 5)
	_skills.add_child(_skills_box)


func _refresh_skills() -> void:
	if player == null:
		return
	for c in _skills_box.get_children():
		c.queue_free()
	var prof: Dictionary = Profession.LIST.get(Settings.profession, Profession.LIST["unemployed"])
	var t := _label(_skills_box, "%s — %s" % [Settings.char_name, prof["name"]], 20, UiTheme.TEXT)
	t.add_theme_font_override("font", UiTheme.font(true))
	var trait_names: Array[String] = []
	for id in Settings.traits:
		trait_names.append(Profession.TRAITS[id][0])
	_label(_skills_box, "Черты: " + (", ".join(trait_names) if not trait_names.is_empty() else "нет"), 13, C_DIM)
	_label(_skills_box, "Навыки растут от дела (K — закрыть)", 13, UiTheme.ACCENT)
	for id in Skills.NAMES:
		var row := HBoxContainer.new()
		_skills_box.add_child(row)
		var l := _label(row, "%s" % Skills.NAMES[id], 15)
		l.custom_minimum_size = Vector2(170, 0)
		var lv := Skills.level_of(player, id)
		var pips := _label(row, "■".repeat(lv) + "□".repeat(Skills.MAX_LEVEL - lv), 13, UiTheme.ACCENT if lv > 0 else C_DIM)
		pips.custom_minimum_size = Vector2(150, 0)
		var b := UiTheme.bar(Color("#8a9a6a"), 80.0, 6.0)
		b.value = Skills.progress(player, id)
		row.add_child(b)


## First person: any window that needs the cursor releases the mouse.
func wants_mouse() -> bool:
	return (_inventory != null and _inventory.visible) or (_map != null and _map.visible) \
		or (_health_panel != null and _health_panel.visible) or (_admin != null and _admin.visible) \
		or (_skills != null and _skills.visible) or (_menu != null and _menu.visible) \
		or (_pause != null and _pause.visible) or (_death != null and _death.visible)


func _update_crosshair() -> void:
	var on := player.fp_active() and player.state == Player.State.NORMAL and not wants_mouse() \
		and player.action_label().is_empty()
	_crosshair.visible = on
	if not on:
		return
	var spd := Vector2(player.velocity.x, player.velocity.z).length()
	var w := player.inventory.weapon()
	var target := 5.0 + spd * 2.2 + (6.0 if player.running and spd > 3.0 else 0.0)
	if w and w.item.attack_style == "shoot":
		target += 4.0
		if player.combat.is_attacking():
			target += 12.0
	_crosshair.spread = lerpf(_crosshair.spread, target, 0.25)
	_crosshair.focus = player.interactor.focused != null
	_crosshair.aiming = player.fp.aiming
