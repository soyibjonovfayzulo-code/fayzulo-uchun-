class_name V04DayNight
extends Node
## Drives sun/moon, ambient light and street lamps from GameTime. Muted, natural palette.

@export var sun_path: NodePath
@export var environment_path: NodePath

var sun: DirectionalLight3D
var env: Environment

# hour -> [sun colour, sun energy, ambient colour, ambient energy]
const KEYS := [
	[0.0, Color("#5a6a90"), 0.2, Color("#2a3448"), 0.5],
	[4.5, Color("#5a6a90"), 0.2, Color("#2a3448"), 0.5],
	[6.0, Color("#e0a070"), 0.55, Color("#605a60"), 0.55],
	[8.0, Color("#f0dcc0"), 1.05, Color("#8a8c90"), 0.75],
	[13.0, Color("#fff0dc"), 1.25, Color("#9a9ca0"), 0.8],
	[18.0, Color("#f0c890"), 0.95, Color("#8a8480"), 0.7],
	[20.5, Color("#c87050"), 0.4, Color("#504850"), 0.5],
	[22.0, Color("#5a6a90"), 0.2, Color("#2a3448"), 0.5],
	[24.0, Color("#5a6a90"), 0.2, Color("#2a3448"), 0.5],
]

var _lamps_on := false
var _wet := 0.0

## 0 at day, 1 at night: read by zombie vision and lighting-dependent systems.
static var night := 0.0


func _ready() -> void:
	sun = get_node(sun_path) as DirectionalLight3D
	var we := get_node(environment_path) as WorldEnvironment
	env = we.environment


func _process(_delta: float) -> void:
	var h := V04GameTime.get_hour_f()
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in range(KEYS.size() - 1):
		if h >= KEYS[i][0] and h <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t: float = 0.0 if b[0] == a[0] else (h - a[0]) / (b[0] - a[0])
	# Overcast and rain: flatter, greyer light and a little haze.
	var rain := V04Climate.instance.rain if V04Climate.instance else 0.0
	sun.light_color = (a[1] as Color).lerp(b[1], t).lerp(Color("#a8b0b8"), rain * 0.6)
	sun.light_energy = lerpf(a[2], b[2], t) * (1.0 - rain * 0.55)
	env.ambient_light_color = (a[3] as Color).lerp(b[3], t).lerp(Color("#707880"), rain * 0.4)
	env.ambient_light_energy = lerpf(a[4], b[4], t) * (1.0 - rain * 0.15)
	# Morning mist lying low over the town, light haze at night, rain haze.
	var mist := smoothstep(4.0, 5.6, h) * (1.0 - smoothstep(7.4, 9.6, h))
	var haze := mist * 0.9 + night_factor_of(h) * 0.25 + rain
	env.fog_enabled = haze > 0.02
	env.fog_light_color = env.ambient_light_color.lerp(Color("#c8ccd0"), mist * 0.5) * 0.8
	env.fog_light_energy = env.ambient_light_energy
	env.fog_density = 0.0045 * rain + 0.0012 * mist + 0.0006 * night_factor_of(h)
	env.fog_height = 0.8
	env.fog_height_density = mist * 0.12
	var gust := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0007) * sin(Time.get_ticks_msec() * 0.00031)
	RenderingServer.global_shader_parameter_set("wind", clampf(0.25 + gust * 0.35 + rain * 0.8, 0.0, 1.5))
	env.adjustment_saturation = 0.82 - rain * 0.18
	# Ground soaks up quickly and dries slowly after the rain.
	_wet = move_toward(_wet, clampf(rain * 1.4, 0.0, 1.0), get_process_delta_time() * (0.05 if rain > _wet else 0.004) * maxf(V04GameTime.time_scale, 1.0))
	RenderingServer.global_shader_parameter_set("rain_wet", _wet)
	# Sun arc (daytime) / moon (night): keep light from a high angle so iso shadows stay short.
	var day := clampf((h - 5.0) / 16.0, 0.0, 1.0)
	var is_night := h < 5.5 or h > 21.0
	var az := lerpf(-70.0, 70.0, day) if not is_night else 30.0
	var el := -lerpf(28.0, 62.0, sin(day * PI)) if not is_night else -55.0
	sun.rotation_degrees = Vector3(el, az - 30.0, 0)
	var night_factor := maxf(1.0 - smoothstep(5.0, 6.5, h), smoothstep(20.0, 21.5, h))
	RenderingServer.global_shader_parameter_set("night_factor", night_factor)
	night = night_factor
	var want := night_factor > 0.6 and V04Climate.has_power()
	if want != _lamps_on:
		_lamps_on = want
		for l in get_tree().get_nodes_in_group("street_lamps"):
			(l as Light3D).light_energy = 6.0 if want else 0.0
		for c in get_tree().get_nodes_in_group("lamp_cones"):
			(c as Node3D).visible = want


static func night_factor_of(h: float) -> float:
	return maxf(1.0 - smoothstep(5.0, 6.5, h), smoothstep(20.0, 21.5, h))
