class_name UpdateWindow
extends CanvasLayer
## Minimal, smooth Russian-language modal window for the Auto Hot Update System.
## Stays visible on completion ("Обновление успешно установлено") or error until the user closes it.

var _backdrop: ColorRect
var _card: PanelContainer
var _title_lbl: Label
var _badge_lbl: Label
var _ver_lbl: Label
var _notes_lbl: Label
var _status_lbl: Label
var _ascii_bar_lbl: Label
var _prog_bar: ProgressBar
var _wait_lbl: Label
var _close_btn: Button

var _last_pct_int := -1
var _target_pct := 0.0
var _display_pct := 0.0


func _init() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_build_ui()
	set_process(false)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.theme()
	add_child(root)

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.02, 0.02, 0.84)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(560, 340)
	_card.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.05, 0.05, 0.045, 0.97), true, 28))
	center.add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_card.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.text = "RUSSIAN ZOMBIE SURVIVAL"
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_override("font", UiTheme.font(true))
	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
	vbox.add_child(_title_lbl)

	var accent_line := ColorRect.new()
	accent_line.color = UiTheme.ACCENT
	accent_line.custom_minimum_size = Vector2(0, 3)
	vbox.add_child(accent_line)

	_badge_lbl = Label.new()
	_badge_lbl.text = "НОВОЕ ОБНОВЛЕНИЕ"
	_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_lbl.add_theme_font_override("font", UiTheme.font(true))
	_badge_lbl.add_theme_font_size_override("font_size", 20)
	_badge_lbl.add_theme_color_override("font_color", UiTheme.ACCENT)
	vbox.add_child(_badge_lbl)

	_ver_lbl = Label.new()
	_ver_lbl.text = "Версия: 0.5.1 (сборка #500)"
	_ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ver_lbl.add_theme_font_size_override("font_size", 18)
	_ver_lbl.add_theme_color_override("font_color", UiTheme.TEXT)
	vbox.add_child(_ver_lbl)

	_notes_lbl = Label.new()
	_notes_lbl.text = ""
	_notes_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notes_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes_lbl.custom_minimum_size = Vector2(480, 0)
	_notes_lbl.add_theme_font_size_override("font_size", 14)
	_notes_lbl.add_theme_color_override("font_color", UiTheme.DIM)
	_notes_lbl.visible = false
	vbox.add_child(_notes_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	_status_lbl = Label.new()
	_status_lbl.text = "Загрузка обновления: 0%"
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.custom_minimum_size = Vector2(480, 0)
	_status_lbl.add_theme_font_size_override("font_size", 18)
	_status_lbl.add_theme_color_override("font_color", UiTheme.TEXT)
	vbox.add_child(_status_lbl)

	_ascii_bar_lbl = Label.new()
	_ascii_bar_lbl.text = "[░░░░░░░░░░░░░░░░░░]"
	_ascii_bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ascii_bar_lbl.add_theme_font_override("font", UiTheme.font(true))
	_ascii_bar_lbl.add_theme_font_size_override("font_size", 20)
	_ascii_bar_lbl.add_theme_color_override("font_color", UiTheme.ACCENT)
	vbox.add_child(_ascii_bar_lbl)

	_prog_bar = ProgressBar.new()
	_prog_bar.custom_minimum_size = Vector2(480, 14)
	_prog_bar.max_value = 100.0
	_prog_bar.value = 0.0
	_prog_bar.show_percentage = false
	vbox.add_child(_prog_bar)

	_wait_lbl = Label.new()
	_wait_lbl.text = "Пожалуйста, подождите..."
	_wait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wait_lbl.custom_minimum_size = Vector2(480, 0)
	_wait_lbl.add_theme_font_size_override("font_size", 16)
	_wait_lbl.add_theme_color_override("font_color", UiTheme.DIM)
	vbox.add_child(_wait_lbl)

	_close_btn = Button.new()
	_close_btn.text = "Продолжить"
	_close_btn.custom_minimum_size = Vector2(240, 44)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_btn.visible = false
	_close_btn.pressed.connect(hide_window)
	vbox.add_child(_close_btn)


func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	_display_pct = move_toward(_display_pct, _target_pct, delta * 180.0)
	_prog_bar.value = _display_pct
	var pct_int := clampi(int(round(_display_pct)), 0, 100)
	if pct_int != _last_pct_int:
		_last_pct_int = pct_int
		_status_lbl.text = "Загрузка обновления: %d%%" % pct_int
		_ascii_bar_lbl.text = _format_block_bar(pct_int, 18)


func _format_block_bar(pct_int: int, total_blocks: int) -> String:
	var filled := clampi(int(round(float(pct_int) / 100.0 * float(total_blocks))), 0, total_blocks)
	var empty := total_blocks - filled
	return "[" + "█".repeat(filled) + "░".repeat(empty) + "]"


func _open_modal() -> void:
	if not visible:
		visible = true
		_card.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_card, "modulate:a", 1.0, 0.2)


