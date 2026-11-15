class_name V02Zombie
extends CharacterBody3D
## Shambling infected. State machine:
##   IDLE (wander, drifts toward other zombies) -> INVESTIGATE (noise) -> CHASE (sees player)
##   -> ATTACK; SEARCH after losing sight; BASH doors/windows in the way; STAGGER/DOWN/GETUP when hit.
## Senses: vision cone with line of sight (worse at night, vs crouching), hearing via NoiseSystem.

enum State { IDLE, INVESTIGATE, CHASE, ATTACK, SEARCH, BASH, STAGGER, DOWN, GETUP, CLIMB, DEAD }

const STATE_NAMES := ["IDLE", "INVESTIGATE", "CHASE", "ATTACK", "SEARCH", "BASH", "STAGGER", "DOWN", "GETUP", "CLIMB", "DEAD"]
const VARIANTS := ["zombie_a", "zombie_b", "zombie_c", "zombie_d", "zombie_e"]
const GRAVITY := 18.0
const MASK := 1 | 2 | 4 | 32
const SIGHT_MASK := 1 | 32
const SIGHT_DAY := 16.0
const SIGHT_NIGHT := 7.0
const FOV_DEG := 75.0
const ATTACK_RANGE := 1.05
const HIT_RANGE := 1.4
const LOSE_TIME := 5.0

signal died

@export var variant := "zombie_a"

var state := State.IDLE
var health: V02HealthComponent
var animator: V02CharacterAnimator
var agent: NavigationAgent3D
var model: Node3D
var player: V02Player
var walk_speed := 0.85
var chase_speed := 2.0
var yaw := 0.0
var target_pos := Vector3.ZERO
var last_seen := Vector3.ZERO
var bash_target: Node3D
var corpse: V02LootContainer

var _state_t := 0.0
var _think_t := 0.0
var _lost_t := 0.0
var _attack_cd := 0.0
var _attack_hit := false
var _groan_t := 0.0
var _stuck_t := 0.0
var _sidestep := Vector3.ZERO
var _sidestep_t := 0.0
var _knock := Vector3.ZERO
var _down_time := 3.0
var _neighbors: Array = []
var _neighbor_t := 0.0
var _vis_t := 0.0
var _path_t := 0.0
var _wander_wait := 0.0


static func spawn(parent: Node, pos: Vector3, rng: RandomNumberGenerator, kind := "") -> V02Zombie:
	var z := (load("res://versions/v02/scenes/zombies/zombie.tscn") as PackedScene).instantiate() as V02Zombie
	z.variant = kind if kind != "" else VARIANTS[rng.randi() % VARIANTS.size()]
	parent.add_child(z)
	z.global_position = pos
	z.yaw = rng.randf() * TAU
	z.walk_speed = rng.randf_range(0.7, 1.05) * V02Settings.zombie_speed
	z.chase_speed = (rng.randf_range(1.7, 2.3) if rng.randf() > 0.12 else 2.9) * V02Settings.zombie_speed
	z.health.max_health = rng.randf_range(55.0, 90.0)
	z.health.health = z.health.max_health
	z._groan_t = rng.randf_range(2.0, 12.0)
	return z


