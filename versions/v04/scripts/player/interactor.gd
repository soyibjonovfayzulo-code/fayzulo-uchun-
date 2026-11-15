class_name V04Interactor
extends Area3D
## Finds the best interactable around the player (range, facing, same floor, line of sight).

signal focus_changed(target: V04Interactable)

const REACH := 1.75

var focused: V04Interactable
var _owner_body: CharacterBody3D
var _timer := 0.0


func _ready() -> void:
	_owner_body = get_parent() as CharacterBody3D
	collision_layer = 0
	collision_mask = V04Interactable.LAYER_INTERACT
	monitoring = true
	monitorable = false
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = REACH
	cs.shape = s
	add_child(cs)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.08
	var best: V04Interactable = null
	var best_score := INF
	var origin := global_position
	var fwd: Vector3 = _owner_body.call("get_facing_vector")
	var space := get_world_3d().direct_space_state
	for area in get_overlapping_areas():
		var it := area.get_parent() as V04Interactable
		if it == null or not it.can_interact(_owner_body):
			continue
		var fp := it.get_focus_point()
		if absf(fp.y - origin.y) > 1.35:
			continue
		var to := fp - origin
		var flat := Vector3(to.x, 0, to.z)
		var dist := flat.length()
		if dist > REACH + it.focus_radius:
			continue
		var facing := fwd.dot(flat.normalized()) if dist > 0.05 else 1.0
		var score := dist - facing * 0.8
		if score >= best_score:
			continue
		if not _has_line_of_sight(space, origin, fp, it):
			continue
		best = it
		best_score = score
	if best != focused:
		if is_instance_valid(focused):
			focused.set_highlight(false)
		focused = best
		if focused:
			focused.set_highlight(true)
		focus_changed.emit(focused)
		V04Events.interaction_focus_changed.emit(focused)


func _has_line_of_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, it: V04Interactable) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 32)
	var ex: Array[RID] = it.get_own_rids()
	ex.append(_owner_body.get_rid())
	q.exclude = ex
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true
	# Hitting something right at the target (its own furniture body) still counts as visible.
	return (hit["position"] as Vector3).distance_to(to) < 0.35


func get_actions() -> Array:
	if is_instance_valid(focused):
		return focused.get_actions(_owner_body)
	return []


func use_primary() -> bool:
	var actions := get_actions()
	if actions.is_empty():
		return false
	focused.perform(actions[0]["id"], _owner_body)
	return true


func use_action(target: V04Interactable, action_id: String) -> void:
	if is_instance_valid(target):
		target.perform(action_id, _owner_body)
