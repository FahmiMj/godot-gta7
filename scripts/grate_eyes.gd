extends Node2D
## Occasionally reveals a pair of monster eyes between the bars of a floor grate.

const EYES_TEXTURE := preload("res://assets/grate_eyes.png")

## World positions of the grate centres this node should peek through.
@export var positions: PackedVector2Array = PackedVector2Array()
## How long to wait between glimpses.
@export var min_delay: float = 3.0
@export var max_delay: float = 8.0
## How long the eyes linger after the blink.
@export var min_visible: float = 1.1
@export var max_visible: float = 2.4

var _eyes: Array[Sprite2D] = []
var _timer: float = 0.0
var _busy: bool = false


func _ready() -> void:
	for p in positions:
		var eye := Sprite2D.new()
		eye.texture = EYES_TEXTURE
		eye.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		eye.position = p
		eye.modulate = Color(1.0, 1.0, 1.0, 0.0)
		eye.visible = false
		add_child(eye)
		_eyes.append(eye)
	_timer = randf_range(1.2, 3.5)


func _process(delta: float) -> void:
	if _busy or _eyes.is_empty():
		return
	_timer -= delta
	if _timer <= 0.0:
		_reveal()


func _reveal() -> void:
	_busy = true
	var index := randi() % _eyes.size()
	var eye := _eyes[index]
	eye.position = positions[index] + Vector2(randf_range(-1.5, 1.5), 0.0)
	eye.scale = Vector2.ONE
	eye.modulate = Color(1.0, 1.0, 1.0, 0.0)
	eye.visible = true

	var tween := create_tween()
	tween.tween_property(eye, "modulate:a", 1.0, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(eye, "position:x", eye.position.x + randf_range(-2.5, 2.5), 0.55)\
		.set_trans(Tween.TRANS_SINE)
	# one slow blink, then stare a little longer
	tween.tween_property(eye, "scale:y", 0.06, 0.06)
	tween.tween_property(eye, "scale:y", 1.0, 0.1)
	tween.tween_interval(randf_range(min_visible, max_visible))
	tween.tween_property(eye, "modulate:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		eye.visible = false
		_busy = false
		_timer = randf_range(min_delay, max_delay)
	)
