class_name CharacterAnimator
extends Node
## Procedural animation for the rigid-part human rig (Blender: assets/characters/*.glb), shared by the
## player and zombies. Every joint follows its target through a critically damped spring, so poses flow
## into each other instead of snapping. Reference: Project Zomboid Build 41 locomotion and combat.
##
## Locomotion is one continuous gait driven by speed (walk -> jog -> run): pelvis bob and sway, counter-
## rotating shoulders, knee lift in swing and heel kick in the run, forward lean, lean into turns, weapon
## carry poses (one- and two-handed), idle breathing, weight shifts and looking around. Attacks have
## anticipation, strike, follow-through and recovery; hits add a flinch impulse; falls are animated.
## Zombies get one of four shambling gaits, reach for their prey, lunge and bite, and can crawl.
## Conventions: model faces +Z; rotation.x > 0 swings a hanging limb backwards; Torso.x > 0 leans forward.

signal step(foot: int)

enum Pose { STAND, CROUCH, SIT, LIE, CLIMB, DEAD, WORK, KNOCKED, GETUP, STAGGER, CRAWL, DRIVE }
enum Gait { REACHER, LIMPER, HUNCHED, LURCHER }

const PART_NAMES := ["Hips", "Torso", "Head", "ArmL", "ArmR", "ForearmL", "ForearmR", "LegL", "LegR", "ShinL", "ShinR"]

@export var model_path: NodePath

var pose := Pose.STAND
var speed := 0.0
var running := false
## 0..1 progress of the current attack, or -1 when not attacking.
var attack_t := -1.0
## swing | stab | shove | stomp | finish | shoot | grab | bash
var attack_style := "swing"
var holding := false
## Long weapons (bat, axe, crowbar, pipe) are carried and swung with both hands.
var two_handed := false
## Shotgun: shouldered long gun.
var rifle := false
var zombie := false
var gait := Gait.REACHER
## Zombie in pursuit: arms reach for the prey.
var hunting := false
## What the hands do in the WORK pose: search | eat | drink | bandage | hammer | cook | read
var work_kind := "search"
## Steering input while driving (-1..1).
var steer := 0.0
var lunge := 0.0

var _parts := {}
var _rest_pos := {}
var _rot := {}
var _vel := {}
var _hips_off := Vector3.ZERO
var _hips_vel := Vector3.ZERO
var _phase := 0.0
var _time := 0.0
var _last_sin := 0.0
var _limp := 1.0
var _model: Node3D
var _prev_yaw := 0.0
var _turn := 0.0
var _pose_prev := Pose.STAND
var _pose_t := 0.0
var _impulse := Vector3.ZERO
var _impulse_vel := Vector3.ZERO
var _look := 0.0
var _look_target := 0.0
var _look_t := 2.0
var _shift := 0.0
var _shift_target := 0.0
var _shift_t := 3.0
var _aim_hold := 0.0
var _last_style := ""
var _sprawl := Vector3.ZERO
var _face_down := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if model_path != NodePath():
		bind(get_node(model_path))
	_rng.randomize()
	_limp = _rng.randf_range(0.7, 1.3)
	_time = _rng.randf() * 10.0
	_sprawl = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))


func bind(model: Node) -> void:
	_parts.clear()
	_model = model as Node3D
	for n in PART_NAMES:
		var node := model.find_child(n, true, false) as Node3D
		if node:
			_parts[n] = node
			_rest_pos[n] = node.position
			_rot[n] = Vector3.ZERO
			_vel[n] = Vector3.ZERO
	if _model:
		_prev_yaw = _model.global_rotation.y


## Jump straight to the current pose (restored corpses, teleports).
func snap() -> void:
	var t := _targets(0.0)
	for n in _parts:
		_rot[n] = t[n]
		_vel[n] = Vector3.ZERO
		(_parts[n] as Node3D).rotation = t[n]
	_hips_off = t.get("_hips", Vector3.ZERO)
	_hips_vel = Vector3.ZERO
	_apply_hips()


## A blow from `dir_world` (normalised, pointing from the attacker) jolts the upper body.
func hit(dir_world: Vector3, strength := 1.0) -> void:
	if _model == null or not dir_world.is_finite():
		return
	var local := _model.global_basis.orthonormalized().inverse() * dir_world
	if not local.is_finite():
		return
	# Pushed from the front -> rock back (negative x lean); from the side -> roll away.
	_impulse_vel += Vector3(local.z * 9.0, local.x * 4.0, -local.x * 7.0) * strength


