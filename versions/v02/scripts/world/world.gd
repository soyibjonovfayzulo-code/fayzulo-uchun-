extends Node3D
## World root: places the player at the district spawn, wires the camera, starts ambience and
## populates the district with zombies (pass `-- --no-zombies` for an empty town).

@onready var district: V02District = $District
@onready var player: V02Player = $Player
@onready var rig: V02CameraRig = $CameraRig
@onready var zombies: V02ZombieSpawner = $Zombies


func _ready() -> void:
	V02GameTime.reset()
	V02Sfx.attach_to(self)
	player.global_position = district.spawn_point
	player.camera = rig.camera
	rig.snap_to_target()
	V02Sfx.start_ambient("wind_loop")
	_starting_kit()
	if V02Settings.test_room:
		V02Events.show_toast.call_deferred("Рядом «Тестовая» (кирпичная будка у площадки): ящики со всеми предметами.")
	var args := OS.get_cmdline_user_args()
	# Tests populate the town themselves.
	if not ("--no-zombies" in args or "--autotest" in args or "--tour" in args or "--poses" in args):
		zombies.spawn_all.call_deferred(V02Settings.zombie_count)


## What the survivor had on them when it all started.
func _starting_kit() -> void:
	var inv := player.inventory
	inv.give("water")
	inv.give("crackers")
	inv.give("matches")
	inv.give("bandage", 2)
