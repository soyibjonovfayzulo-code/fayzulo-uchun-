class_name V03Wounds
extends Node
## Injuries on a survivor, each on a body part: scratches, lacerations and bites bleed until bandaged.
## A wound left without disinfection can fester (pain, fever, no healing) until treated with antibiotics.
## Bites (and rarely other wounds) can carry the zombie infection: nausea, then fever, then death and
## reanimation after Settings.infection_hours_to_death game hours.

signal changed

const TYPES := {
	"scratch": {"name": "Царапина", "bleed": 0.06, "pain": 0.12, "heal_h": 8.0},
	"laceration": {"name": "Рваная рана", "bleed": 0.18, "pain": 0.3, "heal_h": 30.0},
	"bite": {"name": "Укус", "bleed": 0.22, "pain": 0.45, "heal_h": 48.0},
}
const PARTS := ["Голова", "Шея", "Торс", "Левая рука", "Правая рука", "Левая нога", "Правая нога"]
## Where zombie swipes and bites land (arms take most of them, like in PZ).
const HIT_WEIGHTS := [0.05, 0.06, 0.22, 0.23, 0.23, 0.105, 0.105]
const FESTER_AFTER_H := 4.0
const FESTER_CHANCE_PER_H := 0.1

@export var health_path: NodePath

var health: V03HealthComponent
var list: Array[Dictionary] = []
var infected := false
var infection_hours := 0.0
var painkiller_hours := 0.0
var antibiotic_hours := 0.0


func _ready() -> void:
	health = get_node(health_path) as V03HealthComponent


static func random_part() -> String:
	var r := randf()
	for i in PARTS.size():
		r -= HIT_WEIGHTS[i]
		if r <= 0.0:
			return PARTS[i]
	return "Торс"


func add(type: String, part := "") -> Dictionary:
	var w := {"type": type, "part": part if part != "" else random_part(), "bandaged": false, "disinfected": false,
		"festering": false, "age": 0.0}
	list.append(w)
	var chance: float = {
		"bite": V03Settings.infection_chance_bite, "scratch": V03Settings.infection_chance_scratch,
		"laceration": V03Settings.infection_chance_laceration,
	}[type]
	if w["part"] == "Шея":
		chance = minf(chance * 1.5, 1.0)
	if not infected and randf() < chance:
		infected = true
	changed.emit()
	return w


func process_hours(hours: float, real_delta: float) -> void:
	painkiller_hours = maxf(painkiller_hours - hours, 0.0)
	antibiotic_hours = maxf(antibiotic_hours - hours, 0.0)
	var dirty := false
	for i in range(list.size() - 1, -1, -1):
		var w: Dictionary = list[i]
		var spec: Dictionary = TYPES[w["type"]]
		if w["festering"]:
			# Infected wounds do not heal; antibiotics (and to a lesser degree disinfection) clear them.
			var cure := (0.35 if antibiotic_hours > 0.0 else 0.0) + (0.04 if w["disinfected"] else 0.0)
			if randf() < cure * hours:
				w["festering"] = false
				dirty = true
		else:
			w["age"] += hours * (2.0 if w["bandaged"] else 1.0) * (1.3 if w["disinfected"] else 1.0)
			if not w["disinfected"] and w["age"] > FESTER_AFTER_H and antibiotic_hours <= 0.0 \
					and randf() < FESTER_CHANCE_PER_H * hours:
				w["festering"] = true
				dirty = true
				V03Events.show_toast("Рана воспалилась: %s, %s." % [spec["name"].to_lower(), (w["part"] as String).to_lower()])
		if not w["bandaged"]:
			var neck := 1.6 if w["part"] == "Шея" else 1.0
			health.take_damage(spec["bleed"] * neck * real_delta, null, "Кровопотеря")
		if w["festering"]:
			health.take_damage(0.8 * hours, null, "Заражение раны")
		if w["age"] >= spec["heal_h"]:
			list.remove_at(i)
			dirty = true
	if infected:
		infection_hours += hours
		if infection_hours > V03Settings.infection_hours_to_death * 0.45:
			health.take_damage(health.max_health / (V03Settings.infection_hours_to_death * 0.55) * hours, null, "Зомби-вирус")
	if dirty:
		changed.emit()


