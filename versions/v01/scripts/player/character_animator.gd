class_name V01CharacterAnimator
extends Node
## Procedural animation for the rigid-part human model (Blender: assets/characters/*.glb).
## Rotation.x > 0 swings a limb backwards (model faces +Z); poses are blended every frame.

signal step(foot: int)

enum Pose { STAND, CROUCH, SIT, LIE, CLIMB, DEAD }

@export var model_path: NodePath

var pose := Pose.STAND
var speed := 0.0
var running := false
## 0..1 progress of the current attack swing, or -1 when not attacking.
var attack_t := -1.0
var lunge := 0.0

var _parts := {}
var _rest_pos := {}
var _phase := 0.0
var _time := 0.0
var _last_sin := 0.0
var _blend := {}


func _ready() -> void:
	var model := get_node(model_path)
	for n in ["Hips", "Torso", "Head", "ArmL", "ArmR", "ForearmL", "ForearmR", "LegL", "LegR", "ShinL", "ShinR"]:
		var node := model.find_child(n, true, false) as Node3D
		if node:
			_parts[n] = node
			_rest_pos[n] = node.position
			_blend[n] = Vector3.ZERO


func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	_time += delta
	var target := {}
	for n in _parts:
		target[n] = Vector3.ZERO
	var hip_drop := 0.0
	var moving := speed > 0.15

	match pose:
		Pose.STAND, Pose.CROUCH:
			var stride := 2.3 if running else 1.45
			if pose == Pose.CROUCH:
				stride = 1.0
			if moving:
				_phase = fmod(_phase + delta * speed / stride * TAU, TAU)
			else:
				_phase = lerpf(_phase, 0.0 if _phase < PI * 0.5 or _phase > PI * 1.5 else PI, delta * 6.0)
			var s := sin(_phase)
			var c := cos(_phase)
			var amp := clampf(speed / (5.0 if running else 2.3), 0.0, 1.0)
			var a_leg := (0.72 if running else 0.42) * amp
			var a_knee := (1.35 if running else 0.62) * amp
			var a_arm := (0.75 if running else 0.32) * amp
			target["LegL"] = Vector3(-s * a_leg, 0, 0)
			target["LegR"] = Vector3(s * a_leg, 0, 0)
			target["ShinL"] = Vector3(maxf(0.0, c) * a_knee + 0.05, 0, 0)
			target["ShinR"] = Vector3(maxf(0.0, -c) * a_knee + 0.05, 0, 0)
			target["ArmL"] = Vector3(s * a_arm, 0, 0.06)
			target["ArmR"] = Vector3(-s * a_arm, 0, -0.06)
			var fore := -1.25 if running else -0.18 - 0.1 * amp
			target["ForearmL"] = Vector3(fore, 0, 0)
			target["ForearmR"] = Vector3(fore, 0, 0)
			target["Torso"] = Vector3((0.2 if running else 0.03) * amp + sin(_time * 1.6) * 0.012, s * 0.07 * amp, 0)
			target["Head"] = Vector3(-(0.12 if running else 0.0) * amp, 0, 0)
			hip_drop = (absf(c) - 0.6) * (0.05 if running else 0.025) * amp
			if pose == Pose.CROUCH:
				target["LegL"] += Vector3(-1.05, 0, 0.05)
				target["LegR"] += Vector3(-1.05, 0, -0.05)
				target["ShinL"] = Vector3(1.65 + maxf(0.0, c) * 0.3 * amp, 0, 0)
				target["ShinR"] = Vector3(1.65 + maxf(0.0, -c) * 0.3 * amp, 0, 0)
				target["Torso"] = Vector3(0.5, s * 0.05 * amp, 0)
				target["Head"] = Vector3(-0.38, 0, 0)
				target["ArmL"] = Vector3(-0.35 + s * 0.15 * amp, 0, 0.1)
				target["ArmR"] = Vector3(-0.35 - s * 0.15 * amp, 0, -0.1)
				target["ForearmL"] = Vector3(-0.6, 0, 0)
				target["ForearmR"] = Vector3(-0.6, 0, 0)
				hip_drop -= 0.36
			# Footstep events at each foot contact.
			if moving and signf(s) != signf(_last_sin):
				step.emit(0 if s > 0 else 1)
			_last_sin = s
		Pose.SIT:
			target["LegL"] = Vector3(-1.5, 0, 0.06)
			target["LegR"] = Vector3(-1.5, 0, -0.06)
			target["ShinL"] = Vector3(1.45, 0, 0)
			target["ShinR"] = Vector3(1.45, 0, 0)
			target["Torso"] = Vector3(-0.05 + sin(_time * 1.4) * 0.01, 0, 0)
			target["ArmL"] = Vector3(-0.45, 0, 0.1)
			target["ArmR"] = Vector3(-0.45, 0, -0.1)
			target["ForearmL"] = Vector3(-0.7, 0, 0)
			target["ForearmR"] = Vector3(-0.7, 0, 0)
		Pose.LIE:
			target["Torso"] = Vector3(sin(_time * 1.1) * 0.015, 0, 0)
			target["ArmL"] = Vector3(-0.15, 0, 0.25)
			target["ArmR"] = Vector3(-0.15, 0, -0.25)
			target["ShinL"] = Vector3(0.1, 0, 0)
			target["ShinR"] = Vector3(0.2, 0, 0)
		Pose.CLIMB:
			var k := sin(_time * 9.0)
			target["LegL"] = Vector3(-1.2 + k * 0.3, 0, 0.1)
			target["LegR"] = Vector3(-0.5 - k * 0.3, 0, -0.1)
			target["ShinL"] = Vector3(1.3, 0, 0)
			target["ShinR"] = Vector3(0.9, 0, 0)
			target["Torso"] = Vector3(0.55, 0, 0)
			target["ArmL"] = Vector3(-1.3, 0, 0.2)
			target["ArmR"] = Vector3(-1.3, 0, -0.2)
			hip_drop = -0.1
		Pose.DEAD:
			target["ArmL"] = Vector3(-0.3, 0, 1.1)
			target["ArmR"] = Vector3(-0.2, 0, -1.2)
			target["LegL"] = Vector3(-0.1, 0, 0.2)
			target["LegR"] = Vector3(0.1, 0, -0.15)
			target["Head"] = Vector3(0, 0.5, 0)

	lunge = 0.0
	if attack_t >= 0.0:
		_apply_attack(target, attack_t)

	var k_blend := clampf(delta * (18.0 if attack_t >= 0.0 else 12.0), 0.0, 1.0)
	for n in _parts:
		_blend[n] = (_blend[n] as Vector3).lerp(target[n], k_blend)
		(_parts[n] as Node3D).rotation = _blend[n]
	var hips := _parts.get("Hips") as Node3D
	if hips:
		var rp: Vector3 = _rest_pos["Hips"]
		hips.position.y = lerpf(hips.position.y, rp.y + hip_drop, k_blend)
		hips.position.z = lerpf(hips.position.z, rp.z + lunge, k_blend)


func _apply_attack(t: Dictionary, p: float) -> void:
	# Wind-up (0-0.4), strike (0.4-0.6), follow-through/recover (0.6-1).
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
		arm = lerpf(-2.5, -0.45, k)
		twist = lerpf(0.55, -0.45, k)
		lean = lerpf(-0.08, 0.22, k)
	else:
		var k := (p - 0.6) / 0.4
		arm = lerpf(-0.45, 0.0, k)
		twist = lerpf(-0.45, 0.0, k)
		lean = lerpf(0.22, 0.03, k)
	t["ArmR"] = Vector3(arm, 0, -0.25)
	t["ForearmR"] = Vector3(-0.35, 0, 0)
	t["ArmL"] = Vector3(-0.4, 0, 0.15)
	t["ForearmL"] = Vector3(-0.9, 0, 0)
	t["Torso"] = Vector3(lean, twist, 0)
	lunge = 0.08 if p > 0.4 and p < 0.75 else 0.0
