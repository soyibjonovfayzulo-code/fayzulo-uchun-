extends RefCounted
## v0.5 first-person checks: camera in the eyes, own body hidden from the lens (legs visible), mouse
## look and camera-relative walking, crouch eye height, no cutaway with roofs and all floors visible,
## crosshair interaction, the view model (weapons, attacks, eating), aimed head shots, ADS, driving from
## the seat with the cabin and steering wheel, the sky and the backdrop beyond the map, the map edge,
## switching back to isometric. With `tour`, saves first-person screenshots tools/screens/fp_*.png.

var t: Node
var player: Player
var fp: FPCamera
var world: Node3D


func _init(owner_test: Node) -> void:
	t = owner_test
	player = t.player


func _aim_at(p: Vector3) -> void:
	var eye := fp.camera.global_position
	var d := (p - eye).normalized()
	fp.look_yaw = atan2(-d.x, -d.z)
	fp.look_pitch = asin(clampf(d.y, -1.0, 1.0))


func _eye_h() -> float:
	return fp.camera.global_position.y - player.global_position.y


func _press(action: String, sec: float) -> void:
	Input.action_press(action)
	await t._wait(sec)
	Input.action_release(action)


func run(standalone := false) -> void:
	world = t.get_parent().get_world() as Node3D
	await t._clear_zombies()
	GameTime.time_scale = 1.0
	GameTime.set_hour(12.0)
	if Climate.instance:
		Climate.instance.set_rain_now(0.0)
	world.call("set_first_person", true)
	fp = player.fp
	fp.test_mode = true
	var inv := player.inventory
	for slot in ["hand", "offhand"]:
		inv.unequip(slot)
	var d := District.instance
	await t._reset_player(d.spawn_point + Vector3(0, 0.1, 0))
	await t._wait(0.6)
	t._check("fp_camera", fp.active and fp.camera.current and fp.camera.projection == Camera3D.PROJECTION_PERSPECTIVE
		and player.camera == fp.camera, "fov=%.0f" % fp.camera.fov)
	t._check("fp_no_cutaway", VisibilityManager.cut_enabled < 0.5)
	var head_hidden := true
	var legs_visible := false
	for mi in player.model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var n: Node = m
		var under := ""
		while n and n != player.model:
			if n.name in ["Head", "Torso", "LegL", "ShinL"]:
				under = n.name
				break
			n = n.get_parent()
		if under == "Head" and m.layers != FPCamera.HIDDEN_LAYER:
			head_hidden = false
		if under == "ShinL" and m.layers == 1:
			legs_visible = true
	t._check("fp_body_hidden_legs_visible", head_hidden and legs_visible)
	var eh := _eye_h()
	t._check("fp_eye_height", eh > 1.4 and eh < 1.85, "eye=%.2f" % eh)
	# Mouse look turns the body with it.
	var y0 := fp.look_yaw
	fp.look(Vector2(300, 0))
	await t._wait(0.2)
	t._check("fp_mouse_look", absf(angle_difference(y0, fp.look_yaw)) > 0.4
		and absf(angle_difference(player.yaw, fp.look_yaw + PI)) < 0.05, "yaw %.2f -> %.2f" % [y0, fp.look_yaw])
	# W walks where you look.
	fp.look_yaw = -PI * 0.5
	fp.look_pitch = 0.0
	await t._wait(0.2)
	var p0 := player.global_position
	await _press("move_up", 1.2)
	await t._wait(0.3)
	var moved := player.global_position - p0
	t._check("fp_walk_forward", moved.x > 1.6 and absf(moved.z) < 0.6, "moved=%s" % moved)
	await t._press_action("crouch")
	await t._wait(0.9)
	var ec := _eye_h()
	t._check("fp_crouch_eye", player.crouching and ec < eh - 0.2, "eye %.2f -> %.2f" % [eh, ec])
	await t._press_action("crouch")
	await t._wait(0.5)
	if t.tour:
		_aim_at(d.buildings[0].global_position + Vector3(0, 8, 0))
		fp.look_pitch = 0.05
		await t._wait(0.4)
		await t._shot("fp_01_courtyard")

	# ---------------------------------------------------------------- inside an izba: roof and floors stay
	var house: Building = PrivateSector.houses[0]
	var stove: Campfire = null
	for c in t.get_tree().get_nodes_in_group("campfires"):
		if (c as Campfire).stove and house.is_ancestor_of(c):
			stove = c
	await t._reset_player(stove.global_position + stove.global_basis.z * 1.6 + Vector3(0, 0.1, 0))
	await t._wait(0.8)
	t._check("fp_roof_visible_inside", house.contains_point(player.global_position) and house.roof.visible
		and house.get_view() == 100, "view=%d" % house.get_view())
	_aim_at(stove.global_position + Vector3(0, 0.6, 0))
	await t._wait(0.4)
	t._check("fp_crosshair_focus", player.interactor.focused == stove,
		"focused=%s" % (player.interactor.focused.display_name if player.interactor.focused else "-"))
	fp.look_yaw += PI
	await t._wait(0.4)
	t._check("fp_focus_follows_view", player.interactor.focused != stove)
	if t.tour:
		_aim_at(stove.global_position + Vector3(0, 0.9, 0))
		await t._wait(0.3)
		await t._shot("fp_02_izba_stove")
		_aim_at(stove.global_position + Vector3(0, 2.4, 0))
		await t._wait(0.3)
		await t._shot("fp_03_izba_ceiling")

	# ---------------------------------------------------------------- melee from the eyes
	var street := Vector3(40, 0.1, 90)
	await t._reset_player(street)
	inv.equip(inv.give("bat"), "hand")
	await t._wait(0.6)
	var vm := fp.viewmodel
	t._check("fp_viewmodel_bat", vm.kind == "melee2" and vm.grip.get_child_count() > 0, "kind=%s" % vm.kind)
	fp.look_yaw = -PI * 0.5
	fp.look_pitch = -0.1
	await t._wait(0.2)
	var z: Zombie = await t._spawn_zombie(player.global_position + Vector3(1.15, 0.1, 0))
	z.set_physics_process(false)
	await t._wait(0.3)
	var hp0 := z.health.health
	var g0 := vm.grip.position
	var gmax := 0.0
	player.combat.try_attack(player.mouse_world_point())
	var t_end := Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < t_end:
		await t._frames(1)
		gmax = maxf(gmax, vm.grip.position.distance_to(g0))
		if t.tour and absf(player.combat.attack_t - 0.4) < 0.03:
			await t._shot("fp_04_bat_swing")
	await t._wait(0.5)
	# Swings can miss (tiredness, skill): a survivor would just swing again.
	var swings := 1
	while swings < 4 and not (z.health.health < hp0 or z.is_down() or z.is_dead()):
		player.stats.endurance = 1.0
		player.combat.try_attack(player.mouse_world_point())
		await t._wait(1.2)
		swings += 1
	t._check("fp_melee_hits", z.health.health < hp0 or z.is_down() or z.is_dead(), "hp %.0f -> %.0f in %d swings" % [hp0, z.health.health, swings])
	t._check("fp_swing_animates", gmax > 0.25, "grip moved %.2f" % gmax)
	await t._clear_zombies()

	# ---------------------------------------------------------------- aimed fire: head shot
	inv.unequip("hand")
	var pistol := inv.give("pistol")
	pistol.loaded = pistol.item.magazine
	inv.give("ammo", 20)
	inv.equip(pistol, "hand")
	player.skills["firearm"] = Skills.xp_for(10)
	await t._wait(0.5)
	t._check("fp_viewmodel_pistol", vm.kind == "pistol")
	var zp := player.global_position + Vector3(4.5, 0.1, 0)
	var z2: Zombie = await t._spawn_zombie(zp)
	z2.set_physics_process(false)
	await t._wait(0.4)
	Input.action_press("context_menu")
	_aim_at(z2.global_position + Vector3(0, 1.62, 0))
	await t._wait(0.6)
	var fov_ads := fp.camera.fov
	t._check("fp_ads", fp.aiming and fov_ads < GameOptions.fov - 12.0, "fov=%.0f" % fov_ads)
	if t.tour:
		await t._shot("fp_05_pistol_ads")
	_aim_at(z2.global_position + Vector3(0, 1.62, 0))
	player.combat.try_attack(player.mouse_world_point())
	await t._wait(0.5)
	Input.action_release("context_menu")
	t._check("fp_headshot", z2.is_dead() and player.combat.last_result == "head", "result=%s" % player.combat.last_result)
	var z3: Zombie = await t._spawn_zombie(zp + Vector3(0, 0, 1.5))
	z3.set_physics_process(false)
	await t._wait(0.4)
	var hp3 := z3.health.health
	_aim_at(z3.global_position + Vector3(0, 1.05, 0))
	await t._wait(0.3)
	player.combat.try_attack(player.mouse_world_point())
	await t._wait(0.5)
	t._check("fp_body_shot", z3.health.health < hp3 and player.combat.last_result == "hit", "hp %.0f -> %.0f %s" % [hp3, z3.health.health, player.combat.last_result])
	await t._clear_zombies()
	if t.tour:
		inv.unequip("hand")
		var sg := inv.give("shotgun")
		sg.loaded = sg.item.magazine
		inv.equip(sg, "hand")
		fp.look_yaw = -PI * 0.5
		fp.look_pitch = -0.05
		await t._wait(0.8)
		await t._shot("fp_06_shotgun")
	inv.unequip("hand")

	# ---------------------------------------------------------------- hands during timed actions
	player.start_timed_action("Едим тушёнку...", 3.0, func() -> void: pass)
	await t._wait(0.2)
	var r_low := vm.hand_r.position.y
	await t._wait(0.5)
	var r_high := vm.hand_r.position.y
	t._check("fp_eat_animation", vm._props.has("eat") and (vm._props["eat"] as Node3D).visible and r_high > r_low + 0.05,
		"hand y %.2f -> %.2f" % [r_low, r_high])
	if t.tour:
		await t._shot("fp_07_eating")
	player.cancel_action()
	await t._wait(0.3)

	# ---------------------------------------------------------------- flashlight at night
	GameTime.set_hour(23.0)
	var fl := inv.give("flashlight")
	fl.charge = 1.0
	inv.equip(fl, "offhand")
	player.flashlight_on = true
	await t._wait(0.6)
	var own_fl := player.get("_flashlight") as SpotLight3D
	t._check("fp_flashlight", fp.flashlight.visible and not own_fl.visible)
	if t.tour:
		inv.equip(inv.give("knife"), "hand")
		_aim_at(Vector3(52, 1.2, 90))
		await t._wait(0.6)
		await t._shot("fp_08_night_flashlight")
		inv.unequip("hand")
	inv.unequip("offhand")
	GameTime.set_hour(12.0)

	# ---------------------------------------------------------------- driving from the seat
	var car: Vehicle = null
	for v in t.get_tree().get_nodes_in_group("vehicles"):
		if (v as Vehicle).display_name.contains("охра"):
			car = v
	await t._reset_player(car.global_position + car.global_basis.x * 2.2 + Vector3(0, 0.1, 0))
	player.enter_vehicle(car)
	await t._wait(0.6)
	var eye_ok := fp.camera.global_position.distance_to(car.global_transform * FPCamera.DRIVER_EYE) < 0.5
	t._check("fp_drive_seat", player.state == Player.State.DRIVING and eye_ok and car.get("_interior") != null
		and (car.get("_interior") as Node3D).visible and car.wheel_grips().size() == 2)
	var sw := car.get("_steering") as Node3D
	var b0 := sw.basis
	Input.action_press("move_up")
	await _press("move_left", 0.8)
	Input.action_release("move_up")
	var turned := b0.get_rotation_quaternion().angle_to(sw.basis.get_rotation_quaternion())
	t._check("fp_steering_wheel_turns", turned > 0.3, "%.2f rad" % turned)
	var hd := vm.hand_r.global_position.distance_to(car.wheel_grips()[0])
	t._check("fp_hands_on_wheel", hd < 0.12, "dist=%.2f" % hd)
	if t.tour:
		GameTime.set_hour(19.6)
		car.headlights = true
		await t._wait(0.6)
		await t._shot("fp_09_driving")
		GameTime.set_hour(12.0)
	var settle := 0.0
	while absf(car.speed) > 0.3 and settle < 3.0:
		car.drive_input(0.0, 0.0, true, 0.1)
		await t._wait(0.1)
		settle += 0.1
	player.exit_vehicle()
	await t._wait(0.5)
	t._check("fp_exit_car", player.state == Player.State.NORMAL and not (car.get("_interior") as Node3D).visible)

	# ---------------------------------------------------------------- sky, horizon, map edge
	var env := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	t._check("fp_sky", env.background_mode == Environment.BG_SKY and env.sky != null and env.fog_enabled)
	var bd := world.get_node_or_null("Backdrop")
	var mm := 0
	if bd:
		mm = bd.find_children("*", "MultiMeshInstance3D", false, false).size()
	t._check("fp_backdrop_forest", bd != null and mm >= 20, "multimeshes=%d" % mm)
	await t._reset_player(Vector3(-8.0, 0.1, 100.0))
	fp.look_yaw = PI * 0.5
	fp.look_pitch = 0.0
	await t._wait(0.3)
	await _press("move_up", 3.0)
	await t._wait(0.3)
	t._check("fp_map_edge", player.global_position.x > -16.6 and player.global_position.y > -0.5, str(player.global_position))
	if t.tour:
		GameTime.set_hour(18.8)
		await t._reset_player(Vector3(-4.0, 0.1, 60.0))
		fp.look_yaw = PI * 0.5 + 0.3
		fp.look_pitch = 0.04
		await t._wait(0.8)
		await t._shot("fp_10_horizon_sunset")
		GameTime.set_hour(12.0)
		if Climate.instance:
			Climate.instance.set_rain_now(1.0)
		await t._reset_player(street)
		fp.look_yaw = -PI * 0.5
		fp.look_pitch = -0.02
		await t._wait(1.2)
		await t._shot("fp_11_rain_street")
		if Climate.instance:
			Climate.instance.set_rain_now(0.0)
		fp.look_pitch = -1.25
		Input.action_press("move_up")
		await t._wait(0.6)
		await t._shot("fp_12_look_down_legs")
		Input.action_release("move_up")

	# ---------------------------------------------------------------- back to isometric
	world.call("set_first_person", false)
	await t._reset_player(stove.global_position + stove.global_basis.z * 1.6 + Vector3(0, 0.1, 0))
	await t._wait(0.6)
	t._check("fp_toggle_back_iso", not fp.active and player.camera.projection == Camera3D.PROJECTION_ORTHOGONAL
		and VisibilityManager.cut_enabled > 0.5 and not house.roof.visible
		and env.background_mode == Environment.BG_COLOR)
	if standalone:
		world.call("set_first_person", true)
		await t._reset_player(street)
		await t._wait(0.5)
		var e0 := fp.camera.global_position.y
		player.health.take_damage(9999.0, null, "Тест")
		await t._wait(2.0)
		t._check("fp_death_camera_falls", fp.camera.global_position.y < e0 - 0.6, "%.2f -> %.2f" % [e0, fp.camera.global_position.y])
		if t.tour:
			await t._shot("fp_13_death")
	else:
		await t._reset_player(street)
	fp.test_mode = false


