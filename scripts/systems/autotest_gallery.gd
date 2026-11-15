extends RefCounted
## `-- --gallery`: staged, HUD-free shots of the town for the main menu (assets/ui/gallery/*.png).

const OUT := "res://assets/ui/gallery/"

var t: Node
var player: Player


func _init(owner_test: Node) -> void:
	t = owner_test
	player = t.player


func _rig() -> Node:
	return player.camera.get_parent()


func _zoom(z: float) -> void:
	_rig().set("_zoom_target", z)
	_rig().set("zoom", z)


func _scene(pos: Vector3, hour: float, rain: float, zoom: float) -> void:
	if player.state == Player.State.DRIVING:
		player.exit_vehicle()
	GameTime.set_hour(hour)
	Climate.instance.set_rain_now(rain, 50.0)
	_zoom(zoom)
	await t._teleport(pos)


func _zombies(center: Vector3, n: int, radius: float, hunt := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x * 13 + center.z)
	for i in n:
		var a := rng.randf() * TAU
		var r := rng.randf_range(radius * 0.4, radius)
		var z: Zombie = await t._spawn_zombie(center + Vector3(cos(a) * r, 0.2, sin(a) * r), "")
		z.yaw = rng.randf() * TAU
		if hunt:
			z.last_seen = player.global_position
			z.target_pos = player.global_position
			z.call("_set_state", Zombie.State.CHASE)


func _save(name: String) -> void:
	await t._frames(8)
	var img := t.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("GALLERY ", name)


func run() -> void:
	t.get_parent().get_node("UI").visible = false
	Settings.invisible = true
	await t._clear_zombies()
	var inv := player.inventory
	inv.equip(inv.give("telogreika"))
	inv.equip(inv.give("backpack"))
	var bat := inv.give("bat")
	inv.equip(bat)
	# 1. Rainy night on ул. Строителей.
	await _scene(Vector3(52, 0.1, 88.5), 21.6, 0.85, 19.0)
	await _zombies(Vector3(56, 0.1, 89), 6, 8.0)
	await t._wait(3.0)
	await _save("01_street_rain_night")
	await t._clear_zombies()
	# 2. Sunset in the private sector.
	await _scene(Vector3(62, 0.1, 121), 18.7, 0.0, 22.0)
	await _zombies(Vector3(70, 0.1, 120), 3, 6.0)
	await t._wait(2.0)
	await _save("02_village_sunset")
	await t._clear_zombies()
	# 3. The quarantine checkpoint at night, barrel fire.
	await _scene(Vector3(132.5, 0.1, 69), 22.8, 0.0, 17.0)
	await _zombies(Vector3(136, 0.1, 64), 4, 5.0)
	await t._wait(2.5)
	await _save("03_checkpoint_night")
	await t._clear_zombies()
	# 4. Burned bus and a burning car at dusk.
	await _scene(Vector3(194, 0.1, 93.5), 19.7, 0.0, 16.0)
	await _zombies(Vector3(200, 0.1, 92), 3, 6.0)
	await t._wait(2.5)
	await _save("04_burned_bus_dusk")
	await t._clear_zombies()
	# 5. Inside an izba by the lit stove.
	var house: Building = PrivateSector.houses[2]
	var stove: Campfire = null
	for c in t.get_tree().get_nodes_in_group("campfires"):
		if (c as Campfire).stove and house.is_ancestor_of(c):
			stove = c
	if stove:
		stove.fuel_hours = 5.0
		stove.set_burning(true)
		await _scene(stove.global_position + stove.global_basis.z * 1.4 + Vector3(0, 0.1, 0), 22.0, 0.0, 11.0)
		await t._wait(1.5)
		await _save("05_izba_stove")
	# 6. Morning mist over the courtyard.
	await _scene(Vector3(42, 0.1, 40), 6.4, 0.0, 26.0)
	await t._wait(2.0)
	await _save("06_morning_mist")
	# 7. A horde closing in in the courtyard.
	await _scene(Vector3(43, 0.1, 33), 13.0, 0.0, 15.0)
	Settings.invisible = false
	await _zombies(player.global_position, 14, 7.0, true)
	await t._wait(1.6)
	player.combat.try_attack(player.global_position + player.get_facing_vector() * 2.0)
	await t._wait(0.28)
	await _save("07_horde_courtyard")
	Settings.invisible = true
	await t._clear_zombies()
	player.health.health = player.health.max_health
	player.wounds.list.clear()
	# 8. Night drive with headlights.
	var car: Vehicle = null
	for v in t.get_tree().get_nodes_in_group("vehicles"):
		if (v as Vehicle).key_id == "":
			car = v
	await _scene(Vector3(58, 0.1, 92.5), 23.2, 0.3, 15.0)
	car.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(56, 0.4, 91.6))
	car.linear_velocity = Vector3.ZERO
	await t._wait(0.5)
	car.door.perform("enter", player)
	await t._wait(0.6)
	Input.action_press("move_up")
	await t._wait(1.4)
	Input.action_release("move_up")
	await _zombies(car.global_position + Vector3(12, 0, 0), 3, 4.0)
	await t._wait(0.3)
	await _save("08_night_drive")
	player.exit_vehicle()
	await t._clear_zombies()
	# 9. The helicopter over the street.
	await _scene(Vector3(52, 0.1, 88.5), 14.5, 0.0, 24.0)
	var heli := HelicopterEvent.instance
	heli.begin()
	heli.global_position = player.global_position + HelicopterEvent.HOVER_OFFSET + Vector3(-6, 0, -6)
	await t._wait(4.0)
	await _zombies(player.global_position + Vector3(8, 0, -4), 8, 9.0, true)
	await t._wait(1.5)
	await _save("09_helicopter")
	heli.finish()
	await t._clear_zombies()
	# 10. Gas station at dusk.
	await _scene(Vector3(163, 0.1, 108), 19.9, 0.0, 20.0)
	await t._wait(2.0)
	await _save("10_gas_station_dusk")
	t.get_parent().get_node("UI").visible = true
	Settings.invisible = false
