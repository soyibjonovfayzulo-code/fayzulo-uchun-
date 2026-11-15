class_name V02Inventory
extends RefCounted
## Weight-limited list of ItemStacks (player bag, cupboard, corpse, floor).

signal changed

var title := "Инвентарь"
var capacity := 10.0
var stacks: Array[V02ItemStack] = []


func _init(inv_title := "Инвентарь", cap := 10.0) -> void:
	title = inv_title
	capacity = cap


func total_weight() -> float:
	var w := 0.0
	for s in stacks:
		w += s.total_weight()
	return w


func free_weight() -> float:
	return capacity - total_weight()


func can_fit(stack: V02ItemStack, amount := -1) -> bool:
	var n := stack.count if amount < 0 else amount
	return stack.unit_weight() * n <= free_weight() + 0.0001


## Adds (merging into existing stacks). With `force`, ignores capacity (player overload, loot generation).
func add(stack: V02ItemStack, force := false) -> bool:
	if not force and not can_fit(stack):
		return false
	for s in stacks:
		if s.can_merge(stack):
			var room := s.item.max_stack - s.count
			if room <= 0:
				continue
			var moved := mini(room, stack.count)
			s.count += moved
			stack.count -= moved
			if stack.count <= 0:
				changed.emit()
				return true
	stacks.append(stack)
	changed.emit()
	return true


func remove(stack: V02ItemStack) -> void:
	stacks.erase(stack)
	changed.emit()


## Removes `amount` units of `stack` and returns them as their own stack.
func take(stack: V02ItemStack, amount: int) -> V02ItemStack:
	if amount >= stack.count:
		remove(stack)
		return stack
	var part := stack.split(amount)
	changed.emit()
	return part


func has(stack: V02ItemStack) -> bool:
	return stacks.has(stack)


func find_by_id(item_id: String) -> V02ItemStack:
	for s in stacks:
		if s.item.id == item_id:
			return s
	return null


func count_of(item_id: String) -> int:
	var n := 0
	for s in stacks:
		if s.item.id == item_id:
			n += s.count
	return n


## Moves `amount` units (all when -1) to another inventory. Returns true on success.
static func transfer(stack: V02ItemStack, from: V02Inventory, to: V02Inventory, amount := -1, force := false) -> bool:
	if from == to or not from.has(stack):
		return false
	var n := stack.count if amount < 0 else clampi(amount, 1, stack.count)
	if not force and not to.can_fit(stack, n):
		return false
	var part := from.take(stack, n)
	to.add(part, true)
	return true
