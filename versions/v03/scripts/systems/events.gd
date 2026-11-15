extends Node
## Global signal bus. Systems talk through these signals instead of holding references to each other.

@warning_ignore("unused_signal")
signal toast(text: String)
@warning_ignore("unused_signal")
signal noise_emitted(position: Vector3, radius: float, source: Node)
@warning_ignore("unused_signal")
signal interaction_focus_changed(target: Node)
@warning_ignore("unused_signal")
signal player_location_changed(building: Node, level: int)
@warning_ignore("unused_signal")
signal container_opened(container: Node)
@warning_ignore("unused_signal")
signal player_attacked(origin: Vector3, direction: Vector3, reach: float)
@warning_ignore("unused_signal")
signal window_broken(window: Node)
@warning_ignore("unused_signal")
signal inventory_toggle_requested
@warning_ignore("unused_signal")
signal player_hurt(amount: float)
@warning_ignore("unused_signal")
signal zombie_killed(zombie: Node)
@warning_ignore("unused_signal")
signal context_menu_requested(target: Node, actions: Array)


func show_toast(text: String) -> void:
	toast.emit(text)
