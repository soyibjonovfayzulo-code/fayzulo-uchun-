class_name V01LevelBuilder
extends RefCounted
## Builds one level of a Building from rooms and axis-aligned walls with openings.
## Coordinates are building-local metres: x along the building, z across it, y up (absolute).
## Wall faces take the finish of the room they face (wallpaper, tiles, stairwell paint) or the façade.

const SLAB := 0.2

var building: V01Building
var level: Node3D
var index := 0
var y0 := 0.0
var wall_h := 2.6
var ext_key := "panel"
var mb: V01MeshBuilder
var rooms: Array[Dictionary] = []
var fixtures: Node3D
var props: Node3D
var rng := RandomNumberGenerator.new()
var ground_floor := true
## Probability knobs for the abandoned look.
var door_open_chance := 0.55
var window_open_chance := 0.08
var window_broken_chance := 0.05

var _wall_top_mat: Material
var _ext_mat: Material


func _init(b: V01Building, level_index: int, seed_value: int) -> void:
	building = b
	index = level_index
	y0 = b.level_y(level_index)
	wall_h = b.level_height - SLAB
	level = b.add_level(level_index)
	fixtures = level.get_node("Fixtures")
	props = level.get_node("Props")
	mb = V01MeshBuilder.new(level.get_node("Body"))
	rng.seed = seed_value
	ground_floor = level_index == 0
	_wall_top_mat = V01Mats.surface("wall_top")


func set_exterior(key: String) -> void:
	ext_key = key
	_ext_mat = V01Mats.surface(key)


## Adds a room. wall_key: Mats surface key (or "stairwell"); floor_key = "" means no slab (stair holes).
func add_room(rect: Rect2, type: String, wall_key: String, wall_color: Color, floor_key: String,
		floor_color := Color.WHITE) -> Dictionary:
	var wm: Material = V01Mats.stairwell(building.level_height) if wall_key == "stairwell" else V01Mats.surface(wall_key)
	var r := {"rect": rect, "type": type, "wall_key": wall_key, "wall_mat": wm, "wall_color": wall_color,
		"floor_key": floor_key, "floor_color": floor_color}
	rooms.append(r)
	return r


func room_at(x: float, z: float) -> Dictionary:
	var p := Vector2(x, z)
	for r in rooms:
		if (r["rect"] as Rect2).has_point(p):
			return r
	return {}


func _classify_wall(fc: Vector3, n: Vector3) -> Array:
	if n.y > 0.5:
		return ["wall_top", _wall_top_mat]
	if n.y < -0.5:
		return []
	var probe := fc + n * 0.06
	var r := room_at(probe.x, probe.z)
	if r.is_empty():
		if _ext_mat == null:
			_ext_mat = V01Mats.surface(ext_key)
		return [ext_key, _ext_mat]
	return [r["wall_key"], r["wall_mat"], r["wall_color"]]


func _classify_slab(_fc: Vector3, n: Vector3, room: Dictionary) -> Array:
	if n.y > 0.5:
		var fk: String = room["floor_key"]
		return [fk, V01Mats.surface(fk), room["floor_color"]]
	if n.y < -0.5:
		return ["ceiling", V01Mats.surface("ceiling")]
	return ["wall_top", _wall_top_mat]


func build_floors() -> void:
	for r in rooms:
		if r["floor_key"] == "":
			continue
		var rc: Rect2 = r["rect"]
		var room := r
		mb.add_box(Vector3(rc.position.x, y0 - SLAB, rc.position.y), Vector3(rc.end.x, y0, rc.end.y), "", null,
			Color.WHITE, func(fc: Vector3, n: Vector3) -> Array: return _classify_slab(fc, n, room))


