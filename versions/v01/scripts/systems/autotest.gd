extends Node
## Scripted in-engine checks that drive the real player through input actions.
## Prints "AUTOTEST PASS/FAIL <name>" lines and quits. With `tour`, also saves screenshots.

var tour := false
var player: V01Player
var world: Node3D
var _results: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(test: String, ok: bool, info := "") -> void:
	_results.append([test, ok])
	print("AUTOTEST %s %s %s" % ["PASS" if ok else "FAIL", test, info])


func _release_all() -> void:
	for a in ["move_up", "move_down", "move_left", "move_right", "run", "crouch"]:
		Input.action_release(a)


## Walk in a world direction for `sec` seconds using the camera-relative input mapping.
func _walk(dir: Vector3, sec: float, run := false) -> void:
	var cam_yaw := player.camera.global_rotation.y
	var v := dir.normalized().rotated(Vector3.UP, -cam_yaw)
	_release_all()
	if v.x > 0.01:
		Input.action_press("move_right", v.x)
	elif v.x < -0.01:
		Input.action_press("move_left", -v.x)
	if v.z > 0.01:
		Input.action_press("move_down", v.z)
	elif v.z < -0.01:
		Input.action_press("move_up", -v.z)
	if run:
		Input.action_press("run")
	await _wait(sec)
	_release_all()
	await _wait(0.25)


