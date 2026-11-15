class_name Vehicle
extends RigidBody3D
## Drivable car with raycast suspension: four spring-damper wheels, tyre grip limited by load (it slides
## and drifts on the handbrake), rear- or all-wheel drive, speed-dependent steering, fuel, engine damage,
## crashes, running down zombies, headlights, brake lights and an engine note that follows the revs.
## Needs a key (key_id) or hotwiring. Local frame: +Z is the front of the car.

signal engine_changed(on: bool)

const FUEL_MAX := 40.0
const SPRING := 32000.0
const DAMP := 2600.0
const REST := 0.42
const WHEEL_R := 0.3
const GRIP := 1.15
const ROLL_RESIST := 0.015

@export var model_path := "res://assets/vehicles/sedan_body_ochre.glb"
@export var display_name := "Седан"
@export var engine_force := 7600.0
@export var top_speed := 24.0
@export var all_wheel := false
## Wheel contact points (local) front-left, front-right, rear-left, rear-right.
@export var wheel_pos: Array[Vector3] = [Vector3(0.78, 0.63, 1.3), Vector3(-0.78, 0.63, 1.3), Vector3(0.78, 0.63, -1.3), Vector3(-0.78, 0.63, -1.3)]
@export var body_size := Vector3(1.62, 0.9, 4.15)
@export var key_id := ""

var fuel := 20.0
var health := 100.0
var engine_on := false
var hotwired := false
var driver: Player
var throttle := 0.0
var steer := 0.0
var brake := 0.0
var handbrake := false
var headlights := true
var speed := 0.0
var trunk: LootContainer
var door: Interactable
var _wheels: Array[Node3D] = []
var _wheel_spin := 0.0
var _contact := [false, false, false, false]
var _engine: AudioStreamPlayer3D
var _lights: Array[SpotLight3D] = []
var _tail: OmniLight3D
var _noise_t := 0.0
var _hit_cd := {}
var _last_vel := Vector3.ZERO
var _smoke: GPUParticles3D
var _exhaust: CPUParticles3D
var _skid_last: Array[Vector3] = [Vector3.INF, Vector3.INF, Vector3.INF, Vector3.INF]
static var _skids: Array[Decal] = []
static var _skid_i := 0
static var _skid_tex: ImageTexture
const SKID_POOL := 220