func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	delta = minf(delta, 1.0 / 20.0)
	_time += delta
	if pose != _pose_prev:
		_pose_prev = pose
		_pose_t = 0.0
		if pose == Pose.DEAD or pose == Pose.KNOCKED:
			_face_down = _rng.randf() < 0.35
	_pose_t += delta
	if _model:
		var yaw := _model.global_rotation.y
		if is_finite(yaw) and is_finite(_prev_yaw):
			_turn = lerpf(_turn, angle_difference(_prev_yaw, yaw) / maxf(delta, 0.001), clampf(delta * 8.0, 0.0, 1.0))
			_prev_yaw = yaw
		else:
			_turn = 0.0
			_prev_yaw = 0.0
	_update_idle_timers(delta)
	if attack_t >= 0.0:
		_last_style = attack_style
		if attack_style == "shoot":
			_aim_hold = 0.7
	else:
		_aim_hold = maxf(_aim_hold - delta, 0.0)
	var t := _targets(delta)
	# Flinch spring (sub-stepped so it never explodes on slow mobile frames).
	var imp_steps := clampi(ceili(delta / 0.012), 1, 6)
	var imp_dt := delta / float(imp_steps)
	for _s in imp_steps:
		_impulse_vel += (-_impulse * 140.0 - _impulse_vel * 14.0) * imp_dt
		_impulse += _impulse_vel * imp_dt
	if not _impulse.is_finite() or _impulse.length_squared() > 16.0:
		_impulse = Vector3.ZERO
		_impulse_vel = Vector3.ZERO
	t["Torso"] += Vector3(_impulse.x, _impulse.y, _impulse.z)
	t["Head"] += Vector3(_impulse.x * 0.8, 0, _impulse.z * 0.6)
	var omega := _omega()
	# Critically damped springs: semi-implicit Euler requires omega * dt < 1.0 (we keep omega * dt <= 0.30).
	var steps := clampi(ceili(delta * omega / 0.30), 1, 10)
	var dt := delta / float(steps)
	for i in steps:
		for n in _parts:
			var x: Vector3 = _rot[n]
			var v: Vector3 = _vel[n]
			var target_v: Vector3 = t[n]
			v += ((target_v - x) * omega * omega - v * 2.0 * omega) * dt
			x += v * dt
			if not x.is_finite() or not v.is_finite() or x.length_squared() > 100.0:
				x = target_v if target_v.is_finite() else Vector3.ZERO
				v = Vector3.ZERO
			_rot[n] = x
			_vel[n] = v
		var ht: Vector3 = t.get("_hips", Vector3.ZERO)
		_hips_vel += ((ht - _hips_off) * omega * omega - _hips_vel * 2.0 * omega) * dt
		_hips_off += _hips_vel * dt
		if not _hips_off.is_finite() or not _hips_vel.is_finite() or _hips_off.length_squared() > 16.0:
			_hips_off = ht if ht.is_finite() else Vector3.ZERO
			_hips_vel = Vector3.ZERO
	for n in _parts:
		(_parts[n] as Node3D).rotation = _rot[n]
	_apply_hips()


func _apply_hips() -> void:
	var hips := _parts.get("Hips") as Node3D
	if hips:
		var rp: Vector3 = _rest_pos["Hips"]
		hips.position = rp + _hips_off


## Joint stiffness per situation (higher = snappier).
func _omega() -> float:
	if attack_t >= 0.0:
		return 26.0
	match pose:
		Pose.DEAD, Pose.KNOCKED:
			return 7.0 if _pose_t < 0.6 else 10.0
		Pose.GETUP:
			return 7.0
		Pose.STAGGER:
			return 20.0
		Pose.LIE, Pose.SIT:
			return 9.0
		Pose.STAND, Pose.CROUCH, Pose.CRAWL:
			# Gait cycles run up to ~2 Hz: stiff joints keep the full stride, softer when standing still.
			return lerpf(16.0, 44.0, clampf(speed / 2.0, 0.0, 1.0))
	return 16.0


func _update_idle_timers(delta: float) -> void:
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = _rng.randf_range(2.0, 5.5)
		_look_target = _rng.randf_range(-0.6, 0.6) if _rng.randf() < 0.7 else 0.0
	_look = lerpf(_look, _look_target, clampf(delta * 3.0, 0.0, 1.0))
	_shift_t -= delta
	if _shift_t <= 0.0:
		_shift_t = _rng.randf_range(3.0, 7.0)
		_shift_target = -_shift_target if _shift_target != 0.0 else 1.0
	_shift = lerpf(_shift, _shift_target, clampf(delta * 1.5, 0.0, 1.0))


func _zero() -> Dictionary:
	var t := {}
	for n in _parts:
		t[n] = Vector3.ZERO
	t["_hips"] = Vector3.ZERO
	return t


func _targets(delta: float) -> Dictionary:
	var t := _zero()
	match pose:
		Pose.STAND, Pose.CROUCH:
			if zombie:
				_zombie_locomotion(t, delta)
			else:
				_locomotion(t, delta, pose == Pose.CROUCH)
		Pose.SIT:
			_sit(t)
		Pose.DRIVE:
			_sit(t)
			t["ArmL"] = Vector3(-1.05, 0, 0.12 + steer * 0.25)
			t["ArmR"] = Vector3(-1.05, 0, -0.12 + steer * 0.25)
			t["ForearmL"] = Vector3(-0.55 - steer * 0.2, 0, 0)
			t["ForearmR"] = Vector3(-0.55 + steer * 0.2, 0, 0)
			t["Torso"] = Vector3(0.05, 0, steer * 0.06)
			t["Head"] = Vector3(-0.05, steer * 0.25, 0)
		Pose.LIE:
			var br := sin(_time * 1.1)
			t["Torso"] = Vector3(br * 0.02, 0, 0)
			t["ArmL"] = Vector3(-0.15 + br * 0.02, 0, 0.25)
			t["ArmR"] = Vector3(-0.15, 0, -0.25)
			t["ForearmL"] = Vector3(-0.3, 0, 0)
			t["ShinL"] = Vector3(0.1, 0, 0)
			t["ShinR"] = Vector3(0.35, 0, 0)
			t["LegR"] = Vector3(-0.2, 0, 0)
			t["Head"] = Vector3(0, 0.2 * sin(_time * 0.15), 0)
		Pose.WORK:
			_work(t)
		Pose.CLIMB:
			var k := sin(_time * 8.0)
			t["LegL"] = Vector3(-1.4 + k * 0.25, 0, 0.12)
			t["LegR"] = Vector3(-0.35 - k * 0.3, 0, -0.1)
			t["ShinL"] = Vector3(1.6, 0, 0)
			t["ShinR"] = Vector3(0.7, 0, 0)
			t["Torso"] = Vector3(0.65, 0, 0)
			t["Head"] = Vector3(-0.4, 0, 0)
			t["ArmL"] = Vector3(-1.45, 0, 0.25)
			t["ArmR"] = Vector3(-1.45, 0, -0.25)
			t["ForearmL"] = Vector3(-0.4, 0, 0)
			t["ForearmR"] = Vector3(-0.4, 0, 0)
			t["_hips"] = Vector3(0, -0.12, 0)
		Pose.DEAD, Pose.KNOCKED:
			_fallen(t, pose == Pose.KNOCKED)
		Pose.GETUP:
			_getup(t)
		Pose.STAGGER:
			var k := minf(_pose_t / 0.5, 1.0)
			t["Torso"] = Vector3(-0.4 + k * 0.3, 0.25, 0.12)
			t["Head"] = Vector3(0.5 - k * 0.3, 0, 0.25)
			t["ArmL"] = Vector3(-0.7, 0, 0.95 + sin(_time * 18.0) * 0.2)
			t["ArmR"] = Vector3(-0.2, 0, -1.05)
			t["ForearmL"] = Vector3(-0.6, 0, 0)
			t["ForearmR"] = Vector3(-0.3, 0, 0)
			t["LegL"] = Vector3(0.3, 0, 0.06)
			t["LegR"] = Vector3(-0.45, 0, -0.06)
			t["ShinR"] = Vector3(0.55, 0, 0)
			t["ShinL"] = Vector3(0.15, 0, 0)
			t["_hips"] = Vector3(0, -0.05, -0.08)
		Pose.CRAWL:
			_crawl(t, delta)
	lunge = 0.0
	if attack_t >= 0.0:
		_apply_attack(t, attack_t)
	elif _aim_hold > 0.0 and not zombie and pose == Pose.STAND:
		_aim(t, 0.0)
	t["_hips"] = (t["_hips"] as Vector3) + Vector3(0, 0, lunge)
	return t


