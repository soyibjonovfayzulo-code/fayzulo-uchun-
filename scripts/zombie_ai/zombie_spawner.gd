class_name ZombieSpawner
extends Node3D
## Populates the town. Zombies are spread thinly over a map five times bigger than v0.3 (Settings.zombie_count,
## 35 by default): small groups in the courtyard and streets, babushkas in the private sector, soldiers at
## the checkpoint, militia by the police, stragglers indoors. Bodies lie in the streets from the start.

@export var player_path: NodePath
@export var safe_radius := 16.0

## centre, share of the outdoor population, spread, preferred variant ("" = any)
const OUTDOOR_GROUPS := [
	[Vector3(42, 0.1, 30), 0.08, 4.0, ""], [Vector3(60, 0.1, 40), 0.05, 3.0, ""], [Vector3(25, 0.1, 22), 0.04, 3.0, ""],
	[Vector3(76, 0.1, 36), 0.05, 4.0, ""], [Vector3(70, 0.1, 6), 0.04, 5.0, ""], [Vector3(30, 0.1, 89), 0.06, 6.0, ""],
	[Vector3(88, 0.1, 89), 0.05, 6.0, ""], [Vector3(10, 0.1, 60), 0.03, 4.0, ""],
	[Vector3(25, 0.1, 120), 0.05, 6.0, "zombie_g"], [Vector3(90, 0.1, 120), 0.05, 6.0, "zombie_g"],
	[Vector3(60, 0.1, 160), 0.05, 5.0, "zombie_g"], [Vector3(30, 0.1, 170), 0.04, 6.0, ""],
	[Vector3(134, 0.1, 64), 0.08, 4.0, "zombie_f"], [Vector3(152, 0.1, 86), 0.05, 4.0, "zombie_e"],
	[Vector3(165, 0.1, 104), 0.04, 4.0, ""], [Vector3(203, 0.1, 92), 0.06, 5.0, ""], [Vector3(134, 0.1, 175), 0.06, 7.0, ""],
	[Vector3(180, 0.1, -2), 0.03, 6.0, ""], [Vector3(255, 0.1, 120), 0.03, 10.0, "zombie_f"],
]

var spawned: Array[Zombie] = []


func spawn_all(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1993
	var player := get_node_or_null(player_path) as Node3D
	var safe := player.global_position if player else Vector3.ZERO
	var outdoor_total := int(round(count * 0.72))
	var outdoor := 0
	for g in OUTDOOR_GROUPS:
		var n := maxi(int(round(outdoor_total * float(g[1]))), 1 if count >= 10 else 0)
		for i in n:
			var p: Vector3 = g[0] + Vector3(rng.randf_range(-g[2], g[2]), 0, rng.randf_range(-g[2], g[2]))
			if p.distance_to(safe) > safe_radius:
				var kind: String = g[3] if g[3] != "" and rng.randf() < 0.75 else ("zombie_e" if rng.randf() < 0.05 else "")
				_spawn(p, rng, kind)
				outdoor += 1
	# Indoors: random rooms on lower floors, flats, shops, village houses.
	var rooms: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		var bb := b as Building
		for r in bb.room_points:
			if r["level"] <= 3:
				rooms.append([bb, r])
	rooms.shuffle()
	var indoor := maxi(count - outdoor, 0)
	var i := 0
	while indoor > 0 and i < rooms.size():
		var e: Array = rooms[i]
		i += 1
		var bb: Building = e[0]
		var r: Dictionary = e[1]
		var p := bb.to_global(r["pos"] + Vector3(0, 0.15, 0))
		if p.distance_to(safe) < safe_radius:
			continue
		if r["type"] in ["bathroom", "hall"] and rng.randf() < 0.6:
			continue
		var kind := ""
		if str(r["type"]).begins_with("village"):
			kind = "zombie_g" if rng.randf() < 0.5 else ""
		elif r["type"] == "shop" and rng.randf() < 0.3:
			kind = "zombie_e"
		_spawn(p, rng, kind)
		indoor -= 1
	print("ZOMBIES spawned=%d (outdoor %d)" % [spawned.size(), outdoor])


func _spawn(p: Vector3, rng: RandomNumberGenerator, kind: String) -> void:
	var z := Zombie.spawn(self, p, rng, kind)
	spawned.append(z)


## Bodies of those who did not make it: searchable corpses with blood and flies (new game only).
func place_corpses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for c in TownEast.CORPSES:
		var z := Zombie.restore(self, {"v": c[1], "p": [c[0].x, c[0].y, c[0].z], "y": rng.randf() * TAU, "hp": 0.0,
			"mhp": 60.0, "dead": true})
		BloodFX.pool(z.global_position)
		Smoke.flies(z, Vector3.ZERO)
