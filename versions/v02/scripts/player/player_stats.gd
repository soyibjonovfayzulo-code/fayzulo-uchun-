class_name V02PlayerStats
extends Node
## Short-term endurance (stamina), fatigue from exertion, drowsiness, hunger and thirst.
## All values are 0..1 (hunger/thirst: 0 = sated, 1 = starving). Rates are per real second,
## except drowsiness/hunger/thirst which advance per game hour.

signal exhausted_changed(exhausted: bool)

const RUN_DRAIN := 0.085
const REGEN_IDLE := 0.07
const REGEN_WALK := 0.035
const REGEN_REST := 0.12
const FATIGUE_FROM_RUN := 0.004
const FATIGUE_RECOVERY_REST := 0.006
const DROWSY_PER_GAME_HOUR := 1.0 / 17.0
const HUNGER_PER_GAME_HOUR := 1.0 / 30.0
const THIRST_PER_GAME_HOUR := 1.0 / 20.0

var endurance := 1.0
var fatigue := 0.0
var drowsiness := 0.15
var hunger := 0.15
var thirst := 0.12
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
	var hours := V02GameTime.game_hours(delta)
	drowsiness = clampf(drowsiness + hours * DROWSY_PER_GAME_HOUR * (0.0 if resting else 1.0), 0.0, 1.0)
	hunger = clampf(hunger + hours * HUNGER_PER_GAME_HOUR * (1.3 if running else 1.0), 0.0, 1.0)
	thirst = clampf(thirst + hours * THIRST_PER_GAME_HOUR * (1.6 if running else 1.0), 0.0, 1.0)
	var ex := endurance < 0.08 or (exhausted and endurance < 0.25)
	if ex != exhausted:
		exhausted = ex
		exhausted_changed.emit(exhausted)


func can_run() -> bool:
	return not exhausted


func spend_attack(cost := 0.035) -> void:
	endurance = maxf(endurance - cost, 0.0)
	fatigue = minf(fatigue + cost * 0.06, 1.0)


## Movement speed multiplier from tiredness.
func speed_factor() -> float:
	return lerpf(1.0, 0.75, fatigue) * (0.8 if exhausted else 1.0)


## Swing speed / accuracy multiplier: tired survivors fight worse.
func combat_factor() -> float:
	return lerpf(1.0, 0.7, fatigue) * (0.75 if exhausted else 1.0) * lerpf(1.0, 0.85, maxf(hunger - 0.6, 0.0) * 2.5)
