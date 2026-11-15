extends Node
## Scripted in-engine checks that drive the real player through input actions.
## Prints "AUTOTEST PASS/FAIL <name>" lines and quits. With `tour`, also saves screenshots.

var tour := false
var player: V04Player
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
			V04GameTime.set_hour(float(p[4]))
		if p.size() > 5:
			player.camera.get_parent().set("_zoom_target", float(p[5]))
			player.camera.get_parent().set("zoom", float(p[5]))
		if p.size() > 6 and V04Climate.instance:
			V04Climate.instance.set_rain_now(float(p[6]))
		await _teleport(Vector3(float(p[0]), float(p[1]), float(p[2])))
		await _wait(0.4)
		await _shot(p[3])
	return any


func _run() -> void:
	await _frames(10)
	world = get_parent().get_world()
	player = get_tree().get_first_node_in_group("player") as V04Player
	if await _quick_shots():
		get_tree().quit(0)
		return
	if "--poses" in OS.get_cmdline_user_args():
		await _poses()
		get_tree().quit(0)
		return
	if "--loadcheck" in OS.get_cmdline_user_args():
		await preload("res://versions/v04/scripts/systems/autotest_m78.gd").new(self).loadcheck()
		_finish()
		return
	if "--gallery" in OS.get_cmdline_user_args():
		await preload("res://versions/v04/scripts/systems/autotest_gallery.gd").new(self).run()
		get_tree().quit(0)
		return
	if "--v04" in OS.get_cmdline_user_args():
		await preload("res://versions/v04/scripts/systems/autotest_v04.gd").new(self).run()
		_finish()
		return
	if "--m78" in OS.get_cmdline_user_args():
		await preload("res://versions/v04/scripts/systems/autotest_m78.gd").new(self).run()
		_finish()
		return
	var d := V04District.instance
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
		V04Events.context_menu_requested.emit(focused, focused.get_actions(player))
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
	var cont := _nearest_in_group("containers", player.global_position) as V04LootContainer
	if cont:
		cont.perform("search", player)
		await _wait(cont.search_time + 0.4)
		_check("container_open", cont.is_open and cont.searched, cont.display_name)
	var seat := _nearest_seat(player.global_position)
	if seat:
		seat.perform("sit", player)
		await _wait(0.6)
		_check("sit", player.state == V04Player.State.SEATED, seat.display_name)
		player.stand_up()
		await _wait(0.6)
		_check("stand_up", player.state == V04Player.State.NORMAL)
	var tv := _nearest_use(player.global_position, V04Furniture.Use.TV)
	if tv:
		tv.perform("tv", player)
		_check("tv_on", tv.tv_on)
		tv.perform("tv", player)
	var bed := _nearest_use(player.global_position, V04Furniture.Use.BED)
	if bed:
		await _teleport(bed.global_position + bed.global_basis.x * 0.9 + Vector3(0, 0.05, 0))
		bed.perform("lie", player)
		await _wait(0.6)
		_check("lie_on_bed", player.state == V04Player.State.SEATED and player.animator.pose == V04CharacterAnimator.Pose.LIE)
		player.stand_up()
		await _wait(0.6)
	if tour:
		await _teleport(Vector3(26.3, 0.1, 64.0))
		await _shot("04_flat_living_room")
		await _teleport(Vector3(24.0, 0.1, 57.6))
		await _shot("05_flat_kitchen")

	# --- window: smash ground-floor kitchen window from inside and climb out.
	var win := _nearest_in_group("windows", Vector3(23.3, 1.0, 56.0)) as V04WindowObj
	if win:
		await _teleport(win.global_position + win.global_basis.z * -0.9 + Vector3(0, -0.85, 0))
		win.perform("smash", player)
		await _wait(0.3)
		_check("window_smash", win.is_broken)
		win.perform("clear", player)
		win.perform("climb", player)
		await _wait(1.6)
		var outside := not b3.contains_point(player.global_position)
		_check("window_climb_out", outside and player.state == V04Player.State.NORMAL, str(player.global_position))

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
		V04GameTime.set_hour(22.5)
		await _wait(0.6)
		await _shot("10_street_night")
		V04GameTime.set_hour(19.5)
		await _teleport(Vector3(40, 0.1, 48))
		await _wait(0.6)
		await _shot("11_courtyard_evening")
		V04GameTime.set_hour(12.0)
		await _teleport(Vector3(91.0, 0.1, 22.0))
		await _shot("12_nine_storey")
		await _teleport(Vector3(42, 0.1, 3.0))
		await _shot("13_behind_house12_cut")

	await _m456()
	# v0.4 first: the M7-8 run ends with the survivor's death and reanimation.
	await preload("res://versions/v04/scripts/systems/autotest_v04.gd").new(self).run()
	await preload("res://versions/v04/scripts/systems/autotest_m78.gd").new(self).run()
	_finish()


