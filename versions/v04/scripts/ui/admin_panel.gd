extends PanelContainer
## Admin / debug panel (F9) for testing and filming: spawn any item, edit every survivor stat and skill,
## god mode and invisibility, control time, weather, power, zombies, cars and the helicopter, teleport.

const C_DIM := Color(0.62, 0.6, 0.54)
const TELEPORTS := [
	["Двор (старт)", Vector3(40, 0.1, 52)], ["Тестовая", Vector3(45.5, 0.15, 46.5)], ["Продукты", Vector3(25, 0.1, 83)],
	["Аптека", Vector3(89, 0.1, 83.5)], ["Девятиэтажка", Vector3(91, 0.1, 22)], ["Гаражи", Vector3(75, 0.1, -1)],
	["Частный сектор", Vector3(60, 0.1, 128)], ["Ул. Лесная", Vector3(40, 0.1, 170)], ["Перекрёсток", Vector3(134, 0.1, 90)],
	["Блокпост", Vector3(134, 0.1, 74)], ["Полиция", Vector3(153, 0.1, 84)], ["АЗС", Vector3(160, 0.1, 110)],
	["Сгоревший автобус", Vector3(203, 0.1, 95)], ["Пробка на выезде", Vector3(129, 0.1, 172)], ["Лес", Vector3(255, 0.1, 140)],
]
const STATS := [
	["Здоровье", "hp"], ["Голод", "hunger"], ["Жажда", "thirst"], ["Выносливость", "endurance"], ["Усталость", "fatigue"],
	["Сонливость", "drowsiness"], ["Паника", "panic"], ["Отравление", "poison"],
]

var player: V04Player
var _tabs: TabContainer
var _item_list: VBoxContainer
var _search: LineEdit
var _sliders := {}
var _temp_slider: HSlider
var _skill_labels := {}
var _status: Label
var _updating := false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -380
	offset_right = 380
	offset_top = -300
	offset_bottom = 300
	var v := VBoxContainer.new()
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = "АДМИНКА  ·  F9"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", V04UiTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_status = Label.new()
	_status.add_theme_color_override("font_color", C_DIM)
	head.add_child(_status)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(740, 540)
	v.add_child(_tabs)
	_build_items()
	_build_character()
	_build_world()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()
		_fill_items("")


# ------------------------------------------------------------------------------------------------ items
func _build_items() -> void:
	var page := VBoxContainer.new()
	page.name = "Предметы"
	_tabs.add_child(page)
	var row := HBoxContainer.new()
	page.add_child(row)
	_search = LineEdit.new()
	_search.placeholder_text = "Поиск предмета..."
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_fill_items)
	row.add_child(_search)
	for spec in [["Всё по 1", func() -> void: _give_all()], ["Набор выжившего", func() -> void: _give_kit()]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		row.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_item_list)


func _fill_items(filter: String) -> void:
	for c in _item_list.get_children():
		c.queue_free()
	var ids := V04ItemDB.items.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var da: V04ItemData = V04ItemDB.items[a]
		var db: V04ItemData = V04ItemDB.items[b]
		return da.category < db.category or (da.category == db.category and da.display_name < db.display_name))
	for id in ids:
		var d: V04ItemData = V04ItemDB.items[id]
		if filter != "" and not d.display_name.to_lower().contains(filter.to_lower()) and not id.contains(filter):
			continue
		var row := HBoxContainer.new()
		_item_list.add_child(row)
		var ic := TextureRect.new()
		ic.texture = d.icon
		ic.custom_minimum_size = Vector2(32, 32)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(ic)
		var l := Label.new()
		l.text = "%s  ·  %s" % [d.display_name, d.category_name()]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		for n in [1, 10]:
			var b := Button.new()
			b.text = "+%d" % n
			b.custom_minimum_size = Vector2(46, 28)
			var idd: String = id
			var nn: int = n
			b.pressed.connect(func() -> void: _give(idd, nn))
			row.add_child(b)


func _give(id: String, n: int) -> void:
	var d := V04ItemDB.get_item(id)
	if d.is_stackable():
		player.inventory.give(id, n)
	else:
		for i in n:
			var s := player.inventory.give(id)
			if s.item.magazine > 0:
				s.loaded = s.item.magazine
			if s.item.light_range > 0.0:
				s.charge = 1.0
	_status.text = "Выдано: %s ×%d" % [d.display_name, n]


func _give_all() -> void:
	for id in V04ItemDB.items:
		_give(id, 1)
	_status.text = "Выдано всё по одному"


func _give_kit() -> void:
	for e in [["axe", 1], ["pistol", 1], ["ammo", 50], ["backpack", 1], ["telogreika", 1], ["flashlight", 1], ["batteries", 4],
			["first_aid", 1], ["bandage", 5], ["water", 2], ["tushenka", 4], ["can_opener", 1], ["matches", 1], ["hammer", 1],
			["planks", 4], ["nails", 20], ["jerrycan", 1], ["screwdriver", 1]]:
		_give(e[0], e[1])
	_status.text = "Набор выжившего выдан"


