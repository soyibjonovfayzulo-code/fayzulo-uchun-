class_name V04PlayerCombat
extends Node
## Melee and firearm attacks for the player. Weapon stats come from the equipped ItemData;
## empty hands shove (pushes, rarely knocks down). A downed zombie in front gets stomped / finished off.
## The hit lands at ~45% of the swing; tired survivors swing slower and miss more.

signal attack_landed(target: Node, damage: float, killed: bool)
signal attack_missed

const HIT_FRAME := 0.45
const SHOT_FRAME := 0.12

@export var player_path: NodePath

var player: V04Player
var attack_t := -1.0
var attack_style := ""
var attack_dir := Vector3.FORWARD
var last_result := ""
var _duration := 0.6
var _data: V04ItemData
var _stack: V04ItemStack
var _hit_done := false
var _finisher: V04Zombie

static var unarmed: V04ItemData
static var stomp: V04ItemData


func _ready() -> void:
	player = get_node(player_path) as V04Player
	if unarmed == null:
		unarmed = V04ItemData.new()
		unarmed.display_name = "Толчок"
		unarmed.attack_style = "shove"
		unarmed.damage = 2.0
		unarmed.swing_time = 0.5
		unarmed.reach = 1.15
		unarmed.arc_deg = 90.0
		unarmed.hit_chance = 0.95
		unarmed.knockback = 2.8
		unarmed.knockdown_chance = 0.25
		unarmed.endurance_cost = 0.03
		unarmed.noise_radius = 3.0
		unarmed.max_targets = 2
		stomp = V04ItemData.new()
		stomp.display_name = "Добить ногой"
		stomp.attack_style = "stomp"
		stomp.damage = 14.0
		stomp.swing_time = 0.75
		stomp.reach = 1.1
		stomp.arc_deg = 80.0
		stomp.hit_chance = 1.0
		stomp.endurance_cost = 0.04
		stomp.noise_radius = 4.0


func is_attacking() -> bool:
	return attack_t >= 0.0


func try_attack(at_point: Vector3) -> void:
	if is_attacking() or player.state != V04Player.State.NORMAL:
		return
	var d := at_point - player.global_position
	d.y = 0
	attack_dir = d.normalized() if d.length() > 0.2 else player.get_facing_vector()
	_stack = player.inventory.weapon()
	_data = _stack.item if _stack else unarmed
	_finisher = null
	if _data.attack_style != "shoot":
		_finisher = _find_downed()
		if _finisher:
			if _stack == null:
				_data = stomp
			var to := _finisher.global_position - player.global_position
			to.y = 0
			attack_dir = to.normalized()
	if _data.attack_style == "shoot":
		if _stack.loaded <= 0:
			V04Sfx.play_at("gun_empty", player.global_position + Vector3.UP, -4.0)
			V04Events.show_toast("Магазин пуст. R — перезарядить.")
			return
	attack_style = "finish" if _finisher and _stack else _data.attack_style
	_duration = _data.swing_time / clampf(player.stats.combat_factor(), 0.55, 1.0)
	attack_t = 0.0
	_hit_done = false
	player.stats.spend_attack(_data.endurance_cost)
	player.face_towards(attack_dir)
	if _data.attack_style != "shoot":
		V04Sfx.play_at("swing", player.global_position + Vector3.UP, -6.0 if _stack else -10.0)


func _physics_process(delta: float) -> void:
	if attack_t < 0.0:
		return
	attack_t += delta / _duration
	var frame := SHOT_FRAME if _data.attack_style == "shoot" else HIT_FRAME
	if not _hit_done and attack_t >= frame:
		_hit_done = true
		if _data.attack_style == "shoot":
			_fire()
		else:
			_melee()
	if attack_t >= 1.0:
		attack_t = -1.0
		attack_style = ""


func _find_downed() -> V04Zombie:
	var best: V04Zombie = null
	var best_d := INF
	for z in player.get_tree().get_nodes_in_group("zombies"):
		var zz := z as V04Zombie
		if not zz.is_down():
			continue
		var to := zz.global_position - player.global_position
		var dist := Vector2(to.x, to.z).length()
		if dist < 1.25 and absf(to.y) < 0.8 and attack_dir.angle_to(Vector3(to.x, 0, to.z)) < deg_to_rad(80.0) and dist < best_d:
			best = zz
			best_d = dist
	return best


