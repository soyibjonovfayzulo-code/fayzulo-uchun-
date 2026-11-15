class_name Crosshair
extends Control
## First-person crosshair (v0.5): four ticks that open up while moving, sprinting and shooting, a dot
## that turns warm over something usable, a hit marker (red on a kill), and red arcs pointing towards
## whoever just hurt you.

var spread := 6.0
var focus := false
var aiming := false
var _hit_t := 0.0
var _kill := false
var _hurts: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func hit(killed: bool) -> void:
	_hit_t = 0.22
	_kill = killed


## `angle` in radians clockwise from straight ahead.
func hurt(angle: float) -> void:
	_hurts.append([angle, 1.2])


func _process(delta: float) -> void:
	_hit_t = maxf(_hit_t - delta, 0.0)
	for h in _hurts:
		h[1] -= delta
	_hurts = _hurts.filter(func(h: Array) -> bool: return h[1] > 0.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var col := Color(1.0, 0.98, 0.92, 0.85)
	var shadow := Color(0, 0, 0, 0.55)
	var g := spread
	var l := 7.0
	if not aiming:
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var a: Vector2 = c + d * g
			var b: Vector2 = c + d * (g + l)
			draw_line(a + Vector2(1, 1), b + Vector2(1, 1), shadow, 2.0)
			draw_line(a, b, col, 2.0)
	var dot := Color("#f0b060") if focus else col
	draw_circle(c + Vector2(1, 1), 2.2, shadow)
	draw_circle(c, 2.0 if not focus else 3.0, dot)
	if _hit_t > 0.0:
		var hc := Color(0.9, 0.15, 0.1, _hit_t / 0.22) if _kill else Color(1, 1, 1, _hit_t / 0.22)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var dn: Vector2 = d.normalized()
			draw_line(c + dn * 7.0, c + dn * 14.0, hc, 2.5)
	for h in _hurts:
		var ang: float = h[0]
		var alpha: float = clampf(h[1], 0.0, 1.0)
		var r := minf(size.x, size.y) * 0.22
		draw_arc(c, r, ang - PI * 0.5 - 0.35, ang - PI * 0.5 + 0.35, 16, Color(0.85, 0.08, 0.05, 0.75 * alpha), 6.0)
