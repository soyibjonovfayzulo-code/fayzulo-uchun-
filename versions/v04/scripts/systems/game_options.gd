class_name V04GameOptions
extends RefCounted
## Player options persisted in user://options.cfg: volume, graphics quality preset, pixel size, outlines,
## fullscreen and vsync. Applied to the window once and to every world environment that loads.

const PATH := "user://options.cfg"
const QUALITY_NAMES := ["Низкое", "Среднее", "Высокое", "Ультра"]
const PIXEL_NAMES := ["Авто", "Чёткая картинка", "Пиксель ×2", "Крупный пиксель ×3"]
const UI_SCALES := [0.75, 0.9, 1.0, 1.15, 1.3, 1.5]
const UI_SCALE_NAMES := ["75%", "90%", "100%", "115%", "130%", "150%"]

static var volume := 0.8
## 0 low .. 3 ultra
static var quality := 2
## 0 auto, 1 none, 2, 3
static var pixel_scale := 0
static var outline := true
static var fullscreen := false
static var vsync := true
## Interface scale (HUD, menus, windows).
static var ui_scale := 1.0
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		volume = float(cf.get_value("audio", "volume", volume))
		quality = int(cf.get_value("video", "quality", quality))
		pixel_scale = int(cf.get_value("video", "pixel_scale", pixel_scale))
		outline = bool(cf.get_value("video", "outline", outline))
		fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))
		vsync = bool(cf.get_value("video", "vsync", vsync))
		ui_scale = float(cf.get_value("video", "ui_scale", ui_scale))
	_apply_audio()
	apply_window()


static func save() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("audio", "volume", volume)
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "pixel_scale", pixel_scale)
	cf.set_value("video", "outline", outline)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("video", "vsync", vsync)
	cf.set_value("video", "ui_scale", ui_scale)
	cf.save(PATH)


static func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply_audio()
	save()


static func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


static func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED
			and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


## Render scale for the pixel-art SubViewport (stretch_shrink).
static func shrink_for(height: float) -> int:
	match pixel_scale:
		1:
			return 1
		2:
			return 2
		3:
			return 3
	return 3 if height >= 1400.0 else 2


## Graphics preset on a world environment and its sun.
static func apply_environment(env: Environment, sun: DirectionalLight3D) -> void:
	if env == null:
		return
	env.ssao_enabled = quality >= 1
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = false  # noisy without TAA in the pixel pipeline
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.7
	env.ssr_enabled = quality >= 2
	env.ssr_max_steps = 48 if quality >= 3 else 24
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.4
	env.glow_enabled = quality >= 1
	env.glow_intensity = 0.55 if quality >= 3 else 0.45
	env.glow_strength = 0.9
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	if sun:
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 80.0 if quality <= 1 else 120.0
		sun.light_angular_distance = 0.6 if quality >= 3 else 0.0
	RenderingServer.directional_shadow_atlas_set_size(2048 if quality <= 1 else 4096, true)


## The stylisation quad in front of a camera (outlines + grading); returns it so callers can toggle it.
static func add_post(camera: Camera3D) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	q.name = "PostStylize"
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	qm.flip_faces = true
	q.mesh = qm
	var m := ShaderMaterial.new()
	m.shader = load("res://versions/v04/shaders/post_stylize.gdshader")
	m.render_priority = -100
	q.material_override = m
	q.extra_cull_margin = 16384.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = Vector3(0, 0, -2.0)
	q.visible = outline
	camera.add_child(q)
	return q


static func ui_scale_index() -> int:
	var best := 2
	for i in UI_SCALES.size():
		if absf(float(UI_SCALES[i]) - ui_scale) < absf(float(UI_SCALES[best]) - ui_scale):
			best = i
	return best
