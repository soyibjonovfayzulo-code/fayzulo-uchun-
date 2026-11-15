class_name V02CarAlarm
extends Node3D
## Car alarm: once triggered (hit, smashed window, rummaging in the glovebox) it wails for a while,
## flashing the indicators and broadcasting a big noise every second - a zombie magnet.

@export var duration := 40.0

var armed := true
var active := false
var _left := 0.0
var _tick := 0.0
var _lights: Array[OmniLight3D] = []
var _player: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("car_alarms")
	for x in [-0.6, 0.6]:
		for z in [-2.0, 2.0]:
			var l := OmniLight3D.new()
			l.position = Vector3(x, 0.7, z)
			l.omni_range = 3.0
			l.light_color = Color("#ffb040")
			l.light_energy = 0.0
			add_child(l)
			_lights.append(l)
	_player = AudioStreamPlayer3D.new()
	_player.stream = V02Sfx.get_stream("car_alarm")
	_player.unit_size = 14.0
	_player.max_distance = 80.0
	add_child(_player)


func trigger() -> void:
	if not armed or active:
		return
	active = true
	_left = duration
	_tick = 0.0
	_player.play()
	V02Events.show_toast("Сработала автосигнализация!")


func _process(delta: float) -> void:
	if not active:
		return
	_left -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0
		V02NoiseSystem.emit(global_position, 32.0, self)
		if not _player.playing:
			_player.play()
	var blink := 1.4 if fmod(_left, 0.8) > 0.4 else 0.0
	for l in _lights:
		l.light_energy = blink
	if _left <= 0.0:
		active = false
		armed = false
		_player.stop()
		for l in _lights:
			l.light_energy = 0.0
