extends Control
## Main menu. Behind it a slideshow of staged, HUD-free shots of the town (assets/ui/gallery) drifts with
## a slow Ken Burns move and cross-fades, with ash in the air and rain over the rainy shots, under a cold
## ambient theme. Buttons: continue, new game, tutorial, game versions (every frozen build stays playable),
## gallery, settings (graphics, pixel size, interface scale, audio), about, quit.
## Command line: `-- --version=<id>` starts a version directly; test flags start the development build.

const REGISTRY := "res://launcher/versions.json"
const NEW_GAME := "res://scenes/main/new_game.tscn"
const MAIN := "res://scenes/main/main.tscn"
const GALLERY := "res://assets/ui/gallery/"
const TEST_FLAGS := ["--autotest", "--tour", "--poses", "--continue", "--newgame-shot", "--loadcheck", "--m78", "--v04", "--gallery", "--fps", "--fpvm", "--fpgallery", "--probe-admin", "--profile-interactions", "--test-hot-update"]
const SHOTS := [
	["11_fp_rain_bat", "От первого лица: ливень, бита и трое на дороге.", true],
	["01_street_rain_night", "Ул. Строителей, ночь. Фонари ещё горят.", true],
	["12_fp_night_torch", "Фонарик выхватывает того, кто стоит под фонарём.", false],
	["02_village_sunset", "Частный сектор на закате.", false],
	["07_horde_courtyard", "Двор дома 10. Их стало слишком много.", false],
	["03_checkpoint_night", "Блокпост «Карантин» на ул. Ленина.", false],
	["05_izba_stove", "Изба на Садовой. Печь ещё тёплая.", false],
	["09_helicopter", "Вертолёт над городом. Он не за вами.", false],
	["08_night_drive", "Ночная дорога под дождём.", true],
	["04_burned_bus_dusk", "Сгоревший автобус. Эвакуации не будет.", false],
	["13_fp_forest_sunset", "Лес за городом на закате. Дальше — только деревья.", false],
	["14_fp_driving_dusk", "За рулём охристого седана. В свете фар — двое.", false],
	["15_fp_mist_pistol", "Утро, туман во дворе. Макаров на прицеле.", false],
	["06_morning_mist", "Утренний туман над дворами.", false],
	["10_gas_station_dusk", "АЗС №17 в сумерках.", false],
]
const NEWS := "ЧТО НОВОГО В v0.5  ·  ВИД ОТ ПЕРВОГО ЛИЦА: руки и оружие в кадре, прицельная стрельба, выстрел в голову, " \
	+ "салон машины с живым спидометром, небо с облаками и звёздами, лес до горизонта  ·  V — изометрия в любой момент  ·  " \
	+ "v0.4: город стал в 5 раз больше: частный сектор, ул. Ленина, АЗС, полиция, блокпост, лес  ·  " \
	+ "машины с физикой подвески, бензином и угоном  ·  8 профессий, 12 черт, 8 навыков  ·  баррикады, русская печь, " \
	+ "вертолёт  ·  обучение для новичков  ·  новые анимации: шаг, бег, хват двумя руками, ползуны  ·  " \
	+ "трава, лужи с отражениями, туман, конусы света фонарей  ·  админка F9  ·  "

var versions: Array = []
var _bg_a: TextureRect
var _bg_b: TextureRect
var _shot_i := 0
var _shot_t := 0.0
var _caption: Label
var _rain: CPUParticles2D
var _main: VBoxContainer
var _buttons: Array[Button] = []
var _panel_host: Control
var _panels := {}
var _ver_title: Label
var _ver_sub: Label
var _ver_badge: Label
var _ver_desc: Label
var _ver_img: TextureRect
var _ver_selected := 0
var _ver_buttons: Array[Button] = []
var _ticker: Label
var _viewer: Control
var _viewer_img: TextureRect
var _viewer_cap: Label
var _viewer_i := 0
var _music: AudioStreamPlayer
var _textures := {}


