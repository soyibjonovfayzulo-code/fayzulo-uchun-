class_name V03SaveGame
extends RefCounted
## World save (JSON in user://saves/): the clock, sandbox settings, weather, the survivor (stats, wounds,
## inventory, equipment), every door/window/container/car alarm that changed, items on the ground,
## campfires, and all zombies and corpses. The district itself is rebuilt procedurally and identically,
## so world objects are matched by their node path. One slot; death deletes it (permadeath, like PZ).

const DIR := "user://saves"
const PATH := "user://saves/dev.json"
## Automated tests never touch the player's own save.
const TEST_PATH := "user://saves/autotest.json"
const VERSION := 1


static func path() -> String:
	for a in OS.get_cmdline_user_args():
		if a in ["--autotest", "--tour", "--m78", "--loadcheck"]:
			return TEST_PATH
	return PATH


static func exists() -> bool:
	return FileAccess.file_exists(path())


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path()))


## Short description for the menu: {"day", "clock", "saved_at"} or {}.
static func summary() -> Dictionary:
	if not exists():
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path()))
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	var minutes := float(d.get("time", 0.0))
	return {"day": V03GameTime.START_DAY + int(minutes / 1440.0), "clock": "%02d:%02d" % [int(fmod(minutes / 60.0, 24.0)), int(fmod(minutes, 60.0))],
		"saved_at": str(d.get("saved_at", "")), "kills": int((d.get("player", {}) as Dictionary).get("kills", 0))}


static func settings_dict() -> Dictionary:
	var out := {}
	for k in ["infection_chance_bite", "infection_chance_scratch", "infection_chance_laceration", "infection_hours_to_death",
			"zombie_count", "zombie_speed", "zombie_damage", "loot_rarity", "test_room", "utilities_off_day", "weather",
			"world_seed", "day_length_minutes", "start_hour"]:
		out[k] = V03Settings.get(k)
	return out


static func save(world: Node3D) -> bool:
	var player := world.get_node("Player") as V03Player
	if player == null or player.state == V03Player.State.DEAD:
		return false
	if player.is_sleeping():
		player.sleep.wake("")
	var d := {"version": VERSION, "saved_at": Time.get_datetime_string_from_system(false, true),
		"time": V03GameTime.total_minutes, "settings": settings_dict(), "player": player.save_state()}
	var climate := world.get_node_or_null("Climate") as V03Climate
	if climate:
		d["climate"] = climate.save_state()
	var doors := {}
	for n in world.get_tree().get_nodes_in_group("doors"):
		var door := n as V03Door
		doors[str(world.get_path_to(door))] = door.save_state()
	d["doors"] = doors
	var windows := {}
	for n in world.get_tree().get_nodes_in_group("windows"):
		var w := n as V03WindowObj
		windows[str(world.get_path_to(w))] = w.save_state()
	d["windows"] = windows
	var containers := {}
	for n in world.get_tree().get_nodes_in_group("containers"):
		var c := n as V03LootContainer
		if c.searched and c.container_type != "corpse":
			containers[str(world.get_path_to(c))] = c.save_state()
	d["containers"] = containers
	var items: Array = []
	for n in world.get_tree().get_nodes_in_group("world_items"):
		var wi := n as V03WorldItem
		if wi.is_queued_for_deletion():
			continue
		var p := wi.global_position
		items.append({"parent": str(world.get_path_to(wi.get_parent())), "p": [p.x, p.y, p.z], "s": wi.stack.to_dict()})
	d["items"] = items
	var zombies: Array = []
	for n in world.get_tree().get_nodes_in_group("zombies") + world.get_tree().get_nodes_in_group("corpses"):
		var z := n as V03Zombie
		if z and not z.is_queued_for_deletion():
			zombies.append(z.save_state())
	d["zombies"] = zombies
	var fires: Array = []
	for n in world.get_tree().get_nodes_in_group("campfires"):
		fires.append((n as V03Campfire).save_state())
	d["campfires"] = fires
	var alarms := {}
	for n in world.get_tree().get_nodes_in_group("car_alarms"):
		var a := n as V03CarAlarm
		if not a.armed:
			alarms[str(world.get_path_to(a))] = a.save_state()
	d["alarms"] = alarms
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	return true


## Applies the sandbox settings stored in the save (call before the world is built).
static func apply_settings() -> void:
	if not exists():
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path()))
	if typeof(d) != TYPE_DICTIONARY:
		return
	var st: Dictionary = d.get("settings", {})
	for k in st:
		V03Settings.set(k, st[k])


static func load_into(world: Node3D) -> bool:
	if not exists():
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(path()))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	var tree := world.get_tree()
	V03GameTime.total_minutes = float(d.get("time", V03GameTime.total_minutes))
	var climate := world.get_node_or_null("Climate") as V03Climate
	if climate:
		climate.load_state(d.get("climate", {}))
	var player := world.get_node("Player") as V03Player
	player.load_state(d.get("player", {}))
	var doors: Dictionary = d.get("doors", {})
	for path in doors:
		var door := world.get_node_or_null(NodePath(path)) as V03Door
		if door:
			door.load_state(doors[path])
	var windows: Dictionary = d.get("windows", {})
	for path in windows:
		var w := world.get_node_or_null(NodePath(path)) as V03WindowObj
		if w:
			w.load_state(windows[path])
	var containers: Dictionary = d.get("containers", {})
	for path in containers:
		var c := world.get_node_or_null(NodePath(path)) as V03LootContainer
		if c:
			c.load_state(containers[path])
	for n in tree.get_nodes_in_group("world_items"):
		n.queue_free()
	for e in d.get("items", []):
		var parent := world.get_node_or_null(NodePath(str(e["parent"]))) as Node3D
		var s := V03ItemStack.from_dict(e["s"])
		if parent and s:
			var wi := V03WorldItem.drop(s, parent, Vector3.ZERO)
			var p: Array = e["p"]
			wi.global_position = Vector3(p[0], p[1], p[2])
	var zroot := world.get_node("Zombies")
	for n in tree.get_nodes_in_group("zombies") + tree.get_nodes_in_group("corpses"):
		n.queue_free()
	for z in d.get("zombies", []):
		V03Zombie.restore(zroot, z)
	for f in d.get("campfires", []):
		var p: Array = f["pos"]
		var c := V03Campfire.build(world, Vector3(p[0], p[1], p[2]), float(f.get("fuel", 0.0)))
		c.set_burning(bool(f.get("on", false)) and c.fuel_hours > 0.0)
	var alarms: Dictionary = d.get("alarms", {})
	for path in alarms:
		var a := world.get_node_or_null(NodePath(path)) as V03CarAlarm
		if a:
			a.load_state(alarms[path])
	V03Events.show_toast("Игра загружена: день %d, %s." % [V03GameTime.get_day(), V03GameTime.get_clock_text()])
	return true
