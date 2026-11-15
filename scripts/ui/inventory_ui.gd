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
const ROW_H := 44

var player: Player
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
var _sb_btn_normal: StyleBoxFlat
var _sb_btn_hover: StyleBoxFlat
var _sb_btn_empty: StyleBoxEmpty
var _sb_row: StyleBoxFlat
var _sb_row_hov: StyleBoxFlat
var _sb_tab_sel: StyleBoxFlat
var _left_rows: Array[Control] = []
var _right_rows: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _left_empty_lbl: Label
var _right_empty_lbl: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	Events.inventory_toggle_requested.connect(toggle)
	Events.container_opened.connect(func(c: Node) -> void: open(c))
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player") as Player
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
	Sfx.play_ui("cabinet_open", -14.0)


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
	var t := _label(v, title, 19)
	return [p, v, t]


func _build() -> void:
	var lw := _window(Vector2(24, 54), Vector2(465, 570), "Инвентарь")
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
	for slot in PlayerInventory.SLOTS:
		slots.add_child(_make_slot(slot))
	_label(lv, "Предметы  ·  нажмите для действий, двойной клик — переложить", 14, C_DIM)
	_left = _list(lv, "player")

	var rw := _window(Vector2(504, 54), Vector2(465, 570), "Добыча")
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
	_tip_label = _label(_tip, "", 15)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(300, 0)
	for i in 16:
		var r := _create_pooled_row("player")
		r.visible = false
		_left_rows.append(r)
		_left.add_child(r)
	for i in 68:
		var r := _create_pooled_row("loot")
		r.visible = false
		_right_rows.append(r)
		_right.add_child(r)


