extends Node
## Sound-propagation hub for AI. Anything audible calls NoiseSystem.emit(); zombies (Milestone 5) listen to Events.noise_emitted.

const HISTORY_SECONDS := 3.0

var recent: Array[Dictionary] = []


func emit(position: Vector3, radius: float, source: Node = null) -> void:
	recent.append({"pos": position, "radius": radius, "time": Time.get_ticks_msec() / 1000.0})
	Events.noise_emitted.emit(position, radius, source)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	while recent.size() > 0 and now - float(recent[0]["time"]) > HISTORY_SECONDS:
		recent.pop_front()
