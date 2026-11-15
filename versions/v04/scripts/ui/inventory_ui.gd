extends Control
## Project Zomboid-style inventory: player bag + equipment on the left, nearby loot (containers within
## reach and the floor) on the right. Drag & drop rows between panels (Shift = 1 item, Ctrl = half),
## double-click to transfer, right-click for item actions, hover for details.

const C_BG := Color(0.07, 0.07, 0.065, 0.93)
const C_BORDER := Color(0.36, 0.34, 0.29, 0.95)
const C_TEXT := Color(0.88, 0.85, 0.76)
const C_DIM := Color(0.62, 0.6, 0.54)
const C_RED := Color(0.85, 0.35, 0.3)
const REACH := 2.2
const FLOOR_REACH := 1.7
const ROW_H := 40

var player: V04Player
var _left: VBoxContainer
var _right: VBoxContainer
var _left_title: Label
var _right_title: Label
var _weight: ProgressBar
var _tabs: HFlowContainer
var _slot_boxes := {}
var _menu: PopupMenu
var _menu_entries: Array = []
var _tip: PanelContainer
var _tip_label: Label
## Loot sources: [{"name", "inv": Inventory, "kind": "container"|"floor", "node"}]
var _sources: Array = []
var _current := -1
var _floor_map := {}
var _scan_t := 0.0
var _sig := ""
var _wanted_container: Node


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	V04Events.inventory_toggle_requested.connect(toggle)
	V04Events.container_opened.connect(func(c: Node) -> void: open(c))
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player") as V04Player
	if player:
		player.inventory.changed.connect(_refresh_left)
		player.inventory.equipment_changed.connect(func(_s: String) -> void: _refresh_left())


func toggle() -> void:
	if visible:
		close()
	else:
		open(null)


func open(container: Node) -> void:
	_wanted_container = container
	visible = true
	_rescan(true)
	_refresh_left()
	V04Sfx.play_ui("cabinet_open", -14.0)


func close() -> void:
	visible = false
	_tip.visible = false
	_menu.hide()


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------------------------ build
func _panel_style(border := C_BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(8)
	return sb


func _label(parent: Node, text: String, size_px := 14, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _window(pos: Vector2, size_px: Vector2, title: String) -> Array:
	var p := PanelContainer.new()
	p.position = pos
	p.size = size_px
	p.custom_minimum_size = size_px
	p.add_theme_stylebox_override("panel", _panel_style())
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var t := _label(v, title, 17)
	return [p, v, t]


func _build() -> void:
	var lw := _window(Vector2(40, 84), Vector2(470, 600), "Инвентарь")
	var lv: VBoxContainer = lw[1]
	_left_title = lw[2]
	_weight = ProgressBar.new()
	_weight.custom_minimum_size = Vector2(0, 8)
	_weight.show_percentage = false
	_weight.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.14, 0.12)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("#8a8a6a")
	_weight.add_theme_stylebox_override("background", bg)
	_weight.add_theme_stylebox_override("fill", fg)
	lv.add_child(_weight)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	lv.add_child(slots)
	for slot in V04PlayerInventory.SLOTS:
		slots.add_child(_make_slot(slot))
	_label(lv, "Предметы  ·  ПКМ — действия, двойной клик — переложить", 12, C_DIM)
	_left = _list(lv, "player")

	var rw := _window(Vector2(530, 84), Vector2(470, 600), "Добыча")
	var rv: VBoxContainer = rw[1]
	_right_title = rw[2]
	_tabs = HFlowContainer.new()
	_tabs.add_theme_constant_override("h_separation", 4)
	_tabs.add_theme_constant_override("v_separation", 4)
	rv.add_child(_tabs)
	var take_all := Button.new()
	take_all.text = "Взять всё"
	take_all.pressed.connect(_take_all)
	_style_button(take_all)
	rv.add_child(take_all)
	_right = _list(rv, "loot")

	_menu = PopupMenu.new()
	add_child(_menu)
	_menu.id_pressed.connect(_on_menu)
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", _panel_style(Color(0.7, 0.6, 0.35)))
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 10
	add_child(_tip)
	_tip_label = _label(_tip, "", 13)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(300, 0)


func _style_button(b: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.14, 0.135, 0.12)
	n.border_color = C_BORDER
	n.set_border_width_all(1)
	n.set_content_margin_all(4)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.28, 0.24, 0.17)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_font_size_override("font_size", 13)


