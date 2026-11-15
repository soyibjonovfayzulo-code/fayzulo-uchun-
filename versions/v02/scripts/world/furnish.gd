class_name V02Furnish
extends RefCounted
## Turns prop names into the right gameplay object: searchable container, usable furniture or static prop.

## prop -> [display name, container type]; room type comes from where it is placed.
const CONTAINERS := {
	"furniture/fridge": ["Холодильник", "fridge"],
	"furniture/kitchen_cabinet": ["Кухонный шкафчик", "cupboard"],
	"furniture/kitchen_sink": ["Тумба под мойкой", "cupboard"],
	"furniture/wall_cabinet": ["Навесной шкафчик", "cupboard"],
	"furniture/stove": ["Газовая плита", "oven"],
	"furniture/wardrobe": ["Платяной шкаф", "wardrobe"],
	"furniture/stenka": ["Стенка", "wardrobe"],
	"furniture/dresser": ["Комод", "drawers"],
	"furniture/shop_shelf": ["Стеллаж", "shelf"],
	"furniture/drink_fridge": ["Холодильник с напитками", "fridge"],
	"furniture/shop_counter": ["Прилавок", "counter"],
	"furniture/pharm_shelf": ["Аптечный шкаф", "shelf"],
	"furniture/pharm_counter": ["Аптечный прилавок", "counter"],
	"furniture/mailboxes": ["Почтовые ящики", "mailbox"],
	"furniture/toolbox": ["Ящик с инструментами", "toolbox"],
	"furniture/crate_army": ["Армейский ящик", "crate"],
}

const SEATS := {
	"furniture/sofa": ["Диван", [Vector3(-0.55, 0.45, 0.02), Vector3(0, 0.45, 0.02), Vector3(0.55, 0.45, 0.02)]],
	"furniture/chair": ["Стул", [Vector3(0, 0.48, 0.0)]],
	"furniture/stool": ["Табуретка", [Vector3(0, 0.48, 0.0)]],
	"environment/bench": ["Скамейка", [Vector3(-0.5, 0.47, 0.0), Vector3(0.5, 0.47, 0.0)]],
}


## Spawns `name` at local `pos` under `parent`. Returns the gameplay node (container/furniture) or the prop.
static func place(name: String, parent: Node3D, pos: Vector3, rot_deg: float, room_type := "living",
		display := "") -> Node3D:
	if CONTAINERS.has(name):
		var spec: Array = CONTAINERS[name]
		var c := V02LootContainer.new()
		c.position = pos
		c.rotation_degrees.y = rot_deg
		c.name = name.get_file()
		# Model and setup first: _ready() (on add_child) needs them.
		var prop := V02Props.spawn(name, c, Vector3.ZERO, 0.0)
		c.setup(prop, display if display != "" else spec[0], spec[1], room_type)
		parent.add_child(c, true)
		return c
	if SEATS.has(name) or name == "furniture/bed" or name == "furniture/tv":
		var f := V02Furniture.new()
		f.position = pos
		f.rotation_degrees.y = rot_deg
		f.name = name.get_file()
		var prop2 := V02Props.spawn(name, f, Vector3.ZERO, 0.0)
		var pts: Array[Vector3] = []
		var kind := V02Furniture.Use.SEAT
		var nice := ""
		if name == "furniture/bed":
			kind = V02Furniture.Use.BED
			pts.append(Vector3(0, 0.5, 0.05))
			nice = "Кровать"
		elif name == "furniture/tv":
			kind = V02Furniture.Use.TV
			pts.append(Vector3(0, 0.8, 0.0))
			nice = "Телевизор"
		else:
			nice = SEATS[name][0]
			for p in SEATS[name][1]:
				pts.append(p)
		f.setup(prop2, nice, kind, pts)
		parent.add_child(f, true)
		return f
	return V02Props.spawn(name, parent, pos, rot_deg)
