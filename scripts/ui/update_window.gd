class_name UpdateWindow
extends CanvasLayer
## Minimal, smooth Russian-language modal window for the Auto Hot Update System.
## Designed for zero GC / FPS overhead: updates text only when integer percentage changes.

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
var _auto_hide_timer: SceneTreeTimer


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
	_backdrop.color = Color(0.02, 0.02, 0.02, 0.82)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(540, 320)
	_card.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.05, 0.05, 0.045, 0.96), true, 28))
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
	_ver_lbl.text = "Версия: 0.5.1"
	_ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ver_lbl.add_theme_font_size_override("font_size", 18)
	_ver_lbl.add_theme_color_override("font_color", UiTheme.TEXT)
	vbox.add_child(_ver_lbl)

	_notes_lbl = Label.new()
	_notes_lbl.text = ""
	_notes_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notes_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes_lbl.custom_minimum_size = Vector2(460, 0)
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
	_prog_bar.custom_minimum_size = Vector2(460, 14)
	_prog_bar.max_value = 100.0
	_prog_bar.value = 0.0
	_prog_bar.show_percentage = false
	vbox.add_child(_prog_bar)

	_wait_lbl = Label.new()
	_wait_lbl.text = "Пожалуйста, подождите..."
	_wait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wait_lbl.custom_minimum_size = Vector2(460, 0)
	_wait_lbl.add_theme_font_size_override("font_size", 16)
	_wait_lbl.add_theme_color_override("font_color", UiTheme.DIM)
	vbox.add_child(_wait_lbl)

	_close_btn = Button.new()
	_close_btn.text = "Продолжить"
	_close_btn.custom_minimum_size = Vector2(220, 40)
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


func show_update_start(manifest: Dictionary) -> void:
	var ver := str(manifest.get("version", "0.5.x"))
	var notes := str(manifest.get("changelog", manifest.get("release_notes", ""))).strip_edges()
	_badge_lbl.text = "НОВОЕ ОБНОВЛЕНИЕ"
	_badge_lbl.add_theme_color_override("font_color", UiTheme.ACCENT)
	_ver_lbl.text = "Версия: %s" % ver
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
	if not visible:
		visible = true
		_card.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_card, "modulate:a", 1.0, 0.2)
	set_process(true)


func set_progress(pct: float, _downloaded_bytes: int, _total_bytes: int, ver: String) -> void:
	if not visible:
		show_update_start({"version": ver})
	_ver_lbl.text = "Версия: %s" % ver
	_target_pct = clampf(pct, 0.0, 100.0)
	set_process(true)


func show_completed(applied: bool, ver: String, message: String) -> void:
	if not visible and not applied:
		return
	set_process(false)
	if applied:
		_target_pct = 100.0
		_display_pct = 100.0
		_prog_bar.value = 100.0
		_status_lbl.text = "Загрузка обновления: 100%"
		_ascii_bar_lbl.text = _format_block_bar(100, 18)
		_wait_lbl.text = message
		_close_btn.visible = true
		_auto_hide_timer = get_tree().create_timer(1.6)
		_auto_hide_timer.timeout.connect(hide_window)
	else:
		_status_lbl.text = "Обновление отменено"
		_wait_lbl.text = message
		_close_btn.visible = true


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
	_close_btn.visible = true
	visible = true
	set_process(false)


func hide_window() -> void:
	if not visible:
		return
	set_process(false)
	visible = false
