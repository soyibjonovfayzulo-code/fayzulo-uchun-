class_name V01MeshBuilder
extends RefCounted
## Batches many boxes into one ArrayMesh (one surface per material key) so a whole building level
## is a single draw-call-friendly MeshInstance3D. Collision is produced alongside as box shapes.

## Godot treats clockwise triangles as front faces.
const FACE_DIRS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]

var _tools := {}
var _materials := {}
var body: StaticBody3D


func _init(collision_body: StaticBody3D = null) -> void:
	body = collision_body


func _st(key: String, material: Material) -> SurfaceTool:
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
		_materials[key] = material
	return _tools[key]


func add_quad(key: String, material: Material, p: Array, n: Vector3, color := Color.WHITE) -> void:
	var st := _st(key, material)
	var a: Vector3 = p[0]
	var b: Vector3 = p[1]
	var c: Vector3 = p[2]
	var d: Vector3 = p[3]
	# Make winding clockwise when seen from the side the normal points to.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = d
		d = t
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.set_color(color)
		st.add_vertex(v)


## Box given by min/max corners. `classify` is Callable(face_center: Vector3, normal: Vector3) -> Array
## returning [key, material, color] or [] to skip that face. Without it every face uses `key`.
func add_box(bmin: Vector3, bmax: Vector3, key: String, material: Material, color := Color.WHITE,
		classify := Callable(), collide := true) -> void:
	var c := (bmin + bmax) * 0.5
	var h := (bmax - bmin) * 0.5
	for n: Vector3 in FACE_DIRS:
		var fc := c + n * h
		var k := key
		var m := material
		var col := color
		if classify.is_valid():
			var r: Array = classify.call(fc, n)
			if r.is_empty():
				continue
			k = r[0]
			m = r[1]
			col = r[2] if r.size() > 2 else Color.WHITE
		var u: Vector3
		var v: Vector3
		if absf(n.x) > 0.5:
			u = Vector3(0, h.y, 0)
			v = Vector3(0, 0, h.z)
		elif absf(n.y) > 0.5:
			u = Vector3(h.x, 0, 0)
			v = Vector3(0, 0, h.z)
		else:
			u = Vector3(h.x, 0, 0)
			v = Vector3(0, h.y, 0)
		add_quad(k, m, [fc - u - v, fc + u - v, fc + u + v, fc - u + v], n, col)
	if collide and body:
		add_collision(c, h * 2.0)


## Oriented box (ramps, handrails): centre, size and basis in builder space.
func add_obox(center: Vector3, size: Vector3, basis: Basis, key: String, material: Material, color := Color.WHITE,
		collide := false) -> void:
	var h := size * 0.5
	for n0 in FACE_DIRS:
		var n: Vector3 = n0
		var u: Vector3
		var v: Vector3
		if absf(n.x) > 0.5:
			u = Vector3(0, h.y, 0)
			v = Vector3(0, 0, h.z)
		elif absf(n.y) > 0.5:
			u = Vector3(h.x, 0, 0)
			v = Vector3(0, 0, h.z)
		else:
			u = Vector3(h.x, 0, 0)
			v = Vector3(0, h.y, 0)
		var fc := n * h
		var pts := [fc - u - v, fc + u - v, fc + u + v, fc - u + v]
		for i in 4:
			pts[i] = center + basis * pts[i]
		add_quad(key, material, pts, (basis * n).normalized(), color)
	if collide and body:
		add_collision(center, size, basis)


func add_collision(center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = Transform3D(basis, center)
	body.add_child(cs)


func commit(name := "Mesh") -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for key in _tools:
		var st: SurfaceTool = _tools[key]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _materials[key])
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	return mi


func is_empty() -> bool:
	return _tools.is_empty()
