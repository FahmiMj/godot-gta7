extends CharacterBody2D
## Top-down 4-direction player controller.
##
## Animations are named "<state>_<facing>", e.g. walk_left / idle_up.
## The sprite sheet has 5 rows: down, up, left, right, idle.
## Q flash steps forward, E conjures and hurls dark fire toward the cursor,
## left click swings a punch in the current facing direction.

const TRAIL_SHADER := preload("res://assets/shaders/flash_step_trail.gdshader")
const DARK_FIRE_SCENE := preload("res://scenes/dark_fire.tscn")

## The cast animation faces right, so a leftward throw only flips the sprite.
const HAND_OFFSET := Vector2(64.0, -71.0)

@export var speed: float = 400.0
@export var max_health: int = 200
## How far a flash step teleports, in pixels.
@export var flash_step_distance: float = 300.0
## How long the sprite stays invisible mid-flash-step, in seconds.
@export var flash_step_hide_time: float = 0.06
## How many white afterimages are left along the path.
@export var flash_step_trail_count: int = 4
## How long each afterimage takes to fade out, in seconds.
@export var flash_step_trail_fade: float = 0.3
## Time between dark fire throws, in seconds.
@export var attack_cooldown: float = 1.0
## Time between melee swings, in seconds.
@export var melee_cooldown: float = 0.45
## Health taken from each enemy the punch reaches.
@export var melee_damage: int = 25
## How far the punch reaches in front of the player, in pixels.
@export var melee_range: float = 100.0
## How far the character lunges forward when swinging, in pixels.
@export var melee_lunge_distance: float = 40.0
## How long the lunge takes, in seconds.
@export var melee_lunge_time: float = 0.15
## Health taken from each enemy the flash step passes through.
@export var flash_damage: int = 15
## How close to the dash line an enemy must be to be hit, in pixels.
@export var flash_hit_radius: float = 44.0

signal health_changed(current: int, maximum: int)
signal died

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var flash_step_sound: AudioStreamPlayer = $FlashStepSound

var health: int = 200
var _facing: String = "down"
var _flash_stepping: bool = false
var _casting: bool = false
var _melee_attacking: bool = false
var _dead: bool = false
var _reviving: bool = false
var _attack_cooldown_left: float = 0.0
var _melee_cooldown_left: float = 0.0
var _trail_material: ShaderMaterial


func _ready() -> void:
	health = max_health
	_trail_material = ShaderMaterial.new()
	_trail_material.shader = TRAIL_SHADER
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	_melee_cooldown_left = maxf(0.0, _melee_cooldown_left - delta)

	if _dead:
		velocity = Vector2.ZERO
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# planting the feet mid-swing is what sells the punch
	if _melee_attacking:
		velocity = Vector2.ZERO
		return

	velocity = input_dir * speed
	move_and_slide()

	# the spell animation owns the sprite until the throw and recovery finish
	if _casting:
		return

	if input_dir == Vector2.ZERO:
		_play("idle")
		return

	# prefer the dominant axis so diagonals don't flicker between rows
	if absf(input_dir.x) > absf(input_dir.y):
		_facing = "right" if input_dir.x > 0.0 else "left"
	else:
		_facing = "down" if input_dir.y > 0.0 else "up"
	_play("walk")


func _play(state: String) -> void:
	var anim := "%s_%s" % [state, _facing]
	if sprite.animation != anim:
		sprite.play(anim)


func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _melee_cooldown_left <= 0.0 and not _casting and not _melee_attacking:
			_melee_attack()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("flash_step") and not _flash_stepping:
		_flash_step()
	elif event.is_action_pressed("attack") and _attack_cooldown_left <= 0.0 and not _casting:
		_attack()


func take_damage(amount: int) -> void:
	if _dead or _reviving:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()


func heal(amount: int) -> void:
	if _dead or _reviving:
		return
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)


func _die() -> void:
	if _dead:
		return
	_dead = true
	_casting = false
	_melee_attacking = false
	velocity = Vector2.ZERO
	sprite.flip_h = false
	sprite.play("wither")
	died.emit()
	await sprite.animation_finished
	# hold the final withered frame
	if _dead:
		sprite.frame = sprite.sprite_frames.get_frame_count("wither") - 1
		sprite.pause()


func revive() -> void:
	if not _dead or _reviving:
		return
	_reviving = true
	sprite.flip_h = false
	sprite.play_backwards("wither")
	await sprite.animation_finished
	health = max_health
	_dead = false
	_reviving = false
	_casting = false
	_melee_attacking = false
	_facing = "down"
	health_changed.emit(health, max_health)
	_play("idle")


