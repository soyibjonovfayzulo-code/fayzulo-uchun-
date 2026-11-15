class_name V02Furniture
extends V02Interactable
## Usable non-container furniture: seats (sit), beds (lie down / rest) and TVs (power toggle).

enum Use { SEAT, BED, TV }

@export var use := Use.SEAT
## Local seat/lie points (several people could fit a bench; the nearest free one is used).
@export var points: Array[Vector3] = [Vector3(0, 0.45, 0)]
## Local yaw (degrees) the user faces while seated.
@export var facing_deg := 0.0

var model: Node3D
var tv_on := false
var _tv_timer := 0.0


func setup(prop: Node3D, nice_name: String, kind: Use, seat_points: Array[Vector3]) -> void:
	model = prop
	display_name = nice_name
	use = kind
	points = seat_points


func _ready() -> void:
	focus_offset = points[0] + Vector3(0, 0.3, 0.1)
	if use == Use.TV:
		focus_offset = Vector3(0, 0.8, 0.25)
	super._ready()


func get_actions(_actor: Node) -> Array:
	match use:
		Use.SEAT:
			return [{"id": "sit", "label": "Сесть"}]
		Use.BED:
			return [{"id": "lie", "label": "Лечь отдохнуть"}, {"id": "sit", "label": "Сесть на край"}]
		Use.TV:
			return [{"id": "tv", "label": "Выключить телевизор" if tv_on else "Включить телевизор"}]
	return []


func perform(action_id: String, actor: Node) -> void:
	match action_id:
		"sit":
			if actor.has_method("sit_on"):
				actor.sit_on(self, _nearest_point(actor), false)
		"lie":
			if actor.has_method("sit_on"):
				actor.sit_on(self, _nearest_point(actor), true)
		"tv":
			_set_tv(not tv_on)


func _nearest_point(actor: Node) -> Transform3D:
	var best := points[0]
	if actor is Node3D:
		var lp := to_local((actor as Node3D).global_position)
		for p in points:
			if p.distance_to(lp) < best.distance_to(lp):
				best = p
	var face := Basis(Vector3.UP, deg_to_rad(facing_deg))
	return global_transform * Transform3D(face, best)


func _set_tv(on: bool) -> void:
	tv_on = on
	if model == null:
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_surface_override_material(i)
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader == V02Mats.TV_SHADER:
				var own := (mat as ShaderMaterial).duplicate() as ShaderMaterial
				own.set_shader_parameter("powered", on)
				m.set_surface_override_material(i, own)
	if on:
		V02Events.show_toast("Телевизор шипит помехами... Электричество ещё есть.")
	V02Sfx.play_at("tv_click", get_focus_point(), -6.0)


func _process(delta: float) -> void:
	if not tv_on:
		return
	_tv_timer -= delta
	if _tv_timer <= 0.0:
		_tv_timer = 1.5
		V02Sfx.play_at("tv_static", get_focus_point(), -10.0, 0.0)
		V02NoiseSystem.emit(global_position, 9.0, self)
