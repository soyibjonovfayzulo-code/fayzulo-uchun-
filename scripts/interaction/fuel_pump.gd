class_name FuelPump
extends Interactable
## Gas station pump: fills a jerrycan or a car parked next to it, but only while the town still has power.

const CAR_RANGE := 5.5


func _ready() -> void:
	display_name = "Топливная колонка"
	focus_offset = Vector3(0, 1.2, 0)
	focus_radius = 0.5
	super._ready()
	add_to_group("fuel_pumps")
	Props.spawn("environment/fuel_pump", self, Vector3.ZERO, 0.0)


func nearest_car() -> Vehicle:
	var best: Vehicle = null
	for v in get_tree().get_nodes_in_group("vehicles"):
		var car := v as Vehicle
		var dd := car.global_position.distance_to(global_position)
		if dd < CAR_RANGE and (best == null or dd < best.global_position.distance_to(global_position)):
			best = car
	return best


func get_actions(actor: Node) -> Array:
	var a: Array = []
	var p := actor as Player
	if p == null:
		return a
	var car := nearest_car()
	if car and car.fuel < car.FUEL_MAX - 0.5:
		a.append({"id": "car", "label": "Заправить машину (%d/%d л)" % [roundi(car.fuel), roundi(car.FUEL_MAX)]})
	var can := p.inventory.main.find_by_id("jerrycan")
	if can and can.uses_left < can.item.uses:
		a.append({"id": "can", "label": "Наполнить канистру (%d/%d л)" % [can.uses_left, can.item.uses]})
	if a.is_empty():
		a.append({"id": "look", "label": "Колонка: подгоните машину или возьмите канистру"})
	return a


func perform(action_id: String, actor: Node) -> void:
	var p := actor as Player
	if p == null:
		return
	if action_id == "look":
		Events.show_toast("На АЗС заправляют машины и канистры, пока есть электричество.")
		return
	if not Climate.has_power():
		Events.show_toast("Колонка мертва — без электричества насос не качает.")
		return
	match action_id:
		"car":
			var car := nearest_car()
			if car:
				p.start_timed_action("Заправляем машину...", 4.0, func() -> void:
					car.fuel = car.FUEL_MAX
					Sfx.play_at("tap_water", global_position + Vector3.UP, -8.0)
					Events.show_toast("Полный бак."))
		"can":
			var can := p.inventory.main.find_by_id("jerrycan")
			if can:
				p.start_timed_action("Наполняем канистру...", 3.0, func() -> void:
					can.uses_left = can.item.uses
					p.inventory.main.changed.emit()
					Events.show_toast("Канистра полна: 20 литров."))
