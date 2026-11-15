class_name V04HelicopterEvent
extends Node3D
## The helicopter (PZ meta event): once, on day 2-3, a military helicopter crosses the town. If it spots
## the survivor outdoors it hangs overhead for a minute with a searchlight, and the rotor noise drags
## zombies in from all over the district. Indoors, it circles the house for a while and leaves.

const ALT := 18.0
## Hover point relative to the survivor: low and toward the camera so it stays in the iso frame.
const HOVER_OFFSET := Vector3(8.0, 15.5, 8.0)
const SPEED := 16.0
const HOVER_SECONDS := 60.0

static var instance: V04HelicopterEvent

var start_hour := -1.0
var done := false
var active := false
var phase := ""
var _body: Node3D
var _rotor: Node3D
var _sound: AudioStreamPlayer3D
var _light: SpotLight3D
var _t := 0.0
var _noise_t := 0.0
var _orbit := 0.0
var _exit_dir := Vector3.ZERO
var _player: V04Player


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = V04Settings.world_seed + 99
	# Hours since the start: day 2 or 3, between 10:00 and 18:00.
	start_hour = (rng.randi_range(1, 2) * 24.0) + rng.randf_range(10.0, 18.0) - V04GameTime.START_HOUR
	if not V04Settings.helicopter:
		done = true


func _process(delta: float) -> void:
	if not active:
		if not done and V04Climate.instance and V04Climate.instance.hours_since_start() >= start_hour:
			begin()
		return
	_player = get_tree().get_first_node_in_group("player") as V04Player
	if _player == null:
		return
	_t += delta
	_rotor.rotation.y += delta * 28.0
	var target := _player.global_position
	var pos := global_position
	match phase:
		"approach":
			var goal := target + HOVER_OFFSET + Vector3(0, ALT - HOVER_OFFSET.y, 0) * 0.0
			global_position = pos.move_toward(goal, SPEED * delta)
			_face(goal - pos, delta)
			if pos.distance_to(goal) < 4.0:
				phase = "hover" if _player.is_outdoors() else "circle"
				_t = 0.0
				V04Events.show_toast("Вертолёт завис прямо над вами! Зомби сбегаются на шум." if phase == "hover"
					else "Вертолёт кружит над домом...")
		"hover", "circle":
			if phase == "hover":
				var goal := target + HOVER_OFFSET + Vector3(0, sin(_t * 0.7) * 0.6, 0)
				# Pull the camera out so the helicopter hanging overhead stays in frame.
				var rig := _player.get_parent().get_node_or_null("CameraRig")
				if rig and float(rig.get("_zoom_target")) < 24.0:
					rig.set("_zoom_target", 24.0)
				global_position = pos.lerp(goal, clampf(delta * 0.8, 0.0, 1.0))
				_face(Vector3(sin(_t * 0.2), 0, cos(_t * 0.2)), delta * 0.3)
				if not _player.is_outdoors() and _t > 10.0:
					phase = "circle"
			else:
				_orbit += delta * 0.35
				var goal := target + Vector3(cos(_orbit) * 16.0, ALT, sin(_orbit) * 16.0)
				global_position = pos.move_toward(goal, SPEED * delta)
				_face(goal - pos, delta)
			_light.light_energy = 6.0 if V04DayNight.night > 0.4 else 0.0
			_light.look_at(target, Vector3.FORWARD)
			if _t > (HOVER_SECONDS if phase == "hover" else 25.0):
				phase = "leave"
				_exit_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
				V04Events.show_toast("Вертолёт улетает. Зомби остались...")
		"leave":
			global_position = pos + _exit_dir * SPEED * 1.5 * delta + Vector3(0, delta * 2.0, 0)
			_face(_exit_dir, delta)
			_light.light_energy = 0.0
			if global_position.distance_to(target) > 160.0:
				finish()
				return
	_noise_t -= delta
	if _noise_t <= 0.0 and phase != "approach":
		_noise_t = 2.0
		V04NoiseSystem.emit(Vector3(global_position.x, target.y, global_position.z), 70.0 if phase == "hover" else 45.0, self)


func _face(dir: Vector3, k: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	var want := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(k * 2.0, 0.0, 1.0))


func begin() -> void:
	if active:
		return
	active = true
	done = true
	phase = "approach"
	_t = 0.0
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var from := (p.global_position if p else Vector3(120, 0, 100)) + Vector3(-150, ALT, -90)
	global_position = from
	_body = V04Props.spawn("aircraft/helicopter_body", self, Vector3.ZERO, 0.0, false, false)
	_rotor = V04Props.spawn("aircraft/helicopter_rotor", self, Vector3(0, 3.5, 0), 0.0, false, false)
	if _rotor == null:
		_rotor = Node3D.new()
		add_child(_rotor)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = V04Sfx.get_stream("helicopter_loop")
	_sound.unit_size = 40.0
	_sound.max_distance = 250.0
	_sound.volume_db = 2.0
	_sound.finished.connect(func() -> void:
		if active:
			_sound.play())
	add_child(_sound)
	_sound.play()
	_light = SpotLight3D.new()
	_light.position = Vector3(0, -0.2, -3.0)
	_light.spot_range = 40.0
	_light.spot_angle = 14.0
	_light.light_energy = 0.0
	_light.light_color = Color("#f0f4ff")
	_light.shadow_enabled = true
	add_child(_light)
	V04Events.show_toast("Слышен гул вертолёта...")


func finish() -> void:
	active = false
	for c in get_children():
		c.queue_free()


func save_state() -> Dictionary:
	return {"done": done or active}


func load_state(d: Dictionary) -> void:
	done = bool(d.get("done", false))
