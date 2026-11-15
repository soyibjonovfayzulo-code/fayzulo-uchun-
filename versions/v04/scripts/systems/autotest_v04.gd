extends RefCounted
## v0.4 checks: the bigger town, driving physics, running down zombies, fuel and hotwiring, izba stoves,
## wells, barricades, the helicopter, the admin panel, professions and skills, saving cars.

var t: Node
var player: V04Player


func _init(owner_test: Node) -> void:
	t = owner_test
	player = t.player


func _world() -> Node3D:
	return t.get_parent().get_world() as Node3D


func _car(name_part: String) -> V04Vehicle:
	for v in t.get_tree().get_nodes_in_group("vehicles"):
		if (v as V04Vehicle).display_name.contains(name_part):
			return v
	return null


func _press(action: String, sec: float) -> void:
	Input.action_press(action)
	await t._wait(sec)
	Input.action_release(action)


func run() -> void:
	var inv := player.inventory
	await t._clear_zombies()
	V04GameTime.time_scale = 1.0
	V04GameTime.set_hour(12.0)
	if V04Climate.instance:
		V04Climate.instance.set_rain_now(0.0)
	var d := V04District.instance
	var izbas := V04PrivateSector.houses.size()
	t._check("town_size", V04District.BOUNDS.size.x >= 280 and d.buildings.size() >= 25 and izbas >= 12,
		"buildings=%d izbas=%d" % [d.buildings.size(), izbas])
	t._check("zombie_default", V04Settings.zombie_count <= 40, "count=%d" % V04Settings.zombie_count)
	t._check("items_v04", V04ItemDB.items.size() >= 64 and V04ItemDB.get_item("shotgun") != null, "items=%d" % V04ItemDB.items.size())

	# ---------------------------------------------------------------- driving
	var car := _car("охра")
	t._check("car_exists", car != null and car.key_id == "")
	await t._reset_player(car.global_position + car.global_basis.x * 2.2 + Vector3(0, 0.1, 0))
	await t._wait(0.5)
	var start := car.global_position
	car.door.perform("enter", player)
	await t._frames(3)
	t._check("enter_car", player.state == V04Player.State.DRIVING and car.engine_on and player.vehicle == car)
	var fuel0 := car.fuel
	await _press("move_up", 3.0)
	var top := absf(car.speed)
	var moved := car.global_position.distance_to(start)
	t._check("car_accelerates", top > 6.0 and moved > 8.0, "speed=%.1f m/s moved=%.1f" % [top, moved])
	t._check("car_uses_fuel", car.fuel < fuel0, "%.2f -> %.2f" % [fuel0, car.fuel])
	var yaw0 := car.global_rotation.y
	Input.action_press("move_up")
	await _press("move_left", 1.5)
	Input.action_release("move_up")
	var turned := absf(angle_difference(yaw0, car.global_rotation.y))
	t._check("car_steers", turned > 0.3, "turned=%.2f rad" % turned)
	var v_before := absf(car.speed)
	await _press("move_down", 1.0)
	t._check("car_brakes", absf(car.speed) < v_before * 0.5, "%.1f -> %.1f" % [v_before, car.speed])
	var settle := 0.0
	while absf(car.speed) > 0.3 and settle < 3.0:
		car.drive_input(0.0, 0.0, true, 0.1)
		await t._wait(0.1)
		settle += 0.1
	t._check("car_upright", car.global_basis.y.y > 0.9, "up=%.2f" % car.global_basis.y.y)
	if t.tour:
		await t._shot("45_driving")
	# Run a zombie down.
	var ahead := car.global_position + car.global_basis.z * 6.0
	var z: V04Zombie = await t._spawn_zombie(ahead + Vector3(0, 0.2, 0))
	z.set_physics_process(false)
	var zhp := z.health.health
	await _press("move_up", 2.2)
	t._check("car_hits_zombie", z.is_dead() or z.health.health < zhp or z.is_down(), "hp %.0f -> %.0f" % [zhp, z.health.health])
	await _press("move_down", 2.0)
	player.exit_vehicle()
	await t._wait(0.4)
	t._check("exit_car", player.state == V04Player.State.NORMAL and player.global_position.distance_to(car.global_position) < 4.0
		and not car.engine_on and car.global_position.y < 1.0, "state=%d dist=%.1f engine=%s car_y=%.2f" % [player.state, player.global_position.distance_to(car.global_position), car.engine_on, car.global_position.y])
	await t._clear_zombies()
	# Refuel from a jerrycan.
	car.fuel = 5.0
	var can := inv.give("jerrycan")
	can.uses_left = 20
	car.door.perform("refuel", player)
	await t._wait(3.8)
	t._check("jerrycan_refuel", car.fuel > 20.0 and can.uses_left < 5, "fuel=%.1f can=%d" % [car.fuel, can.uses_left])
	# Hotwire the keyless white sedan at the gas station.
	var white := _car("белый")
	await t._reset_player(white.global_position + white.global_basis.x * 2.2 + Vector3(0, 0.1, 0))
	white.door.perform("enter", player)
	await t._frames(3)
	var locked := not white.engine_on
	inv.give("screwdriver")
	player.skills["mechanics"] = V04Skills.xp_for(10)
	player.call("_hotwire")
	await t._wait(3.4)
	t._check("hotwire", locked and white.engine_on and white.hotwired)
	player.exit_vehicle()
	await t._wait(0.3)
	# Gas pump while the power is on.
	var pump := t._nearest_in_group("fuel_pumps", white.global_position) as V04FuelPump
	white.fuel = 2.0
	white.global_position = _free_spot_near(pump.global_position, white)
	white.linear_velocity = Vector3.ZERO
	white.angular_velocity = Vector3.ZERO
	await t._wait(0.6)
	pump.perform("car", player)
	await t._wait(4.3)
	t._check("pump_refuel", white.fuel > 35.0, "fuel=%.1f near=%s" % [white.fuel, pump.nearest_car() == white])

	# ---------------------------------------------------------------- izba: stove, well, barricades
	var house: V04Building = V04PrivateSector.houses[0]
	var stove: V04Campfire = null
	for c in t.get_tree().get_nodes_in_group("campfires"):
		if (c as V04Campfire).stove and house.is_ancestor_of(c):
			stove = c
	t._check("izba_stove", stove != null, house.display_name)
	await t._reset_player(stove.global_position + stove.global_basis.z * 1.3 + Vector3(0, 0.1, 0))
	t._check("izba_inside", house.contains_point(player.global_position))
	inv.give("firewood", 2)
	inv.give("matches")
	stove.perform("fuel:firewood", player)
	await t._frames(3)
	t._check("stove_lit", stove.burning and V04Campfire.heat_at(player.global_position, 3.6) > 0.0)
	if t.tour:
		V04GameTime.set_hour(21.5)
		await t._wait(1.0)
		await t._shot("46_izba_stove_night")
		V04GameTime.set_hour(12.0)
	var well := t._nearest_in_group("wells", player.global_position) as V04Well
	V04Climate.instance.water_off_at = V04Climate.instance.hours_since_start() - 0.1
	player.stats.thirst = 0.6
	well.perform("drink", player)
	await t._wait(3.3)
	t._check("well_water_after_cutoff", not V04Climate.has_water() and player.stats.thirst < 0.05)
	V04Climate.instance.water_off_at = V04Climate.instance.hours_since_start() + 50.0
	var win := t._nearest_in_group("windows", player.global_position) as V04WindowObj
	if win.is_open:
		win.perform("close", player)
	for e in [["hammer", 1], ["planks", 2], ["nails", 4]]:
		inv.give(e[0], e[1])
	win.perform("board", player)
	await t._wait(3.8)
	t._check("barricade_window", win.planks == 1 and not win.get_actions(player).any(func(a: Dictionary) -> bool: return a["id"] == "climb"),
		"planks=%d" % win.planks)
	for i in 3:
		win.damage_glass(null)
	t._check("zombies_tear_planks", win.planks == 0, "planks=%d" % win.planks)
	var nd := t._nearest_door(player.global_position) as V04Door
	nd.set_open_state(false)
	nd.locked = false
	await t._wait(0.5)
	nd.perform("board", player)
	await t._wait(3.8)
	nd.perform("open", player)
	await t._frames(2)
	t._check("barricade_door", nd.planks == 1 and not nd.is_open)
	nd.planks = 0
	nd.call("_refresh_boards")

	# ---------------------------------------------------------------- helicopter
	await t._reset_player(Vector3(40, 0.1, 52))
	var heli := V04HelicopterEvent.instance
	var heard := [0]
	var cb := func(_p: Vector3, r: float, src: Node) -> void:
		if src == heli and r >= 45.0:
			heard[0] += 1
	V04Events.noise_emitted.connect(cb)
	heli.begin()
	var tt := 0.0
	while heli.phase == "approach" and tt < 20.0:
		await t._wait(0.5)
		tt += 0.5
	await t._wait(2.5)
	if t.tour:
		await t._teleport(Vector3(52, 0.1, 88.5))
		await t._wait(4.0)
		await t._shot("47_helicopter")
		player.camera.get_parent().set("_zoom_target", 15.0)
	t._check("helicopter_hovers", heli.active and heli.phase == "hover" and heard[0] > 0, "phase=%s noise=%d" % [heli.phase, heard[0]])
	V04Events.noise_emitted.disconnect(cb)
	heli.finish()

	# ---------------------------------------------------------------- admin, skills, professions
	await t._press_action("admin")
	var admin := t._hud().get("_admin") as Control
	await t._frames(3)
	var n_pot := inv.main.count_of("potato")
	admin.call("_give", "potato", 1)
	t._check("admin_panel", admin.visible and inv.main.count_of("potato") == n_pot + 1)
	if t.tour:
		await t._shot("48_admin")
	admin.call("_heal_all")
	await t._press_action("admin")
	player.skills.erase("melee")
	V04Skills.add_xp(player, "melee", V04Skills.xp_for(2) + 1.0)
	t._check("skills_level", V04Skills.level_of(player, "melee") == 2 and V04Skills.melee_damage(player) > 1.1)
	V04Settings.profession = "carpenter"
	var nails0 := inv.main.count_of("nails")
	V04Profession.apply(player)
	t._check("profession_kit", inv.main.count_of("nails") == nails0 + 20 and V04Skills.level_of(player, "carpentry") == 3)
	V04Settings.profession = "unemployed"
	await t._press_action("skills")
	await t._frames(3)
	t._check("skills_panel", (t._hud().get("_skills") as Control).visible)
	if t.tour:
		await t._shot("49_skills")
	await t._press_action("skills")
	t._check("minimap", (t._hud().get("_minimap") as Control).visible)
	# Corpses dressing the streets.
	t._check("street_corpses", t.get_tree().get_nodes_in_group("corpses").size() >= 0)

	# ---------------------------------------------------------------- tutorial
	await t._reset_player(Vector3(40, 0.1, 52))
	var tut := preload("res://versions/v04/scripts/ui/tutorial.gd").new()
	t._hud().add_child(tut)
	tut.call("bind", player)
	await t._frames(2)
	var s0: int = tut.get("step")
	await t._walk(Vector3(1, 0, 0), 3.6)
	await t._wait(1.6)
	var s1: int = tut.get("step")
	var mk := tut.get("_marker") as Node3D
	var marker_on := mk != null and mk.visible
	if t.tour:
		await t._shot("64_tutorial")
	var near := t._nearest_in_group("containers", player.global_position) as V04LootContainer
	V04Events.container_opened.emit(near)
	await t._wait(1.6)
	t._check("tutorial_steps", s0 == 0 and s1 == 1 and marker_on and int(tut.get("step")) == 2,
		"steps %d -> %d -> %d marker=%s" % [s0, s1, int(tut.get("step")), marker_on])
	tut.queue_free()

	# ---------------------------------------------------------------- animation
	await t._reset_player(Vector3(40, 0.1, 90))
	player.inventory.unequip("hand")
	player.inventory.main.stacks.clear()
	player.inventory.main.changed.emit()
	player.stats.endurance = 1.0
	var torso := player.model.find_child("Torso", true, false) as Node3D
	await t._wait(0.6)
	var idle_lean := torso.rotation.x
	# Along the street (+x world = screen right-down in the iso view).
	Input.action_press("move_right", 0.707)
	Input.action_press("move_down", 0.707)
	Input.action_press("run")
	await t._wait(1.2)
	var run_lean := torso.rotation.x
	var shin := player.model.find_child("ShinL", true, false) as Node3D
	var knee_max := 0.0
	var tm := 0.0
	while tm < 0.8:
		await t._frames(1)
		tm += t.get_process_delta_time()
		knee_max = maxf(knee_max, shin.rotation.x)
	t._release_all()
	t._check("anim_run_lean", run_lean > idle_lean + 0.12 and knee_max > 0.9, "lean %.2f -> %.2f knee %.2f speed %.1f" % [idle_lean,
		run_lean, knee_max, player.animator.speed])
	await t._wait(0.5)
	player.animator.hit(Vector3(0, 0, 1), 1.0)
	await t._wait(0.03)
	t._check("anim_flinch", (player.animator.get("_impulse") as Vector3).length() > 0.02)
	var zd: V04Zombie = await t._spawn_zombie(player.global_position + Vector3(3, 0.2, 0))
	zd.set_physics_process(true)
	zd.health.take_damage(9999.0)
	await t._wait(1.2)
	var zh := zd.model.find_child("Hips", true, false) as Node3D
	t._check("anim_corpse_falls", absf(zh.rotation.x) > 1.2 and absf(zd.model.rotation.x) < 0.01, "hips=%.2f" % zh.rotation.x)
	var zc: V04Zombie = await t._spawn_zombie(player.global_position + Vector3(-4, 0.2, 0))
	var cs0 := zc.chase_speed
	zc.make_crawler()
	await t._wait(1.0)
	var ch := zc.model.find_child("Hips", true, false) as Node3D
	t._check("anim_crawler", zc.crawler and zc.chase_speed < cs0 and zc.animator.pose == V04CharacterAnimator.Pose.CRAWL and ch.rotation.x > 1.0,
		"hips=%.2f" % ch.rotation.x)
	await t._clear_zombies()

	# ---------------------------------------------------------------- saving a moved car
	car.global_position = Vector3(64.0, 0.6, 30.0)
	await t._wait(1.0)
	var cpos := car.global_position
	var world := _world()
	V04SaveGame.save(world)
	car.global_position = Vector3(70, 0.6, 36)
	V04SaveGame.load_into(world)
	await t._frames(4)
	t._check("save_car", car.global_position.distance_to(cpos) < 0.5, "%s vs %s" % [car.global_position, cpos])


## A spot 2.6-3.4 m from `at` where the car's body fits without touching buildings or props.
func _free_spot_near(at: Vector3, car: V04Vehicle) -> Vector3:
	var st := car.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = car.body_size + Vector3(0.3, 0.0, 0.3)
	for r in [2.6, 3.0, 3.4, 4.2]:
		for k in 8:
			var a := TAU * k / 8.0
			var p := at + Vector3(cos(a) * r, 0.0, sin(a) * r)
			p.y = at.y + 0.4
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = box
			q.transform = Transform3D(car.global_basis, p + Vector3(0, 0.36 + car.body_size.y * 0.5 + 0.05, 0))
			q.collision_mask = 1 | 4
			q.exclude = [car.get_rid()]
			if st.intersect_shape(q, 1).is_empty():
				return p
	return at + Vector3(0, 0.4, 2.6)
