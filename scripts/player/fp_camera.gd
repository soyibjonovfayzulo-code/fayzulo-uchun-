class_name FPCamera
extends Node3D
## First-person view (v0.5). The camera sits in the survivor's eyes and follows the animated head, so
## crouching, sitting, lying in bed, climbing through a window, driving and dying all move the view with
## the body. Mouse look, head bob and strafe roll, landing dip, recoil, hit jolts, sprint and aim FOV.
## The survivor's own head, torso and arms are drawn only into shadows (visual layer 20); legs stay
## visible when you look down. Hands and the held item are an FPViewmodel in front of the lens.

const PITCH_LIMIT := 1.5
const BASE_SENS := 0.0024
## Visual layer 20: parts of the survivor the first-person camera must not see.
const HIDDEN_LAYER := 1 << 19
## Eyes in the driver's seat, car local frame (car faces +Z, driver on the left = +X).
const DRIVER_EYE := Vector3(0.38, 1.36, -0.2)

var player: Player
var camera: Camera3D
var viewmodel: FPViewmodel
var flashlight: SpotLight3D
var post: MeshInstance3D
var active := false
var aiming := false
var look_yaw := 0.0
var look_pitch := 0.0
## Mouse movement this frame (radians), read by the viewmodel for weapon sway.
var look_delta := Vector2.ZERO
var drive_yaw := 0.0
var drive_pitch := -0.08
## Autotests: never grab the mouse, aim without a captured cursor.
var test_mode := false

var _head: Node3D
var _eye_h := 1.62
var _eye := Vector3.ZERO
var _roll := 0.0
var _shake := 0.0
var _recoil := Vector2.ZERO
var _recoil_vel := Vector2.ZERO
var _jolt := Vector3.ZERO
var _jolt_vel := Vector3.ZERO
var _bob_t := 0.0
var _bob_amp := 0.0
var _dip := 0.0
var _dip_vel := 0.0
var _was_floor := true
var _fall_speed := 0.0
var _dead_t := 0.0
var _prev_state := -1
var _light_basis := Basis.IDENTITY
var _last_mouse_mode := -1


func _ready() -> void:
	name = "FPCamera"
	var is_mob := OS.has_feature("mobile") or OS.get_name() == "Android"
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = GameOptions.fov
	camera.near = 0.05 if is_mob else 0.03
	camera.far = 115.0 if is_mob else 340.0
	camera.cull_mask = 0xFFFFF & ~HIDDEN_LAYER
	camera.current = false
	add_child(camera)
	viewmodel = FPViewmodel.new()
	viewmodel.name = "Viewmodel"
	camera.add_child(viewmodel)
	flashlight = SpotLight3D.new()
	flashlight.name = "FPFlashlight"
	flashlight.top_level = true
	flashlight.spot_angle = 26.0
	flashlight.spot_attenuation = 0.8
	flashlight.spot_range = 16.0
	flashlight.light_energy = 6.0
	flashlight.light_color = Color("#fff1d0")
	flashlight.shadow_enabled = not is_mob
	flashlight.visible = false
	add_child(flashlight)
	visible = false
	var args := OS.get_cmdline_user_args()
	test_mode = "--autotest" in args or "--fps" in args or "--tour" in args


func bind(p: Player) -> void:
	player = p
	viewmodel.bind(p, self)
	_head = p.model.find_child("Head", true, false) as Node3D
	look_yaw = p.yaw + PI


func set_active(on: bool) -> void:
	active = on
	visible = on
	camera.current = on
	if post:
		post.visible = on and GameOptions.outline
	if on and player:
		look_yaw = player.yaw + PI
		look_pitch = -0.05
		_eye_h = 1.62
		_eye = _eye_target()
		viewmodel.raise()
	if not on:
		flashlight.visible = false
		_set_mouse(false)


func forward() -> Vector3:
	return -camera.global_basis.z


## Ray the survivor aims along: [origin, direction].
func aim_ray() -> Array:
	return [camera.global_position, -camera.global_basis.z]


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Muzzle climb in radians (pitch up, random yaw).
func add_recoil(pitch: float, yaw: float) -> void:
	_recoil_vel += Vector2(pitch, yaw) * 22.0


## A blow from world direction `from` (pointing from the attacker to the player).
func jolt(from: Vector3, strength := 1.0) -> void:
	if not from.is_finite() or from.length_squared() < 0.0001:
		return
	var local := camera.global_basis.orthonormalized().inverse() * from.normalized()
	if not local.is_finite():
		return
	_jolt_vel += Vector3(-local.z * 3.0, local.x * 2.0, -local.x * 5.0) * strength
	add_shake(0.35 * strength)


func _input(event: InputEvent) -> void:
	if not active or player == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look((event as InputEventMouseMotion).screen_relative)


