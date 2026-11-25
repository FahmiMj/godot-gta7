class_name RuneSnare
extends Node2D
## A cursed sigil dropped where the cursor points.
##
## It arms for a moment - the ring shrinks and its rune ticks spin - then detonates
## for area damage and a stagger. Everything is drawn: no decal texture, no sprite.
## The shrinking ring doubles as the telegraph, so the player can read the timing.

## Radius of the blast, in pixels.
var radius: float = 120.0
## Health taken from every enemy caught in the blast.
var damage: int = 40
## Seconds between the drop and the detonation.
var arm_time: float = 0.65
## How long the blast ring lingers after detonating.
var blast_time: float = 0.45
## Tint of the sigil.
var color: Color = Color(0.66, 0.34, 1.0)

var _time: float = 0.0
var _detonated: bool = false


func _ready() -> void:
	z_index = 4
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


## Drops the sigil at `origin`; it arms itself and blows on its own timer.
func setup(origin: Vector2) -> void:
	global_position = origin
	CombatFx.burst(get_parent(), origin, color, 10, 0.55, 15.0, 55.0, Vector2.UP, 80.0, -30.0)


func _process(delta: float) -> void:
	_time += delta
	if not _detonated and _time >= arm_time:
		_detonate()
	if _detonated and _time >= arm_time + blast_time:
		queue_free()
		return
	queue_redraw()


func _detonate() -> void:
	_detonated = true
	var tree := get_tree()
	var targets := Combat.hits_in_circle(tree, global_position, radius)
	Combat.damage(targets, damage)
	Combat.stagger(targets, global_position)
	CombatFx.shockwave(get_parent(), global_position, radius)
	CombatFx.burst(get_parent(), global_position, color, 24, 0.5, 70.0, 230.0, Vector2.UP, 180.0, 70.0)
	CombatFx.shake(tree, 8.0, 0.25)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	if not _detonated:
		_draw_arming()
	else:
		_draw_blast()


## The waiting sigil: a steady outer ring, a closing countdown ring and spinning ticks.
func _draw_arming() -> void:
	var progress := clampf(_time / arm_time, 0.0, 1.0)
	var pulse := 0.55 + 0.45 * sin(_time * 18.0)

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.35), 2.0)
	draw_arc(Vector2.ZERO, radius * (1.6 - 0.6 * progress), 0.0, TAU, 64,
			Color(color.r, color.g, color.b, 0.55 + 0.35 * pulse), 4.0)

	var spin := _time * 3.2
	for i in 12:
		var angle := TAU * float(i) / 12.0 + spin
		var inner := radius * (0.86 + 0.05 * sin(_time * 9.0 + i))
		var outer := inner + 14.0
		draw_line(Vector2.from_angle(angle) * inner, Vector2.from_angle(angle) * outer,
				Color(0.9, 0.8, 1.0, 0.5 + 0.3 * pulse), 3.0)

	# a pentagram turning inside the countdown ring
	var star := PackedVector2Array()
	for idx in [0, 2, 4, 1, 3, 0]:
		star.append(Vector2.from_angle(-PI / 2.0 + TAU * float(idx) / 5.0 + spin * 0.35)
				* radius * 0.6)
	draw_polyline(star, Color(0.88, 0.76, 1.0, 0.25 + 0.3 * pulse), 2.0, true)
	draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 40,
			Color(color.r, color.g, color.b, 0.18 + 0.18 * pulse), 1.5)

	# the ground under the sigil darkens as it charges
	draw_circle(Vector2.ZERO, radius * 0.92, Color(0.16, 0.05, 0.28, 0.18 + 0.22 * progress))


## The blast: one ring racing out, a white flash, then nothing.
func _draw_blast() -> void:
	var progress := clampf((_time - arm_time) / blast_time, 0.0, 1.0)
	var alpha := pow(1.0 - progress, 1.4)
	var ring_radius := lerpf(radius * 0.35, radius * 1.25, ease(progress, 0.35))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64,
			Color(color.r, color.g, color.b, alpha * 0.9), lerpf(12.0, 2.0, progress))
	draw_arc(Vector2.ZERO, ring_radius * 0.78, 0.0, TAU, 64,
			Color(0.95, 0.85, 1.0, alpha * 0.5), lerpf(20.0, 5.0, progress))
	for i in 14:
		var angle := TAU * float(i) / 14.0 + progress * 0.6
		var inner := ring_radius * 0.5
		var outer := ring_radius * (1.0 + 0.1 * sin(i * 2.3))
		draw_line(Vector2.from_angle(angle) * inner, Vector2.from_angle(angle) * outer,
				Color(0.92, 0.8, 1.0, alpha * 0.4), 2.0)
	var flash := 1.0 - clampf(progress / 0.3, 0.0, 1.0)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, radius * 0.5 * flash + 20.0, Color(0.85, 0.7, 1.0, flash * 0.4))