func _targets(reach: float, arc: float) -> Array:
	var out: Array = []
	var origin := player.global_position
	for z in player.get_tree().get_nodes_in_group("zombies"):
		var zz := z as V04Zombie
		var to := zz.global_position - origin
		var dist := Vector2(to.x, to.z).length()
		if dist > reach + 0.35 or absf(to.y) > 1.2:
			continue
		if dist > 0.55 and rad_to_deg(attack_dir.angle_to(Vector3(to.x, 0, to.z))) > arc * 0.5:
			continue
		if not _clear_line(origin + Vector3.UP * 1.1, zz.chest()):
			continue
		out.append([dist, zz])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return out.map(func(e: Array) -> V04Zombie: return e[1])


func _clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | 32)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _melee() -> void:
	var cf := player.stats.combat_factor()
	V04NoiseSystem.emit(player.global_position, _data.noise_radius, player)
	var targets: Array = [_finisher] if _finisher and is_instance_valid(_finisher) and not _finisher.is_dead() else _targets(_data.reach, _data.arc_deg)
	if targets.is_empty():
		_hit_world()
		last_result = "miss"
		attack_missed.emit()
		return
	var landed := 0
	for z in targets.slice(0, _data.max_targets):
		var zz := z as V04Zombie
		var chance := _data.hit_chance * lerpf(0.75, 1.0, cf) * (1.2 if zz.is_down() or zz.state == V04Zombie.State.STAGGER else 1.0) \
			* V04Skills.melee_accuracy(player)
		if randf() > chance:
			continue
		var dmg := _data.damage * randf_range(0.85, 1.15) * lerpf(0.7, 1.0, cf) * V04Skills.melee_damage(player)
		var crit := randf() < _data.crit_chance
		if crit:
			dmg *= 2.0
		if zz.is_down():
			dmg *= 1.8 if _stack else 1.0
		var killed := zz.take_hit(dmg, attack_dir, _data.knockback, _data.knockdown_chance, player)
		landed += 1
		V04Skills.add_xp(player, "melee", 3.0 + (4.0 if killed else 0.0))
		attack_landed.emit(zz, dmg, killed)
		V04Sfx.play_at("hit_sharp" if _data.attack_style == "stab" else "hit_blunt", zz.chest(), 0.0, 0.1)
	if landed == 0:
		last_result = "miss"
		V04Events.show_toast("Промах!")
		attack_missed.emit()
		return
	last_result = "hit"
	_feedback(0.06 if _stack else 0.03, 0.12 if _stack else 0.05)
	_wear(1.0)


## Swing that met no zombie: doors, windows and cars take the blow.
func _hit_world() -> void:
	var from := player.global_position + Vector3.UP * 1.1
	var q := PhysicsRayQueryParameters3D.create(from, from + attack_dir * (_data.reach + 0.3), 1 | 32)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var n: Node = hit["collider"]
	while n and not (n is V04Door) and not (n is V04WindowObj) and not (n is V04LootContainer):
		n = n.get_parent()
	if n is V04Door:
		(n as V04Door).damage(_data.damage * _data.door_damage_mult * (1.0 if _stack else 0.2), player)
		_feedback(0.04, 0.08)
		_wear(0.5)
	elif n is V04WindowObj and not (n as V04WindowObj).is_broken:
		(n as V04WindowObj).perform("smash", player)
	elif n is V04LootContainer and n.has_node("CarAlarm"):
		V04Sfx.play_at("hit_blunt", hit["position"], -2.0)
		(n.get_node("CarAlarm") as V04CarAlarm).trigger()


func _fire() -> void:
	_stack.loaded -= 1
	player.inventory.main.changed.emit()
	V04Sfx.play_at("gunshot", player.global_position + Vector3.UP * 1.3, 4.0, 0.05)
	V04NoiseSystem.emit(player.global_position, _data.noise_radius, player)
	var muzzle := player.global_position + Vector3.UP * 1.3 + attack_dir * 0.6
	var best: V04Zombie = null
	var best_score := INF
	for z in player.get_tree().get_nodes_in_group("zombies"):
		var zz := z as V04Zombie
		var to := zz.chest() - muzzle
		var dist := to.length()
		if dist > _data.fire_range:
			continue
		var ang := rad_to_deg(attack_dir.angle_to(Vector3(to.x, 0, to.z)))
		if ang > 9.0 or not _clear_line(muzzle, zz.chest()):
			continue
		var score := ang * 0.5 + dist * 0.1
		if score < best_score:
			best = zz
			best_score = score
	var end := muzzle + attack_dir * _data.fire_range
	if best:
		var dist := best.chest().distance_to(muzzle)
		var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.5
		var chance := lerpf(0.95, 0.45, dist / _data.fire_range) * (0.8 if moving else 1.0) * player.stats.combat_factor() \
			* V04Skills.firearm_accuracy(player)
		if randf() < chance:
			var dmg := _data.damage * randf_range(0.9, 1.1)
			if randf() < _data.crit_chance:
				dmg = 999.0
			var killed := best.take_hit(dmg, attack_dir, _data.knockback, _data.knockdown_chance, player)
			V04Skills.add_xp(player, "firearm", 5.0)
			attack_landed.emit(best, dmg, killed)
			end = best.chest()
			last_result = "hit"
		else:
			last_result = "miss"
			end = best.chest() + Vector3(randf_range(-1, 1), randf_range(0.3, 1.0), randf_range(-1, 1))
	else:
		var q := PhysicsRayQueryParameters3D.create(muzzle, end, 1 | 32)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			end = hit["position"]
		last_result = "miss"
	_tracer(muzzle, end)
	_feedback(0.0, 0.22)
	_wear(1.0)


