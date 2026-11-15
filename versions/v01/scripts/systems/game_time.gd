extends Node
## World clock. One in-game day lasts `real_minutes_per_day` real minutes (default 48, i.e. 2 s per game minute).

signal hour_changed(hour: int)
signal day_changed(day: int)

const START_DAY := 1
const START_HOUR := 8.5

@export var real_minutes_per_day := 48.0

var total_minutes := START_HOUR * 60.0
var time_scale := 1.0
var paused := false

var _last_hour := -1
var _last_day := -1


func _process(delta: float) -> void:
	if paused or get_tree().paused:
		return
	total_minutes += delta * minutes_per_second() * time_scale
	var h := get_hour()
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)
	var d := get_day()
	if d != _last_day:
		_last_day = d
		day_changed.emit(d)


## Back to the morning of day 1 (new game).
func reset() -> void:
	total_minutes = START_HOUR * 60.0
	time_scale = 1.0
	paused = false
	_last_hour = -1
	_last_day = -1


func minutes_per_second() -> float:
	return 1440.0 / (real_minutes_per_day * 60.0)


## Game hours elapsed per real second at the current scale (used by survival rates).
func game_hours(delta: float) -> float:
	return delta * minutes_per_second() * time_scale / 60.0


func get_day() -> int:
	return START_DAY + int(total_minutes / 1440.0)


func get_hour() -> int:
	return int(fmod(total_minutes / 60.0, 24.0))


func get_minute() -> int:
	return int(fmod(total_minutes, 60.0))


## 0..24 float hour of the current day.
func get_hour_f() -> float:
	return fmod(total_minutes / 60.0, 24.0)


func get_clock_text() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]


func set_hour(hour: float) -> void:
	total_minutes = float(get_day() - START_DAY) * 1440.0 + hour * 60.0
