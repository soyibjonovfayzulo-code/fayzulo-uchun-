extends Node
## Scripted in-engine checks that drive the real player through input actions.
## Prints "AUTOTEST PASS/FAIL <name>" lines and quits. With `tour`, also saves screenshots.

var tour := false
var player: Player
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
	player.set("_walk_vel", Vector3.ZERO)
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


## --shot=x,y,z,name[,hour[,zoom[,rain]]] (repeatable): only teleport and take screenshots.
func _quick_shots() -> bool:
	var any := false
	for a in OS.get_cmdline_user_args():
		if a == "--nohud":
			get_parent().get_node("UI").visible = false
		if not a.begins_with("--shot="):
			continue
		any = true
		var p := a.trim_prefix("--shot=").split(",")
		if p.size() > 4:
			GameTime.set_hour(float(p[4]))
		if p.size() > 5:
			player.camera.get_parent().set("_zoom_target", float(p[5]))
			player.camera.get_parent().set("zoom", float(p[5]))
		if p.size() > 6 and Climate.instance:
			Climate.instance.set_rain_now(float(p[6]))
		await _teleport(Vector3(float(p[0]), float(p[1]), float(p[2])))
		await _wait(0.4)
		await _shot(p[3])
	return any


func _run() -> void:
	await _frames(10)
	world = get_parent().get_world()
	player = get_tree().get_first_node_in_group("player") as Player
	if await _quick_shots():
		get_tree().quit(0)
		return
	if "--poses" in OS.get_cmdline_user_args():
		await _poses()
		get_tree().quit(0)
		return
	if "--loadcheck" in OS.get_cmdline_user_args():
		await preload("res://scripts/systems/autotest_m78.gd").new(self).loadcheck()
		_finish()
		return
	if "--gallery" in OS.get_cmdline_user_args():
		await preload("res://scripts/systems/autotest_gallery.gd").new(self).run()
		get_tree().quit(0)
		return
	if "--v04" in OS.get_cmdline_user_args():
		await preload("res://scripts/systems/autotest_v04.gd").new(self).run()
		_finish()
		return
	if "--probe-admin" in OS.get_cmdline_user_args():
		await _probe_admin()
		get_tree().quit(0)
		return
	if "--profile-interactions" in OS.get_cmdline_user_args():
		await _probe_interactions()
		await _test_hot_update_and_live_debug()
		_finish()
		return
	if "--test-hot-update" in OS.get_cmdline_user_args():
		await _test_hot_update_and_live_debug()
		_finish()
		return
	if "--fpgallery" in OS.get_cmdline_user_args():
		await preload("res://scripts/systems/autotest_fps.gd").new(self).fp_gallery()
		get_tree().quit(0)
		return
	if "--fpvm" in OS.get_cmdline_user_args():
		await preload("res://scripts/systems/autotest_fps.gd").new(self).vm_gallery()
		get_tree().quit(0)
		return
	if "--fps" in OS.get_cmdline_user_args():
		await preload("res://scripts/systems/autotest_fps.gd").new(self).run(true)
		_finish()
		return
	if "--m78" in OS.get_cmdline_user_args():
		await preload("res://scripts/systems/autotest_m78.gd").new(self).run()
		_finish()
		return
	var d := District.instance
	_check("world_built", d != null and d.buildings.size() >= 6, "buildings=%d" % d.buildings.size())
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
		Events.context_menu_requested.emit(focused, focused.get_actions(player))
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
	var cont := _nearest_in_group("containers", player.global_position) as LootContainer
	if cont:
		cont.perform("search", player)
		await _wait(cont.search_time + 0.4)
		_check("container_open", cont.is_open and cont.searched, cont.display_name)
	var seat := _nearest_seat(player.global_position)
	if seat:
		seat.perform("sit", player)
		await _wait(0.6)
		_check("sit", player.state == Player.State.SEATED, seat.display_name)
		player.stand_up()
		await _wait(0.6)
		_check("stand_up", player.state == Player.State.NORMAL)
	var tv := _nearest_use(player.global_position, Furniture.Use.TV)
	if tv:
		tv.perform("tv", player)
		_check("tv_on", tv.tv_on)
		tv.perform("tv", player)
	var bed := _nearest_use(player.global_position, Furniture.Use.BED)
	if bed:
		await _teleport(bed.global_position + bed.global_basis.x * 0.9 + Vector3(0, 0.05, 0))
		bed.perform("lie", player)
		await _wait(0.6)
		_check("lie_on_bed", player.state == Player.State.SEATED and player.animator.pose == CharacterAnimator.Pose.LIE)
		player.stand_up()
		await _wait(0.6)
	if tour:
		await _teleport(Vector3(26.3, 0.1, 64.0))
		await _shot("04_flat_living_room")
		await _teleport(Vector3(24.0, 0.1, 57.6))
		await _shot("05_flat_kitchen")

	# --- window: smash ground-floor kitchen window from inside and climb out.
	var win := _nearest_in_group("windows", Vector3(23.3, 1.0, 56.0)) as WindowObj
	if win:
		await _teleport(win.global_position + win.global_basis.z * -0.9 + Vector3(0, -0.85, 0))
		win.perform("smash", player)
		await _wait(0.3)
		_check("window_smash", win.is_broken)
		win.perform("clear", player)
		win.perform("climb", player)
		await _wait(1.6)
		var outside := not b3.contains_point(player.global_position)
		_check("window_climb_out", outside and player.state == Player.State.NORMAL, str(player.global_position))

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
		GameTime.set_hour(22.5)
		await _wait(0.6)
		await _shot("10_street_night")
		GameTime.set_hour(19.5)
		await _teleport(Vector3(40, 0.1, 48))
		await _wait(0.6)
		await _shot("11_courtyard_evening")
		GameTime.set_hour(12.0)
		await _teleport(Vector3(91.0, 0.1, 22.0))
		await _shot("12_nine_storey")
		await _teleport(Vector3(42, 0.1, 3.0))
		await _shot("13_behind_house12_cut")

	await _m456()
	# v0.4 first: the M7-8 run ends with the survivor's death and reanimation.
	await preload("res://scripts/systems/autotest_v04.gd").new(self).run()
	await preload("res://scripts/systems/autotest_fps.gd").new(self).run()
	await preload("res://scripts/systems/autotest_m78.gd").new(self).run()
	_finish()


