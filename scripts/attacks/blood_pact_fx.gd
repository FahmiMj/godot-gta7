class_name BloodPactFx
extends Node2D
## The look of a blood pact: the Hero's own life spilling out as dark red rings,
## then draining upward into mana. Drawn entirely with arcs and circles.

## How far the outermost ring travels, in pixels.
var radius: float = 110.0
## How long the rings last, in seconds.
var duration: float = 0.7

var _time: float = 0.0


func _ready() -> void:
	z_index = 10
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


func setup(origin: Vector2) -> void:
	global_position = origin
	CombatFx.burst(get_parent(), origin, CombatFx.BLOOD, 22, 0.6, 90.0, 240.0,
			Vector2.UP, 55.0, 260.0)


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	for i in 2:
		var progress := (_time - i * 0.1) / duration
		if progress <= 0.0 or progress >= 1.0:
			continue
		var alpha := pow(1.0 - progress, 1.4)
		var ring_radius := lerpf(18.0, radius, ease(progress, 0.5))
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48,
				Color(0.72, 0.04, 0.06, alpha * 0.9), lerpf(8.0, 2.0, progress))
		draw_arc(Vector2.ZERO, ring_radius * 1.15, 0.0, TAU, 48,
				Color(0.95, 0.35, 0.2, alpha * 0.35), lerpf(14.0, 3.0, progress))

	var spin := _time * 3.0
	for i in 10:
		var angle := TAU * float(i) / 10.0 + spin
		var inner := radius * (0.38 + 0.05 * sin(_time * 9.0 + i))
		draw_line(Vector2.from_angle(angle) * inner, Vector2.from_angle(angle) * (inner + 18.0),
				Color(0.95, 0.3, 0.2, 0.4), 2.0)

	var glow := 1.0 - clampf(_time / 0.3, 0.0, 1.0)
	if glow > 0.0:
		draw_circle(Vector2.ZERO, 26.0 + 40.0 * glow, Color(0.9, 0.15, 0.1, glow * 0.35))
