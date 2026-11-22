extends CharacterBody2D
## Top-down 4-direction player controller.
##
## Animations are named "<state>_<facing>", e.g. walk_left / idle_up.
## The sprite sheet has 5 rows: down, up, left, right, idle.
## Q flash steps forward, E conjures and hurls dark fire toward the cursor.

const TRAIL_SHADER := preload("res://assets/shaders/flash_step_trail.gdshader")
const DARK_FIRE_SCENE := preload("res://scenes/dark_fire.tscn")

## The cast animation faces right, so a leftward throw only flips the sprite.
const HAND_OFFSET := Vector2(64.0, -71.0)

@export var speed: float = 200.0
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

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var flash_step_sound: AudioStreamPlayer = $FlashStepSound

var _facing: String = "down"
var _flash_stepping: bool = false
var _casting: bool = false
var _attack_cooldown_left: float = 0.0
var _trail_material: ShaderMaterial


func _ready() -> void:
	_trail_material = ShaderMaterial.new()
	_trail_material.shader = TRAIL_SHADER


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

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
	if event.is_action_pressed("flash_step") and not _flash_stepping:
		_flash_step()
	elif event.is_action_pressed("attack") and _attack_cooldown_left <= 0.0 and not _casting:
		_attack()


## Vanishes for a moment, reappears flash_step_distance ahead in the facing direction.
func _flash_step() -> void:
	_flash_stepping = true
	_spawn_trail()
	flash_step_sound.play()
	sprite.visible = false
	global_position += _facing_vector() * flash_step_distance
	await get_tree().create_timer(flash_step_hide_time).timeout
	sprite.visible = true
	_flash_stepping = false


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
