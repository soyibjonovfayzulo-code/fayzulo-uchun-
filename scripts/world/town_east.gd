class_name TownEast
extends RefCounted
## The town beyond the microdistrict: ул. Ленина (north-south) crossing ул. Строителей, a gas station,
## the police department with its armoury, an army quarantine checkpoint, the traffic jam of those who
## tried to leave, a burned bus, a second garage row and the forest around the town.

const LENIN_X := Vector2(130.0, 138.0)
const CROSS_Z := Vector2(86.0, 94.0)

## Dead bodies lying around from the start (spawner turns them into searchable corpses): [pos, kind]
const CORPSES := [
	[Vector3(133.0, 0.1, 62.5), "zombie_f"], [Vector3(128.5, 0.1, 64.5), "zombie_f"], [Vector3(140.5, 0.1, 61.0), "zombie_f"],
	[Vector3(135.5, 0.1, 71.5), "zombie_a"], [Vector3(152.0, 0.1, 83.0), "zombie_e"], [Vector3(163.0, 0.1, 100.5), "zombie_c"],
	[Vector3(200.5, 0.1, 93.8), "zombie_b"], [Vector3(46.0, 0.1, 89.0), "zombie_g"], [Vector3(88.0, 0.1, 120.5), "zombie_g"],
	[Vector3(60.5, 0.1, 150.0), "zombie_a"], [Vector3(30.0, 0.1, 70.0), "zombie_h"], [Vector3(98.0, 0.1, 84.5), "zombie_d"],
	[Vector3(134.5, 0.1, 160.0), "zombie_b"], [Vector3(137.0, 0.1, 176.0), "zombie_c"],
]


static func build(d: District) -> void:
	_roads(d)
	_gas_station(d)
	_police(d)
	_checkpoint(d)
	_jam_and_wrecks(d)
	_garages(d)
	_forest(d)
	_dressing(d)


static func _dash_z(d: District, x: float, z0: float, z1: float) -> void:
	var line := Mats.surface("road_line")
	var z := z0
	while z < z1:
		if not (z > CROSS_Z.x - 6 and z < CROSS_Z.y + 3):
			d._mb.add_box(Vector3(x - 0.08, 0.02, z), Vector3(x + 0.08, 0.03, z + 3.0), "road_line", line, Color.WHITE, Callable(), false)
		z += 6.0


static func _roads(d: District) -> void:
	d._flat(Rect2(LENIN_X.x, -14, LENIN_X.y - LENIN_X.x, 254), "asphalt", 0.021, "road", "ул. Ленина")
	d._flat(Rect2(120, CROSS_Z.x, 160, CROSS_Z.y - CROSS_Z.x), "asphalt", 0.02, "road", "")
	_dash_z(d, (LENIN_X.x + LENIN_X.y) * 0.5, -12, 238)
	var line := Mats.surface("road_line")
	var x := 120.0
	while x < 278.0:
		if not (x > LENIN_X.x - 6 and x < LENIN_X.y + 3):
			d._mb.add_box(Vector3(x, 0.02, 89.92), Vector3(x + 3.0, 0.03, 90.08), "road_line", line, Color.WHITE, Callable(), false)
		x += 6.0
	# Zebra crossings on all four sides of the crossroads.
	for i in 8:
		var zx := LENIN_X.x + 0.4 + i * 0.95
		d._mb.add_box(Vector3(zx, 0.022, CROSS_Z.x - 4.2), Vector3(zx + 0.5, 0.032, CROSS_Z.x - 0.4), "road_line", line, Color.WHITE, Callable(), false)
		d._mb.add_box(Vector3(zx, 0.022, CROSS_Z.y + 0.4), Vector3(zx + 0.5, 0.032, CROSS_Z.y + 4.2), "road_line", line, Color.WHITE, Callable(), false)
	for s in [[127.5, 30.0, 84.0], [127.5, 96.5, 150.0], [138.0, 30.0, 84.0], [138.0, 96.5, 150.0]]:
		d._flat(Rect2(s[0], s[1], 2.5, s[2] - s[1]), "asphalt_light", 0.08, "sidewalk")
	for c in [Vector3(128.2, 0.08, 84.6), Vector3(139.8, 0.08, 95.4)]:
		d.prop("environment/traffic_light", c, 180.0 if c.x < 134 else 0.0, false)
		d._trunk_collider(c, 0.1)
	for i in 5:
		d._streetlight(Vector3(139.0, 0.08, 40.0 + i * 24.0), -90.0)
	for i in 6:
		d._streetlight(Vector3(150.0 + i * 22.0, 0.08, 85.2), 0.0)
	d.prop("environment/sign_giveway", Vector3(128.4, 0.08, 80.0), 180.0)
	d.prop("environment/sign_stop", Vector3(139.6, 0.08, 99.0), 0.0)
	d.map_shapes.append([Rect2(120, 82.5, 1, 1), "label", ""])