# ------------------------------------------------------------------------------------------------ survivor gait
func _locomotion(t: Dictionary, delta: float, crouch: bool) -> void:
	var w_run := smoothstep(2.7, 4.7, speed)
	var amp := clampf(speed / 1.5, 0.0, 1.0)
	var moving := speed > 0.12
	var stride := lerpf(1.35, 2.45, w_run) * (0.72 if crouch else 1.0)
	if moving:
		_phase = fmod(_phase + delta * speed / stride * TAU, TAU)
	else:
		# Settle the feet together.
		var target := 0.0 if _phase < PI * 0.5 or _phase > PI * 1.5 else PI
		_phase = lerp_angle(_phase, target, clampf(delta * 5.0, 0.0, 1.0))
	var s := sin(_phase)
	var c := cos(_phase)
	var a_f := lerpf(0.46, 0.98, w_run) * amp
	var a_b := lerpf(0.36, 0.55, w_run) * amp
	var a_k := lerpf(0.78, 1.55, w_run) * amp
	for side in [0, 1]:
		var ss := s if side == 0 else -s
		var cc := c if side == 0 else -c
		var leg := "LegL" if side == 0 else "LegR"
		var shin := "ShinL" if side == 0 else "ShinR"
		var thigh := -(ss * a_f if ss > 0.0 else ss * a_b)
		var knee := a_k * pow(maxf(cc, 0.0), 1.3) + 0.07 * amp + w_run * maxf(-ss, 0.0) * 0.95 * amp
		t[leg] = Vector3(thigh, 0, (0.04 if side == 0 else -0.04))
		t[shin] = Vector3(knee, 0, 0)
	# Arms swing against the legs; elbows bend more on the forward swing and in the run.
	var a_arm := lerpf(0.34, 0.85, w_run) * amp
	for side in [0, 1]:
		var ss := s if side == 0 else -s
		var arm := "ArmL" if side == 0 else "ArmR"
		var fore := "ForearmL" if side == 0 else "ForearmR"
		var sx := 1.0 if side == 0 else -1.0
		t[arm] = Vector3(ss * a_arm, 0, sx * lerpf(0.07, 0.14, w_run))
		t[fore] = Vector3(lerpf(-0.16, -1.45, w_run) - maxf(-ss, 0.0) * lerpf(0.28, 0.25, w_run) * amp, 0, 0)
	var lean := lerpf(0.04, 0.3, w_run) * amp
	var turn_lean := clampf(-_turn * 0.06, -0.22, 0.22) * amp
	t["Torso"] = Vector3(lean + sin(_time * 1.7) * 0.015 * (1.0 - amp), -s * 0.16 * amp, turn_lean)
	t["Hips"] = Vector3(0, s * 0.1 * amp, -c * 0.035 * amp * (1.0 - w_run))
	t["Head"] = Vector3(-lean * 0.55 + s * s * 0.03 * amp, s * 0.07 * amp + _look * (1.0 - amp), -turn_lean * 0.5)
	var bob := lerpf(0.028, 0.06, w_run) * amp
	var hip_y := -bob * s * s + (bob * 0.5 if w_run > 0.5 else 0.0)
	var hip_x := c * 0.022 * amp * (1.0 - w_run)
	# Idle: breathing and weight on one leg.
	if not moving:
		var br := sin(_time * 1.6)
		t["Torso"] += Vector3(br * 0.012, 0, 0)
		t["ArmL"] += Vector3(0, 0, 0.02 + br * 0.01)
		t["ArmR"] += Vector3(0, 0, -0.02 - br * 0.01)
		t["Hips"] += Vector3(0, 0, _shift * 0.05)
		t["Torso"] += Vector3(0, 0, -_shift * 0.04)
		t["LegL" if _shift > 0.0 else "LegR"] += Vector3(-0.08, 0, 0)
		t["ShinL" if _shift > 0.0 else "ShinR"] += Vector3(0.22 * absf(_shift), 0, 0)
		hip_x += _shift * 0.03
		hip_y -= 0.012 * absf(_shift)
	if crouch:
		for side in ["L", "R"]:
			t["Leg" + side] += Vector3(-1.02, 0, 0.05 if side == "L" else -0.05)
			t["Shin" + side] = Vector3(1.6, 0, 0) + (t["Shin" + side] as Vector3) * 0.35
		t["Torso"] = Vector3(0.48, -s * 0.08 * amp, turn_lean)
		t["Head"] = Vector3(-0.36, _look * 0.6 * (1.0 - amp), 0)
		t["ArmL"] = Vector3(-0.42 + s * 0.12 * amp, 0, 0.12)
		t["ArmR"] = Vector3(-0.42 - s * 0.12 * amp, 0, -0.12)
		t["ForearmL"] = Vector3(-0.65, 0, 0)
		t["ForearmR"] = Vector3(-0.65, 0, 0)
		hip_y = -0.36 - 0.015 * s * s * amp
	_carry(t, s, amp, w_run, crouch)
	t["_hips"] = Vector3(hip_x, hip_y, 0)
	if moving and signf(s) != signf(_last_sin):
		step.emit(0 if s > 0 else 1)
	_last_sin = s


