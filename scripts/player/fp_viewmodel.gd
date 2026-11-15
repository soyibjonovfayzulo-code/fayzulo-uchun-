class_name FPViewmodel
extends Node3D
## First-person hands and the held item (v0.5). Everything is procedural: the weapon grip ("W") follows
## a target pose in camera space that blends carry, sprint, aim-down-sights, attacks and timed actions;
## the hands either hold W at fixed grip points or play their own pose (fists, flashlight, eating,
## bandaging, searching, reading, hammering, climbing, the steering wheel). Additive layers on top: walk
## bob, look sway, breathing, panic tremor, recoil kick, hit impact and the raise after switching items.
## The rig is drawn at 0.4 scale close to the lens so it never pokes into walls (same angular size).
## Camera space: -Z forward, +X right, +Y up. W's -Z points along the item (barrel, blade, bat).

const SCALE := 0.4
## Shoulders in camera space (unscaled): forearms always point back towards them (two-bone feel).
const SHOULDER_R := Vector3(0.21, -0.34, 0.16)
const SHOULDER_L := Vector3(-0.21, -0.34, 0.16)
const SKIN := Color("#c4977a")
const SKIN_SHADE := Color("#a87c62")

var player: Player
var cam: FPCamera
var hand_r: Node3D
var hand_l: Node3D
var grip: Node3D
var kind := "none"

var _fingers := {}
var _sleeves: Array[MeshInstance3D] = []
var _sleeve_mat: StandardMaterial3D
var _cuff_mat: StandardMaterial3D
var _skin_mat: StandardMaterial3D
var _model: Node3D
var _model_id := ""
var _muzzle: Node3D
var _flash: MeshInstance3D
var _flash_t := 0.0
var _torch: Node3D
var _torch_id := ""
var _torch_tip: Node3D
var _props := {}
var _w_pos := Vector3(0.2, -0.3, -0.45)
var _w_rot := Quaternion.IDENTITY
var _r := Transform3D.IDENTITY
var _l := Transform3D.IDENTITY
var _raise := 1.0
var _kick := 0.0
var _kick_vel := 0.0
var _sway := Vector2.ZERO
var _sway_vel := Vector2.ZERO
var _impact := Vector3.ZERO
var _impact_vel := Vector3.ZERO
var _t := 0.0
var _fired := false
var _clothing := "?"
var _work_t := 0.0


func bind(p: Player, c: FPCamera) -> void:
	player = p
	cam = c
	scale = Vector3.ONE * SCALE
	_skin_mat = _mat(SKIN, 0.8)
	_sleeve_mat = _mat(Color("#4b5240"), 0.95)
	_cuff_mat = _mat(Color("#3b4133"), 0.95)
	hand_r = _make_hand(1.0)
	hand_l = _make_hand(-1.0)
	grip = Node3D.new()
	grip.name = "Grip"
	add_child(grip)
	_flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_color = Color(1.0, 0.8, 0.45)
	fm.albedo_texture = PlayerCombat._flash_tex()
	fm.no_depth_test = true
	q.material = fm
	_flash.mesh = q
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	add_child(_flash)
	p.combat.attack_landed.connect(func(_t2: Node, _d: float, killed: bool) -> void:
		_impact_vel += Vector3(0, 0.6, 1.4) * (1.4 if killed else 1.0)
		cam.add_shake(0.18 if killed else 0.1))
	p.health.damaged.connect(func(amount: float, _src: Node) -> void:
		if amount >= 2.0:
			_impact_vel += Vector3(randf_range(-1, 1), -1.5, 1.5) * clampf(amount / 15.0, 0.4, 1.5))


