class_name V03SelfActions
extends V03Interactable
## Right-click on empty ground: things the survivor can do on the spot (sleep on the floor, build a
## campfire outdoors). Not registered as a world interactable, so the Interactor never focuses it.

var player: V03Player


func _ready() -> void:
	display_name = "Вы"
	# No InteractArea: this object is only reached through the context menu.


func get_actions(_actor: Node) -> Array:
	var a: Array = []
	if player == null or player.state != V03Player.State.NORMAL:
		return a
	a.append({"id": "sleep_floor", "label": "Спать прямо здесь (на полу)"})
	if player.is_outdoors():
		var fuel := player.fuel_items()
		if not fuel.is_empty() and player.has_fire_starter():
			a.append({"id": "campfire", "label": "Развести костёр (%s)" % fuel[0].item.display_name})
	if player.inventory.main.find_by_id("empty_bottle") != null and player.is_outdoors() and V03Climate.instance \
			and V03Climate.instance.rain > 0.3:
		a.append({"id": "collect_rain", "label": "Набрать дождевой воды"})
	return a


func perform(action_id: String, _actor: Node) -> void:
	match action_id:
		"sleep_floor":
			player.try_sleep(null)
		"campfire":
			player.build_campfire()
		"collect_rain":
			player.collect_rain()