## Weapon carry: one-handed weapons low in the right hand, long weapons across the body in both hands,
## guns held ready.
func _carry(t: Dictionary, s: float, amp: float, w_run: float, crouch: bool) -> void:
	if not holding:
		return
	if rifle:
		t["ArmR"] = Vector3(-0.35 - s * 0.06 * amp, 0, -0.2)
		t["ForearmR"] = Vector3(-1.25, 0, 0)
		t["ArmL"] = Vector3(-0.85 + s * 0.06 * amp, 0, -0.3)
		t["ForearmL"] = Vector3(-0.75, 0, 0)
	elif two_handed:
		t["ArmR"] = Vector3(-0.5 - s * 0.08 * amp, 0, 0.1)
		t["ForearmR"] = Vector3(-0.95 - w_run * 0.3, 0, 0)
		t["ArmL"] = Vector3(-0.72 + s * 0.08 * amp, 0, -0.38)
		t["ForearmL"] = Vector3(-1.05 - w_run * 0.3, 0, 0)
	else:
		t["ArmR"] = Vector3(-0.28 - s * 0.25 * amp * (1.0 + w_run), 0, -0.1)
		t["ForearmR"] = Vector3(-0.6 - w_run * 0.7, 0, 0)
	if crouch:
		t["ArmR"] += Vector3(-0.2, 0, 0)
		t["ArmL"] += Vector3(-0.1, 0, 0)


func _sit(t: Dictionary) -> void:
	var br := sin(_time * 1.4)
	t["LegL"] = Vector3(-1.5, 0, 0.08)
	t["LegR"] = Vector3(-1.5, 0, -0.08)
	t["ShinL"] = Vector3(1.45, 0, 0)
	t["ShinR"] = Vector3(1.3 + _shift * 0.1, 0, 0)
	t["Torso"] = Vector3(0.08 + br * 0.012, _look * 0.15, 0)
	t["Head"] = Vector3(0.05, _look * 0.5, 0)
	t["ArmL"] = Vector3(-0.5, 0, 0.12)
	t["ArmR"] = Vector3(-0.5, 0, -0.12)
	t["ForearmL"] = Vector3(-0.75, 0, 0)
	t["ForearmR"] = Vector3(-0.75, 0, 0)


func _work(t: Dictionary) -> void:
	var k := sin(_time * 7.0)
	# Squatting by a cupboard / kneeling base.
	t["Torso"] = Vector3(0.5, 0, 0)
	t["Head"] = Vector3(-0.3, 0, 0)
	t["LegL"] = Vector3(-0.5, 0, 0.06)
	t["LegR"] = Vector3(-0.25, 0, -0.06)
	t["ShinL"] = Vector3(0.75, 0, 0)
	t["ShinR"] = Vector3(0.45, 0, 0)
	t["_hips"] = Vector3(0, -0.12, 0)
	match work_kind:
		"eat":
			var bite := maxf(sin(_time * 3.2), 0.0)
			_stand_base(t)
			t["ArmR"] = Vector3(-0.75 - bite * 0.35, 0, -0.18)
			t["ForearmR"] = Vector3(-1.5 - bite * 0.8, 0, 0)
			t["ArmL"] = Vector3(-0.5, 0, 0.15)
			t["ForearmL"] = Vector3(-1.0, 0, 0)
			t["Head"] = Vector3(0.12 + bite * 0.1, 0, 0)
		"drink":
			var sip := smoothstep(-0.3, 0.6, sin(_time * 1.8))
			_stand_base(t)
			t["ArmR"] = Vector3(-1.1 - sip * 0.5, 0, -0.2)
			t["ForearmR"] = Vector3(-1.6 - sip * 0.4, 0, 0)
			t["Head"] = Vector3(-0.15 - sip * 0.35, 0, 0)
			t["Torso"] = Vector3(-0.08 * sip, 0, 0)
		"bandage":
			_stand_base(t)
			t["ArmL"] = Vector3(-0.85, 0.3, 0.1)
			t["ForearmL"] = Vector3(-1.2, 0, 0)
			t["ArmR"] = Vector3(-0.9 + k * 0.18, 0, 0.35 + k * 0.12)
			t["ForearmR"] = Vector3(-1.1, 0, 0)
			t["Head"] = Vector3(0.35, 0.2, 0)
			t["Torso"] = Vector3(0.18, 0, 0)
		"hammer":
			var blow := absf(sin(_time * 5.5))
			_stand_base(t)
			t["ArmR"] = Vector3(-1.2 - blow * 1.1, 0, -0.15)
			t["ForearmR"] = Vector3(-0.9 + blow * 0.5, 0, 0)
			t["ArmL"] = Vector3(-1.35, 0, 0.2)
			t["ForearmL"] = Vector3(-0.35, 0, 0)
			t["Torso"] = Vector3(0.12, 0, 0)
			t["Head"] = Vector3(-0.15, 0, 0)
		"cook":
			t["ArmR"] = Vector3(-0.85, 0, -0.1 + sin(_time * 4.0) * 0.18)
			t["ForearmR"] = Vector3(-0.8, sin(_time * 4.0) * 0.3, 0)
			t["ArmL"] = Vector3(-0.6, 0, 0.18)
			t["ForearmL"] = Vector3(-0.9, 0, 0)
		"read":
			_stand_base(t)
			t["ArmL"] = Vector3(-0.8, 0, 0.12)
			t["ArmR"] = Vector3(-0.8, 0, -0.12)
			t["ForearmL"] = Vector3(-1.4, 0, 0)
			t["ForearmR"] = Vector3(-1.4, 0, 0)
			t["Head"] = Vector3(0.35, 0, 0)
		_:
			# Rummaging with both hands, alternating.
			t["ArmL"] = Vector3(-1.0 + k * 0.15, 0, 0.12)
			t["ArmR"] = Vector3(-1.0 - k * 0.15, 0, -0.12)
			t["ForearmL"] = Vector3(-0.45 + k * 0.2, 0, 0)
			t["ForearmR"] = Vector3(-0.45 - k * 0.2, 0, 0)
			t["Head"] = Vector3(-0.3, sin(_time * 1.3) * 0.25, 0)