func _ready() -> void:
	get_tree().paused = false
	GameTime.time_scale = 1.0
	versions = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--version="):
			_launch(_index_of(a.trim_prefix("--version=")))
			return
		if a in TEST_FLAGS or a.begins_with("--shot="):
			_launch(_index_of("dev"))
			return
	GameOptions.ensure_loaded()
	theme = UiTheme.theme()
	Sfx.stop_ambient()
	_build_background()
	_build_ui()
	_build_viewer()
	UiTheme.fit(self)
	_music = AudioStreamPlayer.new()
	_music.stream = Sfx.get_stream("menu_theme")
	_music.volume_db = -40.0
	_music.finished.connect(_music.play)
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", -9.0, 3.0)
	_intro()
	if "--menu-shot" in args:
		await get_tree().create_timer(3.5).timeout
		_save_shot("menu")
		_show("versions")
		_select_version(0)
		for i in 30:
			await get_tree().process_frame
		_save_shot("menu_versions")
		_show("gallery")
		for i in 30:
			await get_tree().process_frame
		_save_shot("menu_gallery")
		_show("settings")
		for i in 30:
			await get_tree().process_frame
		_save_shot("menu_settings")
		_open_viewer(3)
		for i in 30:
			await get_tree().process_frame
		_save_shot("menu_viewer")
		get_tree().quit()


func _save_shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/screens/%s.png" % n))


func _index_of(id: String) -> int:
	for i in versions.size():
		if versions[i]["id"] == id:
			return i
	return versions.size() - 1


func _leave(scene: String) -> void:
	if _music:
		var tw := create_tween()
		tw.tween_property(_music, "volume_db", -40.0, 0.5)
	get_tree().change_scene_to_file.call_deferred(scene)


func _launch(i: int) -> void:
	_leave(versions[i]["scene"])


func _tex(name: String) -> Texture2D:
	if not _textures.has(name):
		var p := GALLERY + name + ".png"
		_textures[name] = load(p) if ResourceLoader.exists(p) else load("res://assets/ui/menu_bg.png")
	return _textures[name]


# ------------------------------------------------------------------------------------------------ background
func _build_background() -> void:
	var base := ColorRect.new()
	base.color = Color(0.03, 0.03, 0.03)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	_bg_a = _bg_layer()
	_bg_b = _bg_layer()
	_bg_a.texture = _tex(SHOTS[0][0])
	_bg_b.modulate.a = 0.0
	# Ash drifting through the air.
	var ash := CPUParticles2D.new()
	ash.amount = 70
	ash.lifetime = 14.0
	ash.preprocess = 14.0
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(1100, 50)
	ash.position = Vector2(800, -40)
	ash.direction = Vector2(0.3, 1)
	ash.spread = 25.0
	ash.gravity = Vector2(6, 18)
	ash.initial_velocity_min = 10.0
	ash.initial_velocity_max = 30.0
	ash.scale_amount_min = 1.0
	ash.scale_amount_max = 2.6
	ash.color = Color(0.85, 0.82, 0.75, 0.35)
	add_child(ash)
	_rain = CPUParticles2D.new()
	_rain.amount = 300
	_rain.lifetime = 0.7
	_rain.preprocess = 1.0
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(1200, 10)
	_rain.position = Vector2(800, -30)
	_rain.direction = Vector2(0.18, 1)
	_rain.spread = 2.0
	_rain.initial_velocity_min = 1300.0
	_rain.initial_velocity_max = 1600.0
	_rain.scale_amount_min = 1.0
	_rain.scale_amount_max = 1.0
	var rimg := Image.create(1, 18, false, Image.FORMAT_RGBA8)
	for y in 18:
		rimg.set_pixel(0, y, Color(0.8, 0.85, 0.92, 0.2 * float(y) / 17.0))
	_rain.texture = ImageTexture.create_from_image(rimg)
	_rain.emitting = SHOTS[0][2]
	add_child(_rain)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.material = _overlay_material()
	add_child(shade)
	_caption = Label.new()
	_caption.anchor_left = 1.0
	_caption.anchor_right = 1.0
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_left = -700
	_caption.offset_right = -32
	_caption.offset_top = -84
	_caption.offset_bottom = -58
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_color", Color(0.88, 0.85, 0.77, 0.88))
	_caption.text = SHOTS[0][1]
	add_child(_caption)