func _finish() -> void:
	var failed := _results.filter(func(r: Array) -> bool: return not r[1]).size()
	print("AUTOTEST DONE %d/%d passed" % [_results.size() - failed, _results.size()])
	GameTime.time_scale = 1.0
	get_tree().quit(1 if failed > 0 else 0)


## Close-up captures of the procedural animation states.
func _poses() -> void:
	var rig := player.camera.get_parent()
	rig.set("_zoom_target", 6.0)
	rig.set("zoom", 6.0)
	await _clear_zombies()
	await _teleport(Vector3(45, 0.1, 33.5))
	await _wait(0.6)
	await _shot("pose_idle")
	var cam_yaw := player.camera.global_rotation.y
	await _teleport(Vector3(40, 0.1, 90))
	for spec in [["pose_walk", false, false], ["pose_run", true, false], ["pose_crouch", false, true]]:
		player.crouching = spec[2]
		var v := Vector3(1, 0, 0).rotated(Vector3.UP, -cam_yaw)
		Input.action_press("move_right", maxf(v.x, 0.0))
		Input.action_press("move_down", maxf(v.z, 0.0))
		Input.action_press("move_up", maxf(-v.z, 0.0))
		if spec[1]:
			Input.action_press("run")
		await _wait(0.9)
		await _shot(spec[0] + "_a")
		await _wait(0.17)
		await _shot(spec[0] + "_b")
		_release_all()
		await _teleport(Vector3(40, 0.1, 90))
	player.crouching = false
	var bat := player.inventory.give("bat")
	player.inventory.equip(bat)
	await _wait(0.6)
	await _shot("pose_hold_bat")
	player.combat.try_attack(player.global_position + player.get_facing_vector() * 2.0)
	for f in [["windup", 0.22], ["strike", 0.13], ["follow", 0.2]]:
		await _wait(f[1])
		await _shot("pose_bat_" + f[0])
	await _wait(0.8)
	for id in ["pistol", "shotgun"]:
		var w := player.inventory.give(id)
		w.loaded = w.item.magazine
		player.inventory.equip(w)
		await _wait(0.5)
		player.combat.try_attack(player.global_position + player.get_facing_vector() * 4.0)
		await _wait(0.06)
		await _shot("pose_shoot_" + id)
		await _wait(1.2)
	player.inventory.unequip("hand")
	for cl in ["telogreika", "sweater", "tracksuit"]:
		player.inventory.equip(player.inventory.give(cl))
		player.inventory.equip(player.inventory.give("backpack" if cl != "sweater" else "sportbag"))
		await _wait(0.4)
		await _shot("pose_wear_" + cl)
	var food := player.inventory.give("crackers")
	player.use_item(food)
	await _wait(0.7)
	await _shot("pose_eat")
	await _wait(2.0)
	var water := player.inventory.give("water")
	player.use_item(water)
	await _wait(0.8)
	await _shot("pose_drink")
	await _wait(1.5)
	# Zombie gaits side by side, walking on the spot.
	var zs: Array = []
	await _teleport(Vector3(43.0, 0.1, 32.6))
	for g in 4:
		var z: Zombie = await _spawn_zombie(Vector3(44.5 - g * 1.6 + g * 0.9, 0.1, 35.5 - g * 1.6 - g * 0.9), "zombie_%s" % ["a", "b", "c", "g"][g])
		z.set_physics_process(false)
		z.animator.gait = g as CharacterAnimator.Gait
		z.animator.speed = 0.85
		z.yaw = 2.36
		z.model.rotation.y = 2.36
		z.animator.set_process(true)
		zs.append(z)
	await _teleport(Vector3(43.0, 0.1, 32.6))
	player.model.visible = false
	rig.set("_zoom_target", 8.0)
	await _wait(0.8)
	await _shot("pose_zombie_gaits")
	for z in zs:
		(z as Zombie).animator.hunting = true
	await _wait(0.7)
	await _shot("pose_zombie_reach")
	var zz: Zombie = zs[0]
	zz.animator.attack_style = "grab"
	for f in [["reach", 0.35], ["bite", 0.57]]:
		zz.animator.attack_t = f[1]
		await _wait(0.25)
		await _shot("pose_zombie_" + f[0])
	zz.animator.attack_t = -1.0
	var cr: Zombie = zs[1]
	cr.make_crawler()
	cr.animator.pose = CharacterAnimator.Pose.CRAWL
	cr.animator.speed = 0.5
	var fall: Zombie = zs[2]
	fall.animator.pose = CharacterAnimator.Pose.DEAD
	await _wait(0.25)
	await _shot("pose_fall_mid")
	await _wait(0.8)
	await _shot("pose_crawl_and_dead")
	player.model.visible = true
	await _clear_zombies()


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


