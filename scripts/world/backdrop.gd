class_name Backdrop
extends RefCounted
## What lies beyond the playable town (needed once you look at the horizon in first person, v0.5):
## fields running to the horizon, a mixed pine and birch belt around the whole map (MultiMesh chunks),
## a dark tree line far away that melts into the fog, and invisible walls just outside the map edge.

const MAP := Rect2(-10, -14, 290, 254)
const BELT := 72.0
const CHUNK := 60.0
const TREES := ["environment/pine_1", "environment/pine_2", "environment/birch_1", "environment/birch_2"]


static func build(world: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Backdrop"
	world.add_child(root)
	_ground(root)
	_forest_belt(root)
	_treeline(root)
	_walls(root)


static func _ground(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Fields"
	var pm := PlaneMesh.new()
	pm.size = Vector2(2600, 2600)
	pm.subdivide_width = 0
	pm.subdivide_depth = 0
	mi.mesh = pm
	mi.material_override = Mats.surface("grass")
	mi.position = Vector3(MAP.get_center().x, -0.035, MAP.get_center().y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Mesh parts of a tree prop with its converted materials baked in, and their local transforms.
static func _parts(asset: String) -> Array:
	var ps := Props.scene(asset)
	if ps == null:
		return []
	var inst := ps.instantiate() as Node3D
	Mats.convert_imported(inst, false)
	var out: Array = []
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.mesh == null:
			continue
		var mesh := m.mesh.duplicate() as Mesh
		if mesh is ArrayMesh:
			for i in mesh.get_surface_count():
				var mat := m.get_surface_override_material(i)
				if mat:
					(mesh as ArrayMesh).surface_set_material(i, mat)
		var xf := Transform3D.IDENTITY
		var p: Node = m
		while p != inst and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		out.append([mesh, xf])
	inst.free()
	return out


static func _forest_belt(root: Node3D) -> void:
	var is_mob := OS.has_feature("mobile") or OS.get_name() == "Android"
	var max_trees := 320 if is_mob else 3600
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var parts := {}
	for a in TREES:
		parts[a] = _parts(a)
	var outer := MAP.grow(BELT)
	var inner := MAP.grow(2.5)
	# chunk key -> asset -> [transforms]
	var chunks := {}
	var tries := 0
	var placed := 0
	while placed < max_trees and tries < 20000:
		tries += 1
		var p := Vector2(rng.randf_range(outer.position.x, outer.end.x), rng.randf_range(outer.position.y, outer.end.y))
		if inner.has_point(p):
			continue
		# Thinner towards the far edge, with clearings.
		var edge_d := _dist_outside(p)
		if rng.randf() < smoothstep(BELT * 0.6, BELT, edge_d) * 0.7:
			continue
		if sin(p.x * 0.05) * sin(p.y * 0.043) > 0.72:
			continue
		var asset: String = TREES[rng.randi() % 2] if rng.randf() < 0.68 else TREES[2 + rng.randi() % 2]
		var s := rng.randf_range(0.85, 1.35)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), Vector3(p.x, 0, p.y))
		var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
		if not chunks.has(key):
			chunks[key] = {}
		var c: Dictionary = chunks[key]
		if not c.has(asset):
			c[asset] = []
		(c[asset] as Array).append([xf, edge_d])
		placed += 1
	for key in chunks:
		var c: Dictionary = chunks[key]
		for asset in c:
			var list: Array = c[asset]
			for part in parts[asset]:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = part[0]
				mm.instance_count = list.size()
				var near_any := false
				for i in list.size():
					mm.set_instance_transform(i, (list[i][0] as Transform3D) * (part[1] as Transform3D))
					near_any = near_any or float(list[i][1]) < 22.0
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (near_any and not is_mob) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if is_mob:
					mmi.visibility_range_end = 110.0
				root.add_child(mmi)


static func _dist_outside(p: Vector2) -> float:
	var dx := maxf(MAP.position.x - p.x, p.x - MAP.end.x)
	var dz := maxf(MAP.position.y - p.y, p.y - MAP.end.y)
	return maxf(maxf(dx, dz), 0.0)


## A ring of conifer silhouettes on the horizon (fog does the rest).
static func _treeline(root: Node3D) -> void:
	var w := 1024
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var tops := PackedFloat32Array()
	tops.resize(w)
	for x in w:
		tops[x] = 0.25 + 0.12 * sin(x * 0.011) + 0.06 * sin(x * 0.037 + 1.3)
	var x0 := 0
	while x0 < w:
		var tw := rng.randi_range(5, 13)
		var th := rng.randf_range(0.45, 0.95)
		for i in tw:
			var x := (x0 + i) % w
			var tri := 1.0 - absf(float(i) / float(tw) * 2.0 - 1.0)
			tops[x] = maxf(tops[x], th * tri + 0.25)
		x0 += rng.randi_range(3, 9)
	for x in w:
		for y in h:
			var hh := 1.0 - float(y) / float(h - 1)
			var a := 1.0 if hh < tops[x] else 0.0
			var shade := 0.75 + 0.25 * hh
			img.set_pixel(x, y, Color(0.11 * shade, 0.14 * shade, 0.11 * shade, a))
	var tex := ImageTexture.create_from_image(img)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3(MAP.get_center().x, -2.0, MAP.get_center().y)
	var r := 560.0
	var top := 62.0
	var seg := 96
	var reps := 14.0
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * r
		var u0 := reps * i / seg
		var u1 := reps * (i + 1) / seg
		for v in [[p0, u0, 1.0], [p1, u1, 1.0], [p1 + Vector3.UP * top, u1, 0.0], [p0, u0, 1.0], [p1 + Vector3.UP * top, u1, 0.0], [p0 + Vector3.UP * top, u0, 0.0]]:
			st.set_normal((c - (v[0] as Vector3)).normalized())
			st.set_uv(Vector2(v[1], v[2]))
			st.add_vertex(v[0])
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.disable_receive_shadows = true
	var mi := MeshInstance3D.new()
	mi.name = "Treeline"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 200.0
	root.add_child(mi)


## The map ends at the forest: you can walk into the trees but not out of the world.
static func _walls(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "MapEdge"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var g := MAP.grow(6.0)
	var t := 1.0
	for spec in [[Vector3(g.get_center().x, 2, g.position.y), Vector3(g.size.x, 6, t)],
			[Vector3(g.get_center().x, 2, g.end.y), Vector3(g.size.x, 6, t)],
			[Vector3(g.position.x, 2, g.get_center().y), Vector3(t, 6, g.size.y)],
			[Vector3(g.end.x, 2, g.get_center().y), Vector3(t, 6, g.size.y)],
			# Floor strips between the map edge and the walls (the fields there have no collision).
			[Vector3(g.get_center().x, -0.085, (g.position.y + MAP.position.y) * 0.5), Vector3(g.size.x, 0.1, MAP.position.y - g.position.y)],
			[Vector3(g.get_center().x, -0.085, (g.end.y + MAP.end.y) * 0.5), Vector3(g.size.x, 0.1, g.end.y - MAP.end.y)],
			[Vector3((g.position.x + MAP.position.x) * 0.5, -0.085, g.get_center().y), Vector3(MAP.position.x - g.position.x, 0.1, g.size.y)],
			[Vector3((g.end.x + MAP.end.x) * 0.5, -0.085, g.get_center().y), Vector3(g.end.x - MAP.end.x, 0.1, g.size.y)]]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[1]
		cs.shape = box
		cs.position = spec[0]
		body.add_child(cs)
