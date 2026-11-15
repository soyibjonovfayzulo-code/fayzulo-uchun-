class_name ItemData
extends Resource
## Static description of an item type (one .tres per item in res://resources/items/).

enum Category { FOOD, DRINK, MEDICAL, WEAPON, AMMO, TOOL, CLOTHING, BAG, LIGHT, MISC }

const CATEGORY_NAMES := {
	Category.FOOD: "Еда", Category.DRINK: "Напиток", Category.MEDICAL: "Медицина", Category.WEAPON: "Оружие",
	Category.AMMO: "Патроны", Category.TOOL: "Инструмент", Category.CLOTHING: "Одежда", Category.BAG: "Сумка",
	Category.LIGHT: "Свет", Category.MISC: "Разное",
}

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var category: Category = Category.MISC
@export var icon: Texture2D
@export var model_path := ""
@export var weight := 0.1
@export var max_stack := 1
## Portions for multi-use items (water bottle = 3 sips). Multi-use items never stack.
@export var uses := 1
## 0 = unbreakable.
@export var max_durability := 0.0
@export var tags: PackedStringArray = PackedStringArray()

@export_group("Use")
## Verb shown in menus ("Съесть", "Выпить", "Перевязать"...). Empty = not usable directly.
@export var use_verb := ""
## Per portion; negative values reduce hunger / thirst.
@export var hunger := 0.0
@export var thirst := 0.0
@export var heal := 0.0
@export var stops_bleeding := false
## Plasters only close scratches.
@export var minor_wounds_only := false
@export var disinfects := false
@export var painkiller_hours := 0.0
@export var light_seconds := 0.0
## Per portion: coffee wakes you up (negative), pills make you sleepy.
@export var drowsiness := 0.0
## Sleeping pills: lets you fall asleep even when not tired.
@export var sleep_aid := false
## Antibiotics: hours of treatment against festering wounds.
@export var antibiotic_hours := 0.0
## Lowers panic (cigarettes, vodka, a hot meal).
@export var calm := 0.0
## Tins need a can opener, a knife or a screwdriver.
@export var needs_opener := false
## Raw groats: edible but barely (cook them on a stove or a campfire).
@export var raw := false
## Item this becomes after cooking ("" = cannot be cooked).
@export var cooked_id := ""
## Item left behind when the last portion is used (water -> empty bottle, kasha -> pot).
@export var empty_id := ""
## Empty containers refill at a tap into this item.
@export var fills_to := ""
## Game hours of burning when put into a campfire (0 = not fuel).
@export var fuel_hours := 0.0

@export_group("Freshness")
## Game hours the food stays fresh, then stale; rotten after rot_hours (0 = never spoils).
@export var fresh_hours := 0.0
@export var rot_hours := 0.0

@export_group("Equip")
## "hand" (weapon/tool), "offhand" (flashlight), "back" (bags), "body" (clothes).
@export var equip_slot := ""
@export var capacity_bonus := 0.0
## 0..1: chance that clothing prevents a scratch/bite from breaking the skin.
@export var protection := 0.0
@export var light_range := 0.0
## 0..1 insulation against cold.
@export var warmth := 0.0

@export_group("Weapon")
@export var attack_style := ""
@export var damage := 0.0
@export var swing_time := 0.6
@export var reach := 1.1
@export var arc_deg := 60.0
@export var hit_chance := 0.85
@export var crit_chance := 0.1
@export var knockback := 1.0
@export var knockdown_chance := 0.1
@export var endurance_cost := 0.03
@export var durability_loss := 1.0
@export var noise_radius := 4.0
@export var door_damage_mult := 1.0
@export var max_targets := 1
@export var ammo_id := ""
@export var magazine := 0
@export var fire_range := 0.0


func is_weapon() -> bool:
	return attack_style != ""


func is_stackable() -> bool:
	return max_stack > 1 and uses <= 1 and max_durability <= 0.0


func is_perishable() -> bool:
	return rot_hours > 0.0


func is_food() -> bool:
	return category == Category.FOOD or category == Category.DRINK


func category_name() -> String:
	return CATEGORY_NAMES.get(category, "")
