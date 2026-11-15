class_name V04Interactable
extends Node3D
## Base class for anything the player can use. Subclasses override get_actions()/perform().
## A small Area3D on the "interact" physics layer lets the player's Interactor find it cheaply.

const LAYER_INTERACT := 8

@export var display_name := "Объект"
## Local-space point used for range checks, prompts and line of sight.
@export var focus_offset := Vector3(0, 1.0, 0)
@export var focus_radius := 0.45

var _highlighted := false


func _ready() -> void:
	add_to_group("interactables")
	var area := Area3D.new()
	area.name = "InteractArea"
	area.collision_layer = LAYER_INTERACT
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = focus_radius
	cs.shape = s
	cs.position = focus_offset
	area.add_child(cs)
	add_child(area)


## Array of {"id": String, "label": String}. The first entry is the E-key action.
func get_actions(_actor: Node) -> Array:
	return []


func perform(_action_id: String, _actor: Node) -> void:
	pass


func get_focus_point() -> Vector3:
	return global_transform * focus_offset


## Physics bodies that belong to this object (ignored by the line-of-sight check).
func get_own_rids() -> Array[RID]:
	var out: Array[RID] = []
	for b in find_children("*", "CollisionObject3D", true, false):
		out.append((b as CollisionObject3D).get_rid())
	return out


func can_interact(_actor: Node) -> bool:
	return is_visible_in_tree() and not get_actions(_actor).is_empty()


func set_highlight(on: bool) -> void:
	if on == _highlighted:
		return
	_highlighted = on
	for mi in _highlight_meshes():
		(mi as MeshInstance3D).material_overlay = V04Mats.highlight() if on else null


func _highlight_meshes() -> Array:
	return find_children("*", "MeshInstance3D", true, false)
