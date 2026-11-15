class_name V03Mats
extends RefCounted
## Shared material library. Every building/ground surface and every imported prop goes through here,
## so the whole game uses the same few shaders (pixel textures, muted palette, cutaway).

const WORLD_SHADER := preload("res://versions/v03/shaders/world.gdshader")
const FOLIAGE_SHADER := preload("res://versions/v03/shaders/foliage.gdshader")
const GLASS_SHADER := preload("res://versions/v03/shaders/glass.gdshader")
const HIGHLIGHT_SHADER := preload("res://versions/v03/shaders/highlight.gdshader")
const TV_SHADER := preload("res://versions/v03/shaders/tv_screen.gdshader")
const TEX := "res://versions/v03/assets/textures/"

## key: [texture, metres per repeat, tint, vertex colour, cuttable]
const SURFACES := {
	"panel": ["panel", Vector2(3.0, 2.8), Color("#ffffff"), false, true],
	"panel_light": ["panel", Vector2(3.0, 2.8), Color("#e8e4da"), false, true],
	"panel_dark": ["panel", Vector2(3.0, 2.8), Color("#c4bcb0"), false, true],
	"brick": ["brick_white", Vector2(2.0, 2.0), Color("#ffffff"), false, true],
	"plaster_ext": ["plaster", Vector2(1.0, 1.0), Color("#c9bfa6"), false, true],
	"plaster_pharm": ["plaster", Vector2(1.0, 1.0), Color("#b8c4bc"), false, true],
	"plinth": ["concrete", Vector2(2.0, 2.0), Color("#8a867c"), false, true],
	"wallpaper_a": ["wallpaper_a", Vector2(1.0, 1.0), Color.WHITE, true, true],
	"wallpaper_b": ["wallpaper_b", Vector2(1.0, 1.0), Color.WHITE, true, true],
	"wallpaper_c": ["wallpaper_c", Vector2(1.0, 1.0), Color.WHITE, true, true],
	"paint": ["plaster", Vector2(1.0, 1.0), Color.WHITE, true, true],
	"tile_wall": ["tile_wall", Vector2(1.25, 1.25), Color.WHITE, true, true],
	"wall_top": ["concrete", Vector2(2.0, 2.0), Color("#5a5650"), false, true],
	"linoleum": ["linoleum", Vector2(2.0, 2.0), Color.WHITE, true, true],
	"parquet": ["parquet", Vector2(2.0, 2.0), Color.WHITE, true, true],
	"floor_tile": ["floor_tile", Vector2(1.0, 1.0), Color.WHITE, true, true],
	"concrete": ["concrete", Vector2(2.0, 2.0), Color.WHITE, false, true],
	"concrete_floor": ["concrete", Vector2(2.0, 2.0), Color("#b8b2a6"), false, true],
	"ceiling": ["plaster", Vector2(1.0, 1.0), Color("#dcd8d0"), false, true],
	"roof": ["roof", Vector2(2.0, 2.0), Color.WHITE, false, true],
	"asphalt": ["asphalt", Vector2(4.0, 4.0), Color.WHITE, false, false],
	"asphalt_light": ["asphalt_light", Vector2(4.0, 4.0), Color.WHITE, false, false],
	"pavement": ["pavement", Vector2(2.0, 2.0), Color.WHITE, false, false],
	"grass": ["grass", Vector2(4.0, 4.0), Color.WHITE, false, false],
	"dirt": ["dirt", Vector2(2.0, 2.0), Color.WHITE, false, false],
	"sand": ["sand", Vector2(2.0, 2.0), Color.WHITE, false, false],
	"curb": ["concrete", Vector2(2.0, 2.0), Color("#c0bcb4"), false, false],
	"road_line": ["concrete", Vector2(2.0, 2.0), Color("#d0ccc0"), false, false],
	"frame": ["grime", Vector2(1.0, 1.0), Color("#d4cdb8"), false, true],
	"sill": ["grime", Vector2(1.0, 1.0), Color("#a89070"), false, true],
	"metal_dark": ["grime", Vector2(1.0, 1.0), Color("#3e4042"), false, true],
	"rail_wood": ["grime", Vector2(1.0, 1.0), Color("#6b4e35"), false, true],
}

static var _surface_cache := {}
static var _prop_cache := {}
static var _tex_cache := {}
static var glass_material: ShaderMaterial
static var highlight_material: ShaderMaterial


static func tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load(TEX + name + ".png")
	return _tex_cache[name]


