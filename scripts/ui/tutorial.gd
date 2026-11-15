extends PanelContainer
## New-player tutorial: a chain of objectives that advance on real actions (walk, search, inventory,
## arm yourself, sneak, fight, treat yourself, map and health window, drive, save). A bobbing orange
## arrow in the world points at the next target when there is one. F2 hides the panel.

const STEPS := [
	["Осмотритесь", "Левый джойстик (или WASD) — идти, правая часть экрана (мышь) — осмотреться. Пройдите немного по двору.", "walk"],
	["Обыщите мебель", "Подойдите к шкафу, холодильнику или ящику (стрелка), наведите прицел и нажмите «ДЕЙСТВИЕ» (E).", "search"],
	["Инвентарь", "Откройте «Рюкзак» (Tab) и переложите найденное к себе.", "inventory"],
	["Вооружитесь", "Возьмите оружие в руку: в «Тестовой» ящики со всем снаряжением (стрелка). Нажмите на предмет → «Взять в руку».", "weapon"],
	["Крадитесь", "Нажмите «СКРЫТНО» (Ctrl) — шаги тише и зомби вас не слышат. Пройдите пару метров крадучись.", "sneak"],
	["Первый бой", "Найдите зомби и ударьте его кнопкой «УДАР» / «ОГОНЬ» (ЛКМ). Лежачего добейте.", "kill"],
	["Позаботьтесь о себе", "Съешьте или выпейте что-нибудь, или перевяжите рану через «Рюкзак».", "use"],
	["Карта и здоровье", "Откройте «Карта» (M) и «Здоровье» (H) на верхней панели.", "panels"],
	["Машина", "У парковки стоит седан с ключом в замке (стрелка). Сядьте за руль («ДЕЙСТВИЕ» / E), «ГАЗ» — ехать.", "drive"],
	["Сохранение", "«Пауза» (Esc) → «Сохранить игру». Смерть удаляет сохранение — берегите себя.", "save"],
]

var player: Player
var step := 0
var _title: Label
var _text: Label
var _progress: Label
var _marker: Node3D
var _walk_from := Vector3.ZERO
var _sneak_t := 0.0
var _flags := {}
var _done_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -210
	offset_right = 210
	offset_top = 54
	custom_minimum_size = Vector2(420, 0)
	var sb := UiTheme.panel_box(Color(0.06, 0.06, 0.055, 0.90), true, 10)
	sb.border_color = UiTheme.ACCENT_DIM
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var tag := Label.new()
	tag.text = "ОБУЧЕНИЕ"
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", UiTheme.ACCENT)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tag)
	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 14)
	_progress.add_theme_color_override("font_color", UiTheme.DIM)
	head.add_child(_progress)
	var hide_btn := Button.new()
	hide_btn.text = "✕"
	hide_btn.custom_minimum_size = Vector2(28, 24)
	hide_btn.add_theme_font_size_override("font_size", 13)
	hide_btn.pressed.connect(func() -> void:
		visible = false
		if _marker:
			_marker.visible = false)
	head.add_child(hide_btn)
	_title = Label.new()
	_title.add_theme_font_override("font", UiTheme.font(true))
	_title.add_theme_font_size_override("font_size", 19)
	v.add_child(_title)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 15)
	_text.add_theme_color_override("font_color", UiTheme.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(390, 0)
	v.add_child(_text)
	Events.container_opened.connect(func(_c: Node) -> void: _flags["search"] = true)
	Events.inventory_toggle_requested.connect(func() -> void: _flags["inv_open"] = true)
	Events.zombie_killed.connect(func(_z: Node) -> void: _flags["kill"] = true)
	Events.vehicle_changed.connect(func(v2: Node) -> void:
		if v2 != null:
			_flags["drive"] = true)
	Events.game_saved.connect(func() -> void: _flags["save"] = true)
	_show_step()


func bind(p: Player) -> void:
	player = p
	_walk_from = p.global_position
	p.inventory.main.changed.connect(func() -> void:
		if _flags.get("inv_open", false):
			_flags["inventory"] = true)
	p.action_changed.connect(func() -> void:
		if p.action_label() != "":
			var l := p.action_label().to_lower()
			for k in ["съесть", "выпить", "перевяз", "едим", "пьём", "кофе", "таблет"]:
				if l.contains(k):
					_flags["use"] = true)
	_marker = _make_marker()
	p.get_parent().add_child(_marker)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F2:
		visible = not visible
		if _marker:
			_marker.visible = visible and _target() != Vector3.INF


func _make_marker() -> Node3D:
	var root := Node3D.new()
	root.name = "TutorialMarker"
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.45, 0.55, 0.12)
	mi.mesh = pm
	mi.rotation_degrees.z = 180.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.55, 0.2)
	m.no_depth_test = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root


