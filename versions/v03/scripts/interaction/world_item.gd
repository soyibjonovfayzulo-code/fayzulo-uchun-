class_name V03WorldItem
extends V03Interactable
## An item lying on the ground. The loot window lists nearby ones as the "Пол" container.

const MODEL_SCALE := 1.5

var stack: V03ItemStack


static func drop(s: V03ItemStack, parent: Node3D, global_pos: Vector3) -> V03WorldItem:
	var w := V03WorldItem.new()
	w.stack = s
	parent.add_child(w, true)
	w.global_position = global_pos + Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
	w.rotation.y = randf() * TAU
	return w


func _ready() -> void:
	display_name = stack.get_name()
	focus_offset = Vector3(0, 0.15, 0)
	focus_radius = 0.35
	super._ready()
	add_to_group("world_items")
	var ps := load(stack.item.model_path) as PackedScene if stack.item.model_path != "" else null
	if ps:
		var m := ps.instantiate() as Node3D
		m.scale = Vector3.ONE * MODEL_SCALE
		add_child(m)
		V03Mats.convert_imported(m, true)


func get_actions(_actor: Node) -> Array:
	var n := " (%d)" % stack.count if stack.count > 1 else ""
	return [{"id": "pickup", "label": "Подобрать: %s%s" % [stack.get_name(), n]}]


func perform(action_id: String, actor: Node) -> void:
	if action_id == "pickup" and actor.has_method("pick_up"):
		actor.pick_up(self)
