class_name VehicleDoor
extends Interactable
## Driver's door of a Vehicle: get in, hotwire, pour fuel from a jerrycan.

var vehicle: Vehicle


func _ready() -> void:
	display_name = vehicle.display_name
	focus_offset = Vector3(0, 1.0, 0)
	focus_radius = 0.6
	super._ready()


func get_actions(actor: Node) -> Array:
	var p := actor as Player
	if p == null:
		return []
	var a: Array = [{"id": "enter", "label": "Сесть за руль: %s" % vehicle.display_name}]
	var can := p.inventory.main.find_by_id("jerrycan")
	if can and can.uses_left > 0 and vehicle.fuel < Vehicle.FUEL_MAX - 0.5:
		a.append({"id": "refuel", "label": "Залить бензин из канистры (%d л в баке)" % roundi(vehicle.fuel)})
	return a


func perform(action_id: String, actor: Node) -> void:
	var p := actor as Player
	if p == null:
		return
	match action_id:
		"enter":
			p.enter_vehicle(vehicle)
		"refuel":
			var can := p.inventory.main.find_by_id("jerrycan")
			if can == null:
				return
			p.start_timed_action("Заливаем бензин...", 3.5, func() -> void:
				var pour := minf(float(can.uses_left), Vehicle.FUEL_MAX - vehicle.fuel)
				vehicle.fuel += pour
				can.uses_left -= int(pour)
				p.inventory.main.changed.emit()
				Events.show_toast("Залито %d л. В баке %d л." % [roundi(pour), roundi(vehicle.fuel)]))