func _bg_layer() -> TextureRect:
	var r := TextureRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _process(delta: float) -> void:
	_shot_t += delta
	# Side panels keep clear of the logo column at large interface scales.
	if _panel_host:
		_panel_host.offset_left = -clampf(size.x - 510.0, 520.0, 680.0)
	# Ken Burns: slow push-in with a drift, per shot.
	var k := clampf(_shot_t / 9.0, 0.0, 1.0)
	var dir := 1.0 if _shot_i % 2 == 0 else -1.0
	for r in [_bg_a, _bg_b]:
		var rr: TextureRect = r
		rr.pivot_offset = rr.size * Vector2(0.5 + 0.12 * dir, 0.55)
	_bg_a.scale = Vector2.ONE * lerpf(1.04, 1.13, k)
	if _shot_t > 8.0 and _bg_b.modulate.a == 0.0:
		_next_shot()
	if _ticker:
		_ticker.position.x -= delta * 60.0
		if _ticker.position.x < -_ticker.size.x * 0.5:
			_ticker.position.x = 0.0


func _next_shot() -> void:
	_shot_i = (_shot_i + 1) % SHOTS.size()
	_bg_b.texture = _tex(SHOTS[_shot_i][0])
	_bg_b.scale = Vector2.ONE * 1.04
	var tw := create_tween()
	tw.tween_property(_bg_b, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_caption, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		_bg_a.texture = _bg_b.texture
		_bg_a.scale = _bg_b.scale
		_bg_b.modulate.a = 0.0
		_shot_t = 0.0
		_caption.text = SHOTS[_shot_i][1]
		_rain.emitting = SHOTS[_shot_i][2])
	tw.tween_property(_caption, "modulate:a", 1.0, 0.8)


func _overlay_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float time_scale = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float left = smoothstep(0.62, 0.0, uv.x) * 0.78;
	float bottom = smoothstep(0.62, 1.0, uv.y) * 0.55;
	float top = smoothstep(0.22, 0.0, uv.y) * 0.35;
	vec2 d = uv - 0.5;
	float vig = smoothstep(0.35, 0.85, length(d * vec2(1.25, 1.0))) * 0.55;
	float bars = step(uv.y, 0.035) + step(0.965, uv.y);
	float a = clamp(left + bottom + top + vig, 0.0, 0.93);
	float grain = (hash(uv * 900.0 + vec2(TIME * 31.0, TIME * 17.0)) - 0.5) * 0.06;
	COLOR = vec4(vec3(0.015 + grain), max(a, bars));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


