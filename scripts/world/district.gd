class_name District
extends Node3D
## The town: the microdistrict ("микрорайон") with apartment blocks, shops and garages, the private sector
## of log houses south of it (PrivateSector), and the town beyond ул. Ленина with a gas station, the police,
## an army checkpoint and the forest (TownEast). Generated deterministically at startup (x east, z south).

const BOUNDS := Rect2(-10, -14, 290, 254)

static var instance: District

## Map overlay data: [Rect2 (x,z), kind, label]
var map_shapes: Array = []
var buildings: Array[Building] = []
var spawn_point := Vector3(40, 0.1, 52)

var _ground_rects: Array = []
## Tree trunks (for leaf litter), counters for the ground detail pass.
var tree_points: Array[Vector3] = []
var grass_count := 0
var decal_count := 0
var _mb: MeshBuilder
var _ground_body: StaticBody3D
var _static: Node3D


func _ready() -> void:
	instance = self
	_ground_body = StaticBody3D.new()
	_ground_body.name = "GroundBody"
	add_child(_ground_body)
	_static = Node3D.new()
	_static.name = "Props"
	add_child(_static)
	_mb = MeshBuilder.new(_ground_body)
	_build_ground()
	_build_buildings()
	if Settings.test_room:
		_build_test_room()
	_build_courtyard()
	_build_street()
	_build_garages()
	_build_greenery()
	PrivateSector.build(self)
	TownEast.build(self)
	_build_vehicles()
	GroundDetail.build(self)
	var gm := _mb.commit("Ground")
	add_child(gm)


# ------------------------------------------------------------------------------------------------ helpers
func _flat(r: Rect2, key: String, top: float, kind := "", label := "", collide := true) -> void:
	_mb.add_box(Vector3(r.position.x, top - 0.25, r.position.y), Vector3(r.end.x, top, r.end.y), key,
		Mats.surface(key), Color.WHITE, Callable(), collide)
	if kind != "":
		map_shapes.append([r, kind, label])
	_ground_rects.append([r, "grass" if key in ["grass", "dirt", "sand"] else "concrete", key, top])


## Sidewalk slab with a curb rim.
func _sidewalk(r: Rect2, label := "") -> void:
	_flat(r, "asphalt_light", 0.08, "sidewalk", label)
	var c := Mats.surface("curb")
	for e in [Rect2(r.position.x, r.position.y, r.size.x, 0.12), Rect2(r.position.x, r.end.y - 0.12, r.size.x, 0.12)]:
		_mb.add_box(Vector3(e.position.x, 0.0, e.position.y), Vector3(e.end.x, 0.1, e.end.y), "curb", c, Color.WHITE,
			Callable(), false)


func prop(asset: String, pos: Vector3, rot := 0.0, collide := true) -> Node3D:
	return Props.spawn(asset, _static, pos, rot, collide)


func _trunk_collider(at: Vector3, radius: float) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = 3.0
	cs.shape = s
	body.position = at + Vector3(0, 1.5, 0)
	body.add_child(cs)
	_static.add_child(body)


static func surface_at(p: Vector3) -> String:
	if instance == null:
		return "concrete"
	for b in instance.buildings:
		if b.contains_point(p):
			return "floor"
	var q := Vector2(p.x, p.z)
	for i in range(instance._ground_rects.size() - 1, -1, -1):
		var e: Array = instance._ground_rects[i]
		if (e[0] as Rect2).has_point(q):
			return e[1]
	return "grass"


