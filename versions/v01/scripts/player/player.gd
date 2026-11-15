class_name V01Player
extends CharacterBody3D
## Survivor controller: camera-relative 8-way movement (walk / run / crouch), turning, attacks,
## interaction, sitting/lying, climbing through windows and fall damage.

enum State { NORMAL, SEATED, CLIMBING, DEAD }

const WALK_SPEED := 2.3
const RUN_SPEED := 5.0
const CROUCH_SPEED := 1.2
const ACCEL := 12.0
const DECEL := 14.0
const TURN_SPEED := 11.0
const GRAVITY := 18.0
const ATTACK_TIME := 0.62
const SAFE_FALL_SPEED := 8.5

signal died
signal crouch_changed(crouching: bool)

@onready var model: Node3D = $Model
@onready var animator: V01CharacterAnimator = $Animator
@onready var health: V01HealthComponent = $Health
@onready var stats: V01PlayerStats = $Stats
@onready var interactor: V01Interactor = $Interactor

var state := State.NORMAL
var crouching := false
var running := false
var yaw := 0.0
var camera: Camera3D
var surface := "concrete"
var _attack_t := -1.0
var _attack_dir := Vector3.FORWARD
var _prev_vy := 0.0
var _was_on_floor := true
var _seat: V01Furniture
var _stand_pos := Vector3.ZERO
var _seat_lying := false


func _ready() -> void:
	add_to_group("player")
	V01Mats.convert_imported(model, false)
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.4
	collision_layer = 2
	collision_mask = 1 | 4
	animator.step.connect(_on_step)
	health.died.connect(_on_died)
	health.damaged.connect(func(amount: float, _src: Node) -> void:
		if amount >= 3.0:
			V01Sfx.play_at("hurt", global_position + Vector3.UP, -4.0))


## Instantly recentres the camera (teleports, tests).
func rig_snap() -> void:
	if camera and camera.get_parent().has_method("snap_to_target"):
		camera.get_parent().call("snap_to_target")


func get_facing_vector() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


func _unhandled_input(event: InputEvent) -> void:
	if state == State.DEAD:
		return
	if event.is_action_pressed("crouch"):
		if state == State.NORMAL:
			crouching = not crouching
			crouch_changed.emit(crouching)
	elif event.is_action_pressed("interact"):
		if state == State.SEATED:
			stand_up()
		elif state == State.NORMAL:
			interactor.use_primary()
	elif event.is_action_pressed("attack"):
		if state == State.NORMAL and _attack_t < 0.0:
			_start_attack()
	elif event.is_action_pressed("context_menu"):
		if state == State.NORMAL and interactor.focused:
			V01Events.context_menu_requested.emit(interactor.focused, interactor.get_actions())
	elif event.is_action_pressed("inventory"):
		V01Events.show_toast("Инвентарь появится в Milestone 4.")


func _physics_process(delta: float) -> void:
	match state:
		State.NORMAL:
			_move(delta)
		State.SEATED:
			stats.update(delta, false, false, true)
			if Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.5:
				stand_up()
		State.CLIMBING, State.DEAD:
			pass
	_update_animation(delta)


func _move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3.ZERO
	if input.length() > 0.05:
		var cam_yaw := camera.global_rotation.y if camera else deg_to_rad(45.0)
		dir = Vector3(input.x, 0, input.y).rotated(Vector3.UP, cam_yaw)
		if dir.length() > 1.0:
			dir = dir.normalized()
	var want_run := Input.is_action_pressed("run") and dir.length() > 0.1 and stats.can_run()
	if want_run and crouching:
		crouching = false
		crouch_changed.emit(false)
	running = want_run
	var speed := RUN_SPEED if running else (CROUCH_SPEED if crouching else WALK_SPEED)
	speed *= stats.speed_factor()
	if _attack_t >= 0.0:
		speed *= 0.35
	var target := dir * speed
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.move_toward(target, (ACCEL if target.length() > hv.length() else DECEL) * delta * maxf(speed, 1.0))
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	_prev_vy = velocity.y
	move_and_slide()
	_check_landing()

	# Facing: attack direction wins, otherwise movement direction.
	var face_dir := Vector3.ZERO
	if _attack_t >= 0.0:
		face_dir = _attack_dir
	elif hv.length() > 0.2:
		face_dir = hv
	if face_dir.length() > 0.01:
		yaw = lerp_angle(yaw, atan2(face_dir.x, face_dir.z), clampf(delta * TURN_SPEED, 0.0, 1.0))
	model.rotation.y = yaw

	if _attack_t >= 0.0:
		var prev := _attack_t
		_attack_t += delta / ATTACK_TIME
		if prev < 0.45 and _attack_t >= 0.45:
			V01Events.player_attacked.emit(global_position + Vector3.UP * 1.2, _attack_dir, 1.3)
			V01NoiseSystem.emit(global_position, 5.0, self)
		if _attack_t >= 1.0:
			_attack_t = -1.0
	stats.update(delta, hv.length() > 0.2, running and hv.length() > 0.5, false)