# ------------------------------------------------------------------------------------------------ UI
func _build_ui() -> void:
	_main = VBoxContainer.new()
	_main.position = Vector2(48, 26)
	_main.add_theme_constant_override("separation", 4)
	add_child(_main)
	var kicker := _label(_main, "ПОСТАПОКАЛИПСИС · ИЗОМЕТРИЯ · ВЫЖИВАНИЕ", 15, UiTheme.ACCENT)
	kicker.add_theme_font_override("font", UiTheme.font(true))
	var logo := Label.new()
	logo.text = "RUSSIAN ZOMBIE\nSURVIVAL"
	logo.add_theme_font_override("font", UiTheme.font(true))
	logo.add_theme_font_size_override("font_size", 56)
	logo.add_theme_constant_override("line_spacing", -14)
	logo.add_theme_color_override("font_color", Color(0.93, 0.9, 0.82))
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	logo.add_theme_constant_override("shadow_offset_x", 4)
	logo.add_theme_constant_override("shadow_offset_y", 4)
	logo.add_theme_constant_override("shadow_outline_size", 6)
	_main.add_child(logo)
	var bar := ColorRect.new()
	bar.name = "AccentBar"
	bar.color = UiTheme.ACCENT
	bar.custom_minimum_size = Vector2(440, 4)
	_main.add_child(bar)
	_label(_main, "ГОРОД СТРОИТЕЛЬ  ·  СЕНТЯБРЬ  ·  ДЕНЬ ПЕРВЫЙ", 17, Color(0.82, 0.79, 0.72))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_main.add_child(gap)
	var sum := SaveGame.summary()
	if not sum.is_empty():
		var c := _menu_button("Продолжить", "день %d, %s · убито %d" % [sum["day"], sum["clock"], sum["kills"]])
		c.pressed.connect(func() -> void:
			SaveGame.apply_settings()
			Settings.load_save = true
			_leave(MAIN))
	_menu_button("Новая игра", "персонаж, профессия, мир").pressed.connect(func() -> void: _leave(NEW_GAME))
	_menu_button("Обучение", "пошаговые подсказки, мало зомби").pressed.connect(_start_tutorial)
	_menu_button("Версии игры", "v0.1 — v0.5, все этапы").pressed.connect(func() -> void: _show("versions"))
	_menu_button("Галерея", "кадры из игры").pressed.connect(func() -> void: _show("gallery"))
	_menu_button("Настройки", "графика, интерфейс, звук").pressed.connect(func() -> void: _show("settings"))
	_menu_button("Проверить обновления", "скачать патч с GitHub").pressed.connect(func() -> void:
		if HotUpdate:
			HotUpdate.check_for_updates("", true))
	_menu_button("Об игре", "управление и история").pressed.connect(func() -> void: _show("about"))
	_menu_button("Выход", "").pressed.connect(func() -> void: get_tree().quit())
	_buttons[0].grab_focus.call_deferred()
	# News ticker along the bottom.
	var strip := Control.new()
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.anchor_right = 1.0
	strip.offset_top = -32
	strip.offset_bottom = -6
	strip.clip_contents = true
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	_ticker = _label(strip, NEWS + NEWS, 15, Color(0.78, 0.75, 0.67))
	_ticker.position = Vector2(0, 4)
	var ver_info := "v%s (сборка #%d) · %s" % [HotUpdate.current_version, HotUpdate.current_build, HotUpdate.status_text] if HotUpdate else "v0.5 «От первого лица» · Godot 4.7"
	var ver := _label(self, ver_info, 14, UiTheme.DIM)
	ver.position = Vector2(48, 0)
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_top = -54
	var upd_bar := ProgressBar.new()
	upd_bar.name = "HotUpdateProgress"
	upd_bar.visible = false
	upd_bar.position = Vector2(48, 0)
	upd_bar.anchor_top = 1.0
	upd_bar.anchor_bottom = 1.0
	upd_bar.offset_top = -74
	upd_bar.offset_bottom = -62
	upd_bar.offset_right = 440
	upd_bar.max_value = 100.0
	add_child(upd_bar)
	if HotUpdate:
		HotUpdate.update_check_started.connect(func(_u: String) -> void:
			ver.add_theme_color_override("font_color", UiTheme.DIM)
			ver.text = HotUpdate.status_text)
		HotUpdate.update_progress.connect(func(pct: float, _got: int, _tot: int, _v: String) -> void:
			upd_bar.visible = true
			upd_bar.value = pct
			ver.add_theme_color_override("font_color", UiTheme.ACCENT)
			ver.text = HotUpdate.status_text)
		HotUpdate.update_up_to_date.connect(func(v: String, b: int, msg: String) -> void:
			upd_bar.visible = false
			ver.add_theme_color_override("font_color", Color(0.62, 0.86, 0.65))
			ver.text = "v%s (сборка #%d) · %s" % [v, b, msg])
		HotUpdate.update_error.connect(func(err_msg: String) -> void:
			upd_bar.visible = false
			ver.add_theme_color_override("font_color", Color(0.95, 0.45, 0.38))
			ver.text = "v%s (сборка #%d) · Ошибка: %s" % [HotUpdate.current_version, HotUpdate.current_build, err_msg])
		HotUpdate.update_finished.connect(func(ok: bool, _v: String, _msg: String) -> void:
			upd_bar.visible = false
			if ok:
				ver.add_theme_color_override("font_color", Color(0.62, 0.88, 0.62))
			ver.text = "v%s (сборка #%d) · %s" % [HotUpdate.current_version, HotUpdate.current_build, HotUpdate.status_text])
	_panel_host = Control.new()
	_panel_host.anchor_left = 1.0
	_panel_host.anchor_right = 1.0
	_panel_host.anchor_bottom = 1.0
	_panel_host.offset_left = -640
	_panel_host.offset_right = -28
	_panel_host.offset_top = 24
	_panel_host.offset_bottom = -58
	_panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_host)
	_panels["versions"] = _build_versions()
	_panels["gallery"] = _build_gallery()
	_panels["settings"] = _build_settings()
	_panels["about"] = _build_about()
	for k in _panels:
		(_panels[k] as Control).visible = false


