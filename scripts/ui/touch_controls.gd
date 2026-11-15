extends Control
## On-screen touch controls for Android / touchscreen devices:
## virtual left joystick ("dvichoq" for walk, run, steer), right-side touch-look (first-person & isometric),
## contextual action buttons (on-foot, seated, driving), and a top quick-bar for HUD windows.

const DEADZONE := 0.10
const SPRINT_RING := 0.85
const MOUSE_FINGER := 99

var hud: Control
var player: Player
var enabled := true
var sprint_lock := false
var aim_lock := false

# Multi-touch tracking by finger index
var _joy_finger := -1
var _joy_base_center := Vector2(138.0, 550.0)
var _joy_center := Vector2(138.0, 550.0)
var _joy_vec := Vector2.ZERO
var _look_finger := -1
var _held_buttons := {} # finger_index -> button_id

# Button definitions rebuilt each frame for current screen size and player state
var _buttons: Array[Dictionary] = []
var _top_buttons: Array[Dictionary] = []
var _test_mode := false


func _ready() -> void:
	name = "TouchControls"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a in ["--autotest", "--tour", "--poses", "--newgame-shot", "--loadcheck", "--m78", "--v04", "--gallery", "--fps", "--fpvm", "--fpgallery", "--probe-admin", "--menu-shot"] or a.begins_with("--shot="):
			_test_mode = true
	if _test_mode:
		enabled = false
		visible = false
		return
	enabled = true
	visible = true
	_sync_size()
	_rebuild_layout()


func set_enabled(on: bool) -> void:
	if _test_mode:
		return
	enabled = on
	visible = on
	if not on:
		_release_all()
	queue_redraw()


func _sync_size() -> void:
	position = Vector2.ZERO
	var vp_sz := get_viewport_rect().size / maxf(GameOptions.ui_scale, 0.5)
	if hud != null and hud.size.x > 100.0 and hud.size.y > 100.0:
		size = hud.size
	elif vp_sz.x > 100.0 and vp_sz.y > 100.0:
		size = vp_sz
	else:
		size = Vector2(1230.0, 692.0)