## Items come up from below after switching (or getting up, entering a car...).
func raise() -> void:
	_raise = 1.0


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Wrist pivot: fingers point -Z, the forearm (sleeve) runs back along +Z, palm faces -Y.
func _make_hand(side: float) -> Node3D:
	var h := Node3D.new()
	h.name = "HandR" if side > 0.0 else "HandL"
	add_child(h)
	var sl := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.043
	cy.bottom_radius = 0.054
	cy.height = 0.56
	cy.radial_segments = 8
	cy.rings = 1
	sl.mesh = cy
	sl.material_override = _sleeve_mat
	sl.rotation.x = PI * 0.5
	sl.position = Vector3(0, 0.004, 0.31)
	sl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(sl)
	_sleeves.append(sl)
	var cuff := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.047
	cc.bottom_radius = 0.047
	cc.height = 0.035
	cc.radial_segments = 8
	cuff.mesh = cc
	cuff.material_override = _cuff_mat
	cuff.rotation.x = PI * 0.5
	cuff.position = Vector3(0, 0.004, 0.045)
	cuff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(cuff)
	_box(h, Vector3(0.05, 0.032, 0.04), Vector3(0, 0, 0.012), _skin_mat)
	_box(h, Vector3(0.074, 0.032, 0.075), Vector3(0, 0, -0.045), _skin_mat)
	var f := Node3D.new()
	f.name = "Fingers"
	f.position = Vector3(0, -0.002, -0.082)
	h.add_child(f)
	_box(f, Vector3(0.072, 0.026, 0.05), Vector3(0, 0, -0.024), _skin_mat)
	_box(f, Vector3(0.07, 0.008, 0.012), Vector3(0, 0.012, -0.006), _mat(SKIN_SHADE, 0.8))
	var th := _box(h, Vector3(0.02, 0.022, 0.05), Vector3(-side * 0.04, -0.008, -0.05), _skin_mat, Vector3(0.2, side * 0.55, 0))
	th.name = "Thumb"
	_fingers[h] = f
	return h


func _set_fist(h: Node3D, curl: float) -> void:
	var f := _fingers[h] as Node3D
	f.rotation.x = lerpf(f.rotation.x, -curl * 1.55, 0.35)


# ------------------------------------------------------------------------------------------------ items
func _refresh_items() -> void:
	var w := player.inventory.weapon()
	var id := w.item.id if w else ""
	if id != _model_id:
		_model_id = id
		if _model:
			_model.queue_free()
		_model = null
		_muzzle = null
		kind = _kind_of(w)
		if w and w.item.model_path != "":
			_model = _load_item(w.item, grip)
			_place_model(_model, w.item, kind)
		raise()
	var fl: ItemStack = player.inventory.equipped["offhand"]
	var tid := fl.item.id if fl and fl.item.light_range > 0.0 else ""
	if tid != _torch_id:
		_torch_id = tid
		if _torch:
			_torch.queue_free()
		_torch = null
		_torch_tip = null
		if tid != "" and fl.item.model_path != "":
			var holder := Node3D.new()
			holder.name = "TorchGrip"
			holder.position = Vector3(0, -0.005, -0.05)
			hand_l.add_child(holder)
			var m := _load_item(fl.item, holder)
			_place_model(m, fl.item, "torch")
			_torch = holder
			_torch_tip = Node3D.new()
			holder.add_child(_torch_tip)
			_torch_tip.position = Vector3(0, 0, -0.16)
	var body: ItemStack = player.inventory.equipped["body"]
	var cid := body.item.id if body else ""
	if cid != _clothing:
		_clothing = cid
		var cols: Array = Player.CLOTHING_COLORS.get(cid, Player.CLOTHING_COLORS[""])
		_sleeve_mat.albedo_color = cols[0]
		_cuff_mat.albedo_color = cols[1]


static func _kind_of(w: ItemStack) -> String:
	if w == null:
		return "none"
	var it := w.item
	if it.attack_style == "shoot":
		return "rifle" if it.weight >= 2.0 else "pistol"
	if it.attack_style == "stab":
		return "knife"
	if it.attack_style == "swing" and it.weight >= 0.9:
		return "melee2"
	return "melee1"


func _load_item(it: ItemData, parent: Node3D) -> Node3D:
	var ps := load(it.model_path) as PackedScene
	if ps == null:
		return null
	var m := ps.instantiate() as Node3D
	parent.add_child(m)
	Mats.convert_imported(m, false)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## Item models lie along +X with +Y up: map +X to the grip's -Z and put the hand point at the origin.