func _snap(n: String) -> void:
	await t._frames(1)
	var img := t.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://tools/screens/vm_%s.png" % n))


func _hold(id: String, slot := "hand") -> ItemStack:
	player.inventory.unequip(slot)
	if id == "":
		return null
	var st := player.inventory.give(id)
	if st.item.magazine > 0:
		st.loaded = st.item.magazine
	player.inventory.equip(st, slot)
	return st


func _pose(style: String, at: float) -> void:
	var c := player.combat
	c.set_physics_process(false)
	c.attack_style = style
	c.attack_t = at
	await t._frames(14)


func _unpose() -> void:
	var c := player.combat
	c.attack_t = -1.0
	c.attack_style = ""
	c.set_physics_process(true)
	await t._frames(14)


## `-- --fpvm`: close-ups of every hand and weapon pose (tools/screens/vm_*.png).
func vm_gallery() -> void:
	world = t.get_parent().get_world() as Node3D
	world.call("set_first_person", true)
	fp = player.fp
	fp.test_mode = true
	t.get_parent().get_node("UI").visible = false
	await t._clear_zombies()
	GameTime.set_hour(12.0)
	if Climate.instance:
		Climate.instance.set_rain_now(0.0)
	await t._reset_player(Vector3(40, 0.1, 90))
	fp.look_yaw = -PI * 0.5
	fp.look_pitch = -0.12
	await t._wait(1.0)
	await _snap("01_unarmed")
	await _pose("shove", 0.42)
	await _snap("02_shove")
	await _unpose()
	_hold("bat")
	await t._wait(0.8)
	await _snap("03_bat")
	await _pose("swing", 0.3)
	await _snap("04_bat_windup")
	await _pose("swing", 0.45)
	await _snap("05_bat_hit")
	await _pose("finish", 0.35)
	await _snap("06_bat_overhead")
	await _unpose()
	_hold("pipe")
	await t._wait(0.8)
	await _snap("07_pipe")
	_hold("knife")
	await t._wait(0.8)
	await _snap("08_knife")
	await _pose("stab", 0.45)
	await _snap("09_knife_stab")
	await _unpose()
	var fl := _hold("flashlight", "offhand")
	fl.charge = 1.0
	await t._wait(0.8)
	await _snap("10_knife_torch")
	player.inventory.unequip("offhand")
	_hold("pistol")
	await t._wait(0.8)
	await _snap("11_pistol")
	Input.action_press("context_menu")
	await t._wait(0.7)
	await _snap("12_pistol_ads")
	Input.action_release("context_menu")
	_hold("shotgun")
	await t._wait(0.8)
	await _snap("13_shotgun")
	Input.action_press("context_menu")
	await t._wait(0.7)
	await _snap("14_shotgun_ads")
	Input.action_release("context_menu")
	_hold("pistol")
	await t._wait(0.5)
	player.start_timed_action("Перезаряжаем...", 9.0, func() -> void: pass)
	await t._wait(0.6)
	await _snap("15_reload")
	player.cancel_action()
	_hold("")
	for spec in [["Едим тушёнку...", "16_eat"], ["Пьём воду...", "17_drink"], ["Перевязываем рану...", "18_bandage"],
			["Читать газету...", "19_read"], ["Заколачиваем окно...", "20_hammer"], ["Обыскиваем шкаф...", "21_search"]]:
		player.start_timed_action(spec[0], 9.0, func() -> void: pass)
		await t._wait(0.75)
		await _snap(spec[1])
		player.cancel_action()
		await t._wait(0.2)
	_hold("bat")
	await t._wait(0.5)
	Input.action_press("run")
	Input.action_press("move_up")
	await t._wait(0.8)
	await _snap("22_sprint_bat")
	Input.action_release("run")
	Input.action_release("move_up")


