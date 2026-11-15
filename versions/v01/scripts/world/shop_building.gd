class_name V01ShopBuilding
extends RefCounted
## Single-storey commercial pavilions: grocery ("Продукты") and pharmacy ("Аптека").
## Local frame: z = 0 is the street front with shop windows and the glass door.

const T_EXT := 0.3
const T_INT := 0.12


static func _new_building(parent: Node3D, pos: Vector3, rot_deg: float, name: String, w: float, d: float) -> V01Building:
	var b := V01Building.new()
	b.name = name
	b.display_name = name
	b.level_height = 3.4
	b.position = pos
	b.rotation_degrees.y = rot_deg
	b.footprint = Rect2(0, 0, w, d)
	parent.add_child(b, true)
	return b


static func _shopfront(at: float, w: float) -> Dictionary:
	return {"at": at, "w": w, "bottom": 0.55, "top": 2.6, "kind": "window"}


static func grocery(parent: Node3D, pos: Vector3, rot_deg: float) -> V01Building:
	var w := 14.0
	var d := 10.0
	var b := _new_building(parent, pos, rot_deg, "Продукты", w, d)
	var lb := V01LevelBuilder.new(b, 0, 4242)
	lb.set_exterior("brick")
	lb.door_open_chance = 0.4
	lb.add_room(Rect2(0, 0, w, 6.5), "shop", "paint", Color("#c8c8b4"), "floor_tile", Color("#e0d8c8"))
	lb.add_room(Rect2(0, 6.5, 9.0, 3.5), "storage", "paint", Color("#a8a490"), "concrete_floor")
	lb.add_room(Rect2(9.0, 6.5, 5.0, 3.5), "office", "wallpaper_b", Color("#b8b098"), "linoleum")
	var glass := {"at": 7.5, "w": V01Door.width_of(V01Door.Kind.GLASS), "bottom": 0.0, "top": V01Door.height_of(V01Door.Kind.GLASS),
		"kind": "door", "door": V01Door.Kind.GLASS, "open": false}
	lb.wall(Vector2(-0.15, 0), Vector2(w + 0.15, 0), T_EXT,
		[_shopfront(2.0, 2.4), _shopfront(4.8, 2.4), glass, _shopfront(10.0, 2.2), _shopfront(12.4, 1.8)], true)
	lb.wall(Vector2(-0.15, d), Vector2(w + 0.15, d), T_EXT,
		[V01PanelHouse._door(2.0, V01Door.Kind.ENTRANCE, true, false), V01PanelHouse._win(11.5, 1.2)], true)
	lb.wall(Vector2(0, 0.15), Vector2(0, d - 0.15), T_EXT, [], true)
	lb.wall(Vector2(w, 0.15), Vector2(w, d - 0.15), T_EXT, [], true)
	lb.wall(Vector2(0, 6.5), Vector2(w, 6.5), T_INT,
		[V01PanelHouse._door(4.5, V01Door.Kind.INTERIOR), V01PanelHouse._door(11.5, V01Door.Kind.INTERIOR)])
	lb.wall(Vector2(9.0, 6.5), Vector2(9.0, d), T_INT)
	var P := lb.props
	var y := lb.y0
	for x in [1.1, 2.95, 6.3, 8.15]:
		V01Furnish.place("furniture/shop_shelf", P, Vector3(x, y, 6.18), 180.0, "shop")
	for x in [9.7, 10.45]:
		V01Furnish.place("furniture/drink_fridge", P, Vector3(x, y, 6.1), 180.0, "shop")
	for x in [3.1, 5.6]:
		V01Furnish.place("furniture/shop_shelf", P, Vector3(x, y, 3.05), 0.0, "shop")
		V01Furnish.place("furniture/shop_shelf", P, Vector3(x, y, 3.6), 180.0, "shop")
	V01Furnish.place("furniture/shop_shelf", P, Vector3(0.42, y, 1.7), 90.0, "shop")
	V01Furnish.place("furniture/shop_counter", P, Vector3(12.2, y, 2.6), -90.0, "shop")
	V01Furnish.place("furniture/shop_counter", P, Vector3(12.2, y, 4.25), -90.0, "shop")
	V01Furnish.place("furniture/stool", P, Vector3(13.2, y, 3.4), 90.0, "shop")
	# Storage room.
	for x in [0.95, 2.8]:
		V01Furnish.place("furniture/shop_shelf", P, Vector3(x, y, 9.6), 180.0, "storage", "Складской стеллаж")
	for p in [Vector3(5.5, 0, 8.4), Vector3(7.2, 0, 9.1)]:
		V01Props.spawn("environment/pallet", P, p + Vector3(0, y, 0), randf() * 20.0, false)
		V01Props.spawn("environment/cardboard", P, p + Vector3(0, y + 0.13, 0), randf() * 360.0)
	V01Props.spawn("environment/cardboard", P, Vector3(4.0, y, 7.2), 30.0)
	# Office.
	V01Furnish.place("furniture/kitchen_table", P, Vector3(11.0, y, 9.3), 0.0, "office")
	V01Furnish.place("furniture/chair", P, Vector3(11.0, y, 8.6), 180.0, "office")
	V01Furnish.place("furniture/dresser", P, Vector3(13.5, y, 8.0), -90.0, "office", "Стол-тумба")
	lb.commit()
	_flat_roof(b, w, d, "brick")
	V01Props.spawn("buildings/sign_produkty", b, Vector3(7.0, 3.0, -0.22), 180.0, false)
	return b


