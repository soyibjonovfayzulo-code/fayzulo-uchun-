class_name V04Profession
extends RefCounted
## Character creation data: occupations (starting skills, kit and perks) and traits (point-buy:
## positive traits cost points, negative ones give them back).

const LIST := {
	"unemployed": {"name": "Безработный", "points": 8, "desc": "Ничего не умеет, зато больше очков на черты характера.",
		"skills": {}, "kit": [], "perks": []},
	"mechanic": {"name": "Автослесарь", "points": 0, "desc": "Механика 3. Заводит машины без ключа с первой попытки. Отвёртка и гаечный ключ.",
		"skills": {"mechanics": 3}, "kit": [["screwdriver", 1], ["wrench", 1]], "perks": ["hotwire"]},
	"medic": {"name": "Фельдшер скорой", "points": 0, "desc": "Первая помощь 3: быстрее перевязывает. Бинты, йод и антибиотик.",
		"skills": {"firstaid": 3}, "kit": [["bandage", 3], ["iodine", 1], ["antibiotics", 1]], "perks": []},
	"police": {"name": "Участковый", "points": -2, "desc": "Стрельба 2, ближний бой 1. Табельный ПМ и 16 патронов.",
		"skills": {"firearm": 2, "melee": 1}, "kit": [["pistol", 1], ["ammo", 16]], "perks": []},
	"carpenter": {"name": "Плотник", "points": 0, "desc": "Плотничество 3: быстро заколачивает окна, доски держат дольше. Молоток, гвозди, доски.",
		"skills": {"carpentry": 3}, "kit": [["hammer", 1], ["nails", 20], ["planks", 2]], "perks": []},
	"cook": {"name": "Повар столовой", "points": 2, "desc": "Кулинария 3: готовит быстрее, еда сытнее. Кастрюля, гречка и нож.",
		"skills": {"cooking": 3}, "kit": [["pot", 1], ["buckwheat", 1], ["knife", 1]], "perks": []},
	"veteran": {"name": "Ветеран", "points": -4, "desc": "Ближний бой 2, стрельба 2. Почти не паникует рядом с зомби.",
		"skills": {"melee": 2, "firearm": 2}, "kit": [["knife", 1]], "perks": ["no_panic"]},
	"hunter": {"name": "Охотник", "points": -2, "desc": "Скрытность 3, стрельба 1. Двустволка и 6 патронов картечи.",
		"skills": {"stealth": 3, "firearm": 1}, "kit": [["shotgun", 1], ["shells", 6]], "perks": []},
}

## id: [name, cost (+ costs points, - gives points), description]
const TRAITS := {
	"fast": ["Быстрые ноги", 4, "Ходит и бегает на 8% быстрее."],
	"strong": ["Здоровяк", 4, "Здоровье 125 вместо 100."],
	"nimble": ["Ловкие руки", 3, "Все действия (обыск, перевязка, готовка) на 25% быстрее."],
	"quiet": ["Тихоня", 3, "Шаги на 30% тише."],
	"iron_gut": ["Крепкий желудок", 2, "Отравления вдвое слабее."],
	"sleeper": ["Крепкий сон", 2, "Высыпается на 30% быстрее."],
	"smoker": ["Курильщик", -2, "Без сигарет нервничает: паника нарастает быстрее."],
	"clumsy": ["Неуклюжий", -3, "Шумит при ходьбе на 30% больше."],
	"glutton": ["Обжора", -2, "Голод растёт на 35% быстрее."],
	"weak": ["Хилый", -3, "Здоровье 80 вместо 100."],
	"coward": ["Трус", -2, "Паникует вдвое сильнее."],
	"slow": ["Медлительный", -3, "Ходит на 8% медленнее."],
}


static func data(_p: Node) -> Dictionary:
	return LIST.get(V04Settings.profession, LIST["unemployed"])


static func has_perk(_p: Node, perk: String) -> bool:
	return perk in (LIST.get(V04Settings.profession, LIST["unemployed"])["perks"] as Array)


static func has_trait(id: String) -> bool:
	return id in V04Settings.traits


## Points left for a profession + trait selection (must be >= 0 to start).
static func points_left(prof: String, traits: Array) -> int:
	var pts: int = LIST.get(prof, LIST["unemployed"])["points"]
	for t in traits:
		pts -= int(TRAITS[t][1])
	return pts


static func speed_mult() -> float:
	return (1.08 if has_trait("fast") else 1.0) * (0.92 if has_trait("slow") else 1.0)


static func noise_mult() -> float:
	return (0.7 if has_trait("quiet") else 1.0) * (1.3 if has_trait("clumsy") else 1.0)


static func panic_mult() -> float:
	var m := (2.0 if has_trait("coward") else 1.0)
	if has_perk(null, "no_panic"):
		m *= 0.3
	return m


static func action_mult() -> float:
	return 0.75 if has_trait("nimble") else 1.0


## Applies the starting skills, kit and traits to a fresh survivor.
static func apply(p: V04Player) -> void:
	var d := data(p)
	for id in d["skills"]:
		p.skills[id] = V04Skills.xp_for(int(d["skills"][id])) + 1.0
	for e in d["kit"]:
		var s := p.inventory.give(e[0], int(e[1]))
		if s and s.item.magazine > 0:
			s.loaded = s.item.magazine
	var hp := 100.0
	if has_trait("strong"):
		hp = 125.0
	if has_trait("weak"):
		hp = 80.0
	p.health.max_health = hp
	p.health.health = hp
	p.stats.hunger_mult = 1.35 if has_trait("glutton") else 1.0
	p.stats.panic_mult = panic_mult()
