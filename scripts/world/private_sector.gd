class_name PrivateSector
extends RefCounted
## "Частный сектор" south of ул. Строителей: two gravel streets (Садовая, Лесная) and a lane (пер. Колхозный),
## 24 plots with log houses, burned ruins and vegetable gardens behind picket fences, sheds, wells,
## woodpiles, outhouses, a village store and wooden power poles with sagging wires.

const STREETS := [
	# name, lane z0, lane z1
	["ул. Садовая", 117.5, 122.5],
	["ул. Лесная", 167.5, 172.5],
]
const LANE_X := Vector2(57.5, 62.5)
const PLOT_W := 18.0
const PLOT_XS := [-3.0, 15.0, 33.0, 64.0, 82.0, 100.0]
const FENCE_COLORS := [Color("#7a8a6a"), Color("#6a7a8a"), Color("#8a7a5a"), Color("#8a6a5a"), Color("#9a9a8a")]

## What stands on each plot (row-major: Садовая north, Садовая south, Лесная north, Лесная south).
const PLAN := [
	"izba", "izba", "ruin", "izba", "garden", "izba",
	"izba", "garden", "izba", "store", "izba", "ruin",
	"ruin", "izba", "izba", "izba", "garden", "izba",
	"izba", "izba", "garden", "ruin", "izba", "izba",
]

static var houses: Array[Building] = []


static func build(d: District) -> void:
	houses.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	for s in STREETS:
		d._flat(Rect2(-6, s[1], 136, s[2] - s[1]), "gravel", 0.04, "dirt", s[0])
	d._flat(Rect2(LANE_X.x, 96.5, LANE_X.y - LANE_X.x, 104), "gravel", 0.041, "dirt", "")
	d.map_shapes.append([Rect2(LANE_X.x - 12, 140, 10, 4), "label", "пер. Колхозный"])
	var house_no := 1
	for row in 4:
		var street: Array = STREETS[floori(row / 2.0)]
		var north := row % 2 == 0
		var edge: float = street[1] if north else street[2]
		for i in PLOT_XS.size():
			var kind: String = PLAN[row * PLOT_XS.size() + i]
			var px: float = PLOT_XS[i]
			var depth := 14.5 if north and row == 0 else 17.0
			_plot(d, rng, px, edge, north, depth, kind, house_no, street[0])
			house_no += 1
	_poles(d)
	# Potato field and the edge of the forest behind Лесная.
	d._flat(Rect2(4, 194, 50, 14), "dirt", 0.035, "dirt", "Колхозное поле")
	for x in range(6, 54, 3):
		d._mb.add_box(Vector3(x, 0.035, 195), Vector3(x + 1.2, 0.12, 207), "dirt", Mats.surface("dirt"), Color.WHITE, Callable(), false)


## Plot-local (u along the street, v away from it) to world.
static func _w(px: float, edge: float, north: bool, u: float, v: float) -> Vector3:
	return Vector3(px + u, 0.0, edge - v if north else edge + v)