func _style_button(b: Button) -> void:
	if _sb_btn_normal == null:
		_sb_btn_normal = StyleBoxFlat.new()
		_sb_btn_normal.bg_color = Color(0.14, 0.135, 0.12)
		_sb_btn_normal.border_color = C_BORDER
		_sb_btn_normal.set_border_width_all(1)
		_sb_btn_normal.set_content_margin_all(5)
		_sb_btn_hover = _sb_btn_normal.duplicate() as StyleBoxFlat
		_sb_btn_hover.bg_color = Color(0.28, 0.24, 0.17)
		_sb_btn_empty = StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", _sb_btn_normal)
	b.add_theme_stylebox_override("hover", _sb_btn_hover)
	b.add_theme_stylebox_override("pressed", _sb_btn_hover)
	b.add_theme_stylebox_override("focus", _sb_btn_empty)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_font_size_override("font_size", 15)


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
	var l := _label(v, PlayerInventory.SLOT_NAMES[slot], 12, C_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.custom_minimum_size = Vector2(96, 0)
	p.set_drag_forwarding(func(_pos: Vector2) -> Variant:
			var s: ItemStack = player.inventory.equipped[slot]
			return (_drag_data(s, "player") as Variant) if s else null,
		func(_pos: Vector2, d: Variant) -> bool: return d is Dictionary and player.inventory.slot_for(d["stack"]) == slot,
		func(_pos: Vector2, d: Variant) -> void:
			var s: ItemStack = d["stack"]
			if d["src"] != "player":
				if not _move(s, d["src"], "player", -1):
					return
			player.inventory.equip(s, slot))
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			var mb := e as InputEventMouseButton
			var is_touch := OS.has_feature("mobile") or OS.get_name() == "Android" or DisplayServer.is_touchscreen_available()
			if mb.button_index == MOUSE_BUTTON_RIGHT or (is_touch and mb.button_index == MOUSE_BUTTON_LEFT):
				player.inventory.unequip(slot))
	p.mouse_entered.connect(func() -> void:
		var s: ItemStack = player.inventory.equipped[slot]
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
	var max_xz := REACH + 1.5
	var reach_sq := REACH * REACH
	for c in get_tree().get_nodes_in_group("containers"):
		var lc := c as LootContainer
		var cp := lc.global_position
		if absf(cp.x - pp.x) > max_xz or absf(cp.z - pp.z) > max_xz or absf(cp.y - pp.y) > 2.6:
			continue
		if not lc.is_visible_in_tree() and not (lc.get_parent() is Zombie):
			continue
		var fp := lc.get_focus_point()
		var dx := fp.x - pp.x
		var dz := fp.z - pp.z
		if (dx * dx + dz * dz) < reach_sq and absf(fp.y - pp.y - 0.7) < 1.4:
			found.append(lc)
	if _wanted_container and not found.has(_wanted_container):
		found.push_front(_wanted_container)
	_floor_map.clear()
	var floor_inv := Inventory.new("Пол", 999.0)
	var floor_sq := FLOOR_REACH * FLOOR_REACH
	for w in get_tree().get_nodes_in_group("world_items"):
		var wi := w as WorldItem
		if wi.is_queued_for_deletion():
			continue
		var d := wi.global_position - pp
		if (d.x * d.x + d.z * d.z) < floor_sq and absf(d.y) < 1.0:
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
			var inv: Inventory = (s["node"] as LootContainer).inventory
			if inv.changed.is_connected(_refresh_right):
				inv.changed.disconnect(_refresh_right)
	_sources.clear()
	for lc in found:
		var c := lc as LootContainer
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
	if _sb_tab_sel == null:
		_sb_tab_sel = StyleBoxFlat.new()
		_sb_tab_sel.bg_color = Color(0.32, 0.26, 0.16)
		_sb_tab_sel.border_color = Color(0.75, 0.6, 0.35)
		_sb_tab_sel.set_border_width_all(1)
		_sb_tab_sel.set_content_margin_all(4)
	while _tab_buttons.size() < _sources.size():
		var b := Button.new()
		_style_button(b)
		var idx := _tab_buttons.size()
		b.pressed.connect(func() -> void:
			if idx >= _sources.size():
				return
			_current = idx
			var src: Dictionary = _sources[idx]
			if src["kind"] == "container" and not (src["node"] as LootContainer).searched:
				_wanted_container = src["node"]
				(src["node"] as LootContainer).perform("search", player)
			_rebuild_tabs()
			_refresh_right())
		_tab_buttons.append(b)
		_tabs.add_child(b)
	for i in _tab_buttons.size():
		var b := _tab_buttons[i]
		if i < _sources.size():
			var s: Dictionary = _sources[i]
			var unsearched: bool = s["kind"] == "container" and not (s["node"] as LootContainer).searched
			b.text = s["name"] + (" (?)" if unsearched else "")
			b.add_theme_color_override("font_color", Color(1, 0.9, 0.6) if i == _current else C_TEXT)
			b.add_theme_stylebox_override("normal", _sb_tab_sel if i == _current else _sb_btn_normal)
			b.visible = true
		else:
			b.visible = false


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
	for slot in PlayerInventory.SLOTS:
		var s: ItemStack = player.inventory.equipped[slot]
		var box: Array = _slot_boxes[slot]
		(box[0] as TextureRect).texture = s.item.icon if s else null
		(box[1] as Label).text = s.get_name() if s else PlayerInventory.SLOT_NAMES[slot]
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
	var inv: Inventory = src["inv"]
	if src["kind"] == "container":
		var lc := src["node"] as LootContainer
		if not lc.searched:
			_right_title.text = "%s — не обыскано" % src["name"]
			_fill(_right, [], "loot", "Нажмите на вкладку, чтобы обыскать.")
			return
		_right_title.text = "%s — %.1f кг" % [src["name"], inv.total_weight()] if inv.capacity >= 999.0 \
			else "%s — %.1f / %.0f кг" % [src["name"], inv.total_weight(), inv.capacity]
	else:
		_right_title.text = "Пол — предметы рядом"
	_fill(_right, inv.stacks, "loot", "Пусто." if inv.stacks.is_empty() else "")


func _fill(list: VBoxContainer, stacks: Array, side: String, empty_msg := "") -> void:
	var pool := _left_rows if side == "player" else _right_rows
	var sorted := stacks.duplicate()
	sorted.sort_custom(func(a: ItemStack, b: ItemStack) -> bool:
		return a.item.category < b.item.category or (a.item.category == b.item.category and a.get_name() < b.get_name()))
	while pool.size() < sorted.size():
		var r := _create_pooled_row(side)
		pool.append(r)
		list.add_child(r)
	for i in pool.size():
		var row := pool[i]
		if i < sorted.size():
			_bind_pooled_row(row, sorted[i], side)
			row.visible = true
		else:
			row.visible = false
	if side == "loot":
		if _right_empty_lbl == null:
			_right_empty_lbl = _label(list, "", 13, C_DIM)
		_right_empty_lbl.text = empty_msg
		_right_empty_lbl.visible = empty_msg != ""


func _create_pooled_row(side: String) -> Control:
	if _sb_row == null:
		_sb_row = StyleBoxFlat.new()
		_sb_row.bg_color = Color(0.11, 0.105, 0.095)
		_sb_row.set_content_margin_all(2)
		_sb_row_hov = _sb_row.duplicate() as StyleBoxFlat
		_sb_row_hov.bg_color = Color(0.22, 0.2, 0.15)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, ROW_H)
	p.add_theme_stylebox_override("panel", _sb_row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon)
	var nl := _label(h, "", 16)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	var sl := _label(h, "", 14, C_DIM)
	var wl := _label(h, "", 14, C_DIM)
	wl.custom_minimum_size = Vector2(48, 0)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var act_btn := Button.new()
	act_btn.text = "⋯"
	act_btn.custom_minimum_size = Vector2(36, 32)
	_style_button(act_btn)
	act_btn.pressed.connect(func() -> void:
		var st: ItemStack = p.get_meta("stack", null)
		if st:
			_open_menu(st, side))
	h.add_child(act_btn)
	p.set_meta("refs", [icon, nl, sl, wl])
	p.set_drag_forwarding(func(_pos: Vector2) -> Variant:
			var st: ItemStack = p.get_meta("stack", null)
			return _drag_data(st, side) if st else null,
		func(_p: Vector2, d: Variant) -> bool: return _can_drop(d, side),
		func(_p: Vector2, d: Variant) -> void: _drop(d, side))
	p.mouse_entered.connect(func() -> void:
		p.add_theme_stylebox_override("panel", _sb_row_hov)
		var st: ItemStack = p.get_meta("stack", null)
		if st:
			_show_tip(st))
	p.mouse_exited.connect(func() -> void:
		p.add_theme_stylebox_override("panel", _sb_row)
		_tip.visible = false)
	p.gui_input.connect(func(e: InputEvent) -> void:
		var st: ItemStack = p.get_meta("stack", null)
		if st and e is InputEventMouseButton and e.pressed:
			var mb := e as InputEventMouseButton
			var is_touch := OS.has_feature("mobile") or OS.get_name() == "Android" or DisplayServer.is_touchscreen_available()
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
				_move(st, side, "loot" if side == "player" else "player", -1)
			elif mb.button_index == MOUSE_BUTTON_RIGHT or (is_touch and mb.button_index == MOUSE_BUTTON_LEFT):
				_open_menu(st, side))
	return p


