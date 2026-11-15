class_name AmbientEvents
extends Node
## Distant life (and death) of the town: crows by day, dogs barking, far-off gunshots and screams,
## an evacuation siren on the first days. Pure atmosphere, played quietly through the UI channel.

const EVENTS := [
	# sound, min_day, max_day, day_only, weight
	["crow", 1, 99, true, 3.0],
	["dog_bark", 1, 99, false, 2.0],
	["distant_shot", 1, 6, false, 1.2],
	["scream_far", 1, 99, false, 0.8],
	["siren", 1, 2, true, 0.7],
]

var _t := 25.0


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = randf_range(35.0, 90.0)
	var day := GameTime.get_day()
	var is_day := DayNight.night < 0.5
	var pool: Array = []
	var total := 0.0
	for e in EVENTS:
		if day >= e[1] and day <= e[2] and (is_day or not e[3]):
			pool.append(e)
			total += float(e[4])
	var r := randf() * total
	for e in pool:
		r -= float(e[4])
		if r <= 0.0:
			Sfx.play_ui(e[0], randf_range(-20.0, -12.0))
			if e[0] == "distant_shot" and randf() < 0.5:
				_t = randf_range(1.0, 2.5)
			break