func _list(parent: VBoxContainer, side: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	sc.add_child(v)
	# Dropping anywhere on the panel moves the stack to that side.
	sc.set_drag_forwarding(Callable(), func(_p: Vector2, d: Variant) -> bool: return _can_drop(d, side),
		func(_p: Vector2, d: Variant) -> void: _drop(d, side))
	return v


func _make_slot(slot: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(108, 86)
	p.add_theme_stylebox_override("panel", _panel_style(Color(0.3, 0.28, 0.24)))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(58, 58)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)
	var l := _label(v, V04PlayerInventory.SLOT_NAMES[slot], 10, C_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.custom_minimum_size = Vector2(96, 0)
	p.set_drag_forwarding(func(_pos: Vector2) -> Variant:
			var s: V04ItemStack = player.inventory.equipped[slot]
			return (_drag_data(s, "player") as Variant) if s else null,
		func(_pos: Vector2, d: Variant) -> bool: return d is Dictionary and player.inventory.slot_for(d["stack"]) == slot,
		func(_pos: Vector2, d: Variant) -> void:
			var s: V04ItemStack = d["stack"]
			if d["src"] != "player":
				if not _move(s, d["src"], "player", -1):
					return
			player.inventory.equip(s, slot))
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			player.inventory.unequip(slot))
	p.mouse_entered.connect(func() -> void:
		var s: V04ItemStack = player.inventory.equipped[slot]
		if s:
			_show_tip(s))
	p.mouse_exited.connect(func() -> void: _tip.visible = false)
	_slot_boxes[slot] = [icon, l]
	return p


# ------------------------------------------------------------------------------------------------ data
func _rescan(force: bool) -> void:
	if player == null:
		return
	var found: Array = []
	var pp := player.global_position
	for c in get_tree().get_nodes_in_group("containers"):
		var lc := c as V04LootContainer
		if not lc.is_visible_in_tree() and not lc.get_parent() is V04Zombie:
			continue
		var fp := lc.get_focus_point()
		if Vector2(fp.x - pp.x, fp.z - pp.z).length() < REACH and absf(fp.y - pp.y - 0.7) < 1.4:
			found.append(lc)
	if _wanted_container and not found.has(_wanted_container):
		found.push_front(_wanted_container)
	_floor_map.clear()
	var floor_inv := V04Inventory.new("Пол", 999.0)
	for w in get_tree().get_nodes_in_group("world_items"):
		var wi := w as V04WorldItem
		if wi.is_queued_for_deletion():
			continue
		var d := wi.global_position - pp
		if Vector2(d.x, d.z).length() < FLOOR_REACH and absf(d.y) < 1.0:
			floor_inv.stacks.append(wi.stack)
			_floor_map[wi.stack] = wi
	var sig := str(found.map(func(n: Node) -> int: return n.get_instance_id())) + "|" + str(_floor_map.size())
	var selected_node: Node = _sources[_current]["node"] if _current >= 0 and _current < _sources.size() else null
	if not force and sig == _sig:
		# Floor contents may change without the signature (stacks swapped) - keep the virtual list fresh.
		for s in _sources:
			if s["kind"] == "floor":
				s["inv"] = floor_inv
		if _current >= 0 and _current < _sources.size() and _sources[_current]["kind"] == "floor":
			_refresh_right()
		return
	_sig = sig
	for s in _sources:
		if s["kind"] == "container" and is_instance_valid(s["node"]):
			var inv: V04Inventory = (s["node"] as V04LootContainer).inventory
			if inv.changed.is_connected(_refresh_right):
				inv.changed.disconnect(_refresh_right)
	_sources.clear()
	for lc in found:
		var c := lc as V04LootContainer
		_sources.append({"name": c.display_name, "inv": c.inventory, "kind": "container", "node": c})
		if not c.inventory.changed.is_connected(_refresh_right):
			c.inventory.changed.connect(_refresh_right)
	_sources.append({"name": "Пол", "inv": floor_inv, "kind": "floor", "node": null})
	_current = 0
	var want: Node = _wanted_container if _wanted_container else selected_node
	for i in _sources.size():
		if _sources[i]["node"] == want and want != null:
			_current = i
	_wanted_container = null
	_rebuild_tabs()
	_refresh_right()


func _rebuild_tabs() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for i in _sources.size():
		var s: Dictionary = _sources[i]
		var b := Button.new()
		var unsearched: bool = s["kind"] == "container" and not (s["node"] as V04LootContainer).searched
		b.text = s["name"] + (" (?)" if unsearched else "")
		_style_button(b)
		if i == _current:
			b.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
			var sel := StyleBoxFlat.new()
			sel.bg_color = Color(0.32, 0.26, 0.16)
			sel.border_color = Color(0.75, 0.6, 0.35)
			sel.set_border_width_all(1)
			sel.set_content_margin_all(4)
			b.add_theme_stylebox_override("normal", sel)
		var idx := i
		b.pressed.connect(func() -> void:
			_current = idx
			var src: Dictionary = _sources[idx]
			if src["kind"] == "container" and not (src["node"] as V04LootContainer).searched:
				_wanted_container = src["node"]
				(src["node"] as V04LootContainer).perform("search", player)
			_rebuild_tabs()
			_refresh_right())
		_tabs.add_child(b)


func _source(key: String) -> Dictionary:
	if key == "player":
		return {"name": "Инвентарь", "inv": player.inventory.main, "kind": "player", "node": null}
	if _current >= 0 and _current < _sources.size():
		return _sources[_current]
	return {}


func _refresh_left() -> void:
	if not visible or player == null:
		return
	var inv := player.inventory.main
	var w := inv.total_weight()
	_left_title.text = "Инвентарь — %.1f / %.1f кг" % [w, inv.capacity]
	_left_title.add_theme_color_override("font_color", C_RED if w > inv.capacity else C_TEXT)
	_weight.value = clampf(w / inv.capacity, 0.0, 1.0)
	for slot in V04PlayerInventory.SLOTS:
		var s: V04ItemStack = player.inventory.equipped[slot]
		var box: Array = _slot_boxes[slot]
		(box[0] as TextureRect).texture = s.item.icon if s else null
		(box[1] as Label).text = s.get_name() if s else V04PlayerInventory.SLOT_NAMES[slot]
		(box[1] as Label).add_theme_color_override("font_color", C_TEXT if s else C_DIM)
	_fill(_left, inv.stacks, "player")


func _refresh_right() -> void:
	if not visible:
		return
	var src := _source("loot")
	if src.is_empty():
		_right_title.text = "Добыча"
		_fill(_right, [], "loot")
		return
	var inv: V04Inventory = src["inv"]
	if src["kind"] == "container":
		var lc := src["node"] as V04LootContainer
		if not lc.searched:
			_right_title.text = "%s — не обыскано" % src["name"]
			_fill(_right, [], "loot")
			_label(_right, "Нажмите на вкладку, чтобы обыскать.", 13, C_DIM)
			return
		_right_title.text = "%s — %.1f кг" % [src["name"], inv.total_weight()] if inv.capacity >= 999.0 			else "%s — %.1f / %.0f кг" % [src["name"], inv.total_weight(), inv.capacity]
	else:
		_right_title.text = "Пол — предметы рядом"
	_fill(_right, inv.stacks, "loot")
	if inv.stacks.is_empty():
		_label(_right, "Пусто.", 13, C_DIM)


func _fill(list: VBoxContainer, stacks: Array, side: String) -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var sorted := stacks.duplicate()
	sorted.sort_custom(func(a: V04ItemStack, b: V04ItemStack) -> bool:
		return a.item.category < b.item.category or (a.item.category == b.item.category and a.get_name() < b.get_name()))
	for s in sorted:
		list.add_child(_row(s, side))


func _row(s: V04ItemStack, side: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, ROW_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.105, 0.095)
	sb.set_content_margin_all(2)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.22, 0.2, 0.15)
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var icon := TextureRect.new()
	icon.texture = s.item.icon
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon)
	var title := s.get_name()
	if side == "player" and player.inventory.is_equipped(s):
		title += "  [%s]" % V04PlayerInventory.SLOT_NAMES[player.inventory.equipped_slot(s)]
	var nl := _label(h, title, 14)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	var st := s.status_text()
	if s.count > 1:
		st = ("×%d  " % s.count) + st
	_label(h, st, 12, C_DIM)
	var wl := _label(h, "%.2f" % s.total_weight(), 12, C_DIM)
	wl.custom_minimum_size = Vector2(44, 0)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.set_drag_forwarding(func(_pos: Vector2) -> Variant: return _drag_data(s, side),
		func(_p: Vector2, d: Variant) -> bool: return _can_drop(d, side),
		func(_p: Vector2, d: Variant) -> void: _drop(d, side))
	p.mouse_entered.connect(func() -> void:
		p.add_theme_stylebox_override("panel", hov)
		_show_tip(s))
	p.mouse_exited.connect(func() -> void:
		p.add_theme_stylebox_override("panel", sb)
		_tip.visible = false)
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			var mb := e as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
				_move(s, side, "loot" if side == "player" else "player", -1)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_open_menu(s, side))
	return p


