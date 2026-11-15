class_name Well
extends Interactable
## Village well: water that never runs out, even after the town's supply is cut.


func _ready() -> void:
	display_name = "Колодец"
	focus_offset = Vector3(0, 1.0, -0.7)
	focus_radius = 0.6
	super._ready()
	add_to_group("wells")


func get_actions(actor: Node) -> Array:
	var a: Array = [{"id": "drink", "label": "Попить из колодца"}]
	var p := actor as Player
	if p and p.has_refillable():
		a.insert(0, {"id": "fill", "label": "Набрать воду в бутылки"})
	return a


func perform(action_id: String, actor: Node) -> void:
	var p := actor as Player
	if p == null:
		return
	match action_id:
		"drink":
			p.drink_tap(true)
		"fill":
			p.fill_bottles(true)