## Vanishes for a moment, reappears flash_step_distance ahead in the facing direction.
func _flash_step() -> void:
	_flash_stepping = true
	_spawn_trail()
	flash_step_sound.play()
	# damage any enemy swept through on the dash line
	var dash_start := global_position
	var dash_end := dash_start + _facing_vector() * flash_step_distance
	_hit_enemies_along_segment(dash_start, dash_end, flash_damage, flash_hit_radius)
	sprite.visible = false
	global_position = dash_end
	await get_tree().create_timer(flash_step_hide_time).timeout
	sprite.visible = true
	_flash_stepping = false


## Damages every enemy whose center is within range and roughly in front of the
## player (used for the melee punch).
func _hit_enemies_in_front(damage: int, range: float) -> void:
	var forward := _facing_vector()
	var origin := global_position
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var to: Vector2 = enemy.global_position - origin
		if to.length() > range:
			continue
		if to.dot(forward) < -16.0:
			continue
		enemy.take_damage(damage)


## Damages every enemy whose center lies within radius of the line segment
## start->end (used for the flash step dash).
func _hit_enemies_along_segment(start: Vector2, end: Vector2, damage: int, radius: float) -> void:
	var segment := end - start
	var length := segment.length()
	if length <= 0.0:
		return
	var direction := segment / length
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var to: Vector2 = enemy.global_position - start
		var t := clampf(to.dot(direction), 0.0, length)
		var closest := start + direction * t
		if enemy.global_position.distance_to(closest) <= radius:
			enemy.take_damage(damage)


## Leaves flat white silhouettes of the current frame along the travel path.
func _spawn_trail() -> void:
	var frame := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
	if frame == null or frame.atlas == null:
		return

	var direction := _facing_vector()
	var parent := get_parent()
	for i in flash_step_trail_count:
		var progress := float(i + 1) / float(flash_step_trail_count + 1)
		var ghost := Sprite2D.new()
		ghost.name = "FlashStepTrail%d" % (i + 1)
		ghost.texture = frame.atlas
		ghost.region_enabled = true
		ghost.region_rect = frame.region
		ghost.offset = sprite.offset
		ghost.flip_h = sprite.flip_h
		ghost.flip_v = sprite.flip_v
		ghost.texture_filter = sprite.texture_filter
		ghost.material = _trail_material
		ghost.modulate = Color(1.0, 1.0, 1.0, 0.8)

		# sit just behind the player in draw order so the real sprite stays on top
		parent.add_child(ghost)
		parent.move_child(ghost, get_index())
		ghost.global_position = global_position + direction * flash_step_distance * progress

		var tween := ghost.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, flash_step_trail_fade)
		tween.tween_callback(ghost.queue_free)


## Swings the punch that matches the way the player is currently facing.
## The sheet already has a dedicated row per direction, so no flipping is
## needed - attack_left really is drawn facing left.
func _melee_attack() -> void:
	_melee_attacking = true
	_melee_cooldown_left = melee_cooldown
	velocity = Vector2.ZERO
	sprite.flip_h = false

	var anim := "attack_%s" % _facing
	if not sprite.sprite_frames.has_animation(anim):
		anim = "attack_down"
	sprite.play(anim)

	# lunge a short step in the attack direction so the punch feels weighty
	var lunge_target := global_position + _facing_vector() * melee_lunge_distance
	var lunge := create_tween()
	lunge.tween_property(self, "global_position", lunge_target, melee_lunge_time)
	lunge.tween_callback(lunge.kill)

	# the punch lands immediately: hurt anything in reach in front of us
	_hit_enemies_in_front(melee_damage, melee_range)

	await sprite.animation_finished
	_melee_attacking = false
	# dying mid-swing hands the sprite over to the wither animation
	if _dead or _reviving:
		return
	_play("idle")


## Plays the conjure animation and releases the ball when the hand is thrust out.
func _attack() -> void:
	_casting = true
	_attack_cooldown_left = attack_cooldown

	var aim := get_global_mouse_position() - global_position
	sprite.flip_h = aim.x < -4.0

	sprite.play("cast")
	await sprite.animation_finished
	_throw_dark_fire(_hand_position())

	sprite.play("cast_recover")
	await sprite.animation_finished
	sprite.flip_h = false
	_casting = false


## World position of the fireball in the release pose, mirrored for left throws.
func _hand_position() -> Vector2:
	return global_position + Vector2(-HAND_OFFSET.x if sprite.flip_h else HAND_OFFSET.x, HAND_OFFSET.y)


func _throw_dark_fire(spawn_position: Vector2) -> void:
	var target := get_global_mouse_position()
	if target.distance_to(spawn_position) < 8.0:
		target = spawn_position + _facing_vector() * 100.0

	var fire := DARK_FIRE_SCENE.instantiate()
	get_parent().add_child(fire)
	fire.global_position = spawn_position
	fire.setup(target)


func _facing_vector() -> Vector2:
	match _facing:
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		"up":
			return Vector2.UP
		_:
			return Vector2.DOWN
