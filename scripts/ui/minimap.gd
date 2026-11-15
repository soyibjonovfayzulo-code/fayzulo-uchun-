extends Control
## Corner minimap (north up): roads, buildings, yards and the forest around the survivor, cars as dots,
## the survivor as an arrow. Drawn from District.map_shapes inside a square frame.

const RADIUS := 95.0
const METERS := 55.0
const COLORS := {
	"road": Color("#4a4844"), "sidewalk": Color("#6a675e"), "path": Color("#77726a"), "parking": Color("#55524c"),
	"building": Color("#8a7a66"), "shop": Color("#6a7a8a"), "pharmacy": Color("#5a8a6a"), "playground": Color("#8a8058"),
	"trash": Color("#5a564e"), "garage": Color("#6a625a"), "stop": Color("#4a6a8a"), "misc": Color("#6a6050"),
	"dirt": Color("#6e6450"), "house": Color("#9a7a54"), "garden": Color("#5a6a3a"), "ruin": Color("#2a2624"),
	"police": Color("#4a5a8a"), "military": Color("#4e5a36"), "forest": Color("#2e4230"), "label": Color(0, 0, 0, 0),
	"car": Color(0, 0, 0, 0),
}


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2, RADIUS * 2)
	size = custom_minimum_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree() and Engine.get_process_frames() % 3 == 0:
		queue_redraw()


func _draw() -> void:
	var d := District.instance
	var pl := get_tree().get_first_node_in_group("player") as Player
	if d == null or pl == null:
		return
	var c := Vector2(RADIUS, RADIUS)
	var k := RADIUS / METERS
	var me := Vector2(pl.global_position.x, pl.global_position.z)
	draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), Color(0.05, 0.05, 0.045, 0.92))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#556046"))
	var view := Rect2(me - Vector2(METERS, METERS), Vector2(METERS, METERS) * 2)
	for s in d.map_shapes:
		var r: Rect2 = s[0]
		if not r.intersects(view):
			continue
		var col: Color = COLORS.get(s[1], Color(0.4, 0.4, 0.4))
		if col.a <= 0.0:
			continue
		var clipped := r.intersection(view)
		var rr := Rect2(c + (clipped.position - me) * k, clipped.size * k)
		draw_rect(rr, col)
	for v in get_tree().get_nodes_in_group("vehicles"):
		var p := Vector2((v as Node3D).global_position.x, (v as Node3D).global_position.z)
		var mp := c + (p - me) * k
		if Rect2(Vector2.ZERO, size).grow(-4).has_point(mp):
			draw_circle(mp, 3.5, Color("#d8b040"))
	var f := pl.get_facing_vector()
	var dir := Vector2(f.x, f.z).normalized()
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([c + dir * 8, c - dir * 5 + side * 5, c - dir * 5 - side * 5])
	draw_colored_polygon(pts, Color("#e04030"))
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BORDER, false, 1.5)
	draw_line(Vector2(0, -1), Vector2(size.x, -1), UiTheme.ACCENT, 2.0)
	draw_string(UiTheme.font(true), Vector2(size.x * 0.5 - 4, 14), "С", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.TEXT)
	var loc := "Улица"
	for b in get_tree().get_nodes_in_group("buildings"):
		if (b as Building).contains_point(pl.global_position):
			loc = (b as Building).display_name
	draw_string(UiTheme.font(), Vector2(6, size.y - 6), loc, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 12, UiTheme.TEXT)