func _stand_base(t: Dictionary) -> void:
	t["LegL"] = Vector3(-0.04, 0, 0.05)
	t["LegR"] = Vector3(0.04, 0, -0.05)
	t["ShinL"] = Vector3(0.06, 0, 0)
	t["ShinR"] = Vector3(0.06, 0, 0)
	t["Torso"] = Vector3(0.04 + sin(_time * 1.6) * 0.01, 0, 0)
	t["_hips"] = Vector3.ZERO


# ------------------------------------------------------------------------------------------------ falls
## On the back (or face down), limbs sprawled per individual, slow twitching while knocked out.
func _fallen(t: Dictionary, knocked: bool) -> void:
	var fall := smoothstep(0.0, 0.55, _pose_t)
	var flip := 1.0 if _face_down else -1.0
	# First the knees buckle, then the body hits the ground.
	var buckle := 1.0 - smoothstep(0.15, 0.5, _pose_t)
	t["Hips"] = Vector3(flip * 1.52 * fall, _sprawl.x * 0.3 * fall, _sprawl.y * 0.15 * fall)
	t["LegL"] = Vector3(-0.15 - buckle * 0.9 + _sprawl.x * 0.25, 0, 0.18 + _sprawl.z * 0.15)
	t["LegR"] = Vector3(-0.05 - buckle * 0.6 - _sprawl.y * 0.3, 0, -0.15)
	t["ShinL"] = Vector3(0.25 + buckle * 1.3 + maxf(_sprawl.z, 0.0) * 0.7, 0, 0)
	t["ShinR"] = Vector3(0.6 + buckle * 1.1, 0, 0)
	t["ArmL"] = Vector3(-0.4 + _sprawl.y * 0.5, 0, 1.0 + _sprawl.x * 0.3)
	t["ArmR"] = Vector3(-0.6 - _sprawl.z * 0.4, 0, -0.9 + _sprawl.y * 0.3)
	t["ForearmL"] = Vector3(-0.3 - maxf(_sprawl.x, 0.0) * 0.8, 0, 0)
	t["ForearmR"] = Vector3(-0.2, 0, 0)
	t["Head"] = Vector3(0.15 * -flip, 0.55 * signf(_sprawl.z + 0.01), 0)
	if knocked and _pose_t > 0.6:
		t["ArmL"] += Vector3(sin(_time * 3.0) * 0.12, 0, 0)
		t["ArmR"] += Vector3(0, 0, sin(_time * 2.3) * 0.1)
		t["Head"] += Vector3(0, sin(_time * 1.7) * 0.35, 0)
		t["LegR"] += Vector3(sin(_time * 2.1) * 0.08, 0, 0)
	t["_hips"] = Vector3(0, -0.8 * fall + buckle * -0.25 * (1.0 - fall), (-0.12 if not _face_down else 0.12) * fall)


func _getup(t: Dictionary) -> void:
	var k := smoothstep(0.0, 1.0, _pose_t / 1.1)
	if k < 0.5:
		# Roll onto hands and knees.
		var a := k / 0.5
		t["Hips"] = Vector3(lerpf(-1.3, 0.9, a), 0, 0)
		t["Torso"] = Vector3(lerpf(0.2, 0.5, a), 0, 0)
		t["ArmL"] = Vector3(-1.2, 0, 0.25)
		t["ArmR"] = Vector3(-1.2, 0, -0.25)
		t["ForearmL"] = Vector3(-0.2, 0, 0)
		t["ForearmR"] = Vector3(-0.2, 0, 0)
		t["LegL"] = Vector3(lerpf(-0.2, -1.6, a), 0, 0.1)
		t["LegR"] = Vector3(lerpf(-0.4, -1.4, a), 0, -0.1)
		t["ShinL"] = Vector3(lerpf(0.4, 2.0, a), 0, 0)
		t["ShinR"] = Vector3(lerpf(0.8, 1.9, a), 0, 0)
		t["Head"] = Vector3(-0.5 * a, 0, 0)
		t["_hips"] = Vector3(0, lerpf(-0.78, -0.55, a), 0)
	else:
		# Push up off one knee.
		var b := (k - 0.5) / 0.5
		t["Hips"] = Vector3(lerpf(0.3, 0.0, b), 0, 0)
		t["Torso"] = Vector3(lerpf(0.7, 0.1, b), 0, 0)
		t["ArmL"] = Vector3(lerpf(-0.9, -0.2, b), 0, 0.3)
		t["ArmR"] = Vector3(lerpf(-0.4, -0.2, b), 0, -0.3)
		t["ForearmL"] = Vector3(-0.5, 0, 0)
		t["LegL"] = Vector3(lerpf(-1.4, -0.1, b), 0, 0.1)
		t["ShinL"] = Vector3(lerpf(1.7, 0.1, b), 0, 0)
		t["LegR"] = Vector3(lerpf(-0.2, 0.0, b), 0, -0.1)
		t["ShinR"] = Vector3(lerpf(1.6, 0.1, b), 0, 0)
		t["Head"] = Vector3(lerpf(-0.4, 0.0, b), 0, 0)
		t["_hips"] = Vector3(0, lerpf(-0.5, 0.0, b), 0)


