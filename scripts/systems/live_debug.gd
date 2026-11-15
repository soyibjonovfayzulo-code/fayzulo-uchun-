extends Node
## Live Debug & Interaction Profiler for Android / PC (Autoload: LiveDebug).
## 1. Registers custom Godot Editor Profiler monitors (visible in Debugger -> Monitors).
## 2. Captures exact CPU & frame-time spikes when opening Doors, Windows, and Crates.
## 3. Watches user://live_sync/ for script/scene/PCK updates pushed over USB/Wi-Fi ADB
##    and hot-reloads them (with automatic state save & scene reload when required) without rebuilding the APK.
## 4. Provides an on-screen telemetry & interaction profiler overlay (F3 or "Профайл" button).

signal interaction_profiled(kind: String, label: String, cpu_ms: float, frame_ms: float)

const SYNC_DIR := "user://live_sync"
const SYNC_MANIFEST := "user://live_sync/sync_manifest.json"

var overlay_visible := false
var fps := 60.0
var frame_time_ms := 16.6
var worst_frame_ms := 16.6
var physics_time_ms := 1.0
var last_interaction_ms := 0.0
var last_door_ms := 0.0
var last_window_ms := 0.0
var last_crate_ms := 0.0
var stutter_count := 0
var interaction_log: Array[Dictionary] = []

var _frame_window: Array[float] = []
var _last_usec := 0
var _sync_timer := 0.0
var _last_sync_stamp := ""
var _canvas: CanvasLayer
var _panel: PanelContainer
var _stats_label: Label
var _log_label: Label
var _sync_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_usec = Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SYNC_DIR))
	_register_custom_monitors()
	_register_debugger_capture()
	_build_overlay()
	var args := OS.get_cmdline_user_args()
	if "--profiler-hud" in args:
		set_overlay_visible(true)


func _register_custom_monitors() -> void:
	if not Performance.has_custom_monitor("RZS/FrameTimeMs"):
		Performance.add_custom_monitor("RZS/FrameTimeMs", func() -> float: return frame_time_ms)
	if not Performance.has_custom_monitor("RZS/WorstFrameMs"):
		Performance.add_custom_monitor("RZS/WorstFrameMs", func() -> float: return worst_frame_ms)
	if not Performance.has_custom_monitor("RZS/InteractionSpikeMs"):
		Performance.add_custom_monitor("RZS/InteractionSpikeMs", func() -> float: return last_interaction_ms)
	if not Performance.has_custom_monitor("RZS/DoorOpenMs"):
		Performance.add_custom_monitor("RZS/DoorOpenMs", func() -> float: return last_door_ms)
	if not Performance.has_custom_monitor("RZS/WindowOpenMs"):
		Performance.add_custom_monitor("RZS/WindowOpenMs", func() -> float: return last_window_ms)
	if not Performance.has_custom_monitor("RZS/CrateOpenMs"):
		Performance.add_custom_monitor("RZS/CrateOpenMs", func() -> float: return last_crate_ms)
	if not Performance.has_custom_monitor("RZS/StutterCount"):
		Performance.add_custom_monitor("RZS/StutterCount", func() -> int: return stutter_count)


func _register_debugger_capture() -> void:
	if EngineDebugger.is_active():
		EngineDebugger.register_message_capture("rzs", _on_debugger_message)


func _on_debugger_message(message: String, data: Array) -> bool:
	match message:
		"reload_script":
			if not data.is_empty():
				reload_script_path(str(data[0]), data.size() > 1 and bool(data[1]))
			return true
		"reload_scene":
			hot_restart_current_scene("Remote Debugger: перезапуск сцены")
			return true
		"toggle_profiler":
			toggle_overlay()
			return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_F3 or ke.physical_keycode == KEY_F3:
			toggle_overlay()
		elif ke.keycode == KEY_F4 or ke.physical_keycode == KEY_F4:
			hot_restart_current_scene("Быстрый перезапуск (F4)")


func toggle_overlay() -> void:
	set_overlay_visible(not overlay_visible)


func set_overlay_visible(v: bool) -> void:
	overlay_visible = v
	if _panel:
		_panel.visible = v
	if v:
		_refresh_overlay_text()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt_ms := (now - _last_usec) / 1000.0
	_last_usec = now
	frame_time_ms = clampf(dt_ms, 0.1, 1000.0)
	fps = Engine.get_frames_per_second()
	physics_time_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_frame_window.append(frame_time_ms)
	if _frame_window.size() > 120:
		_frame_window.pop_front()
	var w := 0.0
	for f in _frame_window:
		if f > w:
			w = f
	worst_frame_ms = w
	if frame_time_ms > 33.4:
		stutter_count += 1
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 1.0
		_check_live_sync()
		if overlay_visible:
			_refresh_overlay_text()