## Mouse look by `rel` screen pixels (also used by tests).
func look(rel: Vector2) -> void:
	if not rel.is_finite():
		return
	var sens := BASE_SENS * GameOptions.mouse_sens * (0.55 if aiming else 1.0)
	var d := Vector2(-rel.x * sens, -rel.y * sens)
	look_delta += d
	if player.state == Player.State.DEAD:
		return
	if player.state == Player.State.DRIVING:
		drive_yaw = clampf(drive_yaw + d.x, -1.9, 1.9)
		drive_pitch = clampf(drive_pitch + d.y, -0.9, 0.7)
		return
	look_yaw = wrapf(look_yaw + d.x, -PI, PI)
	look_pitch = clampf(look_pitch + d.y, -PITCH_LIMIT, PITCH_LIMIT)


func _process(delta: float) -> void:
	if not active or player == null:
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	delta = minf(delta, 0.05)
	if not is_finite(look_yaw):
		look_yaw = player.yaw + PI if is_finite(player.yaw) else 0.0
	if not is_finite(look_pitch):
		look_pitch = 0.0
	if not is_finite(_eye_h):
		_eye_h = 1.62
	_update_mouse_mode()
	var st := player.state
	if st != _prev_state:
		_on_state_changed(_prev_state, st)
		_prev_state = st
	var w := player.inventory.weapon()
	var mobile_touch := OS.has_feature("mobile") or OS.get_name() == "Android" or DisplayServer.is_touchscreen_available()
	aiming = st == Player.State.NORMAL and w != null and w.item.attack_style == "shoot" \
		and Input.is_action_pressed("context_menu") and player.interactor.focused == null \
		and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or test_mode or (mobile_touch and not _ui_blocking()))
	# Eye position: follows the head, filtered so the gait animation does not shake the lens.
	var target := _eye_target()
	if not _eye.is_finite():
		_eye = target
	var k := 1.0 - exp(-delta * (30.0 if st == Player.State.DRIVING else 14.0))
	_eye = _eye.lerp(target, k) if _eye.distance_to(target) < 2.0 else target
	# Head bob, strafe roll, landing dip.
	var hv := Vector3(player.velocity.x, 0, player.velocity.z)
	if not hv.is_finite():
		hv = Vector3.ZERO
	var spd := hv.length() if st == Player.State.NORMAL and player.is_on_floor() else 0.0
	_bob_amp = lerpf(_bob_amp, clampf(spd / 5.0, 0.0, 1.0), clampf(delta * 6.0, 0.0, 1.0))
	_bob_t = fmod(_bob_t + delta * (4.2 + spd * 1.55), TAU * 100.0)
	var bob := Vector3.ZERO
	var bob_roll := 0.0
	if GameOptions.head_bob:
		var a := _bob_amp * (0.55 if player.crouching else 1.0) * (0.5 if aiming else 1.0)
		bob = Vector3(sin(_bob_t) * 0.028 * a, -absf(cos(_bob_t)) * 0.05 * a, 0)
		bob_roll = sin(_bob_t) * 0.008 * a
	var right := Vector3(cos(look_yaw), 0, -sin(look_yaw))
	var strafe := hv.dot(right) if st == Player.State.NORMAL else 0.0
	_roll = lerpf(_roll, -strafe * 0.006, clampf(delta * 6.0, 0.0, 1.0))
	var on_floor := player.is_on_floor()
	if on_floor and not _was_floor and st == Player.State.NORMAL:
		_dip_vel -= clampf(_fall_speed, 1.5, 14.0) * 0.12
	if not on_floor:
		_fall_speed = maxf(-player.velocity.y, 0.0)
	_was_floor = on_floor
	var s_steps := clampi(ceili(delta / 0.012), 1, 6)
	var s_dt := delta / float(s_steps)
	for _i in s_steps:
		_dip_vel += (-_dip * 120.0 - _dip_vel * 18.0) * s_dt
		_dip += _dip_vel * s_dt
		# Recoil and jolts return through damped springs.
		_recoil_vel += (-_recoil * 90.0 - _recoil_vel * 16.0) * s_dt
		_recoil += _recoil_vel * s_dt
		_jolt_vel += (-_jolt * 110.0 - _jolt_vel * 14.0) * s_dt
		_jolt += _jolt_vel * s_dt
	if not is_finite(_dip) or absf(_dip) > 2.0:
		_dip = 0.0
		_dip_vel = 0.0
	if not _recoil.is_finite() or _recoil.length_squared() > 4.0:
		_recoil = Vector2.ZERO
		_recoil_vel = Vector2.ZERO
	if not _jolt.is_finite() or _jolt.length_squared() > 4.0:
		_jolt = Vector3.ZERO
		_jolt_vel = Vector3.ZERO
	_shake = maxf(_shake - delta * 1.6, 0.0)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.02
	# Orientation.
	var rot := Basis.IDENTITY
	match st:
		Player.State.DRIVING:
			var v := player.vehicle
			if v and is_instance_valid(v):
				if absf(v.speed) > 3.0:
					drive_yaw = lerpf(drive_yaw, 0.0, clampf(delta * 0.6, 0.0, 1.0))
				rot = v.global_basis.orthonormalized() * Basis(Vector3.UP, PI + drive_yaw) * Basis(Vector3.RIGHT, drive_pitch)
				look_yaw = rot.get_euler().y
				look_pitch = 0.0
		Player.State.DEAD:
			_dead_t += delta
			var base := Basis(Vector3.UP, look_yaw) * Basis(Vector3.RIGHT, look_pitch)
			if _head and _head.global_basis.determinant() > 0.001 and _head.global_position.is_finite():
				var hb := _head.global_basis.orthonormalized() * Basis(Vector3.UP, PI)
				rot = base.slerp(hb, clampf(_dead_t * 1.2, 0.0, 1.0) * 0.85)
			else:
				rot = base * Basis(Vector3.FORWARD, clampf(_dead_t, 0.0, 1.0) * 1.2)
		_:
			rot = Basis(Vector3.UP, look_yaw) * Basis(Vector3.RIGHT, look_pitch)
	rot = rot * Basis.from_euler(Vector3(_recoil.x + _jolt.x + sh.x, _recoil.y + _jolt.y + sh.y,
		_roll + bob_roll + _jolt.z + sh.z))
	var final_origin := _eye + right * bob.x + Vector3(0, bob.y + _dip, 0)
	if not final_origin.is_finite():
		final_origin = player.global_position + Vector3(0, 1.6, 0)
	global_transform = Transform3D(rot.orthonormalized(), final_origin)
	# The body turns with the view.
	if st == Player.State.NORMAL:
		player.fp_face(look_yaw + PI)
	# Field of view: wider when sprinting, narrow when aiming down the sights.
	var fov_t := GameOptions.fov + (8.0 if player.running and spd > 3.0 else 0.0) - (26.0 if aiming else 0.0)
	camera.fov = lerpf(camera.fov, fov_t, clampf(delta * 9.0, 0.0, 1.0))
	viewmodel.tick(delta)
	_update_flashlight(delta)
	look_delta = Vector2.ZERO