# ------------------------------------------------------------------------------------------------ zombies
func _zombie_locomotion(t: Dictionary, delta: float) -> void:
	var sprint := running
	var amp := clampf(speed / 1.1, 0.0, 1.0)
	var moving := speed > 0.1
	var stride := (1.7 if sprint else 1.0) * (0.9 if gait == Gait.LIMPER else 1.0)
	if moving:
		_phase = fmod(_phase + delta * speed / stride * TAU, TAU)
	var s := sin(_phase)
	var c := cos(_phase)
	var sway := sin(_time * 1.3 * _limp)
	var a_leg := (0.75 if sprint else 0.36) * amp
	var a_knee := (1.3 if sprint else 0.45) * amp
	t["LegL"] = Vector3(-s * a_leg, 0, 0.06)
	t["LegR"] = Vector3(s * a_leg, 0, -0.06)
	t["ShinL"] = Vector3(maxf(c, 0.0) * a_knee + 0.12, 0, 0)
	t["ShinR"] = Vector3(maxf(-c, 0.0) * a_knee + 0.12, 0, 0)
	var hip_y := -0.025 * s * s * amp
	var hip_x := 0.0
	var reach := 1.0 if (hunting or sprint) else 0.0
	match gait:
		Gait.REACHER:
			t["ArmL"] = Vector3(-1.25 + sway * 0.1 + s * 0.1 * amp, 0, 0.14)
			t["ArmR"] = Vector3(-1.1 - sway * 0.1 - s * 0.1 * amp, 0, -0.18)
			t["ForearmL"] = Vector3(-0.25, 0, 0)
			t["ForearmR"] = Vector3(-0.45, 0, 0)
			t["Torso"] = Vector3(0.24 + sin(_time * 0.9) * 0.04, s * 0.12 * amp, sin(_time * 0.7) * 0.06)
			t["Head"] = Vector3(-0.12, sin(_time * 0.5) * 0.25, 0.3 * _limp - 0.28)
		Gait.LIMPER:
			# Stiff right leg dragged along; the body drops onto the good leg.
			t["LegR"] = Vector3(s * a_leg * 0.45, 0.18, -0.12)
			t["ShinR"] = Vector3(0.08, 0, 0)
			t["ShinL"] += Vector3(0.15, 0, 0)
			hip_y = -0.06 * maxf(-c, 0.0) * amp - 0.03
			hip_x = -0.03 * c * amp
			t["Hips"] = Vector3(0, 0, -0.1 * maxf(-c, 0.0) * amp)
			t["Torso"] = Vector3(0.18, s * 0.08, 0.16 + sway * 0.05)
			t["Head"] = Vector3(0.1, 0, 0.45)
			t["ArmL"] = Vector3(0.05 + sway * 0.15, 0, 0.12)
			t["ArmR"] = Vector3(-0.15 - s * 0.2 * amp, 0, -0.05)
			t["ForearmL"] = Vector3(-0.1, 0, 0)
			t["ForearmR"] = Vector3(-0.3, 0, 0)
		Gait.HUNCHED:
			t["Torso"] = Vector3(0.62 + sway * 0.05, s * 0.1 * amp, 0)
			t["Head"] = Vector3(-0.55, sin(_time * 0.6) * 0.2, 0.1)
			t["ArmL"] = Vector3(-0.55 + s * 0.35 * amp, 0, 0.1)
			t["ArmR"] = Vector3(-0.55 - s * 0.35 * amp, 0, -0.1)
			t["ForearmL"] = Vector3(-0.2, 0, 0)
			t["ForearmR"] = Vector3(-0.2, 0, 0)
			t["ShinL"] += Vector3(0.25, 0, 0)
			t["ShinR"] += Vector3(0.25, 0, 0)
			t["LegL"] += Vector3(-0.2, 0, 0)
			t["LegR"] += Vector3(-0.2, 0, 0)
			hip_y -= 0.08
		Gait.LURCHER:
			# Heavy side-to-side lurch, one arm up, one dangling.
			t["Hips"] = Vector3(0, s * 0.12 * amp, c * 0.14 * amp)
			t["Torso"] = Vector3(0.2, -s * 0.15 * amp, -c * 0.2 * amp + sway * 0.05)
			t["Head"] = Vector3(-0.05, 0, c * 0.25 * amp + 0.15)
			t["ArmL"] = Vector3(-1.4 + sway * 0.2, 0, 0.3)
			t["ArmR"] = Vector3(0.1 - c * 0.3 * amp, 0, -0.15 - absf(c) * 0.2)
			t["ForearmL"] = Vector3(-0.5, 0, 0)
			t["ForearmR"] = Vector3(-0.05, 0, 0)
			hip_x = c * 0.05 * amp
	if reach > 0.0:
		# Hunting: everyone reaches for the prey, head forward, mouth first.
		t["ArmL"] = Vector3(-1.45 + s * 0.15 * amp, 0, 0.1)
		t["ArmR"] = Vector3(-1.4 - s * 0.15 * amp, 0, -0.1)
		t["ForearmL"] = Vector3(-0.15 + sway * 0.1, 0, 0)
		t["ForearmR"] = Vector3(-0.2, 0, 0)
		t["Head"] = Vector3(-0.25, 0, (t["Head"] as Vector3).z * 0.4)
		if gait == Gait.LIMPER:
			t["ArmR"] = Vector3(-1.1, 0, -0.1)
	if sprint:
		t["Torso"] = Vector3(0.45, s * 0.18, 0)
		t["ArmL"] = Vector3(-1.6 + s * 0.25, 0, 0.12)
		t["ArmR"] = Vector3(-1.6 - s * 0.25, 0, -0.12)
		t["Head"] = Vector3(-0.35, 0, 0)
		hip_y = -0.05 * s * s
	if not moving:
		# Swaying on the spot, head lolling, occasional twitch.
		t["Torso"] += Vector3(sin(_time * 0.8) * 0.04, 0, sway * 0.05)
		t["Head"] += Vector3(0, sin(_time * 0.45) * 0.3, 0)
		if fmod(_time * _limp, 6.0) < 0.15:
			t["Head"] += Vector3(0.3, 0, 0.4)
			t["ArmL"] += Vector3(-0.3, 0, 0)
	t["_hips"] = Vector3(hip_x, hip_y, 0)
	if moving and signf(s) != signf(_last_sin):
		step.emit(0 if s > 0 else 1)
	_last_sin = s


