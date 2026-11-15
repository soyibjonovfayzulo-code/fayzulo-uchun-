class_name V01CameraRig
extends Node3D
## Isometric (2:1 dimetric) orthographic camera: pitch 30 deg, yaw 45 deg. Follows the target with a
## little lag, zooms with the mouse wheel and snaps to the render-texel grid to avoid pixel shimmer.

const PITCH := -30.0
const YAW := 45.0
const DISTANCE := 60.0

@export var target_path: NodePath
@export var zoom := 15.0
@export var min_zoom := 7.0
@export var max_zoom := 34.0
@export var follow_speed := 7.0

@onready var camera: Camera3D = $Camera3D

var target: Node3D
var _focus := Vector3.ZERO
var _zoom_target := 15.0


func _ready() -> void:
	target = get_node_or_null(target_path) as Node3D
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 1.0
	camera.far = 160.0
	rotation_degrees = Vector3(PITCH, YAW, 0)
	camera.position = Vector3(0, 0, DISTANCE)
	_zoom_target = zoom
	camera.size = zoom
	if target:
		_focus = target.global_position
	RenderingServer.global_shader_parameter_set("cut_cam_dir", -global_basis.z)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		_zoom_target = clampf(_zoom_target * 0.88, min_zoom, max_zoom)
	elif event.is_action_pressed("zoom_out"):
		_zoom_target = clampf(_zoom_target / 0.88, min_zoom, max_zoom)


func _process(delta: float) -> void:
	if target == null:
		return
	var goal := target.global_position + Vector3(0, 1.0, 0)
	_focus = _focus.lerp(goal, clampf(delta * follow_speed, 0.0, 1.0))
	zoom = lerpf(zoom, _zoom_target, clampf(delta * 10.0, 0.0, 1.0))
	camera.size = zoom
	# Snap the focus to whole render texels along the camera's screen axes.
	var vp_h := float(camera.get_viewport().get_visible_rect().size.y)
	var texel := zoom / maxf(vp_h, 1.0)
	var right := global_basis.x
	var up := global_basis.y
	var fwd := global_basis.z
	var r := snappedf(_focus.dot(right), texel)
	var u := snappedf(_focus.dot(up), texel)
	var f := _focus.dot(fwd)
	global_position = right * r + up * u + fwd * f


func snap_to_target() -> void:
	if target:
		_focus = target.global_position + Vector3(0, 1.0, 0)
