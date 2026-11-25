class_name Enemy
extends CharacterBody2D
## Goblin base. This script is the Wave 1 melee goblin; SpearGoblin (Wave 2) and
## HammerGoblin (Wave 3) extend it and replace only the combat (`_engage`). Movement,
## taunting, hit-stun, blood, HP bar and death are shared.

signal died(points: int)

const STATE_SPAWN: StringName = &"spawning"
const STATE_IDLE: StringName = &"idle"
const STATE_TAUNT: StringName = &"taunting"
const STATE_CHASE: StringName = &"chasing"
const STATE_MELEE: StringName = &"melee_attack"
const STATE_STUN: StringName = &"hit_stun"
const STATE_DEAD: StringName = &"dead"

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
## Sight radius. Larger than the arena, so every enemy locks on as soon as it
## spawns and stays aggravated for the whole wave.
@export var detection_range: float = 100000.0
@export var attack_range: float = 128.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
## Distance between the player and each enemy's standing slot. The art is about
## 110 px wide, so this keeps an enemy off the player's sprite while it swings.
@export var slot_distance: float = 112.0
## Enemies closer than this push each other apart.
@export var separation_radius: float = 56.0
## How long a hit freezes the enemy, and how long it then resists being frozen again.
@export var stun_time: float = 0.35
@export var stun_immunity: float = 0.4
## Height of the HP bar above the feet.
@export var hp_bar_height: float = 126.0
## This wave's supplied taunt sprites (clips named taunt_*), and where the sprite sits
## while they play so the feet stay on the same spot as the normal sprites.
@export var taunt_frames: SpriteFrames
@export var taunt_position_y: float = -55.0
## Up-and-down bob while walking, for art that has a single walking pose.
@export var walk_bob: float = 0.0
## True when the death art is an upright pose, so the body is tipped over instead.
@export var death_tips_over: bool = false
@export var skin_color: Color = Color(0.45, 0.62, 0.3)

var is_dead: bool = false
var state: StringName = STATE_IDLE

var _health: int
var _vertical: bool = false # last walk direction was up/down
var _swinging: bool = false
var _swing_hit_done: bool = false
var _swing_sound_done: bool = false
var _spawning: bool = false
var _blocked_time: float = 0.0
var _detour_time: float = 0.0
var _detour: Vector2 = Vector2.ZERO
var _stun_left: float = 0.0
var _stun_immune_left: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _clock: float = 0.0
var _hp_bar: EnemyHpBar
var _base_scale: Vector2 = Vector2.ONE
var _base_position: Vector2 = Vector2.ZERO
var _main_frames: SpriteFrames
var _taunt: StringName = &""
var _taunt_left: float = 0.0
var _taunt_gap: float = 0.0
var _last_taunt: StringName = &""

@onready var _attack_timer: Timer = $AttackTimer
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _slash: AnimatedSprite2D = $SlashEffect
@onready var _swing_sound: AudioStreamPlayer2D = $SwingSound
@onready var _hurt_sound: AudioStreamPlayer2D = $HurtSound


func _ready() -> void:
	_health = max_health
	_attack_timer.wait_time = attack_cooldown
	add_to_group("enemies")
	_base_scale = _sprite.scale
	_base_position = _sprite.position
	_main_frames = _sprite.sprite_frames
	_taunt_gap = randf_range(0.1, 1.2) # so a group does not taunt in lockstep
	_clock = randf() * 10.0
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)
	_slash.animation_finished.connect(_slash.hide)
	_hp_bar = EnemyHpBar.attach(self, &"goblin", max_health, hp_bar_height)