## Records the exact CPU execution time and subsequent frame time of opening a door, window, or crate.
func record_interaction(kind: String, label: String, start_usec: int) -> void:
	var cpu_ms := (Time.get_ticks_usec() - start_usec) / 1000.0
	last_interaction_ms = cpu_ms
	match kind:
		"door":
			last_door_ms = cpu_ms
		"window":
			last_window_ms = cpu_ms
		"crate":
			last_crate_ms = cpu_ms
	var entry := {
		"time": Time.get_time_string_from_system(),
		"kind": kind,
		"label": label,
		"cpu_ms": cpu_ms,
		"frame_ms": frame_time_ms,
	}
	interaction_log.push_front(entry)
	if interaction_log.size() > 8:
		interaction_log.pop_back()
	if EngineDebugger.is_active():
		EngineDebugger.send_message("rzs:interaction", [kind, label, cpu_ms, frame_time_ms])
	interaction_profiled.emit(kind, label, cpu_ms, frame_time_ms)
	if overlay_visible:
		_refresh_overlay_text()


## Checks if `tools/android_live_debug.ps1` pushed updated scripts/scenes/PCK to `user://live_sync/`.
func _check_live_sync() -> void:
	if not FileAccess.file_exists(SYNC_MANIFEST):
		return
	var raw := FileAccess.get_file_as_string(SYNC_MANIFEST)
	if raw == "" or raw == _last_sync_stamp:
		return
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d := parsed as Dictionary
	var stamp := str(d.get("timestamp", ""))
	if stamp == "" or stamp == _last_sync_stamp:
		return
	if _last_sync_stamp == "":
		# First read on boot: apply any live_patch.pck silently and remember stamp.
		_last_sync_stamp = stamp
		var init_pck := str(d.get("pck_file", ""))
		if init_pck != "" and FileAccess.file_exists(SYNC_DIR + "/" + init_pck):
			ProjectSettings.load_resource_pack(SYNC_DIR + "/" + init_pck, true)
		return
	_last_sync_stamp = stamp
	var pck_file := str(d.get("pck_file", ""))
	if pck_file != "":
		var pck_path := SYNC_DIR + "/" + pck_file
		if FileAccess.file_exists(pck_path):
			ProjectSettings.load_resource_pack(pck_path, true)
	var scripts: Array = d.get("scripts", [])
	for s in scripts:
		reload_script_path(str(s), false)
	var need_restart := bool(d.get("restart_scene", false))
	var msg := "Live Sync: обновлено (%d файл.)" % maxi(scripts.size(), 1)
	if _sync_label:
		_sync_label.text = msg + (" · перезапуск..." if need_restart else "")
	Events.show_toast(msg)
	if need_restart:
		hot_restart_current_scene(msg)


func reload_script_path(res_path: String, restart_scene := false) -> bool:
	if not res_path.begins_with("res://"):
		res_path = "res://" + res_path.trim_prefix("/")
	if not ResourceLoader.exists(res_path):
		return false
	var res := ResourceLoader.load(res_path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
	var ok := res != null
	if ok and restart_scene:
		hot_restart_current_scene("Скрипт обновлён: " + res_path.get_file())
	return ok


## Saves the player's current world state (if in-game) and reloads the active scene seamlessly.
func hot_restart_current_scene(reason := "Перезапуск сцены") -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var player := tree.get_first_node_in_group("player")
	if player and player.get_parent() and player.get_parent().name == "World":
		var world := player.get_parent() as Node3D
		if SaveGame.save(world):
			Settings.load_save = true
	Events.show_toast(reason)
	tree.reload_current_scene.call_deferred()


func _build_overlay() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 120
	_canvas.name = "LiveDebugOverlay"
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.visible = overlay_visible
	_panel.position = Vector2(16, 86)
	_panel.custom_minimum_size = Vector2(410, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.06, 0.88)
	sb.border_color = Color(0.35, 0.65, 0.45, 0.9)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", sb)
	_canvas.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "LIVE DEBUG & PROFILER (F3)"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.45, 0.92, 0.58))
	vb.add_child(title)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	vb.add_child(_stats_label)
	_log_label = Label.new()
	_log_label.add_theme_font_size_override("font_size", 12)
	_log_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.88))
	vb.add_child(_log_label)
	_sync_label = Label.new()
	_sync_label.text = "Remote Debug: %s" % ("АКТИВЕН" if EngineDebugger.is_active() else "Автономный режим")
	_sync_label.add_theme_font_size_override("font_size", 12)
	_sync_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.65))
	vb.add_child(_sync_label)


func _refresh_overlay_text() -> void:
	if _stats_label == null:
		return
	var mem_mb := OS.get_static_memory_usage() / (1024.0 * 1024.0)
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_stats_label.text = (
		"FPS: %.0f  |  Кадр: %.2f мс (макс: %.2f мс)  |  Физ: %.2f мс\n" % [fps, frame_time_ms, worst_frame_ms, physics_time_ms]
		+ "RAM: %.1f МБ  |  DrawCalls: %d  |  Объектов: %d  |  Фризов: %d\n" % [mem_mb, draw_calls, objs, stutter_count]
		+ "Дверь: %.2f мс  |  Окно: %.2f мс  |  Ящик: %.2f мс" % [last_door_ms, last_window_ms, last_crate_ms]
	)
	if interaction_log.is_empty():
		_log_label.text = "Журнал взаимодействий: откройте дверь, окно или ящик..."
	else:
		var lines: Array[String] = ["Последние действия (CPU / Кадр):"]
		for e in interaction_log:
			lines.append("• [%s] %s — CPU %.2f мс | кадр %.1f мс" % [e["kind"], e["label"], e["cpu_ms"], e["frame_ms"]])
		_log_label.text = "\n".join(lines)

