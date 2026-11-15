class_name Spoilage
extends RefCounted
## Ages perishable food everywhere it can be: the player's bag, searched containers and items on the
## ground. Working fridges slow it down to a quarter until the power goes out.

const FRIDGE_RATE := 0.25


static func tick(tree: SceneTree, hours: float, power: bool) -> void:
	var player := tree.get_first_node_in_group("player")
	if player and player.get("inventory"):
		age_inventory((player.get("inventory") as PlayerInventory).main, hours)
	for c in tree.get_nodes_in_group("containers"):
		var lc := c as LootContainer
		if lc == null or not lc.searched:
			continue
		var rate := FRIDGE_RATE if (lc.container_type == "fridge" and power) else 1.0
		age_inventory(lc.inventory, hours * rate)
	for w in tree.get_nodes_in_group("world_items"):
		var wi := w as WorldItem
		if wi and wi.stack and wi.stack.item.is_perishable():
			wi.stack.age += hours


static func age_inventory(inv: Inventory, hours: float) -> void:
	var any := false
	for s in inv.stacks:
		if s.item.is_perishable():
			var before := s.freshness()
			s.age += hours
			any = any or s.freshness() != before
	if any:
		inv.changed.emit()


## Initial age of food rolled into a container long after the outbreak began.
static func initial_age(container_type: String, rng: RandomNumberGenerator, item: ItemData) -> float:
	if not item.is_perishable():
		return 0.0
	var since := 0.0
	if Climate.instance:
		var h := Climate.instance.hours_since_start()
		var powered := minf(h, Climate.instance.power_off_at) if Climate.instance.power_off_at >= 0.0 else h
		since = (powered * FRIDGE_RATE + maxf(h - powered, 0.0)) if container_type == "fridge" else h
	return since + rng.randf_range(0.0, item.fresh_hours * 0.6)