static func _gas_station(d: District) -> void:
	d._flat(Rect2(146, 96.2, 34, 18), "concrete", 0.06, "parking", "АЗС")
	d.prop("environment/gas_canopy", Vector3(160, 0.06, 103), 180.0, false)
	for p in [Vector3(155.8, 0.06, 100.8), Vector3(155.8, 0.06, 105.2), Vector3(164.2, 0.06, 100.8), Vector3(164.2, 0.06, 105.2)]:
		Props.add_box(d._static, p + Vector3(0, 2.3, 0), Vector3(0.35, 4.6, 0.35))
	for p in [Vector3(158.0, 0.06, 103.0), Vector3(162.0, 0.06, 103.0)]:
		var fp := FuelPump.new()
		fp.position = p
		fp.rotation_degrees.y = 90.0
		d._static.add_child(fp)
	var b := Building.new()
	b.name = "АЗС"
	b.display_name = "АЗС №17"
	b.level_height = 3.2
	b.position = Vector3(168, 0, 104)
	b.footprint = Rect2(0, 0, 9, 6.5)
	d.add_child(b, true)
	var lb := LevelBuilder.new(b, 0, 1717)
	lb.set_exterior("plaster_ext")
	lb.window_broken_chance = 0.5
	lb.add_room(Rect2(0, 0, 9, 6.5), "gas", "paint", Color("#d0ccb8"), "floor_tile")
	lb.wall(Vector2(-0.15, 0), Vector2(9.15, 0), 0.3, [ShopBuilding._shopfront(2.0, 2.6), {"at": 5.0, "w": 1.0, "bottom": 0.0,
		"top": 2.1, "kind": "door", "door": Door.Kind.GLASS, "open": true}, ShopBuilding._shopfront(7.5, 2.2)], true)
	lb.wall(Vector2(-0.15, 6.5), Vector2(9.15, 6.5), 0.3, [PanelHouse._door(7.5, Door.Kind.ENTRANCE, true)], true)
	lb.wall(Vector2(0, 0.15), Vector2(0, 6.35), 0.3, [], true)
	lb.wall(Vector2(9, 0.15), Vector2(9, 6.35), 0.3, [PanelHouse._win(3.2, 1.2)], true)
	var P := lb.props
	for x in [1.0, 3.0]:
		var sh := Furnish.place("furniture/shop_shelf", P, Vector3(x, lb.y0, 6.15), 180.0, "gas") as LootContainer
		sh.table_id = "gas_shop"
	var ct := Furnish.place("furniture/shop_counter", P, Vector3(7.6, lb.y0, 3.2), -90.0, "gas") as LootContainer
	ct.table_id = "gas_shop"
	Furnish.place("furniture/drink_fridge", P, Vector3(0.45, lb.y0, 2.5), 90.0, "shop")
	lb.commit()
	ShopBuilding._flat_roof(b, 9, 6.5, "plaster_ext")
	d.buildings.append(b)
	d.map_shapes.append([Rect2(168, 104, 9, 6.5), "shop", ""])
	d.prop("environment/barrel_rust", Vector3(178, 0.06, 112), 0.0)
	d.prop("environment/tire", Vector3(177, 0.06, 110), 40.0)


