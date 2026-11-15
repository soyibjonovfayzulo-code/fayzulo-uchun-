class_name V04BodyTemperature
extends Node
## Core body temperature and wetness. Air temperature (Climate), clothing warmth, activity, rain and
## campfires decide whether the survivor slowly chills or warms up; infection and festering add fever.

const NORMAL := 36.6
const RATE_PER_HOUR := 0.7
const FIRE_RADIUS := 3.6

var temp := NORMAL
## 0..1: soaked clothes insulate badly.
var wetness := 0.0
## Last computed "felt" air temperature, for the health panel.
var felt := 20.0
var near_fire := false


func update(delta: float, player: V04Player) -> void:
	var hours := V04GameTime.game_hours(delta)
	var c := V04Climate.instance
	var air := c.temp_at(player.global_position) if c else 18.0
	var indoors := V04District.instance != null and V04District.surface_at(player.global_position) == "floor"
	near_fire = V04Campfire.heat_at(player.global_position, FIRE_RADIUS) > 0.0
	if near_fire:
		air = maxf(air, 26.0)
	# Wetness: rain soaks you outside, buildings and fire dry you.
	var rain := c.rain if c else 0.0
	if not indoors and rain > 0.05:
		wetness = minf(wetness + rain * 1.6 * hours, 1.0)
	else:
		wetness = maxf(wetness - (2.5 if near_fire else (0.5 if indoors else 0.25)) * hours, 0.0)
	var body: V04ItemStack = player.inventory.equipped["body"]
	var insulation := 0.2 + (body.item.warmth if body else 0.0)
	insulation *= 1.0 - wetness * 0.6
	var activity := 0.0
	if player.running:
		activity = 1.0
	elif player.velocity.length() > 0.5:
		activity = 0.35
	elif player.is_sleeping():
		activity = -0.25
	felt = air + insulation * 14.0 + activity * 7.0
	var target := NORMAL
	if felt < 19.0:
		target = NORMAL - (19.0 - felt) * 0.13
	elif felt > 33.0:
		target = NORMAL + minf((felt - 33.0) * 0.08, 1.0)
	target += player.wounds.fever()
	temp = move_toward(temp, target, RATE_PER_HOUR * hours)
	# Effects.
	var mult := 1.0
	if temp < 35.4:
		mult = 0.7
	if temp < 34.8:
		player.health.take_damage(3.0 * hours, null, "Переохлаждение")
		mult = 0.5
	if temp > 38.0:
		mult = minf(mult, 0.75)
	player.stats.regen_mult = mult * (0.85 if player.wounds.infection_stage() >= 1 else 1.0)


## "Прохладно" / "Холодно"... for moodles; "" when comfortable.
func state_name() -> String:
	if temp < 34.8:
		return "Переохлаждение"
	if temp < 35.4:
		return "Холодно"
	if temp < 36.1:
		return "Прохладно"
	if temp > 38.5:
		return "Сильный жар"
	if temp > 37.4:
		return "Жарко" if not get_parent().get("wounds") or (get_parent().get("wounds") as V04Wounds).fever() <= 0.0 else "Температура"
	return ""


func save_state() -> Dictionary:
	return {"t": temp, "w": wetness}


func load_state(d: Dictionary) -> void:
	temp = float(d.get("t", NORMAL))
	wetness = float(d.get("w", 0.0))