# ------------------------------------------------------------------------------------------------ drag & drop
func _drag_data(s: V04ItemStack, side: String) -> Dictionary:
	var prev := HBoxContainer.new()
	var ic := TextureRect.new()
	ic.texture = s.item.icon
	ic.custom_minimum_size = Vector2(36, 36)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prev.add_child(ic)
	var mods := ""
	if Input.is_key_pressed(KEY_SHIFT):
		mods = " (1 шт.)"
	elif Input.is_key_pressed(KEY_CTRL):
		mods = " (половина)"
	_label(prev, s.get_name() + mods, 14)
	set_drag_preview(prev)
	return {"stack": s, "src": side}


func _can_drop(d: Variant, side: String) -> bool:
	return d is Dictionary and d.has("stack") and d["src"] != side


func _drop(d: Variant, side: String) -> void:
	var s: V04ItemStack = d["stack"]
	var amount := -1
	if Input.is_key_pressed(KEY_SHIFT):
		amount = 1
	elif Input.is_key_pressed(KEY_CTRL):
		amount = maxi(floori(s.count / 2.0), 1)
	_move(s, d["src"], side, amount)


## Moves `amount` units (all = -1) between the player bag and the selected loot source (container/floor).
func _move(s: V04ItemStack, from_key: String, to_key: String, amount: int) -> bool:
	if from_key == to_key or player == null:
		return false
	var n := s.count if amount < 0 else clampi(amount, 1, s.count)
	var main := player.inventory.main
	if from_key == "player":
		var dst := _source("loot")
		if dst.is_empty():
			return false
		if dst["kind"] == "floor":
			player.drop_item(s, n)
			_rescan(true)
			return true
		if not (dst["node"] as V04LootContainer).searched:
			return false
		if not V04Inventory.transfer(s, main, dst["inv"], n):
			V04Events.show_toast("Не помещается.")
			return false
		V04Sfx.play_ui("drawer", -16.0)
		return true
	var src := _source("loot")
	if src.is_empty():
		return false
	if main.total_weight() + s.unit_weight() * n > main.capacity + 12.0:
		V04Events.show_toast("Слишком тяжело.")
		return false
	if src["kind"] == "floor":
		var wi: V04WorldItem = _floor_map.get(s)
		if wi == null:
			return false
		var part := s if n >= s.count else s.split(n)
		main.add(part, true)
		if part == s:
			_floor_map.erase(s)
			wi.queue_free()
		V04Sfx.play_ui("pickup", -12.0)
		_rescan(true)
		return true
	V04Inventory.transfer(s, src["inv"], main, n, true)
	if main.total_weight() > main.capacity:
		V04Events.show_toast("Перегруз! Вы двигаетесь медленнее.")
	V04Sfx.play_ui("drawer", -16.0)
	return true


