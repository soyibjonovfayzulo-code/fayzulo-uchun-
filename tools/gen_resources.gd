extends SceneTree
## Bootstrap generator for item and loot-table resources. Re-run after editing the tables:
##   godot --headless --path . -s tools/gen_resources.gd
## The .tres files it writes are the runtime data (editable in the inspector afterwards).

const C := ItemData.Category

# id: [name, category, weight, description, {extra fields}]
var ITEMS := {
	# --- еда
	"tushenka": ["Тушёнка говяжья", C.FOOD, 0.4, "Жестяная банка, ГОСТ. Сытно и долго хранится. Нужно чем-то открыть.", {"max_stack": 10, "needs_opener": true, "use_verb": "Съесть", "hunger": -0.3, "thirst": 0.03}],
	"kilka": ["Килька в томате", C.FOOD, 0.25, "Маленькая банка, пахнет детством и вокзалом. Нужно чем-то открыть.", {"max_stack": 10, "needs_opener": true, "use_verb": "Съесть", "hunger": -0.18, "thirst": 0.04}],
	"sgushenka": ["Сгущёнка", C.FOOD, 0.4, "Молоко цельное сгущённое с сахаром. Очень калорийно. Нужно чем-то открыть.", {"max_stack": 10, "needs_opener": true, "calm": 0.1, "use_verb": "Съесть", "hunger": -0.22, "thirst": 0.06}],
	"bread": ["Хлеб «Бородинский»", C.FOOD, 0.5, "Чёрный хлеб с кориандром. Скоро зачерствеет.", {"uses": 4, "use_verb": "Съесть", "hunger": -0.1, "fresh_hours": 48.0, "rot_hours": 120.0}],
	"water": ["Вода питьевая 1,5 л", C.DRINK, 1.5, "Пластиковая бутылка негазированной воды.", {"uses": 3, "use_verb": "Выпить", "thirst": -0.3, "empty_id": "empty_bottle"}],
	"soda": ["Лимонад «Буратино»", C.DRINK, 0.6, "Сладкая газировка в стеклянной бутылке.", {"uses": 2, "use_verb": "Выпить", "thirst": -0.2, "hunger": -0.03, "calm": 0.05}],
	"kvas": ["Квас хлебный", C.DRINK, 1.0, "Тёплый и выдохшийся, но утоляет жажду.", {"uses": 3, "use_verb": "Выпить", "thirst": -0.25, "hunger": -0.02}],
	"vodka": ["Водка", C.DRINK, 0.5, "40 градусов. Пить — плохая идея, а вот рану обработать можно.", {"uses": 5, "use_verb": "Выпить", "thirst": -0.04, "disinfects": true, "calm": 0.35, "drowsiness": 0.06}],
	"chocolate": ["Шоколадка", C.FOOD, 0.1, "Молочный шоколад в бумажной обёртке.", {"max_stack": 10, "use_verb": "Съесть", "hunger": -0.08, "calm": 0.12}],
	"buckwheat": ["Гречка, 900 г", C.FOOD, 0.9, "Ядрица. Сухой её есть почти невозможно — сварите с водой в кастрюле на плите или костре.", {"uses": 3, "use_verb": "Съесть сырой", "hunger": -0.05, "thirst": 0.1, "raw": true, "cooked_id": "pot_buckwheat"}],
	"macaroni": ["Макароны «Рожки»", C.FOOD, 0.5, "Сухие макароны. Хрустят. Лучше отварить в кастрюле.", {"uses": 3, "use_verb": "Съесть сырыми", "hunger": -0.05, "thirst": 0.08, "raw": true, "cooked_id": "pot_macaroni"}],
	"sausage": ["Колбаса докторская", C.FOOD, 0.5, "Варёная колбаса. Без холодильника долго не протянет.", {"uses": 3, "use_verb": "Съесть", "hunger": -0.15, "fresh_hours": 24.0, "rot_hours": 72.0}],
	"pickles": ["Огурцы солёные", C.FOOD, 1.0, "Трёхлитровка бабушкиного посола.", {"uses": 3, "use_verb": "Съесть", "hunger": -0.08, "thirst": -0.04}],
	"apple": ["Яблоко", C.FOOD, 0.2, "Антоновка с дачи.", {"use_verb": "Съесть", "hunger": -0.07, "thirst": -0.03, "fresh_hours": 120.0, "rot_hours": 240.0}],
	"crackers": ["Сухари ржаные", C.FOOD, 0.2, "Пачка сухарей с солью.", {"uses": 3, "use_verb": "Съесть", "hunger": -0.08, "thirst": 0.05}],
	# --- медицина
	"bandage": ["Бинт стерильный", C.MEDICAL, 0.05, "Останавливает кровотечение.", {"max_stack": 10, "use_verb": "Перевязать", "stops_bleeding": true, "heal": 4.0}],
	"first_aid": ["Аптечка автомобильная", C.MEDICAL, 0.6, "Бинты, жгут, вата и антисептик.", {"uses": 3, "use_verb": "Оказать помощь", "stops_bleeding": true, "disinfects": true, "heal": 20.0}],
	"zelenka": ["Зелёнка", C.MEDICAL, 0.05, "Бриллиантовый зелёный. Обеззараживает раны.", {"uses": 10, "use_verb": "Обработать рану", "disinfects": true, "heal": 1.0}],
	"iodine": ["Йод", C.MEDICAL, 0.05, "Спиртовой раствор йода 5%.", {"uses": 10, "use_verb": "Обработать рану", "disinfects": true, "heal": 1.0}],
	"analgin": ["Анальгин", C.MEDICAL, 0.03, "Обезболивающее. Снимает боль на несколько часов.", {"uses": 10, "use_verb": "Принять таблетку", "painkiller_hours": 4.0}],
	"plaster": ["Пластырь", C.MEDICAL, 0.03, "Катушка лейкопластыря. Годится только для царапин.", {"uses": 5, "use_verb": "Заклеить царапину", "stops_bleeding": true, "minor_wounds_only": true, "heal": 1.0}],
	# --- оружие
	"knife": ["Нож кухонный", C.WEAPON, 0.3, "Быстрый, но короткий. Хорош, чтобы добить лежачего.", {"equip_slot": "hand", "max_durability": 40, "attack_style": "stab", "damage": 14, "swing_time": 0.45, "reach": 1.05, "arc_deg": 45, "hit_chance": 0.9, "crit_chance": 0.25, "knockback": 0.6, "knockdown_chance": 0.04, "endurance_cost": 0.02, "noise_radius": 3, "door_damage_mult": 0.3, "tags": ["cut"]}],
	"bat": ["Бита", C.WEAPON, 1.0, "Деревянная бейсбольная бита. Сбивает с ног.", {"equip_slot": "hand", "max_durability": 45, "attack_style": "swing", "damage": 20, "swing_time": 0.72, "reach": 1.5, "arc_deg": 80, "hit_chance": 0.85, "crit_chance": 0.1, "knockback": 2.4, "knockdown_chance": 0.4, "endurance_cost": 0.04, "noise_radius": 5, "door_damage_mult": 0.8, "max_targets": 2}],
	"axe": ["Топор", C.WEAPON, 1.8, "Тяжёлый плотницкий топор. Рубит и зомби, и двери.", {"equip_slot": "hand", "max_durability": 70, "attack_style": "swing", "damage": 34, "swing_time": 0.92, "reach": 1.4, "arc_deg": 70, "hit_chance": 0.8, "crit_chance": 0.15, "knockback": 1.6, "knockdown_chance": 0.3, "endurance_cost": 0.06, "noise_radius": 5, "door_damage_mult": 2.0, "max_targets": 2, "tags": ["chop"]}],
	"hammer": ["Молоток", C.WEAPON, 0.7, "Слесарный молоток.", {"equip_slot": "hand", "max_durability": 60, "attack_style": "swing", "damage": 15, "swing_time": 0.55, "reach": 1.15, "arc_deg": 60, "hit_chance": 0.88, "crit_chance": 0.12, "knockback": 1.2, "knockdown_chance": 0.15, "endurance_cost": 0.03, "noise_radius": 4, "door_damage_mult": 1.2, "tags": ["hammer"]}],
	"crowbar": ["Монтировка", C.WEAPON, 1.5, "Стальной лом-гвоздодёр. Взламывает запертые двери.", {"equip_slot": "hand", "max_durability": 120, "attack_style": "swing", "damage": 22, "swing_time": 0.78, "reach": 1.35, "arc_deg": 70, "hit_chance": 0.85, "crit_chance": 0.1, "knockback": 1.8, "knockdown_chance": 0.3, "endurance_cost": 0.045, "noise_radius": 5, "door_damage_mult": 1.6, "tags": ["pry"]}],
	"pipe": ["Обрезок трубы", C.WEAPON, 1.2, "Ржавая водопроводная труба.", {"equip_slot": "hand", "max_durability": 50, "attack_style": "swing", "damage": 18, "swing_time": 0.7, "reach": 1.35, "arc_deg": 75, "hit_chance": 0.83, "crit_chance": 0.08, "knockback": 1.8, "knockdown_chance": 0.3, "endurance_cost": 0.04, "noise_radius": 5}],
	"pistol": ["Пистолет Макарова", C.WEAPON, 0.73, "Табельный ПМ, магазин на 8 патронов. Выстрел слышно на весь район.", {"equip_slot": "hand", "max_durability": 300, "durability_loss": 0.5, "attack_style": "shoot", "damage": 45, "swing_time": 0.38, "reach": 1.0, "fire_range": 18, "hit_chance": 0.85, "crit_chance": 0.2, "knockback": 1.0, "knockdown_chance": 0.25, "endurance_cost": 0.005, "noise_radius": 45, "ammo_id": "ammo", "magazine": 8}],
	"ammo": ["Патроны 9×18 мм", C.AMMO, 0.01, "Пистолетные патроны.", {"max_stack": 50}],
	# --- инструменты
	"screwdriver": ["Отвёртка", C.TOOL, 0.15, "Крестовая отвёртка. В крайнем случае — колющее оружие.", {"equip_slot": "hand", "max_durability": 25, "attack_style": "stab", "damage": 9, "swing_time": 0.45, "reach": 1.0, "arc_deg": 40, "hit_chance": 0.88, "crit_chance": 0.2, "knockback": 0.4, "knockdown_chance": 0.0, "endurance_cost": 0.02, "noise_radius": 3, "door_damage_mult": 0.2, "tags": ["screw"]}],
	"pliers": ["Плоскогубцы", C.TOOL, 0.25, "Пригодятся, когда начнём что-то чинить.", {"tags": ["pliers"]}],
	"saw": ["Ножовка", C.TOOL, 0.5, "Ножовка по дереву.", {"tags": ["saw"]}],
	"wrench": ["Гаечный ключ", C.TOOL, 0.4, "Рожковый ключ на 17. Тяжёлый.", {"equip_slot": "hand", "max_durability": 80, "attack_style": "swing", "damage": 12, "swing_time": 0.6, "reach": 1.1, "arc_deg": 60, "hit_chance": 0.86, "crit_chance": 0.08, "knockback": 1.2, "knockdown_chance": 0.15, "endurance_cost": 0.03, "noise_radius": 4, "tags": ["wrench"]}],
	# --- сумки, одежда, свет, прочее
	"backpack": ["Рюкзак туристический", C.BAG, 1.0, "Брезентовый рюкзак. +14 кг вместимости на спине.", {"equip_slot": "back", "capacity_bonus": 14.0}],
	"sportbag": ["Спортивная сумка", C.BAG, 0.8, "Сумка «Олимпиада». +9 кг вместимости.", {"equip_slot": "back", "capacity_bonus": 9.0}],
	"telogreika": ["Телогрейка", C.CLOTHING, 1.5, "Ватная куртка. Зубам зомби её прокусить непросто, и в ней не замёрзнешь.", {"equip_slot": "body", "protection": 0.35, "warmth": 0.8}],
	"sweater": ["Свитер шерстяной", C.CLOTHING, 0.5, "Колючий, зато тёплый.", {"equip_slot": "body", "protection": 0.15, "warmth": 0.55}],
	"tracksuit": ["Спортивный костюм", C.CLOTHING, 0.6, "Синий, с тремя полосками.", {"equip_slot": "body", "protection": 0.1, "warmth": 0.3}],
	"flashlight": ["Фонарик", C.LIGHT, 0.4, "Работает на батарейках. Наденьте на вторую руку.", {"equip_slot": "offhand", "light_range": 14.0, "use_verb": "Вставить батарейки"}],
	"batteries": ["Батарейки", C.MISC, 0.02, "Пара пальчиковых батареек.", {"max_stack": 10}],
	"matches": ["Спички", C.LIGHT, 0.02, "Коробок спичек. Спичка светит секунд десять.", {"uses": 20, "use_verb": "Зажечь спичку", "light_seconds": 10.0}],
	"lighter": ["Зажигалка", C.LIGHT, 0.04, "Дешёвая пластиковая зажигалка.", {"uses": 60, "use_verb": "Посветить зажигалкой", "light_seconds": 15.0}],
	"cigarettes": ["Сигареты без фильтра", C.MISC, 0.03, "Мятая пачка. Успокаивает нервы.", {"uses": 20, "use_verb": "Закурить", "calm": 0.3}],
	"keys": ["Ключ", C.MISC, 0.02, "Ключ от квартиры.", {}],
	"newspaper": ["Газета «Вечерний Строитель»", C.MISC, 0.1, "Последний выпуск перед тем, как всё началось. Хорошая растопка для костра.", {"use_verb": "Читать", "fuel_hours": 0.25, "calm": 0.05}],
	# --- v0.3: выживание
	"pot": ["Кастрюля", C.TOOL, 0.8, "Алюминиевая кастрюля на 2 литра. В ней варят гречку и макароны.", {"tags": ["pot"]}],
	"pot_buckwheat": ["Гречневая каша", C.FOOD, 1.6, "Горячая рассыпчатая гречка в кастрюле.", {"uses": 3, "use_verb": "Съесть", "hunger": -0.22, "thirst": 0.02, "calm": 0.08, "empty_id": "pot", "fresh_hours": 24.0, "rot_hours": 60.0}],
	"pot_macaroni": ["Макароны отварные", C.FOOD, 1.2, "Разварились, но горячие.", {"uses": 3, "use_verb": "Съесть", "hunger": -0.18, "calm": 0.06, "empty_id": "pot", "fresh_hours": 24.0, "rot_hours": 60.0}],
	"pot_navy": ["Гречка с тушёнкой", C.FOOD, 2.0, "Гречка с говяжьей тушёнкой. Лучшее, что можно съесть в конце света.", {"uses": 4, "use_verb": "Съесть", "hunger": -0.25, "calm": 0.15, "empty_id": "pot", "fresh_hours": 24.0, "rot_hours": 60.0}],
	"can_opener": ["Консервный нож", C.TOOL, 0.1, "Открывает консервы. Без него придётся ковырять банку ножом.", {"tags": ["opener"]}],
	"antibiotics": ["Амоксициллин", C.MEDICAL, 0.04, "Антибиотик. Лечит загноившиеся раны. От укуса зомби не спасёт.", {"uses": 6, "use_verb": "Принять таблетку", "antibiotic_hours": 12.0}],
	"coffee": ["Кофе растворимый", C.DRINK, 0.2, "Банка растворимого кофе. Прогоняет сон.", {"uses": 6, "use_verb": "Выпить кофе", "thirst": 0.02, "drowsiness": -0.25}],
	"sleeping_pills": ["Димедрол", C.MEDICAL, 0.03, "Снотворное. Поможет уснуть, даже если не хочется.", {"uses": 10, "use_verb": "Принять таблетку", "sleep_aid": true, "drowsiness": 0.25}],
	"empty_bottle": ["Пустая бутылка", C.MISC, 0.05, "Пластиковая бутылка. Пока в кранах есть вода, её можно наполнить.", {"fills_to": "water"}],
	"firewood": ["Дрова", C.MISC, 1.5, "Берёзовые поленья. Горят около полутора часов.", {"max_stack": 10, "fuel_hours": 1.5}],
	# --- v0.4: частный сектор, машины
	"potato": ["Картошка", C.FOOD, 0.9, "Сетка молодой картошки с огорода. Сырой не поешь — варите в кастрюле.", {"uses": 3, "use_verb": "Съесть сырой", "hunger": -0.04, "thirst": 0.02, "raw": true, "cooked_id": "pot_potato"}],
	"pot_potato": ["Картошка варёная", C.FOOD, 1.5, "Горячая картошка в мундире. С солью — праздник.", {"uses": 3, "use_verb": "Съесть", "hunger": -0.2, "calm": 0.1, "empty_id": "pot", "fresh_hours": 24.0, "rot_hours": 60.0}],
	"jam": ["Варенье малиновое", C.FOOD, 0.6, "Бабушкино, прошлогоднее. Сладко и успокаивает.", {"uses": 4, "use_verb": "Съесть ложку", "hunger": -0.07, "calm": 0.12}],
	"planks": ["Доски", C.MISC, 2.0, "Обрезные доски. Ими заколачивают окна и двери (нужны молоток и гвозди). Горят в костре.", {"max_stack": 6, "fuel_hours": 1.0}],
	"nails": ["Гвозди", C.MISC, 0.01, "Строительные гвозди, 2 штуки на доску.", {"max_stack": 50}],
	"shotgun": ["Двустволка ИЖ", C.WEAPON, 3.2, "Охотничье ружьё 12 калибра. Два ствола, страшная отдача, валит с ног.", {"equip_slot": "hand", "max_durability": 200, "durability_loss": 0.8, "attack_style": "shoot", "damage": 80, "swing_time": 0.7, "reach": 1.0, "fire_range": 12, "hit_chance": 0.9, "crit_chance": 0.3, "knockback": 2.5, "knockdown_chance": 0.7, "endurance_cost": 0.01, "noise_radius": 55, "ammo_id": "shells", "magazine": 2}],
	"shells": ["Патроны 12 калибра", C.AMMO, 0.04, "Картечь в красных гильзах.", {"max_stack": 25}],
	"jerrycan": ["Канистра", C.MISC, 1.2, "Металлическая канистра на 20 литров. Бензин для машины.", {"uses": 20}],
	"car_key": ["Ключи от машины", C.MISC, 0.03, "Ключ зажигания с брелоком.", {}],
}

