extends Node2D
class_name EnemyHealthBar

## A temporary health bar drawn above an enemy. It appears when the enemy takes
## damage, shows the remaining health as a filled bar, and fades out after
## show_time seconds. While the enemy is at full health nothing is drawn.

@export var width: float = 34.0
@export var height: float = 6.0
## Seconds the bar stays visible after the last hit.
@export var show_time: float = 2.5

var _current: int = 0
var _maximum: int = 1
## Seconds left before the bar disappears.
var _timer: float = 0.0


func set_health(current: int, maximum: int) -> void:
	_current = current
	_maximum = maximum
	_timer = show_time
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _maximum <= 0:
		return
	# Only show while damaged and within the display window.
	if _current >= _maximum and _timer <= 0.0:
		return

	var alpha = 1.0
	if show_time > 0.0:
		alpha = clampf(_timer / show_time, 0.0, 1.0)
	if alpha <= 0.0:
		return

	var center = Vector2(width * 0.5, 0.0)
	var size = Vector2(width, height)
	var bg_rect = Rect2(center - size * 0.5, size)

	# Background track.
	draw_rect(bg_rect, Color(0.15, 0.15, 0.15, 0.85 * alpha))
	# Border.
	draw_rect(bg_rect, Color(1.0, 1.0, 1.0, 0.35 * alpha), false)

	# Filled portion (red when low, green otherwise).
	var fill := clampf(float(_current) / float(_maximum), 0.0, 1.0)
	if fill > 0.0:
		var fg_color := Color(1.0, 0.2, 0.2, 0.95 * alpha) if fill < 0.35 else Color(0.25, 0.9, 0.35, 0.9 * alpha)
		var fg_rect := Rect2(center - size * 0.5, Vector2(width * fill, height))
		draw_rect(fg_rect, fg_color)