static func _police(d: District) -> void:
	var w := 14.0
	var dd := 10.0
	var b := Building.new()
	b.name = "Полиция"
	b.display_name = "Отдел полиции"
	b.address = "ул. Ленина, 2"
	b.level_height = 3.2
	b.position = Vector3(160, 0, 80)
	b.rotation_degrees.y = 180.0
	b.footprint = Rect2(0, 0, w, dd)
	d.add_child(b, true)
	var lb := LevelBuilder.new(b, 0, 2020)
	lb.set_exterior("brick_red")
	lb.door_open_chance = 0.5
	lb.window_broken_chance = 0.15
	lb.add_room(Rect2(0, 0, 6, dd), "police_duty", "paint", Color("#b8c0c8"), "linoleum", Color("#a8a8a0"))
	lb.add_room(Rect2(6, 0, 2.2, dd), "hall", "paint", Color("#a8b0b8"), "linoleum", Color("#a8a8a0"))
	lb.add_room(Rect2(8.2, 0, w - 8.2, 5), "office", "wallpaper_a", Color("#c0b8a0"), "parquet")
	lb.add_room(Rect2(8.2, 5, w - 8.2, 5), "armory", "paint", Color("#8a9088"), "concrete_floor")
	lb.wall(Vector2(-0.15, 0), Vector2(w + 0.15, 0), 0.3, [PanelHouse._door(3.0, Door.Kind.ENTRANCE, false, true),
		PanelHouse._win(1.2, 1.0), PanelHouse._win(11.0, 1.4)], true)
	lb.wall(Vector2(-0.15, dd), Vector2(w + 0.15, dd), 0.3, [PanelHouse._win(3.0, 1.2), PanelHouse._door(7.1, Door.Kind.ENTRANCE, true)], true)
	lb.wall(Vector2(0, 0.15), Vector2(0, dd - 0.15), 0.3, [PanelHouse._win(6.5, 1.2)], true)
	lb.wall(Vector2(w, 0.15), Vector2(w, dd - 0.15), 0.3, [PanelHouse._win(2.5, 1.2)], true)
	lb.wall(Vector2(6, 0), Vector2(6, dd), 0.12, [PanelHouse._door(7.0, Door.Kind.INTERIOR)])
	var armory := PanelHouse._door(7.5, Door.Kind.APARTMENT, true)
	armory["key_id"] = "ovd_armory"
	armory["key_label"] = "оружейная ОВД"
	lb.wall(Vector2(8.2, 0), Vector2(8.2, dd), 0.12, [PanelHouse._door(2.5, Door.Kind.INTERIOR), armory])
	lb.wall(Vector2(8.2, 5), Vector2(w, 5), 0.2, [])
	var P := lb.props
	var y := lb.y0
	var desk := Furnish.place("furniture/dresser", P, Vector3(4.8, y, 3.5), -90.0, "police", "Стол дежурного") as LootContainer
	desk.table_id = "police_drawers"
	Furnish.place("furniture/shop_counter", P, Vector3(3.8, y, 3.5), -90.0, "police").set("display_name", "Барьер дежурной части")
	Furnish.place("furniture/chair", P, Vector3(5.2, y, 4.5), -90.0, "police")
	Furnish.place("environment/bench", P, Vector3(1.0, y, 8.5), 90.0, "police")
	Furnish.place("furniture/tv", P, Vector3(5.6, y + 0.0, 8.8), -90.0, "police")
	Furnish.place("furniture/kitchen_table", P, Vector3(11.0, y, 2.6), 0.0, "office", "Стол следователя")
	Furnish.place("furniture/chair", P, Vector3(11.0, y, 1.9), 180.0, "office")
	var od := Furnish.place("furniture/dresser", P, Vector3(13.5, y, 3.5), -90.0, "office", "Тумба") as LootContainer
	od.table_id = "police_drawers"
	Furnish.place("furniture/wardrobe", P, Vector3(8.6, y, 1.2), 90.0, "office")
	for z in [6.0, 8.0]:
		Furnish.place("furniture/gun_safe", P, Vector3(13.6, y, z), -90.0, "armory")
	var crate := Furnish.place("furniture/crate_army", P, Vector3(10.5, y, 9.4), 180.0, "armory", "Ящик с боеприпасами") as LootContainer
	crate.table_id = "zombie_soldier"
	lb.commit()
	ShopBuilding._flat_roof(b, w, dd, "brick_red")
	_sign(b, "ПОЛИЦИЯ", Vector3(7.0, 2.75, -0.2), 180.0, Color("#d8e0f0"), 110)
	d.buildings.append(b)
	d.map_shapes.append([Rect2(146, 70, 14, 10), "police", "Полиция"])
	d._flat(Rect2(146, 80.2, 14, 4.5), "asphalt_light", 0.07, "parking", "")


