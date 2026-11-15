class_name V04Skills
extends RefCounted
## Skills that level up through use (PZ-style): every swing, shot, plank, dish, bandage and hotwire
## gives experience. Levels 0..10 make the matching actions stronger, faster or quieter.

const NAMES := {
	"melee": "Ближний бой", "firearm": "Стрельба", "carpentry": "Плотничество", "cooking": "Кулинария",
	"firstaid": "Первая помощь", "mechanics": "Механика", "stealth": "Скрытность", "fitness": "Выносливость",
}
const MAX_LEVEL := 10


static func xp_for(level: int) -> float:
	return 40.0 * pow(float(level), 1.45)


static func level_of(p: Node, id: String) -> int:
	if p == null or not ("skills" in p):
		return 0
	var xp: float = (p.get("skills") as Dictionary).get(id, 0.0)
	var lv := 0
	while lv < MAX_LEVEL and xp >= xp_for(lv + 1):
		lv += 1
	return lv


static func progress(p: Node, id: String) -> float:
	var lv := level_of(p, id)
	if lv >= MAX_LEVEL:
		return 1.0
	var xp: float = (p.get("skills") as Dictionary).get(id, 0.0)
	return clampf((xp - xp_for(lv)) / (xp_for(lv + 1) - xp_for(lv)), 0.0, 1.0)


static func add_xp(p: Node, id: String, amount: float) -> void:
	if p == null or not ("skills" in p):
		return
	var d: Dictionary = p.get("skills")
	var before := level_of(p, id)
	d[id] = float(d.get(id, 0.0)) + amount
	var after := level_of(p, id)
	if after > before:
		V04Events.show_toast("Навык повышен: %s — %d" % [NAMES[id], after])
		V04Sfx.play_ui("pickup", -6.0)


## Multipliers used by gameplay code.
static func melee_damage(p: Node) -> float:
	return 1.0 + level_of(p, "melee") * 0.06


static func melee_accuracy(p: Node) -> float:
	return 1.0 + level_of(p, "melee") * 0.02


static func firearm_accuracy(p: Node) -> float:
	return 1.0 + level_of(p, "firearm") * 0.04


static func action_time(p: Node, id: String) -> float:
	return 1.0 - level_of(p, id) * 0.06


static func noise(p: Node) -> float:
	return 1.0 - level_of(p, "stealth") * 0.07


static func run_drain(p: Node) -> float:
	return 1.0 - level_of(p, "fitness") * 0.05
