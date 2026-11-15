class_name PanelHouse
extends RefCounted
## Generates a Soviet panel apartment block (khrushchyovka / 9-storey) from sections ("podъезды").
## Each 12 x 11 m section per floor: stairwell with two-flight stairs in the middle,
## a 1-room flat on the west side and a 2-room flat on the east side (bedroom behind the stairwell).
## Local frame: x along the façade, z = 0 entrance side, z = 11 balcony side.

const SEC_W := 12.0
const DEPTH := 11.0
const T_EXT := 0.3
const T_INT := 0.12
const T_STAIR := 0.2
const FLIGHT_RISE := 1.4
const LANDING_Z := 1.8
const MID_Z := 4.6
const STAIR_Z := 6.4

const LIVING_COLORS := [Color("#d6c8a0"), Color("#b8c4a8"), Color("#c8b0a8"), Color("#aab4c4"), Color("#d4ccb4"), Color("#c4b494")]
const HALL_COLORS := [Color("#a88a6a"), Color("#9a8a70"), Color("#b09878")]
const KITCHEN_COLORS := [Color("#d0d8c4"), Color("#e0d4b0"), Color("#c8d4d4")]
const WALLPAPERS := ["wallpaper_a", "wallpaper_b", "wallpaper_c"]


## params: sections, floors, ext ("panel"...), seed, name, address
static func build(parent: Node3D, pos: Vector3, rot_deg: float, params: Dictionary) -> Building:
	var b := Building.new()
	b.name = params.get("name", "PanelHouse")
	b.display_name = params.get("name", "Жилой дом")
	b.address = params.get("address", "")
	b.position = pos
	b.rotation_degrees.y = rot_deg
	parent.add_child(b, true)
	var sections: int = params.get("sections", 2)
	var floors: int = params.get("floors", 5)
	var ext: String = params.get("ext", "panel")
	var seed_base: int = params.get("seed", 1)
	var w := SEC_W * sections
	b.footprint = Rect2(0, 0, w, DEPTH)
	for L in floors:
		var lb := LevelBuilder.new(b, L, seed_base * 1000 + L)
		lb.set_exterior(ext)
		_build_level(lb, sections, floors, seed_base)
		lb.commit()
	_build_roof(b, sections, floors, ext)
	_build_entrances(b, sections, seed_base)
	return b


static func _apt_rng(seed_base: int, level: int, section: int, side: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_base, level, section, side])
	return r


