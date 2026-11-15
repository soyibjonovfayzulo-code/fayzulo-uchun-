class_name V04Barricade
extends RefCounted
## Boarding up doors and windows (PZ-style): a hammer, a plank and two nails per board, up to 4 boards.
## Zombies must tear the boards off one by one before they can break or climb in. Carpentry makes the
## work faster and the boards tougher; a hammer or crowbar pries them off again.

const MAX := 4
const PLANK_HP := 55.0


static func can_build(p: V04Player) -> String:
	var inv := p.inventory.main
	if not inv.stacks.any(func(s: V04ItemStack) -> bool: return "hammer" in s.item.tags):
		return "Нужен молоток."
	if inv.find_by_id("planks") == null:
		return "Нужны доски."
	if inv.count_of("nails") < 2:
		return "Нужно 2 гвоздя."
	return ""


static func can_remove(p: V04Player) -> bool:
	return p.inventory.main.stacks.any(func(s: V04ItemStack) -> bool: return "hammer" in s.item.tags or "pry" in s.item.tags)


## Actions for a door/window with `count` boards.
static func actions(p: V04Player, count: int) -> Array:
	var a: Array = []
	if p == null:
		return a
	if count < MAX:
		a.append({"id": "board", "label": "Заколотить доской (%d/%d)" % [count, MAX]})
	if count > 0 and can_remove(p):
		a.append({"id": "unboard", "label": "Отодрать доску"})
	return a


## Timed hammering; `done` is called on success. Loud: zombies hear the hammer.
static func build(p: V04Player, target: Node3D, done: Callable) -> void:
	var why := can_build(p)
	if why != "":
		V04Events.show_toast(why)
		return
	var t := 3.5 * V04Skills.action_time(p, "carpentry")
	V04Sfx.play_at("hammer", target.global_position + Vector3.UP, -2.0)
	V04NoiseSystem.emit(target.global_position, 14.0, p)
	p.start_timed_action("Заколачиваем...", t, func() -> void:
		if can_build(p) != "":
			return
		var inv := p.inventory
		inv.consume(inv.main.find_by_id("planks"))
		var nails := inv.main.find_by_id("nails")
		inv.main.take(nails, 2)
		V04Sfx.play_at("hammer", target.global_position + Vector3.UP, 0.0)
		V04NoiseSystem.emit(target.global_position, 14.0, p)
		V04Skills.add_xp(p, "carpentry", 10.0)
		done.call())


static func remove(p: V04Player, target: Node3D, done: Callable) -> void:
	p.start_timed_action("Отдираем доску...", 2.5, func() -> void:
		p.inventory.give("planks")
		V04Sfx.play_at("door_bang", target.global_position + Vector3.UP, -4.0)
		done.call())


static func plank_hp(p: Node) -> float:
	return PLANK_HP * (1.0 + V04Skills.level_of(p, "carpentry") * 0.12)


## Visual boards across an opening of width w (local X) at height range [y0, y1], on the outer face z.
static func spawn_boards(parent: Node3D, count: int, w: float, y0: float, y1: float, z: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i in count:
		var y := lerpf(y0, y1, (float(i) + 0.5) / float(MAX))
		var tilt: float = [8.0, -10.0, 5.0, -6.0][i]
		var b := V04Props.spawn("environment/plank", parent, Vector3(0, y, z), 0.0, false)
		if b:
			b.rotation_degrees.z = tilt
			b.scale.x = (w + 0.3) / 1.3
			out.append(b)
	return out
