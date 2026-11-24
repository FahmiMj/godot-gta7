class_name Enemy
extends CharacterBody2D
## Reusable chaser enemy. Goblin, skeleton, mage... differ only by @export stats.

signal died(points: int)

## Swing frame (0-based) where the sword comes forward and the damage lands.
const HIT_FRAME: int = 2
## Swing frame where the sword starts moving fast: the whoosh starts here.
const SOUND_FRAME: int = 1
## Standing spots around the player, as angles in degrees (0 = right, 180 = left).
## The sides come first, so enemies fill left and right before the diagonals.
const SLOT_ANGLES: Array[float] = [0.0, 180.0, -50.0, 230.0, 50.0, 130.0]
const REASSIGN_MSEC: int = 300

## Which slot each enemy holds. Shared by every enemy, refreshed a few times a second.
static var _slots: Dictionary = {}
static var _slots_updated: int = -1000000

@export var speed: float = 130.0
@export var max_health: int = 30
@export var points: int = 5
@export var detection_range: float = 250.0
@export var attack_range: float = 96.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
## Distance between the player and each enemy's standing slot.
@export var slot_distance: float = 76.0
## Enemies closer than this push each other apart.
@export var separation_radius: float = 56.0

var is_dead: bool = false

var _health: int
var _vertical: bool = false # last walk direction was up/down
var _swinging: bool = false
var _swing_hit_done: bool = false
var _swing_sound_done: bool = false
var _blocked_time: float = 0.0
var _detour_time: float = 0.0
var _detour: Vector2 = Vector2.ZERO

@onready var _attack_timer: Timer = $AttackTimer
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _slash: AnimatedSprite2D = $SlashEffect
@onready var _swing_sound: AudioStreamPlayer2D = $SwingSound


func _ready() -> void:
	_health = max_health
	_attack_timer.wait_time = attack_cooldown
	add_to_group("enemies")
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)
	_slash.animation_finished.connect(_slash.hide)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	velocity = Vector2.ZERO
	var target := player if _can_engage(player) else null
	if _swinging and target == null:
		_cancel_swing()
	if target != null and not _swinging:
		if global_position.distance_to(target.global_position) <= attack_range and _at_slot(target):
			_face(target)
			_try_attack(target)
		else:
			velocity = _steer_toward_slot(target)
			if velocity == Vector2.ZERO:
				_face(target)
	var wanted := velocity
	move_and_slide()
	_check_blocked(wanted, delta)
	_update_animation()


func take_damage(amount: int) -> void:
	if is_dead:
		return
	_health -= amount
	if _health <= 0:
		_die()
	else:
		_swinging = false
		_cancel_swing_effects()
		_sprite.play("hurt")


# An enemy only fights a player that exists, is alive and is within detection range.
func _can_engage(player: Node2D) -> bool:
	return is_instance_valid(player) and _is_alive(player) 			and global_position.distance_to(player.global_position) <= detection_range


# The Hero's own health decides: it reports health 0 while dead and again > 0 once revived.
func _is_alive(player: Node2D) -> bool:
	return not ("health" in player) or player.health > 0


func _slot_world(player: Node2D, slot: int) -> Vector2:
	return player.global_position + Vector2.from_angle(deg_to_rad(SLOT_ANGLES[slot])) * slot_distance


# Every enemy holds the free slot nearest to it. This is re-checked a few times a
# second, so an enemy that is blocked or arrives late swaps to a better spot instead
# of being stuck with a distant one.
func _slot_for(player: Node2D) -> int:
	var now := Time.get_ticks_msec()
	if now - _slots_updated >= REASSIGN_MSEC or not _slots.has(self):
		_slots_updated = now
		_assign_slots(player)
	return _slots.get(self, 0)


func _assign_slots(player: Node2D) -> void:
	var pairs: Array = []
	for other: Enemy in get_tree().get_nodes_in_group("enemies"):
		for slot in SLOT_ANGLES.size():
			pairs.append([other.global_position.distance_squared_to(_slot_world(player, slot)), other, slot])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_slots.clear()
	var taken: Dictionary = {}
	for pair: Array in pairs:
		if not _slots.has(pair[1]) and not taken.has(pair[2]):
			_slots[pair[1]] = pair[2]
			taken[pair[2]] = true


func _at_slot(player: Node2D) -> bool:
	return global_position.distance_to(_slot_world(player, _slot_for(player))) <= 20.0


