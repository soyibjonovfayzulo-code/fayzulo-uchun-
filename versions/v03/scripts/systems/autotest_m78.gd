extends RefCounted
## Milestone 7-8 checks (survival, weather, cooking, sleep, utilities, saving, reanimation), driven by
## the main autotest node `t` (its helpers: _check, _wait, _frames, _teleport, _reset_player...).

const EXPECT := "user://saves/expect.json"

var t: Node
var player: V03Player


func _init(owner_test: Node) -> void:
	t = owner_test
	player = t.player


func _world() -> Node3D:
	return t.get_parent().get_world() as Node3D


func _hud() -> Node:
	return t._hud()


func _nearest(group: String, p: Vector3, filter := Callable()) -> Node3D:
	var best: Node3D = null
	for n in t.get_tree().get_nodes_in_group(group):
		if filter.is_valid() and not filter.call(n):
			continue
		var n3 := n as Node3D
		if best == null or n3.global_position.distance_to(p) < best.global_position.distance_to(p):
			best = n3
	return best


func _has_action(acts: Array, id: String) -> bool:
	return acts.any(func(a: Dictionary) -> bool: return a["id"] == id)


func _fresh_player(p: Vector3) -> void:
	player.stats.poison = 0.0
	player.stats.panic = 0.0
	player.stats.drowsiness = 0.2
	player.stats.hunger = 0.2
	player.stats.thirst = 0.2
	player.body_temp.temp = V03BodyTemperature.NORMAL
	player.body_temp.wetness = 0.0
	player.wounds.antibiotic_hours = 0.0
	player.wounds.infection_hours = 0.0
	V03GameTime.time_scale = 1.0
	await t._reset_player(p)


func _hours(scale: float, sec: float) -> void:
	V03GameTime.time_scale = scale
	await t._wait(sec)
	V03GameTime.time_scale = 1.0