func _finish() -> void:
	var failed := _results.filter(func(r: Array) -> bool: return not r[1]).size()
	print("AUTOTEST DONE %d/%d passed" % [_results.size() - failed, _results.size()])
	V04GameTime.time_scale = 1.0
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
		var z: V04Zombie = await _spawn_zombie(Vector3(44.5 - g * 1.6 + g * 0.9, 0.1, 35.5 - g * 1.6 - g * 0.9), "zombie_%s" % ["a", "b", "c", "g"][g])
		z.set_physics_process(false)
		z.animator.gait = g as V04CharacterAnimator.Gait
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
		(z as V04Zombie).animator.hunting = true
	await _wait(0.7)
	await _shot("pose_zombie_reach")
	var zz: V04Zombie = zs[0]
	zz.animator.attack_style = "grab"
	for f in [["reach", 0.35], ["bite", 0.57]]:
		zz.animator.attack_t = f[1]
		await _wait(0.25)
		await _shot("pose_zombie_" + f[0])
	zz.animator.attack_t = -1.0
	var cr: V04Zombie = zs[1]
	cr.make_crawler()
	cr.animator.pose = V04CharacterAnimator.Pose.CRAWL
	cr.animator.speed = 0.5
	var fall: V04Zombie = zs[2]
	fall.animator.pose = V04CharacterAnimator.Pose.DEAD
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


func _nearest_use(p: Vector3, use: V04Furniture.Use) -> V04Furniture:
	var best: V04Furniture = null
	for n in get_tree().get_nodes_in_group("interactables"):
		if n is V04Furniture and (n as V04Furniture).use == use:
			if best == null or (n as Node3D).global_position.distance_to(p) < best.global_position.distance_to(p):
				best = n
	return best


func _nearest_door(p: Vector3) -> V04Door:
	return _nearest_in_group("doors", p) as V04Door


func _nearest_seat(p: Vector3) -> V04Furniture:
	var best: V04Furniture = null
	for n in get_tree().get_nodes_in_group("interactables"):
		if n is V04Furniture and (n as V04Furniture).use == V04Furniture.Use.SEAT:
			if best == null or (n as Node3D).global_position.distance_to(p) < best.global_position.distance_to(p):
				best = n
	return best


# ================================================================================================ M4-M6
const LOSE_WAIT := 8.0


func _hud() -> Node:
	return get_parent().get_node("UI/HUD")


func _spawn_zombie(p: Vector3, kind := "zombie_a") -> V04Zombie:
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	var z := V04Zombie.spawn(get_parent().get_world().get_node("Zombies"), p, rng, kind)
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
	while not V04NavBaker.ready_for_navigation and t < 60.0:
		await _wait(0.5)
		t += 0.5


