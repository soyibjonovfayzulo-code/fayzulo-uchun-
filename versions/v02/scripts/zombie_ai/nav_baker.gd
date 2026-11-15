class_name V02NavBaker
extends Node
## Bakes one navigation mesh for the whole district from static colliders on the "world" layer only
## (doors live on their own layer, so doorways stay walkable and zombies bash closed doors).
## The result is cached in user:// so later launches start instantly.

const NAV_VERSION := "v02-4"

signal baked

static var ready_for_navigation := false

@export var district_path: NodePath

var region: NavigationRegion3D
var bake_seconds := 0.0
var _t0 := 0


func _ready() -> void:
	ready_for_navigation = false
	_start.call_deferred()


func _start() -> void:
	var district := get_node(district_path) as Node3D
	region = NavigationRegion3D.new()
	region.name = "NavRegion"
	add_child(region)
	var cache := "user://navmesh_%s_%d.res" % [NAV_VERSION, _geometry_signature(district)]
	if ResourceLoader.exists(cache) and not "--navdebug" in OS.get_cmdline_user_args():
		var nm := load(cache) as NavigationMesh
		if nm:
			region.navigation_mesh = nm
			_finish("cache")
			return
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.2
	nm.cell_size = 0.1
	nm.cell_height = 0.1
	nm.agent_height = 1.7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nav="):
			var kv := a.trim_prefix("--nav=").split(":")
			nm.set(kv[0], float(kv[1]))
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 42.0
	nm.region_min_size = 6.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	var src := NavigationMeshSourceGeometryData3D.new()
	_t0 = Time.get_ticks_msec()
	NavigationServer3D.parse_source_geometry_data(nm, src, district)
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, func() -> void:
		region.navigation_mesh = nm
		ResourceSaver.save(nm, cache)
		_finish("bake"))


func _finish(how: String) -> void:
	bake_seconds = (Time.get_ticks_msec() - _t0) / 1000.0 if _t0 > 0 else 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	ready_for_navigation = true
	var hist := {}
	for v in region.navigation_mesh.get_vertices():
		var k := int(floor(v.y / 2.8))
		hist[k] = hist.get(k, 0) + 1
	print("NAV ready (%s) polygons=%d in %.1fs levels=%s" % [how, region.navigation_mesh.get_polygon_count(), bake_seconds, hist])
	baked.emit()
	if "--navdebug" in OS.get_cmdline_user_args():
		var map := region.get_navigation_map()
		await get_tree().create_timer(1.0).timeout
		for p in [Vector3(45, 0.1, 40), Vector3(24.3, 0.15, 64), Vector3(28, 0.15, 57.2), Vector3(24.3, 2.95, 64), Vector3(25, 0.15, 76)]:
			var c := NavigationServer3D.map_get_closest_point(map, p)
			var path := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, Vector3(45, 0.1, 40)), c, true)
			print("NAVDBG ", p, " -> ", c, " path_pts=", path.size())
		_debug_image(Rect2(15, 50, 50, 20), 12, "nav_b3.png")
		var space := region.get_world_3d().direct_space_state
		for p in [Vector3(24.3, 0.3, 64), Vector3(24.3, 3.1, 64)]:
			var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.UP * 4.0, 0xFFFF)
			q.collide_with_areas = true
			var h := space.intersect_ray(q)
			print("NAVDBG up from ", p, ": ", h.get("position"), " ", h.get("collider"), " ", (h.get("collider") as Node).get_path() if h else "")


## Top-down raster of the navmesh (colour = floor level) for debugging connectivity.
func _debug_image(area: Rect2, ppm: int, file: String) -> void:
	var nm := region.navigation_mesh
	var img := Image.create(int(area.size.x * ppm), int(area.size.y * ppm), false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.1, 0.1))
	var verts := nm.get_vertices()
	var cols := [Color.DARK_GREEN, Color.YELLOW, Color.ORANGE, Color.RED, Color.MAGENTA, Color.CYAN, Color.BLUE, Color.WHITE, Color.PINK]
	for i in nm.get_polygon_count():
		var poly := nm.get_polygon(i)
		var pts := PackedVector2Array()
		var y := 0.0
		for idx in poly:
			var v: Vector3 = verts[idx]
			pts.append((Vector2(v.x, v.z) - area.position) * ppm)
			y += v.y
		y /= poly.size()
		var col: Color = cols[clampi(int(floor((y + 0.4) / 2.8)), 0, 8)].lerp(Color.WHITE, fmod(y + 0.4, 2.8) / 2.8 * 0.5)
		var bb := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			bb = bb.expand(p)
		for px in range(maxi(int(bb.position.x), 0), mini(int(bb.end.x) + 1, img.get_width())):
			for py in range(maxi(int(bb.position.y), 0), mini(int(bb.end.y) + 1, img.get_height())):
				if Geometry2D.is_point_in_polygon(Vector2(px + 0.5, py + 0.5), pts):
					img.set_pixel(px, py, col)
	img.save_png(ProjectSettings.globalize_path("res://tools/screens/" + file))


## Cheap signature of the collision layout so map edits invalidate the cache.
func _geometry_signature(root: Node) -> int:
	var n := 0
	var acc := 0.0
	for cs in root.find_children("*", "CollisionShape3D", true, false):
		var c := cs as CollisionShape3D
		n += 1
		var p := c.global_position
		acc += p.x * 0.37 + p.y * 1.31 + p.z * 0.73
	return hash([n, snappedf(acc, 0.1)])
