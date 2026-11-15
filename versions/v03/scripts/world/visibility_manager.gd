class_name V03VisibilityManager
extends Node
## Each frame: which building/floor is the player on? Hides floors above and the roof, feeds the
## cutaway shader globals, and remembers the location for footsteps and the HUD.

@export var player_path: NodePath

var player: Node3D
var current_building: V03Building
var current_level := -1
var _radius := 3.2


func _ready() -> void:
	player = get_node_or_null(player_path) as Node3D


func _process(delta: float) -> void:
	if player == null:
		return
	var pos := player.global_position
	var found: V03Building = null
	var level := -1
	for b in get_tree().get_nodes_in_group("buildings"):
		var bb := b as V03Building
		if bb.contains_point(pos):
			found = bb
			level = bb.level_at(pos)
			break
	if found != current_building or level != current_level:
		if current_building and current_building != found:
			current_building.set_view(-1)
		current_building = found
		current_level = level
		if found:
			found.set_view(level)
			RenderingServer.global_shader_parameter_set("cut_box", _world_box(found))
		RenderingServer.global_shader_parameter_set("cut_box_on", 1.0 if found else 0.0)
		V03Events.player_location_changed.emit(found, level)
	var floor_y := pos.y - 0.05
	if found:
		floor_y = found.floor_world_y(level)
	var target_r := 6.5 if found else 3.4
	_radius = lerpf(_radius, target_r, clampf(delta * 5.0, 0.0, 1.0))
	RenderingServer.global_shader_parameter_set("cut_player_pos", pos + Vector3(0, 0.95, 0))
	RenderingServer.global_shader_parameter_set("cut_floor_y", floor_y)
	RenderingServer.global_shader_parameter_set("cut_radius", _radius)
	if player.has_method("set") and "surface" in player:
		player.set("surface", "floor" if found else V03District.surface_at(pos))


## World-space XZ bounds of a building footprint (buildings are rotated in 90 degree steps).
static func _world_box(b: V03Building) -> Vector4:
	var r := b.footprint
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]:
		var w := b.to_global(Vector3(c.x, 0, c.y))
		lo = lo.min(Vector2(w.x, w.z))
		hi = hi.max(Vector2(w.x, w.z))
	return Vector4(lo.x, lo.y, hi.x, hi.y)
