class_name V03Building
extends Node3D
## A multi-level building. Each level is a Node3D with Shell (batched mesh), Body (collision),
## Fixtures (doors, windows, balconies) and Props (furniture). The VisibilityManager calls set_view()
## so upper floors and the roof disappear while the player is inside, like in Project Zomboid.

@export var display_name := "Дом"
@export var level_height := 2.8
@export var base_y := 0.1

## Footprint in local XZ (wall centre lines).
var footprint := Rect2()
var levels: Array[Node3D] = []
var roof: Node3D
## Room centres for spawning: [{"pos": Vector3 (local), "type": String, "level": int}]
var room_points: Array = []
var address := ""
var _view := -2


func _ready() -> void:
	add_to_group("buildings")


func add_level(index: int) -> Node3D:
	var lv := Node3D.new()
	lv.name = "Level%d" % index
	add_child(lv)
	for part in ["Fixtures", "Props"]:
		var n := Node3D.new()
		n.name = part
		lv.add_child(n)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	lv.add_child(body)
	levels.append(lv)
	return lv


func level_y(index: int) -> float:
	return base_y + index * level_height


func contains_point(p: Vector3) -> bool:
	var l := to_local(p)
	if l.y < base_y - 1.2 or l.y > level_y(levels.size()) + 0.5:
		return false
	return footprint.grow(-0.05).has_point(Vector2(l.x, l.z))


func level_at(p: Vector3) -> int:
	var l := to_local(p)
	return clampi(int(floor((l.y - base_y + 0.65) / level_height)), 0, max(levels.size() - 1, 0))


func floor_world_y(index: int) -> float:
	return to_global(Vector3(0, level_y(index), 0)).y


## level < 0: player outside. Otherwise the player is on that level of this building.
func set_view(level: int) -> void:
	if level == _view:
		return
	_view = level
	for i in levels.size():
		var lv := levels[i]
		var props := lv.get_node("Props") as Node3D
		if level < 0:
			lv.visible = true
			props.visible = i == 0
		else:
			lv.visible = i <= level
			props.visible = i == level
	if roof:
		roof.visible = level < 0


func get_view() -> int:
	return _view