func _physics_process(delta: float) -> void:
	if is_dead or _spawning:
		return
	_clock += delta
	_stun_immune_left = maxf(_stun_immune_left - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	velocity = Vector2.ZERO
	if _stun_left > 0.0:
		_stun_left -= delta
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		if _stun_left <= 0.0:
			_set_state(STATE_IDLE)
		return
	var target := player if _can_engage(player) else null
	if target == null:
		_cancel_actions()
		_update_taunt(delta, player)
	else:
		_reset_taunt()
		_engage(target, delta)
	var wanted := velocity
	move_and_slide()
	_check_blocked(wanted, delta)
	_update_animation()
	_apply_pose()


## Called by the wave spawner as soon as the enemy is placed. While the summoning
## circle plays, the enemy is invisible, harmless and cannot be hit; it fades in
## and becomes active after `duration` seconds.
func spawn_in(duration: float) -> void:
	_spawning = true
	_set_state(STATE_SPAWN)
	$CollisionShape2D.set_deferred("disabled", true)
	modulate.a = 0.0
	_sprite.scale = _base_scale * 0.7
	var fade := create_tween().set_parallel(true)
	fade.tween_property(self, "modulate:a", 1.0, duration * 0.45).set_delay(duration * 0.35)
	fade.tween_property(_sprite, "scale", _base_scale, duration * 0.45).set_delay(duration * 0.35)
	await get_tree().create_timer(duration).timeout
	_spawning = false
	_set_state(STATE_IDLE)
	$CollisionShape2D.disabled = false


func take_damage(amount: int) -> void:
	if is_dead or _spawning:
		return
	_health -= amount
	_hp_bar.set_health(_health)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var away := Vector2.UP
	if is_instance_valid(player):
		away = (global_position - player.global_position).normalized()
	CombatFx.blood(get_parent(), _body_center(), away)
	_flash_hit()
	_hurt_sound.play()
	if _health <= 0:
		_die()
	elif _stun_immune_left <= 0.0 and _can_stun():
		_begin_stun(away)


## Where hits land and the body crumbles: the middle of the sprite.
func _body_center() -> Vector2:
	return _sprite.global_position


func _flash_hit() -> void:
	_sprite.self_modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(_sprite, "self_modulate", Color.WHITE, 0.22)


## Subclasses return false while a heavy attack must not be interrupted.
func _can_stun() -> bool:
	return true


## Public entry for the Hero's attacks: shove the enemy away from `from` and stun it.
## Does nothing while it is dead, still spawning, or inside its stun immunity window.
func stagger(from: Vector2, force: float = 150.0) -> void:
	if is_dead or _spawning or _stun_immune_left > 0.0 or not _can_stun():
		return
	var away := global_position - from
	if away.length_squared() < 0.01:
		away = Vector2.UP
	_begin_stun(away.normalized(), force)


# A hit freezes the enemy for a moment and pushes it back; whatever it was doing is
# cancelled, and normal behaviour resumes by itself when the stun runs out.
func _begin_stun(away: Vector2, force: float = 150.0) -> void:
	_cancel_actions()
	_reset_taunt()
	_stun_left = stun_time
	_stun_immune_left = stun_time + stun_immunity
	_knockback = away * force
	_set_state(STATE_STUN)
	_sprite.play("hurt")
	_sprite.offset = Vector2.ZERO
	_sprite.rotation = 0.0
	_sprite.scale = _base_scale


func _set_state(next: StringName) -> void:
	state = next


## Combat behaviour while the player is in range. This is the Wave 1 melee goblin;
## the other variants override it.
func _engage(target: Node2D, delta: float) -> void:
	if _swinging:
		return
	if global_position.distance_to(target.global_position) <= attack_range and _at_slot(target):
		_face(target)
		_try_attack(target)
	else:
		velocity = _steer_toward_slot(target)
		_set_state(STATE_CHASE if velocity != Vector2.ZERO else STATE_IDLE)
		if velocity == Vector2.ZERO:
			_face(target)


## Stops whatever the enemy was in the middle of (swing, throw, jump...).
func _cancel_actions() -> void:
	if _swinging:
		_cancel_swing()


# An enemy only fights a player that exists, is alive and is within detection range.
func _can_engage(player: Node2D) -> bool:
	return is_instance_valid(player) and _is_alive(player) \
			and global_position.distance_to(player.global_position) <= detection_range


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
	for other: Node2D in get_tree().get_nodes_in_group("enemies"):
		if not other is Enemy or other.get_script() != get_script():
			continue # only enemies that fight the same way share the slots
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
	return _steer(desired)


## Adds separation from neighbours and the blocked-detour to a desired velocity.
func _steer(desired: Vector2) -> Vector2:
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


func _facing() -> float:
	return -1.0 if _sprite.flip_h else 1.0


## True while an action animation owns the sprite, so walk/idle must not replace it.
func _busy() -> bool:
	return _swinging


func _update_animation() -> void:
	if _busy() or _taunt != &"":
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
	if not _attack_timer.is_stopped():
		return
	_attack_timer.start()
	_swinging = true
	_swing_hit_done = false
	_swing_sound_done = false
	_set_state(STATE_MELEE)
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


# ---- taunting: an out-of-combat goblin jeers at the Hero instead of standing still ----
# Each wave's goblin has its own supplied taunt sprites (`taunt_frames`). A taunt plays
# one clip of them in sheet order, then the goblin stands idle for a moment, then picks
# another clip at random. Anything that interrupts it calls _reset_taunt(), which puts
# the normal sprites straight back.

func _update_taunt(delta: float, player: Node2D) -> void:
	if is_instance_valid(player) and _is_alive(player):
		_face(player) # it mocks the Hero, so it looks at them
	velocity = Vector2.ZERO
	if _taunt == &"":
		_set_state(STATE_IDLE)
		_taunt_gap -= delta
		if _taunt_gap <= 0.0 and taunt_frames != null:
			_start_taunt()
		return
	_set_state(STATE_TAUNT)
	_taunt_left -= delta
	if _taunt_left <= 0.0:
		_reset_taunt()
		_taunt_gap = randf_range(0.6, 1.8)


func _start_taunt() -> void:
	var clips := taunt_frames.get_animation_names()
	var choices := Array(clips).filter(func(c: StringName) -> bool: return c != _last_taunt)
	_taunt = choices.pick_random()
	_last_taunt = _taunt
	_taunt_left = taunt_frames.get_frame_count(_taunt) / taunt_frames.get_animation_speed(_taunt)
	_sprite.sprite_frames = taunt_frames
	_sprite.position.y = taunt_position_y
	_sprite.play(_taunt)


func _reset_taunt() -> void:
	if _taunt == &"":
		return
	_taunt = &""
	_sprite.sprite_frames = _main_frames
	_sprite.position = _base_position
	_sprite.play(&"idle")


# Layers the procedural pose (taunt, walking bob) on the sprite. Never while spawning.
func _apply_pose() -> void:
	if _spawning or is_dead:
		return
	var offset := Vector2.ZERO
	var rot := 0.0
	var scl := Vector2.ONE
	if walk_bob > 0.0 and velocity != Vector2.ZERO:
		offset.y = -absf(sin(_clock * 9.0)) * walk_bob
		rot = sin(_clock * 9.0) * 0.03
	_sprite.offset = offset
	_sprite.rotation = rot
	_sprite.scale = _base_scale * scl


# ---- death ----

func _die() -> void:
	is_dead = true
	_set_state(STATE_DEAD)
	_cancel_actions()
	_reset_taunt()
	_stun_left = 0.0
	died.emit(points)
	# Game autoload is optional for now: skip points if it is missing.
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("add_score"):
		game.add_score(points)

	# No more fighting: out of the enemy group, no collision, no HP bar.
	remove_from_group("enemies")
	$CollisionShape2D.set_deferred("disabled", true)
	_hp_bar.visible = false
	velocity = Vector2.ZERO
	_sprite.offset = Vector2.ZERO
	_sprite.rotation = 0.0
	_sprite.scale = _base_scale
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var side := 1.0 if not is_instance_valid(player) or global_position.x >= player.global_position.x else -1.0
	_sprite.play("hurt") # staggers, then falls
	await get_tree().create_timer(0.12).timeout
	var fall := create_tween().set_parallel(true)
	if death_tips_over:
		fall.tween_property(_sprite, "rotation", side * PI / 2.0, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		fall.tween_property(_sprite, "position:y", _base_position.y + 34.0, 0.4).set_ease(Tween.EASE_IN)
	else:
		_sprite.play("death") # the art already shows the fallen pose
		fall.tween_property(_sprite, "position:y", _base_position.y + 22.0, 0.3).set_ease(Tween.EASE_IN)
		fall.tween_property(_sprite, "position:x", _base_position.x + side * 14.0, 0.3)
	await fall.finished
	CombatFx.crumble(get_parent(), _sprite.global_position, skin_color)
	var fade := create_tween()
	fade.tween_property(_sprite, "modulate:a", 0.0, 0.5)
	await fade.finished
	queue_free()
