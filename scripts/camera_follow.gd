extends Camera2D
## Keeps the player dead-centre while walking, but pans smoothly after the
## flash-step teleport instead of cutting to the new position.

## Pixels per second the camera moves at when it has almost caught up.
@export var settle_speed: float = 600.0
## Pixels per second the camera moves at right after a jump.
@export var catch_up_speed: float = 1500.0
## Distance from the player at which the camera reaches full catch-up speed.
@export var ramp_distance: float = 320.0
## A single-frame jump larger than this (in pixels) counts as a teleport.
@export var teleport_threshold: float = 100.0

var _last_target := Vector2.ZERO


func _ready() -> void:
	var target := _target()
	if target != null:
		_last_target = target.global_position


func _process(delta: float) -> void:
	var target := _target()
	if target == null:
		return

	var target_pos := target.global_position
	var jump := target_pos - _last_target
	_last_target = target_pos
	if jump.length() > teleport_threshold:
		# The camera rides in the player's transform, so it would jump instantly.
		# Cancel the jump first, then let the pan below glide it to the player.
		global_position -= jump

	var diff := target_pos - get_global_position()
	var distance := diff.length()
	if distance < 0.01:
		return

	# Walking is absorbed in a single frame, so the player stays centred.
	# A flash-step jump ramps the pan speed instead of cutting.
	var weight := clampf(distance / ramp_distance, 0.0, 1.0)
	var step := lerpf(settle_speed, catch_up_speed, weight) * delta
	if distance <= step:
		global_position = target_pos
	else:
		global_position += diff / distance * step


func _target() -> Node2D:
	return get_parent() as Node2D
