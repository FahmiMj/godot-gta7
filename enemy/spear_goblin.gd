class_name SpearGoblin
extends Enemy
## Wave 2 goblin. A ranged spear thrower: it spots the Hero from far away, keeps its
## distance, turns to face them, lifts the spear, throws it as a real projectile, then
## waits out a cooldown before the next throw.

const STATE_PREPARE: StringName = &"preparing_attack"
const STATE_THROW: StringName = &"spear_throw"
const SPEAR: Script = preload("res://enemy/spear_projectile.gd")

## Starts throwing from this far; walks closer when the Hero is further.
@export var throw_range: float = 380.0
## Backs away when the Hero is closer than this.
@export var keep_away_range: float = 170.0
## Time the spear is lifted before it is released.
@export var windup_time: float = 0.55
## Time after release before it can move again.
@export var throw_recovery: float = 0.35
@export var projectile_speed: float = 520.0

var _phase_left: float = 0.0
var _phase: StringName = &""


func _busy() -> bool:
	return _phase != &""


func _cancel_actions() -> void:
	super._cancel_actions()
	_phase = &""


func _engage(target: Node2D, delta: float) -> void:
	var distance := global_position.distance_to(target.global_position)
	if _phase != &"":
		_face(target) # keeps turning toward the Hero while aiming
		_phase_left -= delta
		if _phase_left <= 0.0:
			if _phase == &"prepare":
				_throw(target)
			else:
				_phase = &""
				_set_state(STATE_IDLE)
		return
	_face(target)
	if distance <= throw_range and _attack_timer.is_stopped():
		_start_prepare()
	elif distance > throw_range:
		velocity = _steer(global_position.direction_to(target.global_position) * speed)
		_set_state(STATE_CHASE)
	elif distance < keep_away_range:
		velocity = _steer(target.global_position.direction_to(global_position) * speed * 0.8)
		_set_state(STATE_CHASE)
	else:
		_set_state(STATE_IDLE)


func _start_prepare() -> void:
	_phase = &"prepare"
	_phase_left = windup_time
	_set_state(STATE_PREPARE)
	_sprite.play("prep")


func _throw(target: Node2D) -> void:
	_phase = &"throw"
	_phase_left = throw_recovery
	_attack_timer.start() # the cooldown runs from the release
	_set_state(STATE_THROW)
	_sprite.play("throw")
	_swing_sound.play()
	var spear := SPEAR.new() as SpearProjectile
	spear.damage = attack_damage
	spear.speed = projectile_speed
	spear.max_distance = throw_range + 320.0
	get_parent().add_child(spear)
	var hand := global_position + Vector2(24.0 * _facing(), 0.0)
	spear.global_position = hand
	spear.launch(target.global_position - hand)
