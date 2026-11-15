class_name V01PlayerStats
extends Node
## Short-term endurance (stamina), mid-term fatigue from exertion and slow drowsiness.
## All values are 0..1. Rates are per real second, drowsiness per game hour.

signal exhausted_changed(exhausted: bool)

const RUN_DRAIN := 0.085
const ATTACK_COST := 0.035
const REGEN_IDLE := 0.07
const REGEN_WALK := 0.035
const REGEN_REST := 0.12
const FATIGUE_FROM_RUN := 0.004
const FATIGUE_RECOVERY_REST := 0.006
const DROWSY_PER_GAME_HOUR := 1.0 / 17.0

var endurance := 1.0
var fatigue := 0.0
var drowsiness := 0.15
var exhausted := false


func update(delta: float, moving: bool, running: bool, resting: bool) -> void:
	var max_end := 1.0 - fatigue * 0.5
	if running:
		endurance -= RUN_DRAIN * delta * (1.0 + fatigue * 0.6)
		fatigue += FATIGUE_FROM_RUN * delta
	elif resting:
		endurance += REGEN_REST * delta
		fatigue -= FATIGUE_RECOVERY_REST * delta
	elif moving:
		endurance += REGEN_WALK * delta * (1.0 - fatigue * 0.5)
	else:
		endurance += REGEN_IDLE * delta * (1.0 - fatigue * 0.5)
	endurance = clampf(endurance, 0.0, max_end)
	fatigue = clampf(fatigue, 0.0, 1.0)
	drowsiness = clampf(drowsiness + V01GameTime.game_hours(delta) * DROWSY_PER_GAME_HOUR * (0.0 if resting else 1.0), 0.0, 1.0)
	var ex := endurance < 0.08 or (exhausted and endurance < 0.25)
	if ex != exhausted:
		exhausted = ex
		exhausted_changed.emit(exhausted)


func can_run() -> bool:
	return not exhausted


func spend_attack() -> void:
	endurance = maxf(endurance - ATTACK_COST, 0.0)
	fatigue = minf(fatigue + 0.002, 1.0)


## Movement speed multiplier from tiredness.
func speed_factor() -> float:
	return lerpf(1.0, 0.75, fatigue) * (0.8 if exhausted else 1.0)