static func _sign(parent: Node3D, text: String, pos: Vector3, rot: float, color: Color, size := 56) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.position = pos
	l.rotation_degrees.y = rot
	parent.add_child(l)
	return l


static func _checkpoint(d: District) -> void:
	for p in [Vector3(131.2, 0.02, 60.0), Vector3(136.8, 0.02, 60.0), Vector3(132.6, 0.02, 64.0), Vector3(137.4, 0.02, 64.0)]:
		d.prop("environment/concrete_block", p, 0.0)
	d.prop("environment/barrier_gate", Vector3(134.0, 0.02, 67.5), 0.0)
	for x in [124.5, 126.6, 141.4, 143.5]:
		d.prop("environment/sandbags", Vector3(x, 0.02, 62.0), 0.0)
	d.prop("environment/army_tent", Vector3(147.0, 0.02, 60.0), -90.0)
	d.prop("vehicles/army_truck", Vector3(124.0, 0.03, 70.0), 12.0)
	d.prop("environment/sandbags", Vector3(144.5, 0.02, 57.5), 90.0)
	var board := Props.add_box(d._static, Vector3(134.0, 2.0, 71.0), Vector3(3.2, 1.2, 0.08))
	var mb := MeshBuilder.new()
	mb.add_box(Vector3(132.4, 1.4, 70.96), Vector3(135.6, 2.6, 71.04), "frame", Mats.surface("frame"))
	mb.add_box(Vector3(132.5, 0.0, 70.97), Vector3(132.6, 1.4, 71.03), "metal_dark", Mats.surface("metal_dark"))
	mb.add_box(Vector3(135.4, 0.0, 70.97), Vector3(135.5, 1.4, 71.03), "metal_dark", Mats.surface("metal_dark"))
	board.add_child(mb.commit("Board"))
	board.position = Vector3.ZERO
	_sign(d._static, "КАРАНТИН\nПРОЕЗД ЗАПРЕЩЁН", Vector3(134.0, 2.0, 71.08), 0.0, Color("#a82a20"), 40)
	d.map_shapes.append([Rect2(124, 58, 24, 14), "military", "Блокпост"])
	Smoke.fire(d._static, Vector3(125.5, 0.05, 59.0), 0.5)
	d.prop("environment/barrel_rust", Vector3(125.5, 0.02, 59.0), 0.0)


static func _jam_and_wrecks(d: District) -> void:
	var cars := ["vehicles/car_beige", "vehicles/car_blue", "vehicles/car_white", "vehicles/car_red"]
	var i := 0
	for z in [150.0, 156.5, 163.5, 171.0, 178.0, 186.5, 194.0]:
		var x := 136.0 if i % 2 == 0 else 132.0
		if i == 3:
			d.prop("vehicles/car_burned", Vector3(x, 0.02, z), 175.0)
			Smoke.column(d._static, Vector3(x, 1.5, z), 0.5)
		else:
			d._car(cars[i % cars.size()], Vector3(x, 0.03, z), 180.0 + randf_range(-12, 12), i == 5)
		i += 1
	d.prop("vehicles/bus_burned", Vector3(203.0, 0.02, 90.0), 92.0)
	Smoke.column(d._static, Vector3(203.0, 2.5, 90.0), 0.9)
	d.prop("vehicles/car_burned", Vector3(186.0, 0.02, 91.5), 75.0)
	Smoke.fire(d._static, Vector3(186.0, 0.9, 91.5), 1.0)
	d.prop("vehicles/car_burned", Vector3(229.0, 0.02, 88.0), 105.0)
	d.prop("vehicles/car_burned", Vector3(98.0, 0.02, 91.0), 250.0)
	Smoke.column(d._static, Vector3(98.0, 1.2, 91.0), 0.4)
	d.map_shapes.append([Rect2(197, 88.5, 12, 3), "misc", "Автобус"])