func _gallery_snap(n: String) -> void:
	await t._frames(8)
	var img := t.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://assets/ui/gallery/%s.png" % n))
	print("AUTOTEST SHOT ", n)


func _staged(p: Vector3, kinds: Array, offsets: Array, hunting := true) -> void:
	for i in offsets.size():
		var z: Zombie = await t._spawn_zombie(p + (offsets[i] as Vector3), kinds[i % kinds.size()])
		z.set_physics_process(false)
		z.animator.hunting = hunting
		z.animator.speed = 0.9
		z.yaw = atan2(-(offsets[i] as Vector3).x, -(offsets[i] as Vector3).z)
		z.model.rotation.y = z.yaw


## `-- --fps --fpgallery`: first-person frames without the HUD for the main menu slideshow.
func fp_gallery() -> void:
	world = t.get_parent().get_world() as Node3D
	world.call("set_first_person", true)
	fp = player.fp
	fp.test_mode = true
	t.get_parent().get_node("UI").visible = false
	var inv := player.inventory
	await t._clear_zombies()
	# 11: rainy street, bat in hand, three coming.
	GameTime.set_hour(16.5)
	if Climate.instance:
		Climate.instance.set_rain_now(1.0)
	await t._reset_player(Vector3(40, 0.1, 90))
	_hold("bat")
	await _staged(player.global_position, ["zombie_a", "zombie_c", "zombie_f"], [Vector3(4.5, 0.1, -0.6), Vector3(7.5, 0.1, 1.2), Vector3(11.0, 0.1, -1.5)])
	fp.look_yaw = -PI * 0.5
	fp.look_pitch = 0.02
	await t._wait(1.6)
	await _gallery_snap("11_fp_rain_bat")
	await t._clear_zombies()
	if Climate.instance:
		Climate.instance.set_rain_now(0.0)
	# 12: night, knife and flashlight, a figure under the lamp.
	GameTime.set_hour(23.2)
	await t._reset_player(Vector3(40, 0.1, 90))
	_hold("knife")
	var fl := _hold("flashlight", "offhand")
	fl.charge = 1.0
	player.flashlight_on = true
	await _staged(player.global_position, ["zombie_b", "zombie_d"], [Vector3(6.0, 0.1, 0.4), Vector3(13.0, 0.1, -2.0)])
	fp.look_yaw = -PI * 0.5 + 0.05
	fp.look_pitch = -0.03
	await t._wait(1.0)
	await _gallery_snap("12_fp_night_torch")
	await t._clear_zombies()
	inv.unequip("offhand")
	# 13: the forest at sunset.
	GameTime.set_hour(18.9)
	await t._reset_player(Vector3(-4.0, 0.1, 60.0))
	_hold("axe")
	fp.look_yaw = PI * 0.5 + 0.3
	fp.look_pitch = 0.06
	await t._wait(1.0)
	await _gallery_snap("13_fp_forest_sunset")
	# 14: behind the wheel at dusk.
	GameTime.set_hour(19.7)
	_hold("")
	var car: Vehicle = null
	for v in t.get_tree().get_nodes_in_group("vehicles"):
		if (v as Vehicle).display_name.contains("охра"):
			car = v
	await t._reset_player(car.global_position + car.global_basis.x * 2.2 + Vector3(0, 0.1, 0))
	player.enter_vehicle(car)
	car.headlights = true
	var ahead := car.global_position + car.global_basis.z * 9.0
	await _staged(ahead, ["zombie_a", "zombie_e"], [Vector3(0.5, 0.1, 0), Vector3(-1.8, 0.1, 2.5)])
	await t._wait(1.0)
	await _gallery_snap("14_fp_driving_dusk")
	player.exit_vehicle()
	await t._clear_zombies()
	# 15: morning mist in the courtyard, pistol raised.
	GameTime.set_hour(6.2)
	var d := District.instance
	await t._reset_player(d.spawn_point + Vector3(0, 0.1, 0))
	_hold("pistol")
	await _staged(player.global_position, ["zombie_c"], [Vector3(0.5, 0.1, -7.0)])
	Input.action_press("context_menu")
	fp.look_yaw = 0.0
	fp.look_pitch = 0.04
	await t._wait(1.0)
	await _gallery_snap("15_fp_mist_pistol")
	Input.action_release("context_menu")
	await t._clear_zombies()
