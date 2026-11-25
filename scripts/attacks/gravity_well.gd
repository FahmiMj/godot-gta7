class_name GravityWell
extends Node2D
## A vortex dropped at the cursor. It drags every enemy inside its radius toward
## the centre while grinding them with damage ticks. Drawn entirely with arcs and
## polylines, so it needs no sprite.

var radius: float = 150.0
var damage: int = 10
var duration: float = 2.2
var tick_interval: float = 0.4
var pull_speed: float = 150.0
var color: Color = Color(0.48, 0.2, 0.9)

var _time: float = 0.0
var _tick_left: float = 0.0


func _ready() -> void:
	z_index = 7
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


## Places the well and staggers everything already inside it.
func setup(origin: Vector2) -> void:
	global_position = origin
	var targets := Combat.hits_in_circle(get_tree(), origin, radius)
	Combat.stagger(targets, origin)
	CombatFx.burst(get_parent(), origin, color, 22, 0.55, 40.0, 170.0,
			Vector2.UP, 180.0, -25.0)
	CombatFx.shake(get_tree(), 4.0, 0.2)


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return

	var targets := Combat.hits_in_circle(get_tree(), global_position, radius)
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = tick_interval
		Combat.damage(targets, damage)

	for enemy in targets:
		if not is_instance_valid(enemy):
			continue
		var to_center: Vector2 = global_position - enemy.global_position
		if to_center.length() > 10.0:
			var direction := to_center.normalized()
			# a little sideways drift turns the pull into a spiral
			enemy.global_position += (direction + direction.orthogonal() * 0.35) * pull_speed * delta
	queue_redraw()


func _draw() -> void:
	var k := clampf(_time / duration, 0.0, 1.0)
	var fade := 1.0 if k < 0.82 else (1.0 - k) / 0.18
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	var spin := _time * 4.0

	for ring in 3:
		var ring_radius := radius * (0.32 + 0.2 * ring) * (1.0 - 0.12 * sin(_time * 5.0 + ring))
		draw_arc(Vector2.ZERO, ring_radius, spin + ring, spin + ring + PI * 1.4, 32,
				Color(color.r, color.g, color.b, 0.35 * fade), 3.0)

	for arm in 5:
		var angle := spin + TAU * float(arm) / 5.0
		var points := PackedVector2Array()
		for step in 12:
			var t := float(step) / 11.0
			points.append(Vector2.from_angle(angle + t * 2.6) * lerpf(radius * 0.12, radius, t))
		draw_polyline(points, Color(0.8, 0.62, 1.0, 0.45 * fade), 3.0, true)

	draw_circle(Vector2.ZERO, 22.0 + 6.0 * sin(_time * 12.0),
			Color(0.08, 0.0, 0.18, 0.65 * fade))