func _to_local_ui(screen_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_pos


func _to_local_rel(screen_rel: Vector2) -> Vector2:
	var sc := get_global_transform_with_canvas().get_scale()
	return Vector2(screen_rel.x / maxf(absf(sc.x), 0.5), screen_rel.y / maxf(absf(sc.y), 0.5))


func _process(_delta: float) -> void:
	if _test_mode or not enabled:
		return
	_sync_size()
	if player == null and hud != null:
		player = hud.get("player") as Player
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	_rebuild_layout()
	if _is_modal_open() or get_tree().paused:
		_release_gameplay_inputs()
	else:
		_apply_joystick()
	queue_redraw()


func _is_modal_open() -> bool:
	if hud == null:
		return false
	return bool(hud.call("wants_mouse"))


func _has_closable_panel() -> bool:
	if hud == null:
		return false
	for prop in ["_inventory", "_map", "_health_panel", "_skills", "_admin", "_help"]:
		var n := hud.get(prop) as Control
		if n and n.visible:
			return true
	return false


func _close_any_panel() -> void:
	if hud == null:
		return
	var inv := hud.get("_inventory") as Control
	if inv and inv.visible:
		inv.call("close")
		return
	for prop in ["_map", "_health_panel", "_skills", "_admin", "_help"]:
		var n := hud.get(prop) as Control
		if n and n.visible:
			n.visible = false
			return


func _rebuild_layout() -> void:
	_buttons.clear()
	_top_buttons.clear()
	var sz := size
	if sz.x < 100.0 or sz.y < 100.0:
		return

	# Top bar buttons (centered at top so clock on left and minimap on right stay clear)
	var pause_open := hud != null and (hud.get("_pause") as Control) != null and (hud.get("_pause") as Control).visible
	var death_open := hud != null and (hud.get("_death") as Control) != null and (hud.get("_death") as Control).visible
	if not pause_open and not death_open:
		var specs := [
			["inv", "Рюкзак", "inventory"],
			["hp", "Здоровье", "health"],
			["sk", "Навыки", "skills"],
			["map", "Карта", "map"],
			["view", "Вид", "toggle_view"],
			["adm", "Админ", "admin"],
			["prof", "FPS", ""],
			["pause", "Пауза", "pause"],
		]
		if _has_closable_panel():
			specs.push_front(["close_panel", "✕ Закрыть", ""])
		var bw := 78.0
		var bh := 38.0
		var gap := 5.0
		var total_w := specs.size() * bw + (specs.size() - 1) * gap
		var x0 := clampf((sz.x - total_w) * 0.5, 225.0, maxf(sz.x - total_w - 205.0, 225.0))
		for i in specs.size():
			var s: Array = specs[i]
			var r := Rect2(Vector2(x0 + i * (bw + gap), 10.0), Vector2(bw, bh))
			_top_buttons.append({
				"id": s[0],
				"label": s[1],
				"action": s[2],
				"rect": r,
				"accent": s[0] == "close_panel",
			})

	if _is_modal_open() or get_tree().paused or (player != null and player.state == Player.State.DEAD):
		return

	_joy_base_center = Vector2(138.0, sz.y - 134.0)
	if _joy_finger == -1:
		_joy_center = _joy_base_center

	if player != null and player.state == Player.State.SEATED:
		_add_circle_btn("interact", "ВСТАТЬ" if not player.is_sleeping() else "ПРОСНУТЬСЯ", Vector2(sz.x - 145.0, sz.y - 135.0), 58.0, "interact", true, false)
		return

	if player != null and player.state == Player.State.DRIVING:
		_add_circle_btn("gas", "ГАЗ", Vector2(sz.x - 105.0, sz.y - 115.0), 54.0, "move_up", true, true)
		_add_circle_btn("brake", "ТОРМОЗ", Vector2(sz.x - 225.0, sz.y - 100.0), 46.0, "move_down", false, true)
		_add_circle_btn("handbrake", "РУЧНИК", Vector2(sz.x - 105.0, sz.y - 230.0), 40.0, "handbrake", false, true)
		_add_circle_btn("horn", "СИГНАЛ", Vector2(sz.x - 210.0, sz.y - 208.0), 38.0, "horn", false, false)
		_add_circle_btn("lights", "ФАРЫ", Vector2(sz.x - 305.0, sz.y - 188.0), 38.0, "flashlight", player.vehicle != null and player.vehicle.headlights, false)
		if player.vehicle != null and not player.vehicle.engine_on:
			_add_circle_btn("hotwire", "ЗАВЕСТИ", Vector2(sz.x - 335.0, sz.y - 98.0), 42.0, "reload", true, false)
		_add_circle_btn("exit_car", "ВЫЙТИ", Vector2(sz.x - 198.0, sz.y - 296.0), 40.0, "interact", false, false)
		return

	# Normal on-foot state
	var w := player.inventory.weapon() if (player != null and player.inventory != null) else null
	var is_gun := w != null and w.item.attack_style == "shoot"
	var atk_label := "ОГОНЬ" if is_gun else ("УДАР" if w != null else "ТОЛЧОК")
	var has_focus := player != null and player.interactor != null and player.interactor.focused != null

	_add_circle_btn("attack", atk_label, Vector2(sz.x - 106.0, sz.y - 122.0), 58.0, "attack", true, true)
	_add_circle_btn("interact", "ДЕЙСТВИЕ", Vector2(sz.x - 234.0, sz.y - 92.0), 45.0, "interact", has_focus, false)
	_add_circle_btn("menu", "МЕНЮ", Vector2(sz.x - 338.0, sz.y - 92.0), 38.0, "", has_focus, false)

	if is_gun:
		_add_circle_btn("aim", "ПРИЦЕЛ", Vector2(sz.x - 222.0, sz.y - 198.0), 40.0, "", aim_lock, false)
		_add_circle_btn("reload", "ПЕРЕЗАР.", Vector2(sz.x - 102.0, sz.y - 242.0), 38.0, "reload", false, false)

	_add_circle_btn("flashlight", "ФОНАРЬ", Vector2(sz.x - 180.0, sz.y - 284.0), 36.0, "flashlight", player != null and player.flashlight_on, false)
	_add_circle_btn("sprint", "БЕГ", Vector2(284.0, sz.y - 84.0), 38.0, "", sprint_lock or (player != null and player.running), false)
	_add_circle_btn("crouch", "СКРЫТНО", Vector2(284.0, sz.y - 174.0), 38.0, "crouch", player != null and player.crouching, false)


func _add_circle_btn(id: String, label: String, center: Vector2, radius: float, action: String, active_highlight: bool, holdable: bool) -> void:
	_buttons.append({
		"id": id,
		"label": label,
		"center": center,
		"radius": radius,
		"action": action,
		"active": active_highlight,
		"hold": holdable,
	})


func _input(event: InputEvent) -> void:
	if _test_mode:
		return
	if event is InputEventScreenTouch and not enabled:
		set_enabled(true)
	if not enabled or not visible:
		return

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var p := _to_local_ui(st.position)
		if st.pressed:
			if _handle_press(st.index, p):
				get_viewport().set_input_as_handled()
		else:
			if _handle_release(st.index):
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		var p := _to_local_ui(sd.position)
		var rel := _to_local_rel(sd.relative)
		if _handle_drag(sd.index, p, rel):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device >= 0:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var p := _to_local_ui(mb.position)
			if mb.pressed:
				if _handle_press(MOUSE_FINGER, p):
					get_viewport().set_input_as_handled()
			else:
				if _handle_release(MOUSE_FINGER):
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device >= 0:
		if _joy_finger == MOUSE_FINGER or _look_finger == MOUSE_FINGER or _held_buttons.has(MOUSE_FINGER):
			var mm := event as InputEventMouseMotion
			var p := _to_local_ui(mm.position)
			var rel := _to_local_rel(mm.relative)
			if _handle_drag(MOUSE_FINGER, p, rel):
				get_viewport().set_input_as_handled()


func _handle_press(finger: int, pos: Vector2) -> bool:
	# 1. Top bar buttons
	for b in _top_buttons:
		if (b["rect"] as Rect2).grow(4.0).has_point(pos):
			_trigger_top_button(b)
			return true

	if _is_modal_open() or get_tree().paused or (player != null and player.state == Player.State.DEAD):
		return false

	# 2. Gameplay circular buttons
	for b in _buttons:
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		if pos.distance_to(c) <= r * 1.15:
			_press_game_button(finger, b)
			return true

	# 3. Left virtual joystick zone ("dvichoq" — bottom-left quadrant)
	if _joy_finger == -1 and pos.x < size.x * 0.44 and pos.y > size.y * 0.34:
		_joy_finger = finger
		# If touched near the joystick ring, keep fixed center so directional taps immediately walk;
		# if touched further away in the left zone, shift center closer to the thumb.
		if pos.distance_to(_joy_base_center) > 105.0:
			_joy_center = pos - (pos - _joy_base_center).normalized() * 45.0
		else:
			_joy_center = _joy_base_center
		_update_joy_vec(pos)
		return true

	# 4. Look drag zone (rest of screen)
	if _look_finger == -1 and pos.y > 54.0:
		_look_finger = finger
		return true

	return false


func _handle_drag(finger: int, pos: Vector2, rel: Vector2) -> bool:
	if finger == _joy_finger:
		_update_joy_vec(pos)
		return true
	if finger == _look_finger:
		if player and not _is_modal_open() and not get_tree().paused:
			if player.fp_active():
				player.fp.look(rel * 1.55)
			elif player.state == Player.State.NORMAL and rel.length() > 0.5:
				var cam_yaw := player.camera.global_rotation.y if player.camera else deg_to_rad(45.0)
				var look_dir := Vector3(rel.x, 0, rel.y).rotated(Vector3.UP, cam_yaw)
				player.face_towards(look_dir)
		return true
	return _held_buttons.has(finger)


func _handle_release(finger: int) -> bool:
	if finger == _joy_finger:
		_joy_finger = -1
		_joy_center = _joy_base_center
		_joy_vec = Vector2.ZERO
		_apply_joystick()
		return true
	if finger == _look_finger:
		_look_finger = -1
		return true
	if _held_buttons.has(finger):
		var bid: String = _held_buttons[finger]
		_held_buttons.erase(finger)
		_release_game_button(bid)
		return true
	return false


func _update_joy_vec(pos: Vector2) -> void:
	var max_r := 84.0
	var d := pos - _joy_center
	if d.length() > max_r:
		d = d.normalized() * max_r
	_joy_vec = d / max_r
	if _joy_vec.length() < DEADZONE:
		_joy_vec = Vector2.ZERO
	_apply_joystick()


func _apply_joystick() -> void:
	var want_run := (sprint_lock and _joy_vec.length() > DEADZONE) or _joy_vec.length() >= SPRINT_RING
	if player != null:
		player.set_meta("touch_move", _joy_vec)
		player.set_meta("touch_run", want_run)

	if player != null and player.state == Player.State.DRIVING:
		if _joy_vec.x < -DEADZONE:
			Input.action_press("move_left", clampf(-_joy_vec.x, 0.0, 1.0))
			Input.action_release("move_right")
		elif _joy_vec.x > DEADZONE:
			Input.action_press("move_right", clampf(_joy_vec.x, 0.0, 1.0))
			Input.action_release("move_left")
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")
		if not _is_button_held("gas") and not _is_button_held("brake"):
			if _joy_vec.y < -0.25:
				Input.action_press("move_up", clampf(-_joy_vec.y, 0.0, 1.0))
				Input.action_release("move_down")
			elif _joy_vec.y > 0.25:
				Input.action_press("move_down", clampf(_joy_vec.y, 0.0, 1.0))
				Input.action_release("move_up")
			else:
				Input.action_release("move_up")
				Input.action_release("move_down")
		return

	if _joy_vec.x < -DEADZONE:
		Input.action_press("move_left", clampf(-_joy_vec.x, 0.0, 1.0))
		Input.action_release("move_right")
	elif _joy_vec.x > DEADZONE:
		Input.action_press("move_right", clampf(_joy_vec.x, 0.0, 1.0))
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

	if _joy_vec.y < -DEADZONE:
		Input.action_press("move_up", clampf(-_joy_vec.y, 0.0, 1.0))
		Input.action_release("move_down")
	elif _joy_vec.y > DEADZONE:
		Input.action_press("move_down", clampf(_joy_vec.y, 0.0, 1.0))
		Input.action_release("move_up")
	else:
		Input.action_release("move_up")
		Input.action_release("move_down")

	if want_run:
		Input.action_press("run")
	else:
		Input.action_release("run")


func _is_button_held(bid: String) -> bool:
	for k in _held_buttons:
		if _held_buttons[k] == bid:
			return true
	return false


func _trigger_top_button(b: Dictionary) -> void:
	var id: String = b["id"]
	if id == "close_panel":
		_close_any_panel()
		return
	if id == "prof":
		if LiveDebug:
			LiveDebug.toggle_overlay()
		return
	var act: String = b["action"]
	if act != "":
		_tap_action(act)


func _press_game_button(finger: int, b: Dictionary) -> void:
	var id: String = b["id"]
	var act: String = b["action"]
	if id == "sprint":
		sprint_lock = not sprint_lock
		if sprint_lock and player and player.crouching:
			_tap_action("crouch")
		return
	if id == "aim":
		aim_lock = not aim_lock
		if aim_lock:
			Input.action_press("context_menu")
		else:
			Input.action_release("context_menu")
		return
	if id == "menu":
		_open_context_menu_from_touch()
		return
	if id == "attack":
		_held_buttons[finger] = id
		Input.action_press("attack")
		if player and player.state == Player.State.NORMAL:
			player.cancel_action()
			var target_pt := player.mouse_world_point()
			if not player.fp_active():
				target_pt = player.global_position + player.get_facing_vector() * 2.5
			player.combat.try_attack(target_pt)
		return
	if bool(b["hold"]) and act != "":
		_held_buttons[finger] = id
		Input.action_press(act)
		return
	if act != "":
		_tap_action(act)


func _release_game_button(bid: String) -> void:
	for b in _buttons:
		if b["id"] == bid and b["action"] != "":
			Input.action_release(b["action"])
			return
	if bid == "attack":
		Input.action_release("attack")
	elif bid == "gas":
		Input.action_release("move_up")
	elif bid == "brake":
		Input.action_release("move_down")
	elif bid == "handbrake":
		Input.action_release("handbrake")


func _open_context_menu_from_touch() -> void:
	if player == null or player.state != Player.State.NORMAL:
		return
	if player.interactor and player.interactor.focused:
		Events.context_menu_requested.emit(player.interactor.focused, player.interactor.get_actions())
	elif player.self_actions:
		var own := player.self_actions.get_actions(player)
		if not own.is_empty():
			Events.context_menu_requested.emit(player.self_actions, own)


func _tap_action(act: String) -> void:
	var ev := InputEventAction.new()
	ev.action = act
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev_up := InputEventAction.new()
	ev_up.action = act
	ev_up.pressed = false
	Input.parse_input_event.call_deferred(ev_up)


func _release_gameplay_inputs() -> void:
	_joy_finger = -1
	_joy_center = _joy_base_center
	_joy_vec = Vector2.ZERO
	_look_finger = -1
	_held_buttons.clear()
	if player != null:
		player.set_meta("touch_move", Vector2.ZERO)
		player.set_meta("touch_run", false)
	for a in ["move_left", "move_right", "move_up", "move_down", "run", "attack", "handbrake"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)
	if aim_lock:
		aim_lock = false
		Input.action_release("context_menu")


func _release_all() -> void:
	sprint_lock = false
	_release_gameplay_inputs()


func _draw() -> void:
	if _test_mode or not enabled:
		return
	var f := UiTheme.font(true)
	# Draw top quick-bar
	for b in _top_buttons:
		var r: Rect2 = b["rect"]
		var is_acc: bool = b["accent"]
		var bg := Color(0.62, 0.24, 0.16, 0.92) if is_acc else Color(0.08, 0.08, 0.075, 0.86)
		var border := UiTheme.ACCENT if is_acc else Color(0.46, 0.43, 0.36, 0.92)
		draw_rect(r, bg, true)
		draw_rect(r, border, false, 1.8)
		var txt: String = b["label"]
		var fs := 15
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(r.position.x + (r.size.x - tw) * 0.5, r.position.y + r.size.y * 0.5 + 5.5),
			txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT)

	if _is_modal_open() or get_tree().paused or (player != null and player.state == Player.State.DEAD):
		return

	# Draw virtual joystick ("dvichoq") when not seated
	if player == null or player.state != Player.State.SEATED:
		var jr := 84.0
		var active_joy := _joy_finger != -1
		draw_circle(_joy_center, jr, Color(0.06, 0.06, 0.055, 0.65 if active_joy else 0.52))
		draw_arc(_joy_center, jr, 0.0, TAU, 48, UiTheme.ACCENT if active_joy else Color(0.62, 0.58, 0.48, 0.82), 2.8)
		draw_arc(_joy_center, jr * SPRINT_RING, 0.0, TAU, 36, Color(0.82, 0.38, 0.24, 0.35), 1.4)
		# Crosshair guide lines & directional chevrons inside the joystick
		var guide_col := Color(0.75, 0.72, 0.62, 0.28)
		draw_line(_joy_center + Vector2(-jr + 14.0, 0), _joy_center + Vector2(jr - 14.0, 0), guide_col, 1.5)
		draw_line(_joy_center + Vector2(0, -jr + 14.0), _joy_center + Vector2(0, jr - 14.0), guide_col, 1.5)
		var arr_col := Color(0.88, 0.84, 0.74, 0.68)
		for d_arr in [
			[_joy_center + Vector2(0, -jr + 14.0), _joy_center + Vector2(-8, -jr + 24.0), _joy_center + Vector2(8, -jr + 24.0)],
			[_joy_center + Vector2(0, jr - 14.0), _joy_center + Vector2(-8, jr - 24.0), _joy_center + Vector2(8, jr - 24.0)],
			[_joy_center + Vector2(-jr + 14.0, 0), _joy_center + Vector2(-jr + 24.0, -8), _joy_center + Vector2(-jr + 24.0, 8)],
			[_joy_center + Vector2(jr - 14.0, 0), _joy_center + Vector2(jr - 24.0, -8), _joy_center + Vector2(jr - 24.0, 8)],
		]:
			draw_colored_polygon(PackedVector2Array(d_arr), arr_col)
		var knob := _joy_center + _joy_vec * jr
		var knob_col := Color(0.85, 0.38, 0.24, 0.92) if active_joy else Color(0.72, 0.68, 0.58, 0.80)
		draw_circle(knob, 34.0, knob_col)
		draw_arc(knob, 34.0, 0.0, TAU, 32, Color(0.98, 0.94, 0.84, 0.95), 2.5)
		var j_lbl := "ХОДЬБА"
		var j_fs := 12
		var j_tw := f.get_string_size(j_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, j_fs).x
		draw_string(f, knob + Vector2(-j_tw * 0.5, 4.5), j_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, j_fs, Color(0.12, 0.1, 0.08, 0.95) if not active_joy else UiTheme.TEXT)

	# Draw circular action buttons
	for b in _buttons:
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var held := _is_button_held(b["id"])
		var act_hi: bool = b["active"] or held
		var bg := Color(0.68, 0.28, 0.18, 0.88) if act_hi else Color(0.08, 0.08, 0.075, 0.78)
		var rim := UiTheme.ACCENT if act_hi else Color(0.55, 0.52, 0.44, 0.88)
		draw_circle(c, r, bg)
		draw_arc(c, r, 0.0, TAU, 36, rim, 2.6 if act_hi else 2.0)
		var lbl: String = b["label"]
		var fs := 15 if r >= 44.0 else 13
		var tw := f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-tw * 0.5, 5.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT)
