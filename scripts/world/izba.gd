class_name Izba
extends RefCounted
## Village house of the private sector: a log cabin (сруб) on one floor. Entry hall (сени), a living room
## (горница) with a bed, a chest and the icon corner, a kitchen with the Russian stove and a cellar hatch,
## and a gable roof of painted corrugated sheets. Local frame: z = 0 is the street front, x along it.

const T_EXT := 0.26
const T_INT := 0.1
const ROOFS := ["tin_roof_red", "tin_roof_green", "tin_roof_grey", "tin_roof_blue"]
const WALL_COLORS := [Color("#d8ccb0"), Color("#c8d0c0"), Color("#d0c0b0"), Color("#c8c4d0")]


static func _win(at: float, w := 0.85) -> Dictionary:
	return {"at": at, "w": w, "bottom": 0.8, "top": 1.85, "kind": "window"}


## params: seed, name, address, w, d, locked (front door needs a key), tv
static func build(parent: Node3D, pos: Vector3, rot_deg: float, params: Dictionary) -> Building:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(params.get("seed", 1))
	var w: float = params.get("w", 7.2)
	var d: float = params.get("d", 6.4)
	var b := Building.new()
	b.name = params.get("name", "Изба")
	b.display_name = params.get("name", "Изба")
	b.address = params.get("address", "")
	b.level_height = 2.75
	b.base_y = 0.1
	b.position = pos
	b.rotation_degrees.y = rot_deg
	b.footprint = Rect2(0, 0, w, d)
	parent.add_child(b, true)
	var lb := LevelBuilder.new(b, 0, int(params.get("seed", 1)) * 31)
	lb.set_exterior("logs" if rng.randf() < 0.7 else "logs_dark")
	lb.door_open_chance = 0.35
	lb.window_broken_chance = 0.18
	var hall_w := 2.2
	var split := d * 0.55
	var wc: Color = WALL_COLORS[rng.randi() % WALL_COLORS.size()]
	lb.add_room(Rect2(0, 0, hall_w, d), "hall", "planks_int", Color("#c8b89a"), "wood_floor", Color("#b0a090"))
	lb.add_room(Rect2(hall_w, 0, w - hall_w, split), "village", "whitewash", wc, "wood_floor")
	lb.add_room(Rect2(hall_w, split, w - hall_w, d - split), "village_kitchen", "whitewash", Color("#e0dccc"), "wood_floor")
	var locked: bool = params.get("locked", false)
	var front_door := PanelHouse._door(1.1, Door.Kind.INTERIOR, locked)
	if locked:
		front_door["open"] = false
	if locked:
		front_door["key_id"] = "izba_%d" % int(params.get("seed", 1))
		front_door["key_label"] = params.get("address", "изба")
	var lw := w - hall_w
	lb.wall(Vector2(-0.13, 0), Vector2(w + 0.13, 0), T_EXT, [front_door, _win(hall_w + lw * 0.3), _win(hall_w + lw * 0.75)], true)
	lb.wall(Vector2(-0.13, d), Vector2(w + 0.13, d), T_EXT, [_win(hall_w + lw * 0.5), PanelHouse._door(1.1, Door.Kind.INTERIOR)], true)
	lb.wall(Vector2(0, 0.13), Vector2(0, d - 0.13), T_EXT, [], true)
	lb.wall(Vector2(w, 0.13), Vector2(w, d - 0.13), T_EXT, [_win(split * 0.5), _win(split + (d - split) * 0.5, 0.7)], true)
	lb.wall(Vector2(hall_w, 0.05), Vector2(hall_w, d - 0.05), T_INT,
		[PanelHouse._door(split * 0.45, Door.Kind.INTERIOR), PanelHouse._door(split + (d - split) * 0.6, Door.Kind.INTERIOR)])
	lb.wall(Vector2(hall_w, split), Vector2(w, split), T_INT, [PanelHouse._arch(w - 0.75, 0.9)])
	_furnish(lb, rng, w, d, hall_w, split, params)
	lb.commit()
	_porch(b, d)
	_gable_roof(b, w, d, ROOFS[rng.randi() % ROOFS.size()])
	return b


static func _furnish(lb: LevelBuilder, rng: RandomNumberGenerator, w: float, d: float, hall_w: float, split: float,
		params: Dictionary) -> void:
	var P := lb.props
	var y := lb.y0
	# Kitchen: the stove against the partition, table by the window, cupboard, cellar hatch.
	Campfire.build_stove(P, Vector3(hall_w + 0.82, y, split + 0.92), 90.0)
	Furnish.place("furniture/kitchen_cabinet", P, Vector3(w - 0.35, y, d - 1.2), -90.0, "village")
	Furnish.place("furniture/kitchen_table", P, Vector3(hall_w + (w - hall_w) * 0.62, y, d - 0.6), 0.0, "village")
	Furnish.place("furniture/stool", P, Vector3(hall_w + (w - hall_w) * 0.62, y, d - 1.2), rng.randf() * 360.0, "village")
	Furnish.place("furniture/cellar_hatch", P, Vector3(w - 1.3, y + 0.005, split + 0.8), 0.0, "village")
	if rng.randf() < 0.5:
		Furnish.place("furniture/wall_cabinet", P, Vector3(w - 0.2, y + 1.45, d - 2.3), -90.0, "village")
	# Living room.
	Furnish.place("furniture/bed", P, Vector3(w - 1.0, y, 1.1), -90.0, "village")
	Furnish.place("furniture/chest", P, Vector3(hall_w + 0.6, y, 0.5), 0.0, "village")
	Furnish.place("furniture/wardrobe", P, Vector3(hall_w + 0.4, y, split - 0.75), 90.0, "village")
	Furnish.place("furniture/kitchen_table", P, Vector3(hall_w + 1.9, y, split * 0.5), 90.0, "village", "Стол")
	Furnish.place("furniture/chair", P, Vector3(hall_w + 1.3, y, split * 0.5), 90.0, "village")
	Props.spawn("furniture/icon_corner", P, Vector3(w - 0.3, y + 1.85, 0.3), 225.0, false)
	Props.spawn("furniture/carpet_wall", P, Vector3(w - 0.17, y + 0.9, 1.1), -90.0, false)
	if params.get("tv", rng.randf() < 0.4):
		Furnish.place("furniture/tv", P, Vector3(hall_w + 1.9, y + 0.76, split * 0.5 + 0.2), -90.0, "village")
	# Hall: firewood, boots and clutter.
	if rng.randf() < 0.6:
		Furnish.place("environment/woodpile", P, Vector3(0.5, y, d - 1.2), 90.0, "village", "Дрова в сенях")
	Props.spawn("environment/barrel_rust" if rng.randf() < 0.5 else "environment/cardboard", P, Vector3(1.6, y, d - 0.5), rng.randf() * 360.0)
	for i in rng.randi_range(0, 2):
		Props.spawn("environment/trash_bag", P, Vector3(rng.randf_range(0.4, 1.8), y, rng.randf_range(1.5, d - 1.5)), rng.randf() * 360.0, false)