func _ready() -> void:
	add_to_group("vehicles")
	mass = 1150.0
	collision_layer = 1
	collision_mask = 1 | 2
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.25, 0)
	linear_damp = 0.05
	angular_damp = 0.8
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = true
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = body_size
	cs.shape = box
	cs.position = Vector3(0, 0.36 + body_size.y * 0.5, 0)
	add_child(cs)
	var cab := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(body_size.x * 0.88, 0.55, body_size.z * 0.5)
	cab.shape = cbox
	cab.position = Vector3(0, 0.38 + body_size.y + 0.27, -0.2)
	add_child(cab)
	var ps := load(model_path) as PackedScene
	if ps:
		var m := ps.instantiate() as Node3D
		m.name = "Body"
		add_child(m)
		Mats.convert_imported(m, false)
	var wps := load("res://assets/vehicles/wheel.glb") as PackedScene
	for i in 4:
		var pivot := Node3D.new()
		pivot.position = wheel_pos[i] + Vector3(0, -REST + 0.09, 0)
		add_child(pivot)
		if wps:
			var wm := wps.instantiate() as Node3D
			wm.scale = Vector3.ONE * (1.1 if all_wheel else 1.0)
			pivot.add_child(wm)
			Mats.convert_imported(wm, false)
		_wheels.append(pivot)
	for x in [0.55, -0.55]:
		var l := SpotLight3D.new()
		l.position = Vector3(x, 0.75, body_size.z * 0.5 + 0.05)
		l.rotation_degrees = Vector3(-8, 180, 0)
		l.spot_range = 22.0
		l.spot_angle = 36.0
		l.spot_attenuation = 0.7
		l.light_energy = 0.0
		l.light_color = Color("#fff0c8")
		l.shadow_enabled = x > 0.0
		add_child(l)
		_lights.append(l)
	_tail = OmniLight3D.new()
	_tail.position = Vector3(0, 0.75, -body_size.z * 0.5 - 0.2)
	_tail.omni_range = 3.0
	_tail.light_color = Color("#ff2a1a")
	_tail.light_energy = 0.0
	add_child(_tail)
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = Sfx.get_stream("engine_loop")
	_engine.unit_size = 6.0
	_engine.max_distance = 60.0
	_engine.volume_db = -6.0
	_engine.finished.connect(func() -> void:
		if engine_on:
			_engine.play())
	add_child(_engine)
	_exhaust = CPUParticles3D.new()
	_exhaust.amount = 26
	_exhaust.lifetime = 1.7
	_exhaust.local_coords = false
	var eq := QuadMesh.new()
	eq.size = Vector2(0.28, 0.28)
	eq.material = Smoke._billboard(Color.WHITE)
	_exhaust.mesh = eq
	_exhaust.position = Vector3(body_size.x * 0.3, 0.32, -body_size.z * 0.5 - 0.05)
	_exhaust.direction = Vector3(0, 0.25, -1)
	_exhaust.spread = 14.0
	_exhaust.initial_velocity_min = 0.5
	_exhaust.initial_velocity_max = 1.1
	_exhaust.damping_min = 0.8
	_exhaust.damping_max = 1.4
	_exhaust.gravity = Vector3(0, 0.35, 0)
	_exhaust.scale_amount_min = 0.5
	_exhaust.scale_amount_max = 1.0
	var esc := Curve.new()
	esc.add_point(Vector2(0, 0.4))
	esc.add_point(Vector2(1, 2.2))
	_exhaust.scale_amount_curve = esc
	var eg := Gradient.new()
	eg.set_color(0, Color(0.62, 0.62, 0.6, 0.32))
	eg.set_color(1, Color(0.7, 0.7, 0.68, 0.0))
	_exhaust.color_ramp = eg
	_exhaust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_exhaust.emitting = false
	add_child(_exhaust)
	_skids.assign(_skids.filter(func(x: Variant) -> bool: return is_instance_valid(x)))
	_skid_i = 0
	trunk = LootContainer.new()
	trunk.display_name = "Багажник"
	trunk.container_type = "trunk"
	trunk.room_type = "car"
	trunk.search_time = 1.6
	trunk.focus_offset = Vector3(0, 0.9, -body_size.z * 0.5 - 0.3)
	add_child(trunk)
	door = VehicleDoor.new()
	door.set("vehicle", self)
	door.position = Vector3(body_size.x * 0.5 + 0.35, 0, 0.3)
	add_child(door)