func _nearest_use(p: Vector3, use: Furniture.Use) -> Furniture:
	var best: Furniture = null
	for n in get_tree().get_nodes_in_group("interactables"):
		if n is Furniture and (n as Furniture).use == use:
			if best == null or (n as Node3D).global_position.distance_to(p) < best.global_position.distance_to(p):
				best = n
	return best


func _nearest_door(p: Vector3) -> Door:
	return _nearest_in_group("doors", p) as Door


func _nearest_seat(p: Vector3) -> Furniture:
	var best: Furniture = null
	for n in get_tree().get_nodes_in_group("interactables"):
		if n is Furniture and (n as Furniture).use == Furniture.Use.SEAT:
			if best == null or (n as Node3D).global_position.distance_to(p) < best.global_position.distance_to(p):
				best = n
	return best


# ================================================================================================ M4-M6
const LOSE_WAIT := 8.0


func _hud() -> Node:
	return get_parent().get_node("UI/HUD")


func _spawn_zombie(p: Vector3, kind := "zombie_a") -> Zombie:
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	var z := Zombie.spawn(get_parent().get_world().get_node("Zombies"), p, rng, kind)
	await _frames(2)
	return z


func _clear_zombies() -> void:
	for z in get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("corpses"):
		z.queue_free()
	await _frames(2)


func _reset_player(p: Vector3) -> void:
	player.health.health = player.health.max_health
	player.wounds.list.clear()
	player.wounds.infected = false
	player.stats.endurance = 1.0
	player.stats.fatigue = 0.0
	player.crouching = false
	await _teleport(p)


func _wait_nav() -> void:
	var t := 0.0
	while not NavBaker.ready_for_navigation and t < 60.0:
		await _wait(0.5)
		t += 0.5