# ------------------------------------------------------------------------------------------------ character
func _build_character() -> void:
	var page := HBoxContainer.new()
	page.name = "Персонаж"
	page.add_theme_constant_override("separation", 24)
	_tabs.add_child(page)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(left)
	for s in STATS:
		var row := HBoxContainer.new()
		left.add_child(row)
		var l := Label.new()
		l.text = s[0]
		l.custom_minimum_size = Vector2(120, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.01
		sl.custom_minimum_size = Vector2(200, 24)
		var key: String = s[1]
		sl.value_changed.connect(func(val: float) -> void: _set_stat(key, val))
		row.add_child(sl)
		_sliders[key] = sl
	var trow := HBoxContainer.new()
	left.add_child(trow)
	var tl := Label.new()
	tl.text = "Темп. тела"
	tl.custom_minimum_size = Vector2(120, 0)
	trow.add_child(tl)
	_temp_slider = HSlider.new()
	_temp_slider.min_value = 33.0
	_temp_slider.max_value = 41.0
	_temp_slider.step = 0.1
	_temp_slider.custom_minimum_size = Vector2(200, 24)
	_temp_slider.value_changed.connect(func(val: float) -> void:
		if not _updating:
			player.body_temp.temp = val)
	trow.add_child(_temp_slider)
	var grid := GridContainer.new()
	grid.columns = 2
	left.add_child(grid)
	for spec in [["Вылечить всё", _heal_all], ["Убрать раны", func() -> void: player.wounds.list.clear()],
			["Заразить", func() -> void: player.wounds.infected = true], ["Вылечить заражение", func() -> void:
				player.wounds.infected = false
				player.wounds.infection_hours = 0.0],
			["Нанести укус", func() -> void: player.wounds.add("bite")], ["Высушить и согреть", func() -> void:
				player.body_temp.wetness = 0.0
				player.body_temp.temp = 36.6]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		grid.add_child(b)
	var god := CheckBox.new()
	god.text = "Бессмертие"
	god.button_pressed = V04Settings.god_mode
	god.toggled.connect(func(on: bool) -> void: V04Settings.god_mode = on)
	left.add_child(god)
	var inv := CheckBox.new()
	inv.text = "Невидимость для зомби"
	inv.button_pressed = V04Settings.invisible
	inv.toggled.connect(func(on: bool) -> void: V04Settings.invisible = on)
	left.add_child(inv)
	var right := VBoxContainer.new()
	page.add_child(right)
	var st := Label.new()
	st.text = "Навыки"
	st.add_theme_color_override("font_color", V04UiTheme.ACCENT)
	right.add_child(st)
	for id in V04Skills.NAMES:
		var row := HBoxContainer.new()
		right.add_child(row)
		var l := Label.new()
		l.custom_minimum_size = Vector2(190, 0)
		row.add_child(l)
		_skill_labels[id] = l
		for delta in [-1, 1]:
			var b := Button.new()
			b.text = "−" if delta < 0 else "+"
			b.custom_minimum_size = Vector2(32, 26)
			var sid: String = id
			var dd: int = delta
			b.pressed.connect(func() -> void: _skill_step(sid, dd))
			row.add_child(b)


func _set_stat(key: String, v: float) -> void:
	if _updating or player == null:
		return
	match key:
		"hp":
			player.health.health = v * player.health.max_health
		"hunger":
			player.stats.hunger = v
		"thirst":
			player.stats.thirst = v
		"endurance":
			player.stats.endurance = v
		"fatigue":
			player.stats.fatigue = v
		"drowsiness":
			player.stats.drowsiness = v
		"panic":
			player.stats.panic = v
		"poison":
			player.stats.poison = v


func _heal_all() -> void:
	player.health.health = player.health.max_health
	player.wounds.list.clear()
	player.wounds.infected = false
	player.wounds.infection_hours = 0.0
	var s := player.stats
	s.hunger = 0.0
	s.thirst = 0.0
	s.endurance = 1.0
	s.fatigue = 0.0
	s.drowsiness = 0.0
	s.panic = 0.0
	s.poison = 0.0
	player.body_temp.temp = 36.6
	player.body_temp.wetness = 0.0
	_status.text = "Здоров как бык"


func _skill_step(id: String, d: int) -> void:
	var lv := clampi(V04Skills.level_of(player, id) + d, 0, V04Skills.MAX_LEVEL)
	player.skills[id] = V04Skills.xp_for(lv) + (0.5 if lv > 0 else 0.0)
	_refresh()


# ------------------------------------------------------------------------------------------------ world
func _build_world() -> void:
	var page := HBoxContainer.new()
	page.name = "Мир"
	page.add_theme_constant_override("separation", 24)
	_tabs.add_child(page)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(left)
	var hrow := HBoxContainer.new()
	left.add_child(hrow)
	var hl := Label.new()
	hl.text = "Время:"
	hrow.add_child(hl)
	for h in [6, 12, 18, 22, 2]:
		var b := Button.new()
		b.text = "%02d:00" % h
		var hh: int = h
		b.pressed.connect(func() -> void: V04GameTime.set_hour(float(hh)))
		hrow.add_child(b)
	var srow := HBoxContainer.new()
	left.add_child(srow)
	var sl := Label.new()
	sl.text = "Скорость:"
	srow.add_child(sl)
	for sc in [1, 5, 20, 60]:
		var b := Button.new()
		b.text = "×%d" % sc
		var scc: float = sc
		b.pressed.connect(func() -> void: V04GameTime.time_scale = scc)
		srow.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 2
	left.add_child(grid)
	for spec in [["Дождь: ливень", func() -> void: V04Climate.instance.set_rain_now(1.0)],
			["Дождь: стоп", func() -> void: V04Climate.instance.set_rain_now(0.0)],
			["Отключить свет/газ/воду", func() -> void: _utilities(false)], ["Вернуть свет/газ/воду", func() -> void: _utilities(true)],
			["Зомби рядом (×5)", func() -> void: _spawn_zombies(5)], ["Убить зомби вокруг", _kill_nearby],
			["Убрать всех зомби", _clear_all], ["Вызвать вертолёт", func() -> void: V04HelicopterEvent.instance.begin()],
			["Машина рядом", _spawn_car], ["Заправить ближайшую машину", _refuel_car],
			["Сохранить игру", func() -> void: _status.text = "Сохранено" if V04SaveGame.save(player.get_parent() as Node3D) else "Ошибка"]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		grid.add_child(b)
	var right := VBoxContainer.new()
	page.add_child(right)
	var tl := Label.new()
	tl.text = "Телепорт"
	tl.add_theme_color_override("font_color", V04UiTheme.ACCENT)
	right.add_child(tl)
	for t in TELEPORTS:
		var b := Button.new()
		b.text = t[0]
		b.custom_minimum_size = Vector2(220, 26)
		var pos: Vector3 = t[1]
		b.pressed.connect(func() -> void:
			if player.state == V04Player.State.DRIVING:
				player.exit_vehicle()
			player.global_position = pos
			player.velocity = Vector3.ZERO
			player.rig_snap()
			_status.text = "Телепорт: " + str(t[0]))
		right.add_child(b)


func _utilities(on: bool) -> void:
	var c := V04Climate.instance
	var h := c.hours_since_start()
	if on:
		c.power_off_at = -1.0
		c.water_off_at = -1.0
		c.gas_off_at = -1.0
	else:
		c.power_off_at = h - 0.01
		c.water_off_at = h - 0.01
		c.gas_off_at = h - 0.01


func _spawn_zombies(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	var root := player.get_parent().get_node("Zombies")
	for i in n:
		var a := rng.randf() * TAU
		V04Zombie.spawn(root, player.global_position + Vector3(cos(a), 0, sin(a)) * rng.randf_range(7.0, 11.0) + Vector3(0, 0.2, 0), rng)


func _kill_nearby() -> void:
	for z in get_tree().get_nodes_in_group("zombies"):
		if (z as Node3D).global_position.distance_to(player.global_position) < 25.0:
			(z as V04Zombie).health.take_damage(9999.0)


func _clear_all() -> void:
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()


func _spawn_car() -> void:
	var d := V04District.instance
	var p := player.global_position + player.get_facing_vector() * 4.0 + Vector3(0, 0.6, 0)
	var v := d._vehicle("res://versions/v04/assets/vehicles/sedan_body_ochre.glb", "Седан (админ)", p, rad_to_deg(player.yaw), "", 40.0)
	v.global_position = p


func _refuel_car() -> void:
	var best: V04Vehicle = null
	for v in get_tree().get_nodes_in_group("vehicles"):
		if best == null or (v as Node3D).global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
			best = v
	if best:
		best.fuel = V04Vehicle.FUEL_MAX
		best.health = 100.0
		_status.text = "%s: полный бак, починена" % best.display_name


func _refresh() -> void:
	if player == null:
		return
	_updating = true
	var s := player.stats
	var vals := {"hp": player.health.ratio(), "hunger": s.hunger, "thirst": s.thirst, "endurance": s.endurance,
		"fatigue": s.fatigue, "drowsiness": s.drowsiness, "panic": s.panic, "poison": s.poison}
	for k in vals:
		(_sliders[k] as HSlider).value = vals[k]
	_temp_slider.value = player.body_temp.temp
	for id in _skill_labels:
		(_skill_labels[id] as Label).text = "%s: %d" % [V04Skills.NAMES[id], V04Skills.level_of(player, id)]
	_updating = false


func _process(_delta: float) -> void:
	if visible and Engine.get_process_frames() % 20 == 0 and not _tabs.get_current_tab_control().name == "Предметы" \
			and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_refresh()
