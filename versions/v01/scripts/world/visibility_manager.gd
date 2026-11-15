class_name V01VisibilityManager
extends Node
## Each frame: which building/floor is the player on? Hides floors above and the roof, feeds the
## cutaway shader globals, and remembers the location for footsteps and the HUD.

@export var player_path: NodePath

var player: Node3D
var current_building: V01Building
var current_level := -1
var _radius := 3.2


func _ready() -> void:
	player = get_node_or_null(player_path) as Node3D


func _process(delta: float) -> void:
	if player == null:
		return
	var pos := player.global_position
	var found: V01Building = null
	var level := -1
	for b in get_tree().get_nodes_in_group("buildings"):
		var bb := b as V01Building
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
		V01Events.player_location_changed.emit(found, level)
	var floor_y := pos.y - 0.05
	if found:
		floor_y = found.floor_world_y(level)
	var target_r := 6.5 if found else 3.4
	_radius = lerpf(_radius, target_r, clampf(delta * 5.0, 0.0, 1.0))
	RenderingServer.global_shader_parameter_set("cut_player_pos", pos + Vector3(0, 0.95, 0))
	RenderingServer.global_shader_parameter_set("cut_floor_y", floor_y)
	RenderingServer.global_shader_parameter_set("cut_radius", _radius)
	if player.has_method("set") and "surface" in player:
		player.set("surface", "floor" if found else V01District.surface_at(pos))
