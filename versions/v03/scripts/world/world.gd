extends Node3D
## World root: places the player at the district spawn, wires the camera, starts ambience, weather and
## utilities (Climate), populates the district with zombies (pass `-- --no-zombies` for an empty town)
## and restores a saved game when the new-game menu asked for it.

@onready var district: V03District = $District
@onready var player: V03Player = $Player
@onready var rig: V03CameraRig = $CameraRig
@onready var zombies: V03ZombieSpawner = $Zombies

var climate: V03Climate
var rain_fx: V03RainFX


func _ready() -> void:
	V03GameTime.reset()
	V03GameTime.real_minutes_per_day = V03Settings.day_length_minutes
	V03GameTime.set_hour(V03Settings.start_hour)
	V03Sfx.attach_to(self)
	climate = V03Climate.new()
	climate.name = "Climate"
	add_child(climate)
	rain_fx = V03RainFX.new()
	rain_fx.name = "Rain"
	rain_fx.target = player
	add_child(rain_fx)
	var amb := V03AmbientEvents.new()
	amb.name = "AmbientEvents"
	add_child(amb)
	player.global_position = district.spawn_point
	player.camera = rig.camera
	rig.snap_to_target()
	V03Sfx.start_ambient("wind_loop")
	var args := OS.get_cmdline_user_args()
	var testing := "--autotest" in args or "--tour" in args or "--poses" in args or "--m78" in args
	if V03Settings.load_save and V03SaveGame.exists():
		V03Settings.load_save = false
		V03SaveGame.load_into.call_deferred(self)
		return
	V03Settings.load_save = false
	_starting_kit()
	if V03Settings.test_room:
		V03Events.show_toast.call_deferred("Рядом «Тестовая» (кирпичная будка у площадки): ящики со всеми предметами.")
	# Tests populate the town themselves.
	if not ("--no-zombies" in args or testing):
		zombies.spawn_all.call_deferred(V03Settings.zombie_count)


## What the survivor had on them when it all started.
func _starting_kit() -> void:
	var inv := player.inventory
	inv.give("water")
	inv.give("crackers")
	inv.give("matches")
	inv.give("bandage", 2)
	inv.equip(inv.give("tracksuit"))