# ------------------------------------------------------------------------------------------------ driving
func _physics_process(delta: float) -> void:
	var st := get_world_3d().direct_space_state
	var up := global_basis.y
	var fwd := global_basis.z
	speed = linear_velocity.dot(fwd)
	if driver == null:
		# Left in gear with the parking brake: an abandoned car stops instead of rolling away.
		brake = 1.0
		handbrake = true
		throttle = 0.0
	var max_steer := lerpf(0.6, 0.2, clampf(absf(speed) / top_speed, 0.0, 1.0))
	for i in 4:
		var origin := global_transform * wheel_pos[i]
		var q := PhysicsRayQueryParameters3D.create(origin, origin - up * (REST + WHEEL_R), 1)
		q.exclude = [get_rid()]
		var hit := st.intersect_ray(q)
		_contact[i] = not hit.is_empty()
		var wheel := _wheels[i]
		if hit.is_empty():
			wheel.position.y = lerpf(wheel.position.y, wheel_pos[i].y - REST, 0.2)
			continue
		var dist := origin.distance_to(hit["position"]) - WHEEL_R
		var compression := clampf(REST - dist, 0.0, REST)
		var point: Vector3 = hit["position"]
		var vel := linear_velocity + angular_velocity.cross(point - global_position)
		var spring_f := SPRING * compression - DAMP * vel.dot(up)
		spring_f = maxf(spring_f, 0.0)
		var f := up * spring_f
		# Tyre: steered direction for the front pair.
		var wdir := fwd
		if i < 2:
			wdir = fwd.rotated(up, steer * max_steer)
		var wside := up.cross(wdir).normalized()
		var lat_v := vel.dot(wside)
		var lon_v := vel.dot(wdir)
		var grip := GRIP * (0.45 if handbrake and i >= 2 else 1.0)
		var lat_f := clampf(-lat_v * mass * 0.25 / maxf(delta, 0.001) * 0.35, -grip * spring_f, grip * spring_f)
		f += wside * lat_f
		var drive := (i >= 2 or all_wheel)
		if engine_on and drive and fuel > 0.0 and health > 0.0:
			var target := top_speed if throttle > 0.0 else -8.0
			var k := 1.0 - clampf(lon_v / target, 0.0, 1.0) if target != 0.0 else 0.0
			f += wdir * throttle * engine_force * k / (4.0 if all_wheel else 2.0)
		var stop := brake + (1.0 if handbrake and i >= 2 else 0.0)
		if stop > 0.0:
			f += -wdir * signf(lon_v) * minf(absf(lon_v) * mass * 0.25 / maxf(delta, 0.001), 9000.0 * stop * 0.25)
		f += -wdir * lon_v * ROLL_RESIST * spring_f * 0.1
		apply_force(f, point - global_position)
		if (absf(lat_v) > 2.6 or (stop > 0.5 and absf(lon_v) > 4.0) or (engine_on and drive and absf(throttle) > 0.9
				and absf(lon_v) < 2.5 and i >= 2 and fuel > 0.0)) and spring_f > 500.0:
			_skid(i, point, hit["normal"], vel)
		else:
			_skid_last[i] = Vector3.INF
		wheel.position.y = wheel_pos[i].y - dist
		wheel.rotation.y = steer * max_steer if i < 2 else 0.0
	_wheel_spin += speed * delta / WHEEL_R
	for w in _wheels:
		if w.get_child_count() > 0:
			(w.get_child(0) as Node3D).rotation.x = _wheel_spin
	if engine_on:
		var used := absf(speed) * delta * 0.012 * (0.3 + absf(throttle))
		fuel = maxf(fuel - used - delta * 0.002, 0.0)
		if fuel <= 0.0:
			set_engine(false)
			Events.show_toast("Бензин кончился.")
		_noise_t -= delta
		if _noise_t <= 0.0:
			_noise_t = 1.0
			NoiseSystem.emit(global_position, 14.0 + absf(speed) * 0.8, self)
		_engine.pitch_scale = 0.75 + absf(speed) / top_speed * 1.1 + absf(throttle) * 0.12
	if _interior and _interior.visible:
		_update_interior()
	_exhaust.emitting = engine_on
	_exhaust.initial_velocity_max = 1.1 + absf(throttle) * 1.6
	_check_zombie_hits()
	_check_crash()
	_update_lights()


## Rubber left on the road by a sliding, locked or spinning tyre: short dark decals from a shared pool.
func _skid(i: int, point: Vector3, normal: Vector3, vel: Vector3) -> void:
	var last := _skid_last[i]
	if last != Vector3.INF and last.distance_to(point) < 0.32:
		return
	if last == Vector3.INF:
		_skid_last[i] = point
		return
	var d: Decal
	if _skids.size() < SKID_POOL:
		d = Decal.new()
		d.texture_albedo = _skid_texture()
		d.upper_fade = 0.2
		d.lower_fade = 0.2
		get_tree().current_scene.add_child(d)
		_skids.append(d)
	else:
		_skid_i = (_skid_i + 1) % SKID_POOL
		d = _skids[_skid_i]
		if not is_instance_valid(d):
			d = Decal.new()
			d.texture_albedo = _skid_texture()
			get_tree().current_scene.add_child(d)
			_skids[_skid_i] = d
	var along := point - last
	var seg := along.length()
	d.size = Vector3(0.2, 0.3, seg + 0.08)
	var mid := (point + last) * 0.5
	var z := along.normalized()
	if absf(z.dot(normal)) > 0.95:
		z = vel.normalized()
	var x := normal.cross(z).normalized()
	d.global_transform = Transform3D(Basis(x, normal, x.cross(normal)), mid)
	d.modulate = Color(1, 1, 1, 0.75)
	_skid_last[i] = point


