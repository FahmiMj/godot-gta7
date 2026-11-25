class_name VoidLance
extends Node2D
## A piercing beam of void light fired toward the cursor.
##
## It is aimed by rotating the node, then drawn as a thin white core wrapped in a
## fat additive glow, so no texture or sprite is involved. Every enemy standing on
## the line is hit once: the beam does not stop at the first body it finds.

## Length of the beam, in pixels.
var length: float = 520.0
## Width of the damaging part of the beam, in pixels.
var width: float = 34.0
## Health taken from every enemy the beam crosses.
var damage: int = 45
## How long the beam stays visible, in seconds.
var duration: float = 0.22
## Tint of the outer glow.
var color: Color = Color(0.58, 0.32, 1.0)

var _time: float = 0.0
var _impact_points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	z_index = 9
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


## Aims the beam from `origin` along `direction` and burns everything on the line.
func setup(origin: Vector2, direction: Vector2, beam_length: float = -1.0) -> void:
	if beam_length > 0.0:
		length = beam_length
	var aim := direction.normalized()
	global_position = origin
	rotation = aim.angle()

	var tree := get_tree()
	var end := origin + aim * length
	var targets := Combat.hits_along_line(tree, origin, end, width * 0.5)
	for target in targets:
		_impact_points.append(to_local(target.global_position))
	Combat.damage(targets, damage)
	CombatFx.shake(tree, 6.0, 0.18)
	CombatFx.burst(get_parent(), origin, color, 12, 0.3, 120.0, 260.0, aim, 26.0, 0.0)
	for point in _impact_points:
		CombatFx.burst(get_parent(), to_global(point), Color(0.9, 0.8, 1.0),
				8, 0.28, 60.0, 180.0, -aim, 70.0, 0.0)


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_time / duration, 0.0, 1.0)
	var alpha := pow(1.0 - progress, 1.2)
	# a slow widening at the muzzle keeps the beam from looking like a ruler
	var start_x := 10.0 + 30.0 * progress
	var end_x := length

	# a tapered body under the lines, so the beam reads as a lance instead of a ruler
	var half := width * 0.5 * (1.0 - 0.35 * progress)
	draw_colored_polygon(PackedVector2Array([
		Vector2(start_x, -half), Vector2(end_x, -2.0),
		Vector2(end_x, 2.0), Vector2(start_x, half)]),
		Color(color.r, color.g, color.b, alpha * 0.18))

	# outer glow, then the hot core
	draw_line(Vector2(start_x, 0.0), Vector2(end_x, 0.0),
			Color(color.r, color.g, color.b, alpha * 0.45), width * (1.0 - 0.4 * progress))
	draw_line(Vector2(start_x, 0.0), Vector2(end_x, 0.0),
			Color(0.85, 0.7, 1.0, alpha * 0.85), width * 0.38 * (1.0 - 0.3 * progress))
	draw_line(Vector2(start_x, 0.0), Vector2(end_x, 0.0),
			Color(1.0, 0.98, 1.0, alpha), width * 0.14)

	# a hot pulse racing down the core
	var pulse := fmod(_time / duration * 1.8, 1.0)
	draw_circle(Vector2(lerpf(start_x, end_x, pulse), 0.0), 11.0 * alpha,
			Color(1.0, 0.97, 1.0, alpha * 0.6))

	# muzzle flash and the sparks where the beam met a body
	draw_circle(Vector2(start_x, 0.0), width * 0.55 * (1.0 - progress * 0.6),
			Color(0.85, 0.7, 1.0, alpha * 0.6))
	for point in _impact_points:
		var flicker := 0.7 + 0.3 * sin(_time * 60.0)
		draw_circle(point, 14.0 * (1.0 - progress) * flicker,
				Color(0.95, 0.85, 1.0, alpha * 0.5))
		draw_arc(point, 20.0 * (1.0 - progress), 0.0, TAU, 18,
				Color(0.92, 0.82, 1.0, alpha * 0.55), 2.0)