func show_checking(cur_ver: String, cur_build: int) -> void:
	_badge_lbl.text = "ПРОВЕРКА ОБНОВЛЕНИЙ"
	_badge_lbl.add_theme_color_override("font_color", UiTheme.ACCENT)
	_ver_lbl.text = "Текущая версия: v%s (сборка #%d)" % [cur_ver, cur_build]
	_notes_lbl.visible = false
	_prog_bar.visible = false
	_ascii_bar_lbl.visible = false
	_status_lbl.text = "Подключение к серверу GitHub..."
	_wait_lbl.text = "Пожалуйста, подождите..."
	_close_btn.visible = false
	_open_modal()
	set_process(false)


func show_up_to_date(cur_ver: String, cur_build: int) -> void:
	_badge_lbl.text = "ОБНОВЛЕНИЙ НЕТ"
	_badge_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.58))
	_ver_lbl.text = "Версия: v%s (сборка #%d)" % [cur_ver, cur_build]
	_notes_lbl.visible = false
	_prog_bar.visible = false
	_ascii_bar_lbl.visible = false
	_status_lbl.text = "Установлена последняя версия"
	_wait_lbl.text = "Все ресурсы и скрипты актуальны."
	_close_btn.text = "Закрыть"
	_close_btn.visible = true
	_open_modal()
	set_process(false)


func show_update_start(manifest: Dictionary) -> void:
	var ver := str(manifest.get("version", "0.5.x"))
	var bld := int(manifest.get("build_number", 0))
	var notes := str(manifest.get("changelog", manifest.get("release_notes", ""))).strip_edges()
	_badge_lbl.text = "НОВОЕ ОБНОВЛЕНИЕ"
	_badge_lbl.add_theme_color_override("font_color", UiTheme.ACCENT)
	_ver_lbl.text = "Версия: %s" % ver if bld <= 0 else "Версия: %s (сборка #%d)" % [ver, bld]
	if notes != "":
		_notes_lbl.text = notes
		_notes_lbl.visible = true
	else:
		_notes_lbl.visible = false
	_last_pct_int = -1
	_target_pct = 0.0
	_display_pct = 0.0
	_prog_bar.visible = true
	_ascii_bar_lbl.visible = true
	_status_lbl.text = "Загрузка обновления: 0%"
	_ascii_bar_lbl.text = _format_block_bar(0, 18)
	_wait_lbl.text = "Пожалуйста, подождите..."
	_close_btn.visible = false
	_open_modal()
	set_process(true)


func set_progress(pct: float, _downloaded_bytes: int, _total_bytes: int, ver: String) -> void:
	if not visible:
		show_update_start({"version": ver})
	_target_pct = clampf(pct, 0.0, 100.0)
	set_process(true)


func show_completed(applied: bool, ver: String, message: String, is_manual := false) -> void:
	set_process(false)
	if applied:
		_badge_lbl.text = "ОБНОВЛЕНИЕ ЗАВЕРШЕНО"
		_badge_lbl.add_theme_color_override("font_color", Color(0.55, 0.88, 0.55))
		_ver_lbl.text = "Версия: %s" % ver
		_target_pct = 100.0
		_display_pct = 100.0
		_prog_bar.visible = true
		_ascii_bar_lbl.visible = true
		_prog_bar.value = 100.0
		_status_lbl.text = "Обновление успешно установлено"
		_ascii_bar_lbl.text = _format_block_bar(100, 18)
		_wait_lbl.text = message
		_close_btn.text = "Продолжить"
		_close_btn.visible = true
		_open_modal()
	elif is_manual or visible:
		_badge_lbl.text = "ОШИБКА ОБНОВЛЕНИЯ"
		_badge_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.28))
		_prog_bar.visible = false
		_ascii_bar_lbl.visible = false
		_status_lbl.text = "Не удалось обновить игру"
		_wait_lbl.text = message
		_close_btn.text = "Закрыть"
		_close_btn.visible = true
		_open_modal()


func show_apk_required(manifest: Dictionary, message: String) -> void:
	var ver := str(manifest.get("version", "0.5.x"))
	var reason := str(manifest.get("apk_update_reason", "")).strip_edges()
	_badge_lbl.text = "ТРЕБУЕТСЯ ОБНОВЛЕНИЕ APK"
	_badge_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.28))
	_ver_lbl.text = "Версия: %s" % ver
	_prog_bar.visible = false
	_ascii_bar_lbl.visible = false
	_status_lbl.text = message
	_wait_lbl.text = reason if reason != "" else "Изменились нативные компоненты Android или движка. Установите новый APK."
	_close_btn.text = "Закрыть"
	_close_btn.visible = true
	_open_modal()
	set_process(false)


func hide_window() -> void:
	if not visible:
		return
	set_process(false)
	visible = false