func _m456() -> void:
	var inv := player.inventory
	# ---------------------------------------------------------------- test room: every item, piles of ammo
	var crates := get_tree().get_nodes_in_group("containers").filter(func(c: Node) -> bool:
		return (c as LootContainer).container_type == "crate" and (c as LootContainer).display_name.begins_with("Ящик:"))
	var have := {}
	var ammo := 0
	for c in crates:
		for s in (c as LootContainer).inventory.stacks:
			have[s.item.id] = true
			if s.item.id == "ammo":
				ammo += s.count
	_check("test_room_all_items", crates.size() == 3 and have.size() == ItemDB.items.size() and ammo >= 500,
		"crates=%d items=%d/%d ammo=%d" % [crates.size(), have.size(), ItemDB.items.size(), ammo])
	if tour:
		await _teleport(Vector3(45.5, 0.1, 46.0))
		crates[0].perform("search", player)
		await _wait(0.8)
		await _shot("25_test_room")
		_hud().get("_inventory").call("close")
	# ---------------------------------------------------------------- M4: data
	_check("item_db", ItemDB.items.size() >= 45 and ItemDB.tables.size() >= 20,
		"items=%d tables=%d" % [ItemDB.items.size(), ItemDB.tables.size()])
	_check("starting_kit", inv.main.find_by_id("water") != null and inv.main.count_of("bandage") == 2)
	inv.give("tushenka", 3)
	inv.give("tushenka", 2)
	var tush := inv.main.find_by_id("tushenka")
	_check("stacking", tush != null and tush.count == 5 and inv.main.stacks.filter(func(s: ItemStack) -> bool: return s.item.id == "tushenka").size() == 1)
	var part := inv.main.take(tush, 2)
	inv.main.stacks.append(part)
	_check("split_stack", part.count == 2 and tush.count == 3)
	var cap0 := inv.main.capacity
	var bag := inv.give("backpack")
	inv.equip(bag)
	_check("backpack_capacity", is_equal_approx(inv.main.capacity, cap0 + 14.0), "cap=%.1f" % inv.main.capacity)

	# ---------------------------------------------------------------- M4: looting through the real UI
	await _reset_player(Vector3(25.5, 0.1, 76.4))
	var shelves := get_tree().get_nodes_in_group("containers").filter(func(c: Node) -> bool:
		return (c as LootContainer).container_type == "shelf" and (c as LootContainer).room_type == "shop")
	var total := 0
	for c in shelves:
		total += (c as LootContainer).inventory.stacks.size() if (c as LootContainer).searched else 0
	var fresh := get_tree().get_nodes_in_group("containers").filter(func(c: Node) -> bool:
		return (c as LootContainer).room_type == "kitchen" and not (c as LootContainer).searched and (c as LootContainer).container_type == "fridge")
	var fridge := fresh[0] as LootContainer
	fridge.ensure_loot()
	var ids := fridge.inventory.stacks.map(func(s: ItemStack) -> String: return s.item.id)
	_check("loot_by_room", ids.all(func(id: String) -> bool: return id in ItemDB.tables["kitchen_fridge"].item_ids), str(ids))
	var shelf := _nearest_in_group("containers", player.global_position) as LootContainer
	var ui: Control = _hud().get("_inventory")
	shelf.perform("search", player)
	await _wait(0.2)
	_check("search_timed", player.action_progress() >= 0.0, "progress=%.2f" % player.action_progress())
	await _wait(shelf.search_time + 0.3)
	_check("search_opens_ui", shelf.searched and ui.visible, shelf.display_name)
	for c in shelves:
		(c as LootContainer).ensure_loot()
		total += (c as LootContainer).inventory.stacks.size()
	_check("shop_loot", shelves.size() >= 8 and total >= 10, "shelves=%d stacks=%d" % [shelves.size(), total])
	if tour:
		await _wait(0.3)
		await _shot("20_inventory_loot")
	if not shelf.inventory.stacks.is_empty():
		var s0: ItemStack = shelf.inventory.stacks[0]
		ui.call("_move", s0, "loot", "player", -1)
		_check("ui_transfer_to_player", not shelf.inventory.has(s0) and inv.main.stacks.any(func(s: ItemStack) -> bool: return s.item == s0.item))
	ui.call("close")
	var drop := inv.main.find_by_id("crackers")
	var wi := player.drop_item(drop)
	await _frames(2)
	_check("drop_to_floor", wi != null and wi.is_inside_tree() and not inv.main.has(drop))
	wi.perform("pickup", player)
	await _frames(2)
	_check("pick_up", inv.main.find_by_id("crackers") != null)

	# ---------------------------------------------------------------- M4: using items
	player.stats.hunger = 0.6
	inv.give("can_opener")
	var n_can := inv.main.count_of("tushenka")
	player.use_item(inv.main.find_by_id("tushenka"))
	await _wait(3.0)
	_check("eat_food", player.stats.hunger < 0.35 and inv.main.count_of("tushenka") == n_can - 1, "hunger=%.2f" % player.stats.hunger)
	player.stats.thirst = 0.6
	player.use_item(inv.main.find_by_id("water"))
	await _wait(2.0)
	var water := inv.main.find_by_id("water")
	_check("drink", player.stats.thirst < 0.4 and water != null and water.uses_left == 2, "thirst=%.2f" % player.stats.thirst)
	player.wounds.add("laceration")
	var hp0 := player.health.health
	await _wait(1.0)
	_check("bleeding_hurts", player.wounds.is_bleeding() and player.health.health < hp0)
	player.use_item(inv.main.find_by_id("bandage"))
	await _wait(3.4)
	_check("bandage", not player.wounds.is_bleeding() and inv.main.count_of("bandage") == 1)
	var fl := inv.give("flashlight")
	fl.charge = 1.0
	inv.equip(fl)
	await _wait(0.3)
	_check("flashlight", (player.get("_flashlight") as SpotLight3D).visible, "slot=%s on=%s" % [inv.equipped_slot(fl), player.flashlight_on])

	# ---------------------------------------------------------------- M5: navigation
	await _wait_nav()
	var map := (get_parent().get_world() as Node3D).get_world_3d().navigation_map
	var goal := Vector3(24.3, 2.95, 64.0)
	var from := NavigationServer3D.map_get_closest_point(map, Vector3(45, 0.1, 40))
	var to := NavigationServer3D.map_get_closest_point(map, goal)
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	var end := path[path.size() - 1] if path.size() > 0 else Vector3.ZERO
	_check("navmesh_path_upstairs", NavBaker.ready_for_navigation and path.size() > 2 and end.distance_to(goal) < 1.2,
		"points=%d end=%s" % [path.size(), end])

	# ---------------------------------------------------------------- M5: senses
	await _clear_zombies()
	GameTime.set_hour(12.0)
	# Open driveway in front of house 10: nothing blocks the view.
	await _reset_player(Vector3(30, 0.1, 51.5))
	var z := await _spawn_zombie(Vector3(38, 0.1, 51.5))
	z.yaw = -PI * 0.5
	await _wait(1.5)
	_check("zombie_sees_player", z.state == Zombie.State.CHASE or z.state == Zombie.State.ATTACK, z.state_name())
	var closest := INF
	for i in 14:
		await _wait(0.25)
		closest = minf(closest, z.global_position.distance_to(player.global_position))
	_check("zombie_chases", closest < 1.6, "closest=%.1f" % closest)
	await _wait(2.5)
	_check("zombie_attacks", player.health.health < player.health.max_health, "hp=%.0f" % player.health.health)
	if tour:
		await _shot("21_zombie_attack")
	await _clear_zombies()
	await _reset_player(Vector3(45, 0.1, 38))
	var deaf := await _spawn_zombie(Vector3(45, 0.1, 26))
	deaf.yaw = PI
	await _wait(1.0)
	_check("zombie_idle_unaware", deaf.state == Zombie.State.IDLE, deaf.state_name())
	NoiseSystem.emit(player.global_position, 20.0, player)
	await _wait(0.5)
	_check("zombie_hears_noise", deaf.state == Zombie.State.INVESTIGATE or deaf.state == Zombie.State.CHASE, deaf.state_name())
	await _wait(1.5)
	deaf._spot_player()
	await _reset_player(Vector3(40, 0.1, 3.0))
	await _wait(LOSE_WAIT)
	_check("zombie_loses_target", deaf.state in [Zombie.State.SEARCH, Zombie.State.IDLE, Zombie.State.INVESTIGATE], deaf.state_name())
	await _clear_zombies()
	# Group behaviour: an alerted zombie pulls its neighbours along.
	await _reset_player(Vector3(30, 0.1, 51.5))
	var lead := await _spawn_zombie(Vector3(38, 0.1, 51.5))
	lead.yaw = -PI * 0.5
	var mate := await _spawn_zombie(Vector3(43, 0.1, 50.5))
	mate.yaw = PI * 0.5
	await _wait(1.6)
	_check("zombie_alerts_group", mate.state != Zombie.State.IDLE, "lead=%s mate=%s" % [lead.state_name(), mate.state_name()])
	await _clear_zombies()

	# ---------------------------------------------------------------- M5: doors are bashed
	var edoor := _nearest_door(Vector3(40, 0.1, 56))
	edoor.set_open_state(false)
	await _reset_player(Vector3(40, 0.1, 58.5))
	var basher := await _spawn_zombie(Vector3(40, 0.1, 54.2))
	basher.last_seen = player.global_position
	basher.target_pos = player.global_position
	basher._set_state(Zombie.State.CHASE)
	var hp_door := edoor.health
	await _wait(5.0)
	_check("zombie_bashes_door", edoor.health < hp_door, "state=%s door=%.0f/%.0f" % [basher.state_name(), edoor.health, hp_door])
	await _clear_zombies()

	# ---------------------------------------------------------------- M6: melee
	await _reset_player(Vector3(45, 0.1, 40))
	var bat := inv.give("bat")
	inv.equip(bat)
	await _frames(2)
	_check("weapon_in_hand", (player.get("_hand_r") as Node3D).get_child_count() > 0)
	var dummy := await _spawn_zombie(Vector3(45, 0.1, 41.1))
	var swings := 0
	var dur0 := bat.durability
	while not dummy.is_dead() and swings < 25:
		dummy._attack_cd = 5.0
		player.face_towards(dummy.global_position - player.global_position)
		player.combat.try_attack(dummy.global_position)
		await _wait(bat.item.swing_time * 1.5 + 0.1)
		swings += 1
	_check("melee_kill", dummy.is_dead(), "swings=%d" % swings)
	_check("weapon_wear", bat.durability < dur0, "%.0f -> %.0f" % [dur0, bat.durability])
	_check("corpse_lootable", dummy.is_dead() and dummy.corpse != null and dummy.corpse.is_in_group("containers"))
	var down := await _spawn_zombie(Vector3(45, 0.1, 41.1))
	down.take_hit(1.0, Vector3.BACK, 1.0, 1.0, player)
	var dhp := down.health.health
	player.combat.try_attack(down.global_position)
	await _wait(1.2)
	_check("finish_downed", down.is_dead() or down.health.health < dhp - 20.0, "hp %.0f -> %.0f" % [dhp, down.health.health])
	if tour:
		await _shot("22_melee")
	await _clear_zombies()

	# ---------------------------------------------------------------- M6: pistol
	var gun := inv.give("pistol")
	gun.loaded = 0
	inv.give("ammo", 16)
	inv.equip(gun)
	player.combat.reload()
	await _wait(2.0)
	_check("reload", gun.loaded == 8 and inv.main.count_of("ammo") == 8, "loaded=%d" % gun.loaded)
	var target := await _spawn_zombie(Vector3(45, 0.1, 35.5))
	target._attack_cd = 99.0
	var heard := [false]
	var cb := func(_p: Vector3, r: float, _s: Node) -> void:
		if r >= 40.0:
			heard[0] = true
	Events.noise_emitted.connect(cb)
	var thp := target.health.health
	for i in 3:
		if target.is_dead():
			break
		player.combat.try_attack(target.global_position)
		await _wait(0.6)
	Events.noise_emitted.disconnect(cb)
	_check("gunshot", gun.loaded <= 7 and heard[0] and (target.is_dead() or target.health.health < thp), "loaded=%d hp=%.0f" % [gun.loaded, target.health.health])
	await _clear_zombies()

	# ---------------------------------------------------------------- M6: breaking a door, car alarm
	var axe := inv.give("axe")
	inv.equip(axe)
	var idoor: Door = null
	for d in get_tree().get_nodes_in_group("doors"):
		var dd := d as Door
		if dd.kind == Door.Kind.INTERIOR and dd.global_position.y < 0.5 and not dd.broken and dd.global_position.distance_to(Vector3(36, 0, 62)) < 8.0:
			idoor = dd
			break
	idoor.set_open_state(false)
	await _reset_player(idoor.global_position + idoor.global_basis.z * 0.9 + Vector3(0, 0.1, 0))
	var hits := 0
	while not idoor.broken and hits < 10:
		player.combat.try_attack(idoor.global_position + Vector3.UP)
		await _wait(axe.item.swing_time * 1.3 + 0.1)
		hits += 1
	_check("axe_breaks_door", idoor.broken, "hits=%d hp=%.0f" % [hits, idoor.health])
	var alarm := get_tree().get_nodes_in_group("car_alarms")[0] as CarAlarm
	var car := alarm.get_parent() as Node3D
	await _reset_player(car.global_position + car.global_basis.x * 1.7)
	player.combat.try_attack(car.global_position + Vector3.UP * 0.8)
	await _wait(1.2)
	_check("car_alarm", alarm.active)

	# ---------------------------------------------------------------- full town
	await _reset_player(Vector3(40, 0.1, 52))
	get_parent().get_world().get_node("Zombies").spawn_all(Settings.zombie_count)
	await _wait(3.0)
	var fps := Engine.get_frames_per_second()
	_check("fps_with_zombies", fps >= 30.0, "fps=%d zombies=%d" % [fps, get_tree().get_nodes_in_group("zombies").size()])
	if tour:
		await _teleport(Vector3(46, 0.1, 44))
		player.camera.get_parent().set("_zoom_target", 22.0)
		await _wait(4.0)
		await _shot("23_horde_courtyard")
		GameTime.set_hour(23.0)
		await _wait(0.8)
		await _shot("24_night_flashlight")


