class_name V01WindowObj
extends V01Interactable
## Soviet double-casement wooden window. Origin = opening centre at sill height, local X along the wall,
## local -Z points to the room interior (set by the builder). Can be opened, smashed and climbed through.

const FRAME := 0.06

@export var width := 1.4
@export var height := 1.4
@export var wall_thickness := 0.3
@export var start_open := false
@export var start_broken := false
@export var sill_height := 0.9
## Outside shards only make sense when there is ground right below the window.
@export var ground_floor := true

var is_open := false
var is_broken := false
var shards_cleared := false
var _sashes: Array[Node3D] = []
var _glass: Array[MeshInstance3D] = []
var _blocker: StaticBody3D
var _shards: Array[Node3D] = []


func _ready() -> void:
	display_name = "Окно"
	focus_offset = Vector3(0, height * 0.45, 0)
	focus_radius = 0.55
	super._ready()
	add_to_group("windows")
	_build()
	if start_broken:
		_break(false)
	elif start_open:
		_set_open(true, false)


func _build() -> void:
	var frame_mat := V01Mats.surface("frame")
	var mb := V01MeshBuilder.new()
	var hw := width * 0.5
	var t := 0.07
	mb.add_box(Vector3(-hw, 0, -t), Vector3(-hw + FRAME, height, t), "frame", frame_mat)
	mb.add_box(Vector3(hw - FRAME, 0, -t), Vector3(hw, height, t), "frame", frame_mat)
	mb.add_box(Vector3(-hw, height - FRAME, -t), Vector3(hw, height, t), "frame", frame_mat)
	mb.add_box(Vector3(-hw, 0, -t), Vector3(hw, FRAME, t), "frame", frame_mat)
	# Inner wooden sill and outer metal drip.
	mb.add_box(Vector3(-hw - 0.05, -0.04, -wall_thickness * 0.5 - 0.2), Vector3(hw + 0.05, 0.0, -t),
		"sill", V01Mats.surface("sill"))
	mb.add_box(Vector3(-hw, -0.06, t), Vector3(hw, -0.03, wall_thickness * 0.5 + 0.08), "metal_dark",
		V01Mats.surface("metal_dark"))
	add_child(mb.commit("Frame"))
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "Sash%s" % ("L" if side < 0 else "R")
		hinge.position = Vector3(hw * side - FRAME * side, FRAME, 0)
		add_child(hinge)
		var sw := hw - FRAME
		var smb := V01MeshBuilder.new()
		var x0 := -sw if side > 0 else 0.0
		var x1 := 0.0 if side > 0 else sw
		var sh := height - FRAME * 2.0
		var f := 0.045
		smb.add_box(Vector3(x0, 0, -0.03), Vector3(x0 + f, sh, 0.03), "frame", frame_mat)
		smb.add_box(Vector3(x1 - f, 0, -0.03), Vector3(x1, sh, 0.03), "frame", frame_mat)
		smb.add_box(Vector3(x0, 0, -0.03), Vector3(x1, f, 0.03), "frame", frame_mat)
		smb.add_box(Vector3(x0, sh - f, -0.03), Vector3(x1, sh, 0.03), "frame", frame_mat)
		smb.add_box(Vector3(x0, sh * 0.72, -0.03), Vector3(x1, sh * 0.72 + f * 0.8, 0.03), "frame", frame_mat)
		hinge.add_child(smb.commit("SashFrame"))
		var gm := MeshInstance3D.new()
		gm.name = "Glass"
		var q := BoxMesh.new()
		q.size = Vector3(sw - f * 2.0, sh - f * 2.0, 0.008)
		gm.mesh = q
		gm.material_override = V01Mats.glass()
		gm.position = Vector3((x0 + x1) * 0.5, sh * 0.5, 0)
		hinge.add_child(gm)
		_sashes.append(hinge)
		_glass.append(gm)
	_blocker = V01Props.add_box(self, Vector3(0, height * 0.5, 0), Vector3(width, height, 0.12))


func get_actions(_actor: Node) -> Array:
	var a: Array = []
	if is_broken or is_open:
		a.append({"id": "climb", "label": "Пролезть в окно"})
	if not is_broken:
		a.append({"id": "close" if is_open else "open", "label": "Закрыть окно" if is_open else "Открыть окно"})
		a.append({"id": "smash", "label": "Разбить стекло"})
	elif not shards_cleared:
		a.append({"id": "clear", "label": "Убрать осколки"})
	return a


func perform(action_id: String, actor: Node) -> void:
	match action_id:
		"open":
			_set_open(true)
		"close":
			_set_open(false)
		"smash":
			_break(true)
		"clear":
			shards_cleared = true
			V01Sfx.play_at("glass_clear", get_focus_point(), -6.0)
			V01Events.show_toast("Осколки убраны с рамы.")
		"climb":
			if actor.has_method("climb_through_window"):
				actor.climb_through_window(self)


func _set_open(open: bool, animate := true) -> void:
	is_open = open
	for i in _sashes.size():
		var s := _sashes[i]
		var side := -1.0 if i == 0 else 1.0
		var target := deg_to_rad(78.0) * side if open else 0.0
		if animate:
			create_tween().tween_property(s, "rotation:y", target, 0.4).set_trans(Tween.TRANS_SINE)
		else:
			s.rotation.y = target
	if animate:
		V01Sfx.play_at("window_open", get_focus_point(), -6.0)
		V01NoiseSystem.emit(global_position, 3.0, self)


func _break(loud: bool) -> void:
	if is_broken:
		return
	is_broken = true
	for g in _glass:
		g.visible = false
	for side in [-1.0, 1.0]:
		if side > 0.0 and not ground_floor:
			continue
		var p := position + basis * Vector3(0, 0, side * (wall_thickness * 0.5 + 0.45))
		p.y = position.y - sill_height + 0.012
		var sh := V01Props.spawn("environment/shards", get_parent() as Node3D, p, randf() * 360.0, false)
		if sh:
			_shards.append(sh)
	if loud:
		V01Sfx.play_at("glass_break", get_focus_point(), 2.0)
		V01NoiseSystem.emit(global_position, 20.0, self)
		V01Events.window_broken.emit(self)


## Point on the far side of the window relative to `from` (global), used by the climbing player.
func get_climb_target(from: Vector3) -> Vector3:
	var local := to_local(from)
	var side := -signf(local.z) if absf(local.z) > 0.01 else 1.0
	return global_transform * Vector3(0, 0.05, side * (wall_thickness * 0.5 + 0.55))


func get_sill_point() -> Vector3:
	return global_transform * Vector3(0, 0.05, 0)


## True while unremoved glass still sticks out of the frame (climbing will hurt).
func is_hazardous() -> bool:
	return is_broken and not shards_cleared
