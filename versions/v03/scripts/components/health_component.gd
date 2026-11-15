class_name V03HealthComponent
extends Node
## Reusable hit points for the player and zombies. Remembers what hurt last (death screen).

signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died

@export var max_health := 100.0

var health := 100.0
var last_cause := ""


func _ready() -> void:
	health = max_health


func take_damage(amount: float, source: Node = null, cause := "") -> void:
	if is_dead() or amount <= 0.0:
		return
	if cause != "":
		last_cause = cause
	elif source != null:
		last_cause = "Зомби" if source.is_in_group("zombies") else last_cause
	health = maxf(health - amount, 0.0)
	damaged.emit(amount, source)
	if health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if is_dead() or amount <= 0.0:
		return
	var before := health
	health = minf(health + amount, max_health)
	healed.emit(health - before)


func is_dead() -> bool:
	return health <= 0.0


func ratio() -> float:
	return health / max_health