func _tracer(a: Vector3, b: Vector3) -> void:
	var root := player.get_parent() as Node3D
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, a.distance_to(b))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.5)
	bm.material = m
	mi.mesh = bm
	root.add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP)
	var flash := OmniLight3D.new()
	flash.light_color = Color("#ffc870")
	flash.light_energy = 6.0
	flash.omni_range = 7.0
	root.add_child(flash)
	flash.global_position = a
	# Star-shaped flash at the muzzle and a curl of powder smoke.
	var star := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(0.55, 0.55)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.albedo_color = Color(1.0, 0.78, 0.4)
	sm.albedo_texture = _flash_tex()
	sq.material = sm
	star.mesh = sq
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(star)
	star.global_position = a + (b - a).normalized() * 0.15
	star.rotation.z = randf() * TAU
	V04Smoke.puff(root, a + (b - a).normalized() * 0.2, (b - a).normalized() * 0.4 + Vector3.UP * 0.3, 6)
	var tw := root.create_tween()
	tw.tween_interval(0.05)
	tw.tween_callback(mi.queue_free)
	tw.tween_callback(flash.queue_free)
	tw.tween_callback(star.queue_free)


static var _flash: ImageTexture


static func _flash_tex() -> ImageTexture:
	if _flash == null:
		var n := 32
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
				var ang := atan2(d.y, d.x)
				var rays := pow(absf(cos(ang * 2.5)), 6.0) * 0.8 + 0.25
				var a := clampf(1.0 - d.length() / rays, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_flash = ImageTexture.create_from_image(img)
	return _flash


## Hit-stop + camera shake give blows their weight.
func _feedback(hitstop: float, shake: float) -> void:
	var rig := player.camera.get_parent() if player.camera else null
	if rig and rig.has_method("add_shake"):
		rig.add_shake(shake)
	if hitstop > 0.0:
		Engine.time_scale = 0.08
		await player.get_tree().create_timer(hitstop, true, false, true).timeout
		Engine.time_scale = 1.0


func _wear(mult: float) -> void:
	if _stack == null or _stack.item.max_durability <= 0.0:
		return
	_stack.durability -= _stack.item.durability_loss * mult
	if _stack.durability <= 0.0:
		V04Events.show_toast("%s сломался!" % _stack.get_name())
		V04Sfx.play_at("weapon_break", player.global_position + Vector3.UP, 0.0)
		player.inventory.main.remove(_stack)
		_stack = null
	else:
		player.inventory.main.changed.emit()


func reload() -> void:
	var w := player.inventory.weapon()
	if w == null or w.item.magazine <= 0:
		return
	var need := w.item.magazine - w.loaded
	if need <= 0:
		V04Events.show_toast("Магазин полон.")
		return
	var ammo := player.inventory.main.find_by_id(w.item.ammo_id)
	if ammo == null:
		V04Events.show_toast("Нет патронов.")
		return
	player.start_timed_action("Перезаряжаем...", 1.6, func() -> void:
		var a := player.inventory.main.find_by_id(w.item.ammo_id)
		if a == null:
			return
		var n := mini(need, a.count)
		player.inventory.main.take(a, n)
		w.loaded += n
		player.inventory.main.changed.emit()
		V04Sfx.play_at("gun_reload", player.global_position + Vector3.UP, -4.0))


func unload(w: V04ItemStack) -> void:
	if w.loaded <= 0:
		return
	player.inventory.give(w.item.ammo_id, w.loaded)
	w.loaded = 0
	player.inventory.main.changed.emit()
