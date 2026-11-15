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
	if "--autotest" in args or "--tour" in args or "--poses" in args or "--loadcheck" in args or "--m78" in args or "--v04" in args or "--gallery" in args or "--fps" in args or "--probe-admin" in args or "--profile-interactions" in args or "--test-hot-update" in args or shots:
		var t := preload("res://scripts/systems/autotest.gd").new()
		t.tour = "--tour" in args
		add_child(t)


func _update_scale() -> void:
	var h := get_viewport().get_visible_rect().size.y
	view.stretch_shrink = GameOptions.shrink_for(h)


func get_world() -> Node3D:
	return $GameView/SubViewport/World