static func _build_level(lb: LevelBuilder, sections: int, floors: int, seed_base: int) -> void:
	var L := lb.index
	var w := SEC_W * sections
	var front_ops: Array = []
	var back_ops: Array = []
	for s in sections:
		var ox := s * SEC_W
		# --- rooms: finishes are chosen per flat
		for side in [0, 1]:
			var r := _apt_rng(seed_base, L, s, side)
			var living_wp: String = WALLPAPERS[r.randi() % 3]
			var living_col: Color = LIVING_COLORS[r.randi() % LIVING_COLORS.size()]
			var hall_col: Color = HALL_COLORS[r.randi() % HALL_COLORS.size()]
			var kit_col: Color = KITCHEN_COLORS[r.randi() % KITCHEN_COLORS.size()]
			var floor_tint := Color(1, 1, 1).darkened(r.randf() * 0.15)
			var m := func(x: float, width: float) -> float: return ox + (x if side == 0 else SEC_W - x - width)
			lb.add_room(Rect2(m.call(0.0, 2.6), 0, 2.6, 3.2), "kitchen", "paint", kit_col, "linoleum", floor_tint)
			lb.add_room(Rect2(m.call(2.6, 2.0), 0, 2.0, 3.2), "hall", "wallpaper_a", hall_col, "linoleum", floor_tint)
			lb.add_room(Rect2(m.call(0.0, 2.0), 3.2, 2.0, 2.0), "bathroom", "tile_wall", Color("#dfe6e4"), "floor_tile")
			lb.add_room(Rect2(m.call(2.0, 2.6), 3.2, 2.6, 2.0), "hall", "wallpaper_a", hall_col, "linoleum", floor_tint)
			lb.add_room(Rect2(m.call(0.0, 4.6), 5.2, 4.6, 5.8), "living", living_wp, living_col, "parquet", floor_tint)
			if side == 1:
				var bed_wp: String = WALLPAPERS[r.randi() % 3]
				lb.add_room(Rect2(ox + 4.6, STAIR_Z, 2.8, DEPTH - STAIR_Z), "bedroom", bed_wp,
					LIVING_COLORS[r.randi() % LIVING_COLORS.size()], "parquet", floor_tint)
		if L == 0:
			lb.add_room(Rect2(ox + 4.6, 0, 2.8, STAIR_Z), "stairwell", "stairwell", Color.WHITE, "floor_tile", Color("#d8c8b0"))
		else:
			lb.add_room(Rect2(ox + 4.6, 0, 2.8, LANDING_Z), "stairwell", "stairwell", Color.WHITE, "floor_tile", Color("#d8c8b0"))
			lb.add_room(Rect2(ox + 4.6, LANDING_Z, 2.8, STAIR_Z - LANDING_Z), "stairwell", "stairwell", Color.WHITE, "")

	for s in sections:
		var ox := s * SEC_W
		var lock_r := _apt_rng(seed_base, L, s, 7)
		# --- interior walls of both flats (east = mirror of west)
		for side in [0, 1]:
			var mx := func(x: float) -> float: return ox + (x if side == 0 else SEC_W - x)
			lb.wall(Vector2(mx.call(2.6), 0), Vector2(mx.call(2.6), 3.2), T_INT, [_door(2.3, Door.Kind.INTERIOR)])
			lb.wall(Vector2(mx.call(0.0), 3.2), Vector2(mx.call(4.6), 3.2), T_INT, [_arch(mx.call(3.6), 0.8)])
			lb.wall(Vector2(mx.call(2.0), 3.2), Vector2(mx.call(2.0), 5.2), T_INT, [_door(4.0, Door.Kind.INTERIOR)])
			lb.wall(Vector2(mx.call(0.0), 5.2), Vector2(mx.call(4.6), 5.2), T_INT, [_door(mx.call(3.3), Door.Kind.INTERIOR)])
		# --- stairwell walls with flat entrance doors
		var lock_w := lock_r.randf() < 0.3
		var lock_e := lock_r.randf() < 0.3
		var dw := _door(0.95, Door.Kind.APARTMENT, lock_w, lock_r.randf() < 0.25)
		var de := _door(0.95, Door.Kind.APARTMENT, lock_e, lock_r.randf() < 0.25)
		for pair in [[dw, 0], [de, 1]]:
			var flat: int = s * floors * 2 + L * 2 + pair[1] + 1
			pair[0]["key_id"] = "%s:%d" % [lb.building.name, flat]
			pair[0]["key_label"] = "%s, кв. %d" % [lb.building.display_name.get_slice(" (", 0), flat]
		lb.wall(Vector2(ox + 4.6, 0), Vector2(ox + 4.6, DEPTH), T_STAIR, [dw])
		lb.wall(Vector2(ox + 7.4, 0), Vector2(ox + 7.4, DEPTH), T_STAIR, [de, _door(7.4, Door.Kind.INTERIOR)])
		lb.wall(Vector2(ox + 4.6, STAIR_Z), Vector2(ox + 7.4, STAIR_Z), T_STAIR)
		if s > 0:
			lb.wall(Vector2(ox, 0), Vector2(ox, DEPTH), 0.2)
		# --- façade openings
		front_ops.append(_win(ox + 1.3, 1.4, true))
		front_ops.append(_win(ox + 10.7, 1.4, true))
		if L == 0:
			front_ops.append({"at": ox + 6.0, "w": Door.width_of(Door.Kind.ENTRANCE), "bottom": 0.0,
				"top": Door.height_of(Door.Kind.ENTRANCE), "kind": "door", "door": Door.Kind.ENTRANCE, "open": false})
			back_ops.append(_win(ox + 1.3, 1.4, true))
			back_ops.append(_win(ox + 3.3, 1.2, true))
			back_ops.append(_win(ox + 8.7, 1.2, true))
		else:
			front_ops.append({"at": ox + 6.0, "w": 1.2, "bottom": 1.0, "top": 2.2, "kind": "window"})
			back_ops.append(_win(ox + 1.3, 1.4, true))
			back_ops.append(_door(ox + 3.3, Door.Kind.BALCONY, false, false))
			back_ops.append(_door(ox + 8.7, Door.Kind.BALCONY, false, false))
		back_ops.append(_win(ox + 6.0, 1.4, true))
		back_ops.append(_win(ox + 10.7, 1.4, true))
		_build_stairs(lb, ox, floors)
		_furnish_section(lb, ox, seed_base)
		if L > 0:
			for bx in [ox + 2.4, ox + 9.6]:
				_balcony(lb, Vector3(bx, lb.y0 - 0.14, DEPTH + T_EXT * 0.5))
	# --- exterior walls
	lb.wall(Vector2(-T_EXT * 0.5, 0), Vector2(w + T_EXT * 0.5, 0), T_EXT, front_ops, true)
	lb.wall(Vector2(-T_EXT * 0.5, DEPTH), Vector2(w + T_EXT * 0.5, DEPTH), T_EXT, back_ops, true)
	lb.wall(Vector2(0, T_EXT * 0.5), Vector2(0, DEPTH - T_EXT * 0.5), T_EXT, [_win(8.2, 1.2, true)], true)
	lb.wall(Vector2(w, T_EXT * 0.5), Vector2(w, DEPTH - T_EXT * 0.5), T_EXT, [_win(8.2, 1.2, true)], true)


