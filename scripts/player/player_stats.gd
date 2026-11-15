class_name PlayerStats
extends Node
## Short-term endurance (stamina), fatigue from exertion, drowsiness, hunger, thirst, panic and food
## poisoning. All values are 0..1 (hunger/thirst: 0 = sated, 1 = starving). Endurance, fatigue and panic
## change per real second; drowsiness, hunger, thirst and poisoning per game hour.

signal exhausted_changed(exhausted: bool)

const RUN_DRAIN := 0.085
const REGEN_IDLE := 0.07
const REGEN_WALK := 0.035
const REGEN_REST := 0.12
const FATIGUE_FROM_RUN := 0.004
const FATIGUE_RECOVERY_REST := 0.006
const DROWSY_PER_GAME_HOUR := 1.0 / 18.0
## A full night in a proper bed (~7 h) clears drowsiness.
const SLEEP_RECOVERY_PER_HOUR := 1.0 / 6.5
const HUNGER_PER_GAME_HOUR := 1.0 / 30.0
const THIRST_PER_GAME_HOUR := 1.0 / 20.0
const PANIC_DECAY := 0.045
const POISON_DECAY_PER_HOUR := 0.07

var endurance := 1.0
var fatigue := 0.0
var drowsiness := 0.15
var hunger := 0.15
var thirst := 0.12
var panic := 0.0
## Food poisoning severity 0..1 (rotten or stale food).
var poison := 0.0
var exhausted := false
## Set by the body temperature / infection: multiplies endurance regeneration.
var regen_mult := 1.0
## Traits / skills.
var hunger_mult := 1.0
var panic_mult := 1.0
var run_drain_mult := 1.0
## Smokers crave a cigarette: 0..1, reset by smoking.
var craving := 0.0


func update(delta: float, moving: bool, running: bool, resting: bool) -> void:
	var max_end := 1.0 - fatigue * 0.5
	if running:
		endurance -= RUN_DRAIN * delta * (1.0 + fatigue * 0.6) * run_drain_mult
		fatigue += FATIGUE_FROM_RUN * delta
	elif resting:
		endurance += REGEN_REST * delta * regen_mult
		fatigue -= FATIGUE_RECOVERY_REST * delta
	elif moving:
		endurance += REGEN_WALK * delta * (1.0 - fatigue * 0.5) * regen_mult
	else:
		endurance += REGEN_IDLE * delta * (1.0 - fatigue * 0.5) * regen_mult
	endurance = clampf(endurance, 0.0, max_end)
	fatigue = clampf(fatigue, 0.0, 1.0)
	var hours := GameTime.game_hours(delta)
	drowsiness = clampf(drowsiness + hours * DROWSY_PER_GAME_HOUR * (0.0 if resting else 1.0), 0.0, 1.0)
	hunger = clampf(hunger + hours * HUNGER_PER_GAME_HOUR * (1.3 if running else 1.0) * hunger_mult, 0.0, 1.0)
	if Profession.has_trait("smoker"):
		craving = minf(craving + hours / 10.0, 1.0)
		if craving > 0.6:
			panic = maxf(panic, 0.2 * (craving - 0.6) / 0.4)
	thirst = clampf(thirst + hours * THIRST_PER_GAME_HOUR * (1.6 if running else 1.0) * (1.0 + poison), 0.0, 1.0)
	poison = maxf(poison - hours * POISON_DECAY_PER_HOUR, 0.0)
	panic = maxf(panic - PANIC_DECAY * delta, 0.0)
	var ex := endurance < 0.08 or (exhausted and endurance < 0.25)
	if ex != exhausted:
		exhausted = ex
		exhausted_changed.emit(exhausted)


## While asleep: the night passes at high speed, the body needs less food and water.
func update_sleep(hours: float, quality: float) -> void:
	drowsiness = clampf(drowsiness - hours * SLEEP_RECOVERY_PER_HOUR * quality, 0.0, 1.0)
	fatigue = clampf(fatigue - hours * 0.12 * quality, 0.0, 1.0)
	endurance = minf(endurance + hours * 0.5, 1.0 - fatigue * 0.5)
	hunger = clampf(hunger + hours * HUNGER_PER_GAME_HOUR * 0.5, 0.0, 1.0)
	thirst = clampf(thirst + hours * THIRST_PER_GAME_HOUR * 0.5, 0.0, 1.0)
	poison = maxf(poison - hours * POISON_DECAY_PER_HOUR, 0.0)
	panic = 0.0


func add_panic(v: float) -> void:
	panic = clampf(panic + v * panic_mult, 0.0, 1.0)


func can_run() -> bool:
	return not exhausted


func spend_attack(cost := 0.035) -> void:
	endurance = maxf(endurance - cost, 0.0)
	fatigue = minf(fatigue + cost * 0.06, 1.0)


## Movement speed multiplier from tiredness and sleepiness.
func speed_factor() -> float:
	return lerpf(1.0, 0.75, fatigue) * (0.8 if exhausted else 1.0) * (0.85 if drowsiness > 0.85 else 1.0)


## Swing speed / accuracy multiplier: tired, sleepy, hungry or scared survivors fight worse.
func combat_factor() -> float:
	return lerpf(1.0, 0.7, fatigue) * (0.75 if exhausted else 1.0) * lerpf(1.0, 0.85, maxf(hunger - 0.6, 0.0) * 2.5) \
		* lerpf(1.0, 0.85, maxf(drowsiness - 0.7, 0.0) / 0.3) * lerpf(1.0, 0.8, panic)


func save_state() -> Dictionary:
	return {"end": endurance, "fat": fatigue, "drw": drowsiness, "hun": hunger, "thi": thirst, "pan": panic, "poi": poison,
		"crv": craving}


func load_state(d: Dictionary) -> void:
	endurance = float(d.get("end", 1.0))
	fatigue = float(d.get("fat", 0.0))
	drowsiness = float(d.get("drw", 0.15))
	hunger = float(d.get("hun", 0.15))
	thirst = float(d.get("thi", 0.12))
	panic = float(d.get("pan", 0.0))
	poison = float(d.get("poi", 0.0))
	craving = float(d.get("crv", 0.0))