func _check_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var impact := -_prev_vy
		if impact > SAFE_FALL_SPEED:
			var dmg := pow(impact - SAFE_FALL_SPEED, 2.0) * 1.6
			health.take_damage(dmg, null)
			V01Sfx.play_at("thud", global_position, 0.0)
			V01NoiseSystem.emit(global_position, 8.0, self)
			if not health.is_dead():
				V01Events.show_toast("Неудачное падение!" if dmg < 40.0 else "Тяжёлое падение! Ноги не слушаются...")
	_was_on_floor = on_floor


func _start_attack() -> void:
	_attack_t = 0.0
	var mp := mouse_world_point()
	var d := mp - global_position
	d.y = 0
	_attack_dir = d.normalized() if d.length() > 0.2 else get_facing_vector()
	stats.spend_attack()
	V01Sfx.play_at("swing", global_position + Vector3.UP, -6.0)


## Mouse cursor projected onto the player's chest-height plane.
func mouse_world_point() -> Vector3:
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
	animator.attack_t = _attack_t
	match state:
		State.NORMAL:
			animator.pose = V01CharacterAnimator.Pose.CROUCH if crouching else V01CharacterAnimator.Pose.STAND
		State.SEATED:
			animator.pose = V01CharacterAnimator.Pose.LIE if _seat_lying else V01CharacterAnimator.Pose.SIT
		State.CLIMBING:
			animator.pose = V01CharacterAnimator.Pose.CLIMB
		State.DEAD:
			animator.pose = V01CharacterAnimator.Pose.DEAD


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
	V01Sfx.play_at(snd + "*", global_position, vol, 0.12)
	V01NoiseSystem.emit(global_position, radius, self)


# ---------------------------------------------------------------- furniture
func sit_on(seat: V01Furniture, at: Transform3D, lying: bool) -> void:
	if state != State.NORMAL:
		return
	_seat = seat
	_seat_lying = lying
	_stand_pos = global_position
	state = State.SEATED
	crouching = false
	velocity = Vector3.ZERO
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
		V01Events.show_toast("Вы легли отдохнуть. Нажмите E или клавишу движения, чтобы встать.")
	else:
		V01Events.show_toast("Вы присели. Выносливость восстанавливается быстрее.")


func stand_up() -> void:
	if state != State.SEATED:
		return
	model.rotation = Vector3(0, yaw, 0)
	model.position = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(self, "global_position", _stand_pos, 0.3)
	tw.tween_callback(func() -> void:
		collision_mask = 1 | 4
		state = State.NORMAL)
	_seat = null


# ---------------------------------------------------------------- windows
func climb_through_window(win: V01WindowObj) -> void:
	if state != State.NORMAL:
		return
	state = State.CLIMBING
	crouching = false
	velocity = Vector3.ZERO
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
		collision_mask = 1 | 4
		state = State.NORMAL
		_was_on_floor = false
		if win.is_hazardous():
			health.take_damage(randf_range(6.0, 14.0), win)
			V01Events.show_toast("Порезались об осколки стекла!"))
	V01Sfx.play_at("climb", sill, -6.0)
	V01NoiseSystem.emit(sill, 4.0, self)


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	model.rotation = Vector3(-PI * 0.5, yaw, 0)
	model.position = Vector3(0, 0.12, 0)
	died.emit()