func _ready() -> void:
	add_to_group("zombies")
	collision_layer = 4
	collision_mask = MASK
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.4
	health = $Health
	animator = $Animator
	agent = $Agent
	model = (load("res://versions/v02/assets/characters/%s.glb" % variant) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	var s := randf_range(0.94, 1.06)
	model.scale = Vector3(s, s * randf_range(0.97, 1.03), s)
	add_child(model)
	V02Mats.convert_imported(model, false)
	animator.zombie = true
	animator.bind(model)
	animator.step.connect(_on_step)
	health.died.connect(_die)
	V02Events.noise_emitted.connect(_on_noise)
	_think_t = randf() * 0.3
	target_pos = global_position


func state_name() -> String:
	return STATE_NAMES[state]


func is_dead() -> bool:
	return state == State.DEAD


func is_down() -> bool:
	return state == State.DOWN or state == State.GETUP


func chest() -> Vector3:
	return global_position + Vector3(0, 0.6 if is_down() else 1.2, 0)


func _set_state(s: State) -> void:
	if state == State.DEAD:
		return
	state = s
	_state_t = 0.0
	_stuck_t = 0.0
	if s == State.ATTACK:
		_attack_hit = false


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as V02Player
	_state_t += delta
	_attack_cd -= delta
	_think_t -= delta
	var far := player != null and global_position.distance_squared_to(player.global_position) > 45.0 * 45.0
	if _think_t <= 0.0:
		_think_t = (0.9 if far else 0.2) + randf() * 0.1
		_think()
	_vis_t -= delta
	if _vis_t <= 0.0:
		_vis_t = 0.3
		_update_visibility(far)
	var want := Vector3.ZERO
	match state:
		State.IDLE:
			want = _steer_to(target_pos, walk_speed * 0.75, 0.6)
			if want == Vector3.ZERO:
				_wander_wait -= delta
		State.INVESTIGATE:
			want = _steer_to(target_pos, walk_speed * 1.15, 0.8)
			if want == Vector3.ZERO:
				_begin_search(target_pos)
		State.SEARCH:
			want = _steer_to(target_pos, walk_speed, 0.6)
			if _state_t > 9.0:
				_set_state(State.IDLE)
		State.CHASE:
			want = _steer_to(target_pos, chase_speed, 0.3)
			if player and _flat_dist(player.global_position) < ATTACK_RANGE and absf(player.global_position.y - global_position.y) < 1.2 \
					and _attack_cd <= 0.0 and player.state != V02Player.State.DEAD:
				_set_state(State.ATTACK)
		State.ATTACK:
			_face(player.global_position - global_position, delta * 8.0)
			if not _attack_hit and _state_t >= 0.55:
				_attack_hit = true
				_resolve_attack()
			if _state_t >= 1.05:
				_attack_cd = randf_range(0.2, 0.6)
				_set_state(State.CHASE)
		State.BASH:
			_bash(delta)
		State.STAGGER:
			if _state_t > 0.5:
				_set_state(State.CHASE if player and player.state != V02Player.State.DEAD else State.SEARCH)
		State.DOWN:
			if _state_t > _down_time:
				_set_state(State.GETUP)
		State.GETUP:
			if _state_t > 1.1:
				_set_state(State.CHASE if _can_see_player() else State.SEARCH)
		State.CLIMB:
			pass
	# Movement integration.
	if state != State.CLIMB:
		var hv := Vector3(velocity.x, 0, velocity.z)
		var target_v := want + _knock + _separation() * 0.8
		hv = hv.move_toward(target_v, delta * 6.0)
		velocity.x = hv.x
		velocity.z = hv.z
		_knock = _knock.move_toward(Vector3.ZERO, delta * 6.0)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = minf(velocity.y, 0.0)
		move_and_slide()
		if want.length() > 0.3:
			_face(want, delta * 5.0)
			if hv.length() < want.length() * 0.25:
				_stuck_t += delta
				if _stuck_t > 0.7:
					_handle_stuck(want)
			else:
				_stuck_t = maxf(_stuck_t - delta, 0.0)
	model.rotation.y = yaw
	_animate()
	_groan_t -= delta
	if _groan_t <= 0.0 and not far:
		_groan_t = randf_range(5.0, 14.0) if state == State.IDLE else randf_range(2.5, 6.0)
		V02Sfx.play_at("zombie_groan_*", global_position + Vector3.UP * 1.5, -10.0 if state == State.IDLE else -4.0, 0.15)


# ------------------------------------------------------------------------------------------------ senses
func _think() -> void:
	match state:
		State.IDLE, State.INVESTIGATE, State.SEARCH:
			if _can_see_player():
				_spot_player()
			elif state == State.IDLE and (_flat_dist(target_pos) < 0.7 and _wander_wait <= 0.0):
				_pick_wander()
		State.CHASE:
			if _can_see_player():
				last_seen = player.global_position
				_lost_t = 0.0
				target_pos = last_seen
			else:
				_lost_t += 0.2
				target_pos = last_seen
				if _lost_t > LOSE_TIME or (_flat_dist(last_seen) < 0.8 and _lost_t > 1.0):
					_begin_search(last_seen)


func _can_see_player() -> bool:
	if player == null or player.state == V02Player.State.DEAD:
		return false
	var to := player.global_position - global_position
	if absf(to.y) > 1.8:
		return false
	var dist := Vector2(to.x, to.z).length()
	var range_m := lerpf(SIGHT_DAY, SIGHT_NIGHT, V02DayNight.night)
	if player.crouching:
		range_m *= 0.55
	elif player.running:
		range_m *= 1.15
	if dist > range_m:
		return false
	if dist > 2.2:
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		if rad_to_deg(fwd.angle_to(Vector3(to.x, 0, to.z))) > FOV_DEG:
			return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.55, 0), player.global_position + Vector3(0, 1.2, 0), SIGHT_MASK)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _spot_player() -> void:
	var was_hunting := state == State.CHASE
	_set_state(State.CHASE)
	last_seen = player.global_position
	target_pos = last_seen
	_lost_t = 0.0
	if not was_hunting:
		V02Sfx.play_at("zombie_alert", global_position + Vector3.UP * 1.5, -2.0, 0.15)
		# Others nearby come to see what the fuss is about: groups form.
		V02NoiseSystem.emit(global_position, 8.0, self)