static func pharmacy(parent: Node3D, pos: Vector3, rot_deg: float) -> V01Building:
	var w := 10.0
	var d := 9.0
	var b := _new_building(parent, pos, rot_deg, "Аптека", w, d)
	var lb := V01LevelBuilder.new(b, 0, 777)
	lb.set_exterior("plaster_pharm")
	lb.add_room(Rect2(0, 0, w, 4.6), "pharmacy", "paint", Color("#d8e0d8"), "floor_tile", Color("#e8e8e0"))
	lb.add_room(Rect2(0, 4.6, w, 4.4), "pharmacy_storage", "tile_wall", Color("#e0e8e8"), "floor_tile", Color("#d0d0c8"))
	var glass := {"at": 2.6, "w": V01Door.width_of(V01Door.Kind.GLASS), "bottom": 0.0, "top": V01Door.height_of(V01Door.Kind.GLASS),
		"kind": "door", "door": V01Door.Kind.GLASS, "open": false}
	lb.wall(Vector2(-0.15, 0), Vector2(w + 0.15, 0), T_EXT, [_shopfront(0.95, 1.2), glass, _shopfront(6.5, 3.4)], true)
	lb.wall(Vector2(-0.15, d), Vector2(w + 0.15, d), T_EXT, [V01PanelHouse._win(7.5, 1.2)], true)
	lb.wall(Vector2(0, 0.15), Vector2(0, d - 0.15), T_EXT, [], true)
	lb.wall(Vector2(w, 0.15), Vector2(w, d - 0.15), T_EXT, [V01PanelHouse._door(7.0, V01Door.Kind.ENTRANCE, true, false)], true)
	lb.wall(Vector2(0, 4.6), Vector2(w, 4.6), T_INT, [V01PanelHouse._door(9.0, V01Door.Kind.INTERIOR)])
	var P := lb.props
	var y := lb.y0
	V01Furnish.place("furniture/pharm_counter", P, Vector3(5.0, y, 3.0), 180.0, "pharmacy")
	V01Furnish.place("furniture/pharm_counter", P, Vector3(7.05, y, 3.0), 180.0, "pharmacy")
	for x in [4.9, 6.6]:
		V01Furnish.place("furniture/pharm_shelf", P, Vector3(x, y, 4.3), 180.0, "pharmacy")
	V01Furnish.place("furniture/pharm_shelf", P, Vector3(0.36, y, 2.6), 90.0, "pharmacy")
	V01Furnish.place("environment/bench", P, Vector3(1.2, y, 0.75), 0.0, "pharmacy")
	for x in [1.0, 2.8, 4.6]:
		V01Furnish.place("furniture/pharm_shelf", P, Vector3(x, y, 8.6), 180.0, "pharmacy_storage", "Склад аптеки")
	V01Props.spawn("environment/cardboard", P, Vector3(7.0, y, 6.5), 20.0)
	V01Furnish.place("furniture/chair", P, Vector3(8.0, y, 3.9), 180.0, "pharmacy")
	lb.commit()
	_flat_roof(b, w, d, "plaster_pharm")
	V01Props.spawn("buildings/sign_apteka", b, Vector3(5.0, 3.0, -0.22), 180.0, false)
	return b


static func _flat_roof(b: V01Building, w: float, d: float, ext: String) -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	b.add_child(roof)
	b.roof = roof
	var mb := V01MeshBuilder.new()
	var y := b.level_y(1) - V01LevelBuilder.SLAB
	var e := T_EXT * 0.5
	var em := V01Mats.surface(ext)
	mb.add_box(Vector3(-e, y, -e), Vector3(w + e, y + 0.22, d + e), "roof", V01Mats.surface("roof"))
	mb.add_box(Vector3(-e - 0.05, y, -e - 0.05), Vector3(w + e + 0.05, y + 0.45, e), ext, em)
	mb.add_box(Vector3(-e, y, d - e), Vector3(w + e, y + 0.45, d + e), ext, em)
	mb.add_box(Vector3(-e, y, -e), Vector3(e, y + 0.45, d + e), ext, em)
	mb.add_box(Vector3(w - e, y, -e), Vector3(w + e, y + 0.45, d + e), ext, em)
	mb.add_box(Vector3(w * 0.7, y + 0.22, d * 0.5), Vector3(w * 0.7 + 1.2, y + 1.0, d * 0.5 + 0.8), "metal_dark",
		V01Mats.surface("metal_dark"))
	roof.add_child(mb.commit("RoofMesh"))