static func _door(at: float, kind: Door.Kind, locked := false, open = null) -> Dictionary:
	var d := {"at": at, "w": Door.width_of(kind), "bottom": 0.0, "top": Door.height_of(kind), "kind": "door",
		"door": kind, "locked": locked}
	if open != null:
		d["open"] = open
	return d


static func _arch(at: float, w: float) -> Dictionary:
	return {"at": at, "w": w, "bottom": 0.0, "top": 2.0, "kind": "arch"}


static func _win(at: float, w: float, radiator := false) -> Dictionary:
	return {"at": at, "w": w, "bottom": 0.85, "top": 2.25, "kind": "window", "radiator": radiator}


# ------------------------------------------------------------------------------------------------ stairs
static func _build_stairs(lb: LevelBuilder, ox: float, floors: int) -> void:
	var y0 := lb.y0
	var mb := lb.mb
	var concrete := Mats.surface("concrete")
	var tile := Mats.surface("concrete_floor")
	var rail := Mats.surface("metal_dark")
	var wood := Mats.surface("rail_wood")
	var stair_wall := Mats.stairwell(lb.building.level_height)
	var xa0 := ox + 6.0
	var xa1 := ox + 7.4 - T_STAIR * 0.5
	var xb0 := ox + 4.6 + T_STAIR * 0.5
	var xb1 := ox + 6.0
	var top_level := lb.index == floors - 1
	if lb.index == 0:
		# Solid block under the upper flight (keeps people out of the low gap), mailboxes on it.
		mb.add_box(Vector3(xb0, y0, 2.7), Vector3(xb1, y0 + 1.3, MID_Z), "stairwell", stair_wall)
		Furnish.place("furniture/mailboxes", lb.props, Vector3((xb0 + xb1) * 0.5, y0 + 0.5, 2.6), 180.0, "stairwell")
	if not top_level:
		_flight(mb, xa0, xa1, LANDING_Z, MID_Z, y0, y0 + FLIGHT_RISE, concrete, tile)
		_flight(mb, xb0, xb1, MID_Z, LANDING_Z, y0 + FLIGHT_RISE, y0 + FLIGHT_RISE * 2.0, concrete, tile)
		# Mid landing.
		mb.add_box(Vector3(xb0, y0 + FLIGHT_RISE - 0.15, MID_Z), Vector3(xa1, y0 + FLIGHT_RISE, STAIR_Z - T_STAIR * 0.5),
			"concrete_floor", tile)
		# Divider between flights: invisible blocker + visible railing.
		mb.add_collision(Vector3(ox + 6.0, y0 + 2.0, (LANDING_Z + MID_Z) * 0.5), Vector3(0.08, 4.0, MID_Z - LANDING_Z))
		_railing(mb, ox + 6.0, LANDING_Z, MID_Z, y0, y0 + FLIGHT_RISE, rail, wood)
		_railing(mb, ox + 6.0, MID_Z, LANDING_Z, y0 + FLIGHT_RISE, y0 + FLIGHT_RISE * 2.0, rail, wood)
	else:
		# No flight up from the top floor: guard the opening over the flight below.
		mb.add_collision(Vector3((xa0 + xa1) * 0.5, y0 + 0.6, LANDING_Z), Vector3(xa1 - xa0, 1.2, 0.08))
		for i in 6:
			var x := xa0 + 0.1 + i * 0.24
			mb.add_box(Vector3(x - 0.012, y0, LANDING_Z - 0.012), Vector3(x + 0.012, y0 + 0.95, LANDING_Z + 0.012),
				"rail", rail, Color.WHITE, Callable(), false)
		mb.add_box(Vector3(xa0, y0 + 0.92, LANDING_Z - 0.03), Vector3(xa1, y0 + 0.98, LANDING_Z + 0.03), "rail_wood",
			wood, Color.WHITE, Callable(), false)