## Frame-time probe around the F9 admin panel (avg / worst ms), isometric and first person.
func _frame_stats(sec: float) -> Array:
	var worst := 0.0
	var total := 0.0
	var n := 0
	var last := Time.get_ticks_usec()
	var end := last + int(sec * 1000000.0)
	while Time.get_ticks_usec() < end:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000.0
		last = now
		worst = maxf(worst, dt)
		total += dt
		n += 1
	return [total / maxf(n, 1), worst]


func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)


func _probe_admin() -> void:
	await _wait(3.0)
	world.get_node("Zombies").call("spawn_all", 35)
	player.fp.test_mode = false
	await _wait(3.0)
	var admin := _hud().get("_admin") as Control
	for mode in [false, true]:
		world.call("set_first_person", mode)
		await _wait(1.5)
		var a: Array = await _frame_stats(2.0)
		var t0 := Time.get_ticks_usec()
		_key(KEY_F9)
		await get_tree().process_frame
		var t_open := (Time.get_ticks_usec() - t0) / 1000.0
		var b: Array = await _frame_stats(0.5)
		var c: Array = await _frame_stats(2.0)
		var shown: bool = admin.visible and bool(_hud().call("wants_mouse"))
		_key(KEY_F9)
		var d: Array = await _frame_stats(2.0)
		print("PROBE fp=%s panel+cursor=%s | closed avg %.1f max %.1f ms | F9 frame %.1f ms | first 0.5s max %.1f | open avg %.1f max %.1f | after avg %.1f max %.1f"
			% [mode, shown, a[0], a[1], t_open, b[1], c[0], c[1], d[0], d[1]])