func run() -> void:
	var inv := player.inventory
	var c := V03Climate.instance
	await t._clear_zombies()
	V03GameTime.set_hour(12.0)
	await _fresh_player(Vector3(40, 0.1, 50))
	c.set_rain_now(0.0)
	t._check("climate", c != null and c.power_on() and c.outside_temp() > 0.0 and c.outside_temp() < 25.0,
		"air=%.1f power_off_at=%.1fh" % [c.outside_temp(), c.power_off_at])
	t._check("item_db_v03", V03ItemDB.items.size() >= 55 and V03ItemDB.get_item("pot_navy") != null, "items=%d" % V03ItemDB.items.size())

	# ---------------------------------------------------------------- weather, cold, clothing
	inv.unequip("body")
	V03GameTime.set_hour(3.0)
	c.set_rain_now(1.0)
	var t0 := player.body_temp.temp
	await _hours(40.0, 4.0)
	t._check("rain_soaks", player.body_temp.wetness > 0.5, "wet=%.2f rain=%.2f" % [player.body_temp.wetness, c.rain])
	t._check("cold_drops_body_temp", player.body_temp.temp < t0 - 0.5, "%.2f -> %.2f felt=%.1f" % [t0, player.body_temp.temp, player.body_temp.felt])
	await t._frames(4)
	var key: String = (_hud().get("_moodles") as Control).get_meta("key", "")
	t._check("cold_moodle", "Прохладно" in key or "Холодно" in key, key.left(160))
	if t.tour:
		player.camera.get_parent().set("_zoom_target", 18.0)
		V03GameTime.set_hour(14.0)
		await t._wait(1.2)
		await t._shot("31_rain_day")
		V03GameTime.set_hour(3.5)
		await t._frames(4)
	var felt_bare := player.body_temp.felt
	inv.equip(inv.give("telogreika"))
	await t._frames(3)
	t._check("clothing_warms", player.body_temp.felt > felt_bare + 3.0, "felt %.1f -> %.1f" % [felt_bare, player.body_temp.felt])

	# ---------------------------------------------------------------- campfire
	inv.give("firewood", 2)
	inv.give("newspaper")
	inv.give("matches")
	t._check("campfire_offered", _has_action(player.self_actions.get_actions(player), "campfire"))
	player.self_actions.perform("campfire", player)
	await t._wait(4.6)
	var fire := _nearest("campfires", player.global_position) as V03Campfire
	t._check("campfire_built", fire != null and fire.burning and fire.fuel_hours > 1.0,
		"fuel=%.2f" % (fire.fuel_hours if fire else -1.0))
	c.set_rain_now(0.0)
	var wet0 := player.body_temp.wetness
	await _hours(30.0, 3.0)
	t._check("fire_dries_and_warms", V03Campfire.heat_at(player.global_position, V03BodyTemperature.FIRE_RADIUS) > 0.0
		and player.body_temp.wetness < wet0 - 0.2, "wet %.2f -> %.2f" % [wet0, player.body_temp.wetness])

	# ---------------------------------------------------------------- cooking on the fire
	for id in ["pot", "buckwheat", "tushenka", "can_opener"]:
		inv.give(id)
	if inv.main.find_by_id("water") == null:
		inv.give("water")
	t._check("campfire_recipes", _has_action(fire.get_actions(player), "cook:pot_navy"))
	fire.perform("cook:pot_navy", player)
	await t._wait(V03Cooking.COOK_SECONDS + 0.6)
	var dish := inv.main.find_by_id("pot_navy")
	t._check("cooked_navy", dish != null and inv.main.find_by_id("pot") == null and inv.main.find_by_id("buckwheat") == null,
		"dish=%s" % (dish.get_name() if dish else "none"))
	if t.tour:
		V03GameTime.set_hour(23.0)
		player.camera.get_parent().set("_zoom_target", 11.0)
		await t._wait(1.5)
		await t._shot("32_campfire_night")
		player.camera.get_parent().set("_zoom_target", 15.0)
	if dish:
		dish.uses_left = 1
		player.stats.hunger = 0.7
		player.use_item(dish)
		await t._wait(2.4)
	t._check("eat_dish_returns_pot", player.stats.hunger < 0.6 and inv.main.find_by_id("pot") != null
		and inv.main.find_by_id("pot_navy") == null, "hunger=%.2f" % player.stats.hunger)

	# ---------------------------------------------------------------- tins need an opener
	for st in inv.main.stacks.duplicate():
		if st.item.id == "can_opener" or "cut" in st.item.tags or "screw" in st.item.tags:
			inv.main.remove(st)
	inv.give("kilka")
	var n_k := inv.main.count_of("kilka")
	player.use_item(inv.main.find_by_id("kilka"))
	await t._wait(3.0)
	t._check("tin_needs_opener", inv.main.count_of("kilka") == n_k, "kilka=%d" % inv.main.count_of("kilka"))
	inv.give("can_opener")
	player.use_item(inv.main.find_by_id("kilka"))
	await t._wait(3.0)
	t._check("tin_with_opener", inv.main.count_of("kilka") == n_k - 1)

	# ---------------------------------------------------------------- spoilage, fridges, poisoning
	var saus := inv.give("sausage")
	var was_fresh := saus.freshness() == V03ItemStack.Fresh.FRESH
	V03Spoilage.age_inventory(inv.main, 80.0)
	t._check("food_rots", was_fresh and saus.freshness() == V03ItemStack.Fresh.ROTTEN and "испорчено" in saus.get_name(), saus.get_name())
	inv.main.remove(saus)
	var fridge := _nearest("containers", Vector3(40, 0, 60), func(x: Node) -> bool: return (x as V03LootContainer).container_type == "fridge") as V03LootContainer
	fridge.ensure_loot()
	var fs := V03ItemDB.make("sausage")
	fridge.inventory.add(fs, true)
	V03Spoilage.tick(t.get_tree(), 4.0, true)
	var powered_age := fs.age
	V03Spoilage.tick(t.get_tree(), 4.0, false)
	t._check("fridge_slows_spoilage", is_equal_approx(powered_age, 1.0) and is_equal_approx(fs.age, 5.0),
		"age %.2f / %.2f" % [powered_age, fs.age])
	fridge.inventory.remove(fs)
	seed(4242)
	var tries := 0
	while player.stats.poison <= 0.0 and tries < 5:
		var rs := inv.give("sausage")
		rs.age = 100.0
		player.use_item(rs)
		await t._wait(2.4)
		tries += 1
	var hp1 := player.health.health
	await _hours(30.0, 2.0)
	var key2: String = (_hud().get("_moodles") as Control).get_meta("key", "")
	t._check("rotten_food_poisons", player.stats.poison > 0.0 and player.health.health < hp1 and "Отравление" in key2,
		"poison=%.2f hp %.1f -> %.1f" % [player.stats.poison, hp1, player.health.health])
	player.stats.poison = 0.0

	# ---------------------------------------------------------------- kitchen: tap and gas stove
	var sink := _nearest("containers", Vector3(40, 0, 60), func(x: Node) -> bool:
		return (x as V03LootContainer).has_tap and (x as Node3D).global_position.y < 1.0) as V03LootContainer
	inv.give("empty_bottle")
	var sacts := sink.get_actions(player)
	t._check("sink_actions", _has_action(sacts, "fill") and _has_action(sacts, "drink_tap"), str(sacts.map(func(a: Dictionary) -> String: return a["id"])))
	var waters0 := inv.main.count_of("water")
	sink.perform("fill", player)
	await t._wait(3.4)
	t._check("tap_fills_bottle", inv.main.count_of("water") == waters0 + 1 and inv.main.find_by_id("empty_bottle") == null,
		"water %d -> %d" % [waters0, inv.main.count_of("water")])
	var stove := _nearest("containers", sink.global_position, func(x: Node) -> bool: return (x as V03LootContainer).container_type == "oven") as V03LootContainer
	inv.give("macaroni")
	t._check("stove_recipes", _has_action(stove.get_actions(player), "cook:pot_macaroni"))
	stove.perform("cook:pot_macaroni", player)
	await t._wait(V03Cooking.COOK_SECONDS + 0.6)
	t._check("stove_cooks", inv.main.find_by_id("pot_macaroni") != null)

	# ---------------------------------------------------------------- wounds on body parts, health window
	await _fresh_player(Vector3(40, 0.1, 50))
	var w := player.wounds.add("laceration")
	t._check("wound_body_part", w["part"] in V03Wounds.PARTS, w["part"])
	inv.give("bandage")
	await t._press_action("health")
	var panel := _hud().get("_health_panel") as Control
	await t._frames(3)
	t._check("health_panel", panel.visible and (panel.get("_list") as Control).get_child_count() > 0)
	if t.tour:
		await t._shot("33_health_panel")
	var btn: Button = null
	for b in (panel.get("_list") as Control).find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Перевязать:"):
			btn = b
	var found := btn != null
	if btn:
		btn.pressed.emit()
	await t._wait(3.4)
	t._check("panel_bandages", found and not player.wounds.is_bleeding(), str(player.wounds.list))
	await t._press_action("health")

	# ---------------------------------------------------------------- festering wound and antibiotics
	player.wounds.list.clear()
	var lw := player.wounds.add("laceration", "Левая рука")
	seed(77)
	var n := 0
	while not lw["festering"] and n < 26:
		player.wounds.process_hours(1.0, 0.0)
		n += 1
	var fever := player.wounds.fever()
	t._check("wound_festers", lw["festering"] and fever > 0.0, "hours=%d fever=+%.1f" % [n, fever])
	player.use_item(inv.give("antibiotics"))
	await t._wait(1.8)
	var m := 0
	while lw["festering"] and m < 24:
		player.wounds.process_hours(1.0, 0.0)
		m += 1
	t._check("antibiotics_cure", player.wounds.antibiotic_hours > 0.0 and not lw["festering"], "hours=%d" % m)
	player.wounds.list.clear()

	# ---------------------------------------------------------------- panic
	await _fresh_player(Vector3(40, 0.1, 50))
	await t._spawn_zombie(player.global_position + Vector3(2.5, 0, 0))
	await t._wait(2.5)
	t._check("panic_near_zombies", player.stats.panic > 0.1, "panic=%.2f" % player.stats.panic)
	await t._clear_zombies()

	# ---------------------------------------------------------------- coffee, pills, sleep
	player.stats.drowsiness = 0.6
	player.use_item(inv.give("coffee"))
	await t._wait(2.4)
	t._check("coffee_wakes", player.stats.drowsiness < 0.4, "drowsy=%.2f" % player.stats.drowsiness)
	player.stats.drowsiness = 0.05
	var blocked := player.sleep.blocker() != ""
	player.use_item(inv.give("sleeping_pills"))
	await t._wait(1.8)
	t._check("pills_allow_sleep", blocked and player.sleep.blocker() == "", player.sleep.blocker())
	player.sleep.set("_pill", false)
	var bed := t._nearest_use(Vector3(40, 0, 60), V03Furniture.Use.BED) as V03Furniture
	await _fresh_player(bed.global_position + Vector3(0, 0.1, 0))
	player.stats.drowsiness = 0.1
	bed.perform("sleep", player)
	await t._frames(3)
	t._check("sleep_needs_drowsiness", not player.is_sleeping())
	player.stats.drowsiness = 0.85
	var before := V03GameTime.total_minutes
	bed.perform("sleep", player)
	await t._frames(3)
	var slept := player.is_sleeping() and V03GameTime.time_scale > 30.0
	await t._wait(1.2)
	var overlay := (_hud().get("_sleep_overlay") as Control).visible
	if t.tour:
		await t._shot("34_sleep")
	var tt := 0.0
	while player.is_sleeping() and tt < 40.0:
		await t._wait(0.5)
		tt += 0.5
	await t._wait(0.6)
	var hours := (V03GameTime.total_minutes - before) / 60.0
	t._check("sleep_in_bed", slept and overlay and not player.is_sleeping() and player.stats.drowsiness < 0.1 and hours > 4.0,
		"hours=%.1f drowsy=%.2f reason=%s" % [hours, player.stats.drowsiness, player.sleep.wake_reason])
	t._check("woke_up_standing", player.state == V03Player.State.NORMAL and V03GameTime.time_scale == 1.0)
	await _fresh_player(Vector3(40, 0.1, 50))
	player.stats.drowsiness = 0.9
	player.self_actions.perform("sleep_floor", player)
	await t._frames(3)
	var floor_sleep := player.is_sleeping()
	await t._spawn_zombie(player.global_position + Vector3(4.5, 0, 0))
	await t._wait(1.0)
	t._check("zombie_wakes_sleeper", floor_sleep and not player.is_sleeping() and ("Зомби" in player.sleep.wake_reason or "шум" in player.sleep.wake_reason), player.sleep.wake_reason)
	await t._clear_zombies()
	await t._wait(0.5)

	# ---------------------------------------------------------------- lit windows at night while the power works
	V03GameTime.total_minutes = (V03GameTime.START_HOUR + 14.5) * 60.0  # day 1, 23:00
	await t._frames(6)
	var lit := t.get_tree().get_nodes_in_group("room_lights").filter(func(l: Node) -> bool: return (l as Light3D).light_energy > 0.5).size()
	t._check("room_lights_at_night", c.power_on() and lit >= 8, "lit=%d of %d night=%.2f" % [lit,
		t.get_tree().get_nodes_in_group("room_lights").size(), V03DayNight.night])
	if t.tour:
		await t._teleport(Vector3(46, 0.1, 44))
		player.camera.get_parent().set("_zoom_target", 26.0)
		await t._wait(1.2)
		await t._shot("35_lit_windows_night")
		player.camera.get_parent().set("_zoom_target", 15.0)
	V03GameTime.set_hour(12.0)

	# ---------------------------------------------------------------- save / load
	await _fresh_player(Vector3(41.5, 0.1, 50.5))
	var world := _world()
	var sdoor := t._nearest_door(Vector3(40, 0, 56)) as V03Door
	sdoor.locked = false
	sdoor.set_open_state(true)
	var swin := _nearest("windows", Vector3(33, 1.5, 56), func(x: Node) -> bool: return not (x as V03WindowObj).is_broken) as V03WindowObj
	swin.perform("smash", player)
	var scont := _nearest("containers", Vector3(40, 0, 60), func(x: Node) -> bool: return (x as V03LootContainer).container_type == "wardrobe") as V03LootContainer
	scont.ensure_loot()
	scont.inventory.add(V03ItemDB.make("antibiotics"), true)
	player.drop_item(inv.give("pipe"))
	player.stats.hunger = 0.42
	player.wounds.add("scratch", "Шея")
	await t._spawn_zombie(Vector3(30, 0.1, 40))
	var zb: V03Zombie = await t._spawn_zombie(Vector3(31, 0.1, 40))
	zb.health.take_damage(1000.0)
	await t._wait(0.5)
	var n_z := t.get_tree().get_nodes_in_group("zombies").size()
	var n_c := t.get_tree().get_nodes_in_group("corpses").size()
	var ppos := player.global_position
	var saved := V03SaveGame.save(world)
	t._check("save_written", saved and V03SaveGame.exists() and not V03SaveGame.summary().is_empty())
	var expect := {"door": str(world.get_path_to(sdoor)), "window": str(world.get_path_to(swin)),
		"cont": str(world.get_path_to(scont)), "pos": [ppos.x, ppos.y, ppos.z], "zombies": n_z, "corpses": n_c,
		"time": V03GameTime.total_minutes}
	var f := FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify(expect))
	f.close()
	# Wreck the state, then load.
	sdoor.set_open_state(false)
	player.stats.hunger = 0.9
	player.wounds.list.clear()
	await t._teleport(Vector3(60, 0.1, 40))
	await t._clear_zombies()
	for wi in t.get_tree().get_nodes_in_group("world_items"):
		wi.queue_free()
	scont.inventory.stacks.clear()
	await t._frames(2)
	V03SaveGame.load_into(world)
	await t._frames(6)
	t._check("load_restores_player", player.global_position.distance_to(ppos) < 0.6 and absf(player.stats.hunger - 0.42) < 0.01
		and player.wounds.list.size() == 1 and player.wounds.list[0]["part"] == "Шея",
		"pos=%s hunger=%.2f wounds=%d" % [player.global_position, player.stats.hunger, player.wounds.list.size()])
	var pipe_back := t.get_tree().get_nodes_in_group("world_items").any(func(x: Node) -> bool: return (x as V03WorldItem).stack.item.id == "pipe")
	t._check("load_restores_world", sdoor.is_open and swin.is_broken and scont.inventory.find_by_id("antibiotics") != null and pipe_back)
	t._check("load_restores_zombies", t.get_tree().get_nodes_in_group("zombies").size() == n_z and t.get_tree().get_nodes_in_group("corpses").size() == n_c,
		"zombies=%d/%d corpses=%d/%d" % [t.get_tree().get_nodes_in_group("zombies").size(), n_z, t.get_tree().get_nodes_in_group("corpses").size(), n_c])
	var save_text := FileAccess.get_file_as_string(V03SaveGame.path())
	await t._clear_zombies()

	# ---------------------------------------------------------------- utilities shut off
	V03GameTime.total_minutes = (V03GameTime.START_HOUR + c.gas_off_at + 1.0) * 60.0
	var h := V03GameTime.get_hour_f()
	if h > 5.0 and h < 21.5:
		V03GameTime.total_minutes += (23.0 - h) * 60.0
	await t._frames(8)
	var lamps_dark := t.get_tree().get_nodes_in_group("street_lamps").all(func(l: Node) -> bool: return (l as Light3D).light_energy == 0.0)
	var rooms_dark := t.get_tree().get_nodes_in_group("room_lights").all(func(l: Node) -> bool: return (l as Light3D).light_energy == 0.0)
	t._check("power_outage", not c.power_on() and not c.water_on() and not c.gas_on() and lamps_dark and rooms_dark,
		"day=%d %s" % [V03GameTime.get_day(), V03GameTime.get_clock_text()])
	var tv := t._nearest_use(Vector3(40, 0, 60), V03Furniture.Use.TV) as V03Furniture
	tv.perform("tv", player)
	inv.give("pot")
	inv.give("buckwheat")
	if inv.main.find_by_id("water") == null:
		inv.give("water")
	var stove_acts := stove.get_actions(player)
	player.stats.thirst = 0.5
	sink.perform("drink_tap", player)
	await t._wait(3.3)
	t._check("utilities_gone", not tv.tv_on and _has_action(stove_acts, "nogas") and not _has_action(stove_acts, "cook:pot_buckwheat")
		and player.stats.thirst >= 0.5, "tv=%s thirst=%.2f" % [tv.tv_on, player.stats.thirst])
	if t.tour:
		await t._teleport(Vector3(46, 0.1, 44))
		player.camera.get_parent().set("_zoom_target", 26.0)
		await t._wait(1.2)
		await t._shot("36_blackout_night")
		player.camera.get_parent().set("_zoom_target", 15.0)

	# ---------------------------------------------------------------- infection: fever, death, reanimation
	V03GameTime.set_hour(13.0)
	await _fresh_player(Vector3(40, 0.1, 50))
	V03Settings.reanimate_seconds = 1.0
	player.wounds.infected = true
	player.wounds.infection_hours = V03Settings.infection_hours_to_death * 0.5
	await _hours(60.0, 4.0)
	t._check("infection_fever", player.wounds.symptoms() == "Жар" and player.body_temp.temp > 37.2,
		"%s %.1f" % [player.wounds.symptoms(), player.body_temp.temp])
	player.health.take_damage(1000.0, null, "Зомби-вирус")
	await t._wait(2.0)
	var rz := player.reanimated_as as V03Zombie
	t._check("infected_reanimates", rz != null and rz.is_in_group("zombies") and rz.variant == "player" and not player.model.visible)
	await t._wait(0.6)
	var death := _hud().get("_death") as Control
	var title := (_hud().get("_death_title") as Label).text
	t._check("death_screen", death.visible and title == "ВЫ ОБРАТИЛИСЬ", title)
	if t.tour:
		await t._shot("37_reanimated")
	# Death deletes the save; put it back for the cross-session load check.
	t._check("death_deletes_save", not V03SaveGame.exists())
	var sf := FileAccess.open(V03SaveGame.path(), FileAccess.WRITE)
	sf.store_string(save_text)
	sf.close()