static func _flight(mb: MeshBuilder, x0: float, x1: float, z0: float, z1: float, ya: float, yb: float,
		concrete: Material, tile: Material) -> void:
	var steps := 10
	var dz := (z1 - z0) / steps
	var dy := (yb - ya) / steps
	for i in steps:
		var za := z0 + dz * i
		var zb := za + dz
		var top := ya + dy * (i + 1)
		mb.add_box(Vector3(x0, top - 0.18, minf(za, zb)), Vector3(x1, top, maxf(za, zb)), "concrete_floor", tile,
			Color.WHITE, Callable(), false)
	# Walkable ramp collider + sloped concrete underside.
	var run := absf(z1 - z0)
	var length := sqrt(run * run + (yb - ya) * (yb - ya)) + 0.12
	var ang := atan2(yb - ya, run)
	var dir_sign := 1.0 if z1 > z0 else -1.0
	var basis := Basis(Vector3.RIGHT, -ang * dir_sign)
	var center := Vector3((x0 + x1) * 0.5, (ya + yb) * 0.5, (z0 + z1) * 0.5)
	mb.add_collision(center - basis.y * 0.05, Vector3(x1 - x0, 0.1, length), basis)
	mb.add_obox(center - basis.y * 0.22, Vector3(x1 - x0, 0.16, length - 0.12), basis, "concrete", concrete)


static func _railing(mb: MeshBuilder, x: float, z0: float, z1: float, ya: float, yb: float, rail: Material,
		wood: Material) -> void:
	var n := 9
	for i in range(1, n):
		var t := float(i) / n
		var z := lerpf(z0, z1, t)
		var y := lerpf(ya, yb, t)
		mb.add_box(Vector3(x - 0.012, y, z - 0.012), Vector3(x + 0.012, y + 0.9, z + 0.012), "rail", rail,
			Color.WHITE, Callable(), false)
	var run := absf(z1 - z0)
	var length := sqrt(run * run + (yb - ya) * (yb - ya))
	var ang := atan2(yb - ya, run)
	var dir_sign := 1.0 if z1 > z0 else -1.0
	var basis := Basis(Vector3.RIGHT, -ang * dir_sign)
	mb.add_obox(Vector3(x, (ya + yb) * 0.5 + 0.92, (z0 + z1) * 0.5), Vector3(0.07, 0.05, length), basis,
		"rail_wood", wood)