func _on_noise(pos: Vector3, radius: float, source: Node) -> void:
	if source == self or state in [State.CHASE, State.ATTACK, State.BASH, State.DOWN, State.GETUP, State.STAGGER, State.CLIMB, State.DEAD]:
		return
	var d := global_position.distance_to(pos)
	if absf(pos.y - global_position.y) > 2.2:
		radius *= 0.45
	if d > radius:
		return
	if source is V02Zombie:
		# A neighbour's howl: shuffle toward it after a moment of hesitation.
		_think_t = randf_range(0.2, 0.7)
	_set_state(State.INVESTIGATE)
	target_pos = pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))


func _begin_search(at: Vector3) -> void:
	_set_state(State.SEARCH)
	target_pos = at + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))


func _pick_wander() -> void:
	_wander_wait = randf_range(1.5, 6.0)
	var p := global_position + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
	_neighbor_t -= 1.0
	if _neighbor_t <= 0.0:
		_neighbor_t = 3.0
		_neighbors = get_tree().get_nodes_in_group("zombies").filter(func(z: Node) -> bool:
			return z != self and (z as Node3D).global_position.distance_squared_to(global_position) < 225.0)
	if not _neighbors.is_empty() and randf() < 0.6:
		var c := Vector3.ZERO
		for z in _neighbors:
			if is_instance_valid(z):
				c += (z as Node3D).global_position
		c /= _neighbors.size()
		p = p.lerp(c, 0.55)
	p.y = global_position.y
	target_pos = p


# ------------------------------------------------------------------------------------------------ movement
func _steer_to(p: Vector3, speed: float, arrive: float) -> Vector3:
	if _flat_dist(p) < arrive:
		return Vector3.ZERO
	if _sidestep_t > 0.0:
		_sidestep_t -= get_physics_process_delta_time()
		return _sidestep * speed
	var next := p
	if V02NavBaker.ready_for_navigation:
		_path_t -= get_physics_process_delta_time()
		if _path_t <= 0.0 or agent.target_position.distance_squared_to(p) > 1.0:
			_path_t = 0.35
			agent.target_position = p
		if not agent.is_navigation_finished():
			next = agent.get_next_path_position()
	var d := next - global_position
	d.y = 0
	if d.length() < 0.05:
		d = p - global_position
		d.y = 0
	return d.normalized() * speed


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for z in _neighbors:
		if not is_instance_valid(z) or (z as V02Zombie).is_dead():
			continue
		var d := global_position - (z as Node3D).global_position
		d.y = 0
		var l := d.length()
		if l > 0.01 and l < 0.75:
			push += d / l * (0.75 - l) * 2.0
	return push


