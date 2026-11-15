class_name V01LootContainer
extends V01Interactable
## Searchable furniture (fridge, wardrobe, shop shelf...). Wraps a prop model; sub-nodes named
## anim_door_L / anim_door_R swing open, anim_drawer_N slide out. Loot tables plug in at Milestone 4
## through `container_type` + `room_type` and the Events.container_opened signal.

@export var container_type := "cupboard"
@export var room_type := "living"
@export var capacity_kg := 20.0

var is_open := false
var searched := false
var model: Node3D
var _doors: Array[Node3D] = []
var _drawers: Array[Node3D] = []
var _rest := {}


## Wraps an already spawned prop; call before adding to the tree or right after.
func setup(prop: Node3D, nice_name: String, ctype: String, rtype: String) -> void:
	model = prop
	display_name = nice_name
	container_type = ctype
	room_type = rtype


func _ready() -> void:
	if model:
		var box := V01Props.local_aabb(model)
		focus_offset = model.transform * Vector3(box.get_center().x, clampf(box.get_center().y, 0.4, 1.2),
			box.end.z)
	super._ready()
	add_to_group("containers")
	if model:
		for n in model.find_children("anim_door_*", "Node3D", true, false):
			_doors.append(n)
			_rest[n] = (n as Node3D).transform
		for n in model.find_children("anim_drawer_*", "Node3D", true, false):
			_drawers.append(n)
			_rest[n] = (n as Node3D).transform


func get_actions(_actor: Node) -> Array:
	var a: Array = [{"id": "search", "label": "Обыскать: " + display_name}]
	if not _doors.is_empty() or not _drawers.is_empty():
		a.append({"id": "close" if is_open else "open", "label": "Закрыть" if is_open else "Открыть"})
	return a


func perform(action_id: String, _actor: Node) -> void:
	match action_id:
		"open":
			_animate(true)
		"close":
			_animate(false)
		"search":
			_animate(true)
			searched = true
			V01Events.container_opened.emit(self)


func _animate(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	var tw := create_tween().set_parallel(true)
	for d in _doors:
		var swing := 1.0 if String(d.name).ends_with("L") else -1.0
		var r: Transform3D = _rest[d]
		var target := r.basis.rotated(Vector3.UP, deg_to_rad(100.0) * swing) if open else r.basis
		tw.tween_property(d, "basis", target, 0.35).set_trans(Tween.TRANS_SINE)
	for d in _drawers:
		var r: Transform3D = _rest[d]
		tw.tween_property(d, "position", r.origin + Vector3(0, 0, 0.3) if open else r.origin, 0.3)
	if not _doors.is_empty() or not _drawers.is_empty():
		V01Sfx.play_at("drawer" if _doors.is_empty() else "cabinet_open", get_focus_point(), -8.0)
