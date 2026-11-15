class_name DayNight
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
## v0.5 first person: a real sky with clouds, sun, moon and stars, and distance fog to the horizon.
var first_person := false:
	set(v):
		first_person = v
		_apply_background()
var _sky_mat: ShaderMaterial
var _cloud_t := 0.0
var _sky_t := 0.0

# hour -> [zenith, horizon] for the first-person sky
const SKY_KEYS := [
	[0.0, Color("#070b14"), Color("#141b28")],
	[4.5, Color("#0b1220"), Color("#1f2636")],
	[6.0, Color("#3a4866"), Color("#d89a70")],
	[7.5, Color("#5a7ea8"), Color("#c8c4b8")],
	[13.0, Color("#5c8ac0"), Color("#b8c8d6")],
	[18.0, Color("#5a7aa0"), Color("#d0c0a0")],
	[20.5, Color("#2c3654"), Color("#c86e48")],
	[22.0, Color("#0a0f1c"), Color("#182030")],
	[24.0, Color("#070b14"), Color("#141b28")],
]

## 0 at day, 1 at night: read by zombie vision and lighting-dependent systems.
static var night := 0.0


func _ready() -> void:
	sun = get_node(sun_path) as DirectionalLight3D
	var we := get_node(environment_path) as WorldEnvironment
	env = we.environment


func _process(_delta: float) -> void:
	var h := GameTime.get_hour_f()
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in range(KEYS.size() - 1):
		if h >= KEYS[i][0] and h <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t: float = 0.0 if b[0] == a[0] else (h - a[0]) / (b[0] - a[0])
	# Overcast and rain: flatter, greyer light and a little haze.
	var rain := Climate.instance.rain if Climate.instance else 0.0
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
	_wet = move_toward(_wet, clampf(rain * 1.4, 0.0, 1.0), get_process_delta_time() * (0.05 if rain > _wet else 0.004) * maxf(GameTime.time_scale, 1.0))
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
	if first_person:
		if OS.has_feature("mobile") or OS.get_name() == "Android":
			_sky_t -= _delta
			if _sky_t <= 0.0:
				_sky_t = 12.0
				_update_sky(h, rain, mist, night_factor)
		else:
			_update_sky(h, rain, mist, night_factor)
	var want := night_factor > 0.6 and Climate.has_power()
	if want != _lamps_on:
		_lamps_on = want
		for l in get_tree().get_nodes_in_group("street_lamps"):
			(l as Light3D).light_energy = 6.0 if want else 0.0
		for c in get_tree().get_nodes_in_group("lamp_cones"):
			(c as Node3D).visible = want


static func night_factor_of(h: float) -> float:
	return maxf(1.0 - smoothstep(5.0, 6.5, h), smoothstep(20.0, 21.5, h))


func _apply_background() -> void:
	if env == null:
		return
	var is_mob := OS.has_feature("mobile") or OS.get_name() == "Android"
	if first_person:
		if _sky_mat == null:
			_sky_mat = ShaderMaterial.new()
			_sky_mat.shader = load("res://shaders/sky.gdshader")
			var nt := NoiseTexture2D.new()
			var fn := FastNoiseLite.new()
			fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			fn.frequency = 0.012
			fn.fractal_octaves = 2 if is_mob else 3
			nt.noise = fn
			nt.width = 128 if is_mob else 256
			nt.height = 128 if is_mob else 256
			nt.seamless = true
			_sky_mat.set_shader_parameter("cloud_noise", nt)
			var sky := Sky.new()
			sky.sky_material = _sky_mat
			sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL if is_mob else Sky.PROCESS_MODE_REALTIME
			sky.radiance_size = Sky.RADIANCE_SIZE_32 if is_mob else Sky.RADIANCE_SIZE_256
			env.sky = sky
		if is_mob:
			env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.background_mode = Environment.BG_SKY
		env.fog_sky_affect = 0.0
		_sky_t = 0.0
	else:
		env.background_mode = Environment.BG_COLOR
		env.fog_sky_affect = 1.0


func _update_sky(h: float, rain: float, mist: float, nf: float) -> void:
	var a: Array = SKY_KEYS[0]
	var b: Array = SKY_KEYS[1]
	for i in range(SKY_KEYS.size() - 1):
		if h >= SKY_KEYS[i][0] and h <= SKY_KEYS[i + 1][0]:
			a = SKY_KEYS[i]
			b = SKY_KEYS[i + 1]
			break
	var t: float = 0.0 if b[0] == a[0] else (h - a[0]) / (b[0] - a[0])
	var zen := (a[1] as Color).lerp(b[1], t)
	var hor := (a[2] as Color).lerp(b[2], t)
	var grey := Color("#5c6268").lerp(Color("#1a1d22"), nf)
	zen = zen.lerp(grey, rain * 0.85)
	hor = hor.lerp(grey.lightened(0.15), rain * 0.8).lerp(Color("#c8ccd0").lerp(Color("#30363e"), nf), mist * 0.6)
	_cloud_t += get_process_delta_time() * (1.0 + rain * 2.0) * maxf(GameTime.time_scale, 1.0)
	_sky_mat.set_shader_parameter("zenith_color", zen)
	_sky_mat.set_shader_parameter("horizon_color", hor)
	_sky_mat.set_shader_parameter("ground_color", hor.darkened(0.45))
	_sky_mat.set_shader_parameter("sun_color", sun.light_color)
	_sky_mat.set_shader_parameter("night", nf)
	_sky_mat.set_shader_parameter("cloud_cover", clampf(0.42 + rain * 0.55, 0.0, 0.97))
	_sky_mat.set_shader_parameter("cloud_light", Color("#f0ece4").lerp(Color("#8a9096"), rain).lerp(Color("#2a3040"), nf))
	_sky_mat.set_shader_parameter("cloud_dark", Color("#9098a4").lerp(Color("#4a5058"), rain).lerp(Color("#10141c"), nf))
	_sky_mat.set_shader_parameter("cloud_time", _cloud_t)
	# Distance fog that melts the far forest into the horizon.
	env.fog_enabled = true
	env.fog_light_color = hor * 0.92
	env.fog_light_energy = 1.0
	env.fog_density = 0.0022 + 0.0045 * rain + 0.0028 * mist + 0.0008 * nf
