class_name V03CharacterAnimator
extends Node
## Procedural animation for the rigid-part human rig (Blender: assets/characters/*.glb), shared by
## the player and zombies. Rotation.x > 0 swings a limb backwards (model faces +Z); poses blend every frame.

signal step(foot: int)

enum Pose { STAND, CROUCH, SIT, LIE, CLIMB, DEAD, WORK, KNOCKED, GETUP, STAGGER }

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
var zombie := false
var lunge := 0.0

var _parts := {}
var _rest_pos := {}
var _phase := 0.0
var _time := 0.0
var _last_sin := 0.0
var _blend := {}
var _limp := 0.0


func _ready() -> void:
	if model_path != NodePath():
		bind(get_node(model_path))
	_limp = randf_range(0.6, 1.4)
	_time = randf() * 10.0


func bind(model: Node) -> void:
	_parts.clear()
	for n in PART_NAMES:
		var node := model.find_child(n, true, false) as Node3D
		if node:
			_parts[n] = node
			_rest_pos[n] = node.position
			_blend[n] = Vector3.ZERO


func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	_time += delta
	var t := {}
	for n in _parts:
		t[n] = Vector3.ZERO
	var hip_drop := 0.0
	var hip_back := 0.0
	var moving := speed > 0.15
	var k_speed := 12.0

	match pose:
		Pose.STAND, Pose.CROUCH:
			var stride := 2.3 if running else 1.45
			if pose == Pose.CROUCH:
				stride = 1.0
			if zombie:
				stride = 1.6 if running else 1.05
			if moving:
				_phase = fmod(_phase + delta * speed / stride * TAU, TAU)
			else:
				_phase = lerpf(_phase, 0.0 if _phase < PI * 0.5 or _phase > PI * 1.5 else PI, delta * 6.0)
			var s := sin(_phase)
			var c := cos(_phase)
			var amp := clampf(speed / (5.0 if running else 2.3), 0.0, 1.0)
			if zombie:
				amp = clampf(speed / 1.2, 0.0, 1.0)
			var a_leg := (0.72 if running else 0.42) * amp
			var a_knee := (1.35 if running else 0.62) * amp
			var a_arm := (0.75 if running else 0.32) * amp
			t["LegL"] = Vector3(-s * a_leg, 0, 0)
			t["LegR"] = Vector3(s * a_leg, 0, 0)
			t["ShinL"] = Vector3(maxf(0.0, c) * a_knee + 0.05, 0, 0)
			t["ShinR"] = Vector3(maxf(0.0, -c) * a_knee + 0.05, 0, 0)
			t["ArmL"] = Vector3(s * a_arm, 0, 0.06)
			t["ArmR"] = Vector3(-s * a_arm, 0, -0.06)
			var fore := -1.25 if running else -0.18 - 0.1 * amp
			t["ForearmL"] = Vector3(fore, 0, 0)
			t["ForearmR"] = Vector3(fore, 0, 0)
			t["Torso"] = Vector3((0.2 if running else 0.03) * amp + sin(_time * 1.6) * 0.012, s * 0.07 * amp, 0)
			t["Head"] = Vector3(-(0.12 if running else 0.0) * amp, 0, 0)
			hip_drop = (absf(c) - 0.6) * (0.05 if running else 0.025) * amp
			if holding and not zombie:
				t["ArmR"] = Vector3(-0.25 - s * a_arm * 0.4, 0, -0.08)
				t["ForearmR"] = Vector3(-0.55, 0, 0)
			if pose == Pose.CROUCH:
				t["LegL"] += Vector3(-1.05, 0, 0.05)
				t["LegR"] += Vector3(-1.05, 0, -0.05)
				t["ShinL"] = Vector3(1.65 + maxf(0.0, c) * 0.3 * amp, 0, 0)
				t["ShinR"] = Vector3(1.65 + maxf(0.0, -c) * 0.3 * amp, 0, 0)
				t["Torso"] = Vector3(0.5, s * 0.05 * amp, 0)
				t["Head"] = Vector3(-0.38, 0, 0)
				t["ArmL"] = Vector3(-0.35 + s * 0.15 * amp, 0, 0.1)
				t["ArmR"] = Vector3(-0.35 - s * 0.15 * amp, 0, -0.1)
				t["ForearmL"] = Vector3(-0.6, 0, 0)
				t["ForearmR"] = Vector3(-0.6, 0, 0)
				hip_drop -= 0.36
			if zombie:
				# Arms reaching forward, head lolling, one leg dragging.
				var sway := sin(_time * 1.3 * _limp) * 0.12
				t["ArmL"] = Vector3(-1.25 + sway + s * 0.12 * amp, 0, 0.12)
				t["ArmR"] = Vector3(-1.1 - sway - s * 0.12 * amp, 0, -0.18)
				t["ForearmL"] = Vector3(-0.25, 0, 0)
				t["ForearmR"] = Vector3(-0.45, 0, 0)
				t["Torso"] = Vector3(0.22 + sin(_time * 0.9) * 0.04, s * 0.12 * amp, sin(_time * 0.7) * 0.06)
				t["Head"] = Vector3(-0.1, sin(_time * 0.5) * 0.25, 0.32 * _limp - 0.3)
				t["ShinR"] = Vector3(maxf(0.0, -c) * a_knee * 0.4 + 0.15, 0, 0)
				t["LegR"] = Vector3(s * a_leg * 0.7, 0.15, 0)
				if running:
					t["ArmL"] = Vector3(-1.5 + s * 0.2, 0, 0.1)
					t["ArmR"] = Vector3(-1.5 - s * 0.2, 0, -0.1)
					t["Torso"] += Vector3(0.15, 0, 0)
			if moving and signf(s) != signf(_last_sin):
				step.emit(0 if s > 0 else 1)
			_last_sin = s
		Pose.SIT:
			t["LegL"] = Vector3(-1.5, 0, 0.06)
			t["LegR"] = Vector3(-1.5, 0, -0.06)
			t["ShinL"] = Vector3(1.45, 0, 0)
			t["ShinR"] = Vector3(1.45, 0, 0)
			t["Torso"] = Vector3(-0.05 + sin(_time * 1.4) * 0.01, 0, 0)
			t["ArmL"] = Vector3(-0.45, 0, 0.1)
			t["ArmR"] = Vector3(-0.45, 0, -0.1)
			t["ForearmL"] = Vector3(-0.7, 0, 0)
			t["ForearmR"] = Vector3(-0.7, 0, 0)
		Pose.LIE:
			t["Torso"] = Vector3(sin(_time * 1.1) * 0.015, 0, 0)
			t["ArmL"] = Vector3(-0.15, 0, 0.25)
			t["ArmR"] = Vector3(-0.15, 0, -0.25)
			t["ShinL"] = Vector3(0.1, 0, 0)
			t["ShinR"] = Vector3(0.2, 0, 0)
		Pose.WORK:
			var k := sin(_time * 7.0)
			t["Torso"] = Vector3(0.55, 0, 0)
			t["Head"] = Vector3(-0.35, 0, 0)
			t["ArmL"] = Vector3(-0.95 + k * 0.12, 0, 0.12)
			t["ArmR"] = Vector3(-0.95 - k * 0.12, 0, -0.12)
			t["ForearmL"] = Vector3(-0.5, 0, 0)
			t["ForearmR"] = Vector3(-0.5, 0, 0)
			t["LegL"] = Vector3(-0.45, 0, 0.05)
			t["LegR"] = Vector3(-0.3, 0, -0.05)
			t["ShinL"] = Vector3(0.7, 0, 0)
			t["ShinR"] = Vector3(0.5, 0, 0)
			hip_drop = -0.12
		Pose.CLIMB:
			var k := sin(_time * 9.0)
			t["LegL"] = Vector3(-1.2 + k * 0.3, 0, 0.1)
			t["LegR"] = Vector3(-0.5 - k * 0.3, 0, -0.1)
			t["ShinL"] = Vector3(1.3, 0, 0)
			t["ShinR"] = Vector3(0.9, 0, 0)
			t["Torso"] = Vector3(0.55, 0, 0)
			t["ArmL"] = Vector3(-1.3, 0, 0.2)
			t["ArmR"] = Vector3(-1.3, 0, -0.2)
			hip_drop = -0.1
		Pose.DEAD:
			t["ArmL"] = Vector3(-0.3, 0, 1.1)
			t["ArmR"] = Vector3(-0.2, 0, -1.2)
			t["LegL"] = Vector3(-0.1, 0, 0.2)
			t["LegR"] = Vector3(0.1, 0, -0.15)
			t["Head"] = Vector3(0, 0.5, 0)
		Pose.KNOCKED:
			# Flat on the back, limbs sprawled, twitching.
			t["Hips"] = Vector3(-1.5, 0, 0)
			t["ArmL"] = Vector3(-0.4 + sin(_time * 3.0) * 0.1, 0, 1.0)
			t["ArmR"] = Vector3(-0.6, 0, -0.9 + sin(_time * 2.3) * 0.1)
			t["LegL"] = Vector3(-0.2, 0, 0.15)
			t["ShinL"] = Vector3(0.3, 0, 0)
			t["LegR"] = Vector3(-0.5, 0, -0.1)
			t["ShinR"] = Vector3(0.8, 0, 0)
			t["Head"] = Vector3(0.2, sin(_time * 1.7) * 0.4, 0)
			hip_drop = -0.78
			hip_back = -0.1
			k_speed = 9.0
		Pose.GETUP:
			t["Hips"] = Vector3(-0.35, 0, 0)
			t["Torso"] = Vector3(0.7, 0, 0)
			t["ArmL"] = Vector3(-0.6, 0, 0.3)
			t["ArmR"] = Vector3(-0.6, 0, -0.3)
			t["LegL"] = Vector3(-1.3, 0, 0.1)
			t["ShinL"] = Vector3(1.9, 0, 0)
			t["LegR"] = Vector3(-0.2, 0, -0.1)
			t["ShinR"] = Vector3(1.5, 0, 0)
			hip_drop = -0.5
			k_speed = 4.0
		Pose.STAGGER:
			t["Torso"] = Vector3(-0.35, 0.2, 0)
			t["Head"] = Vector3(0.45, 0, 0.2)
			t["ArmL"] = Vector3(-0.6, 0, 0.9)
			t["ArmR"] = Vector3(-0.3, 0, -1.0)
			t["LegL"] = Vector3(0.25, 0, 0)
			t["LegR"] = Vector3(-0.35, 0, 0)
			t["ShinR"] = Vector3(0.4, 0, 0)
			k_speed = 16.0

	lunge = 0.0
	if attack_t >= 0.0:
		_apply_attack(t, attack_t)
		k_speed = 18.0

	var k_blend := clampf(delta * k_speed, 0.0, 1.0)
	for n in _parts:
		_blend[n] = (_blend[n] as Vector3).lerp(t[n], k_blend)
		(_parts[n] as Node3D).rotation = _blend[n]
	var hips := _parts.get("Hips") as Node3D
	if hips:
		var rp: Vector3 = _rest_pos["Hips"]
		hips.position.y = lerpf(hips.position.y, rp.y + hip_drop, k_blend)
		hips.position.z = lerpf(hips.position.z, rp.z + lunge + hip_back, k_blend)


