class_name V04GroundDetail
extends RefCounted
## Fine ground detail over the whole town: tens of thousands of grass and weed clumps (MultiMesh in
## 24 m chunks with distance culling), and decals — fallen leaves under trees, cracks in the asphalt,
## oil stains on roads and parking, damp stains on concrete, scattered paper by shops and stops.
## Density follows the graphics quality preset.

const CHUNK := 24.0
const TEX := "res://versions/v04/assets/textures/"

static var _tuft_mesh: ArrayMesh


static func build(d: V04District) -> void:
	var q := V04GameOptions.quality
	var density: float = [0.3, 0.6, 1.0, 1.25][clampi(q, 0, 3)]
	_grass(d, density)
	_decals(d, density)


static func _mesh() -> ArrayMesh:
	if _tuft_mesh:
		return _tuft_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.3
	var h := 0.36
	for i in 3:
		var a := i * PI / 3.0
		var dx := Vector3(cos(a), 0, sin(a)) * w
		var pts := [-dx, dx, dx + Vector3(0, h, 0), -dx + Vector3(0, h, 0)]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[k])
			st.add_vertex(pts[k])
	_tuft_mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://versions/v04/shaders/grass_tuft.gdshader")
	m.set_shader_parameter("tuft_tex", load(TEX + "grass_tuft.png"))
	_tuft_mesh.surface_set_material(0, m)
	return _tuft_mesh


static func _grass(d: V04District, density: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5050
	var b := V04District.BOUNDS
	var chunks := {}
	var step := 0.9 / sqrt(density)
	var greens := [Color("#6a7a3e"), Color("#5e7038"), Color("#7a8044"), Color("#8a8a4c"), Color("#6e7a40")]
	var straw := [Color("#9a8c58"), Color("#a89660"), Color("#8a7c4c")]
	var y := b.position.y
	while y < b.end.y:
		var x := b.position.x
		while x < b.end.x:
			var p := Vector3(x + rng.randf_range(-step, step) * 0.5, 0.0, y + rng.randf_range(-step, step) * 0.5)
			x += step
			var key := d.ground_key_at(p)
			var chance := 0.0
			match key:
				"grass":
					chance = 0.85
				"dirt":
					chance = 0.14
				"gravel":
					chance = 0.05
				"sand":
					chance = 0.02
				"asphalt", "asphalt_light", "concrete", "pavement":
					chance = 0.012
			if chance <= 0.0 or rng.randf() > chance:
				continue
			if V04District.surface_at(p) == "floor":
				continue
			var top := d.ground_top_at(p)
			var dry := key != "grass" or rng.randf() < 0.18
			var col: Color = (straw[rng.randi() % straw.size()] if dry else greens[rng.randi() % greens.size()])
			col = col.lerp(Color(col.r * 1.1, col.g * 1.08, col.b, 1), rng.randf() * 0.4)
			var s := rng.randf_range(0.65, 1.35) * (1.25 if key != "grass" else 1.0)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
			var ck := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
			if not chunks.has(ck):
				chunks[ck] = []
			(chunks[ck] as Array).append([Transform3D(basis, Vector3(p.x, top, p.z)), col])
		y += step
	var total := 0
	for ck in chunks:
		var items: Array = chunks[ck]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _mesh()
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, items[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Grass_%d_%d" % [ck.x, ck.y]
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 120.0
		mi.visibility_range_end_margin = 10.0
		d.add_child(mi)
		total += items.size()
	d.grass_count = total


static func _decal(d: V04District, tex: String, pos: Vector3, size: float, rot: float, mod := Color.WHITE) -> void:
	var dc := Decal.new()
	dc.texture_albedo = load(TEX + tex + ".png")
	dc.size = Vector3(size, 0.35, size)
	dc.modulate = mod
	dc.upper_fade = 0.1
	dc.lower_fade = 0.1
	dc.position = Vector3(pos.x, d.ground_top_at(pos) + 0.05, pos.z)
	dc.rotation.y = rot
	dc.cull_mask = 1
	d._static.add_child(dc)
	d.decal_count += 1


static func _decals(d: V04District, density: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6060
	for p in d.tree_points:
		if rng.randf() < 0.65:
			_decal(d, "decal_leaves", p + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)),
				rng.randf_range(2.5, 4.0), rng.randf() * TAU)
	var b := V04District.BOUNDS
	var n := int(900 * density)
	for i in n:
		var p := Vector3(rng.randf_range(b.position.x, b.end.x), 0, rng.randf_range(b.position.y, b.end.y))
		if V04District.surface_at(p) == "floor":
			continue
		var key := d.ground_key_at(p)
		match key:
			"asphalt":
				var r := rng.randf()
				if r < 0.1:
					_decal(d, "decal_crack", p, rng.randf_range(1.5, 3.0), rng.randf() * TAU)
				elif r < 0.14:
					_decal(d, "decal_oil", p, rng.randf_range(0.8, 1.6), rng.randf() * TAU)
			"asphalt_light", "concrete", "pavement":
				var r := rng.randf()
				if r < 0.07:
					_decal(d, "decal_stain", p, rng.randf_range(1.0, 2.2), rng.randf() * TAU)
				elif r < 0.12:
					_decal(d, "decal_crack", p, rng.randf_range(1.0, 2.0), rng.randf() * TAU)
				elif r < 0.15:
					_decal(d, "decal_paper", p, rng.randf_range(1.2, 2.0), rng.randf() * TAU)
			"gravel", "dirt":
				if rng.randf() < 0.025:
					_decal(d, "decal_paper", p, rng.randf_range(1.0, 1.8), rng.randf() * TAU)
	# Paper and leaves where people gathered: stops, shops, the checkpoint.
	for c in [Vector3(50, 0, 84), Vector3(25, 0, 82), Vector3(89, 0, 83), Vector3(134, 0, 70), Vector3(160, 0, 100),
			Vector3(70, 0, 126), Vector3(152, 0, 83)]:
		for k in 3:
			_decal(d, "decal_paper", c + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-2, 2)), rng.randf_range(1.4, 2.2),
				rng.randf() * TAU)
