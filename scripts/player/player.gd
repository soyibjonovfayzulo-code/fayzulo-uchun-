class_name Player
extends CharacterBody3D
## Survivor controller: camera-relative 8-way movement (walk / run / crouch), turning, interaction,
## timed actions (search, eat, bandage), items and equipment, sitting/lying, climbing, fall damage.
## Melee/firearm attacks live in PlayerCombat; injuries in Wounds; sleep, body temperature, cooking and
## campfires in scripts/survival/.

enum State { NORMAL, SEATED, CLIMBING, DEAD, DRIVING }

const WALK_SPEED := 2.3
const RUN_SPEED := 5.0
const CROUCH_SPEED := 1.2
const ACCEL := 12.0
const DECEL := 14.0
const TURN_SPEED := 11.0
const GRAVITY := 18.0
const SAFE_FALL_SPEED := 8.5
## world + zombies + doors
const MASK := 1 | 4 | 32
const FLASHLIGHT_SECONDS := 900.0
const HEADLINES := [
	"«Вечерний Строитель»: В городской больнице вспышка «тяжёлого гриппа». Горздрав просит не паниковать.",
	"«Вечерний Строитель»: На ул. Строителей перекрыт проезд. Военные проводят «учения».",
	"«Вечерний Строитель»: Укусы бродячих собак участились. Обращайтесь в травмпункт немедленно!",
	"«Вечерний Строитель»: Комендантский час с 21:00. Жителям рекомендовано не покидать квартиры.",
	"«Вечерний Строитель»: Программа передач на неделю. В пятницу — «Кавказская пленница».",
]

signal died
signal reanimated(zombie: Node3D)
signal crouch_changed(crouching: bool)
signal action_changed

@onready var model: Node3D = $Model
@onready var animator: CharacterAnimator = $Animator
@onready var health: HealthComponent = $Health
@onready var stats: PlayerStats = $Stats
@onready var interactor: Interactor = $Interactor
@onready var inventory: PlayerInventory = $Inventory
@onready var wounds: Wounds = $Wounds
@onready var combat: PlayerCombat = $Combat

var body_temp: BodyTemperature
var sleep: Sleep
var self_actions: SelfActions
## Zombies killed this life (death screen).
var kills := 0
var reanimated_as: Node3D
var vehicle: Vehicle
## Skill experience by id (see Skills).
var skills := {}

var state := State.NORMAL
var crouching := false
var running := false
var yaw := 0.0
var camera: Camera3D
## First-person camera (v0.5); active while `fp.active`.
var fp: FPCamera
## Direction of the last blow (HUD damage indicator).
var last_hit_from := Vector3.ZERO
var surface := "concrete"
var flashlight_on := true
var _prev_vy := 0.0
var _was_on_floor := true
var _seat: Furniture
var _stand_pos := Vector3.ZERO
var _seat_lying := false
var _action := {}
var _hand_r: Node3D
var _hand_l: Node3D
var _flashlight: SpotLight3D
var _temp_light: OmniLight3D
var _temp_light_left := 0.0
var _push := Vector3.ZERO
## Own walking velocity, kept apart from knockback so pushes do not compound.
var _walk_vel := Vector3.ZERO
var _panic_t := 0.0
var _heart_t := 0.0
var _vomit_t := 0.0
var _going_to_sleep := false


func _ready() -> void:
	add_to_group("player")
	Mats.convert_imported(model, false)
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.4
	collision_layer = 2
	collision_mask = MASK
	animator.step.connect(_on_step)
	health.died.connect(_on_died)
	health.damaged.connect(func(amount: float, _src: Node) -> void:
		if amount >= 3.0:
			Sfx.play_at("hurt", global_position + Vector3.UP, -4.0))
	inventory.equipment_changed.connect(_on_equipment_changed)
	_hand_r = _make_hand("ForearmR")
	_hand_l = _make_hand("ForearmL")
	_flashlight = SpotLight3D.new()
	_flashlight.position = Vector3(0, 1.25, 0.25)
	_flashlight.rotation_degrees = Vector3(-12, 180, 0)
	_flashlight.spot_angle = 28.0
	_flashlight.spot_range = 14.0
	_flashlight.light_energy = 3.5
	_flashlight.light_color = Color("#fff1d0")
	_flashlight.shadow_enabled = not (OS.has_feature("mobile") or OS.get_name() == "Android")
	_flashlight.visible = false
	model.add_child(_flashlight)
	_temp_light = OmniLight3D.new()
	_temp_light.position = Vector3(0, 1.3, 0.2)
	_temp_light.omni_range = 5.0
	_temp_light.light_energy = 0.0
	_temp_light.light_color = Color("#ffb060")
	model.add_child(_temp_light)
	body_temp = BodyTemperature.new()
	body_temp.name = "BodyTemperature"
	add_child(body_temp)
	sleep = Sleep.new()
	sleep.name = "Sleep"
	add_child(sleep)
	sleep.changed.connect(_on_sleep_changed)
	self_actions = SelfActions.new()
	self_actions.name = "SelfActions"
	self_actions.player = self
	add_child(self_actions)
	Events.zombie_killed.connect(func(_z: Node) -> void: kills += 1)


func _make_hand(forearm: String) -> Node3D:
	var arm := model.find_child(forearm, true, false) as Node3D
	var h := Node3D.new()
	h.name = "Hand"
	h.position = Vector3(0, -0.31, 0.0)
	if arm:
		arm.add_child(h)
	else:
		model.add_child(h)
	return h


## Instantly recentres the camera (teleports, tests).
func rig_snap() -> void:
	if camera and camera.get_parent().has_method("snap_to_target"):
		camera.get_parent().call("snap_to_target")


func get_facing_vector() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


func fp_active() -> bool:
	return fp != null and fp.active


## The first-person view turns the body (called every frame by FPCamera).
func fp_face(y: float) -> void:
	yaw = y
	model.rotation.y = y


## Head, torso and arms (with whatever they hold) go to the shadow-only layer in first person.
func set_first_person_body(on: bool) -> void:
	# A mesh belongs to the nearest rig part above it; only the legs stay in view.
	const HIDE := ["Hips", "Torso", "Head", "ArmL", "ArmR", "ForearmL", "ForearmR"]
	for mi in model.find_children("*", "GeometryInstance3D", true, false):
		var g := mi as GeometryInstance3D
		var hidden := false
		var n: Node = g
		while n and n != model:
			if n.name in CharacterAnimator.PART_NAMES:
				hidden = n.name in HIDE
				break
			n = n.get_parent()
		g.layers = FPCamera.HIDDEN_LAYER if on and hidden else 1


