extends Node
## Registry of all ItemData / LootTable resources and the loot roller.

const ITEMS_DIR := "res://versions/v04/resources/items/"
const TABLES_DIR := "res://versions/v04/resources/loot_tables/"

var items := {}
var tables := {}


func _ready() -> void:
	for f in _list(ITEMS_DIR):
		var d := load(ITEMS_DIR + f) as V04ItemData
		if d:
			items[d.id] = d
	for f in _list(TABLES_DIR):
		var t := load(TABLES_DIR + f) as V04LootTable
		if t:
			tables[t.id] = t


func _list(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with(".tres"):
			out.append(f)
	return out


func get_item(id: String) -> V04ItemData:
	return items.get(id)


func make(id: String, amount := 1) -> V04ItemStack:
	var d := get_item(id)
	if d == null:
		push_warning("Unknown item " + id)
		return null
	var s := V04ItemStack.create(d, amount)
	if d.light_range > 0.0:
		s.charge = randf_range(0.3, 1.0)
	return s


## Picks the most specific table: "<room>_<container>", then "<container>", then "<room>", then "default".
func resolve_table(container_type: String, room_type: String) -> V04LootTable:
	for key in ["%s_%s" % [room_type, container_type], container_type, room_type, "default"]:
		if tables.has(key):
			return tables[key]
	return null


func roll(table: V04LootTable, rng: RandomNumberGenerator) -> Array[V04ItemStack]:
	var out: Array[V04ItemStack] = []
	if table == null or rng.randf() < table.empty_chance:
		return out
	var rolls := rng.randi_range(table.rolls_min, table.rolls_max)
	for i in rolls:
		var idx := table.pick(rng)
		var d := get_item(table.item_ids[idx])
		if d == null:
			continue
		var n := rng.randi_range(1, maxi(table.max_counts[idx], 1)) if d.is_stackable() else 1
		var s := V04ItemStack.create(d, n)
		if d.uses > 1:
			s.uses_left = rng.randi_range(maxi(1, ceili(d.uses * 0.5)), d.uses)
		if d.max_durability > 0.0:
			s.durability = d.max_durability * rng.randf_range(0.45, 1.0)
		if d.light_range > 0.0:
			s.charge = rng.randf_range(0.15, 0.9)
		if d.magazine > 0:
			s.loaded = rng.randi_range(0, d.magazine)
		out.append(s)
	return out
