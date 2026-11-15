class_name Sleep
extends Node
## Sleeping: the game clock runs SPEED times faster while drowsiness drains (a bed is better than a sofa,
## a sofa better than the floor). Zombies nearby, loud noises and pain wake you up.

signal changed(sleeping: bool)

const SPEED := 60.0
const MAX_HOURS := 12.0

var active := false
var quality := 1.0
var hours_slept := 0.0
var wake_reason := ""
var _player: Player
var _check_t := 0.0
var _pill := false


func _ready() -> void:
	_player = get_parent() as Player
	Events.noise_emitted.connect(_on_noise)


## Why the player cannot fall asleep right now ("" = can).
func blocker() -> String:
	var s := _player.stats
	if s.panic > 0.35:
		return "Слишком страшно, чтобы уснуть."
	if _player.wounds.pain() > 0.55:
		return "Боль не даёт уснуть."
	if s.drowsiness < 0.3 and not _pill:
		return "Спать пока не хочется."
	if _zombie_nearby(9.0, true):
		return "Нельзя спать, когда рядом зомби!"
	return ""


func take_pill() -> void:
	_pill = true


func begin(q: float) -> void:
	active = true
	quality = q * (1.3 if Profession.has_trait("sleeper") else 1.0)
	hours_slept = 0.0
	wake_reason = ""
	_pill = false
	GameTime.time_scale = SPEED
	changed.emit(true)


func wake(reason: String) -> void:
	if not active:
		return
	active = false
	wake_reason = reason
	GameTime.time_scale = 1.0
	changed.emit(false)
	if reason != "":
		Events.show_toast(reason)


func _physics_process(delta: float) -> void:
	if not active:
		return
	var hours := GameTime.game_hours(delta)
	hours_slept += hours
	_player.stats.update_sleep(hours, quality)
	_player.health.heal(4.0 * hours * quality if not _player.wounds.is_bleeding() else 0.0)
	var h := GameTime.get_hour_f()
	if _player.stats.drowsiness <= 0.01 and (h > 5.5 or hours_slept > 6.0):
		wake("Вы выспались. %s" % GameTime.get_clock_text())
	elif hours_slept >= MAX_HOURS:
		wake("Вы проснулись. %s" % GameTime.get_clock_text())
	elif _player.stats.hunger > 0.9 or _player.stats.thirst > 0.9:
		wake("Вас разбудил голод." if _player.stats.hunger > 0.9 else "Вас разбудила жажда.")
	elif _player.wounds.is_bleeding():
		wake("Вы проснулись от боли — кровотечение!")
	_check_t -= delta
	if _check_t <= 0.0 and active:
		_check_t = 0.25
		if _zombie_nearby(7.0, false) or _zombie_nearby(14.0, true):
			wake("Вас разбудил шорох рядом... Зомби!")


func _zombie_nearby(radius: float, hunting_only: bool) -> bool:
	for z in get_tree().get_nodes_in_group("zombies"):
		var zz := z as Zombie
		if zz == null or zz.is_dead():
			continue
		if absf(zz.global_position.y - _player.global_position.y) > 2.0:
			continue
		if zz.global_position.distance_to(_player.global_position) > radius:
			continue
		if not hunting_only or zz.state in [Zombie.State.CHASE, Zombie.State.ATTACK, Zombie.State.BASH]:
			return true
	return false


func _on_noise(pos: Vector3, radius: float, source: Node) -> void:
	if not active or source == _player:
		return
	var d := pos.distance_to(_player.global_position)
	if d < radius * 0.8 and radius >= 8.0:
		wake("Вас разбудил громкий шум!")
