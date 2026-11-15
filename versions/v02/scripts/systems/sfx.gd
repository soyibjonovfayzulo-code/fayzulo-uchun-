extends Node
## Positional one-shot sounds with a small player pool, plus the ambient wind bed.

const SOUND_DIR := "res://versions/v02/assets/audio/"
const POOL_SIZE := 16

var _streams := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0
var _ambient: AudioStreamPlayer
var _ui: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		p.max_distance = 45.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_ui = AudioStreamPlayer.new()
	add_child(_ui)
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = -14.0
	add_child(_ambient)
	_ambient.finished.connect(_ambient.play)


## Positional players must live inside the game's 3D world (the SubViewport), so the world adopts them.
func attach_to(world_root: Node3D) -> void:
	for p in _pool:
		p.reparent(world_root, false)
	# Take the players back before the world is freed (scene reload, return to menu).
	world_root.tree_exiting.connect(_reclaim_pool, CONNECT_ONE_SHOT)


func _reclaim_pool() -> void:
	for p in _pool:
		if is_instance_valid(p) and p.get_parent() != self:
			p.stop()
			p.reparent(self, false)


func stop_ambient() -> void:
	_ambient.stop()


func get_stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path := SOUND_DIR + sound + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]


## Plays `sound` (file name without .wav). A trailing "*" picks a random numbered variant, e.g. "step_concrete_*".
func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	if sound.ends_with("*"):
		sound = sound.trim_suffix("*") + str(randi_range(1, 4))
	var stream := get_stream(sound)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	if not p.is_inside_tree():
		return
	p.global_position = pos
	p.play()


func play_ui(sound: String, volume_db := -6.0) -> void:
	var stream := get_stream(sound)
	if stream:
		_ui.stream = stream
		_ui.volume_db = volume_db
		_ui.play()


func start_ambient(sound: String) -> void:
	var stream := get_stream(sound)
	if stream:
		_ambient.stream = stream
		_ambient.play()
