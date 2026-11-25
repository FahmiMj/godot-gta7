class_name ChainLightning
extends ChainHex
## A blue-white bolt that leaps between bodies. It reuses ChainHex's targeting
## and damage, but reaches further, hits more bodies and loses less bite per jump.
## Only the draw is replaced, adding forked branches; no sprite is involved.

func _init() -> void:
	damage = 22
	decay = 0.85
	first_range = 340.0
	jump_range = 260.0
	max_targets = 5
	color = Color(0.45, 0.78, 1.0)


func _draw() -> void:
	var alpha := pow(1.0 - clampf(_time / duration, 0.0, 1.0), 1.1)
	if alpha <= 0.0:
		return

	for i in range(1, _points.size()):
		var arc := _jagged(_points[i - 1], _points[i])
		draw_polyline(arc, Color(color.r, color.g, color.b, alpha * 0.25), 14.0, true)
		draw_polyline(arc, Color(color.r, color.g, color.b, alpha * 0.6), 7.0, true)
		draw_polyline(arc, Color(0.95, 0.98, 1.0, alpha), 2.0, true)

		# one forked branch per hop keeps the bolt from looking like a rope
		var middle := arc[arc.size() / 2]
		var fork_end := middle + Vector2.from_angle(randf() * TAU) * 34.0
		draw_polyline(_jagged(middle, fork_end),
				Color(0.8, 0.92, 1.0, alpha * 0.7), 1.5, true)

	for i in range(1, _points.size()):
		draw_circle(_points[i], 7.0 * alpha + 2.0, Color(0.9, 0.97, 1.0, alpha * 0.6))
