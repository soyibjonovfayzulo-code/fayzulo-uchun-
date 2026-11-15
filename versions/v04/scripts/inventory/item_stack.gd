class_name V04ItemStack
extends RefCounted
## A concrete item (or a stack of identical items) in some inventory or on the ground.

enum Fresh { FRESH, STALE, ROTTEN }

var item: V04ItemData
var count := 1
var uses_left := 1
var durability := 0.0
## Flashlight battery 0..1, pistol rounds in the magazine, key target, etc.
var charge := 1.0
var loaded := 0
var key_id := ""
var custom_name := ""
## Game hours since this food was made (perishables only).
var age := 0.0


static func create(data: V04ItemData, amount := 1) -> V04ItemStack:
	var s := V04ItemStack.new()
	s.item = data
	s.count = maxi(amount, 1)
	s.uses_left = data.uses
	s.durability = data.max_durability
	return s


func get_name() -> String:
	var base := custom_name if custom_name != "" else item.display_name
	match freshness():
		Fresh.STALE:
			return base + (" (чёрствый)" if item.id == "bread" else " (несвежее)")
		Fresh.ROTTEN:
			return base + " (испорчено)"
	return base


func freshness() -> Fresh:
	if not item.is_perishable():
		return Fresh.FRESH
	if age >= item.rot_hours:
		return Fresh.ROTTEN
	if age >= item.fresh_hours:
		return Fresh.STALE
	return Fresh.FRESH


func unit_weight() -> float:
	if item.uses > 1:
		return item.weight * (0.25 + 0.75 * float(uses_left) / float(item.uses))
	return item.weight


func total_weight() -> float:
	return unit_weight() * count


func can_merge(other: V04ItemStack) -> bool:
	return other != self and other.item == item and item.is_stackable() and key_id == other.key_id \
		and custom_name == other.custom_name


## Splits `amount` units off into a new stack (returns self when taking everything).
func split(amount: int) -> V04ItemStack:
	if amount >= count:
		return self
	var s := V04ItemStack.create(item, amount)
	s.uses_left = uses_left
	s.durability = durability
	s.charge = charge
	s.loaded = loaded
	s.key_id = key_id
	s.custom_name = custom_name
	s.age = age
	count -= amount
	return s


func status_text() -> String:
	var parts: Array[String] = []
	if item.uses > 1:
		parts.append("%d/%d" % [uses_left, item.uses])
	if item.max_durability > 0.0:
		parts.append("%d%%" % roundi(durability / item.max_durability * 100.0))
	if item.magazine > 0:
		parts.append("%d/%d" % [loaded, item.magazine])
	if item.light_range > 0.0:
		parts.append("%d%%" % roundi(charge * 100.0))
	return " ".join(parts)


func freshness_text() -> String:
	if not item.is_perishable():
		return ""
	match freshness():
		Fresh.FRESH:
			return "Свежее"
		Fresh.STALE:
			return "Несвежее — может стошнить"
	return "Испорчено! Можно отравиться"


# ------------------------------------------------------------------------------------------------ save
func to_dict() -> Dictionary:
	var d := {"id": item.id, "n": count}
	if item.uses > 1:
		d["u"] = uses_left
	if item.max_durability > 0.0:
		d["dur"] = snappedf(durability, 0.01)
	if item.light_range > 0.0:
		d["ch"] = snappedf(charge, 0.001)
	if item.magazine > 0:
		d["ld"] = loaded
	if key_id != "":
		d["key"] = key_id
	if custom_name != "":
		d["name"] = custom_name
	if item.is_perishable():
		d["age"] = snappedf(age, 0.01)
	return d


static func from_dict(d: Dictionary) -> V04ItemStack:
	var data := V04ItemDB.get_item(str(d.get("id", "")))
	if data == null:
		return null
	var s := V04ItemStack.create(data, int(d.get("n", 1)))
	s.uses_left = int(d.get("u", data.uses))
	s.durability = float(d.get("dur", data.max_durability))
	s.charge = float(d.get("ch", 1.0))
	s.loaded = int(d.get("ld", 0))
	s.key_id = str(d.get("key", ""))
	s.custom_name = str(d.get("name", ""))
	s.age = float(d.get("age", 0.0))
	return s