func _target() -> Vector3:
	if player == null:
		return Vector3.INF
	match STEPS[step][2] if step < STEPS.size() else "":
		"search":
			var best: Node3D = null
			for c in get_tree().get_nodes_in_group("containers"):
				var lc := c as LootContainer
				if lc.searched or lc.container_type in ["corpse", "trunk", "crate"]:
					continue
				if best == null or lc.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
					best = lc
			return best.global_position + Vector3(0, 1.8, 0) if best else Vector3.INF
		"weapon":
			return Vector3(45.5, 2.6, 46.5) if Settings.test_room else Vector3.INF
		"drive":
			for v in get_tree().get_nodes_in_group("vehicles"):
				if (v as Vehicle).key_id == "":
					return (v as Node3D).global_position + Vector3(0, 2.4, 0)
	return Vector3.INF


func _process(delta: float) -> void:
	if player == null or step >= STEPS.size():
		return
	if _done_t > 0.0:
		_done_t -= delta
		if _done_t <= 0.0:
			step += 1
			_show_step()
		return
	var id: String = STEPS[step][2]
	var ok := false
	match id:
		"walk":
			ok = player.global_position.distance_to(_walk_from) > 6.0
		"search":
			ok = _flags.get("search", false)
		"inventory":
			ok = _flags.get("inventory", false)
		"weapon":
			ok = player.inventory.weapon() != null
		"sneak":
			if player.crouching and player.velocity.length() > 0.4:
				_sneak_t += delta
			ok = _sneak_t > 1.5
		"kill":
			ok = _flags.get("kill", false)
		"use":
			ok = _flags.get("use", false)
		"panels":
			var hud := get_parent()
			if (hud.get("_map") as Control).visible:
				_flags["map"] = true
			if (hud.get("_health_panel") as Control).visible:
				_flags["health"] = true
			ok = _flags.get("map", false) and _flags.get("health", false)
		"drive":
			ok = _flags.get("drive", false)
		"save":
			ok = _flags.get("save", false)
	if ok:
		_title.text = "✓ " + str(STEPS[step][0])
		_title.add_theme_color_override("font_color", UiTheme.GOOD)
		Sfx.play_ui("pickup", -4.0)
		_done_t = 1.2
	var tp := _target()
	if _marker:
		_marker.visible = visible and tp != Vector3.INF
		if tp != Vector3.INF:
			_marker.global_position = tp + Vector3(0, sin(Time.get_ticks_msec() * 0.005) * 0.15, 0)


func _show_step() -> void:
	if step >= STEPS.size():
		_title.text = "Обучение пройдено"
		_title.add_theme_color_override("font_color", UiTheme.GOOD)
		_text.text = "Теперь сами по себе. Удачи, выживший."
		_progress.text = ""
		if _marker:
			_marker.queue_free()
			_marker = null
		var tw := create_tween()
		tw.tween_interval(6.0)
		tw.tween_property(self, "modulate:a", 0.0, 1.0)
		tw.tween_callback(queue_free)
		return
	_title.add_theme_color_override("font_color", UiTheme.TEXT)
	_title.text = STEPS[step][0]
	_text.text = STEPS[step][1]
	_progress.text = "%d / %d" % [step + 1, STEPS.size()]
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