func _take_all() -> void:
	var src := _source("loot")
	if src.is_empty():
		return
	for s in (src["inv"] as V04Inventory).stacks.duplicate():
		if not _move(s, "loot", "player", -1):
			break


# ------------------------------------------------------------------------------------------------ menu & tooltip
func _open_menu(s: V04ItemStack, side: String) -> void:
	_menu.clear()
	_menu_entries.clear()
	var add := func(label: String, cb: Callable) -> void:
		_menu.add_item(label, _menu_entries.size())
		_menu_entries.append(cb)
	_menu.add_separator(s.get_name())
	if side == "player":
		for a in player.item_actions(s):
			var id: String = a["id"]
			add.call(a["label"], func() -> void: player.use_item(s, id))
		if s.count > 1:
			add.call("Разделить пополам", func() -> void:
				var half := player.inventory.main.take(s, floori(s.count / 2.0))
				player.inventory.main.stacks.append(half)
				player.inventory.main.changed.emit())
		var dst := _source("loot")
		if not dst.is_empty() and dst["kind"] == "container" and (dst["node"] as V04LootContainer).searched:
			add.call("Переложить в: " + dst["name"], func() -> void: _move(s, "player", "loot", -1))
		add.call("Выбросить", func() -> void:
			player.drop_item(s, -1)
			_rescan(true))
	else:
		add.call("Взять", func() -> void: _move(s, "loot", "player", -1))
		if s.count > 1:
			add.call("Взять 1", func() -> void: _move(s, "loot", "player", 1))
		if player.inventory.can_equip(s):
			add.call("Взять и экипировать", func() -> void:
				if _move(s, "loot", "player", 1):
					var got := player.inventory.main.stacks.filter(func(x: V04ItemStack) -> bool: return x.item == s.item)
					if not got.is_empty():
						player.inventory.equip(got[-1]))
	_menu.reset_size()
	_menu.content_scale_factor = V04GameOptions.ui_scale
	_menu.position = Vector2i(get_viewport().get_mouse_position()) + Vector2i(6, 6)
	_menu.popup()