## Surface key of the topmost ground rectangle at p ("grass", "asphalt", "gravel"...).
func ground_key_at(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	for i in range(_ground_rects.size() - 1, -1, -1):
		var e: Array = _ground_rects[i]
		if (e[0] as Rect2).has_point(q):
			return e[2] if e.size() > 2 else e[1]
	return "grass"


func ground_top_at(p: Vector3) -> float:
	var q := Vector2(p.x, p.z)
	var top := 0.0
	for i in range(_ground_rects.size() - 1, -1, -1):
		var e: Array = _ground_rects[i]
		if (e[0] as Rect2).has_point(q):
			return float(e[3]) if e.size() > 3 else 0.0
	return top


# ------------------------------------------------------------------------------------------------ layout
func _build_ground() -> void:
	_flat(BOUNDS, "grass", 0.0)
	# Street "ул. Строителей" with sidewalks.
	_flat(Rect2(-10, 86, 130, 8), "asphalt", 0.02, "road", "ул. Строителей")
	_sidewalk(Rect2(-10, 82.5, 130, 3.5))
	_sidewalk(Rect2(-10, 94, 130, 2.5))
	var line := Mats.surface("road_line")
	var x := -8.0
	while x < 118.0:
		_mb.add_box(Vector3(x, 0.02, 89.92), Vector3(x + 3.0, 0.03, 90.08), "road_line", line, Color.WHITE, Callable(), false)
		x += 6.0
	for i in 7:
		var zx := 62.0 + i * 0.9
		_mb.add_box(Vector3(zx, 0.02, 86.3), Vector3(zx + 0.5, 0.03, 93.7), "road_line", line, Color.WHITE, Callable(), false)
	# Courtyard driveways.
	_flat(Rect2(66, 20, 6, 66.5), "asphalt", 0.03, "road")
	_flat(Rect2(17.5, 19.5, 88.5, 4.5), "asphalt", 0.031, "road")
	_flat(Rect2(17.5, 49.5, 54.5, 4.0), "asphalt", 0.032, "road")
	_flat(Rect2(100, -3, 6, 27), "asphalt", 0.033, "road")
	_flat(Rect2(54, -3, 52, 5.5), "dirt", 0.034, "dirt")
	# Parking pocket.
	_flat(Rect2(72, 26, 8, 22), "asphalt", 0.035, "parking", "Стоянка")
	for i in 8:
		var pz := 26.5 + i * 2.7
		_mb.add_box(Vector3(73.0, 0.035, pz), Vector3(79.5, 0.045, pz + 0.1), "road_line", line, Color.WHITE, Callable(), false)
	# Sidewalks along building fronts.
	_sidewalk(Rect2(29, 17.1, 26, 2.4))
	_sidewalk(Rect2(21, 53.5, 38, 2.4))
	_flat(Rect2(17.1, 23, 2.4, 26), "asphalt_light", 0.07, "sidewalk")
	_flat(Rect2(83.5, 24, 2.4, 14), "asphalt_light", 0.07, "sidewalk")
	# Paths through the courtyard.
	_flat(Rect2(19, 35, 11, 1.8), "asphalt_light", 0.06, "path")
	_flat(Rect2(50, 35, 16, 1.8), "asphalt_light", 0.06, "path")
	_flat(Rect2(52, 24, 1.8, 26), "asphalt_light", 0.061, "path")
	# Shop forecourts.
	_flat(Rect2(17, 80, 16, 2.6), "pavement", 0.081, "sidewalk")
	_flat(Rect2(83, 81, 12, 1.6), "pavement", 0.082, "sidewalk")


func _build_buildings() -> void:
	var b1 := PanelHouse.build(self, Vector3(54, 0, 17), 180.0,
		{"sections": 2, "floors": 5, "ext": "panel", "seed": 11, "name": "Дом 12", "address": "ул. Строителей, 12"})
	var b2 := PanelHouse.build(self, Vector3(17, 0, 24), -90.0,
		{"sections": 2, "floors": 5, "ext": "panel_dark", "seed": 22, "name": "Дом 14", "address": "ул. Строителей, 14"})
	var b3 := PanelHouse.build(self, Vector3(22, 0, 56), 0.0,
		{"sections": 3, "floors": 5, "ext": "panel", "seed": 33, "name": "Дом 10", "address": "ул. Строителей, 10"})
	var b4 := PanelHouse.build(self, Vector3(86, 0, 37), 90.0,
		{"sections": 1, "floors": 9, "ext": "panel_light", "seed": 44, "name": "Дом 16 (9 этажей)", "address": "ул. Строителей, 16"})
	var shop := ShopBuilding.grocery(self, Vector3(32, 0, 80), 180.0)
	var pharm := ShopBuilding.pharmacy(self, Vector3(94, 0, 81), 180.0)
	buildings = [b1, b2, b3, b4, shop, pharm]
	map_shapes.append([Rect2(30, 6, 24, 11), "building", "д. 12"])
	map_shapes.append([Rect2(6, 24, 11, 24), "building", "д. 14"])
	map_shapes.append([Rect2(22, 56, 36, 11), "building", "д. 10"])
	map_shapes.append([Rect2(86, 25, 11, 12), "building", "д. 16"])
	map_shapes.append([Rect2(18, 70, 14, 10), "shop", "Продукты"])
	map_shapes.append([Rect2(84, 72, 10, 9), "pharmacy", "Аптека"])


# ------------------------------------------------------------------------------------------------ test room
const TEST_CRATES := [
	["Оружие и патроны", [ItemData.Category.WEAPON, ItemData.Category.AMMO, ItemData.Category.TOOL]],
	["Еда и вода", [ItemData.Category.FOOD, ItemData.Category.DRINK]],
	["Медицина и снаряжение", [ItemData.Category.MEDICAL, ItemData.Category.CLOTHING, ItemData.Category.BAG,
		ItemData.Category.LIGHT, ItemData.Category.MISC]],
]


## Brick shed by the spawn ("Тестовая"): three army crates with every item in the game, piles of ammo
## and consumables. Toggle with Settings.test_room.
func _build_test_room() -> void:
	var w := 5.0
	var d := 4.0
	var b := Building.new()
	b.name = "Тестовая"
	b.display_name = "Тестовая"
	b.level_height = 3.0
	b.position = Vector3(48, 0, 48.6)
	b.rotation_degrees.y = 180.0
	b.footprint = Rect2(0, 0, w, d)
	add_child(b, true)
	var lb := LevelBuilder.new(b, 0, 9090)
	lb.set_exterior("brick")
	lb.add_room(Rect2(0, 0, w, d), "storage", "paint", Color("#b8b4a0"), "concrete_floor")
	var door := {"at": 2.5, "w": Door.width_of(Door.Kind.ENTRANCE), "bottom": 0.0, "top": Door.height_of(Door.Kind.ENTRANCE),
		"kind": "door", "door": Door.Kind.ENTRANCE, "open": true}
	lb.wall(Vector2(-0.15, 0), Vector2(w + 0.15, 0), 0.3, [door], true)
	lb.wall(Vector2(-0.15, d), Vector2(w + 0.15, d), 0.3, [], true)
	lb.wall(Vector2(0, 0.15), Vector2(0, d - 0.15), 0.3, [PanelHouse._win(2.0, 1.0)], true)
	lb.wall(Vector2(w, 0.15), Vector2(w, d - 0.15), 0.3, [PanelHouse._win(2.0, 1.0)], true)
	var y := lb.y0
	for i in TEST_CRATES.size():
		var spec: Array = TEST_CRATES[i]
		var c := Furnish.place("furniture/crate_army", lb.props, Vector3(0.95 + i * 1.55, y, d - 0.55), 180.0, "test",
			"Ящик: " + spec[0]) as LootContainer
		_fill_test_crate(c, spec[1])
	Furnish.place("furniture/stool", lb.props, Vector3(4.4, y, 1.0), 30.0, "test")
	lb.commit()
	ShopBuilding._flat_roof(b, w, d, "brick")
	var sign_label := Label3D.new()
	sign_label.text = "ТЕСТОВАЯ"
	sign_label.font_size = 64
	sign_label.pixel_size = 0.006
	sign_label.modulate = Color("#e8d8a0")
	sign_label.outline_size = 12
	sign_label.position = Vector3(2.5, 2.55, -0.2)
	sign_label.rotation_degrees.y = 180.0
	b.add_child(sign_label)
	# The label is not cut away with the wall, so hide it while the player is inside.
	Events.player_location_changed.connect(func(bld: Node, _lvl: int) -> void: sign_label.visible = bld != b)
	buildings.append(b)
	map_shapes.append([Rect2(43, 44.6, 5, 4), "misc", "Тестовая"])


func _fill_test_crate(c: LootContainer, cats: Array) -> void:
	c.searched = true
	c.search_time = 0.3
	for id in ItemDB.items:
		var data: ItemData = ItemDB.items[id]
		if not data.category in cats:
			continue
		var copies := 2
		var amount := 1
		if data.category == ItemData.Category.AMMO:
			copies = 10
			amount = data.max_stack
		elif data.is_stackable():
			copies = 3
			amount = data.max_stack
		elif data.uses > 1:
			copies = 4
		if id == "keys":
			copies = 8
		for i in copies:
			var s := ItemStack.create(data, amount)
			if data.magazine > 0:
				s.loaded = data.magazine
			c.inventory.add(s, true)
	if c.inventory.find_by_id("keys"):
		c.call("_assign_keys")


func _build_courtyard() -> void:
	# Playground on sand.
	_flat(Rect2(30, 27, 20, 16), "sand", 0.05, "playground", "Детская площадка")
	prop("environment/swing", Vector3(35, 0.05, 30.5), 0.0)
	prop("environment/slide", Vector3(44.5, 0.05, 31), 90.0)
	prop("environment/carousel", Vector3(40, 0.05, 38), 0.0)
	prop("environment/sandbox", Vector3(34, 0.05, 39.5), 0.0)
	prop("environment/horizontal_bar", Vector3(47, 0.05, 40), 90.0)
	for b in [[Vector3(31, 0.05, 34), 90.0], [Vector3(49, 0.05, 34), -90.0], [Vector3(40, 0.05, 42.2), 180.0], [Vector3(40, 0.06, 28.2), 0.0]]:
		Furnish.place("environment/bench", _static, b[0], b[1], "outside")
	prop("environment/urn", Vector3(31, 0.05, 36.2))
	prop("environment/urn", Vector3(49, 0.05, 31.8))
	# Garbage site with three containers behind low concrete walls.
	_flat(Rect2(56, 43, 7, 5), "concrete", 0.06, "trash", "Мусорка")
	var wall := Mats.surface("concrete")
	for r in [[Vector3(56, 0, 43), Vector3(56.15, 1.4, 48)], [Vector3(62.85, 0, 43), Vector3(63, 1.4, 48)], [Vector3(56, 0, 43), Vector3(63, 1.4, 43.15)]]:
		_mb.add_box(r[0], r[1], "concrete", wall)
	for i in 3:
		prop("environment/dumpster", Vector3(57.4 + i * 2.1, 0.06, 44.2), 180.0 + randf_range(-6, 6))
	for p in [Vector3(57, 0.06, 47), Vector3(61.5, 0.06, 47.5), Vector3(63.8, 0, 46), Vector3(55.2, 0, 45.6)]:
		prop("environment/trash_bag", p, randf() * 360.0, false)
	prop("environment/cardboard", Vector3(64, 0, 44), 40.0)
	prop("environment/tire", Vector3(55, 0, 48.2), 0.0)
	# Parking with abandoned cars.
	_car("vehicles/car_beige", Vector3(76.2, 0.04, 28.0), -90.0, false)
	_car("vehicles/car_blue", Vector3(76.0, 0.04, 33.4), -88.0, true)
	_car("vehicles/car_white", Vector3(76.4, 0.04, 41.6), -96.0, false)
	_car("vehicles/car_red", Vector3(69.0, 0.04, 44.0), 8.0, false)
	# Transformer booth and fence.
	prop("environment/transformer", Vector3(22, 0, 12), 90.0)
	map_shapes.append([Rect2(20.7, 10.5, 2.6, 3), "misc", ""])
	for i in 30:
		prop("environment/concrete_fence", Vector3(-8 + i * 4.0, 0, -12.5), 0.0)
	for i in 26:
		if i == 22 or i == 24:
			continue
		prop("environment/concrete_fence", Vector3(116, 0, -10.5 + i * 4.0), 90.0)
	# Courtyard lamps.
	for p in [[Vector3(64.5, 0, 26), 90.0], [Vector3(64.5, 0, 52), 90.0], [Vector3(25, 0, 51.5), 0.0]]:
		_streetlight(p[0], p[1])


func _build_street() -> void:
	for i in 7:
		_streetlight(Vector3(2 + i * 18.0, 0.08, 85.4), 0.0)
	var stop := prop("environment/bus_stop", Vector3(50, 0.08, 84.3), 0.0, false)
	if stop:
		Props.add_box(_static, Vector3(50, 1.3, 84.9), Vector3(4.0, 2.6, 0.1))
		Props.add_box(_static, Vector3(48.1, 1.3, 84.3), Vector3(0.1, 2.6, 1.2))
		Props.add_box(_static, Vector3(51.9, 1.3, 84.3), Vector3(0.1, 2.6, 1.2))
		Props.add_box(_static, Vector3(50, 0.3, 84.7), Vector3(3.0, 0.4, 0.35))
	map_shapes.append([Rect2(48, 83.5, 4, 1.5), "stop", "Остановка"])
	prop("environment/sign_bus", Vector3(46.8, 0.08, 85.7), 0.0)
	prop("environment/kiosk", Vector3(56.5, 0.08, 83.6), 0.0)
	map_shapes.append([Rect2(55.2, 82.6, 2.6, 2), "misc", "Ларёк"])
	prop("environment/sign_crossing", Vector3(61.4, 0.08, 85.7), 0.0)
	prop("environment/sign_crossing", Vector3(68.8, 0.08, 94.4), 180.0)
	prop("environment/sign_giveway", Vector3(72.6, 0.08, 85.6), 0.0)
	prop("environment/sign_stop", Vector3(65.4, 0.08, 85.8), 0.0)
	prop("environment/billboard", Vector3(30, 0, 98.5), 180.0)
	# Wrecks on the road.
	_car("vehicles/car_red", Vector3(38, 0.02, 90.6), 74.0, false)
	_car("vehicles/car_white", Vector3(84, 0.08, 84.2), 12.0, true)
	_car("vehicles/car_blue", Vector3(102, 0.02, 88.3), -95.0, false)
	prop("environment/trash_bag", Vector3(36, 0.08, 83.4), 0.0, false)
	prop("environment/cardboard", Vector3(34.2, 0.08, 81.4), 15.0)
	# South side: fence and wasteland.
	for i in 30:
		if i % 7 == 3 or i == 16 or i == 17:
			continue
		prop("environment/concrete_fence", Vector3(-8 + i * 4.0, 0, 101.5), 0.0)


## Abandoned car: the glovebox is searchable; some still have a live alarm.
func _car(asset: String, pos: Vector3, rot: float, alarm: bool) -> void:
	var c := LootContainer.new()
	c.display_name = "Машина"
	c.container_type = "car"
	c.room_type = "car"
	c.search_time = 2.2
	c.focus_offset = Vector3(0.95, 1.0, -0.3)
	c.position = pos
	c.rotation_degrees.y = rot
	var m := Props.spawn(asset, c, Vector3.ZERO, 0.0)
	c.model = m
	if alarm:
		var a := CarAlarm.new()
		a.name = "CarAlarm"
		c.add_child(a)
		c.searched_hook = func() -> void:
			if randf() < 0.7:
				a.trigger()
	_static.add_child(c)


func _streetlight(pos: Vector3, rot: float) -> void:
	prop("environment/streetlight", pos, rot, false)
	_trunk_collider(pos, 0.15)
	var light := SpotLight3D.new()
	light.position = pos + Basis(Vector3.UP, deg_to_rad(rot)) * Vector3(0, 7.3, 1.45)
	light.rotation_degrees = Vector3(-90, 0, 0)
	light.spot_range = 13.0
	light.spot_angle = 58.0
	light.spot_attenuation = 0.6
	light.light_energy = 0.0
	light.light_color = Color("#ffd49a")
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 26.0
	light.distance_fade_length = 8.0
	light.add_to_group("street_lamps")
	_static.add_child(light)
	# Fake volumetric cone under the lamp head (DayNight shows it with the lamps).
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 2.4
	cm.height = 6.9
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 16
	cone.mesh = cm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/lamp_cone.gdshader")
	cone.material_override = mat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.position = light.position - Vector3(0, 3.5, 0)
	cone.visible = false
	cone.add_to_group("lamp_cones")
	_static.add_child(cone)


func _build_garages() -> void:
	for i in 12:
		var g := "environment/garage_rust" if i % 3 == 1 else "environment/garage"
		prop(g, Vector3(58.0 + i * 3.3, 0, -6.0), 0.0)
		if i in [1, 4, 7, 10]:
			var gc := LootContainer.new()
			gc.display_name = "Гараж №%d" % (i + 31)
			gc.container_type = "garage"
			gc.room_type = "garage"
			gc.search_time = 3.0
			gc.focus_offset = Vector3(0, 1.0, 0)
			gc.position = Vector3(58.0 + i * 3.3, 0, -2.7)
			_static.add_child(gc)
	map_shapes.append([Rect2(56.4, -9, 39.6, 6), "garage", "Гаражи"])
	prop("environment/tire", Vector3(62, 0.03, -2.2), 0.0)
	prop("environment/tire", Vector3(62.5, 0.25, -2.0), 30.0)
	prop("environment/pallet", Vector3(90, 0.03, -2.0), 10.0, false)
	_car("vehicles/car_blue", Vector3(84.0, 0.03, -0.2), 90.0, false)


func _build_greenery() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 2024
	# Poplars along the street.
	var x := 0.0
	while x < 112.0:
		if not (x > 14 and x < 36) and not (x > 80 and x < 98) and not (x > 46 and x < 60) and not (x > 60 and x < 74):
			_tree("environment/poplar_%d" % (1 + r.randi() % 2), Vector3(x + r.randf_range(-1, 1), 0, 81.2 + r.randf_range(-0.3, 0.3)))
		x += 8.5
	# Courtyard birches and a dead tree.
	for p in [Vector3(26, 0, 28), Vector3(25, 0, 44), Vector3(55, 0, 30), Vector3(58, 0, 38), Vector3(29, 0, 47),
			Vector3(62, 0, 51), Vector3(80, 0, 14), Vector3(24, 0, 64), Vector3(61, 0, 62), Vector3(9, 0, 52),
			Vector3(12, 0, 16), Vector3(82, 0, 52), Vector3(100, 0, 40), Vector3(105, 0, 60), Vector3(8, 0, 70)]:
		_tree("environment/birch_%d" % (1 + r.randi() % 2), p)
	for p in [Vector3(26, 0, 28), Vector3(55, 0, 30), Vector3(29, 0, 47), Vector3(61, 0, 62), Vector3(82, 0, 52), Vector3(24, 0, 64)]:
		Smoke.leaves(_static, p)
	_tree("environment/dead_tree", Vector3(90, 0, 50))
	_tree("environment/dead_tree", Vector3(3, 0, 6))
	# Bushes along façades and the courtyard.
	for p in [Vector3(28, 0, 16), Vector3(56, 0, 16), Vector3(20.5, 0, 25), Vector3(20.5, 0, 47), Vector3(60.5, 0, 57),
			Vector3(20, 0, 58), Vector3(84, 0, 39.5), Vector3(84, 0, 18), Vector3(51, 0, 45), Vector3(29, 0, 41),
			Vector3(66, 0, 66), Vector3(98, 0, 70), Vector3(15, 0, 76), Vector3(3, 0, 60)]:
		prop("environment/bush_%d" % (1 + r.randi() % 2), p, r.randf() * 360.0, false)


func _tree(asset: String, pos: Vector3) -> void:
	tree_points.append(pos)
	prop(asset, pos, randf() * 360.0, false)
	_trunk_collider(pos, 0.25)


## Drivable cars: one with the keys in the ignition by the courtyard parking, one in the private sector
## (key in a house on Садовая), a militia off-roader by the police (key in the duty desk) and one at the
## gas station with no key at all (hotwire it).
func _build_vehicles() -> void:
	_vehicle("res://assets/vehicles/sedan_body_ochre.glb", "Седан (охра)", Vector3(69.0, 0.3, 37.0), 180.0, "", 18.0)
	var green := _vehicle("res://assets/vehicles/sedan_body_green.glb", "Седан (зелёный)", Vector3(60.0, 0.3, 140.0), 0.0, "car_green", 26.0)
	_vehicle("res://assets/vehicles/sedan_body_white.glb", "Седан (белый)", Vector3(151.0, 0.36, 109.0), 90.0, "car_white", 6.0)
	var uaz := _vehicle("res://assets/vehicles/uaz_body.glb", "Полицейский внедорожник", Vector3(150.0, 0.36, 82.5), -90.0, "car_uaz", 32.0,
		{"all_wheel": true, "engine_force": 9000.0, "top_speed": 21.0, "body_size": Vector3(1.8, 1.1, 4.05)})
	_car_key_to(green, Vector3(70, 0, 112))
	_car_key_to(uaz, Vector3(150, 0, 77))
	map_shapes.append([Rect2(68, 35, 2, 4), "car", ""])


func _vehicle(model: String, nice: String, pos: Vector3, rot: float, key: String, fuel: float, extra := {}) -> Vehicle:
	var v := Vehicle.new()
	v.name = "Vehicle_" + nice.validate_node_name()
	v.model_path = model
	v.display_name = nice
	v.key_id = key
	for k in extra:
		v.set(k, extra[k])
	v.position = pos
	v.rotation_degrees.y = rot
	v.fuel = fuel
	add_child(v, true)
	return v


## Puts the car's key into the nearest searchable container to `near` (checked on first search).
func _car_key_to(v: Vehicle, near: Vector3) -> void:
	var best: LootContainer = null
	for c in get_tree().get_nodes_in_group("containers"):
		var lc := c as LootContainer
		if lc.container_type in ["corpse", "trunk", "crate"]:
			continue
		if best == null or lc.global_position.distance_to(near) < best.global_position.distance_to(near):
			best = lc
	if best:
		var k := ItemDB.make("car_key")
		k.key_id = v.key_id
		k.custom_name = "Ключи: " + v.display_name
		best.bonus_items.append(k)
