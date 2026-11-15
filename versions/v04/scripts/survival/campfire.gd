class_name V04Campfire
extends V04Interactable
## A campfire built outdoors from matches/lighter and fuel (newspapers, firewood). Burns fuel by game
## hours, lights and warms the area, dries clothes, and is the only way to cook once the gas is gone.

const MODEL := "environment/campfire"

var fuel_hours := 0.0
var burning := false
## Russian stove (печь) in an izba: same fire, built into the house, heats every room.
var stove := false
var heat_radius := 3.6
var _light: OmniLight3D
var _flames: GPUParticles3D
var _sound: AudioStreamPlayer3D
var _crackle_t := 0.0


static func build(parent: Node3D, pos: Vector3, fuel: float) -> V04Campfire:
	var c := V04Campfire.new()
	c.name = "Campfire"
	parent.add_child(c, true)
	c.global_position = pos
	c.fuel_hours = fuel
	c.set_burning(fuel > 0.0)
	return c


## Stove placed by the izba builder (local position/rotation under `parent`).
static func build_stove(parent: Node3D, local_pos: Vector3, rot_deg: float) -> V04Campfire:
	var c := V04Campfire.new()
	c.name = "RussianStove"
	c.stove = true
	c.heat_radius = 6.5
	c.position = local_pos
	c.rotation_degrees.y = rot_deg
	parent.add_child(c, true)
	return c


static func heat_at(p: Vector3, radius: float) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var best := 0.0
	for n in tree.get_nodes_in_group("campfires"):
		var c := n as V04Campfire
		if c.burning:
			var r := maxf(radius, c.heat_radius)
			var d := c.global_position.distance_to(p)
			if d < r and absf(c.global_position.y - p.y) < 2.0:
				best = maxf(best, 1.0 - d / r)
	return best


func _ready() -> void:
	display_name = "Русская печь" if stove else "Костёр"
	focus_offset = Vector3(0, 0.9, 0.95) if stove else Vector3(0, 0.35, 0)
	focus_radius = 0.5
	super._ready()
	add_to_group("campfires")
	V04Props.spawn("furniture/russian_stove" if stove else MODEL, self, Vector3.ZERO, 0.0 if stove else randf() * 360.0)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.85, 1.05) if stove else Vector3(0, 0.7, 0)
	_light.omni_range = 4.5 if stove else 8.0
	_light.light_color = Color("#ff9a48")
	_light.shadow_enabled = true
	add_child(_light)
	_flames = _make_flames()
	if stove:
		_flames.position = Vector3(0, 0.68, 0.72)
		_flames.scale = Vector3.ONE * 0.6
	add_child(_flames)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = V04Sfx.get_stream("fire_loop")
	_sound.unit_size = 3.0
	_sound.max_distance = 22.0
	_sound.volume_db = -8.0
	_sound.finished.connect(func() -> void:
		if burning:
			_sound.play())
	add_child(_sound)
	set_burning(burning)


func _make_flames() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 26
	p.lifetime = 0.8
	p.position = Vector3(0, 0.12, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.14
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.1))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	grad.set_color(1, Color(0.8, 0.15, 0.02, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 1)
	q.material = m
	p.draw_pass_1 = q
	return p


func set_burning(on: bool) -> void:
	burning = on
	if _light == null:
		return
	_light.visible = on
	_flames.emitting = on
	if on and not _sound.playing and is_inside_tree():
		_sound.play()
	elif not on:
		_sound.stop()


func _process(delta: float) -> void:
	if not burning:
		return
	fuel_hours -= V04GameTime.game_hours(delta)
	_light.light_energy = 2.4 + sin(Time.get_ticks_msec() * 0.021) * 0.25 + randf() * 0.35
	_crackle_t -= delta
	if _crackle_t <= 0.0:
		_crackle_t = 3.0
		V04NoiseSystem.emit(global_position, 5.0, self)
	if fuel_hours <= 0.0:
		fuel_hours = 0.0
		set_burning(false)
		V04Events.show_toast("Печь прогорела." if stove else "Костёр догорел.")


func get_actions(actor: Node) -> Array:
	var a: Array = []
	var p := actor as V04Player
	if p == null:
		return a
	if burning:
		a.append_array(V04Cooking.available(p, false))
	for s in p.fuel_items():
		a.append({"id": "fuel:" + s.item.id, "label": ("Подбросить: " if burning else ("Растопить печь: " if stove else "Разжечь: ")) + s.item.display_name})
	if burning and not stove:
		a.append({"id": "douse", "label": "Потушить костёр"})
	if a.is_empty():
		if stove:
			a.append({"id": "look", "label": "Печь (%s)" % ("топится" if burning else "холодная")})
		else:
			a.append({"id": "look", "label": "Костёр (%s)" % ("горит" if burning else "погас")})
	return a


func perform(action_id: String, actor: Node) -> void:
	var p := actor as V04Player
	if p == null:
		return
	if action_id.begins_with("cook:"):
		V04Cooking.cook(p, action_id.trim_prefix("cook:"), self, false)
	elif action_id.begins_with("fuel:"):
		var s := p.inventory.main.find_by_id(action_id.trim_prefix("fuel:"))
		if s == null:
			return
		if not burning and not p.use_fire_starter():
			V04Events.show_toast("Нечем разжечь: нужны спички или зажигалка.")
			return
		fuel_hours += s.item.fuel_hours
		p.inventory.consume(s)
		set_burning(true)
		V04Sfx.play_at("match", global_position, -6.0)
	elif action_id == "douse":
		fuel_hours = 0.0
		set_burning(false)
		V04Events.show_toast("Костёр потушен.")
	elif action_id == "look":
		V04Events.show_toast("Нужны дрова, доски или газета и спички." if not burning else "Тепло. На печи можно готовить.")


func save_state() -> Dictionary:
	return {"pos": [global_position.x, global_position.y, global_position.z], "fuel": fuel_hours, "on": burning}


func load_state(d: Dictionary) -> void:
	fuel_hours = float(d.get("fuel", 0.0))
	set_burning(bool(d.get("on", false)) and fuel_hours > 0.0)
