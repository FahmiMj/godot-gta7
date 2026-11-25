class_name HammerGoblin
extends Enemy
## Wave 3 goblin. A big, slow bruiser. Its attack: lift the hammer (a red ring shows
## where it will land), leap at the Hero, slam the hammer down for area damage with a
## shockwave and screen shake, then stand open for a short recovery.
## It cannot be staggered while airborne or slamming.

const STATE_PREPARE: StringName = &"preparing_attack"
const STATE_JUMP: StringName = &"jump_attack"
const STATE_SLAM: StringName = &"hammer_slam"
const STATE_RECOVER: StringName = &"recovering"
const SLAM_SOUND: AudioStream = preload("res://assets/audio/hammer_slam.wav")
const JUMP_SOUND: AudioStream = preload("res://assets/audio/hammer_jump.wav")

## Starts the attack when the Hero is within this distance.
@export var jump_range: float = 320.0
@export var windup_time: float = 0.65
@export var jump_time: float = 0.5
@export var jump_height: float = 90.0
## Everything within this distance of the landing spot is hit by the slam.
@export var impact_radius: float = 140.0
@export var slam_hold: float = 0.25
@export var recovery_time: float = 0.8
@export var screen_shake: float = 14.0

var _phase: StringName = &""
var _phase_left: float = 0.0
var _jump_from: Vector2 = Vector2.ZERO
var _jump_to: Vector2 = Vector2.ZERO
var _marker: Node2D
var _audio: AudioStreamPlayer2D


func _ready() -> void:
	super._ready()
	_audio = AudioStreamPlayer2D.new()
	_audio.max_distance = 1800.0
	add_child(_audio)


func _draw() -> void:
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 46.0, Color(0, 0, 0, 0.3)) # ground shadow


func _exit_tree() -> void:
	_clear_marker()


func _busy() -> bool:
	return _phase != &""


func _can_stun() -> bool:
	return _phase != &"jump" and _phase != &"slam"


func _cancel_actions() -> void:
	super._cancel_actions()
	if _phase != &"":
		_phase = &""
		_clear_marker()
		_sprite.position = _base_position
		_hp_bar.position.y = -hp_bar_height


func _engage(target: Node2D, delta: float) -> void:
	if _phase != &"":
		_run_phase(target, delta)
		return
	_face(target)
	var distance := global_position.distance_to(target.global_position)
	if distance <= jump_range and _attack_timer.is_stopped():
		_phase = &"windup"
		_phase_left = windup_time
		_set_state(STATE_PREPARE)
		_sprite.play("windup")
		_show_marker(target.global_position)
	elif distance > 110.0:
		velocity = _steer(global_position.direction_to(target.global_position) * speed)
		_set_state(STATE_CHASE)
	else:
		_set_state(STATE_IDLE)


func _run_phase(target: Node2D, delta: float) -> void:
	_phase_left -= delta
	match _phase:
		&"windup":
			_face(target)
			_marker.global_position = target.global_position # the ring follows until the leap
			if _phase_left <= 0.0:
				_start_jump(target)
		&"jump":
			var k := clampf(1.0 - _phase_left / jump_time, 0.0, 1.0)
			var wanted := _jump_from.lerp(_jump_to, k)
			velocity = (wanted - global_position) / maxf(delta, 0.001)
			var lift := sin(PI * k) * jump_height
			_sprite.position.y = _base_position.y - lift
			_hp_bar.position.y = -hp_bar_height - lift
			if _phase_left <= 0.0:
				_land(target)
		&"slam":
			if _phase_left <= 0.0:
				_phase = &"recover"
				_phase_left = recovery_time
				_set_state(STATE_RECOVER)
				_sprite.play("recover")
		&"recover":
			if _phase_left <= 0.0:
				_phase = &""
				_set_state(STATE_IDLE)


func _start_jump(target: Node2D) -> void:
	_phase = &"jump"
	_phase_left = jump_time
	_set_state(STATE_JUMP)
	_sprite.play("jump")
	_jump_from = global_position
	# Lands just in front of the Hero's current spot, locked now, so a Hero who keeps
	# moving can dodge it.
	var to_hero := target.global_position - global_position
	_jump_to = target.global_position - to_hero.normalized() * minf(50.0, to_hero.length())
	_marker.global_position = _jump_to
	_play(JUMP_SOUND)


func _land(target: Node2D) -> void:
	_phase = &"slam"
	_phase_left = slam_hold
	_attack_timer.start() # cooldown runs from the landing
	_set_state(STATE_SLAM)
	_sprite.play("slam")
	_sprite.position = _base_position
	_hp_bar.position.y = -hp_bar_height
	_clear_marker()
	# One check at the moment of impact: the slam can hurt the Hero only once.
	if is_instance_valid(target) and _is_alive(target) and target.has_method("take_damage") \
			and global_position.distance_to(target.global_position) <= impact_radius:
		target.take_damage(attack_damage)
	CombatFx.shockwave(get_parent(), global_position, impact_radius)
	CombatFx.shake(get_tree(), screen_shake, 0.4)
	_play(SLAM_SOUND)


func _play(stream: AudioStream) -> void:
	_audio.stream = stream
	_audio.play()


func _show_marker(at: Vector2) -> void:
	_clear_marker()
	_marker = TargetRing.new()
	(_marker as TargetRing).radius = impact_radius
	(_marker as TargetRing).duration = windup_time + jump_time
	get_parent().add_child(_marker)
	_marker.global_position = at


func _clear_marker() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


## The red warning ring on the ground where the slam will land.
class TargetRing extends Node2D:
	var radius: float = 140.0
	var duration: float = 1.0
	var _time: float = 0.0

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_time / duration, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, radius, Color(0.9, 0.1, 0.1, 0.10 + 0.14 * k))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.25, 0.2, 0.55 + 0.35 * k), 3.0)
		draw_arc(Vector2.ZERO, radius * (1.0 - k), 0.0, TAU, 48, Color(1.0, 0.5, 0.3, 0.6), 2.0)
