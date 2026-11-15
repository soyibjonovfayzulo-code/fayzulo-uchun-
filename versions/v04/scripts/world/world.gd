extends Node3D
## World root: places the player at the district spawn, wires the camera, starts ambience, weather and
## utilities (Climate), populates the district with zombies (pass `-- --no-zombies` for an empty town)
## and restores a saved game when the new-game menu asked for it.

@onready var district: V04District = $District
@onready var player: V04Player = $Player
@onready var rig: V04CameraRig = $CameraRig
@onready var zombies: V04ZombieSpawner = $Zombies

var climate: V04Climate
var rain_fx: V04RainFX


func _ready() -> void:
	V04GameOptions.ensure_loaded()
	V04GameOptions.apply_environment(($WorldEnvironment as WorldEnvironment).environment, $Sun as DirectionalLight3D)
	V04GameOptions.add_post(rig.camera)
	V04GameTime.reset()
	V04GameTime.real_minutes_per_day = V04Settings.day_length_minutes
	V04GameTime.set_hour(V04Settings.start_hour)
	V04Sfx.attach_to(self)
	climate = V04Climate.new()
	climate.name = "Climate"
	add_child(climate)
	rain_fx = V04RainFX.new()
	rain_fx.name = "Rain"
	rain_fx.target = player
	add_child(rain_fx)
	var amb := V04AmbientEvents.new()
	amb.name = "AmbientEvents"
	add_child(amb)
	var heli := V04HelicopterEvent.new()
	heli.name = "Helicopter"
	add_child(heli)
	player.global_position = district.spawn_point
	player.camera = rig.camera
	rig.snap_to_target()
	V04Sfx.start_ambient("wind_loop")
	var args := OS.get_cmdline_user_args()
	var testing := "--autotest" in args or "--tour" in args or "--poses" in args or "--m78" in args or "--v04" in args or "--gallery" in args
	if V04Settings.load_save and V04SaveGame.exists():
		V04Settings.load_save = false
		V04SaveGame.load_into.call_deferred(self)
		return
	V04Settings.load_save = false
	_starting_kit()
	if V04Settings.test_room:
		V04Events.show_toast.call_deferred("Рядом «Тестовая» (кирпичная будка у площадки): ящики со всеми предметами.")
	zombies.place_corpses.call_deferred()
	# Tests populate the town themselves.
	if not ("--no-zombies" in args or testing):
		zombies.spawn_all.call_deferred(V04Settings.zombie_count)


## What the survivor had on them when it all started.
func _starting_kit() -> void:
	var inv := player.inventory
	inv.give("water")
	inv.give("crackers")
	inv.give("matches")
	inv.give("bandage", 2)
	inv.equip(inv.give("tracksuit"))
	V04Profession.apply(player)
