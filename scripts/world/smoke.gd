class_name Smoke
extends RefCounted
## Post-apocalyptic atmosphere particles: smoke columns over smouldering ruins and wrecks, small fires
## with flickering light, flies over corpses, falling leaves and drifting paper.

static var _soft_tex: GradientTexture2D


static func _soft() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(0.5, 0.0)
		_soft_tex.width = 32
		_soft_tex.height = 32
	return _soft_tex


static func _billboard(color: Color, additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if additive else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = _soft()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.disable_receive_shadows = true
	return m


## Dark smoke rising and drifting with the wind; `strength` 0..1 scales size and density.
static func column(parent: Node3D, pos: Vector3, strength := 1.0) -> GPUParticles3D:
	var is_mob := OS.has_feature("mobile") or OS.get_name() == "Android"
	var p := GPUParticles3D.new()
	p.amount = maxi(int(lerpf(12, 40, strength) * (0.45 if is_mob else 1.0)), 4)
	p.lifetime = lerpf(6.0, 11.0, strength)
	p.preprocess = 0.0 if is_mob else p.lifetime
	p.visibility_aabb = AABB(Vector3(-10, -2, -10), Vector3(30, 40, 30))
	if is_mob:
		p.visibility_range_end = 42.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5 + strength
	pm.direction = Vector3(0.25, 1, 0.1)
	pm.spread = 10.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0.5, 0.15, 0.2)
	pm.scale_min = 1.0
	pm.scale_max = 1.8
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 2.6))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(0.16, 0.15, 0.14, 0.0))
	grad.add_point(0.12, Color(0.18, 0.17, 0.16, 0.55))
	grad.set_color(grad.get_point_count() - 1, Color(0.35, 0.34, 0.33, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6) * lerpf(0.8, 1.6, strength)
	q.material = _billboard(Color(1, 1, 1, 1))
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = pos
	parent.add_child(p)
	return p


## Small open fire (burning wreck, barrel fire): flames, embers, warm flickering light, smoke above.
static func fire(parent: Node3D, pos: Vector3, size := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Fire"
	root.position = pos
	parent.add_child(root)
	var p := GPUParticles3D.new()
	p.amount = int(24 * size)
	p.lifetime = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35 * size
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0, 1.0, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.15))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.8, 0.35, 1.0))
	grad.set_color(1, Color(0.7, 0.12, 0.02, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.7) * size
	q.material = _billboard(Color(1, 1, 1, 1), true)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if OS.has_feature("mobile") or OS.get_name() == "Android":
		p.visibility_range_end = 35.0
	root.add_child(p)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 0.8, 0)
	l.omni_range = 6.0 * size
	l.light_color = Color("#ff8a3a")
	l.light_energy = 2.0
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 24.0
	l.distance_fade_length = 6.0
	l.set_script(preload("res://scripts/world/flicker_light.gd"))
	root.add_child(l)
	column(root, Vector3(0, 1.2, 0), 0.6 * size)
	return root


## A cloud of flies buzzing over a corpse.
static func flies(parent: Node3D, pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.4
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 4.0
	pm.turbulence_noise_scale = 2.0
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.05, 0.05, 0.05)
	q.material = m
	p.draw_pass_1 = q
	p.position = pos + Vector3(0, 0.5, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


## Yellow September leaves drifting down from a tree crown.
static func leaves(parent: Node3D, pos: Vector3, radius := 2.5) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 8
	p.lifetime = 7.0
	p.preprocess = 7.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius, 0.6, radius)
	pm.direction = Vector3(0.3, -1, 0.1)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0.3, -0.35, 0.1)
	pm.angular_velocity_min = -180.0
	pm.angular_velocity_max = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	var grad := Gradient.new()
	grad.set_color(0, Color("#c8a040"))
	grad.set_color(1, Color("#9a5a2a"))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_initial_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	p.position = pos + Vector3(0, 4.0, 0)
	p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 10, 12))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


## One-shot puff of grey smoke (gunshots, tyre burnouts); frees itself.
static func puff(parent: Node, pos: Vector3, dir: Vector3, amount := 8, color := Color(0.75, 0.74, 0.7, 0.45)) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 1.1
	p.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(0.35, 0.35)
	qm.material = _billboard(Color.WHITE)
	p.mesh = qm
	p.direction = dir if dir.length() > 0.01 else Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.8
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.gravity = Vector3(0, 0.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
