extends Node3D
## World root: places the player at the district spawn, wires the camera and starts ambience.

@onready var district: V01District = $District
@onready var player: V01Player = $Player
@onready var rig: V01CameraRig = $CameraRig


func _ready() -> void:
	V01GameTime.reset()
	V01Sfx.attach_to(self)
	player.global_position = district.spawn_point
	player.camera = rig.camera
	rig.snap_to_target()
	V01Sfx.start_ambient("wind_loop")
