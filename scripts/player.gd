extends CharacterBody2D
## Top-down 4-direction player controller.
##
## Animations are named "<state>_<facing>", e.g. walk_left / idle_up.
## The sprite sheet has 5 rows: down, up, left, right, idle.
## Q flash steps forward, E hurls dark fire toward the cursor.

const TRAIL_SHADER := preload("res://assets/shaders/flash_step_trail.gdshader")
const DarkFire := preload("res://scripts/dark_fire.gd")
const DARK_FIRE_SCENE := preload("res://scenes/dark_fire.tscn")

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
@export var attack_cooldown: float = 0.45
## How long the flame is conjured in the hand before the throw, in seconds.
@export var cast_time: float = 0.22

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var flash_step_sound: AudioStreamPlayer = $FlashStepSound

var _facing: String = "down"
var _flash_stepping: bool = false
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
	elif event.is_action_pressed("attack") and _attack_cooldown_left <= 0.0:
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


## Conjures dark fire in the hand, then hurls it at the cursor.
func _attack() -> void:
	_attack_cooldown_left = attack_cooldown

	var hand_offset := _facing_vector() * 26.0 + Vector2(0.0, -70.0)
	var flame := DarkFire.make_flame_sprite(Vector2(0.5, 0.7))
	flame.name = "HandFlame"
	flame.position = hand_offset
	flame.rotation = _facing_vector().angle() + PI * 0.5
	add_child(flame)

	# the flame swells in the hand while it is being conjured
	var tween := create_tween()
	tween.tween_property(flame, "scale", Vector2(0.8, 1.05), cast_time * 0.8)
	tween.parallel().tween_property(flame, "modulate:a", 1.0, cast_time * 0.5)

	await get_tree().create_timer(cast_time).timeout
	if not is_instance_valid(flame):
		return
	var spawn_position := flame.global_position
	flame.queue_free()
	_throw_dark_fire(spawn_position)


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