func _place_model(m: Node3D, _it: ItemData, k: String) -> void:
	if m == null:
		return
	m.basis = Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))
	if k == "torch":
		# The torch model has its lens at -X: point that end forward.
		m.basis = Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	var box := Props.local_aabb(m)
	var c := box.get_center()
	var g := Vector3(box.position.x + minf(0.08, box.size.x * 0.3), c.y, c.z)
	match k:
		"pistol":
			g = Vector3(box.position.x + box.size.x * 0.28, c.y - box.size.y * 0.1, c.z)
		"rifle":
			g = Vector3(box.position.x + box.size.x * 0.34, c.y - box.size.y * 0.1, c.z)
		"torch":
			g = Vector3(box.position.x + box.size.x * 0.62, c.y, c.z)
	m.position = -(m.basis * g)
	if k == "pistol" or k == "rifle":
		_muzzle = Node3D.new()
		_muzzle.name = "Muzzle"
		grip.add_child(_muzzle)
		_muzzle.position = m.position + m.basis * Vector3(box.end.x, c.y + box.size.y * 0.2, c.z)


# ------------------------------------------------------------------------------------------------ per frame
func tick(delta: float) -> void:
	if player == null:
		return
	_t += delta
	_refresh_items()
	var st := player.state
	var combat := player.combat
	var driving := st == Player.State.DRIVING
	scale = Vector3.ONE * (1.0 if driving else SCALE)
	_raise = maxf(_raise - delta * 2.6, 0.0)
	# --- target poses
	var w_pos := Vector3(0.2, -0.3, -0.45)
	var w_rot := Vector3.ZERO
	# Empty hands rest low at the edges of the view and come up for shoves and work.
	var r_free := Transform3D(Basis.from_euler(Vector3(0.55, -0.25, 0.35)), Vector3(0.25, -0.47, -0.36))
	var l_free := Transform3D(Basis.from_euler(Vector3(0.55, 0.25, -0.35)), Vector3(-0.25, -0.48, -0.37))
	var r_attached := kind != "none"
	var l_attached := kind == "melee2" or kind == "rifle" or (kind == "pistol" and _torch == null)
	var r_curl := 1.0
	var l_curl := 1.0
	var l_pump := 0.0
	match kind:
		"melee1":
			w_pos = Vector3(0.25, -0.21, -0.44)
			w_rot = Vector3(0.95, 0.2, -0.45)
		"melee2":
			w_pos = Vector3(0.21, -0.2, -0.42)
			w_rot = Vector3(1.0, 0.35, -0.75)
		"knife":
			w_pos = Vector3(0.2, -0.19, -0.42)
			w_rot = Vector3(0.25, 0.1, -0.35)
		"pistol":
			w_pos = Vector3(0.14, -0.17, -0.42)
			w_rot = Vector3(0.0, 0.06, 0.0)
		"rifle":
			w_pos = Vector3(0.13, -0.18, -0.34)
			w_rot = Vector3(0.0, 0.04, 0.0)
	if _torch:
		l_free = Transform3D(Basis.from_euler(Vector3(0.05, 0.12, 0.1)), Vector3(-0.2, -0.25, -0.45))
	elif kind == "melee1" or kind == "knife":
		l_free = Transform3D(Basis.from_euler(Vector3(0.5, 0.2, -0.3)), Vector3(-0.26, -0.46, -0.36))
		l_curl = 0.6
	var spd := Vector2(player.velocity.x, player.velocity.z).length()
	var sprint := st == Player.State.NORMAL and player.running and spd > 3.0 and not combat.is_attacking()
	if sprint:
		var s := 1.0
		if kind == "pistol" or kind == "rifle":
			w_pos += Vector3(-0.03, -0.06, 0.06) * s
			w_rot += Vector3(-0.55, 0.6, 0.25) * s
		elif kind != "none":
			w_pos += Vector3(0.0, -0.05, 0.05) * s
			w_rot += Vector3(-0.35, 0.3, -0.3) * s
		var pump := sin(cam._bob_t) * 0.06
		r_free.origin += Vector3(0, pump - 0.05, -pump * 0.5)
		l_free.origin += Vector3(0, -pump - 0.05, pump * 0.5)
	if cam.aiming:
		if kind == "pistol":
			w_pos = Vector3(0.0, -0.125, -0.42)
			w_rot = Vector3.ZERO
		elif kind == "rifle":
			w_pos = Vector3(0.0, -0.112, -0.3)
			w_rot = Vector3.ZERO
	if player.crouching:
		w_pos += Vector3(-0.01, 0.015, 0.02)
	# --- attacks
	var at := combat.attack_t
	var style := combat.attack_style
	if at >= 0.0:
		match style:
			"swing":
				var big := 1.35 if kind == "melee2" else 1.0
				var o := _keys(at, [[0.0, Vector3.ZERO, Vector3.ZERO],
					[0.3, Vector3(0.06, 0.08, 0.06) * big, Vector3(0.4, -0.4, -0.5)],
					[0.45, Vector3(-0.28, -0.08, -0.1) * big, Vector3(-0.6, 1.0, 0.9)],
					[0.62, Vector3(-0.36, -0.18, 0.0) * big, Vector3(-0.9, 1.3, 1.1)],
					[1.0, Vector3.ZERO, Vector3.ZERO]])
				w_pos += o[0]
				w_rot += o[1]
			"stab":
				var o := _keys(at, [[0.0, Vector3.ZERO, Vector3.ZERO],
					[0.3, Vector3(0.03, 0.03, 0.13), Vector3(0.2, -0.1, 0.0)],
					[0.45, Vector3(-0.09, 0.04, -0.26), Vector3(-0.05, 0.12, 0.0)],
					[0.7, Vector3(-0.04, 0.0, -0.1), Vector3.ZERO],
					[1.0, Vector3.ZERO, Vector3.ZERO]])
				w_pos += o[0]
				w_rot += o[1]
			"finish":
				var o := _keys(at, [[0.0, Vector3.ZERO, Vector3.ZERO],
					[0.35, Vector3(-0.1, 0.13, -0.06), Vector3(0.8, -0.2, 0.4)],
					[0.48, Vector3(-0.14, -0.12, -0.2), Vector3(-1.2, 0.1, 0.4)],
					[0.7, Vector3(-0.12, -0.16, -0.14), Vector3(-1.3, 0.1, 0.3)],
					[1.0, Vector3.ZERO, Vector3.ZERO]])
				w_pos += o[0]
				w_rot += o[1]
			"shove":
				var o := _keys(at, [[0.0, Vector3.ZERO, Vector3.ZERO], [0.25, Vector3(0, 0.02, 0.09), Vector3.ZERO],
					[0.42, Vector3(0, 0.08, -0.22), Vector3.ZERO], [0.65, Vector3(0, 0.05, -0.16), Vector3.ZERO],
					[1.0, Vector3.ZERO, Vector3.ZERO]])
				# Both palms come up and thrust forward.
				var env := smoothstep(0.05, 0.3, at) * (1.0 - smoothstep(0.65, 1.0, at))
				var thrust := smoothstep(0.25, 0.42, at) * (1.0 - smoothstep(0.55, 0.9, at))
				var palm := Basis.from_euler(Vector3(1.35, 0.0, 0.0))
				r_free = Transform3D(r_free.basis.slerp(palm * Basis(Vector3.FORWARD, 0.25), env),
					r_free.origin.lerp(Vector3(0.13, -0.22, -0.4 - 0.14 * thrust), env))
				l_free = Transform3D(l_free.basis.slerp(palm * Basis(Vector3.FORWARD, -0.25), env),
					l_free.origin.lerp(Vector3(-0.13, -0.22, -0.4 - 0.14 * thrust), env))
				r_curl = 1.0 - smoothstep(0.1, 0.35, at) * (1.0 - smoothstep(0.7, 1.0, at))
				l_curl = r_curl
				w_pos += o[0]
			"stomp":
				var e := sin(clampf(at, 0.0, 1.0) * PI)
				r_free.origin += Vector3(0.12, 0.06, 0.05) * e
				l_free.origin += Vector3(-0.12, 0.06, 0.05) * e
				w_pos += Vector3(0.05, 0.05, 0.05) * e
				if at > 0.45 and not _fired:
					cam.add_shake(0.12)
			"shoot":
				if at >= PlayerCombat.SHOT_FRAME and not _fired:
					_fired = true
					_kick_vel += 9.0 if kind == "rifle" else 6.0
					cam.add_recoil(0.06 if kind == "rifle" else 0.032, randf_range(-0.012, 0.012))
					cam.add_shake(0.3 if kind == "rifle" else 0.15)
					_flash_t = 0.06
					if _flash:
						_flash.rotation.z = randf() * TAU
				if kind == "rifle":
					# Pump: the left hand racks the fore-end.
					l_pump = smoothstep(0.35, 0.55, at) * (1.0 - smoothstep(0.62, 0.85, at))
					w_rot += Vector3(0.0, 0.0, 0.2) * l_pump
		if style != "shoot" and at >= 0.45:
			_fired = true
	else:
		_fired = false
	# --- timed actions, climbing, sitting, driving, death
	var hide_w := false
	match st:
		Player.State.NORMAL:
			if not player.action_label().is_empty():
				_work_t += delta
				var wk := _work_kind()
				if wk == "reload" and (kind == "pistol" or kind == "rifle"):
					var ph := sin(_work_t * 4.0)
					w_pos += Vector3(-0.04, -0.05, 0.04)
					w_rot += Vector3(-0.3, 0.2, 0.7)
					l_attached = false
					l_free = Transform3D(Basis.from_euler(Vector3(0.6, 0.3, -0.4)), Vector3(0.06, -0.32 - 0.05 * ph, -0.42))
				else:
					hide_w = true
					var hands: Array = _work_pose(wk, _work_t)
					r_free = hands[0]
					l_free = hands[1]
					r_curl = hands[2]
					l_curl = hands[3]
					r_attached = false
					l_attached = false
			else:
				_work_t = 0.0
		Player.State.CLIMBING:
			hide_w = true
			r_attached = false
			l_attached = false
			var pal := Basis.from_euler(Vector3(-0.2, 0, 0))
			r_free = Transform3D(pal, Vector3(0.22, -0.3, -0.5))
			l_free = Transform3D(pal, Vector3(-0.22, -0.3, -0.5))
			r_curl = 0.15
			l_curl = 0.15
		Player.State.SEATED, Player.State.DEAD:
			hide_w = true
			r_attached = false
			l_attached = false
			r_free.origin += Vector3(0.05, -0.75, 0.2)
			l_free.origin += Vector3(-0.05, -0.75, 0.2)
		Player.State.DRIVING:
			hide_w = true
			r_attached = false
			l_attached = false
			var gp: Array = player.vehicle.wheel_grips() if player.vehicle and is_instance_valid(player.vehicle) else []
			if gp.size() == 2:
				r_free = _drive_hand(gp[0], 1.0)
				l_free = _drive_hand(gp[1], -1.0)
			r_curl = 1.0
			l_curl = 1.0
	if hide_w:
		w_pos += Vector3(0.05, -0.6, 0.25)
	# --- smoothing
	var fast := at >= 0.0 and style != "shoot"
	var k := 1.0 - exp(-delta * (34.0 if fast else 16.0))
	_w_pos = _w_pos.lerp(w_pos, k)
	_w_rot = _w_rot.slerp(Quaternion(Basis.from_euler(w_rot)), k)
	# --- additive layers
	var add := Vector3.ZERO
	var add_rot := Vector3.ZERO
	var bob_a: float = cam._bob_amp * (0.35 if cam.aiming else 1.0)
	add += Vector3(sin(cam._bob_t) * 0.014, -absf(cos(cam._bob_t)) * 0.016, 0) * bob_a * (1.7 if sprint else 1.0)
	add_rot += Vector3(0, 0, sin(cam._bob_t) * 0.04) * bob_a
	var breath := 1.0 + (1.0 - player.stats.endurance) * 2.5
	add += Vector3(0, sin(_t * 1.7) * 0.004 * breath, 0)
	var panic := player.stats.panic
	if panic > 0.3:
		add += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.003 * panic
	var s_steps := clampi(ceili(delta / 0.010), 1, 8)
	var s_dt := delta / float(s_steps)
	var sway_in := cam.look_delta * -2.2 / maxf(delta, 0.005) * 0.016
	for _i in s_steps:
		_sway_vel += (sway_in - _sway * 120.0 - _sway_vel * 18.0) * s_dt
		_sway += _sway_vel * s_dt
		_kick_vel += (-_kick * 260.0 - _kick_vel * 24.0) * s_dt
		_kick += _kick_vel * s_dt
		_impact_vel += (-_impact * 200.0 - _impact_vel * 20.0) * s_dt
		_impact += _impact_vel * s_dt
	if not _sway.is_finite():
		_sway = Vector2.ZERO
		_sway_vel = Vector2.ZERO
	_sway = _sway.limit_length(0.12)
	if not is_finite(_kick) or absf(_kick) > 2.0:
		_kick = 0.0
		_kick_vel = 0.0
	if not _impact.is_finite() or _impact.length_squared() > 4.0:
		_impact = Vector3.ZERO
		_impact_vel = Vector3.ZERO
	add += Vector3(_sway.x * 0.5, _sway.y * 0.5, 0)
	add_rot += Vector3(_sway.y * 1.2, _sway.x * 1.6, _sway.x * 0.8)
	add += Vector3(0, 0.01, 0.06) * _kick
	add_rot += Vector3(0.28, 0, 0) * _kick
	add += _impact * 0.03
	add_rot += Vector3(_impact.y * 0.2, _impact.x * 0.2, 0)
	var rs := _raise * _raise
	add += Vector3(0.02, -0.32, 0.08) * rs
	add_rot += Vector3(-0.6, 0.2, 0.3) * rs
	var wt := Transform3D(Basis(_w_rot) * Basis.from_euler(add_rot), _w_pos + add)
	grip.transform = wt
	grip.visible = not hide_w or _w_pos.y > -0.7
	# --- hands
	var ra := _attach_r(kind)
	var la := _attach_l(kind).translated_local(Vector3(0, 0, 0.11 * l_pump))
	var r_t := (wt * ra) if r_attached else Transform3D(r_free.basis * Basis.from_euler(add_rot * 0.5), r_free.origin + add)
	var l_t := (wt * la) if l_attached else Transform3D(l_free.basis * Basis.from_euler(add_rot * 0.5), l_free.origin + add * 0.8)
	if not driving:
		r_t = _to_shoulder(r_t, SHOULDER_R)
		l_t = _to_shoulder(l_t, SHOULDER_L)
	var hk := 1.0 - exp(-delta * (40.0 if fast or driving else 20.0))
	_r = _r.interpolate_with(r_t, hk) if _r.origin.distance_to(r_t.origin) < 1.5 else r_t
	_l = _l.interpolate_with(l_t, hk) if _l.origin.distance_to(l_t.origin) < 1.5 else l_t
	hand_r.transform = _r
	hand_l.transform = _l
	_set_fist(hand_r, r_curl if not r_attached else 1.0)
	_set_fist(hand_l, l_curl if not l_attached else 0.85)
	if _torch:
		_torch.visible = not l_attached and not hide_w
	# --- muzzle flash
	_flash_t -= delta
	_flash.visible = _flash_t > 0.0 and _muzzle != null
	if _flash.visible:
		_flash.global_position = _muzzle.global_position


