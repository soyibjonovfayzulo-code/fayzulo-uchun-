class_name Door
extends Interactable
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

## Locked flat doors: matching key stacks carry the same key_id.
@export var key_id := ""
@export var key_label := ""

const LAYER_DOORS := 32
const MAX_HEALTH := {Kind.INTERIOR: 60.0, Kind.APARTMENT: 160.0, Kind.ENTRANCE: 220.0, Kind.GLASS: 50.0, Kind.BALCONY: 50.0}

var is_open := false
var broken := false
var health := 100.0
## Boards nailed across the door (Barricade).
var planks := 0
var plank_hp := 0.0
var _boards: Array[Node3D] = []
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
	health = MAX_HEALTH[kind]
	var w: float = WIDTHS[kind]
	var h: float = HEIGHTS[kind]
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	_hinge.position = Vector3(w * 0.5, 0, 0)
	add_child(_hinge)
	var model := Props.spawn(MODELS[kind], _hinge, Vector3.ZERO, 0.0, false)
	if model:
		model.name = "Leaf"
	_leaf = AnimatableBody3D.new()
	_leaf.name = "LeafBody"
	# Own layer: navigation is baked without doors, so zombies path through doorways and bash them.
	_leaf.collision_layer = LAYER_DOORS
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
	var mb := MeshBuilder.new()
	var mat := Mats.surface("frame")
	var t := wall_thickness * 0.5 + 0.02
	mb.add_box(Vector3(-w * 0.5 - 0.07, 0, -t), Vector3(-w * 0.5, h + 0.07, t), "frame", mat)
	mb.add_box(Vector3(w * 0.5, 0, -t), Vector3(w * 0.5 + 0.07, h + 0.07, t), "frame", mat)
	mb.add_box(Vector3(-w * 0.5 - 0.07, h, -t), Vector3(w * 0.5 + 0.07, h + 0.07, t), "frame", mat)
	var mi := mb.commit("Frame")
	add_child(mi)


func get_actions(actor: Node) -> Array:
	if broken:
		return []
	if planks > 0:
		return Barricade.actions(actor as Player, planks)
	if is_open:
		return [{"id": "close", "label": "Закрыть"}]
	var a: Array = [{"id": "open", "label": "Открыть"}]
	if actor is Player and not locked:
		a.append_array(Barricade.actions(actor as Player, 0))
	if locked:
		var inv := _inventory_of(actor)
		if inv and key_id != "" and inv.main.stacks.any(func(s: ItemStack) -> bool: return s.key_id == key_id):
			a.push_front({"id": "unlock", "label": "Открыть ключом"})
		if inv and inv.main.stacks.any(func(s: ItemStack) -> bool: return s.item.tags.has("pry")):
			a.append({"id": "pry", "label": "Взломать монтировкой"})
	return a


func can_interact(actor: Node) -> bool:
	return not broken and super.can_interact(actor)


func _inventory_of(actor: Node) -> PlayerInventory:
	return actor.get("inventory") as PlayerInventory if actor else null


## Melee hits and zombie bashing. Breaks the leaf off its hinges at zero health.
func damage(amount: float, _source: Node = null) -> void:
	if broken:
		return
	if planks > 0:
		plank_hp -= amount
		Sfx.play_at("door_bang", get_focus_point(), -2.0)
		NoiseSystem.emit(global_position, 10.0, self)
		if plank_hp <= 0.0:
			planks -= 1
			plank_hp = Barricade.PLANK_HP
			Sfx.play_at("weapon_break", get_focus_point(), -2.0)
			_refresh_boards()
		return
	health -= amount
	Sfx.play_at("door_bang", get_focus_point(), 0.0)
	NoiseSystem.emit(global_position, 10.0, self)
	var tw := create_tween()
	var base := _hinge.rotation.y
	tw.tween_property(_hinge, "rotation:y", base + 0.04, 0.05)
	tw.tween_property(_hinge, "rotation:y", base, 0.08)
	if health <= 0.0:
		break_down()


func break_down() -> void:
	broken = true
	locked = false
	is_open = true
	_leaf.collision_layer = 0
	var tw := create_tween()
	tw.tween_property(_hinge, "rotation:x", -1.45, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_hinge, "position:y", 0.05, 0.35)
	Sfx.play_at("door_break", get_focus_point(), 2.0)
	NoiseSystem.emit(global_position, 16.0, self)
	set_highlight(false)
	opened_changed.emit(true)


func perform(action_id: String, actor: Node) -> void:
	var _prof_t0 := Time.get_ticks_usec()
	match action_id:
		"board":
			Barricade.build(actor as Player, self, func() -> void:
				if planks == 0:
					plank_hp = Barricade.plank_hp(actor)
				planks += 1
				_refresh_boards())
			return
		"unboard":
			Barricade.remove(actor as Player, self, func() -> void:
				planks = maxi(planks - 1, 0)
				_refresh_boards())
			return
		"open":
			if planks > 0:
				Events.show_toast("Дверь заколочена.")
				return
			if locked:
				Events.show_toast("Заперто.")
				Sfx.play_at("door_locked", get_focus_point())
				NoiseSystem.emit(global_position, 3.0, self)
				return
			var side := 1.0
			if actor is Node3D:
				var local := to_local((actor as Node3D).global_position)
				side = -signf(local.z) if absf(local.z) > 0.01 else 1.0
			_set_open(true, side)
		"close":
			_set_open(false, 0.0)
		"unlock":
			locked = false
			Sfx.play_at("door_locked", get_focus_point(), -6.0)
			Events.show_toast("Ключ подошёл.")
			perform("open", actor)
		"pry":
			if actor.has_method("start_timed_action"):
				actor.start_timed_action("Взламываем дверь...", 4.0, func() -> void:
					locked = false
					health -= 30.0
					NoiseSystem.emit(global_position, 12.0, self)
					Sfx.play_at("door_bang", get_focus_point(), 0.0)
					Events.show_toast("Замок поддался.")
					perform("open", actor))
	if LiveDebug:
		LiveDebug.record_interaction("door", "%s (%s)" % [display_name, action_id], _prof_t0)


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
		Sfx.play_at("door_open" if open else "door_close", get_focus_point(), -4.0)
		NoiseSystem.emit(global_position, 4.0 if open else 6.0, self)
	else:
		_hinge.rotation.y = target
	opened_changed.emit(is_open)


func get_focus_point() -> Vector3:
	return global_transform * focus_offset


func save_state() -> Dictionary:
	return {"o": is_open, "l": locked, "b": broken, "hp": health, "a": _hinge.rotation.y, "pl": planks, "php": plank_hp}


func _refresh_boards() -> void:
	for b in _boards:
		if is_instance_valid(b):
			b.queue_free()
	_boards = Barricade.spawn_boards(self, planks, width_of(kind), 0.35, height_of(kind) - 0.2, wall_thickness * 0.5 + 0.03)
	invalidate_cache()


func load_state(d: Dictionary) -> void:
	locked = bool(d.get("l", locked))
	health = float(d.get("hp", health))
	planks = int(d.get("pl", 0))
	plank_hp = float(d.get("php", Barricade.PLANK_HP))
	_refresh_boards()
	if bool(d.get("b", false)):
		broken = true
		locked = false
		is_open = true
		_leaf.collision_layer = 0
		_hinge.rotation.x = -1.45
		_hinge.position.y = 0.05
		opened_changed.emit(true)
		return
	var open := bool(d.get("o", false))
	if open != is_open:
		is_open = open
		_hinge.rotation.y = float(d.get("a", deg_to_rad(open_angle)))
		opened_changed.emit(is_open)
