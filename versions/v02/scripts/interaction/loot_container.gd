class_name V02LootContainer
extends V02Interactable
## Searchable storage (fridge, wardrobe, shop shelf, car, garage, corpse...). Wraps an optional prop model;
## sub-nodes named anim_door_L / anim_door_R swing open, anim_drawer_N slide out.
## Loot is rolled once, on the first search, from ItemDB tables chosen by container_type + room_type.

const CAPACITY := {
	"fridge": 15.0, "cupboard": 10.0, "oven": 6.0, "wardrobe": 25.0, "drawers": 10.0, "shelf": 30.0, "counter": 12.0,
	"mailbox": 2.0, "garage": 40.0, "car": 8.0, "corpse": 10.0, "toolbox": 8.0, "crate": 9999.0,
}

@export var container_type := "cupboard"
@export var room_type := "living"
## Overrides table resolution (e.g. "zombie_militia").
@export var table_id := ""
@export var search_time := 1.4

## Optional callback run when the container is searched for the first time (car alarms).
var searched_hook := Callable()
var is_open := false
var searched := false
var inventory: V02Inventory
var model: Node3D
var _doors: Array[Node3D] = []
var _drawers: Array[Node3D] = []
var _rest := {}


## Wraps an already spawned prop; call before adding to the tree.
func setup(prop: Node3D, nice_name: String, ctype: String, rtype: String) -> void:
	model = prop
	display_name = nice_name
	container_type = ctype
	room_type = rtype


func _ready() -> void:
	if model and focus_offset == Vector3(0, 1.0, 0):
		var box := V02Props.local_aabb(model)
		focus_offset = model.transform * Vector3(box.get_center().x, clampf(box.get_center().y, 0.4, 1.2), box.end.z)
	super._ready()
	add_to_group("containers")
	inventory = V02Inventory.new(display_name, CAPACITY.get(container_type, 12.0))
	if model:
		for n in model.find_children("anim_door_*", "Node3D", true, false):
			_doors.append(n)
			_rest[n] = (n as Node3D).transform
		for n in model.find_children("anim_drawer_*", "Node3D", true, false):
			_drawers.append(n)
			_rest[n] = (n as Node3D).transform


func get_actions(_actor: Node) -> Array:
	var a: Array = [{"id": "search", "label": ("Осмотреть: " if searched else "Обыскать: ") + display_name}]
	if not _doors.is_empty() or not _drawers.is_empty():
		a.append({"id": "close" if is_open else "open", "label": "Закрыть" if is_open else "Открыть"})
	return a


func perform(action_id: String, actor: Node) -> void:
	match action_id:
		"open":
			_animate(true)
		"close":
			_animate(false)
		"search":
			if searched:
				_animate(true)
				V02Events.container_opened.emit(self)
			elif actor.has_method("start_timed_action"):
				_animate(true)
				actor.start_timed_action("Обыскиваем: " + display_name, search_time,
					func() -> void: finish_search())
			else:
				finish_search()


## Rolls the loot (deterministic per container position) and opens the loot window.
func finish_search() -> void:
	ensure_loot()
	_animate(true)
	V02Events.container_opened.emit(self)


func ensure_loot() -> void:
	if searched:
		return
	searched = true
	var rng := RandomNumberGenerator.new()
	var p := global_position
	rng.seed = hash(Vector3i(roundi(p.x * 10.0), roundi(p.y * 10.0), roundi(p.z * 10.0)))
	var table: V02LootTable = V02ItemDB.tables.get(table_id) if table_id != "" else V02ItemDB.resolve_table(container_type, room_type)
	for s in V02ItemDB.roll(table, rng):
		inventory.add(s, true)
	if searched_hook.is_valid():
		searched_hook.call()
	if inventory.stacks.any(func(s: V02ItemStack) -> bool: return s.item.id == "keys"):
		_assign_keys()
	inventory.changed.emit()


## Found keys belong to a random locked flat door nearby (same building if possible).
func _assign_keys() -> void:
	var locked: Array = get_tree().get_nodes_in_group("doors").filter(
		func(d: Node) -> bool: return (d as V02Door).locked and (d as V02Door).key_id != "")
	if locked.is_empty():
		return
	locked.sort_custom(func(a: Node, b: Node) -> bool:
		return (a as Node3D).global_position.distance_squared_to(global_position) < (b as Node3D).global_position.distance_squared_to(global_position))
	var pool := locked.slice(0, mini(6, locked.size()))
	for s in inventory.stacks:
		if s.item.id == "keys":
			var d := pool[randi() % pool.size()] as V02Door
			s.key_id = d.key_id
			s.custom_name = "Ключ: " + d.key_label


func _animate(open: bool) -> void:
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
	V02Sfx.play_at("drawer" if _doors.is_empty() else "cabinet_open", get_focus_point(), -8.0)
