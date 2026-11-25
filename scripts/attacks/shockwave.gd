class_name Shockwave
extends Node2D
## A close-range blast that damages and hurls enemies away. The ring is flattened
## onto the floor and drawn with arcs and spokes, so no sprite is needed.

var radius: float = 170.0
var damage: int = 28
var duration: float = 0.42
var knockback: float = 380.0
var color: Color = Color(0.6, 0.8, 1.0)

var _time: float = 0.0


func _ready() -> void:
	z_index = 8
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


func setup(origin: Vector2) -> void:
	global_position = origin
	var targets := Combat.hits_in_circle(get_tree(), origin, radius)
	Combat.damage(targets, damage)
	Combat.stagger(targets, origin, knockback)
	CombatFx.shockwave(get_parent(), origin, radius)
	CombatFx.shake(get_tree(), 8.0, 0.25)
	CombatFx.burst(get_parent(), origin, color, 24, 0.5, 80.0, 250.0,
			Vector2.UP, 180.0, 40.0)


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_time / duration, 0.0, 1.0)
	var alpha := pow(1.0 - k, 1.3)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	var ring_radius := lerpf(radius * 0.25, radius, ease(k, 0.35))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64,
			Color(color.r, color.g, color.b, alpha * 0.9), lerpf(12.0, 2.0, k))
	draw_arc(Vector2.ZERO, ring_radius * 0.78, 0.0, TAU, 64,
			Color(0.88, 0.96, 1.0, alpha * 0.5), lerpf(20.0, 4.0, k))
	for i in 16:
		var angle := TAU * float(i) / 16.0
		draw_line(Vector2.from_angle(angle) * ring_radius * 0.55,
				Vector2.from_angle(angle) * ring_radius,
				Color(0.82, 0.93, 1.0, alpha * 0.35), 2.0)
