class_name V04LootTable
extends Resource
## Weighted loot for one kind of container/room (res://versions/v04/resources/loot_tables/<id>.tres).

@export var id := ""
@export var item_ids: PackedStringArray = PackedStringArray()
@export var weights: PackedFloat32Array = PackedFloat32Array()
## Max count per pick for stackable items (1 for the rest).
@export var max_counts: PackedInt32Array = PackedInt32Array()
@export var rolls_min := 1
@export var rolls_max := 3
@export_range(0.0, 1.0) var empty_chance := 0.2


func pick(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return weights.size() - 1
