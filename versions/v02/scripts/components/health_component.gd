class_name V02HealthComponent
extends Node
## Reusable hit points for the player now and zombies later.

signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died

@export var max_health := 100.0

var health := 100.0


func _ready() -> void:
	health = max_health


func take_damage(amount: float, source: Node = null) -> void:
	if is_dead() or amount <= 0.0:
		return
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
