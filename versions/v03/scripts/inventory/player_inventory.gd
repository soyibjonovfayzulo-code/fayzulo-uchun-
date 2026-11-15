class_name V03PlayerInventory
extends Node
## The survivor's carried items plus equipment slots. Equipped stacks stay inside `main`
## (their weight counts, like in PZ); `equipped` only references them.

signal changed
signal equipment_changed(slot: String)

const BASE_CAPACITY := 8.0
const SLOTS := ["hand", "offhand", "back", "body"]
const SLOT_NAMES := {"hand": "Рука", "offhand": "2-я рука", "back": "Спина", "body": "Тело"}

var main := V03Inventory.new("Инвентарь", BASE_CAPACITY)
var equipped := {"hand": null, "offhand": null, "back": null, "body": null}


func _ready() -> void:
	main.changed.connect(_on_main_changed)


func _on_main_changed() -> void:
	# Anything that left the bag is no longer equipped.
	for slot in SLOTS:
		var s: V03ItemStack = equipped[slot]
		if s != null and not main.has(s):
			equipped[slot] = null
			_refresh_capacity()
			equipment_changed.emit(slot)
	changed.emit()


func _refresh_capacity() -> void:
	var bag: V03ItemStack = equipped["back"]
	main.capacity = BASE_CAPACITY + (bag.item.capacity_bonus if bag else 0.0)


func slot_for(stack: V03ItemStack) -> String:
	var s := stack.item.equip_slot
	if s == "" and stack.item.is_weapon():
		s = "hand"
	return s


func can_equip(stack: V03ItemStack) -> bool:
	return slot_for(stack) != ""


func equip(stack: V03ItemStack, slot := "") -> bool:
	if slot == "":
		slot = slot_for(stack)
	if slot == "" or not equipped.has(slot):
		return false
	if not main.has(stack):
		main.add(stack, true)
	# One unit only in a slot.
	if stack.count > 1:
		stack = main.take(stack, 1)
		main.stacks.append(stack)
	for other in SLOTS:
		if equipped[other] == stack:
			equipped[other] = null
			equipment_changed.emit(other)
	equipped[slot] = stack
	_refresh_capacity()
	equipment_changed.emit(slot)
	changed.emit()
	return true


func unequip(slot: String) -> void:
	if equipped.get(slot) == null:
		return
	equipped[slot] = null
	_refresh_capacity()
	equipment_changed.emit(slot)
	changed.emit()


func is_equipped(stack: V03ItemStack) -> bool:
	for slot in SLOTS:
		if equipped[slot] == stack:
			return true
	return false


func equipped_slot(stack: V03ItemStack) -> String:
	for slot in SLOTS:
		if equipped[slot] == stack:
			return slot
	return ""


func weapon() -> V03ItemStack:
	var s: V03ItemStack = equipped["hand"]
	return s if s != null and s.item.is_weapon() else null


func protection() -> float:
	var s: V03ItemStack = equipped["body"]
	return s.item.protection if s else 0.0


func load_ratio() -> float:
	return main.total_weight() / maxf(main.capacity, 0.1)


## Destroys one unit (consumed food, broken weapon).
func consume(stack: V03ItemStack) -> void:
	if stack.count > 1:
		stack.count -= 1
		main.changed.emit()
	else:
		main.remove(stack)


func give(id: String, amount := 1) -> V03ItemStack:
	var s := V03ItemDB.make(id, amount)
	if s:
		main.add(s, true)
	return s