## Opening spec: {"at": float (centre along the wall), "w": float, "bottom": float, "top": float,
##   "kind": "door" | "window" | "arch", "door": Door.Kind, "locked": bool, "open": bool}
## `exterior` walls extend down through the slab band so façades have no gaps.
func wall(a: Vector2, b: Vector2, t: float, openings: Array = [], exterior := false) -> void:
	var along_x := absf(a.y - b.y) < 0.001
	var s0 := minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var s1 := maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var line := a.y if along_x else a.x
	var bottom := y0 - SLAB if exterior else y0
	var top := y0 + wall_h
	# Split positions: room boundaries (so each face gets one finish) and openings.
	var cuts: Array[float] = [s0, s1]
	for r in rooms:
		var rc: Rect2 = r["rect"]
		for v in ([rc.position.x, rc.end.x] if along_x else [rc.position.y, rc.end.y]):
			if v > s0 + 0.01 and v < s1 - 0.01:
				cuts.append(v)
	var ops: Array = []
	for o in openings:
		var o0: float = o["at"] - o["w"] * 0.5
		var o1: float = o["at"] + o["w"] * 0.5
		ops.append([o0, o1, o])
		cuts.append(o0)
		cuts.append(o1)
	cuts.sort()
	for i in range(cuts.size() - 1):
		var c0 := cuts[i]
		var c1 := cuts[i + 1]
		if c1 - c0 < 0.005:
			continue
		var mid := (c0 + c1) * 0.5
		var hole: Dictionary = {}
		for o in ops:
			if mid > o[0] and mid < o[1]:
				hole = o[2]
		if hole.is_empty():
			_wall_piece(along_x, line, t, c0, c1, bottom, top)
		else:
			var hb: float = y0 + float(hole["bottom"])
			var ht: float = y0 + float(hole["top"])
			if hb > bottom + 0.01:
				_wall_piece(along_x, line, t, c0, c1, bottom, hb)
			if ht < top - 0.01:
				_wall_piece(along_x, line, t, c0, c1, ht, top)
	for o in ops:
		_spawn_opening(along_x, line, t, o[2], exterior)


func _wall_piece(along_x: bool, line: float, t: float, c0: float, c1: float, yb: float, yt: float) -> void:
	var bmin: Vector3
	var bmax: Vector3
	if along_x:
		bmin = Vector3(c0, yb, line - t * 0.5)
		bmax = Vector3(c1, yt, line + t * 0.5)
	else:
		bmin = Vector3(line - t * 0.5, yb, c0)
		bmax = Vector3(line + t * 0.5, yt, c1)
	mb.add_box(bmin, bmax, "", null, Color.WHITE, _classify_wall)


func _spawn_opening(along_x: bool, line: float, t: float, o: Dictionary, exterior: bool) -> void:
	var kind: String = o.get("kind", "arch")
	if kind == "arch":
		return
	var at: float = o["at"]
	var pos := Vector3(at, y0, line) if along_x else Vector3(line, y0, at)
	# Outward direction for exterior openings: away from the footprint centre.
	var c := building.footprint.get_center()
	var out_sign := 1.0
	if along_x:
		out_sign = 1.0 if line > c.y else -1.0
	else:
		out_sign = 1.0 if line > c.x else -1.0
	var rot := 0.0
	if along_x:
		rot = 0.0 if out_sign > 0 else 180.0
	else:
		rot = 90.0 if out_sign > 0 else -90.0
	if kind == "door":
		var d := V01Door.new()
		d.kind = o.get("door", V01Door.Kind.INTERIOR)
		d.wall_thickness = t
		d.locked = o.get("locked", false)
		d.start_open = o.get("open", rng.randf() < door_open_chance) and not d.locked
		d.position = pos
		d.rotation_degrees.y = rot
		fixtures.add_child(d, true)
	elif kind == "window":
		var w := V01WindowObj.new()
		w.width = o["w"]
		w.height = float(o["top"]) - float(o["bottom"])
		w.sill_height = o["bottom"]
		w.wall_thickness = t
		w.ground_floor = ground_floor
		w.start_broken = o.get("broken", rng.randf() < window_broken_chance)
		w.start_open = rng.randf() < window_open_chance
		w.position = pos + Vector3(0, float(o["bottom"]), 0)
		w.rotation_degrees.y = rot
		fixtures.add_child(w, true)
		if o.get("radiator", false) and exterior:
			var inward := -Vector3(sin(deg_to_rad(rot)), 0, cos(deg_to_rad(rot)))
			V01Props.spawn("furniture/radiator", props, pos + inward * (t * 0.5 + 0.08), rot + 180.0, false)


func commit() -> void:
	build_floors()
	if not mb.is_empty():
		var mi := mb.commit("Shell")
		level.add_child(mi)
		level.move_child(mi, 0)
