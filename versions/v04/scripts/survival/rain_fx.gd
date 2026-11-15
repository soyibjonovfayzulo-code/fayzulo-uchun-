class_name V04RainFX
extends Node3D
## Rain around the camera focus: streak particles, a rain bed sound (muffled indoors) and thunder in
## heavy showers. Intensity comes from Climate.rain.

var target: Node3D
var _particles: GPUParticles3D
var _sound: AudioStreamPlayer
var _thunder_t := 20.0
var _splash: GPUParticles3D


func _ready() -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = 2600
	_particles.lifetime = 0.9
	_particles.visibility_aabb = AABB(Vector3(-24, -14, -24), Vector3(48, 30, 48))
	_particles.position = Vector3(0, 11, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(20, 0.5, 20)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 13.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3(0, -6, 0)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	_particles.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_color = Color(0.72, 0.78, 0.85, 0.32)
	m.disable_receive_shadows = true
	q.material = m
	_particles.draw_pass_1 = q
	_particles.emitting = false
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)
	# Splashes on the ground: tiny rings flashing where drops land.
	_splash = GPUParticles3D.new()
	_splash.amount = 700
	_splash.lifetime = 0.22
	_splash.visibility_aabb = AABB(Vector3(-24, -2, -24), Vector3(48, 4, 48))
	_splash.position = Vector3(0, 0.06, 0)
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(16, 0.0, 16)
	sp.direction = Vector3.UP
	sp.spread = 60.0
	sp.initial_velocity_min = 0.3
	sp.initial_velocity_max = 0.8
	sp.gravity = Vector3(0, -6, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.2))
	var ct := CurveTexture.new()
	ct.curve = curve
	sp.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(0.8, 0.85, 0.9, 0.55))
	grad.set_color(1, Color(0.8, 0.85, 0.9, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	sp.color_ramp = gt
	_splash.process_material = sp
	var sq := QuadMesh.new()
	sq.size = Vector2(0.07, 0.04)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sq.material = sm
	_splash.draw_pass_1 = sq
	_splash.emitting = false
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_splash)
	_sound = AudioStreamPlayer.new()
	_sound.stream = V04Sfx.get_stream("rain_loop")
	_sound.volume_db = -60.0
	_sound.finished.connect(_sound.play)
	add_child(_sound)


func _process(delta: float) -> void:
	var c := V04Climate.instance
	var r := c.rain if c else 0.0
	if target and is_instance_valid(target):
		global_position = Vector3(target.global_position.x, target.global_position.y, target.global_position.z)
	var on := r > 0.03
	_particles.emitting = on
	_particles.amount_ratio = clampf(r, 0.05, 1.0)
	var indoors_now := target != null and V04District.instance != null and V04District.surface_at(target.global_position) == "floor"
	_splash.emitting = on and not indoors_now
	_splash.amount_ratio = clampf(r, 0.05, 1.0)
	if target and is_instance_valid(target):
		_splash.global_position.y = target.global_position.y + 0.04
	if on and not _sound.playing:
		_sound.play()
	var indoors := target != null and V04District.instance != null and V04District.surface_at(target.global_position) == "floor"
	var want_db := linear_to_db(maxf(r, 0.001)) - (16.0 if indoors else 6.0)
	_sound.volume_db = lerpf(_sound.volume_db, want_db if on else -60.0, clampf(delta * 2.0, 0.0, 1.0))
	if not on and _sound.playing and _sound.volume_db < -55.0:
		_sound.stop()
	if r > 0.7:
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(18.0, 45.0)
			V04Sfx.play_ui("thunder", randf_range(-12.0, -4.0))
