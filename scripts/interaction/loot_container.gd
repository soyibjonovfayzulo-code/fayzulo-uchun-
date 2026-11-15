class_name LootContainer
extends Interactable
## Searchable storage (fridge, wardrobe, shop shelf, car, garage, corpse...). Wraps an optional prop model;
## sub-nodes named anim_door_L / anim_door_R swing open, anim_drawer_N slide out.
## Loot is rolled once, on the first search, from ItemDB tables chosen by container_type + room_type.

const CAPACITY := {
	"fridge": 15.0, "cupboard": 10.0, "oven": 6.0, "wardrobe": 25.0, "drawers": 10.0, "shelf": 30.0, "counter": 12.0,
	"mailbox": 2.0, "garage": 40.0, "car": 8.0, "corpse": 10.0, "toolbox": 8.0, "crate": 9999.0,
	"chest": 20.0, "trunk": 50.0, "cellar": 40.0, "shed": 40.0, "gunsafe": 15.0, "woodpile": 30.0,
}

@export var container_type := "cupboard"
@export var room_type := "living"
## Overrides table resolution (e.g. "zombie_militia").
@export var table_id := ""
@export var search_time := 1.4

## Optional callback run when the container is searched for the first time (car alarms).
var searched_hook := Callable()
## Kitchen sink: tap water while the water supply works.
var has_tap := false
## Placed by the level (car keys): added on the first search on top of the rolled loot.
var bonus_items: Array[ItemStack] = []
var is_open := false
var searched := false
var inventory: Inventory
var model: Node3D
var _doors: Array[Node3D] = []
var _drawers: Array[Node3D] = []
var _rest := {}
var _anim_resolved := false


## Wraps an already spawned prop; call before adding to the tree.
func setup(prop: Node3D, nice_name: String, ctype: String, rtype: String) -> void:
	model = prop
	display_name = nice_name
	container_type = ctype
	room_type = rtype


func _ready() -> void:
	if model and focus_offset == Vector3(0, 1.0, 0):
		var box := Props.local_aabb(model)
		focus_offset = model.transform * Vector3(box.get_center().x, clampf(box.get_center().y, 0.4, 1.2), box.end.z)
	super._ready()
	add_to_group("containers")
	inventory = Inventory.new(display_name, CAPACITY.get(container_type, 12.0))


func _resolve_anim_parts() -> void:
	if _anim_resolved:
		return
	_anim_resolved = true
	if model:
		for n in model.find_children("anim_door_*", "Node3D", true, false):
			_doors.append(n)
			_rest[n] = (n as Node3D).transform
		for n in model.find_children("anim_drawer_*", "Node3D", true, false):
			_drawers.append(n)
			_rest[n] = (n as Node3D).transform


func get_actions(actor: Node) -> Array:
	_resolve_anim_parts()
	var a: Array = [{"id": "search", "label": ("Осмотреть: " if searched else "Обыскать: ") + display_name}]
	var p := actor as Player
	if p and container_type == "oven":
		var recipes := Cooking.available(p, Climate.has_water())
		if not recipes.is_empty():
			if Climate.has_gas():
				a = recipes + a
			else:
				a.append({"id": "nogas", "label": "Готовить (газа нет)"})
	if p and has_tap:
		a.append({"id": "drink_tap", "label": "Попить из-под крана"})
		if p.has_refillable():
			a.insert(0, {"id": "fill", "label": "Набрать воду в бутылки"})
	if not _doors.is_empty() or not _drawers.is_empty():
		a.append({"id": "close" if is_open else "open", "label": "Закрыть" if is_open else "Открыть"})
	return a