static func _plot(d: District, rng: RandomNumberGenerator, px: float, edge: float, north: bool, depth: float,
		kind: String, no: int, street: String) -> void:
	var fc: Color = FENCE_COLORS[rng.randi() % FENCE_COLORS.size()]
	var gate_u := 3.0
	# Picket fence: along the street (gate gap), one side, the back (with gaps where it fell).
	_fence_x(d, rng, px + 0.2, px + gate_u - 0.3, _w(px, edge, north, 0, 0.8).z, fc)
	_fence_x(d, rng, px + gate_u + 1.4, px + PLOT_W - 0.2, _w(px, edge, north, 0, 0.8).z, fc)
	var zf := _w(px, edge, north, 0, 0.8).z
	var zb := _w(px, edge, north, 0, depth).z
	_fence_z(d, rng, px + 0.2, minf(zf, zb), maxf(zf, zb), fc)
	if rng.randf() < 0.6:
		_fence_x(d, rng, px + 0.2, px + PLOT_W - 0.2, zb, fc)
	var rot := 180.0 if north else 0.0
	var addr := "%s, %d" % [street, no]
	match kind:
		"izba":
			var w := rng.randf_range(6.6, 7.8)
			var dd := rng.randf_range(6.0, 6.8)
			var front := _w(px, edge, north, 0, 4.0)
			var pos := Vector3(px + 2.8 + (w if north else 0.0), 0, front.z)
			var b := Izba.build(d, pos, rot, {"seed": no * 13 + 5, "name": "Дом %d" % no, "address": addr,
				"w": w, "d": dd, "locked": rng.randf() < 0.35})
			d.buildings.append(b)
			houses.append(b)
			var r0 := _w(px, edge, north, 2.8, 4.0)
			var r1 := _w(px, edge, north, 2.8 + w, 4.0 + dd)
			d.map_shapes.append([Rect2(minf(r0.x, r1.x), minf(r0.z, r1.z), absf(r1.x - r0.x), absf(r1.z - r0.z)), "house", str(no)])
			_yard(d, rng, px, edge, north, depth, 4.0 + dd)
		"ruin":
			var p := _w(px, edge, north, 6.0, 7.5)
			d.prop("environment/ruin_house", p, rot + rng.randf_range(-8, 8))
			d._flat(Rect2(p.x - 4.5, p.z - 4.5, 9, 9), "soot", 0.03, "ruin", "")
			if rng.randf() < 0.6:
				Smoke.column(d._static, p + Vector3(1.3, 3.4, 0.8), 0.4)
			_yard(d, rng, px, edge, north, depth, 11.0, true)
		"garden":
			for j in 4:
				d.prop("environment/garden_bed", _w(px, edge, north, 3.5 + (j % 2) * 7.0, 4.0 + floorf(j / 2.0) * 4.0), 0.0, false)
			Furnish.place("environment/shed", d._static, _w(px, edge, north, 14.0, depth - 2.5), rot, "village")
			d.map_shapes.append([Rect2(px + 1, minf(edge, _w(px, edge, north, 0, depth).z), PLOT_W - 2, depth - 1), "garden", ""])
		"store":
			var sp := Vector3(px + 3.0, 0, _w(px, edge, north, 0, 3.0).z)
			var st := _village_store(d, sp, rot)
			d.buildings.append(st)
			d.map_shapes.append([Rect2(px + 3, sp.z, 10, 7), "shop", "Магазин"])


static func _yard(d: District, rng: RandomNumberGenerator, px: float, edge: float, north: bool, depth: float,
		behind: float, burned := false) -> void:
	var rot := 180.0 if north else 0.0
	if not burned or rng.randf() < 0.5:
		Furnish.place("environment/shed", d._static, _w(px, edge, north, 14.2, minf(behind + 2.5, depth - 1.8)), rot + 90.0, "village")
	d.prop("environment/outhouse", _w(px, edge, north, 16.6, depth - 1.0), rot)
	if not burned:
		Furnish.place("environment/woodpile", d._static, _w(px, edge, north, 11.0, behind + 0.8), rot, "village")
	if rng.randf() < 0.45:
		var wl := Well.new()
		wl.position = _w(px, edge, north, 11.5, 2.6)
		wl.rotation_degrees.y = rot
		d._static.add_child(wl)
		Props.spawn("environment/well", wl, Vector3.ZERO, 0.0)
	for j in rng.randi_range(1, 3):
		d.prop("environment/garden_bed", _w(px, edge, north, 12.0 + (j % 2) * 3.4, 5.5 + j * 1.6), 90.0, false)
	if rng.randf() < 0.6:
		d._tree("environment/apple_tree", _w(px, edge, north, rng.randf_range(4, 9), behind + rng.randf_range(1.5, 3.5)))
	if rng.randf() < 0.35:
		d.prop("environment/dog_booth", _w(px, edge, north, 9.0, 3.0), rot + 30.0)
	if rng.randf() < 0.5:
		d.prop("environment/barrel_rust", _w(px, edge, north, 1.2, behind - 0.5), 0.0)
	if rng.randf() < 0.4:
		Furnish.place("environment/bench", d._static, _w(px, edge, north, 6.5, 0.3), rot + 180.0, "outside")
	# Footpath from the gate to the porch.
	var a := _w(px, edge, north, 3.2, 0.0)
	var b := _w(px, edge, north, 4.4, 4.0)
	d._flat(Rect2(minf(a.x, b.x), minf(a.z, b.z), absf(b.x - a.x), absf(b.z - a.z)), "dirt", 0.03, "", "", false)