static func _balcony(lb: LevelBuilder, at: Vector3) -> void:
	var bal := Props.spawn("buildings/balcony", lb.fixtures, at, 0.0, false)
	if bal == null:
		return
	# Walkable slab and parapet colliders (the auto box collider would fill the balcony).
	Props.add_box(lb.fixtures, at + Vector3(0, 0.08, 0.55), Vector3(3.0, 0.16, 1.1))
	Props.add_box(lb.fixtures, at + Vector3(0, 0.66, 1.08), Vector3(3.0, 1.1, 0.08))
	Props.add_box(lb.fixtures, at + Vector3(-1.47, 0.66, 0.55), Vector3(0.08, 1.1, 1.1))
	Props.add_box(lb.fixtures, at + Vector3(1.47, 0.66, 0.55), Vector3(0.08, 1.1, 1.1))


# ------------------------------------------------------------------------------------------------ furniture
## West-flat layout in section-local coords: [prop, x, z, rot, room, optional y]. East flat is mirrored.
const FLAT_LAYOUT := [
	["furniture/fridge", 0.42, 2.8, 90.0, "kitchen"],
	["furniture/stove", 0.38, 2.15, 90.0, "kitchen"],
	["furniture/kitchen_sink", 0.4, 1.6, 90.0, "kitchen"],
	["furniture/kitchen_cabinet", 0.4, 1.0, 90.0, "kitchen"],
	["furniture/wall_cabinet", 0.24, 1.0, 90.0, "kitchen", 1.45],
	["furniture/wall_cabinet", 0.24, 1.6, 90.0, "kitchen", 1.45],
	["furniture/kitchen_table", 1.55, 0.62, 0.0, "kitchen"],
	["furniture/stool", 1.55, 1.2, 0.0, "kitchen"],
	["furniture/stool", 2.25, 0.62, 0.0, "kitchen"],
	["furniture/wardrobe", 3.2, 0.42, 0.0, "hall"],
	["furniture/bathtub", 0.45, 4.42, 90.0, "bathroom"],
	["furniture/toilet", 1.6, 4.85, 180.0, "bathroom"],
	["furniture/washbasin", 1.45, 3.45, 0.0, "bathroom"],
	["furniture/wall_cabinet", 1.45, 3.43, 0.0, "bathroom", 1.65],
	["furniture/sofa", 0.52, 7.9, 90.0, "living"],
	["furniture/carpet_wall", 0.17, 7.9, 90.0, "living", 0.95],
	["furniture/carpet_floor", 2.2, 8.0, 90.0, "living"],
	["furniture/stenka", 4.26, 9.6, -90.0, "living"],
	["furniture/tv", 4.1, 6.3, -90.0, "living"],
	["furniture/chair", 2.3, 6.2, 180.0, "living"],
	["furniture/dresser", 1.2, 5.53, 0.0, "living"],
]

const BEDROOM_LAYOUT := [
	["furniture/bed", 5.2, 7.6, 0.0, "bedroom"],
	["furniture/wardrobe", 6.84, 9.4, -90.0, "bedroom"],
	["furniture/dresser", 4.93, 10.15, 90.0, "bedroom"],
	["furniture/chair", 6.6, 10.3, 180.0, "bedroom"],
]

const MESS := ["environment/cardboard", "environment/trash_bag"]


static func _furnish_section(lb: LevelBuilder, ox: float, seed_base: int) -> void:
	var y0 := lb.y0
	for side in [0, 1]:
		var r := _apt_rng(seed_base, lb.index, int(ox / SEC_W), side + 10)
		for e in FLAT_LAYOUT:
			# Some flats were stripped bare before the outbreak.
			if r.randf() < 0.08 and e[4] == "living":
				continue
			var x: float = e[1]
			var rot: float = e[3]
			if side == 1:
				x = SEC_W - x
				rot = -rot
			var y: float = y0 + (e[5] if e.size() > 5 else 0.0)
			var name: String = e[0]
			if name == "furniture/wall_cabinet" and e[4] == "bathroom":
				Furnish.place(name, lb.props, Vector3(ox + x, y, e[2]), rot, "bathroom", "Аптечка в ванной")
			else:
				Furnish.place(name, lb.props, Vector3(ox + x, y, e[2]), rot, e[4])
		if side == 1:
			for e in BEDROOM_LAYOUT:
				Furnish.place(e[0], lb.props, Vector3(ox + e[1], y0, e[2]), e[3], e[4])
		if r.randf() < 0.45:
			var tx := 4.3 if side == 0 else SEC_W - 4.3
			Furnish.place("furniture/toolbox", lb.props, Vector3(ox + tx, y0, 4.7), -90.0 if side == 0 else 90.0, "hall")
		# Abandoned-flat clutter.
		for i in r.randi_range(0, 2):
			var px := r.randf_range(0.6, 4.0)
			var pz := r.randf_range(5.8, 10.4)
			if side == 1:
				px = SEC_W - px
			Props.spawn(MESS[r.randi() % MESS.size()], lb.props, Vector3(ox + px, y0, pz), r.randf() * 360.0, false)