func _bind_pooled_row(p: Control, s: ItemStack, side: String) -> void:
	p.set_meta("stack", s)
	var refs: Array = p.get_meta("refs")
	(refs[0] as TextureRect).texture = s.item.icon
	var title := s.get_name()
	if side == "player" and player.inventory.is_equipped(s):
		title += "  [%s]" % PlayerInventory.SLOT_NAMES[player.inventory.equipped_slot(s)]
	(refs[1] as Label).text = title
	var st := s.status_text()
	if s.count > 1:
		st = ("×%d  " % s.count) + st
	(refs[2] as Label).text = st
	(refs[3] as Label).text = "%.2f" % s.total_weight()


# ------------------------------------------------------------------------------------------------ drag & drop
func _drag_data(s: ItemStack, side: String) -> Dictionary:
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
	var s: ItemStack = d["stack"]
	var amount := -1
	if Input.is_key_pressed(KEY_SHIFT):
		amount = 1
	elif Input.is_key_pressed(KEY_CTRL):
		amount = maxi(floori(s.count / 2.0), 1)
	_move(s, d["src"], side, amount)


## Moves `amount` units (all = -1) between the player bag and the selected loot source (container/floor).
func _move(s: ItemStack, from_key: String, to_key: String, amount: int) -> bool:
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
		if not (dst["node"] as LootContainer).searched:
			return false
		if not Inventory.transfer(s, main, dst["inv"], n):
			Events.show_toast("Не помещается.")
			return false
		Sfx.play_ui("drawer", -16.0)
		return true
	var src := _source("loot")
	if src.is_empty():
		return false
	if main.total_weight() + s.unit_weight() * n > main.capacity + 12.0:
		Events.show_toast("Слишком тяжело.")
		return false
	if src["kind"] == "floor":
		var wi: WorldItem = _floor_map.get(s)
		if wi == null:
			return false
		var part := s if n >= s.count else s.split(n)
		main.add(part, true)
		if part == s:
			_floor_map.erase(s)
			wi.queue_free()
		Sfx.play_ui("pickup", -12.0)
		_rescan(true)
		return true
	Inventory.transfer(s, src["inv"], main, n, true)
	if main.total_weight() > main.capacity:
		Events.show_toast("Перегруз! Вы двигаетесь медленнее.")
	Sfx.play_ui("drawer", -16.0)
	return true


func _take_all() -> void:
	var src := _source("loot")
	if src.is_empty():
		return
	for s in (src["inv"] as Inventory).stacks.duplicate():
		if not _move(s, "loot", "player", -1):
			break


# ------------------------------------------------------------------------------------------------ menu & tooltip
func _open_menu(s: ItemStack, side: String) -> void:
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
		if not dst.is_empty() and dst["kind"] == "container" and (dst["node"] as LootContainer).searched:
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
					var got := player.inventory.main.stacks.filter(func(x: ItemStack) -> bool: return x.item == s.item)
					if not got.is_empty():
						player.inventory.equip(got[-1]))
	_menu.reset_size()
	_menu.content_scale_factor = GameOptions.ui_scale
	_menu.position = Vector2i(get_viewport().get_mouse_position()) + Vector2i(6, 6)
	_menu.popup()


func _on_menu(id: int) -> void:
	if id >= 0 and id < _menu_entries.size():
		(_menu_entries[id] as Callable).call()


func _show_tip(s: ItemStack) -> void:
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
		lines.append("Сварить → %s" % ItemDB.get_item(d.cooked_id).display_name)
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
		var vs := get_viewport_rect().size / GameOptions.ui_scale
		_tip.position = (UiTheme.to_ui(get_viewport().get_mouse_position()) + Vector2(18, 14)).min(vs - _tip.size)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.3
		_rescan(false)