func _on_menu(id: int) -> void:
	if id >= 0 and id < _menu_entries.size():
		(_menu_entries[id] as Callable).call()


func _show_tip(s: V04ItemStack) -> void:
	var d := s.item
	var lines: Array[String] = [s.get_name(), "%s · %.2f кг" % [d.category_name(), s.unit_weight()], d.description]
	if d.is_weapon():
		if d.attack_style == "shoot":
			lines.append("Урон %d · дальность %d м · магазин %d/%d" % [d.damage, d.fire_range, s.loaded, d.magazine])
		else:
			lines.append("Урон %d · скорость %.2f с · дальность %.1f м" % [d.damage, d.swing_time, d.reach])
			lines.append("Сбить с ног: %d%% · крит: %d%%" % [d.knockdown_chance * 100, d.crit_chance * 100])
	if d.max_durability > 0.0:
		lines.append("Прочность: %d / %d" % [s.durability, d.max_durability])
	if d.hunger < 0.0 or d.thirst < 0.0:
		lines.append("Сытость %+d · жажда %+d (за порцию)" % [-d.hunger * 100, -d.thirst * 100])
	if d.uses > 1:
		lines.append("Осталось: %d из %d" % [s.uses_left, d.uses])
	if d.capacity_bonus > 0.0:
		lines.append("Вместимость +%d кг" % d.capacity_bonus)
	if d.protection > 0.0:
		lines.append("Защита от укусов: %d%%" % (d.protection * 100))
	if d.light_range > 0.0:
		lines.append("Заряд: %d%%" % (s.charge * 100))
	if d.warmth > 0.0:
		lines.append("Тепло: %d%%" % (d.warmth * 100))
	if s.freshness_text() != "":
		lines.append(s.freshness_text())
	if d.needs_opener:
		lines.append("Нужен консервный нож (или нож, отвёртка)")
	if d.cooked_id != "":
		lines.append("Сварить → %s" % V04ItemDB.get_item(d.cooked_id).display_name)
	if d.fuel_hours > 0.0:
		lines.append("Топливо для костра: %.1f ч" % d.fuel_hours)
	if d.drowsiness < 0.0:
		lines.append("Бодрит")
	if d.antibiotic_hours > 0.0:
		lines.append("Лечит воспаление ран")
	if d.calm > 0.0:
		lines.append("Успокаивает")
	_tip_label.text = "\n".join(lines)
	_tip.visible = true
	_tip.reset_size()


func _process(delta: float) -> void:
	if not visible:
		return
	if _tip.visible:
		var vs := get_viewport_rect().size / V04GameOptions.ui_scale
		_tip.position = (V04UiTheme.to_ui(get_viewport().get_mouse_position()) + Vector2(18, 14)).min(vs - _tip.size)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.3
		_rescan(false)