func _intro() -> void:
	_main.modulate.a = 0.0
	_main.position.x -= 30.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_main, "modulate:a", 1.0, 1.2).set_delay(0.3)
	tw.tween_property(_main, "position:x", _main.position.x + 30.0, 1.2).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var bar := _main.get_node("AccentBar") as ColorRect
	bar.custom_minimum_size.x = 0.0
	tw.tween_property(bar, "custom_minimum_size:x", 440.0, 1.4).set_delay(0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in _buttons.size():
		var b := _buttons[i]
		b.modulate.a = 0.0
		tw.tween_property(b, "modulate:a", 1.0, 0.45).set_delay(0.9 + i * 0.07)


func _start_tutorial() -> void:
	Settings.tutorial = true
	Settings.zombie_count = 12
	Settings.profession = "unemployed"
	Settings.traits = []
	Settings.test_room = true
	Settings.helicopter = false
	Settings.load_save = false
	SaveGame.delete()
	_leave(MAIN)


func _menu_button(text: String, sub: String) -> Button:
	var b := Button.new()
	b.text = "   " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(440, 44)
	b.add_theme_font_override("font", UiTheme.font(true))
	b.add_theme_font_size_override("font_size", 24)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.05, 0.05, 0.045, 0.0)
	n.border_color = Color(0, 0, 0, 0)
	n.border_width_left = 3
	n.content_margin_left = 14
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.22, 0.11, 0.08, 0.78)
	h.border_color = UiTheme.ACCENT
	h.content_margin_left = 22
	b.add_theme_stylebox_override("normal", n)
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, h)
	b.add_theme_color_override("font_color", Color(0.86, 0.83, 0.75))
	b.add_theme_color_override("font_focus_color", Color(1, 0.96, 0.88))
	b.add_theme_color_override("font_hover_color", Color(1, 0.96, 0.88))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.focus_entered.connect(func() -> void: Sfx.play_ui("tv_click", -22.0))
	_main.add_child(b)
	if sub != "":
		var l := Label.new()
		l.text = sub
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(0.78, 0.75, 0.67))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.position = Vector2(440 - 14 - 260, 13)
		l.size = Vector2(260, 20)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
	_buttons.append(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE):
		if _viewer.visible:
			_viewer.visible = false
		else:
			_show("")
		get_viewport().set_input_as_handled()


func _show(which: String) -> void:
	for k in _panels:
		var p := _panels[k] as Control
		var on: bool = k == which
		if on and not p.visible:
			p.modulate.a = 0.0
			p.visible = true
			var tw := create_tween()
			tw.tween_property(p, "modulate:a", 1.0, 0.25)
		elif not on:
			p.visible = false


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.04, 0.04, 0.035, 0.9), true, 20))
	_panel_host.add_child(p)
	return p