static func _skid_texture() -> ImageTexture:
	if _skid_tex == null:
		var img := Image.create(8, 16, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for y in 16:
			for x in 8:
				var edge := 1.0 - absf(x - 3.5) / 4.0
				img.set_pixel(x, y, Color(0.04, 0.04, 0.04, clampf(edge * 1.4, 0, 1) * rng.randf_range(0.35, 0.7)))
		_skid_tex = ImageTexture.create_from_image(img)
	return _skid_tex


func _update_lights() -> void:
	var on := engine_on and headlights
	for l in _lights:
		l.light_energy = 7.0 if on else 0.0
	_tail.light_energy = (2.0 if brake > 0.1 or throttle < -0.1 else 0.6) if engine_on else 0.0


func _check_crash() -> void:
	var dv := (linear_velocity - _last_vel).length()
	_last_vel = linear_velocity
	if dv > 6.0 and get_contact_count() > 0:
		var dmg := (dv - 6.0) * 4.0
		health = maxf(health - dmg, 0.0)
		Sfx.play_at("car_crash", global_position + Vector3.UP, clampf(-10.0 + dv, -10.0, 4.0))
		NoiseSystem.emit(global_position, 22.0, self)
		if driver:
			driver.camera_shake(clampf(dv * 0.05, 0.1, 0.6))
			if dv > 14.0:
				driver.health.take_damage((dv - 14.0) * 3.0, null, "Авария")
				Events.show_toast("Жёсткий удар! Вас тряхнуло о руль.")
		if health <= 0.0 and engine_on:
			set_engine(false)
			Events.show_toast("Двигатель заглох — машина разбита.")
		if health < 40.0 and _smoke == null:
			_smoke = Smoke.column(self, Vector3(0, 1.1, body_size.z * 0.42), 0.35)


## Zombies hit by the bumper: damage and knockdown by speed; heavy hits dent the car.
func _check_zombie_hits() -> void:
	if absf(speed) < 2.5:
		return
	var now := Time.get_ticks_msec()
	for z in get_tree().get_nodes_in_group("zombies"):
		var zz := z as Zombie
		if zz.is_dead():
			continue
		var local := to_local(zz.global_position)
		if absf(local.x) > body_size.x * 0.5 + 0.35 or absf(local.z) > body_size.z * 0.5 + 0.5 or absf(local.y) > 1.5:
			continue
		if _hit_cd.get(zz.get_instance_id(), 0) > now:
			continue
		_hit_cd[zz.get_instance_id()] = now + 700
		var dir := linear_velocity.normalized()
		var dmg := absf(speed) * 7.0
		zz.take_hit(dmg, dir, absf(speed) * 0.5, 1.0 if absf(speed) > 5.0 else 0.6, driver)
		Sfx.play_at("hit_blunt", zz.global_position + Vector3.UP, 2.0)
		BloodFX.splash(zz.chest(), dir, 1.2)
		linear_velocity *= 0.93
		health = maxf(health - absf(speed) * 0.25, 0.0)


# ------------------------------------------------------------------------------------------------ control
func set_engine(on: bool) -> void:
	if on == engine_on:
		return
	engine_on = on
	if on:
		Sfx.play_at("engine_start", global_position + Vector3.UP, -2.0)
		_engine.play()
		NoiseSystem.emit(global_position, 18.0, self)
	else:
		_engine.stop()
		throttle = 0.0
	engine_changed.emit(on)


func has_key(p: Player) -> bool:
	return key_id == "" or p.inventory.main.stacks.any(func(s: ItemStack) -> bool: return s.key_id == key_id)


## Driver input (called by the player every physics frame while driving).
func drive_input(t: float, s: float, hb: bool, delta: float) -> void:
	throttle = clampf(t, -1.0, 1.0)
	# Pressing back while rolling forward brakes first, then reverses.
	brake = 0.0
	if throttle < 0.0 and speed > 1.0:
		brake = -throttle
		throttle = 0.0
	elif throttle > 0.0 and speed < -1.0:
		brake = throttle
		throttle = 0.0
	if t == 0.0 and absf(speed) < 0.6:
		brake = 0.3
	steer = move_toward(steer, s, delta * 3.2)
	handbrake = hb
	if engine_on:
		sleeping = false


func horn() -> void:
	Sfx.play_at("horn", global_position + Vector3.UP, 2.0)
	NoiseSystem.emit(global_position, 35.0, self)


func kmh() -> int:
	return roundi(absf(speed) * 3.6)


# ------------------------------------------------------------------------------------------------ interior
## Cabin seen from the driver's seat in first person (v0.5): dashboard with a live speedometer, a steering
## wheel that turns with the front wheels, seats, door cards, pillars, headliner and the mirror.
const WHEEL_CENTER := Vector3(0.38, 1.1, 0.36)
var _interior: Node3D
var _steering: Node3D
var _needle: Node3D


func set_interior(on: bool) -> void:
	if on and _interior == null:
		_build_interior()
	if _interior:
		_interior.visible = on


## World points on the rim where the driver's [right, left] hands hold the wheel.
func wheel_grips() -> Array:
	if _steering == null:
		return []
	return [_steering.global_transform * Vector3(-0.172, 0.03, 0.0), _steering.global_transform * Vector3(0.172, 0.03, 0.0)]


func _imat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


func _ibox(parent: Node3D, a: Vector3, b: Vector3, mat: Material, rot := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = (b - a).abs()
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = Transform3D(rot, (a + b) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build_interior() -> void:
	_interior = Node3D.new()
	_interior.name = "Interior"
	add_child(_interior)
	var hw := body_size.x * 0.5 - 0.05
	var floor_y := 0.42
	var belt := 0.36 + body_size.y - 0.02
	var roof := 0.38 + body_size.y + 0.5
	var front := body_size.z * 0.23
	var plastic := _imat(Color("#232427"), 0.7)
	var fabric := _imat(Color("#4d4237"))
	var card := _imat(Color("#5b5248"))
	var liner := _imat(Color("#8c877c"))
	_ibox(_interior, Vector3(-hw, 0.36, -1.3), Vector3(hw, floor_y, front + 0.4), _imat(Color("#1b1b1b")))
	# Dashboard and instrument hood.
	_ibox(_interior, Vector3(-hw, belt - 0.3, front), Vector3(hw, belt - 0.02, front + 0.42), plastic)
	_ibox(_interior, Vector3(0.17, belt - 0.04, front + 0.04), Vector3(0.6, belt + 0.06, front + 0.24), plastic)
	_ibox(_interior, Vector3(-0.1, belt - 0.26, front - 0.05), Vector3(0.12, belt - 0.12, front + 0.02), _imat(Color("#2e2f33"), 0.5))
	var dial := MeshInstance3D.new()
	var dc := CylinderMesh.new()
	dc.top_radius = 0.07
	dc.bottom_radius = 0.07
	dc.height = 0.01
	dial.mesh = dc
	var dm := _imat(Color("#d8d2b8"), 0.6)
	dm.emission_enabled = true
	dm.emission = Color("#b8a870")
	dm.emission_energy_multiplier = 0.25
	dial.material_override = dm
	var face := Basis(Vector3(1, 0, 0), Vector3(0, 0.45, -0.89).normalized(), Vector3(1, 0, 0).cross(Vector3(0, 0.45, -0.89).normalized()))
	dial.transform = Transform3D(face, Vector3(0.36, belt - 0.0, front + 0.05))
	dial.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_interior.add_child(dial)
	_needle = Node3D.new()
	dial.add_child(_needle)
	_needle.position = Vector3(0, 0.008, 0)
	_ibox(_needle, Vector3(-0.004, 0, 0.0), Vector3(0.004, 0.003, 0.06), _imat(Color("#c83020"), 0.5))
	# Steering column and wheel.
	var n := (FPCamera.DRIVER_EYE - WHEEL_CENTER).normalized()
	var x := Vector3(1, 0, 0)
	var wb := Basis(x, n, x.cross(n))
	_ibox(_interior, WHEEL_CENTER - n * 0.32 - Vector3(0.025, 0.025, 0), WHEEL_CENTER - n * 0.02 + Vector3(0.025, 0.025, 0), plastic, Basis.IDENTITY)
	_steering = Node3D.new()
	_steering.name = "SteeringWheel"
	_steering.transform = Transform3D(wb, WHEEL_CENTER)
	_interior.add_child(_steering)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.152
	tm.outer_radius = 0.192
	tm.rings = 24
	tm.ring_segments = 6
	rim.mesh = tm
	rim.material_override = _imat(Color("#1a1a1c"), 0.6)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_steering.add_child(rim)
	_ibox(_steering, Vector3(-0.16, -0.012, -0.018), Vector3(0.16, 0.012, 0.018), plastic)
	_ibox(_steering, Vector3(-0.018, -0.012, -0.16), Vector3(0.018, 0.012, 0.0), plastic)
	_ibox(_steering, Vector3(-0.05, -0.02, -0.05), Vector3(0.05, 0.03, 0.05), _imat(Color("#30302e"), 0.5))
	# Seats.
	for sx in [0.38, -0.38]:
		var back := Basis(Vector3.RIGHT, -0.22)
		_ibox(_interior, Vector3(sx - 0.25, floor_y + 0.12, -0.42), Vector3(sx + 0.25, floor_y + 0.26, 0.06), fabric)
		_ibox(_interior, Vector3(sx - 0.25, floor_y + 0.26, -0.58), Vector3(sx + 0.25, floor_y + 0.95, -0.46), fabric, back)
		_ibox(_interior, Vector3(sx - 0.13, floor_y + 0.98, -0.66), Vector3(sx + 0.13, floor_y + 1.16, -0.56), fabric, back)
	_ibox(_interior, Vector3(-hw + 0.05, floor_y + 0.1, -1.25), Vector3(hw - 0.05, floor_y + 0.85, -1.1), fabric)
	# Door cards below the windows, pillars, headliner, mirror.
	for side in [1.0, -1.0]:
		_ibox(_interior, Vector3(side * hw - 0.03, floor_y, -1.3), Vector3(side * hw + 0.03, belt, front + 0.1), card)
		_ibox(_interior, Vector3(side * hw - 0.08, belt - 0.18, -0.6), Vector3(side * hw - 0.02, belt - 0.12, 0.4), plastic)
		var a0 := Vector3(side * (hw - 0.02), belt, front + 0.4)
		var a1 := Vector3(side * (hw - 0.08), roof - 0.04, front - 0.18)
		var ad := (a1 - a0)
		var ab := Basis.looking_at(ad.normalized(), Vector3.UP)
		var pil := _ibox(_interior, Vector3(-0.035, -0.04, 0), Vector3(0.035, 0.04, -ad.length()), plastic)
		pil.transform = Transform3D(ab, a0) * Transform3D(Basis.IDENTITY, Vector3(0, 0, -ad.length() * 0.5))
		_ibox(_interior, Vector3(side * (hw - 0.06), belt, -0.36), Vector3(side * hw, roof - 0.03, -0.24), card)
		_ibox(_interior, Vector3(side * (hw - 0.06), belt, -1.32), Vector3(side * hw, roof - 0.05, -1.12), card)
	_ibox(_interior, Vector3(-hw, roof - 0.06, -1.3), Vector3(hw, roof - 0.02, front - 0.15), liner)
	_ibox(_interior, Vector3(-0.1, roof - 0.12, front - 0.2), Vector3(0.1, roof - 0.07, front - 0.17), plastic)
	_ibox(_interior, Vector3(-0.09, roof - 0.115, front - 0.205), Vector3(0.09, roof - 0.075, front - 0.199), _imat(Color("#8a9aa8"), 0.05))


func _update_interior() -> void:
	if _steering == null:
		return
	var n := (FPCamera.DRIVER_EYE - WHEEL_CENTER).normalized()
	var x := Vector3(1, 0, 0)
	_steering.transform = Transform3D(Basis(x, n, x.cross(n)) * Basis(Vector3.UP, -steer * 2.4), WHEEL_CENTER)
	_needle.rotation.y = 2.2 - clampf(absf(speed) * 3.6 / 160.0, 0.0, 1.0) * 4.4


func seat_transform() -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(0.38, 0.55, -0.1))


func exit_point() -> Vector3:
	for side in [1.0, -1.0]:
		var p := global_transform * Vector3(side * (body_size.x * 0.5 + 0.7), 0.1, 0.2)
		var st := get_world_3d().direct_space_state
		var q := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.3
		q.shape = sph
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.9, 0))
		q.collision_mask = 1 | 4
		q.exclude = [get_rid()]
		if st.intersect_shape(q, 1).is_empty():
			return p
	return global_transform * Vector3(0, 0.1, -body_size.z * 0.5 - 1.0)


func save_state() -> Dictionary:
	var t := global_transform
	return {"o": [t.origin.x, t.origin.y, t.origin.z], "b": [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y,
		t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z], "fuel": fuel, "hp": health, "hw": hotwired,
		"trunk": trunk.save_state()}


func load_state(d: Dictionary) -> void:
	var o: Array = d["o"]
	var b: Array = d["b"]
	global_transform = Transform3D(Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8])),
		Vector3(o[0], o[1], o[2]))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	fuel = float(d.get("fuel", fuel))
	health = float(d.get("hp", health))
	hotwired = bool(d.get("hw", false))
	trunk.load_state(d.get("trunk", {}))