## Picket fence along x at world z (pickets merged into the ground mesh, one collision box per line).
static func _fence_x(d: District, rng: RandomNumberGenerator, x0: float, x1: float, z: float, c: Color) -> void:
	if x1 - x0 < 0.4:
		return
	var m := Mats.surface("fence_paint")
	var post := Mats.surface("planks")
	var x := x0
	while x < x1:
		if rng.randf() > 0.06:
			var h := 1.22 + rng.randf_range(-0.07, 0.05)
			var col := c if rng.randf() > 0.15 else Color("#8a8478")
			d._mb.add_box(Vector3(x, 0.0, z - 0.012), Vector3(x + 0.09, h, z + 0.012), "fence_paint", m, col, Callable(), false)
		x += 0.2
	for y in [0.35, 0.95]:
		d._mb.add_box(Vector3(x0, y, z + 0.012), Vector3(x1, y + 0.07, z + 0.05), "planks", post, Color.WHITE, Callable(), false)
	var p := x0
	while p <= x1 + 0.01:
		d._mb.add_box(Vector3(p - 0.05, 0.0, z + 0.012), Vector3(p + 0.05, 1.35, z + 0.11), "planks", post, Color.WHITE, Callable(), false)
		p += 2.0
	d._mb.add_collision(Vector3((x0 + x1) * 0.5, 0.7, z + 0.03), Vector3(x1 - x0, 1.4, 0.12))


static func _fence_z(d: District, rng: RandomNumberGenerator, x: float, z0: float, z1: float, c: Color) -> void:
	if z1 - z0 < 0.4:
		return
	var m := Mats.surface("fence_paint")
	var post := Mats.surface("planks")
	var z := z0
	while z < z1:
		if rng.randf() > 0.06:
			var h := 1.22 + rng.randf_range(-0.07, 0.05)
			d._mb.add_box(Vector3(x - 0.012, 0.0, z), Vector3(x + 0.012, h, z + 0.09), "fence_paint", m, c, Callable(), false)
		z += 0.2
	for y in [0.35, 0.95]:
		d._mb.add_box(Vector3(x + 0.012, y, z0), Vector3(x + 0.05, y + 0.07, z1), "planks", post, Color.WHITE, Callable(), false)
	d._mb.add_collision(Vector3(x + 0.03, 0.7, (z0 + z1) * 0.5), Vector3(0.12, 1.4, z1 - z0))


## Wooden poles along both streets and the lane, with three wires per span.
static func _poles(d: District) -> void:
	for s in STREETS:
		var pts: Array[Vector3] = []
		var x := -4.0
		while x < 128.0:
			pts.append(Vector3(x, 0, float(s[1]) - 0.4))
			x += 22.0
		_pole_line(d, pts, 0.0)
	var lane: Array[Vector3] = []
	var z := 104.0
	while z < 200.0:
		lane.append(Vector3(LANE_X.x - 0.5, 0, z))
		z += 24.0
	_pole_line(d, lane, 90.0)