func _probe_interactions() -> void:
	await _frames(15)
	world.get_node("Zombies").call("spawn_all", 35)
	world.call("set_first_person", true)
	await _frames(15)
	var doors := get_tree().get_nodes_in_group("doors")
	var windows := get_tree().get_nodes_in_group("windows")
	var containers := get_tree().get_nodes_in_group("containers")
	print("PROFILE_START doors=%d windows=%d containers=%d" % [doors.size(), windows.size(), containers.size()])
	# 1. Focus & LOS (get_own_rids + set_highlight) across 20 doors/windows/containers
	for i in mini(20, doors.size()):
		(doors[i] as Door).get_own_rids()
		(doors[i] as Door)._highlight_meshes()
	for i in mini(20, windows.size()):
		(windows[i] as WindowObj).get_own_rids()
		(windows[i] as WindowObj)._highlight_meshes()
	for i in mini(20, containers.size()):
		(containers[i] as LootContainer).get_own_rids()
		(containers[i] as LootContainer)._highlight_meshes()
	var t0 := Time.get_ticks_usec()
	for i in mini(20, doors.size()):
		var dr := doors[i] as Door
		var _r := dr.get_own_rids()
		dr.set_highlight(true)
		dr.set_highlight(false)
	for i in mini(20, windows.size()):
		var wn := windows[i] as WindowObj
		var _r := wn.get_own_rids()
		wn.set_highlight(true)
		wn.set_highlight(false)
	for i in mini(20, containers.size()):
		var ct := containers[i] as LootContainer
		var _r := ct.get_own_rids()
		ct.set_highlight(true)
		ct.set_highlight(false)
	var focus_ms := (Time.get_ticks_usec() - t0) / 1000.0
	# 2. Door open/close + Building multi-floor view switch
	var door := doors[0] as Door
	door.locked = false
	var t_door0 := Time.get_ticks_usec()
	door.perform("open", player)
	if District.instance and not District.instance.buildings.is_empty():
		var b9: Building = District.instance.buildings[-1]
		b9.reset_view()
		b9.set_view_first_person(true)
	var door_open_ms := (Time.get_ticks_usec() - t_door0) / 1000.0
	await get_tree().process_frame
	# 3. Window open + smash (glass shards spawn + material convert)
	var win := windows[0] as WindowObj
	var t_win0 := Time.get_ticks_usec()
	win.perform("open", player)
	win.perform("smash", player)
	var win_ms := (Time.get_ticks_usec() - t_win0) / 1000.0
	await get_tree().process_frame
	# 4. Crate / Container search + InventoryUI open + rescan across 1400+ containers
	var test_crate: LootContainer = null
	var normal_crate: LootContainer = null
	for c in containers:
		var lc := c as LootContainer
		if lc.container_type == "crate" and test_crate == null:
			test_crate = lc
		elif lc.container_type == "cupboard" and normal_crate == null:
			normal_crate = lc
	if normal_crate == null and not containers.is_empty():
		normal_crate = containers[0] as LootContainer
	var t_crate0 := Time.get_ticks_usec()
	if normal_crate:
		normal_crate.searched = false
		normal_crate.finish_search()
	var normal_crate_ms := (Time.get_ticks_usec() - t_crate0) / 1000.0
	await get_tree().process_frame
	var t_heavy0 := Time.get_ticks_usec()
	if test_crate:
		player.global_position = test_crate.global_position + Vector3(0, 0, 1.0)
		test_crate.finish_search()
		var inv_ui := _hud().get("_inventory") as Control
		for r in 5:
			inv_ui.call("_rescan", true)
			inv_ui.call("_refresh_left")
			inv_ui.call("_refresh_right")
	var heavy_crate_ms := (Time.get_ticks_usec() - t_heavy0) / 1000.0
	print("PROFILE_RESULT focus_60_ms=%.3f door_open_ms=%.3f window_smash_ms=%.3f normal_crate_ms=%.3f heavy_crate_5x_ms=%.3f"
		% [focus_ms, door_open_ms, win_ms, normal_crate_ms, heavy_crate_ms])