func perform(action_id: String, actor: Node) -> void:
	if action_id.begins_with("cook:") and actor is Player:
		Cooking.cook(actor as Player, action_id.trim_prefix("cook:"), self, Climate.has_water())
		return
	match action_id:
		"nogas":
			Events.show_toast("Газ отключили. Готовить теперь можно только на костре во дворе.")
		"fill":
			(actor as Player).fill_bottles()
		"drink_tap":
			(actor as Player).drink_tap()
		"open":
			_animate(true)
		"close":
			_animate(false)
		"search":
			if searched:
				_animate(true)
				Events.container_opened.emit(self)
			elif actor.has_method("start_timed_action"):
				_animate(true)
				actor.start_timed_action("Обыскиваем: " + display_name, search_time,
					func() -> void: finish_search())
			else:
				finish_search()


## Rolls the loot (deterministic per container position) and opens the loot window.
func finish_search() -> void:
	var _prof_t0 := Time.get_ticks_usec()
	ensure_loot()
	_animate(true)
	Events.container_opened.emit(self)
	if LiveDebug:
		LiveDebug.record_interaction("crate", display_name, _prof_t0)


func ensure_loot() -> void:
	if searched:
		return
	searched = true
	var rng := RandomNumberGenerator.new()
	var p := global_position
	rng.seed = hash(Vector3i(roundi(p.x * 10.0), roundi(p.y * 10.0), roundi(p.z * 10.0)))
	var table: LootTable = ItemDB.tables.get(table_id) if table_id != "" else ItemDB.resolve_table(container_type, room_type)
	for s in ItemDB.roll(table, rng):
		s.age = Spoilage.initial_age(container_type, rng, s.item)
		inventory.add(s, true)
	for s in bonus_items:
		inventory.add(s, true)
	bonus_items.clear()
	if searched_hook.is_valid():
		searched_hook.call()
	if inventory.stacks.any(func(s: ItemStack) -> bool: return s.item.id == "keys"):
		_assign_keys()
	inventory.changed.emit()


func save_state() -> Dictionary:
	return {"s": searched, "inv": inventory.to_array()}


func load_state(d: Dictionary) -> void:
	searched = bool(d.get("s", false))
	inventory.load_array(d.get("inv", []))


## Found keys belong to a random locked flat door nearby (same building if possible).
func _assign_keys() -> void:
	var my_pos := global_position
	var pool: Array[Door] = []
	var pool_d2: Array[float] = []
	for n in get_tree().get_nodes_in_group("doors"):
		var d := n as Door
		if not d.locked or d.key_id == "":
			continue
		var d2 := d.global_position.distance_squared_to(my_pos)
		if pool.size() < 6:
			pool.append(d)
			pool_d2.append(d2)
		else:
			var worst_idx := 0
			for i in range(1, 6):
				if pool_d2[i] > pool_d2[worst_idx]:
					worst_idx = i
			if d2 < pool_d2[worst_idx]:
				pool[worst_idx] = d
				pool_d2[worst_idx] = d2
	if pool.is_empty():
		return
	for s in inventory.stacks:
		if s.item.id == "keys":
			var d := pool[randi() % pool.size()]
			s.key_id = d.key_id
			s.custom_name = "Ключ: " + d.key_label


func _animate(open: bool) -> void:
	_resolve_anim_parts()
	if open == is_open:
		return
	is_open = open
	if _doors.is_empty() and _drawers.is_empty():
		return
	var tw := create_tween().set_parallel(true)
	for d in _doors:
		var swing := 1.0 if String(d.name).ends_with("L") else -1.0
		var r: Transform3D = _rest[d]
		var target := r.basis.rotated(Vector3.UP, deg_to_rad(100.0) * swing) if open else r.basis
		tw.tween_property(d, "basis", target, 0.35).set_trans(Tween.TRANS_SINE)
	for d in _drawers:
		var r: Transform3D = _rest[d]
		tw.tween_property(d, "position", r.origin + Vector3(0, 0, 0.3) if open else r.origin, 0.3)
	Sfx.play_at("drawer" if _doors.is_empty() else "cabinet_open", get_focus_point(), -8.0)
