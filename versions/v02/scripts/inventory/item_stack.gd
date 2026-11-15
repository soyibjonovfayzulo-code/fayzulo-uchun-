class_name V02ItemStack
extends RefCounted
## A concrete item (or a stack of identical items) in some inventory or on the ground.

var item: V02ItemData
var count := 1
var uses_left := 1
var durability := 0.0
## Flashlight battery 0..1, pistol rounds in the magazine, key target, etc.
var charge := 1.0
var loaded := 0
var key_id := ""
var custom_name := ""


static func create(data: V02ItemData, amount := 1) -> V02ItemStack:
	var s := V02ItemStack.new()
	s.item = data
	s.count = maxi(amount, 1)
	s.uses_left = data.uses
	s.durability = data.max_durability
	return s


func get_name() -> String:
	return custom_name if custom_name != "" else item.display_name


func unit_weight() -> float:
	if item.uses > 1:
		return item.weight * (0.25 + 0.75 * float(uses_left) / float(item.uses))
	return item.weight


func total_weight() -> float:
	return unit_weight() * count


func can_merge(other: V02ItemStack) -> bool:
	return other != self and other.item == item and item.is_stackable() and key_id == other.key_id \
		and custom_name == other.custom_name


## Splits `amount` units off into a new stack (returns self when taking everything).
func split(amount: int) -> V02ItemStack:
	if amount >= count:
		return self
	var s := V02ItemStack.create(item, amount)
	s.uses_left = uses_left
	s.durability = durability
	s.charge = charge
	s.key_id = key_id
	s.custom_name = custom_name
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