const GROCERY := [["tushenka", 4, 3], ["kilka", 4, 3], ["sgushenka", 3, 2], ["buckwheat", 3, 1], ["macaroni", 3, 1], ["bread", 3, 1], ["chocolate", 3, 3], ["crackers", 2, 1], ["soda", 2, 1]]

# id: [[item, weight, max_count], ...], rolls_min, rolls_max, empty_chance
var TABLES := {
	"kitchen_fridge": [[["sausage", 3, 1], ["kvas", 2, 1], ["pickles", 2, 1], ["sgushenka", 2, 1], ["apple", 3, 3], ["vodka", 1, 1], ["water", 2, 1]], 1, 3, 0.25],
	"kitchen_cupboard": [[["pot", 1.5, 1], ["can_opener", 1.5, 1], ["coffee", 1, 1], ["empty_bottle", 1, 1], ["buckwheat", 3, 1], ["macaroni", 3, 1], ["tushenka", 3, 2], ["kilka", 2, 2], ["crackers", 2, 1], ["matches", 2, 1], ["knife", 1.2, 1], ["water", 1, 1], ["bread", 1, 1]], 1, 2, 0.35],
	"kitchen_oven": [[["pot", 2, 1], ["buckwheat", 1, 1], ["knife", 0.5, 1], ["matches", 1, 1]], 1, 1, 0.75],
	"wardrobe": [[["sweater", 3, 1], ["tracksuit", 2, 1], ["telogreika", 1.5, 1], ["sportbag", 1.2, 1], ["backpack", 0.6, 1], ["bat", 0.4, 1], ["newspaper", 1, 1]], 1, 2, 0.3],
	"hall_wardrobe": [[["telogreika", 2.5, 1], ["sportbag", 1.5, 1], ["backpack", 0.8, 1], ["bat", 0.7, 1], ["hammer", 1, 1], ["flashlight", 1, 1], ["screwdriver", 1, 1]], 1, 2, 0.3],
	"living_wardrobe": [[["sleeping_pills", 0.8, 1], ["coffee", 0.6, 1], ["vodka", 2, 1], ["chocolate", 2, 2], ["analgin", 1.5, 1], ["iodine", 1, 1], ["matches", 1, 1], ["newspaper", 1.5, 1], ["cigarettes", 1, 1]], 1, 3, 0.25],
	"drawers": [[["can_opener", 1, 1], ["sleeping_pills", 0.5, 1], ["matches", 2, 1], ["lighter", 1.5, 1], ["cigarettes", 2, 1], ["batteries", 2, 2], ["flashlight", 1, 1], ["analgin", 1.5, 1], ["bandage", 1.5, 2], ["zelenka", 1, 1], ["screwdriver", 1, 1], ["newspaper", 1, 1], ["pistol", 0.08, 1], ["ammo", 0.25, 8]], 1, 2, 0.3],
	"bathroom_cupboard": [[["antibiotics", 0.5, 1], ["sleeping_pills", 1, 1], ["bandage", 3, 3], ["zelenka", 2, 1], ["iodine", 2, 1], ["analgin", 2, 1], ["plaster", 2, 1], ["first_aid", 0.5, 1]], 1, 3, 0.2],
	"shop_shelf": [GROCERY + [["coffee", 1.5, 1], ["can_opener", 0.8, 1]], 2, 4, 0.15],
	"shop_fridge": [[["water", 3, 1], ["soda", 3, 1], ["kvas", 2, 1], ["sausage", 2, 1]], 1, 3, 0.15],
	"shop_counter": [[["cigarettes", 3, 1], ["lighter", 2, 1], ["matches", 2, 1], ["chocolate", 2, 2], ["batteries", 1.5, 2], ["newspaper", 1, 1]], 1, 3, 0.2],
	"storage_shelf": [[["planks", 1, 2], ["nails", 1, 10], ["firewood", 1, 3], ["pot", 0.6, 1], ["tushenka", 3, 4], ["buckwheat", 2, 1], ["macaroni", 2, 1], ["water", 3, 1], ["crowbar", 0.6, 1], ["knife", 0.6, 1], ["pipe", 0.6, 1]], 2, 4, 0.15],
	"pharmacy_shelf": [[["antibiotics", 1.5, 1], ["sleeping_pills", 1.5, 1], ["bandage", 3, 4], ["first_aid", 1, 1], ["zelenka", 2, 1], ["iodine", 2, 1], ["analgin", 3, 1], ["plaster", 2, 1]], 1, 3, 0.15],
	"pharmacy_counter": [[["antibiotics", 0.6, 1], ["analgin", 2, 1], ["bandage", 2, 2], ["plaster", 1, 1], ["first_aid", 0.5, 1]], 1, 2, 0.25],
	"mailbox": [[["newspaper", 4, 1], ["keys", 1.2, 1]], 1, 2, 0.4],
	"office": [[["batteries", 2, 2], ["flashlight", 1, 1], ["cigarettes", 1.5, 1], ["lighter", 1, 1], ["newspaper", 1, 1], ["analgin", 1, 1]], 1, 2, 0.3],
	"garage": [[["planks", 1.5, 3], ["nails", 1.5, 12], ["jerrycan", 1.0, 1], ["firewood", 2.5, 4], ["empty_bottle", 1, 2], ["wrench", 3, 1], ["screwdriver", 2, 1], ["pliers", 2, 1], ["saw", 1.5, 1], ["hammer", 2, 1], ["axe", 1, 1], ["crowbar", 1.2, 1], ["pipe", 1.5, 1], ["batteries", 1, 2], ["flashlight", 1, 1]], 1, 3, 0.15],
	"toolbox": [[["nails", 3, 16], ["screwdriver", 3, 1], ["pliers", 3, 1], ["hammer", 2, 1], ["wrench", 2, 1], ["saw", 1, 1], ["axe", 0.5, 1], ["crowbar", 0.5, 1]], 1, 3, 0.2],
	"car": [[["can_opener", 0.6, 1], ["first_aid", 2, 1], ["flashlight", 1.5, 1], ["batteries", 1.5, 2], ["cigarettes", 1.5, 1], ["wrench", 1.5, 1], ["water", 1, 1], ["newspaper", 1, 1]], 1, 2, 0.35],
	"zombie": [[["car_key", 0.3, 1], ["shells", 0.1, 4], ["cigarettes", 2, 1], ["lighter", 1.5, 1], ["matches", 1, 1], ["keys", 1, 1], ["chocolate", 1, 1], ["analgin", 0.8, 1], ["bandage", 0.6, 1], ["knife", 0.3, 1], ["ammo", 0.15, 6]], 1, 2, 0.5],
	"zombie_militia": [[["pistol", 1.5, 1], ["ammo", 3, 10], ["flashlight", 1, 1], ["cigarettes", 1, 1]], 1, 2, 0.0],
	"village_cupboard": [[["potato", 3, 1], ["jam", 2, 1], ["buckwheat", 2, 1], ["pot", 2, 1], ["matches", 2, 1], ["can_opener", 1, 1], ["tushenka", 1.5, 1], ["pickles", 1.5, 1], ["coffee", 0.6, 1]], 1, 3, 0.2],
	"cellar": [[["potato", 4, 1], ["pickles", 3, 1], ["jam", 3, 1], ["vodka", 1.2, 1], ["apple", 2, 1], ["empty_bottle", 1, 1]], 2, 4, 0.1],
	"chest": [[["sweater", 2, 1], ["telogreika", 1.5, 1], ["vodka", 1.5, 1], ["shells", 1.0, 6], ["shotgun", 0.25, 1], ["newspaper", 1, 1], ["cigarettes", 1, 1], ["matches", 1, 1], ["sleeping_pills", 0.5, 1]], 1, 3, 0.2],
	"shed": [[["firewood", 3, 4], ["planks", 2.5, 4], ["nails", 2.5, 20], ["hammer", 1.5, 1], ["axe", 1, 1], ["saw", 1.2, 1], ["jerrycan", 1, 1], ["pot", 0.8, 1], ["empty_bottle", 1, 2], ["pipe", 0.8, 1]], 2, 4, 0.1],
	"woodpile": [[["firewood", 1, 5]], 1, 2, 0.0],
	"gunsafe": [[["shotgun", 2, 1], ["shells", 3, 15], ["pistol", 1.5, 1], ["ammo", 3, 24]], 2, 3, 0.0],
	"police_drawers": [[["ammo", 2, 8], ["flashlight", 1.5, 1], ["batteries", 1.5, 2], ["car_key", 1, 1], ["cigarettes", 1, 1], ["bandage", 1, 2], ["analgin", 1, 1], ["keys", 0.8, 1]], 1, 3, 0.2],
	"gas_shop": [[["chocolate", 2, 3], ["soda", 2, 1], ["water", 2, 1], ["jerrycan", 2.5, 1], ["cigarettes", 1.5, 1], ["lighter", 1.5, 1], ["crackers", 1, 1], ["batteries", 1, 2], ["car_key", 0.6, 1]], 2, 4, 0.1],
	"zombie_soldier": [[["ammo", 2, 10], ["shells", 1, 6], ["bandage", 1.5, 2], ["first_aid", 0.8, 1], ["tushenka", 1, 1], ["flashlight", 0.8, 1], ["pistol", 0.4, 1]], 1, 3, 0.1],
	"default": [[["newspaper", 1, 1], ["matches", 1, 1], ["batteries", 1, 1], ["cigarettes", 1, 1]], 1, 1, 0.6],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/items"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/loot_tables"))
	var n_items := 0
	for id in ITEMS:
		var spec: Array = ITEMS[id]
		var d := ItemData.new()
		d.id = id
		d.display_name = spec[0]
		d.category = spec[1]
		d.weight = spec[2]
		d.description = spec[3]
		d.icon = load("res://assets/items/icons/%s.png" % id)
		d.model_path = "res://assets/items/%s.glb" % id
		for k in spec[4]:
			var v = spec[4][k]
			if k == "tags":
				d.tags = PackedStringArray(v)
			else:
				d.set(k, v)
		var err := ResourceSaver.save(d, "res://resources/items/%s.tres" % id)
		if err != OK:
			push_error("save failed: " + id)
		n_items += 1
	for id in TABLES:
		var spec: Array = TABLES[id]
		var t := LootTable.new()
		t.id = id
		for e in spec[0]:
			assert(ITEMS.has(e[0]), "unknown item in table %s: %s" % [id, e[0]])
			t.item_ids.append(e[0])
			t.weights.append(float(e[1]))
			t.max_counts.append(int(e[2]))
		t.rolls_min = spec[1]
		t.rolls_max = spec[2]
		t.empty_chance = spec[3]
		ResourceSaver.save(t, "res://resources/loot_tables/%s.tres" % id)
	print("generated %d items, %d loot tables" % [n_items, TABLES.size()])
	quit()
