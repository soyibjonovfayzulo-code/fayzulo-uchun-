class_name V01Door
extends V01Interactable
## Hinged door placed in a wall opening. Node origin = opening centre at floor level,
## local X runs along the wall, local Z is the wall normal. The leaf swings away from whoever opens it.

enum Kind { INTERIOR, APARTMENT, ENTRANCE, GLASS, BALCONY }

const MODELS := {
	Kind.INTERIOR: "buildings/door_wood",
	Kind.APARTMENT: "buildings/door_apartment",
	Kind.ENTRANCE: "buildings/door_metal",
	Kind.GLASS: "buildings/door_glass",
	Kind.BALCONY: "buildings/door_balcony",
}
const WIDTHS := {Kind.INTERIOR: 0.8, Kind.APARTMENT: 0.9, Kind.ENTRANCE: 1.0, Kind.GLASS: 1.0, Kind.BALCONY: 0.75}
const HEIGHTS := {Kind.INTERIOR: 2.0, Kind.APARTMENT: 2.05, Kind.ENTRANCE: 2.05, Kind.GLASS: 2.1, Kind.BALCONY: 2.05}
const NAMES := {
	Kind.INTERIOR: "Дверь", Kind.APARTMENT: "Дверь квартиры", Kind.ENTRANCE: "Дверь подъезда",
	Kind.GLASS: "Стеклянная дверь", Kind.BALCONY: "Балконная дверь",
}

signal opened_changed(is_open: bool)

@export var kind := Kind.INTERIOR
@export var locked := false
@export var wall_thickness := 0.12
@export var open_angle := 92.0
## Optional: start open (abandoned flats often are).
@export var start_open := false

var is_open := false
var health := 100.0
var _hinge: Node3D
var _leaf: AnimatableBody3D
var _tween: Tween


static func width_of(k: Kind) -> float:
	return WIDTHS[k]


static func height_of(k: Kind) -> float:
	return HEIGHTS[k]


func _ready() -> void:
	display_name = NAMES[kind]
	focus_offset = Vector3(0, 1.05, 0)
	focus_radius = 0.5
	super._ready()
	add_to_group("doors")
	var w: float = WIDTHS[kind]
	var h: float = HEIGHTS[kind]
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	_hinge.position = Vector3(w * 0.5, 0, 0)
	add_child(_hinge)
	var model := V01Props.spawn(MODELS[kind], _hinge, Vector3.ZERO, 0.0, false)
	if model:
		model.name = "Leaf"
	_leaf = AnimatableBody3D.new()
	_leaf.name = "LeafBody"
	_leaf.collision_layer = 1
	_leaf.collision_mask = 0
	_leaf.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w - 0.04, h - 0.02, 0.07)
	cs.shape = box
	cs.position = Vector3(-w * 0.5, h * 0.5, 0)
	_leaf.add_child(cs)
	_hinge.add_child(_leaf)
	_build_frame(w, h)
	if start_open and not locked:
		_set_open(true, 1.0, false)


func _build_frame(w: float, h: float) -> void:
	var mb := V01MeshBuilder.new()
	var mat := V01Mats.surface("frame")
	var t := wall_thickness * 0.5 + 0.02
	mb.add_box(Vector3(-w * 0.5 - 0.07, 0, -t), Vector3(-w * 0.5, h + 0.07, t), "frame", mat)
	mb.add_box(Vector3(w * 0.5, 0, -t), Vector3(w * 0.5 + 0.07, h + 0.07, t), "frame", mat)
	mb.add_box(Vector3(-w * 0.5 - 0.07, h, -t), Vector3(w * 0.5 + 0.07, h + 0.07, t), "frame", mat)
	var mi := mb.commit("Frame")
	add_child(mi)


func get_actions(_actor: Node) -> Array:
	if is_open:
		return [{"id": "close", "label": "Закрыть"}]
	return [{"id": "open", "label": "Открыть"}]


func perform(action_id: String, actor: Node) -> void:
	match action_id:
		"open":
			if locked:
				V01Events.show_toast("Заперто.")
				V01Sfx.play_at("door_locked", get_focus_point())
				V01NoiseSystem.emit(global_position, 3.0, self)
				return
			var side := 1.0
			if actor is Node3D:
				var local := to_local((actor as Node3D).global_position)
				side = -signf(local.z) if absf(local.z) > 0.01 else 1.0
			_set_open(true, side)
		"close":
			_set_open(false, 0.0)


## Force open/close from scripts (zombie breaking in, debug).
func set_open_state(open: bool, side := 1.0) -> void:
	_set_open(open, side)


func _set_open(open: bool, side: float, animate := true) -> void:
	if open == is_open:
		return
	is_open = open
	var target := deg_to_rad(open_angle) * side if open else 0.0
	if _tween and _tween.is_valid():
		_tween.kill()
	if animate:
		_tween = create_tween()
		_tween.tween_property(_hinge, "rotation:y", target, 0.45 if open else 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		V01Sfx.play_at("door_open" if open else "door_close", get_focus_point(), -4.0)
		V01NoiseSystem.emit(global_position, 4.0 if open else 6.0, self)
	else:
		_hinge.rotation.y = target
	opened_changed.emit(is_open)


func get_focus_point() -> Vector3:
	return global_transform * focus_offset
