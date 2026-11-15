class_name V04BloodFX
extends RefCounted
## Pixel blood: short particle spurts on hits and dark stains left on the ground.

const MAX_STAINS := 160

static var _stains: Array[Node3D] = []
static var _mat: StandardMaterial3D
static var _stain_mat: StandardMaterial3D


static func _root() -> Node3D:
	var p := (Engine.get_main_loop() as SceneTree).get_first_node_in_group("player") as Node3D
	return p.get_parent() as Node3D if p else null


static func _materials() -> void:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.albedo_color = Color("#6a0e0a")
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_stain_mat = StandardMaterial3D.new()
		_stain_mat.albedo_color = Color(0.25, 0.02, 0.02, 0.85)
		_stain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_stain_mat.roughness = 0.4


static func splash(at: Vector3, dir: Vector3, amount := 1.0) -> void:
	var root := _root()
	if root == null:
		return
	_materials()
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = int(10 + 18 * amount)
	p.lifetime = 0.55
	p.explosiveness = 0.95
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	q.material = _mat
	p.mesh = q
	p.particle_flag_align_y = false
	p.direction = (dir.normalized() + Vector3(0, 0.6, 0)).normalized()
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5 * amount + 1.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	root.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	if randf() < 0.7:
		stain(at + dir.normalized() * randf_range(0.3, 0.9), 0.25 + amount * 0.25)


static func pool(at: Vector3) -> void:
	stain(at, 0.75)


static func stain(at: Vector3, size: float) -> void:
	var root := _root()
	if root == null:
		return
	_materials()
	var space := root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 3.0, 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size * randf_range(0.6, 1.0))
	m.mesh = pm
	m.material_override = _stain_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	m.global_position = (hit["position"] as Vector3) + Vector3.UP * 0.012
	m.rotation.y = randf() * TAU
	_stains.append(m)
	while _stains.size() > MAX_STAINS:
		var old: Node3D = _stains.pop_front()
		if is_instance_valid(old):
			old.queue_free()