func _apply_attack(t: Dictionary, p: float) -> void:
	match attack_style:
		"stab":
			var arm := lerpf(0.5, -1.55, smoothstep(0.25, 0.5, p)) if p < 0.6 else lerpf(-1.55, -0.3, (p - 0.6) / 0.4)
			t["ArmR"] = Vector3(arm, 0, -0.15)
			t["ForearmR"] = Vector3(-1.4 if p < 0.3 else -0.1, 0, 0)
			t["Torso"] = Vector3(0.12, -0.25 if p < 0.35 else 0.2, 0)
			t["ArmL"] = Vector3(-0.5, 0, 0.2)
			t["ForearmL"] = Vector3(-1.0, 0, 0)
			lunge = 0.1 if p > 0.35 and p < 0.7 else 0.0
		"shove":
			var a := lerpf(-0.6, -1.45, smoothstep(0.25, 0.48, p)) if p < 0.65 else lerpf(-1.45, 0.0, (p - 0.65) / 0.35)
			var f := -1.3 if p < 0.3 else lerpf(-1.3, -0.1, smoothstep(0.3, 0.48, p))
			t["ArmL"] = Vector3(a, 0, 0.12)
			t["ArmR"] = Vector3(a, 0, -0.12)
			t["ForearmL"] = Vector3(f, 0, 0)
			t["ForearmR"] = Vector3(f, 0, 0)
			t["Torso"] = Vector3(0.2 if p > 0.35 else -0.05, 0, 0)
			lunge = 0.14 if p > 0.35 and p < 0.7 else 0.0
		"stomp":
			var up := p < 0.4
			t["LegR"] = Vector3(-1.2 if up else -0.35, 0, 0)
			t["ShinR"] = Vector3(1.5 if up else 0.25, 0, 0)
			t["LegL"] = Vector3(0.1, 0, 0)
			t["Torso"] = Vector3(0.3, 0, 0)
			t["Head"] = Vector3(-0.5, 0, 0)
			t["ArmL"] = Vector3(-0.3, 0, 0.5)
			t["ArmR"] = Vector3(-0.3, 0, -0.5)
		"shoot":
			var recoil := 0.35 if p > 0.1 and p < 0.3 else 0.0
			t["ArmR"] = Vector3(-1.5 - recoil, 0, -0.1)
			t["ForearmR"] = Vector3(0.0, 0, 0)
			t["ArmL"] = Vector3(-1.3 - recoil * 0.5, 0, 0.45)
			t["ForearmL"] = Vector3(-0.5, 0, 0)
			t["Torso"] = Vector3(-0.04 - recoil * 0.2, 0, 0)
		"grab":
			var reach := smoothstep(0.1, 0.5, p)
			t["ArmL"] = Vector3(lerpf(-1.2, -1.75, reach), 0, 0.05)
			t["ArmR"] = Vector3(lerpf(-1.1, -1.75, reach), 0, -0.05)
			t["ForearmL"] = Vector3(-0.15, 0, 0)
			t["ForearmR"] = Vector3(-0.15, 0, 0)
			t["Torso"] = Vector3(lerpf(0.15, 0.55, reach), 0, 0)
			t["Head"] = Vector3(-0.3 * reach, 0, 0)
			lunge = 0.18 * reach if p < 0.75 else 0.0
		"bash":
			var hit := sin(p * TAU)
			t["ArmR"] = Vector3(-1.9 + hit * 0.7, 0, -0.1)
			t["ArmL"] = Vector3(-1.9 - hit * 0.7, 0, 0.1)
			t["ForearmL"] = Vector3(-0.3, 0, 0)
			t["ForearmR"] = Vector3(-0.3, 0, 0)
			t["Torso"] = Vector3(0.25 + absf(hit) * 0.1, 0, 0)
		_:
			# swing / finish: wind-up (0-0.4), strike (0.4-0.6), follow-through (0.6-1).
			var low := attack_style == "finish"
			var arm: float
			var twist: float
			var lean: float
			if p < 0.4:
				var k := p / 0.4
				arm = lerpf(0.0, -2.5, k)
				twist = lerpf(0.0, 0.55, k)
				lean = lerpf(0.0, -0.08, k)
			elif p < 0.6:
				var k := (p - 0.4) / 0.2
				arm = lerpf(-2.5, -0.1 if low else -0.45, k)
				twist = lerpf(0.55, -0.45, k)
				lean = lerpf(-0.08, 0.55 if low else 0.22, k)
			else:
				var k := (p - 0.6) / 0.4
				arm = lerpf(-0.1 if low else -0.45, 0.0, k)
				twist = lerpf(-0.45, 0.0, k)
				lean = lerpf(0.55 if low else 0.22, 0.03, k)
			t["ArmR"] = Vector3(arm, 0, -0.25)
			t["ForearmR"] = Vector3(-0.35, 0, 0)
			t["ArmL"] = Vector3(arm * 0.6 if holding else -0.4, 0, 0.15)
			t["ForearmL"] = Vector3(-0.9, 0, 0)
			t["Torso"] = Vector3(lean, twist, 0)
			if low:
				t["LegL"] = Vector3(-0.5, 0, 0)
				t["ShinL"] = Vector3(0.6, 0, 0)
			lunge = 0.08 if p > 0.4 and p < 0.75 else 0.0