static func surface(key: String) -> ShaderMaterial:
	if _surface_cache.has(key):
		return _surface_cache[key]
	var spec: Array = SURFACES.get(key, ["grime", Vector2.ONE, Color.MAGENTA, false, true])
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("albedo_tex", tex(spec[0]))
	m.set_shader_parameter("tex_meters", spec[1])
	m.set_shader_parameter("tint", spec[2])
	m.set_shader_parameter("use_vertex_color", spec[3])
	m.set_shader_parameter("cuttable", spec[4])
	_surface_cache[key] = m
	return m


## Soviet stairwell: green oil paint up to ~1.45 m, whitewash above.
static func stairwell(level_height: float) -> ShaderMaterial:
	var key := "stairwell_%.2f" % level_height
	if _surface_cache.has(key):
		return _surface_cache[key]
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("albedo_tex", tex("plaster"))
	m.set_shader_parameter("tex_meters", Vector2.ONE)
	m.set_shader_parameter("tint", Color("#d6d2c4"))
	m.set_shader_parameter("two_tone", true)
	m.set_shader_parameter("low_color", Color("#56705e"))
	m.set_shader_parameter("level_height", level_height)
	_surface_cache[key] = m
	return m


static func glass() -> ShaderMaterial:
	if glass_material == null:
		glass_material = ShaderMaterial.new()
		glass_material.shader = GLASS_SHADER
		glass_material.render_priority = 1
	return glass_material


static func highlight() -> ShaderMaterial:
	if highlight_material == null:
		highlight_material = ShaderMaterial.new()
		highlight_material.shader = HIGHLIGHT_SHADER
	return highlight_material


## Material for a colour-only prop surface (grime texture keeps it from looking flat-shaded).
static func prop_color(color: Color, cuttable := true, emission_night := 0.0) -> ShaderMaterial:
	var key := "%s|%s|%s" % [color.to_html(), cuttable, emission_night]
	if _prop_cache.has(key):
		return _prop_cache[key]
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("albedo_tex", tex("grime"))
	m.set_shader_parameter("tex_meters", Vector2(1.0, 1.0))
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("cuttable", cuttable)
	if emission_night > 0.0:
		m.set_shader_parameter("emission_night", emission_night)
		m.set_shader_parameter("emission_color", color)
	_prop_cache[key] = m
	return m


## Replaces imported StandardMaterial3D surfaces with the game's shaders, keyed off the Blender material name.
static func convert_imported(root: Node, cuttable := true) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		var mesh := mesh_inst.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			mesh_inst.set_surface_override_material(i, _convert(src, cuttable))


static func _convert(src: Material, cuttable: bool) -> Material:
	if not (src is BaseMaterial3D):
		return src
	var std := src as BaseMaterial3D
	var name := std.resource_name
	var col := std.albedo_color
	var key := "%s|%s|%s" % [name, col.to_html(), cuttable]
	if _prop_cache.has(key):
		return _prop_cache[key]
	var out: Material
	if name.begins_with("RZ_Leaves"):
		var f := ShaderMaterial.new()
		f.shader = FOLIAGE_SHADER
		f.set_shader_parameter("leaf_tex", tex("leafmask"))
		f.set_shader_parameter("tint", col)
		f.set_shader_parameter("coverage", 0.45 if name.contains("bush") else 0.5)
		out = f
	elif name.begins_with("RZ_Glass"):
		var g := ShaderMaterial.new()
		g.shader = GLASS_SHADER
		g.render_priority = 1
		g.set_shader_parameter("tint", col)
		g.set_shader_parameter("opacity", 0.5 if name == "RZ_Glass" else 0.35)
		out = g
	elif name == "RZ_Screen":
		var t := ShaderMaterial.new()
		t.shader = TV_SHADER
		out = t
	elif name.begins_with("RZ_Carpet"):
		var c := ShaderMaterial.new()
		c.shader = WORLD_SHADER
		c.set_shader_parameter("albedo_tex", tex("carpet"))
		c.set_shader_parameter("cuttable", cuttable)
		c.set_shader_parameter("tex_meters", Vector2(2.0, 1.4) if name == "RZ_Carpet" else Vector2(2.0, 1.4))
		c.set_shader_parameter("tint", Color.WHITE if name == "RZ_Carpet" else Color("#c8a898"))
		out = c
	elif name.begins_with("RZ_Lamp") and name != "RZ_Lamp_head":
		out = prop_color(col, cuttable, 3.0)
	else:
		out = prop_color(col, cuttable)
	_prop_cache[key] = out
	return out