func _build_versions() -> Control:
	var p := _panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	_label(v, "ВЕРСИИ ИГРЫ", 17, UiTheme.ACCENT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for i in versions.size():
		var b := Button.new()
		b.text = str(versions[i]["title"]).split(" — ")[0]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(96, 38)
		b.add_theme_font_size_override("font_size", 16)
		var idx := i
		b.pressed.connect(func() -> void: _select_version(idx))
		row.add_child(b)
		_ver_buttons.append(b)
	_ver_img = TextureRect.new()
	_ver_img.custom_minimum_size = Vector2(480, 165)
	_ver_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ver_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_ver_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.add_child(_ver_img)
	_ver_title = _label(v, "", 26, UiTheme.TEXT)
	_ver_title.add_theme_font_override("font", UiTheme.font(true))
	_ver_sub = _label(v, "", 16, UiTheme.DIM)
	_ver_badge = _label(v, "", 15, UiTheme.ACCENT)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_ver_desc = _label(scroll, "", 17, UiTheme.TEXT)
	_ver_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ver_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ver_desc.custom_minimum_size = Vector2(480, 0)
	var play := Button.new()
	play.text = "Играть в эту версию"
	play.custom_minimum_size = Vector2(0, 46)
	play.add_theme_font_override("font", UiTheme.font(true))
	play.add_theme_font_size_override("font_size", 21)
	play.pressed.connect(func() -> void: _launch(_ver_selected))
	v.add_child(play)
	_select_version(versions.size() - 1)
	return p


func _select_version(i: int) -> void:
	_ver_selected = i
	var v: Dictionary = versions[i]
	for j in _ver_buttons.size():
		_ver_buttons[j].button_pressed = j == i
	_ver_title.text = v["title"]
	_ver_sub.text = v["subtitle"]
	_ver_badge.text = "ЗАМОРОЖЕННАЯ ВЕРСИЯ — не меняется" if v.get("frozen", false) else "ТЕКУЩАЯ РАЗРАБОТКА"
	_ver_desc.text = v["description"]
	var pth: String = v.get("preview", "")
	_ver_img.texture = load(pth) as Texture2D if pth != "" and ResourceLoader.exists(pth) else null


func _build_gallery() -> Control:
	var p := _panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	_label(v, "ГАЛЕРЕЯ · кадры из игры без интерфейса", 17, UiTheme.ACCENT)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for i in SHOTS.size():
		var b := TextureButton.new()
		b.texture_normal = _tex(SHOTS[i][0])
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		b.custom_minimum_size = Vector2(235, 88)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var idx := i
		b.pressed.connect(func() -> void: _open_viewer(idx))
		b.mouse_entered.connect(func() -> void: b.modulate = Color(1.15, 1.1, 1.05))
		b.mouse_exited.connect(func() -> void: b.modulate = Color.WHITE)
		grid.add_child(b)
	_label(v, "Нажмите — во весь экран, ← → — листать, Esc — закрыть", 14, UiTheme.DIM)
	return p


func _build_viewer() -> void:
	_viewer = ColorRect.new()
	(_viewer as ColorRect).color = Color(0, 0, 0, 0.94)
	_viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewer.visible = false
	add_child(_viewer)
	_viewer_img = TextureRect.new()
	_viewer_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewer_img.offset_left = 40
	_viewer_img.offset_right = -40
	_viewer_img.offset_top = 30
	_viewer_img.offset_bottom = -70
	_viewer_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_viewer_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_viewer_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_viewer.add_child(_viewer_img)
	_viewer_cap = Label.new()
	_viewer_cap.anchor_top = 1.0
	_viewer_cap.anchor_bottom = 1.0
	_viewer_cap.anchor_right = 1.0
	_viewer_cap.offset_top = -56
	_viewer_cap.offset_bottom = -24
	_viewer_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_viewer_cap.add_theme_font_size_override("font_size", 17)
	_viewer.add_child(_viewer_cap)
	_viewer.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_viewer.visible = false)


func _open_viewer(i: int) -> void:
	_viewer_i = (i + SHOTS.size()) % SHOTS.size()
	_viewer_img.texture = _tex(SHOTS[_viewer_i][0])
	_viewer_cap.text = "%s    %d / %d" % [SHOTS[_viewer_i][1], _viewer_i + 1, SHOTS.size()]
	_viewer.visible = true


func _input(event: InputEvent) -> void:
	if _viewer and _viewer.visible and event is InputEventKey and event.pressed:
		var k := (event as InputEventKey).keycode
		if k == KEY_RIGHT:
			_open_viewer(_viewer_i + 1)
			get_viewport().set_input_as_handled()
		elif k == KEY_LEFT:
			_open_viewer(_viewer_i - 1)
			get_viewport().set_input_as_handled()


