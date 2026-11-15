class_name V02Wounds
extends Node
## Injuries on a survivor: scratches, lacerations and bites bleed until bandaged; bites (and rarely other
## wounds) can carry the infection. Drives bleeding damage, pain and the infection timeline.

signal changed

const TYPES := {
	"scratch": {"name": "Царапина", "bleed": 0.06, "pain": 0.12, "heal_h": 8.0},
	"laceration": {"name": "Рваная рана", "bleed": 0.18, "pain": 0.3, "heal_h": 30.0},
	"bite": {"name": "Укус", "bleed": 0.22, "pain": 0.45, "heal_h": 48.0},
}

@export var health_path: NodePath

var health: V02HealthComponent
var list: Array[Dictionary] = []
var infected := false
var infection_hours := 0.0
var painkiller_hours := 0.0


func _ready() -> void:
	health = get_node(health_path) as V02HealthComponent


func add(type: String) -> Dictionary:
	var w := {"type": type, "bandaged": false, "disinfected": false, "age": 0.0}
	list.append(w)
	var chance: float = {
		"bite": V02Settings.infection_chance_bite, "scratch": V02Settings.infection_chance_scratch,
		"laceration": V02Settings.infection_chance_laceration,
	}[type]
	if not infected and randf() < chance:
		infected = true
	changed.emit()
	return w


func process_hours(hours: float, real_delta: float) -> void:
	painkiller_hours = maxf(painkiller_hours - hours, 0.0)
	var dirty := false
	for i in range(list.size() - 1, -1, -1):
		var w: Dictionary = list[i]
		var spec: Dictionary = TYPES[w["type"]]
		w["age"] += hours * (2.0 if w["bandaged"] else 1.0) * (1.3 if w["disinfected"] else 1.0)
		if not w["bandaged"]:
			health.take_damage(spec["bleed"] * real_delta)
		if w["age"] >= spec["heal_h"]:
			list.remove_at(i)
			dirty = true
	if infected:
		infection_hours += hours
		if infection_hours > V02Settings.infection_hours_to_death * 0.45:
			health.take_damage(health.max_health / (V02Settings.infection_hours_to_death * 0.55) * hours)
	if dirty:
		changed.emit()


func is_bleeding() -> bool:
	for w in list:
		if not w["bandaged"]:
			return true
	return false


func pain() -> float:
	var p := 0.0
	for w in list:
		p += TYPES[w["type"]]["pain"] * (0.5 if w["bandaged"] else 1.0)
	return 0.0 if painkiller_hours > 0.0 else clampf(p, 0.0, 1.0)


## Bandages the worst bleeding wound (plasters only close scratches). Returns the wound name or "".
func bandage(minor_only: bool) -> String:
	var best := -1
	var order := ["bite", "laceration", "scratch"]
	for t in order:
		if minor_only and t != "scratch":
			continue
		for i in list.size():
			if list[i]["type"] == t and not list[i]["bandaged"]:
				best = i
				break
		if best >= 0:
			break
	if best < 0:
		return ""
	list[best]["bandaged"] = true
	changed.emit()
	return TYPES[list[best]["type"]]["name"]


func disinfect() -> bool:
	var any := false
	for w in list:
		if not w["disinfected"]:
			w["disinfected"] = true
			any = true
	if any:
		changed.emit()
	return any


func has_type(type: String) -> bool:
	for w in list:
		if w["type"] == type:
			return true
	return false


## Visible infection symptoms only show up after a while, like in PZ.
func symptoms() -> String:
	if not infected:
		return ""
	if infection_hours > V02Settings.infection_hours_to_death * 0.45:
		return "Жар"
	if infection_hours > V02Settings.infection_hours_to_death * 0.2:
		return "Тошнота"
	return ""