# ------------------------------------------------------------------------------------------------ roof & entrances
static func _build_roof(b: Building, sections: int, floors: int, ext: String) -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	b.add_child(roof)
	b.roof = roof
	var mb := MeshBuilder.new()
	var y := b.level_y(floors) - LevelBuilder.SLAB
	var w := SEC_W * sections
	var e := T_EXT * 0.5
	var roof_mat := Mats.surface("roof")
	var ext_mat := Mats.surface(ext)
	mb.add_box(Vector3(-e, y, -e), Vector3(w + e, y + 0.25, DEPTH + e), "roof", roof_mat)
	for p in [[Vector3(-e, y, -e), Vector3(w + e, y + 0.75, e)], [Vector3(-e, y, DEPTH - e), Vector3(w + e, y + 0.75, DEPTH + e)],
			[Vector3(-e, y, -e), Vector3(e, y + 0.75, DEPTH + e)], [Vector3(w - e, y, -e), Vector3(w + e, y + 0.75, DEPTH + e)]]:
		mb.add_box(p[0], p[1], ext, ext_mat)
	for s in sections:
		var ox := s * SEC_W
		mb.add_box(Vector3(ox + 4.5, y, 0.6), Vector3(ox + 7.5, y + 2.4, 3.4), ext, ext_mat)
		mb.add_box(Vector3(ox + 4.4, y + 2.4, 0.5), Vector3(ox + 7.6, y + 2.55, 3.5), "roof", roof_mat)
		for k in 3:
			var ax := ox + 1.5 + k * 3.7
			mb.add_box(Vector3(ax - 0.02, y + 0.25, 8.0), Vector3(ax + 0.02, y + 2.2, 8.04), "metal_dark", Mats.surface("metal_dark"))
			mb.add_box(Vector3(ax - 0.5, y + 1.9, 8.0), Vector3(ax + 0.5, y + 1.93, 8.03), "metal_dark", Mats.surface("metal_dark"))
	roof.add_child(mb.commit("RoofMesh"))


static func _build_entrances(b: Building, sections: int, seed_base: int) -> void:
	var lv := b.levels[0]
	var fx := lv.get_node("Fixtures") as Node3D
	var body := lv.get_node("Body") as StaticBody3D
	var mb := MeshBuilder.new(body)
	var conc := Mats.surface("concrete")
	var r := RandomNumberGenerator.new()
	r.seed = seed_base * 77
	for s in sections:
		var ox := s * SEC_W
		mb.add_box(Vector3(ox + 4.7, 0.0, -1.3), Vector3(ox + 7.3, b.base_y, -T_EXT * 0.5), "concrete", conc)
		Props.spawn("buildings/canopy", fx, Vector3(ox + 6.0, b.base_y + 2.4, -T_EXT * 0.5), 180.0, false)
		Props.spawn("buildings/intercom", fx, Vector3(ox + 6.75, b.base_y + 1.2, -T_EXT * 0.5 - 0.02), 180.0, false)
		Furnish.place("environment/bench", fx, Vector3(ox + 8.6, 0.0, -1.5), 180.0, "outside")
		if r.randf() < 0.6:
			Props.spawn("environment/urn", fx, Vector3(ox + 7.6, 0.0, -1.2), 0.0)
	var mi := mb.commit("EntranceMesh")
	lv.add_child(mi)