## Wooden steps and a little canopy over the front door.
static func _porch(b: Building, _d: float) -> void:
	var mb := MeshBuilder.new(b.levels[0].get_node("Body") as StaticBody3D)
	var wood := Mats.surface("planks")
	mb.add_box(Vector3(0.3, 0.0, -1.2), Vector3(1.9, 0.07, -0.13), "planks", wood)
	mb.add_box(Vector3(0.25, 2.45, -1.2), Vector3(1.95, 2.52, -0.13), "planks", wood, Color.WHITE, Callable(), false)
	for x in [0.32, 1.88]:
		mb.add_box(Vector3(x - 0.05, 0.07, -1.15), Vector3(x + 0.05, 2.45, -1.05), "planks", wood, Color.WHITE, Callable(), false)
	b.levels[0].add_child(mb.commit("Porch"))


## Gable roof, ridge along x, painted corrugated sheets; planked gables. Hidden while the player is inside.
static func _gable_roof(b: Building, w: float, d: float, roof_key: String) -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	b.add_child(roof)
	b.roof = roof
	var mb := MeshBuilder.new()
	var y := b.level_y(1) - LevelBuilder.SLAB + 0.05
	var o := 0.45
	var rise := 1.9
	var rm := Mats.surface(roof_key)
	var gm := Mats.surface("planks")
	var x0 := -o
	var x1 := w + o
	var zf := -o
	var zb := d + o
	var zr := d * 0.5
	var yr := y + rise + o * rise / (d * 0.5)
	var ye := y - o * rise / (d * 0.5) * 0.0
	# Two slopes (with a little thickness for the eaves).
	var nf := Vector3(0, d * 0.5 + o, -(rise)).normalized()
	nf = Vector3(0, absf(nf.y), -absf(nf.z))
	var nb := Vector3(0, nf.y, -nf.z)
	mb.add_quad(roof_key, rm, [Vector3(x0, ye, zf), Vector3(x1, ye, zf), Vector3(x1, yr, zr), Vector3(x0, yr, zr)], nf)
	mb.add_quad(roof_key, rm, [Vector3(x0, ye, zb), Vector3(x1, ye, zb), Vector3(x1, yr, zr), Vector3(x0, yr, zr)], nb)
	mb.add_quad(roof_key, rm, [Vector3(x0, ye - 0.06, zf), Vector3(x1, ye - 0.06, zf), Vector3(x1, yr - 0.06, zr), Vector3(x0, yr - 0.06, zr)], -nf)
	mb.add_quad(roof_key, rm, [Vector3(x0, ye - 0.06, zb), Vector3(x1, ye - 0.06, zb), Vector3(x1, yr - 0.06, zr), Vector3(x0, yr - 0.06, zr)], -nb)
	# Gables (triangles as quads with a doubled apex), slightly inset.
	var top := y + rise
	for gx in [0.0, w]:
		var n := Vector3(-1, 0, 0) if gx == 0.0 else Vector3(1, 0, 0)
		var gx2: float = gx + (-0.13 if gx == 0.0 else 0.13)
		mb.add_quad("planks", gm, [Vector3(gx2, y - 0.25, -0.13), Vector3(gx2, y - 0.25, d + 0.13), Vector3(gx2, top, zr), Vector3(gx2, top, zr)], n)
		mb.add_box(Vector3(gx2 - 0.03 if gx == 0.0 else gx2, y + rise * 0.35, zr - 0.3),
			Vector3(gx2 if gx == 0.0 else gx2 + 0.03, y + rise * 0.35 + 0.5, zr + 0.3), "frame", Mats.surface("frame"))
	# Plank ceiling under the attic (part of the roof, so the isometric view hides it with the roof).
	mb.add_box(Vector3(0.0, y - 0.03, 0.0), Vector3(w, y + 0.05, d), "planks", gm)
	# Ridge cap and a brick chimney above the stove.
	mb.add_box(Vector3(x0, yr - 0.02, zr - 0.08), Vector3(x1, yr + 0.08, zr + 0.08), roof_key, rm)
	mb.add_box(Vector3(2.75, y + 0.6, d * 0.72), Vector3(3.25, yr + 0.7, d * 0.72 + 0.5), "brick_red", Mats.surface("brick_red"))
	roof.add_child(mb.commit("RoofMesh"))