func _build_settings() -> Control:
	var p := _panel()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	_label(v, "НАСТРОЙКИ", 15, UiTheme.ACCENT)
	_option_row(v, "Качество графики", GameOptions.QUALITY_NAMES, GameOptions.quality, func(i: int) -> void:
		GameOptions.quality = i
		GameOptions.save())
	_option_row(v, "Размер пикселя", GameOptions.PIXEL_NAMES, GameOptions.pixel_scale, func(i: int) -> void:
		GameOptions.pixel_scale = i
		GameOptions.save())
	_option_row(v, "Масштаб интерфейса", GameOptions.UI_SCALE_NAMES, GameOptions.ui_scale_index(), func(i: int) -> void:
		GameOptions.ui_scale = GameOptions.UI_SCALES[i]
		GameOptions.save()
		UiTheme.fit(self))
	_check_row(v, "Контуры и цветокоррекция", GameOptions.outline, func(on: bool) -> void:
		GameOptions.outline = on
		GameOptions.save())
	_check_row(v, "Полный экран", GameOptions.fullscreen, func(on: bool) -> void:
		GameOptions.fullscreen = on
		GameOptions.save()
		GameOptions.apply_window())
	_check_row(v, "Вертикальная синхронизация", GameOptions.vsync, func(on: bool) -> void:
		GameOptions.vsync = on
		GameOptions.save()
		GameOptions.apply_window())
	_check_row(v, "Покачивание камеры при ходьбе", GameOptions.head_bob, func(on: bool) -> void:
		GameOptions.head_bob = on
		GameOptions.save())
	_slider_row(v, "Обзор от первого лица (FOV)", 70.0, 110.0, 1.0, GameOptions.fov, func(x: float) -> void:
		GameOptions.fov = x
		GameOptions.save())
	_slider_row(v, "Чувствительность мыши", 0.3, 2.5, 0.05, GameOptions.mouse_sens, func(x: float) -> void:
		GameOptions.mouse_sens = x
		GameOptions.save())
	var row := HBoxContainer.new()
	v.add_child(row)
	var l := _label(row, "Громкость", 17, UiTheme.TEXT)
	l.custom_minimum_size = Vector2(240, 0)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = GameOptions.volume
	vol.custom_minimum_size = Vector2(220, 28)
	vol.value_changed.connect(func(x: float) -> void: GameOptions.set_volume(x))
	row.add_child(vol)
	var hint := _label(v, "Качество: Низкое — без SSAO и свечения, меньше травы. Ультра — мягкие тени, отражения в лужах, больше травы.\n"
		+ "Размер пикселя «Чёткая картинка» отключает пиксель-арт. Масштаб интерфейса меняет размер всех окон и HUD.\n"
		+ "Качество и пиксель применяются при входе в игру.", 13, UiTheme.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(460, 0)
	return p


func _option_row(parent: Control, text: String, items: Array, sel: int, cb: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _label(row, text, 17, UiTheme.TEXT)
	l.custom_minimum_size = Vector2(240, 0)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(220, 34)
	for it in items:
		ob.add_item(it)
	ob.select(sel)
	ob.item_selected.connect(cb)
	row.add_child(ob)


func _slider_row(parent: Control, text: String, lo: float, hi: float, step: float, value: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _label(row, text, 17, UiTheme.TEXT)
	l.custom_minimum_size = Vector2(240, 0)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(220, 28)
	s.value_changed.connect(cb)
	row.add_child(s)


func _check_row(parent: Control, text: String, on: bool, cb: Callable) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_size_override("font_size", 17)
	c.toggled.connect(cb)
	parent.add_child(c)


func _build_about() -> Control:
	var p := _panel()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	_label(v, "ОБ ИГРЕ", 17, UiTheme.ACCENT)
	var txt := _label(v, "Выживание в духе Project Zomboid в русском городке сентябрьской осенью — от первого лица "
		+ "или в изометрии (V переключает вид в любой момент).\n\n"
		+ "Управление (сенсор / ПК): левый джойстик (движок) — ходьба и бег, правая сторона экрана — обзор, кнопки справа — УДАР, ДЕЙСТВИЕ, ПРИЦЕЛ, ПРИСЕД, БЕГ, сверху — ВЕЩИ, ЗДОР., НАВЫКИ, КАРТА, СВЕТ, ВИД, ПАУЗА.\n"
		+ "На ПК: WASD — ходьба, мышь — обзор, Shift — бег, Ctrl — красться, E — действие, ПКМ — меню, ЛКМ — удар/выстрел, "
		+ "Tab — инвентарь, H — здоровье, K — навыки, M — карта, F — фонарик, R — перезарядка, Esc — пауза, F9 — админка.\n\n"
		+ "История: v0.1 — прототип района; v0.2 — лут, зомби, бой; v0.3 — выживание, погода, сохранения; "
		+ "v0.4 — большой город, частный сектор, машины, навыки и профессии, баррикады, вертолёт, обучение; "
		+ "v0.5 — вид от первого лица: руки и оружие, прицельная стрельба, салон машины, небо и горизонт.", 17, UiTheme.TEXT)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.custom_minimum_size = Vector2(480, 0)
	return p


func _label(parent: Node, text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
