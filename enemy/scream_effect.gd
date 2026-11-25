extends Node2D
## Expanding, wobbling shock rings for a ghoul's scream. Add it at the mouth;
## it frees itself once the rings have faded. The outer edge reaches `radius`,
## so the effect also shows how far the scream carries.

const RINGS: int = 3
const RING_DELAY: float = 0.14
const POINTS: int = 72

var radius: float = 250.0
var duration: float = 0.9
var color: Color = Color(0.62, 0.18, 0.95)

var _time: float = 0.0


func _ready() -> void:
	z_index = 20
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration + RING_DELAY * (RINGS - 1):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for i in RINGS:
		var progress := (_time - i * RING_DELAY) / duration
		if progress <= 0.0 or progress >= 1.0:
			continue
		var ring_radius := lerpf(18.0, radius, ease(progress, 0.45))
		var alpha := pow(1.0 - progress, 1.6)
		var points := PackedVector2Array()
		for k in POINTS + 1:
			var angle := TAU * k / POINTS
			# distortion: the ring is never a clean circle
			var wobble := 1.0 + 0.07 * sin(angle * 7.0 + _time * 28.0 + i) + 0.04 * sin(angle * 3.0 - _time * 17.0)
			points.append(Vector2.from_angle(angle) * ring_radius * wobble)
		var tint := color.lerp(Color(1.0, 0.2, 0.35), 0.55 * (1.0 - progress))
		draw_polyline(points, Color(tint.r, tint.g, tint.b, alpha * 0.9), lerpf(7.0, 2.0, progress), true)
		draw_polyline(points, Color(tint.r, tint.g, tint.b, alpha * 0.25), lerpf(18.0, 6.0, progress), true)
	var flash := 1.0 - clampf(_time / 0.35, 0.0, 1.0)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, 30.0 + 40.0 * (1.0 - flash), Color(0.8, 0.3, 1.0, flash * 0.35))