# Head for the slot (it moves with the player) and slide away from neighbours.
func _steer_toward_slot(player: Node2D) -> Vector2:
	var to_slot := _slot_world(player, _slot_for(player)) - global_position
	var desired := to_slot.normalized() * speed * clampf(to_slot.length() / 24.0, 0.0, 1.0)
	var push := Vector2.ZERO
	for other: Node2D in get_tree().get_nodes_in_group("enemies"):
		var offset := global_position - other.global_position
		var gap := offset.length()
		if other != self and gap > 0.0 and gap < separation_radius:
			push += offset / gap * (1.0 - gap / separation_radius)
	var detour := _detour * speed if _detour_time > 0.0 else Vector2.ZERO
	var steer := (desired + push * speed + detour).limit_length(speed)
	return Vector2.ZERO if steer.length() < 8.0 else steer


# Enemies are solid to each other. If something keeps this one from moving where
# it wants to go, it sidesteps for a moment (random side) to find another way round.
func _check_blocked(wanted: Vector2, delta: float) -> void:
	_detour_time = maxf(_detour_time - delta, 0.0)
	if wanted.length() > 40.0 and get_real_velocity().length() < wanted.length() * 0.3:
		_blocked_time += delta
	else:
		_blocked_time = 0.0
	if _blocked_time > 0.4:
		_blocked_time = 0.0
		_detour_time = 0.6
		_detour = wanted.orthogonal().normalized() * (1.0 if randf() < 0.5 else -1.0)


# All the art faces RIGHT, so flip it to face left. Used only while standing or
# swinging; while walking, the facing follows velocity (see _walk_animation).
func _face(player: Node2D) -> void:
	var dx := player.global_position.x - global_position.x
	if absf(dx) > 3.0:
		_sprite.flip_h = dx < 0.0


func _is_hurt() -> bool:
	return _sprite.animation == &"hurt" and _sprite.is_playing()


# Walk/idle never interrupt a swing or a hurt pose that is still playing.
# While walking, the art is flipped by velocity, not by player position.
func _update_animation() -> void:
	if _swinging or _is_hurt():
		return
	_sprite.play(_walk_animation() if velocity != Vector2.ZERO else &"idle")


# Pick the walk animation from the actual movement direction. The 1.3 margin
# stops it flickering between side and up/down on near-diagonal movement.
func _walk_animation() -> StringName:
	if _vertical:
		_vertical = absf(velocity.x) <= absf(velocity.y) * 1.3
	else:
		_vertical = absf(velocity.y) > absf(velocity.x) * 1.3
	if absf(velocity.x) > 5.0:
		_sprite.flip_h = velocity.x < 0.0
	if not _vertical:
		return &"walk_side"
	return &"walk_down" if velocity.y > 0.0 else &"walk_up"


func _try_attack(_player: Node2D) -> void:
	# The timer is the cooldown: it starts with the swing, so a new swing can
	# only begin once it has stopped. Damage lands later, in _on_frame_changed.
	if not _attack_timer.is_stopped() or _is_hurt():
		return
	_attack_timer.start()
	_swinging = true
	_swing_hit_done = false
	_swing_sound_done = false
	_sprite.play("attack")


# The whoosh starts as the sword speeds up. Damage and the slash effect happen
# once per swing, on the forward frame; damage only if the player is still in reach.
func _on_frame_changed() -> void:
	if not _swinging or _sprite.animation != &"attack":
		return
	if _sprite.frame == SOUND_FRAME and not _swing_sound_done:
		_swing_sound_done = true
		_swing_sound.play()
	if _sprite.frame != HIT_FRAME or _swing_hit_done:
		return
	_swing_hit_done = true
	_play_slash()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player) or not player.has_method("take_damage") or not _is_alive(player):
		return
	if global_position.distance_to(player.global_position) <= attack_range + 8.0:
		player.take_damage(attack_damage)


# The slash art faces right like the sprite: mirror it to the side the sword swings.
func _play_slash() -> void:
	_slash.flip_h = _sprite.flip_h
	_slash.position.x = absf(_slash.position.x) * (-1.0 if _sprite.flip_h else 1.0)
	_slash.show()
	_slash.play("slash")


func _cancel_swing() -> void:
	_swinging = false
	_cancel_swing_effects()


func _cancel_swing_effects() -> void:
	_slash.stop()
	_slash.hide()
	_swing_sound.stop()


func _on_animation_finished() -> void:
	if _sprite.animation == &"attack":
		_swinging = false


func _die() -> void:
	is_dead = true
	_swinging = false
	_cancel_swing_effects()
	died.emit(points)
	# Game autoload is optional for now: skip points if it is missing.
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("add_score"):
		game.add_score(points)

	# Stop interacting, show the death pose, fade out, then remove.
	remove_from_group("enemies")
	$CollisionShape2D.set_deferred("disabled", true)
	_sprite.play("death")
	var fade := create_tween()
	fade.tween_property(_sprite, "modulate:a", 0.0, 0.6)
	await fade.finished
	queue_free()