## Keeps the hand where it is but turns it so the forearm runs back to the shoulder; the pose's own
## up axis decides the roll of the wrist.
func _to_shoulder(h: Transform3D, shoulder: Vector3) -> Transform3D:
	var dir := h.origin - shoulder
	if dir.length() < 0.05:
		return h
	dir = dir.normalized()
	var up := h.basis.y.normalized()
	if absf(up.dot(dir)) > 0.95:
		up = h.basis.x.cross(dir).normalized()
	return Transform3D(Basis.looking_at(dir, up), h.origin)


func _keys(t: float, keys: Array) -> Array:
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t >= a[0] and t <= b[0]:
			var u := smoothstep(0.0, 1.0, (t - a[0]) / maxf(b[0] - a[0], 0.001))
			return [(a[1] as Vector3).lerp(b[1], u), (a[2] as Vector3).lerp(b[2], u)]
	return [Vector3.ZERO, Vector3.ZERO]


## Right hand around the grip: forearm down the handle (melee) or behind the grip (guns).
func _attach_r(k: String) -> Transform3D:
	match k:
		"pistol":
			return Transform3D(Basis.from_euler(Vector3(-0.3, 0.0, 0.0)), Vector3(0.0, -0.045, 0.03))
		"rifle":
			return Transform3D(Basis.from_euler(Vector3(-0.35, 0.05, 0.0)), Vector3(0.0, -0.05, 0.07))
		"melee1", "melee2":
			return Transform3D(Basis.from_euler(Vector3(-PI * 0.5 + 0.3, 0.0, 0.0)), Vector3(0.0, 0.0, -0.02))
		"knife":
			return Transform3D(Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5)), Vector3(0.0, -0.01, 0.04))
	return Transform3D.IDENTITY