## Face down, pulling itself along with alternating arms, legs dragging behind.
func _crawl(t: Dictionary, delta: float) -> void:
	if speed > 0.05:
		_phase = fmod(_phase + delta * speed / 0.55 * TAU, TAU)
	var s := sin(_phase)
	var c := cos(_phase)
	t["Hips"] = Vector3(1.48, s * 0.06, c * 0.06)
	t["Torso"] = Vector3(-0.12, s * 0.12, 0)
	t["Head"] = Vector3(-0.85, sin(_time * 0.7) * 0.2, 0)
	t["ArmL"] = Vector3(-2.7 + s * 0.55, 0, 0.35)
	t["ArmR"] = Vector3(-2.7 - s * 0.55, 0, -0.35)
	t["ForearmL"] = Vector3(-0.2 - maxf(-s, 0.0) * 0.9, 0, 0)
	t["ForearmR"] = Vector3(-0.2 - maxf(s, 0.0) * 0.9, 0, 0)
	t["LegL"] = Vector3(0.05 + c * 0.08, 0, 0.12)
	t["LegR"] = Vector3(0.0, 0, -0.1)
	t["ShinL"] = Vector3(0.2 + maxf(c, 0.0) * 0.4, 0, 0)
	t["ShinR"] = Vector3(0.6, 0, 0)
	t["_hips"] = Vector3(0, -0.8, 0.1)
	if signf(s) != signf(_last_sin) and speed > 0.05:
		step.emit(0)
	_last_sin = s


# ------------------------------------------------------------------------------------------------ attacks
## Easing helpers for anticipation -> strike -> recovery.
static func _ease_in(x: float) -> float:
	return x * x


static func _ease_out(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


func _aim(t: Dictionary, recoil: float) -> void:
	if rifle:
		t["ArmR"] = Vector3(-1.05 - recoil * 0.3, 0, -0.35)
		t["ForearmR"] = Vector3(-1.2, 0, 0)
		t["ArmL"] = Vector3(-1.5 - recoil * 0.4, 0.2, -0.3)
		t["ForearmL"] = Vector3(-0.3, 0, 0)
		t["Torso"] = Vector3(0.05 - recoil * 0.35, 0.15, 0)
		t["Head"] = Vector3(0.1, -0.15, 0.12)
	else:
		# Two-handed pistol grip, arms out at shoulder height.
		t["ArmR"] = Vector3(-1.52 - recoil * 0.45, 0, 0.14)
		t["ForearmR"] = Vector3(-0.05, 0, 0)
		t["ArmL"] = Vector3(-1.42 - recoil * 0.35, 0, -0.32)
		t["ForearmL"] = Vector3(-0.45, 0, 0)
		t["Torso"] = Vector3(0.02 - recoil * 0.2, 0.08, 0)
		t["Head"] = Vector3(0.05, -0.08, 0)
	t["LegL"] = Vector3(-0.25, 0, 0.1)
	t["LegR"] = Vector3(0.18, 0, -0.12)
	t["ShinL"] = Vector3(0.2, 0, 0)
	t["ShinR"] = Vector3(0.12, 0, 0)
	t["_hips"] = Vector3(0, -0.04, 0)


func _apply_attack(t: Dictionary, p: float) -> void:
	match attack_style:
		"shoot":
			var recoil := _ease_out(clampf(p / 0.12, 0.0, 1.0)) * (1.0 - smoothstep(0.12, 0.5, p))
			_aim(t, recoil * (1.6 if rifle else 1.0))
			lunge = -0.06 * recoil * (2.0 if rifle else 1.0)
		"stab":
			# Pull back, thrust with a step, recover.
			var pull := smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.3, 0.42, p))
			var thrust := smoothstep(0.3, 0.45, p) * (1.0 - smoothstep(0.65, 1.0, p))
			t["ArmR"] = Vector3(0.45 * pull - 1.55 * thrust, 0, -0.15)
			t["ForearmR"] = Vector3(-1.5 * pull - 0.05 * thrust - 0.6 * (1.0 - pull - thrust), 0, 0)
			t["Torso"] = Vector3(0.08 + thrust * 0.22, -0.3 * pull + 0.25 * thrust, 0)
			t["ArmL"] = Vector3(-0.55, 0, 0.25)
			t["ForearmL"] = Vector3(-1.1, 0, 0)
			t["LegL"] = Vector3(-0.45 * thrust, 0, 0.05)
			t["ShinL"] = Vector3(0.35 * thrust, 0, 0)
			t["LegR"] = Vector3(0.2 * thrust, 0, -0.05)
			lunge = 0.14 * thrust
		"shove":
			var heave := smoothstep(0.0, 0.28, p) * (1.0 - smoothstep(0.28, 0.4, p))
			var push := smoothstep(0.28, 0.45, p) * (1.0 - smoothstep(0.65, 1.0, p))
			var a := -0.6 * heave - 1.45 * push
			var f := -1.4 * heave - 0.1 * push - 0.5 * (1.0 - heave - push)
			t["ArmL"] = Vector3(a, 0, 0.14)
			t["ArmR"] = Vector3(a, 0, -0.14)
			t["ForearmL"] = Vector3(f, 0, 0)
			t["ForearmR"] = Vector3(f, 0, 0)
			t["Torso"] = Vector3(-0.08 * heave + 0.3 * push, 0, 0)
			t["LegL"] = Vector3(-0.5 * push, 0, 0.05)
			t["ShinL"] = Vector3(0.4 * push, 0, 0)
			t["LegR"] = Vector3(0.3 * push, 0, -0.05)
			lunge = 0.18 * push
		"stomp":
			var lift := smoothstep(0.0, 0.35, p) * (1.0 - smoothstep(0.38, 0.5, p))
			var down := smoothstep(0.38, 0.5, p) * (1.0 - smoothstep(0.75, 1.0, p))
			t["LegR"] = Vector3(-1.35 * lift - 0.45 * down, 0, -0.05)
			t["ShinR"] = Vector3(1.7 * lift + 0.15 * down, 0, 0)
			t["LegL"] = Vector3(0.12, 0, 0.06)
			t["ShinL"] = Vector3(0.25 * down + 0.1, 0, 0)
			t["Torso"] = Vector3(0.2 + 0.25 * down, 0, 0)
			t["Head"] = Vector3(-0.55, 0, 0)
			t["ArmL"] = Vector3(-0.35, 0, 0.55 + 0.2 * lift)
			t["ArmR"] = Vector3(-0.35, 0, -0.55 - 0.2 * lift)
			t["ForearmL"] = Vector3(-0.5, 0, 0)
			t["ForearmR"] = Vector3(-0.5, 0, 0)
			t["_hips"] = Vector3(0, 0.03 * lift - 0.1 * down, 0)
		"grab":
			# Zombie lunge: arms reach, close in, head darts in for the bite.
			var reach := smoothstep(0.05, 0.45, p)
			var clamp_in := smoothstep(0.45, 0.6, p) * (1.0 - smoothstep(0.85, 1.0, p))
			var bite := smoothstep(0.5, 0.62, p) * (1.0 - smoothstep(0.7, 0.9, p))
			t["ArmL"] = Vector3(lerpf(-1.2, -1.7, reach), -0.3 * clamp_in, 0.1 - 0.35 * clamp_in)
			t["ArmR"] = Vector3(lerpf(-1.1, -1.7, reach), 0.3 * clamp_in, -0.1 + 0.35 * clamp_in)
			t["ForearmL"] = Vector3(-0.15 - 0.7 * clamp_in, 0, 0)
			t["ForearmR"] = Vector3(-0.15 - 0.7 * clamp_in, 0, 0)
			t["Torso"] = Vector3(lerpf(0.15, 0.55, reach) + bite * 0.2, 0, 0)
			t["Head"] = Vector3(-0.3 * reach + 0.5 * bite, 0, 0)
			t["LegL"] = Vector3(-0.4 * reach, 0, 0.06)
			t["LegR"] = Vector3(0.25 * reach, 0, -0.06)
			t["ShinL"] = Vector3(0.3 * reach, 0, 0)
			lunge = 0.22 * reach * (1.0 - smoothstep(0.75, 1.0, p))
		"bash":
			var pound := sin(p * TAU)
			t["ArmR"] = Vector3(-1.95 + pound * 0.75, 0, -0.1)
			t["ArmL"] = Vector3(-1.95 - pound * 0.75, 0, 0.1)
			t["ForearmL"] = Vector3(-0.35, 0, 0)
			t["ForearmR"] = Vector3(-0.35, 0, 0)
			t["Torso"] = Vector3(0.28 + absf(pound) * 0.12, 0, 0)
			t["Head"] = Vector3(-0.2, 0, 0.1)
			t["_hips"] = Vector3(0, -0.03 * absf(pound), 0.03 * pound)
		_:
			_swing(t, p, attack_style == "finish")