func _test_hot_update_and_live_debug() -> void:
	# 1. Verify LiveDebug custom monitors and interaction log
	_check("live_debug_monitors", Performance.has_custom_monitor("RZS/FrameTimeMs") and Performance.has_custom_monitor("RZS/DoorOpenMs"),
		"door=%.3fms win=%.3fms crate=%.3fms" % [LiveDebug.last_door_ms, LiveDebug.last_window_ms, LiveDebug.last_crate_ms])
	_check("live_debug_interaction_log", LiveDebug.interaction_log.size() >= 3, "entries=%d" % LiveDebug.interaction_log.size())
	LiveDebug.toggle_overlay()
	_check("live_debug_overlay", LiveDebug.overlay_visible, "overlay=true")
	LiveDebug.toggle_overlay()

	# 2. Verify Russian UpdateWindow UI & ASCII block bar + persistent completion/up-to-date/error states
	var uw: Variant = HotUpdate.update_window
	uw.show_update_start({"version": "0.5.3", "release_notes": "Тестовое обновление"})
	uw.set_progress(75.0, 7500, 10000, "0.5.3")
	uw._display_pct = 74.5
	uw._process(0.1)
	_check("update_window_ui", uw.visible and uw._ver_lbl.text == "Версия: 0.5.3" and uw._status_lbl.text == "Загрузка обновления: 75%" and uw._ascii_bar_lbl.text == "[██████████████░░░░]",
		"%s | %s" % [uw._status_lbl.text, uw._ascii_bar_lbl.text])
	uw.show_completed(true, "0.5.3", "Обновление v0.5.3 успешно установлено!")
	_check("update_window_persists_on_success", uw.visible and uw._status_lbl.text == "Обновление успешно установлено" and uw._close_btn.visible,
		uw._status_lbl.text)
	uw.show_up_to_date("0.5.3", 502)
	_check("update_window_up_to_date", uw.visible and uw._status_lbl.text == "Установлена последняя версия", uw._status_lbl.text)
	uw.show_completed(false, "0.5.1", "Таймаут подключения к серверу обновлений (TIMEOUT)", true)
	_check("update_window_shows_error", uw.visible and uw._wait_lbl.text.contains("TIMEOUT"), uw._wait_lbl.text)
	uw.hide_window()

	# 3. Save game before Hot Update to verify Save/Load preservation
	var saved_ok := SaveGame.save(world)
	_check("save_before_patch", saved_ok and SaveGame.exists(), SaveGame.path())

	# 4. Build a real delta .pck using PCKPacker
	var test_pck := "user://patches/autotest_delta.pck"
	var abs_pck := ProjectSettings.globalize_path(test_pck)
	var packer := PCKPacker.new()
	var err := packer.pck_start(abs_pck)
	var src_door := ProjectSettings.globalize_path("res://scripts/interaction/door.gd")
	packer.add_file("res://scripts/interaction/door.gd", src_door)
	packer.flush(true)
	var pck_sha := FileAccess.get_sha256(test_pck)
	var f := FileAccess.open(test_pck, FileAccess.READ)
	var pck_sz := int(f.get_length()) if f else 0
	if f:
		f.close()
	_check("delta_pck_built", err == OK and pck_sz > 64 and pck_sz < 65536, "size=%dB sha=%s" % [pck_sz, pck_sha.substr(0, 12)])

	# 5. Verify manifest security check (forged signature / hash rejected)
	var forged_manifest := {
		"version": "0.9.9",
		"build_number": 999,
		"min_apk_build": 500,
		"requires_apk_update": false,
		"pck_size": pck_sz,
		"sha256": pck_sha,
		"manifest_hash": "deadbeef00000000000000000000000000000000000000000000000000000000",
	}
	_check("forged_manifest_rejected", not HotUpdate.verify_manifest_security(forged_manifest), "forged_hash_blocked=true")

	# 6. Verify corrupt SHA-256 is rejected and old working version is kept
	var prev_ver := HotUpdate.current_version
	var bad_manifest := {
		"version": "0.9.9",
		"build_number": 999,
		"min_apk_build": 500,
		"pck_size": pck_sz,
		"sha256": "0000000000000000000000000000000000000000000000000000000000000000",
	}
	var bad_ok := HotUpdate.apply_downloaded_patch(test_pck, bad_manifest)
	_check("corrupt_patch_rejected", (not bad_ok) and HotUpdate.current_version == prev_ver, "kept_version=" + HotUpdate.current_version)

	# 7. If --update-url= is provided, test live HTTP manifest + PCK download + RSA-2048 verification!
	var custom_url := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--update-url="):
			custom_url = a.trim_prefix("--update-url=")
	if custom_url != "":
		var http_done := [false, false, ""]
		var fin_cb := func(applied: bool, ver: String, msg: String) -> void:
			http_done[0] = true
			http_done[1] = applied
			http_done[2] = "%s (%s)" % [ver, msg]
		HotUpdate.update_finished.connect(fin_cb)
		HotUpdate.check_for_updates(custom_url)
		var wait_t := 0.0
		while not http_done[0] and wait_t < 8.0:
			await get_tree().process_frame
			wait_t += get_process_delta_time()
		HotUpdate.update_finished.disconnect(fin_cb)
		_check("live_http_hot_update", http_done[1] and HotUpdate.current_build > 500, str(http_done[2]))
	else:
		# Rebuild valid temp PCK and apply locally with matching SHA-256
		var p2 := PCKPacker.new()
		p2.pck_start(abs_pck)
		p2.add_file("res://scripts/interaction/door.gd", src_door)
		p2.flush(true)
		var good_manifest := {
			"version": "0.5.2",
			"build_number": 502,
			"min_apk_build": 500,
			"pck_size": pck_sz,
			"sha256": pck_sha,
			"changed_files": ["res://scripts/interaction/door.gd"],
		}
		var good_ok := HotUpdate.apply_downloaded_patch(test_pck, good_manifest)
		_check("hot_update_applied", good_ok and HotUpdate.current_version == "0.5.2" and HotUpdate.current_build == 502,
			"version=%s build=%d" % [HotUpdate.current_version, HotUpdate.current_build])

	# 8. Verify Save/Load data is intact after Hot Update
	var loaded_ok := SaveGame.load_into(world)
	_check("save_preserved_after_patch", loaded_ok and SaveGame.exists(), "loaded=true")

	# 9. Verify offline mode (unreachable server does not break gameplay or lose current version)
	var cur_ver_before_offline := HotUpdate.current_version
	var off_done := [false]
	var off_cb := func(_applied: bool, _ver: String, _msg: String) -> void: off_done[0] = true
	HotUpdate.update_finished.connect(off_cb)
	HotUpdate.check_for_updates("http://127.0.0.1:59999/unreachable_manifest.json")
	var off_wait := 0.0
	while not off_done[0] and off_wait < 16.0:
		await get_tree().process_frame
		off_wait += get_process_delta_time()
	HotUpdate.update_finished.disconnect(off_cb)
	_check("offline_mode_safe", off_done[0] and HotUpdate.current_version == cur_ver_before_offline, "status=" + HotUpdate.status_text)

	# 10. Verify Native / APK update required detection (`min_apk_build > APK_BUILD_NUMBER`)
	var apk_req_triggered := [false]
	var cb := func(_m: Dictionary, _msg: String) -> void: apk_req_triggered[0] = true
	HotUpdate.apk_update_required.connect(cb)
	HotUpdate._evaluate_manifest({"version": "0.6.0", "build_number": 600, "min_apk_build": 600, "requires_apk_update": true, "apk_update_reason": "Изменен AndroidManifest"})
	HotUpdate.apk_update_required.disconnect(cb)
	_check("native_apk_requirement_detected", apk_req_triggered[0] and HotUpdate.current_version == cur_ver_before_offline, "status=" + HotUpdate.status_text)
	uw.hide_window()

	# Clean up test patch state so normal user boot starts clean
	if FileAccess.file_exists(HotUpdate.STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(HotUpdate.STATE_PATH))
	SaveGame.delete()