func _face(dir: Vector3, k: float) -> void:
	if Vector2(dir.x, dir.z).length() > 0.01:
		yaw = lerp_angle(yaw, atan2(dir.x, dir.z), clampf(k, 0.0, 1.0))


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


## Blocked while walking: closed door or window ahead -> bash it; otherwise sidestep.
func _handle_stuck(want: Vector3) -> void:
	_stuck_t = 0.0
	var dir := want.normalized()
	var from := global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1.1, 1 | 32)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and state in [State.CHASE, State.INVESTIGATE, State.SEARCH]:
		var n: Node = hit["collider"]
		while n and not (n is V02Door) and not (n is V02WindowObj):
			n = n.get_parent()
		if n is V02Door and not (n as V02Door).broken and not (n as V02Door).is_open:
			bash_target = n
			_set_state(State.BASH)
			return
		if n is V02WindowObj and state == State.CHASE:
			bash_target = n
			_set_state(State.BASH)
			return
	_sidestep = dir.rotated(Vector3.UP, PI * 0.5 * (1.0 if randf() > 0.5 else -1.0))
	_sidestep_t = randf_range(0.5, 1.1)


func _bash(_delta: float) -> void:
	if not is_instance_valid(bash_target):
		_set_state(State.CHASE)
		return
	_face(bash_target.global_position - global_position, 0.2)
	if bash_target is V02Door:
		var d := bash_target as V02Door
		if d.broken or d.is_open:
			_set_state(State.CHASE if _can_see_player() else State.INVESTIGATE)
			return
		if _state_t > 1.25:
			_state_t = 0.0
			d.damage(randf_range(9.0, 15.0), self)
	elif bash_target is V02WindowObj:
		var w := bash_target as V02WindowObj
		if w.is_broken or w.is_open:
			_climb_window(w)
			return
		if _state_t > 1.25:
			_state_t = 0.0
			w.damage_glass(self)


func _climb_window(w: V02WindowObj) -> void:
	_set_state(State.CLIMB)
	collision_mask = 0
	var sill := w.get_sill_point()
	var target := w.get_climb_target(global_position)
	var tw := create_tween()
	tw.tween_property(self, "global_position", Vector3(sill.x, sill.y - 0.25, sill.z), 0.9)
	tw.tween_property(self, "global_position", Vector3(target.x, maxf(target.y - 0.5, sill.y - 1.0), target.z), 0.8)
	tw.tween_callback(func() -> void:
		collision_mask = MASK
		_set_state(State.CHASE))


# ------------------------------------------------------------------------------------------------ combat
func _resolve_attack() -> void:
	if player == null or player.state == V02Player.State.DEAD:
		return
	var to := player.global_position - global_position
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	if Vector2(to.x, to.z).length() > HIT_RANGE or absf(to.y) > 1.2 or rad_to_deg(fwd.angle_to(Vector3(to.x, 0, to.z))) > 70.0:
		V02Sfx.play_at("swing", global_position + Vector3.UP, -10.0)
		return
	var chance := 0.72
	if player.running:
		chance = 0.45
	if randf() > chance:
		V02Sfx.play_at("swing", global_position + Vector3.UP, -10.0)
		return
	var crowd := 0
	for z in _neighbors:
		if is_instance_valid(z) and (z as V02Zombie).state == State.ATTACK:
			crowd += 1
	var r := randf()
	var bite_chance := 0.14 + crowd * 0.1
	var wound := "bite" if r < bite_chance else ("laceration" if r < bite_chance + 0.27 else "scratch")
	V02Sfx.play_at("zombie_attack", global_position + Vector3.UP * 1.4, 0.0, 0.1)
	player.take_zombie_hit(self, randf_range(6.0, 11.0), wound)


