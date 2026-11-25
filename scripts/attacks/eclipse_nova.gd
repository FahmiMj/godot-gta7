class_name EclipseNova
extends Node2D
## A ring of dark force bursts out around the caster.
##
## Pure geometry: three flattened rings race outward over the ground, an additive
## core flash lights the feet, and the damage lands the moment it is set up. The
## rings are drawn flattened (scale.y < 1) so they read as lying on the floor, the
## same trick the hammer's ShockRing uses.

## Radius of the damaging ring, in pixels.
var radius: float = 190.0
## Health taken from every enemy inside the ring.
var damage: int = 35
## How long the rings take to fade, in seconds.
var duration: float = 0.55
## Tint of the rings; the core flash is a lighter version of it.
var color: Color = Color(0.62, 0.3, 1.0)

var _time: float = 0.0


func _ready() -> void:
	z_index = 8
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


## Places the nova and lets it go: damage first, then the show.
func setup(origin: Vector2) -> void:
	global_position = origin
	var tree := get_tree()
	var targets := Combat.hits_in_circle(tree, origin, radius)
	Combat.damage(targets, damage)
	Combat.stagger(targets, origin)
	CombatFx.shockwave(get_parent(), origin, radius)
	CombatFx.shake(tree, 10.0, 0.3)
	CombatFx.burst(get_parent(), origin, color, 30, 0.55, 80.0, 260.0, Vector2.UP, 180.0, 60.0)
	CombatFx.burst(get_parent(), origin, Color(0.95, 0.82, 1.0), 14, 0.7, 30.0, 130.0,
			Vector2.UP, 45.0, -35.0)


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	for i in 3:
		var progress := (_time - i * 0.06) / duration
		if progress <= 0.0 or progress >= 1.0:
			continue
		var ring_radius := lerpf(24.0, radius, ease(progress, 0.4))
		var alpha := pow(1.0 - progress, 1.5)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64,
				Color(color.r, color.g, color.b, alpha * 0.9), lerpf(10.0, 2.0, progress))
		draw_arc(Vector2.ZERO, ring_radius * 0.82, 0.0, TAU, 64,
				Color(0.92, 0.78, 1.0, alpha * 0.45), lerpf(18.0, 4.0, progress))
		for spoke in 12:
			var angle := TAU * float(spoke) / 12.0 + _time * 2.2
			var inner := ring_radius * 0.58
			draw_line(Vector2.from_angle(angle) * inner, Vector2.from_angle(angle) * ring_radius,
					Color(color.r, color.g, color.b, alpha * 0.3), 2.0)
	var pit := 1.0 - clampf(_time / 0.22, 0.0, 1.0)
	if pit > 0.0:
		draw_circle(Vector2.ZERO, 42.0 * pit, Color(0.18, 0.02, 0.32, 0.55 * pit))
	var flash := 1.0 - clampf(_time / 0.18, 0.0, 1.0)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, 30.0 + 60.0 * flash, Color(0.72, 0.42, 1.0, flash * 0.35))
