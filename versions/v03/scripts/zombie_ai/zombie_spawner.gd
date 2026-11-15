class_name V03ZombieSpawner
extends Node3D
## Populates the district: shambling groups in the yard and on the street, stragglers by the garages,
## and the infected who never left their flats, stairwells and shops.

@export var player_path: NodePath
@export var safe_radius := 16.0

const OUTDOOR_GROUPS := [
	# centre, count, spread
	[Vector3(42, 0.1, 30), 5, 4.0], [Vector3(60, 0.1, 40), 4, 3.0], [Vector3(25, 0.1, 22), 3, 3.0],
	[Vector3(76, 0.1, 36), 4, 4.0], [Vector3(70, 0.1, 6), 4, 5.0], [Vector3(30, 0.1, 89), 6, 6.0],
	[Vector3(88, 0.1, 89), 5, 6.0], [Vector3(55, 0.1, 89), 3, 3.0], [Vector3(100, 0.1, 30), 3, 4.0],
	[Vector3(10, 0.1, 60), 3, 4.0], [Vector3(90, 0.1, 55), 3, 3.0],
]

var spawned: Array[V03Zombie] = []


func spawn_all(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1993
	var player := get_node_or_null(player_path) as Node3D
	var safe := player.global_position if player else Vector3.ZERO
	var outdoor := 0
	for g in OUTDOOR_GROUPS:
		for i in g[1]:
			var p: Vector3 = g[0] + Vector3(rng.randf_range(-g[2], g[2]), 0, rng.randf_range(-g[2], g[2]))
			if p.distance_to(safe) > safe_radius:
				_spawn(p, rng, "zombie_e" if rng.randf() < 0.08 else "")
				outdoor += 1
	# Indoors: random rooms on lower floors, stairwells, shops.
	var rooms: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		var bb := b as V03Building
		for r in bb.room_points:
			if r["level"] <= 3:
				rooms.append([bb, r])
	rooms.shuffle()
	var indoor := maxi(count - outdoor, 0)
	var i := 0
	while indoor > 0 and i < rooms.size():
		var e: Array = rooms[i]
		i += 1
		var bb: V03Building = e[0]
		var r: Dictionary = e[1]
		var p := bb.to_global(r["pos"] + Vector3(0, 0.15, 0))
		if p.distance_to(safe) < safe_radius:
			continue
		if r["type"] in ["bathroom", "hall"] and rng.randf() < 0.6:
			continue
		_spawn(p, rng, "zombie_e" if r["type"] == "shop" and rng.randf() < 0.3 else "")
		indoor -= 1
	print("ZOMBIES spawned=%d (outdoor %d)" % [spawned.size(), outdoor])


func _spawn(p: Vector3, rng: RandomNumberGenerator, kind: String) -> void:
	var z := V03Zombie.spawn(self, p, rng, kind)
	spawned.append(z)
