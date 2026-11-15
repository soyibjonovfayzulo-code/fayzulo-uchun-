extends Control
## Paper-style district map drawn from District.map_shapes, with the player's position and heading.

const COLORS := {
	"road": Color("#5a5650"), "sidewalk": Color("#8a8678"), "path": Color("#9a9484"), "parking": Color("#6a665e"),
	"building": Color("#7a6a58"), "shop": Color("#6a7a8a"), "pharmacy": Color("#5a8a6a"), "playground": Color("#b8a878"),
	"trash": Color("#7a7468"), "garage": Color("#6a625a"), "stop": Color("#4a6a8a"), "misc": Color("#7a7060"),
	"dirt": Color("#9a8a6a"),
}

var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var d := V02District.instance
	if d == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var b := V02District.BOUNDS
	var margin := 60.0
	var scale_f := minf((size.x - margin * 2) / b.size.x, (size.y - margin * 2) / b.size.y)
	var origin := (size - b.size * scale_f) * 0.5
	var to_map := func(p: Vector2) -> Vector2: return origin + (p - b.position) * scale_f
	var paper := Rect2(origin - Vector2(14, 14), b.size * scale_f + Vector2(28, 28))
	draw_rect(paper, Color("#d8d0b8"))
	draw_rect(Rect2(origin, b.size * scale_f), Color("#a8ae88"))
	var labels: Array = []
	for s in d.map_shapes:
		var r: Rect2 = s[0]
		var kind: String = s[1]
		var rr := Rect2(to_map.call(r.position), r.size * scale_f)
		draw_rect(rr, COLORS.get(kind, Color.GRAY))
		if kind in ["building", "shop", "pharmacy", "garage"]:
			draw_rect(rr, Color("#3a3028"), false, 1.5)
		if s[2] != "":
			labels.append([rr, s[2]])
	for l in labels:
		var rr: Rect2 = l[0]
		var txt: String = l[1]
		var fs := 13
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, rr.get_center() + Vector2(-w * 0.5, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#1e1a14"))
	draw_string(_font, paper.position + Vector2(16, 26), "Микрорайон «Строитель»", HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color("#2a2418"))
	draw_string(_font, paper.position + Vector2(16, paper.size.y - 10), "M / Esc — закрыть", HORIZONTAL_ALIGNMENT_LEFT, -1,
		13, Color("#4a4030"))
	var pl := get_tree().get_first_node_in_group("player") as V02Player
	if pl:
		var p: Vector2 = to_map.call(Vector2(pl.global_position.x, pl.global_position.z))
		var f := pl.get_facing_vector()
		var dir := Vector2(f.x, f.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array([p + dir * 10, p - dir * 6 + side * 6, p - dir * 6 - side * 6])
		draw_colored_polygon(pts, Color("#c03020"))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color("#401008"), 1.5)
	# North arrow.
	var na := paper.position + Vector2(paper.size.x - 34, 40)
	draw_line(na + Vector2(0, 14), na - Vector2(0, 14), Color("#2a2418"), 2)
	draw_string(_font, na + Vector2(-5, -18), "С", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#2a2418"))