func is_bleeding() -> bool:
	for w in list:
		if not w["bandaged"]:
			return true
	return false


func has_festering() -> bool:
	return list.any(func(w: Dictionary) -> bool: return w["festering"])


func pain() -> float:
	var p := 0.0
	for w in list:
		p += TYPES[w["type"]]["pain"] * (0.5 if w["bandaged"] else 1.0) + (0.25 if w["festering"] else 0.0)
	return 0.0 if painkiller_hours > 0.0 else clampf(p, 0.0, 1.0)


## 0..1: how badly the legs are hurt (slows walking).
func leg_injury() -> float:
	return _part_injury(["Левая нога", "Правая нога"])


## 0..1: how badly the arms are hurt (weaker, less accurate swings).
func arm_injury() -> float:
	return _part_injury(["Левая рука", "Правая рука"])


func _part_injury(parts: Array) -> float:
	var v := 0.0
	for w in list:
		if w["part"] in parts:
			v += {"scratch": 0.1, "laceration": 0.3, "bite": 0.35}[w["type"]] * (0.6 if w["bandaged"] else 1.0)
	return clampf(v, 0.0, 1.0)


## Wounds on one body part (for the health panel).
func on_part(part: String) -> Array:
	return list.filter(func(w: Dictionary) -> bool: return w["part"] == part)


## Bandages the worst bleeding wound (plasters only close scratches). Returns the wound name or "".
func bandage(minor_only: bool, part := "") -> String:
	var best := -1
	var order := ["bite", "laceration", "scratch"]
	for t in order:
		if minor_only and t != "scratch":
			continue
		for i in list.size():
			if list[i]["type"] == t and not list[i]["bandaged"] and (part == "" or list[i]["part"] == part):
				best = i
				break
		if best >= 0:
			break
	if best < 0:
		return ""
	list[best]["bandaged"] = true
	changed.emit()
	return "%s (%s)" % [TYPES[list[best]["type"]]["name"], (list[best]["part"] as String).to_lower()]


func disinfect(part := "") -> bool:
	var any := false
	for w in list:
		if not w["disinfected"] and (part == "" or w["part"] == part):
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


## Zombie infection stage: 0 none/hidden, 1 nausea, 2 fever, 3 dying.
func infection_stage() -> int:
	if not infected:
		return 0
	var f := infection_hours / V03Settings.infection_hours_to_death
	if f > 0.8:
		return 3
	if f > 0.45:
		return 2
	if f > 0.2:
		return 1
	return 0


## Degrees of fever above normal from the infection and festering wounds.
func fever() -> float:
	var f := 0.0
	match infection_stage():
		1:
			f = 0.5
		2:
			f = 1.7
		3:
			f = 2.6
	if has_festering():
		f = maxf(f, 0.9)
	return f


## Visible infection symptoms only show up after a while, like in PZ.
func symptoms() -> String:
	match infection_stage():
		1:
			return "Тошнота"
		2:
			return "Жар"
		3:
			return "Лихорадка"
	return ""


func save_state() -> Dictionary:
	return {"list": list.duplicate(true), "infected": infected, "inf_h": infection_hours,
		"pk": painkiller_hours, "ab": antibiotic_hours}


func load_state(d: Dictionary) -> void:
	list.clear()
	for w in d.get("list", []):
		var e: Dictionary = w
		e["age"] = float(e.get("age", 0.0))
		e["part"] = str(e.get("part", "Торс"))
		e["festering"] = bool(e.get("festering", false))
		list.append(e)
	infected = bool(d.get("infected", false))
	infection_hours = float(d.get("inf_h", 0.0))
	painkiller_hours = float(d.get("pk", 0.0))
	antibiotic_hours = float(d.get("ab", 0.0))
	changed.emit()
