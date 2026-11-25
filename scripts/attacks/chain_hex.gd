class_name ChainHex
extends Node2D
## A hex that leaps from body to body.
##
## The first target is chosen by the caller (the nearest enemy to the Hero), then
## the curse jumps to the closest enemy it has not touched yet, losing bite with
## every jump. The lightning is a jagged polyline rebuilt every frame, so it
## crackles without any sprite or particle work.

## Health taken by the first body the hex lands on.
var damage: int = 32
## Each further jump multiplies the damage by this factor.
var decay: float = 0.75
## How far the first body may be from the Hero.
var first_range: float = 380.0
## How far the hex can jump between bodies.
var jump_range: float = 240.0
## Maximum number of bodies, including the first.
var max_targets: int = 4
## How long the arcs stay visible, in seconds.
var duration: float = 0.3
## Tint of the arcs.
var color: Color = Color(0.7, 0.35, 1.0)

var _time: float = 0.0
## Chain nodes in local space; index 0 is the caster's hand.
var _points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	z_index = 12
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


## Starts the chain at `first` (already picked by the player) and applies its damage.
func setup(origin: Vector2, first: Node2D) -> void:
	global_position = origin
	_points.append(Vector2.ZERO)

	var tree := get_tree()
	var visited: Array = []
	var current: Node2D = first
	var bite := damage
	var count := 0

	while current != null and count < max_targets:
		var world_point := current.global_position
		_points.append(to_local(world_point))
		Combat.damage([current], bite)
		CombatFx.burst(get_parent(), world_point, color, 10, 0.3, 60.0, 170.0, Vector2.UP, 120.0, 40.0)
		visited.append(current)
		count += 1
		bite = int(round(float(bite) * decay))
		current = Combat.nearest(tree, world_point, jump_range, visited)

	CombatFx.shake(tree, 5.0, 0.2)


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := pow(1.0 - clampf(_time / duration, 0.0, 1.0), 1.1)
	if alpha <= 0.0:
		return

	for i in range(1, _points.size()):
		var arc := _jagged(_points[i - 1], _points[i])
		draw_polyline(arc, Color(color.r, color.g, color.b, alpha * 0.22), 13.0, true)
		draw_polyline(arc, Color(color.r, color.g, color.b, alpha * 0.55), 7.0, true)
		draw_polyline(arc, Color(0.95, 0.9, 1.0, alpha), 2.0, true)

	for i in range(1, _points.size()):
		draw_circle(_points[i], 9.0 * alpha + 3.0, Color(0.9, 0.8, 1.0, alpha * 0.5))
		var pulse := 1.0 + 0.18 * sin(_time * 26.0 + i * 1.7)
		draw_arc(_points[i], 22.0 * pulse, 0.0, TAU, 20,
				Color(color.r, color.g, color.b, alpha * 0.55), 2.0)
		draw_arc(_points[i], 13.0 * pulse, _time * 8.0, _time * 8.0 + PI * 1.4, 14,
				Color(1.0, 0.92, 1.0, alpha * 0.8), 2.0)


## A zig-zag between two points, re-randomised every frame so the arc crackles.
func _jagged(from: Vector2, to: Vector2) -> PackedVector2Array:
	const STEPS: int = 9
	var points := PackedVector2Array()
	var span := to - from
	var normal := span.normalized().orthogonal()
	for i in STEPS + 1:
		var t := float(i) / float(STEPS)
		# no jitter at the ends: the arc must start and end exactly on the bodies
		var envelope := sin(t * PI)
		var offset := randf_range(-1.0, 1.0) * 14.0 * envelope
		points.append(from + span * t + normal * offset)
	return points
