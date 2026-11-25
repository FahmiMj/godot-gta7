extends Node2D
## Spawns short-lived expanding rings on the room's puddles at random intervals.

const RIPPLE_TEXTURE := preload("res://assets/water_ripple.png")

## World positions of the puddle centres this node should animate.
@export var positions: PackedVector2Array = PackedVector2Array()
## Shortest and longest wait before a given puddle ripples again.
@export var min_delay: float = 0.9
@export var max_delay: float = 3.4
## How long one ring takes to expand and fade.
@export var ripple_lifetime: float = 1.5

var _timers: Array[float] = []


func _ready() -> void:
	for i in positions.size():
		_timers.append(randf_range(0.15, max_delay))


func _process(delta: float) -> void:
	for i in _timers.size():
		_timers[i] -= delta
		if _timers[i] > 0.0:
			continue
		_timers[i] = randf_range(min_delay, max_delay)
		_spawn_ripple(positions[i])


func _spawn_ripple(center: Vector2) -> void:
	var ring := Sprite2D.new()
	ring.texture = RIPPLE_TEXTURE
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring.position = center + Vector2(randf_range(-20.0, 20.0), randf_range(-12.0, 12.0))
	ring.scale = Vector2.ONE * randf_range(0.32, 0.48)
	ring.modulate = Color(0.72, 0.88, 1.0, 0.0)
	add_child(ring)

	var target_scale := randf_range(0.85, 1.15)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "modulate:a", 0.78, 0.12)
	tween.tween_property(ring, "scale", Vector2.ONE * target_scale, ripple_lifetime)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, ripple_lifetime * 0.65)\
		.set_delay(ripple_lifetime * 0.35)
	tween.chain().tween_callback(ring.queue_free)