static func _pole_line(d: District, pts: Array[Vector3], rot: float) -> void:
	var wire := Mats.surface("metal_dark")
	for p in pts:
		d.prop("environment/power_pole", p, rot, false)
		d._trunk_collider(p, 0.13)
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var along := (b - a).normalized()
		var side := Vector3(-along.z, 0, along.x)
		for off in [-0.7, 0.25, 0.7]:
			var pa: Vector3 = a + side * off + Vector3(0, 7.15, 0)
			var pb: Vector3 = b + side * off + Vector3(0, 7.15, 0)
			# Two segments with a sag in the middle.
			var mid: Vector3 = (pa + pb) * 0.5 + Vector3(0, -0.45, 0)
			for seg in [[pa, mid], [mid, pb]]:
				var s0: Vector3 = seg[0]
				var s1: Vector3 = seg[1]
				var dir := s1 - s0
				var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
				d._mb.add_obox((s0 + s1) * 0.5, Vector3(0.025, 0.025, dir.length()), basis, "metal_dark", wire)


static func _village_store(d: District, pos: Vector3, rot: float) -> Building:
	var w := 10.0
	var dd := 7.0
	var b := Building.new()
	b.name = "Магазин"
	b.display_name = "Магазин «Сельпо»"
	b.level_height = 3.2
	b.position = pos + (Vector3(w, 0, 0) if rot == 180.0 else Vector3.ZERO)
	b.rotation_degrees.y = rot
	b.footprint = Rect2(0, 0, w, dd)
	d.add_child(b, true)
	var lb := LevelBuilder.new(b, 0, 5151)
	lb.set_exterior("brick_red")
	lb.door_open_chance = 0.0
	lb.window_broken_chance = 0.4
	lb.add_room(Rect2(0, 0, w, 4.8), "shop", "paint", Color("#c8c0a8"), "wood_floor")
	lb.add_room(Rect2(0, 4.8, w, dd - 4.8), "storage", "paint", Color("#a8a490"), "concrete_floor")
	lb.wall(Vector2(-0.15, 0), Vector2(w + 0.15, 0), 0.3, [PanelHouse._door(5.0, Door.Kind.INTERIOR, false, true),
		PanelHouse._win(2.2, 1.6), PanelHouse._win(7.8, 1.6)], true)
	lb.wall(Vector2(-0.15, dd), Vector2(w + 0.15, dd), 0.3, [PanelHouse._door(8.5, Door.Kind.INTERIOR, true)], true)
	lb.wall(Vector2(0, 0.15), Vector2(0, dd - 0.15), 0.3, [], true)
	lb.wall(Vector2(w, 0.15), Vector2(w, dd - 0.15), 0.3, [PanelHouse._win(2.4, 1.2)], true)
	lb.wall(Vector2(0, 4.8), Vector2(w, 4.8), 0.12, [PanelHouse._door(1.5, Door.Kind.INTERIOR)])
	var P := lb.props
	var y := lb.y0
	for x in [3.0, 5.0, 7.0]:
		Furnish.place("furniture/shop_shelf", P, Vector3(x, y, 4.5), 180.0, "shop")
	Furnish.place("furniture/shop_counter", P, Vector3(8.8, y, 2.2), -90.0, "shop")
	Furnish.place("furniture/drink_fridge", P, Vector3(0.45, y, 2.5), 90.0, "shop")
	Furnish.place("furniture/shop_shelf", P, Vector3(3.0, y, 6.7), 180.0, "storage", "Склад")
	Furnish.place("furniture/shop_shelf", P, Vector3(5.0, y, 6.7), 180.0, "storage", "Склад")
	Props.spawn("environment/cardboard", P, Vector3(7.5, y, 6.0), 20.0)
	lb.commit()
	ShopBuilding._flat_roof(b, w, dd, "brick_red")
	var sign_label := Label3D.new()
	sign_label.text = "ПРОДУКТЫ"
	sign_label.font_size = 56
	sign_label.pixel_size = 0.006
	sign_label.modulate = Color("#e8d8a0")
	sign_label.outline_size = 0
	sign_label.position = Vector3(5.0, 2.75, -0.2)
	sign_label.rotation_degrees.y = 180.0
	b.add_child(sign_label)
	return b