func _eye_target() -> Vector3:
	var p := player.global_position
	if not p.is_finite():
		return Vector3(45.0, 1.7, 35.0)
	match player.state:
		Player.State.DRIVING:
			if player.vehicle and is_instance_valid(player.vehicle):
				var dp := player.vehicle.global_transform * DRIVER_EYE
				if dp.is_finite():
					return dp
		Player.State.NORMAL:
			if _head and _head.global_position.is_finite():
				var raw_h := _head.global_position.y - p.y + 0.12
				if is_finite(raw_h):
					var h := clampf(raw_h, 0.75, 1.72)
					_eye_h = lerpf(_eye_h, h, 0.12)
			return p + Vector3(0, _eye_h, 0)
	if _head and _head.global_position.is_finite():
		var hp := _head.global_position + Vector3(0, 0.1, 0)
		if hp.distance_to(p) < 2.5:
			return hp
	return p + Vector3(0, 1.15 if player.state == Player.State.SEATED else 1.6, 0)


func _on_state_changed(from: int, to: int) -> void:
	if to == Player.State.DEAD:
		_dead_t = 0.0
	if to == Player.State.DRIVING:
		drive_yaw = 0.0
		drive_pitch = -0.08
	if from == Player.State.DRIVING:
		look_yaw = player.yaw + PI
		look_pitch = -0.05
	if to == Player.State.SEATED and player.get("_seat_lying"):
		look_pitch = 1.1
	if from == Player.State.SEATED:
		look_pitch = clampf(look_pitch, -0.4, 0.3)
	viewmodel.raise()


func _update_flashlight(delta: float) -> void:
	var want: bool = player.fp_flashlight_on()
	flashlight.visible = want
	if not want:
		return
	var fl: ItemStack = player.inventory.equipped["offhand"]
	if fl:
		flashlight.spot_range = fl.item.light_range + 2.0
		flashlight.light_energy = 6.0 * clampf(fl.charge * 4.0, 0.25, 1.0)
	_light_basis = _light_basis.slerp(camera.global_basis.orthonormalized(), clampf(delta * 16.0, 0.0, 1.0)).orthonormalized()
	var at := viewmodel.flashlight_anchor()
	flashlight.global_transform = Transform3D(_light_basis, at)


func _update_mouse_mode() -> void:
	var want := player.state != Player.State.DEAD and not get_tree().paused and not _ui_blocking()
	_set_mouse(want)


func _set_mouse(capture: bool) -> void:
	if DisplayServer.get_name() == "headless" or test_mode:
		return
	if OS.has_feature("mobile") or OS.get_name() == "Android" or DisplayServer.is_touchscreen_available():
		return
	var mode := Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	if mode == _last_mouse_mode and Input.mouse_mode == mode:
		return
	_last_mouse_mode = mode
	Input.mouse_mode = mode
	if not capture:
		var vp := get_tree().root
		vp.warp_mouse(vp.get_visible_rect().size * 0.5)


func _ui_blocking() -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	return hud != null and bool(hud.call("wants_mouse"))