## Where shots leave the gun: the view-model muzzle in first person, the chest otherwise.
func muzzle_point(dir: Vector3) -> Vector3:
	if fp_active():
		return fp.viewmodel.muzzle_world()
	return global_position + Vector3.UP * 1.3 + dir * 0.6


func fp_flashlight_on() -> bool:
	return _fp_light


func face_towards(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() > 0.01:
		yaw = atan2(dir.x, dir.z)
		model.rotation.y = yaw


func _unhandled_input(event: InputEvent) -> void:
	if state == State.DEAD:
		return
	if state == State.DRIVING:
		_driving_input(event)
		return
	if event.is_action_pressed("crouch"):
		if state == State.NORMAL:
			crouching = not crouching
			crouch_changed.emit(crouching)
	elif event.is_action_pressed("interact"):
		if state == State.SEATED:
			stand_up()
		elif state == State.NORMAL and _action.is_empty():
			interactor.use_primary()
	elif event.is_action_pressed("attack"):
		if state == State.NORMAL:
			cancel_action()
			combat.try_attack(mouse_world_point())
	elif event.is_action_pressed("context_menu"):
		if state == State.NORMAL and interactor.focused:
			Events.context_menu_requested.emit(interactor.focused, interactor.get_actions())
		elif state == State.NORMAL and fp_active() and inventory.weapon() and inventory.weapon().item.attack_style == "shoot":
			pass  # held right mouse button = aim down the sights (FPCamera)
		elif state == State.NORMAL:
			var own := self_actions.get_actions(self)
			if not own.is_empty():
				Events.context_menu_requested.emit(self_actions, own)
	elif event.is_action_pressed("inventory"):
		Events.inventory_toggle_requested.emit()
	elif event.is_action_pressed("reload"):
		combat.reload()
	elif event.is_action_pressed("flashlight"):
		flashlight_on = not flashlight_on
		Sfx.play_at("tv_click", global_position + Vector3.UP, -8.0)
	elif event.is_action_pressed("toggle_view"):
		if get_parent().has_method("toggle_view"):
			get_parent().call("toggle_view")


func _physics_process(delta: float) -> void:
	match state:
		State.NORMAL:
			_move(delta)
			_process_action(delta)
		State.SEATED:
			if not sleep.active:
				stats.update(delta, false, false, true)
			var seat_in := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			var tm_seat: Vector2 = get_meta("touch_move", Vector2.ZERO)
			if seat_in.length() > 0.5 or tm_seat.length() > 0.5:
				stand_up()
		State.DRIVING:
			_drive(delta)
		State.CLIMBING, State.DEAD:
			pass
	if state != State.DEAD:
		_survival(delta)
	_update_lights(delta)
	_update_animation(delta)


func _move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var tm: Vector2 = get_meta("touch_move", Vector2.ZERO)
	if tm.length() > input.length():
		input = tm
	var dir := Vector3.ZERO
	if input.length() > 0.05:
		var cam_yaw := camera.global_rotation.y if camera else deg_to_rad(45.0)
		dir = Vector3(input.x, 0, input.y).rotated(Vector3.UP, cam_yaw)
		if dir.length() > 1.0:
			dir = dir.normalized()
	var overloaded := inventory.load_ratio() > 1.0
	var touch_run := bool(get_meta("touch_run", false))
	var want_run := (Input.is_action_pressed("run") or touch_run) and dir.length() > 0.1 and stats.can_run() and not overloaded
	if want_run and crouching:
		crouching = false
		crouch_changed.emit(false)
	running = want_run
	var speed := RUN_SPEED if running else (CROUCH_SPEED if crouching else WALK_SPEED)
	speed *= stats.speed_factor() * speed_penalty() * Profession.speed_mult()
	if combat.is_attacking():
		speed *= 0.35
	var target := dir * speed
	var hv := _walk_vel
	hv = hv.move_toward(target, (ACCEL if target.length() > hv.length() else DECEL) * delta * maxf(speed, 1.0))
	_walk_vel = hv
	velocity.x = hv.x + _push.x
	velocity.z = hv.z + _push.z
	_push = _push.move_toward(Vector3.ZERO, delta * 8.0)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	_prev_vy = velocity.y
	move_and_slide()
	_check_landing()

	# Facing: attack direction wins, otherwise movement direction (first person: the view decides).
	var face_dir := Vector3.ZERO
	if fp_active():
		hv = Vector3.ZERO
	if combat.is_attacking():
		face_dir = combat.attack_dir
	elif hv.length() > 0.2:
		face_dir = hv
	if face_dir.length() > 0.01:
		yaw = lerp_angle(yaw, atan2(face_dir.x, face_dir.z), clampf(delta * TURN_SPEED, 0.0, 1.0))
	model.rotation.y = yaw
	hv = _walk_vel
	if not _action.is_empty() and dir.length() > 0.3:
		cancel_action("Действие прервано.")
	stats.update(delta, hv.length() > 0.2, running and hv.length() > 0.5, false)


## Load, pain, injured legs and the cold slow you down.
func speed_penalty() -> float:
	var f := 1.0
	var lr := inventory.load_ratio()
	if lr > 1.0:
		f *= clampf(1.0 - (lr - 1.0) * 0.6, 0.45, 1.0)
	f *= 1.0 - wounds.pain() * 0.35
	f *= 1.0 - wounds.leg_injury() * 0.35
	if body_temp.temp < 35.0:
		f *= 0.85
	return f


func _check_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var impact := -_prev_vy
		if impact > SAFE_FALL_SPEED:
			var dmg := pow(impact - SAFE_FALL_SPEED, 2.0) * 1.6
			health.take_damage(dmg, null, "Падение с высоты")
			Sfx.play_at("thud", global_position, 0.0)
			NoiseSystem.emit(global_position, 8.0, self)
			if dmg > 15.0 and not health.is_dead():
				wounds.add("laceration", "Левая нога" if randf() < 0.5 else "Правая нога")
			if not health.is_dead():
				Events.show_toast("Неудачное падение!" if dmg < 40.0 else "Тяжёлое падение! Ноги не слушаются...")
	_was_on_floor = on_floor


## Mouse cursor projected onto the player's chest-height plane (first person: straight ahead).
func mouse_world_point() -> Vector3:
	if fp_active():
		return fp.camera.global_position + fp.forward() * 6.0
	if camera == null:
		return global_position + get_facing_vector()
	var mp := camera.get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	var plane := Plane(Vector3.UP, global_position.y + 1.0)
	var hit = plane.intersects_ray(from, dir)
	return hit if hit != null else global_position + get_facing_vector()


func _update_animation(_delta: float) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	animator.speed = hv.length() if state == State.NORMAL else 0.0
	animator.running = running
	animator.attack_t = combat.attack_t
	animator.attack_style = combat.attack_style
	var w := inventory.weapon()
	animator.holding = w != null
	animator.two_handed = w != null and w.item.attack_style == "swing" and w.item.weight >= 0.9
	animator.rifle = w != null and w.item.attack_style == "shoot" and w.item.weight >= 2.0
	animator.work_kind = _work_kind()
	if vehicle:
		animator.steer = vehicle.steer
	match state:
		State.NORMAL:
			if not _action.is_empty():
				animator.pose = CharacterAnimator.Pose.WORK
			else:
				animator.pose = CharacterAnimator.Pose.CROUCH if crouching else CharacterAnimator.Pose.STAND
		State.SEATED:
			animator.pose = CharacterAnimator.Pose.LIE if _seat_lying else CharacterAnimator.Pose.SIT
		State.DRIVING:
			animator.pose = CharacterAnimator.Pose.DRIVE
		State.CLIMBING:
			animator.pose = CharacterAnimator.Pose.CLIMB
		State.DEAD:
			animator.pose = CharacterAnimator.Pose.DEAD


## What the hands do during the current timed action (animation only).
func _work_kind() -> String:
	var l := action_label().to_lower()
	if l == "":
		return "search"
	for e in [["пьём", "drink"], ["выпить", "drink"], ["кофе", "drink"], ["съесть", "eat"], ["едим", "eat"], ["сырой", "eat"],
			["перевяз", "bandage"], ["обрабат", "bandage"], ["таблет", "eat"], ["заколач", "hammer"], ["взламыва", "hammer"],
			["отдира", "hammer"], ["варим", "cook"], ["костёр", "cook"], ["читать", "read"], ["газет", "read"]]:
		if l.contains(e[0]):
			return e[1]
	return "search"


var _fp_light := false


func _on_step(_foot: int) -> void:
	var vol := -14.0
	var radius := 4.5
	if running:
		vol = -6.0
		radius = 13.0
	elif crouching:
		vol = -22.0
		radius = 1.5
	var snd := "step_grass_" if surface == "grass" else ("step_floor_" if surface == "floor" else "step_concrete_")
	Sfx.play_at(snd + "*", global_position, vol, 0.12)
	radius *= Profession.noise_mult() * (Skills.noise(self) if crouching else 1.0)
	NoiseSystem.emit(global_position, radius, self)
	if crouching:
		Skills.add_xp(self, "stealth", 0.25)
	elif running:
		Skills.add_xp(self, "fitness", 0.15)


# ---------------------------------------------------------------- survival
func _survival(delta: float) -> void:
	var hours := GameTime.game_hours(delta)
	wounds.process_hours(hours, delta)
	body_temp.update(delta, self)
	if stats.hunger > 0.92 or stats.thirst > 0.92:
		health.take_damage(4.0 * hours, null, "Голод" if stats.hunger > stats.thirst else "Обезвоживание")
	elif not wounds.is_bleeding() and stats.hunger < 0.7 and stats.thirst < 0.7 and stats.poison <= 0.0 \
			and not sleep.active:
		health.heal(3.0 * hours * (2.0 if state == State.SEATED else 1.0))
	if stats.poison > 0.0:
		health.take_damage(5.0 * stats.poison * hours, null, "Пищевое отравление")
		_vomit_t -= delta
		if stats.poison > 0.45 and _vomit_t <= 0.0 and not sleep.active:
			_vomit_t = randf_range(25.0, 50.0)
			stats.hunger = minf(stats.hunger + 0.08, 1.0)
			stats.thirst = minf(stats.thirst + 0.06, 1.0)
			Sfx.play_at("cough", global_position + Vector3.UP, -6.0)
			Events.show_toast("Вас стошнило.")
	if sleep.active:
		return
	_update_panic(delta)
	if stats.drowsiness >= 1.0 and state == State.NORMAL:
		Events.show_toast("Глаза закрываются сами собой... Вы отключились прямо на полу.")
		_lie_on_floor()
		sleep.begin(0.45)


## Zombies hunting you nearby make you panic: worse aim, a pounding heart.
func _update_panic(delta: float) -> void:
	_panic_t -= delta
	if _panic_t <= 0.0:
		_panic_t = 0.3
		var n := 0
		for z in get_tree().get_nodes_in_group("zombies"):
			var zz := z as Zombie
			if zz == null or zz.is_dead() or absf(zz.global_position.y - global_position.y) > 2.0:
				continue
			var d := zz.global_position.distance_to(global_position)
			if d < 3.5 or (d < 9.0 and zz.state in [Zombie.State.CHASE, Zombie.State.ATTACK]):
				n += 1
		if n > 0:
			stats.add_panic(0.035 * n * (0.5 if crouching else 1.0))
	if stats.panic > 0.55:
		_heart_t -= delta
		if _heart_t <= 0.0:
			_heart_t = lerpf(0.95, 0.55, stats.panic)
			Sfx.play_ui("heartbeat", lerpf(-14.0, -4.0, stats.panic))


func is_sleeping() -> bool:
	return sleep != null and sleep.active


func is_outdoors() -> bool:
	return District.instance == null or District.surface_at(global_position) != "floor"


# ---------------------------------------------------------------- timed actions
## Runs `callback` after `seconds` unless the player moves or attacks (PZ-style timed action).
func start_timed_action(label: String, seconds: float, callback: Callable) -> void:
	if state != State.NORMAL:
		return
	cancel_action()
	velocity = Vector3.ZERO
	_walk_vel = Vector3.ZERO
	seconds *= Profession.action_mult()
	_action = {"label": label, "t": 0.0, "total": seconds, "cb": callback}
	action_changed.emit()


func cancel_action(message := "") -> void:
	if _action.is_empty():
		return
	_action = {}
	action_changed.emit()
	if message != "":
		Events.show_toast(message)


func action_progress() -> float:
	return -1.0 if _action.is_empty() else clampf(_action["t"] / _action["total"], 0.0, 1.0)


func action_label() -> String:
	return _action.get("label", "")


func _process_action(delta: float) -> void:
	if _action.is_empty():
		return
	_action["t"] += delta
	if _action["t"] >= _action["total"]:
		var cb: Callable = _action["cb"]
		_action = {}
		action_changed.emit()
		cb.call()


# ---------------------------------------------------------------- items
## Actions offered for a carried stack in the inventory menu: [{"id", "label"}].
func item_actions(s: ItemStack) -> Array:
	var a: Array = []
	var d := s.item
	if d.use_verb != "":
		a.append({"id": "use", "label": d.use_verb})
	if d.id == "vodka":
		a.append({"id": "disinfect", "label": "Обработать рану"})
	if d.cooked_id != "":
		a.append({"id": "howto", "label": "Как приготовить?"})
	if inventory.can_equip(s):
		if inventory.is_equipped(s):
			a.append({"id": "unequip", "label": "Снять"})
		else:
			var verb := {"hand": "Взять в руку", "offhand": "Взять во вторую руку", "back": "Надеть на спину", "body": "Надеть"}
			a.append({"id": "equip", "label": verb.get(inventory.slot_for(s), "Экипировать")})
	if d.magazine > 0:
		a.append({"id": "reload", "label": "Зарядить (%d в магазине)" % s.loaded})
		if s.loaded > 0:
			a.append({"id": "unload", "label": "Разрядить"})
	return a


func use_item(s: ItemStack, mode := "use") -> void:
	if state != State.NORMAL or not inventory.main.has(s):
		return
	var d := s.item
	match mode:
		"equip":
			inventory.equip(s)
			return
		"unequip":
			inventory.unequip(inventory.equipped_slot(s))
			return
		"reload":
			if inventory.weapon() != s:
				inventory.equip(s)
			combat.reload()
			return
		"unload":
			combat.unload(s)
			return
		"howto":
			Events.show_toast("Нужны кастрюля и вода: подойдите к газовой плите или к горящему костру.")
			return
		"disinfect":
			if wounds.list.is_empty():
				Events.show_toast("Ран нет.")
				return
			start_timed_action("Обрабатываем рану водкой...", 2.0, func() -> void:
				wounds.disinfect()
				spend_use(s)
				Events.show_toast("Жжёт! Рана обработана."))
			return
	if d.stops_bleeding and not wounds.is_bleeding() and d.heal < 10.0:
		Events.show_toast("Кровотечения нет.")
		return
	if d.disinfects and d.category == ItemData.Category.MEDICAL and not d.stops_bleeding and wounds.list.is_empty():
		Events.show_toast("Обрабатывать нечего.")
		return
	if d.id == "flashlight":
		var bat := inventory.main.find_by_id("batteries")
		if bat == null:
			Events.show_toast("Нет батареек.")
			return
		start_timed_action("Меняем батарейки...", 1.5, func() -> void:
			inventory.consume(bat)
			s.charge = 1.0
			inventory.main.changed.emit()
			Events.show_toast("Фонарик заряжен."))
		return
	if d.sleep_aid and wounds.pain() > 0.55:
		Events.show_toast("Сначала снимите боль.")
	var dur := 2.0
	var label := "%s: %s" % [d.use_verb, s.get_name()]
	if d.needs_opener:
		if inventory.main.find_by_id("can_opener") != null:
			dur = 2.6
			label = "Открываем консервным ножом и едим: " + s.get_name()
		elif has_opener():
			dur = 4.5
			label = "Ковыряем банку ножом и едим: " + s.get_name()
		else:
			Events.show_toast("Нечем открыть банку: нужен консервный нож, нож или отвёртка.")
			return
	match d.category:
		ItemData.Category.DRINK:
			dur = 1.6
		ItemData.Category.MEDICAL:
			dur = (3.0 if d.stops_bleeding else 1.5) * Skills.action_time(self, "firstaid")
		ItemData.Category.LIGHT, ItemData.Category.MISC:
			dur = 1.0 if d.light_seconds > 0.0 else 3.0
	start_timed_action(label, dur, func() -> void: _apply_item(s))


func _apply_item(s: ItemStack) -> void:
	if not inventory.main.has(s):
		return
	var d := s.item
	var appetite := 0.6 if wounds.infection_stage() >= 1 or stats.poison > 0.2 else 1.0
	var fresh := s.freshness()
	var food_mult := 1.0 if fresh == ItemStack.Fresh.FRESH else (0.8 if fresh == ItemStack.Fresh.STALE else 0.5)
	stats.hunger = clampf(stats.hunger + d.hunger * (appetite * food_mult if d.hunger < 0.0 else 1.0), 0.0, 1.0)
	stats.thirst = clampf(stats.thirst + d.thirst, 0.0, 1.0)
	stats.drowsiness = clampf(stats.drowsiness + d.drowsiness, 0.0, 1.0)
	stats.panic = maxf(stats.panic - d.calm, 0.0)
	if d.heal > 0.0:
		health.heal(d.heal)
	var msg := ""
	if d.antibiotic_hours > 0.0:
		wounds.antibiotic_hours = maxf(wounds.antibiotic_hours, d.antibiotic_hours)
		msg = "Антибиотик принят. Воспаление должно отступить." if wounds.has_festering() else "Антибиотик принят."
	if d.sleep_aid:
		sleep.take_pill()
		msg = "Димедрол подействует быстро. Найдите, где лечь."
	if d.stops_bleeding:
		var w := wounds.bandage(d.minor_wounds_only)
		msg = "Перевязано: %s." % w if w != "" else ""
		if w != "":
			Skills.add_xp(self, "firstaid", 8.0)
			health.heal(Skills.level_of(self, "firstaid") * 1.5)
	if d.disinfects and d.category == ItemData.Category.MEDICAL:
		wounds.disinfect()
		if msg == "":
			msg = "Рана обработана."
	if d.painkiller_hours > 0.0:
		wounds.painkiller_hours = d.painkiller_hours
		msg = "Боль отступает."
	if d.light_seconds > 0.0:
		_temp_light_left = d.light_seconds
		Sfx.play_at("tv_click", global_position + Vector3.UP, -10.0)
	if d.id == "cigarettes":
		stats.fatigue = maxf(stats.fatigue - 0.03, 0.0)
		stats.craving = 0.0
		msg = "Затянулись. Руки перестали дрожать."
	if d.id == "newspaper":
		Events.show_toast(HEADLINES[randi() % HEADLINES.size()])
		return
	if d.is_food():
		msg = "%s: вкусно." % d.display_name if d.hunger < -0.15 else ""
		if d.drowsiness < 0.0:
			msg = "Горький кофе. Сон как рукой сняло."
		if d.raw:
			msg = "Сухая крупа скрипит на зубах. Лучше сварить."
			if randf() < 0.25:
				stats.poison = maxf(stats.poison, 0.2)
				msg = "Живот скрутило от сырой крупы."
		match fresh:
			ItemStack.Fresh.STALE:
				if randf() < 0.25:
					stats.poison = maxf(stats.poison, 0.3)
					msg = "Что-то с этой едой было не так... Тошнит."
			ItemStack.Fresh.ROTTEN:
				if randf() < 0.8:
					stats.poison = minf(stats.poison + (0.33 if Profession.has_trait("iron_gut") else 0.65), 1.0)
					msg = "Тухлятина! Вам очень плохо. Пищевое отравление."
		Sfx.play_at("eat" if d.category == ItemData.Category.FOOD else "drink", global_position + Vector3.UP, -6.0)
	spend_use(s)
	if msg != "":
		Events.show_toast(msg)


## Uses up one portion; the last one leaves the container behind (empty bottle, pot).
func spend_use(s: ItemStack) -> void:
	var empty := s.item.empty_id
	if s.item.uses > 1:
		s.uses_left -= 1
		if s.uses_left <= 0:
			inventory.main.remove(s)
		else:
			inventory.main.changed.emit()
			empty = ""
	else:
		inventory.consume(s)
	if empty != "":
		inventory.give(empty)


## A can opener, a knife or a screwdriver opens tins.
func has_opener() -> bool:
	for st in inventory.main.stacks:
		if st.item.id == "can_opener" or "cut" in st.item.tags or "screw" in st.item.tags:
			return true
	return false


func has_fire_starter() -> bool:
	return inventory.main.find_by_id("matches") != null or inventory.main.find_by_id("lighter") != null


## Spends one match (or a lighter use). Returns false without any.
func use_fire_starter() -> bool:
	var st := inventory.main.find_by_id("matches")
	if st == null:
		st = inventory.main.find_by_id("lighter")
	if st == null:
		return false
	spend_use(st)
	return true


## Carried fuel, firewood first.
func fuel_items() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for st in inventory.main.stacks:
		if st.item.fuel_hours > 0.0:
			out.append(st)
	out.sort_custom(func(a: ItemStack, b: ItemStack) -> bool: return a.item.fuel_hours > b.item.fuel_hours)
	return out


func build_campfire() -> void:
	if not is_outdoors():
		Events.show_toast("Костёр в квартире? Плохая идея.")
		return
	var fuel := fuel_items()
	if fuel.is_empty() or not has_fire_starter():
		Events.show_toast("Нужны дрова или газета и спички.")
		return
	start_timed_action("Разводим костёр...", 4.0, func() -> void:
		var f := fuel_items()
		if f.is_empty() or not use_fire_starter():
			return
		var hours := f[0].item.fuel_hours
		inventory.consume(f[0])
		var at := global_position + get_facing_vector() * 0.9
		at.y = global_position.y
		Campfire.build(get_parent() as Node3D, at, hours)
		Sfx.play_at("match", at, -4.0)
		Events.show_toast("Костёр разгорелся. У огня тепло, на нём можно готовить."))


func collect_rain() -> void:
	var b := inventory.main.find_by_id("empty_bottle")
	if b == null:
		return
	start_timed_action("Собираем дождевую воду...", 5.0, func() -> void:
		if not inventory.main.has(b):
			return
		inventory.consume(b)
		var w := inventory.give("water")
		w.uses_left = 2
		inventory.main.changed.emit()
		Events.show_toast("Бутылка наполнилась дождевой водой."))


## Tap water (kitchen sink): fill every empty bottle and top up opened ones.
func fill_bottles(well := false) -> void:
	if not well and not Climate.has_water():
		Events.show_toast("Из крана ничего не течёт. Воду отключили.")
		return
	start_timed_action("Набираем воду из-под крана...", 3.0, func() -> void:
		var n := 0
		for st in inventory.main.stacks.duplicate():
			if st.item.fills_to != "":
				for i in st.count:
					inventory.give(st.item.fills_to)
					n += 1
				inventory.main.remove(st)
			elif st.item.id == "water" and st.uses_left < st.item.uses:
				st.uses_left = st.item.uses
				n += 1
		Sfx.play_at("tap_water", global_position + Vector3.UP, -6.0)
		inventory.main.changed.emit()
		Events.show_toast("Набрано бутылок: %d." % n if n > 0 else "Нечего наполнять: нужна бутылка."))


func drink_tap(well := false) -> void:
	if not well and not Climate.has_water():
		Events.show_toast("Из крана ничего не течёт. Воду отключили.")
		return
	start_timed_action("Пьём из-под крана...", 3.0, func() -> void:
		stats.thirst = 0.0
		Sfx.play_at("tap_water", global_position + Vector3.UP, -6.0)
		Events.show_toast("Вы напились воды из-под крана."))


func has_refillable() -> bool:
	for st in inventory.main.stacks:
		if st.item.fills_to != "" or (st.item.id == "water" and st.uses_left < st.item.uses):
			return true
	return false


func pick_up(w: WorldItem) -> void:
	if inventory.main.total_weight() + w.stack.total_weight() > inventory.main.capacity + 12.0:
		Events.show_toast("Слишком тяжело, не унести.")
		return
	inventory.main.add(w.stack, true)
	Sfx.play_at("pickup", w.global_position, -8.0)
	w.queue_free()


## Drops (part of) a carried stack at the feet. Items go into the current floor's prop layer.
func drop_item(s: ItemStack, amount := -1) -> WorldItem:
	if not inventory.main.has(s):
		return null
	var part := inventory.main.take(s, s.count if amount < 0 else amount)
	Sfx.play_at("pickup", global_position, -10.0)
	return WorldItem.drop(part, drop_parent(), global_position + get_facing_vector() * 0.35)


func drop_parent() -> Node3D:
	for b in get_tree().get_nodes_in_group("buildings"):
		var bb := b as Building
		if bb.contains_point(global_position):
			return bb.levels[bb.level_at(global_position)].get_node("Props") as Node3D
	return get_parent() as Node3D


## Jacket colours per worn clothing item (top, trim).
const CLOTHING_COLORS := {
	"": [Color("#4b5240"), Color("#3b4133")],
	"telogreika": [Color("#3c4036"), Color("#2a2c26")],
	"sweater": [Color("#7a3e32"), Color("#5a2c24")],
	"tracksuit": [Color("#2f4a7a"), Color("#d8d8d0")],
}
var _back_model: Node3D


func _apply_clothing() -> void:
	var s: ItemStack = inventory.equipped["body"]
	var cols: Array = CLOTHING_COLORS.get(s.item.id if s else "", CLOTHING_COLORS[""])
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			if src == null:
				continue
			var nm := src.resource_name
			var want: Color
			if nm == "RZ_player_top" or nm == "RZ_player_collar":
				want = cols[0] if nm == "RZ_player_top" else cols[0].darkened(0.2)
			elif nm == "RZ_player_top_dark":
				want = cols[1]
			else:
				continue
			var cur := m.get_surface_override_material(i)
			if cur is ShaderMaterial:
				var own := (cur as ShaderMaterial).duplicate() as ShaderMaterial
				own.set_shader_parameter("tint", want)
				m.set_surface_override_material(i, own)


## Backpack on the back, sports bag at the hip.
func _apply_back() -> void:
	if _back_model and is_instance_valid(_back_model):
		_back_model.queue_free()
	_back_model = null
	var s: ItemStack = inventory.equipped["back"]
	var torso := model.find_child("Torso", true, false) as Node3D
	if s == null or torso == null or s.item.model_path == "":
		return
	var ps := load(s.item.model_path) as PackedScene
	if ps == null:
		return
	_back_model = ps.instantiate() as Node3D
	torso.add_child(_back_model)
	Mats.convert_imported(_back_model, false)
	if s.item.id == "backpack":
		_back_model.position = Vector3(0, 0.03, -0.2)
		_back_model.rotation_degrees.y = 180.0
	else:
		_back_model.position = Vector3(-0.2, -0.12, -0.02)
		_back_model.rotation_degrees = Vector3(0, 90, 8)
	if fp_active():
		set_first_person_body(true)


func _on_equipment_changed(slot: String) -> void:
	if slot == "body":
		_apply_clothing()
		return
	if slot == "back":
		_apply_back()
		return
	var hand := _hand_r if slot == "hand" else (_hand_l if slot == "offhand" else null)
	if hand == null:
		return
	for c in hand.get_children():
		c.queue_free()
	var s: ItemStack = inventory.equipped[slot]
	if s == null or s.item.model_path == "":
		return
	var ps := load(s.item.model_path) as PackedScene
	if ps == null:
		return
	var m := ps.instantiate() as Node3D
	hand.add_child(m)
	Mats.convert_imported(m, false)
	var box := Props.local_aabb(m)
	# Item models lie along +X: point it down the forearm (pistols straight, long weapons slightly forward).
	var x_axis := Vector3(0, -1, 0) if s.item.attack_style == "shoot" else Vector3(0, -0.6, 0.8).normalized()
	var z_axis := Vector3(0, 0, 1) if s.item.attack_style == "shoot" else Vector3(-1, 0, 0)
	if absf(x_axis.dot(z_axis)) > 0.5:
		z_axis = Vector3(1, 0, 0)
	var y_axis := z_axis.cross(x_axis).normalized()
	m.basis = Basis(x_axis, y_axis, x_axis.cross(y_axis))
	var grip := Vector3(box.position.x + minf(0.07, box.size.x * 0.3), box.get_center().y, box.get_center().z)
	if s.item.attack_style == "shoot" or s.item.light_range > 0.0:
		grip = box.get_center()
	m.position = -(m.basis * grip)
	if fp_active():
		set_first_person_body(true)


func _update_lights(delta: float) -> void:
	var fl: ItemStack = inventory.equipped["offhand"]
	var on := fl != null and fl.item.light_range > 0.0 and fl.charge > 0.0 and flashlight_on and state != State.DEAD
	_fp_light = on and fp_active() and state != State.DRIVING
	_flashlight.visible = on and not _fp_light
	if on:
		_flashlight.spot_range = fl.item.light_range
		_flashlight.light_energy = 3.5 * clampf(fl.charge * 4.0, 0.25, 1.0)
		fl.charge = maxf(fl.charge - delta / FLASHLIGHT_SECONDS, 0.0)
		if fl.charge <= 0.0:
			Events.show_toast("Батарейки сели.")
	if _temp_light_left > 0.0:
		_temp_light_left -= delta
		_temp_light.light_energy = 1.2 + randf() * 0.3
	else:
		_temp_light.light_energy = 0.0


# ---------------------------------------------------------------- damage from zombies
## Called by a zombie that connected with a swipe or a bite.
func take_zombie_hit(attacker: Node3D, damage: float, wound_type: String) -> void:
	if state == State.DEAD:
		return
	if state == State.DRIVING and vehicle:
		# The car body takes it until the glass and doors give way.
		vehicle.health = maxf(vehicle.health - 2.5, 0.0)
		Sfx.play_at("door_bang", vehicle.global_position + Vector3.UP, -6.0)
		if vehicle.health > 30.0:
			stats.add_panic(0.05)
			return
	cancel_action()
	if state == State.SEATED:
		sleep.wake("")
		stand_up()
	var from := (global_position - attacker.global_position)
	from.y = 0
	_push = from.normalized() * 2.2
	var protected := randf() < inventory.protection()
	last_hit_from = from.normalized()
	if fp_active():
		fp.jolt(from.normalized(), 1.0 if not protected else 0.5)
	health.take_damage(damage * Settings.zombie_damage * (0.5 if protected else 1.0), attacker)
	if not protected and not health.is_dead():
		var w := wounds.add(wound_type)
		var names := {"scratch": "Вас поцарапали!", "laceration": "Глубокая рваная рана!", "bite": "ВАС УКУСИЛИ!"}
		Events.show_toast("%s (%s)" % [names[wound_type], (w["part"] as String).to_lower()])
		animator.hit(from.normalized(), 1.0 if wound_type == "bite" else 0.7)
		stats.add_panic(0.25 if wound_type == "bite" else 0.12)
		BloodFX.splash(global_position + Vector3.UP * 1.1, from.normalized(), 0.7)
	elif protected:
		Events.show_toast("Одежда защитила от укуса.")
	Events.player_hurt.emit(damage)


# ---------------------------------------------------------------- furniture
func sit_on(seat: Furniture, at: Transform3D, lying: bool) -> void:
	if state != State.NORMAL:
		return
	_seat = seat
	_seat_lying = lying
	_stand_pos = global_position
	state = State.SEATED
	crouching = false
	velocity = Vector3.ZERO
	_walk_vel = Vector3.ZERO
	collision_mask = 0
	var target := at.origin - Vector3(0, 0.9, 0) if not lying else at.origin - Vector3(0, 0.05, 0)
	var tw := create_tween()
	tw.tween_property(self, "global_position", target, 0.35)
	var face := at.basis.get_euler().y
	yaw = face
	model.rotation.y = face
	if lying:
		model.rotation = Vector3(-PI * 0.5, face, 0)
		model.position = Vector3(0, 0.12, 0) + Basis(Vector3.UP, face) * Vector3(0, 0, 0.85)
		if not _going_to_sleep:
			Events.show_toast("Вы легли отдохнуть. Нажмите E или клавишу движения, чтобы встать.")
	else:
		Events.show_toast("Вы присели. Выносливость восстанавливается быстрее.")


## Sleep on a bed/sofa (furniture) or on the floor (null). Quality decides how fast drowsiness drains.
func try_sleep(seat: Furniture) -> void:
	if state != State.NORMAL:
		return
	var why := sleep.blocker()
	if why != "":
		Events.show_toast(why)
		return
	var q := 0.5
	if seat:
		q = 1.0 if seat.use == Furniture.Use.BED else 0.75
		_going_to_sleep = true
		sit_on(seat, seat.call("_nearest_point", self), true)
		_going_to_sleep = false
	else:
		_lie_on_floor()
	sleep.begin(q)
	Events.show_toast("Вы засыпаете... (E — проснуться)")


func _lie_on_floor() -> void:
	cancel_action()
	_seat = null
	_seat_lying = true
	_stand_pos = global_position
	state = State.SEATED
	crouching = false
	velocity = Vector3.ZERO
	_walk_vel = Vector3.ZERO
	model.rotation = Vector3(-PI * 0.5, yaw, 0)
	model.position = Vector3(0, 0.12, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.85)


func _on_sleep_changed(on: bool) -> void:
	if not on and state == State.SEATED:
		stand_up()


func stand_up() -> void:
	if state != State.SEATED:
		return
	if sleep.active:
		sleep.wake("Вы встали.")
		return
	model.rotation = Vector3(0, yaw, 0)
	model.position = Vector3.ZERO
	state = State.CLIMBING
	var tw := create_tween()
	tw.tween_property(self, "global_position", _stand_pos, 0.3)
	tw.tween_callback(func() -> void:
		collision_mask = MASK
		state = State.NORMAL)
	_seat = null


# ---------------------------------------------------------------- windows
func climb_through_window(win: WindowObj) -> void:
	if state != State.NORMAL:
		return
	state = State.CLIMBING
	crouching = false
	velocity = Vector3.ZERO
	_walk_vel = Vector3.ZERO
	collision_mask = 0
	var sill := win.get_sill_point()
	var target := win.get_climb_target(global_position)
	var face := target - global_position
	yaw = atan2(face.x, face.z)
	model.rotation.y = yaw
	var tw := create_tween()
	tw.tween_property(self, "global_position", Vector3(sill.x, sill.y - 0.2, sill.z), 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "global_position", Vector3(target.x, maxf(target.y - 0.5, sill.y - 1.0), target.z), 0.5)
	tw.tween_callback(func() -> void:
		collision_mask = MASK
		state = State.NORMAL
		_was_on_floor = false
		if win.is_hazardous():
			health.take_damage(randf_range(6.0, 14.0), win, "Порезы стеклом")
			wounds.add("scratch", "Левая рука" if randf() < 0.5 else "Правая рука")
			Events.show_toast("Порезались об осколки стекла!"))
	Sfx.play_at("climb", sill, -6.0)
	NoiseSystem.emit(sill, 4.0, self)


func _on_died() -> void:
	if sleep.active:
		sleep.wake("")
	if state == State.DRIVING:
		exit_vehicle()
	state = State.DEAD
	cancel_action()
	velocity = Vector3.ZERO
	_walk_vel = Vector3.ZERO
	collision_layer = 0
	model.rotation = Vector3(0, yaw, 0)
	model.position = Vector3.ZERO
	died.emit()
	if wounds.infected:
		_reanimate()


## The infected always come back: the body gets up as one of them and the camera follows it.
func _reanimate() -> void:
	await get_tree().create_timer(Settings.reanimate_seconds).timeout
	if not is_inside_tree():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	var z := Zombie.spawn(get_parent().get_node("Zombies"), global_position + Vector3.UP * 0.1, rng, "player")
	z.yaw = yaw
	model.visible = false
	reanimated_as = z
	# You watch yourself get up as one of them from the outside.
	if fp_active() and get_parent().has_method("set_first_person"):
		get_parent().call("set_first_person", false)
	Sfx.play_at("zombie_groan_1", global_position + Vector3.UP, 0.0)
	var rig := get_parent().get_node_or_null("CameraRig")
	if rig:
		rig.set("target", z)
	reanimated.emit(z)


# ------------------------------------------------------------------------------------------------ save
func save_state() -> Dictionary:
	var eq := {}
	for slot in PlayerInventory.SLOTS:
		var st: ItemStack = inventory.equipped[slot]
		eq[slot] = inventory.main.stacks.find(st) if st else -1
	return {"pos": [global_position.x, global_position.y, global_position.z], "yaw": yaw, "hp": health.health,
		"stats": stats.save_state(), "wounds": wounds.save_state(), "temp": body_temp.save_state(),
		"inv": inventory.main.to_array(), "eq": eq, "kills": kills, "fl": flashlight_on, "crouch": crouching,
		"skills": skills.duplicate(), "mhp": health.max_health}


func load_state(d: Dictionary) -> void:
	var p: Array = d.get("pos", [global_position.x, global_position.y, global_position.z])
	global_position = Vector3(p[0], p[1], p[2])
	yaw = float(d.get("yaw", 0.0))
	model.rotation.y = yaw
	health.health = float(d.get("hp", health.max_health))
	stats.load_state(d.get("stats", {}))
	wounds.load_state(d.get("wounds", {}))
	body_temp.load_state(d.get("temp", {}))
	for slot in PlayerInventory.SLOTS:
		inventory.unequip(slot)
	inventory.main.load_array(d.get("inv", []))
	var eq: Dictionary = d.get("eq", {})
	for slot in eq:
		var i := int(eq[slot])
		if i >= 0 and i < inventory.main.stacks.size():
			inventory.equip(inventory.main.stacks[i], slot)
	kills = int(d.get("kills", 0))
	skills = (d.get("skills", {}) as Dictionary).duplicate()
	health.max_health = float(d.get("mhp", health.max_health))
	flashlight_on = bool(d.get("fl", true))
	crouching = bool(d.get("crouch", false))
	_walk_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	rig_snap()


# ------------------------------------------------------------------------------------------------ driving
func enter_vehicle(v: Vehicle) -> void:
	if state != State.NORMAL or v.driver != null:
		return
	cancel_action()
	vehicle = v
	v.driver = self
	state = State.DRIVING
	crouching = false
	velocity = Vector3.ZERO
	_walk_vel = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	Sfx.play_at("door_close", v.global_position + Vector3.UP, -4.0)
	v.set_interior(fp_active())
	var rig := get_parent().get_node_or_null("CameraRig")
	if rig:
		rig.set("target", v)
	if v.fuel <= 0.0:
		Events.show_toast("Бак пуст. Нужна канистра или АЗС.")
	elif v.has_key(self) or v.hotwired:
		v.set_engine(true)
		Events.show_toast("Двигатель завёлся. W/S — газ и тормоз, A/D — руль, Пробел — ручник, Q — сигнал, E — выйти.")
	else:
		Events.show_toast("Ключа нет. [R] — завести напрямую (нужна отвёртка), E — выйти.")
	Events.vehicle_changed.emit(v)


func exit_vehicle() -> void:
	if state != State.DRIVING or vehicle == null:
		return
	var v := vehicle
	var p := v.exit_point()
	v.set_engine(false)
	v.drive_input(0.0, 0.0, true, 0.1)
	v.driver = null
	v.set_interior(false)
	vehicle = null
	state = State.NORMAL
	global_position = p
	collision_mask = MASK
	# The teleport out of the seat is a kinematic move through the car's body: with the player's layer on,
	# Jolt treats it as a 90 m/s shove and launches the car. Turn the layer back on once settled.
	_restore_layer_later()
	model.rotation = Vector3(0, yaw, 0)
	var rig := get_parent().get_node_or_null("CameraRig")
	if rig:
		rig.set("target", self)
		rig.set("_zoom_target", 15.0)
	Sfx.play_at("door_close", p + Vector3.UP, -4.0)
	Events.vehicle_changed.emit(null)


func _restore_layer_later() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if state == State.NORMAL:
		collision_layer = 2


func _drive(delta: float) -> void:
	var v := vehicle
	if v == null or not is_instance_valid(v):
		state = State.NORMAL
		return
	var t := Input.get_axis("move_down", "move_up")
	var st := Input.get_axis("move_right", "move_left")
	var tm_d: Vector2 = get_meta("touch_move", Vector2.ZERO)
	if absf(tm_d.x) > absf(st):
		st = -tm_d.x
	if absf(tm_d.y) > absf(t):
		t = -tm_d.y
	v.drive_input(t if v.engine_on else 0.0, st, Input.is_action_pressed("handbrake"), delta)
	var seat := v.seat_transform()
	global_position = seat.origin - Vector3(0, 0.86, 0)
	yaw = seat.basis.get_euler().y
	model.rotation = Vector3(0, yaw, 0)
	stats.update(delta, false, false, false)
	var rig := get_parent().get_node_or_null("CameraRig")
	if rig:
		rig.set("_zoom_target", lerpf(15.0, 24.0, clampf(absf(v.speed) / v.top_speed, 0.0, 1.0)))


func _driving_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		exit_vehicle()
	elif event.is_action_pressed("horn"):
		vehicle.horn()
	elif event.is_action_pressed("flashlight"):
		vehicle.headlights = not vehicle.headlights
	elif event.is_action_pressed("reload") and not vehicle.engine_on:
		_hotwire()
	elif event.is_action_pressed("inventory"):
		Events.inventory_toggle_requested.emit()


## Starting a car without the key: screwdriver, nerves and time. Mechanics skill and the right job help.
func _hotwire() -> void:
	var v := vehicle
	if v.fuel <= 0.0:
		Events.show_toast("Бак пуст.")
		return
	if v.has_key(self) or v.hotwired:
		v.set_engine(true)
		return
	var tool := inventory.main.stacks.filter(func(st: ItemStack) -> bool: return "screw" in st.item.tags)
	if tool.is_empty():
		Events.show_toast("Чтобы завести без ключа, нужна отвёртка.")
		return
	var chance := 0.35 + Skills.level_of(self, "mechanics") * 0.08 + (0.5 if Profession.has_perk(self, "hotwire") else 0.0)
	Events.show_toast("Ковыряем замок зажигания...")
	Sfx.play_at("drawer", v.global_position + Vector3.UP, -6.0)
	await get_tree().create_timer(3.0).timeout
	if vehicle != v:
		return
	Skills.add_xp(self, "mechanics", 12.0)
	if randf() < chance:
		v.hotwired = true
		v.set_engine(true)
		Events.show_toast("Провода замкнуты — мотор ожил!")
	else:
		Sfx.play_at("engine_fail", v.global_position + Vector3.UP, -4.0)
		NoiseSystem.emit(v.global_position, 8.0, self)
		Events.show_toast("Не вышло. Попробуйте ещё раз [R].")


func camera_shake(amount: float) -> void:
	if fp_active():
		fp.add_shake(amount)
	var rig := get_parent().get_node_or_null("CameraRig")
	if rig and rig.has_method("add_shake"):
		rig.call("add_shake", amount)