## Melee swing: anticipation (weapon cocked over the right shoulder, torso wound up, weight back),
## a fast strike through the target with a step, follow-through across the body, then recovery.
func _swing(t: Dictionary, p: float, low: bool) -> void:
	var wind := _ease_out(clampf(p / 0.38, 0.0, 1.0))
	var strike := _ease_in(clampf((p - 0.38) / 0.17, 0.0, 1.0))
	var recover := smoothstep(0.62, 1.0, p)
	var arm_up := -2.55 if not low else -2.7
	var arm_hit := (-0.15 if low else -0.5)
	var arm := lerpf(lerpf(-0.4, arm_up, wind), arm_hit, strike)
	arm = lerpf(arm, -0.35, recover)
	var twist := lerpf(lerpf(0.0, 0.7, wind), -0.55, strike)
	twist = lerpf(twist, 0.0, recover)
	var lean := lerpf(lerpf(0.02, -0.12, wind), 0.6 if low else 0.25, strike)
	lean = lerpf(lean, 0.04, recover)
	t["Torso"] = Vector3(lean, twist, -0.06 * wind + 0.08 * strike * (1.0 - recover))
	t["Hips"] = Vector3(0, twist * 0.35, 0)
	t["ArmR"] = Vector3(arm, 0, lerpf(-0.35, -0.1, strike))
	t["ForearmR"] = Vector3(lerpf(-1.1, -0.25, strike) * (1.0 - recover) - 0.5 * recover, 0, 0)
	if two_handed:
		t["ArmL"] = Vector3(arm * 0.92, 0, lerpf(-0.45, -0.28, strike))
		t["ForearmL"] = Vector3(lerpf(-1.25, -0.4, strike) * (1.0 - recover) - 0.9 * recover, 0, 0)
	else:
		t["ArmL"] = Vector3(lerpf(-0.6, 0.25, strike), 0, 0.25)
		t["ForearmL"] = Vector3(-0.9, 0, 0)
	var step_k := strike * (1.0 - recover)
	t["LegL"] = Vector3(-0.15 * wind - 0.45 * step_k, 0, 0.08)
	t["ShinL"] = Vector3(0.2 + 0.4 * step_k + (0.5 if low else 0.0) * step_k, 0, 0)
	t["LegR"] = Vector3(0.12 * wind + 0.3 * step_k, 0, -0.08)
	t["ShinR"] = Vector3(0.15 + 0.2 * step_k, 0, 0)
	t["Head"] = Vector3(-lean * 0.4 + (0.3 if low else 0.0) * step_k, -twist * 0.5, 0)
	t["_hips"] = Vector3(0, -0.05 * step_k - (0.12 if low else 0.0) * step_k, 0)
	lunge = 0.1 * step_k
	t["_hips"] += Vector3(0, 0, lunge)