## Second process (`-- --loadcheck`): the save written by the autotest must restore the same world.
func loadcheck() -> void:
	await t._wait(1.0)
	var e = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	if typeof(e) != TYPE_DICTIONARY:
		t._check("loadcheck_expect", false, "no expect.json")
		return
	var world := _world()
	var door := world.get_node_or_null(NodePath(e["door"])) as V03Door
	var win := world.get_node_or_null(NodePath(e["window"])) as V03WindowObj
	var cont := world.get_node_or_null(NodePath(e["cont"])) as V03LootContainer
	var p: Array = e["pos"]
	t._check("loadcheck_paths", door != null and win != null and cont != null, "%s | %s" % [e["door"], e["window"]])
	t._check("loadcheck_world", door != null and door.is_open and win != null and win.is_broken and cont != null
		and cont.inventory.find_by_id("antibiotics") != null)
	t._check("loadcheck_player", player.global_position.distance_to(Vector3(p[0], p[1], p[2])) < 0.6
		and absf(player.stats.hunger - 0.42) < 0.02 and player.wounds.list.size() == 1,
		"pos=%s hunger=%.2f" % [player.global_position, player.stats.hunger])
	t._check("loadcheck_zombies", t.get_tree().get_nodes_in_group("zombies").size() == int(e["zombies"])
		and t.get_tree().get_nodes_in_group("corpses").size() == int(e["corpses"]),
		"z=%d c=%d" % [t.get_tree().get_nodes_in_group("zombies").size(), t.get_tree().get_nodes_in_group("corpses").size()])
	t._check("loadcheck_time", absf(V03GameTime.total_minutes - float(e["time"])) < 5.0, V03GameTime.get_clock_text())