## Returns true if this hit killed the zombie.
func take_hit(damage: float, dir: Vector3, knockback: float, knockdown_chance: float, attacker: Node3D) -> bool:
	if state == State.DEAD:
		return false
	health.take_damage(damage, attacker)
	V02BloodFX.splash(chest(), dir, clampf(damage / 25.0, 0.3, 1.2))
	if state == State.DEAD:
		return true
	if attacker is V02Player:
		last_seen = attacker.global_position
		target_pos = last_seen
	if is_down():
		_set_state(State.DOWN)
		_down_time = randf_range(1.5, 3.0)
		return false
	var kd := knockdown_chance + (0.15 if damage > 25.0 else 0.0)
	if randf() < kd:
		_set_state(State.DOWN)
		_down_time = randf_range(2.0, 4.0)
		_knock = dir.normalized() * knockback * 0.8
		V02Sfx.play_at("body_fall", global_position, -4.0)
	else:
		_set_state(State.STAGGER)
		_knock = dir.normalized() * knockback
	V02Sfx.play_at("zombie_hurt", global_position + Vector3.UP * 1.5, -6.0, 0.15)
	return false


func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	remove_from_group("zombies")
	add_to_group("corpses")
	animator.pose = V02CharacterAnimator.Pose.DEAD
	animator.attack_t = -1.0
	model.rotation = Vector3(-PI * 0.5, yaw, 0)
	model.position = Vector3(0, 0.12, 0)
	V02Sfx.play_at("zombie_die", global_position + Vector3.UP, -2.0)
	V02Sfx.play_at("body_fall", global_position, -2.0)
	V02BloodFX.pool(global_position)
	corpse = V02LootContainer.new()
	corpse.display_name = "Труп"
	corpse.container_type = "corpse"
	corpse.table_id = "zombie_militia" if variant == "zombie_e" else "zombie"
	corpse.focus_offset = Vector3(0, 0.3, 0)
	corpse.search_time = 1.8
	add_child(corpse)
	died.emit()
	V02Events.zombie_killed.emit(self)
	# Settle once on the ground, then stop simulating.
	await get_tree().create_timer(1.5).timeout
	set_physics_process(false)
	animator.set_process(false)


func _on_step(_foot: int) -> void:
	if state == State.CHASE and player and global_position.distance_squared_to(player.global_position) < 400.0:
		V02Sfx.play_at("step_concrete_*", global_position, -18.0, 0.2)


# ------------------------------------------------------------------------------------------------ presentation
func _animate() -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	animator.speed = hv.length()
	animator.running = state == State.CHASE and chase_speed > 2.5
	animator.attack_t = clampf(_state_t / 1.05, 0.0, 1.0) if state == State.ATTACK else (
		fmod(_state_t, 1.25) / 1.25 if state == State.BASH else -1.0)
	animator.attack_style = "grab" if state == State.ATTACK else "bash"
	match state:
		State.DOWN:
			animator.pose = V02CharacterAnimator.Pose.KNOCKED
		State.GETUP:
			animator.pose = V02CharacterAnimator.Pose.GETUP
		State.CLIMB:
			animator.pose = V02CharacterAnimator.Pose.CLIMB
		State.STAGGER:
			animator.pose = V02CharacterAnimator.Pose.STAGGER
		_:
			animator.pose = V02CharacterAnimator.Pose.STAND
	model.position.y = 0.0


## Zombies on floors that are hidden (player inside on a lower level) must not float in view.
func _update_visibility(far: bool) -> void:
	animator.set_process(not far)
	var vis := true
	for b in get_tree().get_nodes_in_group("buildings"):
		var bb := b as V02Building
		if bb.contains_point(global_position):
			var view := bb.get_view()
			vis = not (view >= 0 and bb.level_at(global_position) > view)
			break
	model.visible = vis
