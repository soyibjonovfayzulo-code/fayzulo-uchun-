extends Node3D
## World root: places the player at the district spawn, wires the camera, starts ambience, weather and
## utilities (Climate), populates the district with zombies (pass `-- --no-zombies` for an empty town)
## and restores a saved game when the new-game menu asked for it.

@onready var district: District = $District
@onready var player: Player = $Player
@onready var rig: CameraRig = $CameraRig
@onready var zombies: ZombieSpawner = $Zombies

var climate: Climate
var rain_fx: RainFX
var fp_cam: FPCamera
var first_person := false


func _ready() -> void:
	GameOptions.ensure_loaded()
	GameOptions.apply_environment(($WorldEnvironment as WorldEnvironment).environment, $Sun as DirectionalLight3D)
	GameOptions.add_post(rig.camera)
	GameTime.reset()
	GameTime.real_minutes_per_day = Settings.day_length_minutes
	GameTime.set_hour(Settings.start_hour)
	Sfx.attach_to(self)
	climate = Climate.new()
	climate.name = "Climate"
	add_child(climate)
	rain_fx = RainFX.new()
	rain_fx.name = "Rain"
	rain_fx.target = player
	add_child(rain_fx)
	var amb := AmbientEvents.new()
	amb.name = "AmbientEvents"
	add_child(amb)
	var heli := HelicopterEvent.new()
	heli.name = "Helicopter"
	add_child(heli)
	player.global_position = district.spawn_point
	player.camera = rig.camera
	rig.snap_to_target()
	Backdrop.build(self)
	fp_cam = FPCamera.new()
	add_child(fp_cam)
	fp_cam.bind(player)
	player.fp = fp_cam
	fp_cam.post = GameOptions.add_post(fp_cam.camera)
	(fp_cam.post.material_override as ShaderMaterial).set_shader_parameter("perspective", 1.0)
	Sfx.start_ambient("wind_loop")
	var args := OS.get_cmdline_user_args()
	var testing := "--autotest" in args or "--tour" in args or "--poses" in args or "--m78" in args or "--v04" in args or "--gallery" in args or "--fps" in args or "--profile-interactions" in args or "--test-hot-update" in args
	# Tests drive the isometric game unless they ask for first person.
	var want_fp := Settings.first_person and (not testing or "--fps" in args)
	set_first_person.call_deferred(want_fp)
	if Settings.load_save and SaveGame.exists():
		Settings.load_save = false
		SaveGame.load_into.call_deferred(self)
		return
	Settings.load_save = false
	_starting_kit()
	if Settings.test_room:
		Events.show_toast.call_deferred("Рядом «Тестовая» (кирпичная будка у площадки): ящики со всеми предметами.")
	zombies.place_corpses.call_deferred()
	# Tests populate the town themselves.
	if not ("--no-zombies" in args or testing):
		zombies.spawn_all.call_deferred(Settings.zombie_count)


## What the survivor had on them when it all started.
func _starting_kit() -> void:
	var inv := player.inventory
	inv.give("water")
	inv.give("crackers")
	inv.give("matches")
	inv.give("bandage", 2)
	inv.equip(inv.give("tracksuit"))
	Profession.apply(player)


## Switches between the survivor's eyes (v0.5) and the isometric camera of v0.1-v0.4.
func set_first_person(on: bool) -> void:
	first_person = on
	Mats.first_person = on
	var vm := get_node_or_null("VisibilityManager") as VisibilityManager
	if vm:
		vm.set_first_person(on)
	fp_cam.set_active(on)
	rig.camera.current = not on
	var iso_post := rig.camera.get_node_or_null("PostStylize") as Node3D
	if iso_post:
		iso_post.visible = GameOptions.outline and not on
	player.camera = fp_cam.camera if on else rig.camera
	player.set_first_person_body(on)
	for v in get_tree().get_nodes_in_group("vehicles"):
		(v as Vehicle).set_interior(on and (v as Vehicle).driver == player)
	var dn := get_node_or_null("DayNight")
	if dn:
		dn.set("first_person", on)
	if not on:
		rig.snap_to_target()
	Events.view_changed.emit(on)


func toggle_view() -> void:
	if player.state == Player.State.DEAD:
		return
	set_first_person(not first_person)
	Events.show_toast("Вид от первого лица." if first_person else "Изометрический вид (V — обратно от первого лица).")