## Left hand: lower on the handle (two-handed), under the fore-end (shotgun), cupping the pistol.
func _attach_l(k: String) -> Transform3D:
	match k:
		"pistol":
			return Transform3D(Basis.from_euler(Vector3(-0.25, -0.6, -0.3)), Vector3(-0.035, -0.06, 0.02))
		"rifle":
			return Transform3D(Basis.from_euler(Vector3(-0.3, -0.55, -0.45)), Vector3(-0.01, -0.045, -0.3))
		"melee2":
			return Transform3D(Basis.from_euler(Vector3(-PI * 0.5 + 0.3, PI, 0.0)), Vector3(0.0, 0.0, 0.07))
	return Transform3D.IDENTITY


func _work_kind() -> String:
	var l := player.action_label().to_lower()
	if l.contains("перезаряж"):
		return "reload"
	return player.animator.work_kind


## [right, left, right curl, left curl] for a timed action.
func _work_pose(wk: String, t: float) -> Array:
	# The lower edge of a 90 degree view is ~0.5 m down per metre ahead: keep the hands above it.
	var down := Basis.from_euler(Vector3(-0.3, 0, 0))
	var r := Transform3D(down, Vector3(0.14, -0.22, -0.48))
	var l := Transform3D(down, Vector3(-0.14, -0.22, -0.48))
	var rc := 0.5
	var lc := 0.5
	_show_prop(wk)
	match wk:
		"eat", "drink":
			var cyc := 0.5 - 0.5 * cos(t * TAU / 1.3)
			var mouth := Vector3(0.03, -0.1, -0.27)
			var rest := Vector3(0.13, -0.22, -0.44)
			var tilt := Basis.from_euler(Vector3(0.2 + (0.9 if wk == "drink" else 0.3) * cyc, -0.4, 0.0))
			r = Transform3D(tilt, rest.lerp(mouth, cyc))
			l = Transform3D(Basis.from_euler(Vector3(0.4, 0.3, -0.3)), Vector3(-0.22, -0.3, -0.4))
			rc = 0.9
		"bandage":
			l = Transform3D(Basis.from_euler(Vector3(0.1, -1.25, 0.0)), Vector3(-0.04, -0.2, -0.44))
			r = Transform3D(Basis.from_euler(Vector3(0.2, 0.3, 0.0)), Vector3(0.05 + cos(t * 7.0) * 0.05, -0.18 + sin(t * 7.0) * 0.035, -0.42))
			rc = 0.7
			lc = 0.2
		"hammer":
			var hit := absf(sin(t * 7.5))
			r = Transform3D(Basis.from_euler(Vector3(-0.2 + hit * 0.6, -0.3, 0.0)), Vector3(0.1, -0.24 + hit * 0.1, -0.52))
			l = Transform3D(Basis.from_euler(Vector3(-0.4, 0.2, 0.0)), Vector3(-0.12, -0.33, -0.55))
			rc = 1.0
			lc = 0.1
		"cook":
			r = Transform3D(down, Vector3(0.06 + cos(t * 4.0) * 0.05, -0.24, -0.55 + sin(t * 4.0) * 0.05))
			l = Transform3D(down, Vector3(-0.16, -0.26, -0.5))
			rc = 0.9
		"read":
			var face := Basis.from_euler(Vector3(1.2, 0, 0))
			r = Transform3D(face * Basis(Vector3.UP, 0.4), Vector3(0.17, -0.22, -0.38))
			l = Transform3D(face * Basis(Vector3.UP, -0.4), Vector3(-0.17, -0.22, -0.38))
			rc = 0.6
			lc = 0.6
		_:
			# Searching: both hands rummage.
			r.origin += Vector3(sin(t * 5.3) * 0.04, sin(t * 7.1) * 0.05, cos(t * 5.3) * 0.06)
			l.origin += Vector3(sin(t * 4.7 + 1.0) * 0.04, sin(t * 6.3 + 2.0) * 0.05, cos(t * 4.7 + 1.0) * 0.06)
			rc = 0.3 + 0.3 * sin(t * 6.0)
			lc = 0.3 + 0.3 * cos(t * 6.0)
	return [r, l, rc, lc]