func _m456() -> void:
	var inv := player.inventory
	# ---------------------------------------------------------------- test room: every item, piles of ammo
	var crates := get_tree().get_nodes_in_group("containers").filter(func(c: Node) -> bool:
		return (c as V04LootContainer).container_type == "crate" and (c as V04LootContainer).display_name.begins_with("Ящик:"))
	var have := {}
	var ammo := 0
	for c in crates:
		for s in (c as V04LootContainer).inventory.stacks:
			have[s.item.id] = true
			if s.item.id == "ammo":
				ammo += s.count
	_check("test_room_all_items", crates.size() == 3 and have.size() == V04ItemDB.items.size() and ammo >= 500,
		"crates=%d items=%d/%d ammo=%d" % [crates.size(), have.size(), V04ItemDB.items.size(), ammo])
	if tour:
		await _teleport(Vector3(45.5, 0.1, 46.0))
		crates[0].perform("search", player)
		await _wait(0.8)
		await _shot("25_test_room")
		_hud().get("_inventory").call("close")
	# ---------------------------------------------------------------- M4: data
	_check("item_db", V04ItemDB.items.size() >= 45 and V04ItemDB.tables.size() >= 20,
		"items=%d tables=%d" % [V04ItemDB.items.size(), V04ItemDB.tables.size()])
	_check("starting_kit", inv.main.find_by_id("water") != null and inv.main.count_of("bandage") == 2)
	inv.give("tushenka", 3)
	inv.give("tushenka", 2)
	var tush := inv.main.find_by_id("tushenka")
	_check("stacking", tush != null and tush.count == 5 and inv.main.stacks.filter(func(s: V04ItemStack) -> bool: return s.item.id == "tushenka").size() == 1)
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
		return (c as V04LootContainer).container_type == "shelf" and (c as V04LootContainer).room_type == "shop")
	var total := 0
	for c in shelves:
		total += (c as V04LootContainer).inventory.stacks.size() if (c as V04LootContainer).searched else 0
	var fresh := get_tree().get_nodes_in_group("containers").filter(func(c: Node) -> bool:
		return (c as V04LootContainer).room_type == "kitchen" and not (c as V04LootContainer).searched and (c as V04LootContainer).container_type == "fridge")
	var fridge := fresh[0] as V04LootContainer
	fridge.ensure_loot()
	var ids := fridge.inventory.stacks.map(func(s: V04ItemStack) -> String: return s.item.id)
	_check("loot_by_room", ids.all(func(id: String) -> bool: return id in V04ItemDB.tables["kitchen_fridge"].item_ids), str(ids))
	var shelf := _nearest_in_group("containers", player.global_position) as V04LootContainer
	var ui: Control = _hud().get("_inventory")
	shelf.perform("search", player)
	await _wait(0.2)
	_check("search_timed", player.action_progress() >= 0.0, "progress=%.2f" % player.action_progress())
	await _wait(shelf.search_time + 0.3)
	_check("search_opens_ui", shelf.searched and ui.visible, shelf.display_name)
	for c in shelves:
		(c as V04LootContainer).ensure_loot()
		total += (c as V04LootContainer).inventory.stacks.size()
	_check("shop_loot", shelves.size() >= 8 and total >= 10, "shelves=%d stacks=%d" % [shelves.size(), total])
	if tour:
		await _wait(0.3)
		await _shot("20_inventory_loot")
	if not shelf.inventory.stacks.is_empty():
		var s0: V04ItemStack = shelf.inventory.stacks[0]
		ui.call("_move", s0, "loot", "player", -1)
		_check("ui_transfer_to_player", not shelf.inventory.has(s0) and inv.main.stacks.any(func(s: V04ItemStack) -> bool: return s.item == s0.item))
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
	_check("navmesh_path_upstairs", V04NavBaker.ready_for_navigation and path.size() > 2 and end.distance_to(goal) < 1.2,
		"points=%d end=%s" % [path.size(), end])

	# ---------------------------------------------------------------- M5: senses
	await _clear_zombies()
	V04GameTime.set_hour(12.0)
	# Open driveway in front of house 10: nothing blocks the view.
	await _reset_player(Vector3(30, 0.1, 51.5))
	var z := await _spawn_zombie(Vector3(38, 0.1, 51.5))
	z.yaw = -PI * 0.5
	await _wait(1.5)
	_check("zombie_sees_player", z.state == V04Zombie.State.CHASE or z.state == V04Zombie.State.ATTACK, z.state_name())
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
	_check("zombie_idle_unaware", deaf.state == V04Zombie.State.IDLE, deaf.state_name())
	V04NoiseSystem.emit(player.global_position, 20.0, player)
	await _wait(0.5)
	_check("zombie_hears_noise", deaf.state == V04Zombie.State.INVESTIGATE or deaf.state == V04Zombie.State.CHASE, deaf.state_name())
	await _wait(1.5)
	deaf._spot_player()
	await _reset_player(Vector3(40, 0.1, 3.0))
	await _wait(LOSE_WAIT)
	_check("zombie_loses_target", deaf.state in [V04Zombie.State.SEARCH, V04Zombie.State.IDLE, V04Zombie.State.INVESTIGATE], deaf.state_name())
	await _clear_zombies()
	# Group behaviour: an alerted zombie pulls its neighbours along.
	await _reset_player(Vector3(30, 0.1, 51.5))
	var lead := await _spawn_zombie(Vector3(38, 0.1, 51.5))
	lead.yaw = -PI * 0.5
	var mate := await _spawn_zombie(Vector3(43, 0.1, 50.5))
	mate.yaw = PI * 0.5
	await _wait(1.6)
	_check("zombie_alerts_group", mate.state != V04Zombie.State.IDLE, "lead=%s mate=%s" % [lead.state_name(), mate.state_name()])
	await _clear_zombies()

	# ---------------------------------------------------------------- M5: doors are bashed
	var edoor := _nearest_door(Vector3(40, 0.1, 56))
	edoor.set_open_state(false)
	await _reset_player(Vector3(40, 0.1, 58.5))
	var basher := await _spawn_zombie(Vector3(40, 0.1, 54.2))
	basher.last_seen = player.global_position
	basher.target_pos = player.global_position
	basher._set_state(V04Zombie.State.CHASE)
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
	V04Events.noise_emitted.connect(cb)
	var thp := target.health.health
	for i in 3:
		if target.is_dead():
			break
		player.combat.try_attack(target.global_position)
		await _wait(0.6)
	V04Events.noise_emitted.disconnect(cb)
	_check("gunshot", gun.loaded <= 7 and heard[0] and (target.is_dead() or target.health.health < thp), "loaded=%d hp=%.0f" % [gun.loaded, target.health.health])
	await _clear_zombies()

	# ---------------------------------------------------------------- M6: breaking a door, car alarm
	var axe := inv.give("axe")
	inv.equip(axe)
	var idoor: V04Door = null
	for d in get_tree().get_nodes_in_group("doors"):
		var dd := d as V04Door
		if dd.kind == V04Door.Kind.INTERIOR and dd.global_position.y < 0.5 and not dd.broken and dd.global_position.distance_to(Vector3(36, 0, 62)) < 8.0:
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
	var alarm := get_tree().get_nodes_in_group("car_alarms")[0] as V04CarAlarm
	var car := alarm.get_parent() as Node3D
	await _reset_player(car.global_position + car.global_basis.x * 1.7)
	player.combat.try_attack(car.global_position + Vector3.UP * 0.8)
	await _wait(1.2)
	_check("car_alarm", alarm.active)

	# ---------------------------------------------------------------- full town
	await _reset_player(Vector3(40, 0.1, 52))
	get_parent().get_world().get_node("Zombies").spawn_all(V04Settings.zombie_count)
	await _wait(3.0)
	var fps := Engine.get_frames_per_second()
	_check("fps_with_zombies", fps >= 30.0, "fps=%d zombies=%d" % [fps, get_tree().get_nodes_in_group("zombies").size()])
	if tour:
		await _teleport(Vector3(46, 0.1, 44))
		player.camera.get_parent().set("_zoom_target", 22.0)
		await _wait(4.0)
		await _shot("23_horde_courtyard")
		V04GameTime.set_hour(23.0)
		await _wait(0.8)
		await _shot("24_night_flashlight")
