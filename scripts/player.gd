extends CharacterBody2D
## Top-down 4-direction player controller.
##
## Animations are named "<state>_<facing>", e.g. walk_left / idle_up.
## The sprite sheet has 5 rows: down, up, left, right, idle.

@export var speed: float = 200.0
## How far a blink teleports, in pixels.
@export var blink_distance: float = 300.0
## How long the sprite stays invisible mid-blink, in seconds.
@export var blink_hide_time: float = 0.06

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _facing: String = "down"
var _blinking: bool = false


func _physics_process(_delta: float) -> void:
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
	if event.is_action_pressed("blink") and not _blinking:
		_blink()


## Vanishes for a moment, reappears blink_distance ahead in the facing direction.
func _blink() -> void:
	_blinking = true
	sprite.visible = false
	global_position += _facing_vector() * blink_distance
	await get_tree().create_timer(blink_hide_time).timeout
	sprite.visible = true
	_blinking = false


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
