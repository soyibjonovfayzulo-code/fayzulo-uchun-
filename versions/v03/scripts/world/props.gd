class_name V03Props
extends RefCounted
## Spawns Blender-exported props (res://versions/v03/assets/<name>.glb) with game materials and box collision.

static var _scenes := {}


static func scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		_scenes[name] = load("res://versions/v03/assets/%s.glb" % name)
	return _scenes[name]


static func spawn(name: String, parent: Node3D, pos: Vector3, rot_deg := 0.0, collide := true, cuttable := true) -> Node3D:
	var ps := scene(name)
	if ps == null:
		push_warning("Missing prop: " + name)
		return null
	var inst := ps.instantiate() as Node3D
	inst.name = name.get_file()
	inst.position = pos
	inst.rotation_degrees.y = rot_deg
	parent.add_child(inst)
	V03Mats.convert_imported(inst, cuttable)
	if collide:
		add_box_collider(inst)
	return inst


## Bounding box of all meshes under `root`, expressed in root's local space.
static func local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var box := xf * m.mesh.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


static func add_box_collider(inst: Node3D, inset := 0.02, layer := 1) -> StaticBody3D:
	var box := local_aabb(inst)
	if box.size.length() < 0.01:
		return null
	var body := StaticBody3D.new()
	body.name = "Collider"
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = (box.size - Vector3(inset, 0, inset) * 2.0).max(Vector3(0.05, 0.05, 0.05))
	cs.shape = shape
	cs.position = box.get_center()
	body.add_child(cs)
	inst.add_child(body)
	return body


## Explicit box collider in `parent` local space (used for walk-on geometry such as balconies).
static func add_box(parent: Node3D, center: Vector3, size: Vector3, layer := 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = center
	body.add_child(cs)
	parent.add_child(body)
	return body