func _teleport(p: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = p
	player.rig_snap()
	await _wait(0.35)


func _shot(shot_name: String) -> void:
	await _frames(6)
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://tools/screens")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/" + shot_name + ".png")
	print("AUTOTEST SHOT ", shot_name)


## --shot=x,y,z,name[,hour[,zoom]] (repeatable): only teleport and take screenshots.
func _quick_shots() -> bool:
	var any := false
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--shot="):
			continue
		any = true
		var p := a.trim_prefix("--shot=").split(",")
		if p.size() > 4:
			V01GameTime.set_hour(float(p[4]))
		if p.size() > 5:
			player.camera.get_parent().set("_zoom_target", float(p[5]))
			player.camera.get_parent().set("zoom", float(p[5]))
		await _teleport(Vector3(float(p[0]), float(p[1]), float(p[2])))
		await _wait(0.4)
		await _shot(p[3])
	return any


func _run() -> void:
	await _frames(10)
	world = get_parent().get_world()
	player = get_tree().get_first_node_in_group("player") as V01Player
	if await _quick_shots():
		get_tree().quit(0)
		return
	if "--poses" in OS.get_cmdline_user_args():
		await _poses()
		get_tree().quit(0)
		return
	var d := V01District.instance
	_check("world_built", d != null and d.buildings.size() == 6, "buildings=%d" % d.buildings.size())
	var n_doors := get_tree().get_nodes_in_group("doors").size()
	var n_win := get_tree().get_nodes_in_group("windows").size()
	var n_cont := get_tree().get_nodes_in_group("containers").size()
	var n_int := get_tree().get_nodes_in_group("interactables").size()
	_check("interactables", n_doors > 100 and n_win > 100 and n_cont > 100,
		"doors=%d windows=%d containers=%d total=%d" % [n_doors, n_win, n_cont, n_int])
	await _wait(1.0)
	_check("player_on_floor", player.is_on_floor(), str(player.global_position))

	# --- walking / running / crouching speeds
	var p0 := player.global_position
	await _walk(Vector3(1, 0, 0), 1.5)
	var walked := (player.global_position - p0).length()
	_check("walk", walked > 2.0 and walked < 4.5, "dist=%.2f" % walked)
	p0 = player.global_position
	await _walk(Vector3(-1, 0, 0), 1.5, true)
	var ran := (player.global_position - p0).length()
	_check("run_faster", ran > walked * 1.6, "dist=%.2f" % ran)
	var end_before := player.stats.endurance
	_check("run_drains_endurance", end_before < 0.98, "endurance=%.2f" % end_before)
	player.crouching = true
	p0 = player.global_position
	await _walk(Vector3(1, 0, 0), 1.5)
	var crept := (player.global_position - p0).length()
	_check("crouch_slower", player.crouching and crept < walked * 0.7, "dist=%.2f" % crept)
	player.crouching = false
	# 8 directions: diagonal works and the model turns toward movement.
	await _walk(Vector3(1, 0, 1), 1.0)
	var f := player.get_facing_vector()
	_check("turn_to_move_dir", f.dot(Vector3(1, 0, 1).normalized()) > 0.9, "facing=%s" % f)

	# --- collision: walk into the facade of house 10 (front wall z=56) from the courtyard.
	await _teleport(Vector3(33.0, 0.1, 54.5))
	await _walk(Vector3(0, 0, 1), 2.0)
	_check("wall_collision", player.global_position.z < 56.0, "z=%.2f" % player.global_position.z)

	# --- entrance door of house 10, section 1 (world x=40): open and walk in.
	var door := _nearest_door(Vector3(40, 0.1, 56))
	await _teleport(Vector3(40, 0.1, 54.6))
	await _wait(0.3)
	var focused := player.interactor.focused
	_check("door_focus", focused == door, "focused=%s" % (focused.display_name if focused else "none"))
	# UI: right-click action menu, map and pause through real input events.
	var hud := get_parent().get_node("UI/HUD")
	if focused:
		V01Events.context_menu_requested.emit(focused, focused.get_actions(player))
		await _frames(2)
		_check("context_menu", (hud.get("_menu") as PopupMenu).visible and (hud.get("_menu") as PopupMenu).item_count >= 2)
		(hud.get("_menu") as PopupMenu).hide()
	await _press_action("map")
	_check("map_opens", (hud.get("_map") as Control).visible)
	await _press_action("map")
	await _press_action("pause")
	_check("pause_opens", get_tree().paused and (hud.get("_pause") as Control).visible)
	await _press_action("pause")
	_check("pause_closes", not get_tree().paused)
	if door:
		door.perform("open", player)
		await _wait(0.6)
		_check("door_opens", door.is_open)
	await _walk(Vector3(0, 0, 1), 1.6)
	var b3 := d.buildings[2]
	_check("entered_building", b3.contains_point(player.global_position), str(player.global_position))
	await _frames(3)
	_check("upper_floors_hidden", b3.get_view() == 0 and not b3.levels[1].visible and not b3.roof.visible)
	if tour:
		await _shot("02_stairwell_ground")

	# --- stairs: flight A up (+z), then flight B (-z) to the 2nd floor landing.
	await _teleport(Vector3(40.7, 0.12, 57.3))
	await _walk(Vector3(0, 0, 1), 1.9)
	var mid_y := player.global_position.y
	_check("flight_a_climb", mid_y > 1.2, "y=%.2f" % mid_y)
	await _walk(Vector3(-1, 0, 0), 0.6)
	await _walk(Vector3(0, 0, -1), 2.0)
	var y2 := player.global_position.y
	_check("reach_level_2", y2 > 2.7 and b3.level_at(player.global_position) == 1, "y=%.2f" % y2)
	await _frames(3)
	_check("level2_view", b3.get_view() == 1 and b3.levels[1].visible and not b3.levels[2].visible)
	if tour:
		await _shot("03_stairwell_level2")
	# Walk back down.
	await _walk(Vector3(0, 0, 1), 2.0)
	await _walk(Vector3(1, 0, 0), 0.6)
	await _walk(Vector3(0, 0, -1), 2.2)
	_check("stairs_down", player.global_position.y < 0.5, "y=%.2f" % player.global_position.y)

	# --- flat interior: container search + sit.
	await _teleport(Vector3(36.0, 0.1, 62.5))
	var cont := _nearest_in_group("containers", player.global_position) as V01LootContainer
	if cont:
		cont.perform("search", player)
		await _wait(0.5)
		_check("container_open", cont.is_open and cont.searched, cont.display_name)
	var seat := _nearest_seat(player.global_position)
	if seat:
		seat.perform("sit", player)
		await _wait(0.6)
		_check("sit", player.state == V01Player.State.SEATED, seat.display_name)
		player.stand_up()
		await _wait(0.6)
		_check("stand_up", player.state == V01Player.State.NORMAL)
	var tv := _nearest_use(player.global_position, V01Furniture.Use.TV)
	if tv:
		tv.perform("tv", player)
		_check("tv_on", tv.tv_on)
		tv.perform("tv", player)
	var bed := _nearest_use(player.global_position, V01Furniture.Use.BED)
	if bed:
		await _teleport(bed.global_position + bed.global_basis.x * 0.9 + Vector3(0, 0.05, 0))
		bed.perform("lie", player)
		await _wait(0.6)
		_check("lie_on_bed", player.state == V01Player.State.SEATED and player.animator.pose == V01CharacterAnimator.Pose.LIE)
		player.stand_up()
		await _wait(0.6)
	if tour:
		await _teleport(Vector3(26.3, 0.1, 64.0))
		await _shot("04_flat_living_room")
		await _teleport(Vector3(24.0, 0.1, 57.6))
		await _shot("05_flat_kitchen")

	# --- window: smash ground-floor kitchen window from inside and climb out.
	var win := _nearest_in_group("windows", Vector3(23.3, 1.0, 56.0)) as V01WindowObj
	if win:
		await _teleport(win.global_position + win.global_basis.z * -0.9 + Vector3(0, -0.85, 0))
		win.perform("smash", player)
		await _wait(0.3)
		_check("window_smash", win.is_broken)
		win.perform("clear", player)
		win.perform("climb", player)
		await _wait(1.6)
		var outside := not b3.contains_point(player.global_position)
		_check("window_climb_out", outside and player.state == V01Player.State.NORMAL, str(player.global_position))

	# --- shops.
	await _teleport(Vector3(24.5, 0.1, 81.6))
	var gdoor := _nearest_door(Vector3(24.5, 0.1, 80))
	if gdoor:
		gdoor.perform("open", player)
		await _wait(0.5)
	await _walk(Vector3(0, 0, -1), 1.6)
	_check("enter_grocery", d.buildings[4].contains_point(player.global_position), str(player.global_position))
	if tour:
		await _teleport(Vector3(26.0, 0.1, 76.0))
		await _shot("06_grocery")
		await _teleport(Vector3(88.5, 0.1, 79.0))
		await _shot("07_pharmacy")

	# --- fall damage from a 4th-floor height behind house 10.
	var hp := player.health.health
	await _teleport(Vector3(40.0, 6.0, 70.5))
	await _wait(2.0)
	_check("fall_damage", player.health.health < hp and not player.health.is_dead(), "hp=%.1f" % player.health.health)
	player.health.health = player.health.max_health

	# --- performance in the courtyard.
	await _teleport(Vector3(45, 0.1, 40))
	await _wait(2.0)
	var fps := Engine.get_frames_per_second()
	_check("fps", fps >= 30.0, "fps=%d draw=%d" % [fps, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	if tour:
		await _shot("01_courtyard_day")
		player.camera.get_parent().set("_zoom_target", 30.0)
		await _wait(1.0)
		await _shot("08_courtyard_wide")
		player.camera.get_parent().set("_zoom_target", 15.0)
		await _teleport(Vector3(52, 0.1, 88.5))
		await _shot("09_street_day")
		V01GameTime.set_hour(22.5)
		await _wait(0.6)
		await _shot("10_street_night")
		V01GameTime.set_hour(19.5)
		await _teleport(Vector3(40, 0.1, 48))
		await _wait(0.6)
		await _shot("11_courtyard_evening")
		V01GameTime.set_hour(12.0)
		await _teleport(Vector3(91.0, 0.1, 22.0))
		await _shot("12_nine_storey")
		await _teleport(Vector3(42, 0.1, 3.0))
		await _shot("13_behind_house12_cut")

	var failed := _results.filter(func(r: Array) -> bool: return not r[1]).size()
	print("AUTOTEST DONE %d/%d passed" % [_results.size() - failed, _results.size()])
	get_tree().quit(1 if failed > 0 else 0)


## Close-up captures of the procedural animation states.
func _poses() -> void:
	var rig := player.camera.get_parent()
	rig.set("_zoom_target", 6.0)
	rig.set("zoom", 6.0)
	await _teleport(Vector3(45, 0.1, 33.5))
	await _shot("pose_idle")
	var cam_yaw := player.camera.global_rotation.y
	for spec in [["pose_walk", false, false], ["pose_run", true, false], ["pose_crouch", false, true]]:
		player.crouching = spec[2]
		var v := Vector3(1, 0, 0).rotated(Vector3.UP, -cam_yaw)
		Input.action_press("move_right", maxf(v.x, 0.0))
		Input.action_press("move_down", maxf(v.z, 0.0))
		Input.action_press("move_up", maxf(-v.z, 0.0))
		if spec[1]:
			Input.action_press("run")
		await _wait(0.9)
		await _shot(spec[0])
		_release_all()
		await _teleport(Vector3(45, 0.1, 33.5))
	player.crouching = false
	player.call("_start_attack")
	await _wait(0.22)
	await _shot("pose_attack_windup")
	await _wait(0.12)
	await _shot("pose_attack_strike")
	await _wait(0.6)
	var seat := _nearest_seat(player.global_position)
	await _teleport(seat.global_position + seat.global_basis.z * 0.8)
	seat.perform("sit", player)
	await _wait(0.8)
	await _shot("pose_sit")


func _nearest_in_group(group: String, p: Vector3) -> Node3D:
	var best: Node3D = null
	for n in get_tree().get_nodes_in_group(group):
		var n3 := n as Node3D
		if best == null or n3.global_position.distance_to(p) < best.global_position.distance_to(p):
			best = n3
	return best


func _press_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _nearest_use(p: Vector3, use: V01Furniture.Use) -> V01Furniture:
	var best: V01Furniture = null
	for n in get_tree().get_nodes_in_group("interactables"):
		if n is V01Furniture and (n as V01Furniture).use == use:
			if best == null or (n as Node3D).global_position.distance_to(p) < best.global_position.distance_to(p):
				best = n
	return best


func _nearest_door(p: Vector3) -> V01Door:
	return _nearest_in_group("doors", p) as V01Door


func _nearest_seat(p: Vector3) -> V01Furniture:
	var best: V01Furniture = null
	for n in get_tree().get_nodes_in_group("interactables"):
		if n is V01Furniture and (n as V01Furniture).use == V01Furniture.Use.SEAT:
			if best == null or (n as Node3D).global_position.distance_to(p) < best.global_position.distance_to(p):
				best = n
	return best
