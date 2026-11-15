extends OmniLight3D
## Fire light that flickers around its starting energy.

var _base := 2.0
var _t := 0.0


func _ready() -> void:
	_base = light_energy
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	light_energy = _base * (0.8 + 0.12 * sin(_t * 13.0) + 0.1 * sin(_t * 31.0 + 1.3) + randf() * 0.08)
