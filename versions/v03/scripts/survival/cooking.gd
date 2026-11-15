class_name V03Cooking
extends RefCounted
## Recipes for a pot on a gas stove or a campfire. Every dish needs a pot and one portion of water
## (from a bottle or a working tap), raw groats, and for "по-флотски" a tin of stew (and an opener).

const RECIPES := [
	{"id": "pot_navy", "label": "Сварить гречку с тушёнкой", "needs": ["buckwheat", "tushenka"]},
	{"id": "pot_buckwheat", "label": "Сварить гречку", "needs": ["buckwheat"]},
	{"id": "pot_macaroni", "label": "Отварить макароны", "needs": ["macaroni"]},
]
const COOK_SECONDS := 6.0


## Recipes the player can make right now: [{"id", "label"}] for interaction menus.
static func available(player: V03Player, tap_water: bool) -> Array:
	var out: Array = []
	var inv := player.inventory.main
	if inv.find_by_id("pot") == null:
		return out
	if not tap_water and _water(inv) == null:
		return out
	for r in RECIPES:
		var ok := true
		for id in r["needs"]:
			if inv.find_by_id(id) == null:
				ok = false
		if ok and "tushenka" in r["needs"] and not player.has_opener():
			ok = false
		if ok:
			out.append({"id": "cook:" + str(r["id"]), "label": r["label"]})
	return out


static func _water(inv: V03Inventory) -> V03ItemStack:
	for s in inv.stacks:
		if s.item.id == "water" and s.uses_left > 0:
			return s
	return null


## Starts the timed cooking action. `where` is the stove/campfire (for the sound position).
static func cook(player: V03Player, recipe_id: String, where: Node3D, tap_water: bool) -> void:
	var r: Dictionary = {}
	for e in RECIPES:
		if e["id"] == recipe_id:
			r = e
	if r.is_empty():
		return
	V03Sfx.play_at("boil", where.global_position + Vector3.UP * 0.9, -6.0, 0.0)
	player.start_timed_action("Варим: %s..." % V03ItemDB.get_item(recipe_id).display_name, COOK_SECONDS, func() -> void:
		finish(player, r, tap_water))


static func finish(player: V03Player, r: Dictionary, tap_water: bool) -> bool:
	var inv := player.inventory
	var pot := inv.main.find_by_id("pot")
	if pot == null:
		return false
	var parts: Array[V03ItemStack] = []
	for id in r["needs"]:
		var s := inv.main.find_by_id(id)
		if s == null:
			V03Events.show_toast("Не хватает продуктов.")
			return false
		parts.append(s)
	var water := _water(inv.main)
	if not tap_water:
		if water == null:
			V03Events.show_toast("Нет воды.")
			return false
		player.spend_use(water)
	# The dish keeps as many portions as the groats pack had left.
	var groats := parts[0]
	var frac := float(groats.uses_left) / float(maxi(groats.item.uses, 1))
	inv.main.remove(groats)
	for i in range(1, parts.size()):
		inv.consume(parts[i])
	inv.consume(pot)
	var dish := V03ItemDB.make(r["id"])
	dish.uses_left = maxi(1, ceili(dish.item.uses * frac))
	inv.main.add(dish, true)
	V03Events.show_toast("Готово: %s. Пахнет как дома." % dish.item.display_name)
	return true
