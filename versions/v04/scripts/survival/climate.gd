class_name V04Climate
extends Node
## Weather and utilities of the district: September air temperature (day/night cycle, slowly getting
## colder), rain spells from a deterministic schedule, and the moment the power, gas and tap water die
## (Settings.utilities_off_day). Also ages perishable food and lights a few apartment windows at night.

signal power_changed(on: bool)
signal rain_changed(raining: bool)

const TICK_HOURS := 0.25
const ROOM_LIGHTS := 16

static var instance: V04Climate

## 0..1 current rain intensity (smoothed).
var rain := 0.0
## Hours since the start of the game at which the utilities go off.
var power_off_at := 60.0
var water_off_at := 62.0
var gas_off_at := 66.0
var _power := true
var _raining := false
var _spells: Array = []  # [start_hour, end_hour, intensity] in hours since start
var _tick := 0.0
var _room_lights: Array[OmniLight3D] = []


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = V04Settings.world_seed
	var day := maxi(V04Settings.utilities_off_day, 1)
	var off_clock := rng.randf_range(9.0, 20.0)
	power_off_at = (day - 1) * 24.0 + off_clock - V04GameTime.START_HOUR
	water_off_at = power_off_at + rng.randf_range(1.0, 6.0)
	gas_off_at = power_off_at + rng.randf_range(4.0, 12.0)
	if V04Settings.utilities_off_day <= 0:
		power_off_at = -1.0
		water_off_at = -1.0
		gas_off_at = -1.0
	_build_schedule(rng)
	_power = power_on()
	_place_room_lights.call_deferred()


## Rain spells for 30 days: the first one on the afternoon of day 1 (the series opens in drizzle).
func _build_schedule(rng: RandomNumberGenerator) -> void:
	_spells.clear()
	if not V04Settings.weather:
		return
	_spells.append([15.5 - V04GameTime.START_HOUR, 17.5 - V04GameTime.START_HOUR, 0.55])
	for d in range(1, 30):
		var n := rng.randi_range(0, 2)
		for i in n:
			var start := d * 24.0 + rng.randf_range(0.0, 22.0) - V04GameTime.START_HOUR
			var dur := rng.randf_range(0.8, 5.0)
			_spells.append([start, start + dur, rng.randf_range(0.35, 1.0)])


func hours_since_start() -> float:
	return V04GameTime.total_minutes / 60.0 - V04GameTime.START_HOUR


func power_on() -> bool:
	return power_off_at < 0.0 or hours_since_start() < power_off_at


func water_on() -> bool:
	return water_off_at < 0.0 or hours_since_start() < water_off_at


func gas_on() -> bool:
	return gas_off_at < 0.0 or hours_since_start() < gas_off_at


static func has_power() -> bool:
	return instance == null or instance.power_on()


static func has_water() -> bool:
	return instance == null or instance.water_on()


static func has_gas() -> bool:
	return instance == null or instance.gas_on()


## Target rain intensity from the schedule at the current time.
func scheduled_rain() -> float:
	var h := hours_since_start()
	for s in _spells:
		if h >= s[0] and h <= s[1]:
			# Soft start and end.
			var edge: float = minf(h - s[0], s[1] - h)
			return float(s[2]) * clampf(edge / 0.3, 0.2, 1.0)
	return 0.0


## Outside air, degrees C. September in a Russian town: ~+16 by day, ~+5 before dawn, colder each day.
func outside_temp() -> float:
	var h := V04GameTime.get_hour_f()
	var day := float(V04GameTime.get_day() - V04GameTime.START_DAY)
	var mean := 11.0 - day * 0.35
	var t := mean + 5.5 * cos((h - 15.0) / 24.0 * TAU)
	return t - rain * 3.0


## Air temperature at a point: buildings keep some warmth (no heating yet in September).
func temp_at(p: Vector3) -> float:
	var out := outside_temp()
	if V04District.instance and V04District.surface_at(p) == "floor":
		return lerpf(out, 19.0, 0.65)
	return out


## Forces the weather now (tests, debugging): replaces any spell in progress.
func set_rain_now(v: float, hours := 3.0) -> void:
	var h := hours_since_start()
	_spells = _spells.filter(func(sp: Array) -> bool: return not (h >= sp[0] and h <= sp[1]))
	rain = v
	if v > 0.0:
		_spells.append([h - 0.3, h + hours, v])


func _process(delta: float) -> void:
	var target := scheduled_rain()
	rain = move_toward(rain, target, delta * 0.15 * maxf(V04GameTime.time_scale, 1.0))
	var raining := rain > 0.05
	if raining != _raining:
		_raining = raining
		rain_changed.emit(raining)
		if raining:
			V04Events.show_toast("Начался дождь.")
	var p := power_on()
	if p != _power:
		_power = p
		power_changed.emit(p)
		if not p:
			_on_power_lost()
	var night := V04DayNight.night > 0.5
	for l in _room_lights:
		if is_instance_valid(l):
			l.light_energy = (1.3 + 0.08 * sin(Time.get_ticks_msec() * 0.003 + l.position.x)) if (night and _power) else 0.0
	_tick += V04GameTime.game_hours(delta)
	if _tick >= TICK_HOURS:
		V04Spoilage.tick(get_tree(), _tick, _power)
		_tick = 0.0


func _on_power_lost() -> void:
	V04Sfx.play_ui("power_down", -4.0)
	V04Events.show_toast("Свет погас во всём районе. Электричества больше нет.")
	for tv in get_tree().get_nodes_in_group("tvs"):
		if tv.get("tv_on"):
			tv.call("_set_tv", false)


## A handful of lit apartments: warm light in the windows at night until the power dies.
func _place_room_lights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = V04Settings.world_seed + 7
	var rooms: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		var bb := b as V04Building
		for r in bb.room_points:
			if r["type"] in ["living", "kitchen", "bedroom"] and r["level"] <= 4:
				rooms.append([bb, r])
	if rooms.is_empty():
		return
	for i in ROOM_LIGHTS:
		var e: Array = rooms[rng.randi() % rooms.size()]
		var bb: V04Building = e[0]
		var r: Dictionary = e[1]
		var lvl: int = r["level"]
		if lvl >= bb.levels.size():
			continue
		var l := OmniLight3D.new()
		l.omni_range = 4.6
		l.omni_attenuation = 1.4
		l.light_color = Color("#ffc888") if rng.randf() < 0.7 else Color("#d8e4ff")
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.add_to_group("room_lights")
		(bb.levels[lvl] as Node3D).add_child(l)
		l.global_position = bb.to_global(r["pos"]) + Vector3(0, 2.2, 0)
		_room_lights.append(l)


func save_state() -> Dictionary:
	return {"rain": rain}


func load_state(d: Dictionary) -> void:
	rain = float(d.get("rain", 0.0))
	_power = power_on()
	_raining = rain > 0.05