## Hand on the steering wheel rim (world point) with the forearm towards the shoulder.
func _drive_hand(world: Vector3, side: float) -> Transform3D:
	var local := (get_parent() as Node3D).global_transform.affine_inverse() * world
	local /= scale.x
	var shoulder := Vector3(side * 0.22, -0.38, 0.12)
	var dir := (local - shoulder).normalized()
	var b := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.FORWARD, side * 0.9)
	return Transform3D(b, local)


## Bottle, tin, bandage roll, hammer or newspaper in the hands during timed actions.
func _show_prop(wk: String) -> void:
	for k in _props:
		(_props[k] as Node3D).visible = k == wk
	if _props.has(wk) or not wk in ["eat", "drink", "bandage", "hammer", "read"]:
		return
	var n := Node3D.new()
	n.name = "Prop_" + wk
	match wk:
		"drink":
			hand_r.add_child(n)
			var mi := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.018
			cy.bottom_radius = 0.032
			cy.height = 0.2
			mi.mesh = cy
			var gm := _mat(Color(0.55, 0.75, 0.6, 0.75), 0.1)
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.material_override = gm
			mi.position = Vector3(0, -0.02, -0.06)
			mi.rotation.x = -0.4
			n.add_child(mi)
		"eat":
			hand_r.add_child(n)
			var mi := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.035
			cy.bottom_radius = 0.035
			cy.height = 0.07
			mi.mesh = cy
			mi.material_override = _mat(Color("#a0a4a8"), 0.35)
			mi.position = Vector3(0, -0.04, -0.05)
			n.add_child(mi)
			_box(n, Vector3(0.072, 0.045, 0.072), Vector3(0, -0.04, -0.05), _mat(Color("#b8402e"), 0.8))
		"bandage":
			hand_l.add_child(n)
			_box(n, Vector3(0.1, 0.06, 0.07), Vector3(0, 0.005, 0.07), _mat(Color("#eeeae0"), 0.9))
		"hammer":
			hand_r.add_child(n)
			_box(n, Vector3(0.022, 0.022, 0.3), Vector3(0, -0.01, -0.04), _mat(Color("#7a5532"), 0.8), Vector3(PI * 0.5, 0, 0))
			_box(n, Vector3(0.11, 0.035, 0.035), Vector3(0, -0.16, -0.04), _mat(Color("#55575a"), 0.4))
		"read":
			hand_l.add_child(n)
			var mi := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.36, 0.26)
			mi.mesh = qm
			mi.material_override = _mat(Color("#d8d2c0"), 0.95)
			mi.position = Vector3(0.17, 0.02, -0.05)
			mi.rotation = Vector3(-PI * 0.5, 0, 0)
			n.add_child(mi)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_props[wk] = n


## Where the first-person flashlight shines from (world space).
func flashlight_anchor() -> Vector3:
	if _torch_tip and _torch and _torch.visible:
		return _torch_tip.global_position
	var c := get_parent() as Node3D
	return c.global_transform * Vector3(-0.14, -0.1, -0.12)


## World position of the gun muzzle (tracers and the flash light start here).
func muzzle_world() -> Vector3:
	if _muzzle:
		return _muzzle.global_position
	var c := get_parent() as Node3D
	return c.global_transform * Vector3(0.06, -0.08, -0.4)
