class_name V03GameOptions
extends RefCounted
## Player options that persist between launches (user://options.cfg): master volume.

const PATH := "user://options.cfg"

static var volume := 0.8
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		volume = float(cf.get_value("audio", "volume", volume))
	_apply()


static func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply()
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("audio", "volume", volume)
	cf.save(PATH)


static func _apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
