extends Node
## Root: keeps the game render at an integer pixel scale and starts optional test modes
## (user args: --autotest runs functional checks, --tour also saves screenshots to tools/screens).

@onready var view: SubViewportContainer = $GameView


func _ready() -> void:
	get_tree().root.size_changed.connect(_update_scale)
	_update_scale()
	var args := OS.get_cmdline_user_args()
	var shots := false
	for a in args:
		shots = shots or a.begins_with("--shot=")
	if "--autotest" in args or "--tour" in args or "--poses" in args or shots:
		var t := preload("res://versions/v01/scripts/systems/autotest.gd").new()
		t.tour = "--tour" in args
		add_child(t)


func _update_scale() -> void:
	var h := get_viewport().get_visible_rect().size.y
	view.stretch_shrink = 3 if h >= 1400.0 else 2


func get_world() -> Node3D:
	return $GameView/SubViewport/World