static func _garages(d: District) -> void:
	for i in 20:
		var g := "environment/garage_rust" if i % 3 == 0 else "environment/garage"
		d.prop(g, Vector3(148.0 + i * 3.3, 0, -6.0), 0.0)
		if i in [2, 6, 11, 15, 18]:
			var gc := LootContainer.new()
			gc.display_name = "Гараж №%d" % (i + 101)
			gc.container_type = "garage"
			gc.room_type = "garage"
			gc.search_time = 3.0
			gc.focus_offset = Vector3(0, 1.0, 0)
			gc.position = Vector3(148.0 + i * 3.3, 0, -2.7)
			d._static.add_child(gc)
	d._flat(Rect2(146, -3, 70, 6), "dirt", 0.034, "dirt")
	d.map_shapes.append([Rect2(146.4, -9, 66, 6), "garage", "Гаражи"])


static func _forest(d: District) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4545
	var placed := 0
	var tries := 0
	while placed < 130 and tries < 2000:
		tries += 1
		var p: Vector3
		if rng.randf() < 0.45:
			p = Vector3(rng.randf_range(244, 277), 0, rng.randf_range(-10, 236))
		else:
			p = Vector3(rng.randf_range(-6, 242), 0, rng.randf_range(212, 237))
		if p.x > LENIN_X.x - 3 and p.x < LENIN_X.y + 3:
			continue
		if p.z > CROSS_Z.x - 3 and p.z < CROSS_Z.y + 3:
			continue
		var asset := "environment/pine_%d" % (1 + rng.randi() % 2) if rng.randf() < 0.7 else "environment/birch_%d" % (1 + rng.randi() % 2)
		d._tree(asset, p)
		placed += 1
	d.map_shapes.append([Rect2(244, -10, 33, 246), "forest", "Лес"])
	d.map_shapes.append([Rect2(-6, 212, 248, 25), "forest", ""])


## Litter of the collapse: trash heaps, abandoned suitcases, graffiti, scattered across the town.
static func _dressing(d: District) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for p in [Vector3(44, 0.08, 83.5), Vector3(70, 0.03, 23), Vector3(15, 0.03, 52), Vector3(126, 0.03, 100),
			Vector3(140.8, 0.08, 120), Vector3(64.5, 0.03, 116), Vector3(105, 0.03, 50), Vector3(180, 0.06, 98)]:
		d.prop("environment/trash_pile", p, rng.randf() * 360.0, false)
	for p in [Vector3(51.5, 0.08, 83.8), Vector3(49.0, 0.08, 84.6), Vector3(133.5, 0.02, 75.0), Vector3(135.2, 0.02, 148.5),
			Vector3(60.0, 0.04, 99.0)]:
		d.prop("environment/suitcase", p, rng.randf() * 360.0, false)
	var paint := [Color("#a82a20"), Color("#d8d4c8"), Color("#2a2a2a")]
	for g in [["ЖИВЫЕ ЕСТЬ? КВ. 47", Vector3(31.0, 2.2, 67.2), 0.0], ["ЭВАКУАЦИЯ — ШКОЛА №3\n(ВРАНЬЁ)", Vector3(45.0, 1.7, 67.2), 0.0],
			["ОНИ ИДУТ НА ЗВУК", Vector3(53.0, 2.6, 67.2), 0.0], ["НЕ ВХОДИТЬ\nЗАРАЖЕНЫ", Vector3(97.25, 1.6, 31.0), 90.0],
			["ПАТРОНОВ НЕТ", Vector3(150.0, 1.5, 80.25), 0.0], ["МАМА, МЫ У БАБУШКИ\nНА САДОВОЙ", Vector3(54.25, 1.9, 11.0), 90.0]]:
		var l := _sign(d._static, g[0], g[1], g[2], paint[rng.randi() % paint.size()], 44)
		l.pixel_size = 0.0075
		l.modulate.a = 0.85
