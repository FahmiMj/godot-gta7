class_name ShadowOrbs
extends Node2D
## Three orbs of shadow that circle the Hero and bite whatever they sweep through.
##
## The orbs are pure `_draw` circles - a wide dim halo, a solid body and a hot core -
## so they need no sprite, and they orbit the caster instead of the world. Each enemy
## is only hurt once per hit_interval, so a body parked in the ring takes steady
## ticks rather than one hit per frame.

## How many orbs orbit the caster.
var count: int = 3
## Orbit radius around the caster, in pixels.
var orbit_radius: float = 78.0
## Radians per second the ring turns.
var spin: float = 2.4
## How long the orbs last, in seconds.
var duration: float = 6.0
## Health taken by one orb touching a body.
var damage: int = 12
## Seconds before the same enemy can be hit again by the same orb.
var hit_interval: float = 0.35
## How close a body must come to an orb to be hit, in pixels.
var hit_radius: float = 42.0
## The orbs float above the caster's feet by this much.
var lift: Vector2 = Vector2(0, -44)
## Tint of the orbs.
var color: Color = Color(0.6, 0.3, 1.0)

var _caster: Node2D
var _time: float = 0.0
var _angle: float = 0.0
## enemy -> seconds left before that enemy can be hit again
var _lockouts: Dictionary = {}


func _ready() -> void:
	z_index = 11
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


## Ties the orbs to the node they should follow and starts their life timer.
func setup(caster: Node2D, orb_damage: int = -1, orb_duration: float = -1.0) -> void:
	_caster = caster
	if orb_damage >= 0:
		damage = orb_damage
	if orb_duration > 0.0:
		duration = orb_duration
	if is_instance_valid(_caster):
		global_position = _caster.global_position


func _process(delta: float) -> void:
	if not is_instance_valid(_caster):
		queue_free()
		return

	_time += delta
	if _time >= duration:
		_expire()
		return

	global_position = _caster.global_position
	_angle += spin * delta
	_tick_lockouts(delta)
	_sweep()
	queue_redraw()


func _tick_lockouts(delta: float) -> void:
	for enemy in _lockouts.keys():
		_lockouts[enemy] -= delta
		if _lockouts[enemy] <= 0.0:
			_lockouts.erase(enemy)


## Hurts every body an orb is currently touching, once per hit_interval.
func _sweep() -> void:
	var tree := get_tree()
	var bodies := Combat.enemies(tree)
	for i in count:
		var orb := _orb_position(i)
		for enemy in bodies:
			if _lockouts.has(enemy):
				continue
			if enemy.global_position.distance_to(orb) > hit_radius:
				continue
			Combat.damage([enemy], damage)
			CombatFx.burst(get_parent(), enemy.global_position, color, 6, 0.25, 30.0, 110.0,
					Vector2.UP, 90.0, 0.0)
			_lockouts[enemy] = hit_interval


func _orb_position(index: int) -> Vector2:
	var angle := _angle + TAU * float(index) / float(maxi(count, 1))
	return global_position + lift + Vector2.from_angle(angle) * orbit_radius


func _expire() -> void:
	for i in count:
		CombatFx.burst(get_parent(), _orb_position(i), color, 10, 0.35, 40.0, 140.0,
				Vector2.UP, 180.0, 30.0)
	queue_free()


func _draw() -> void:
	var fade := 1.0
	# ease out over the last half second so the orbs do not vanish mid-swing
	var remaining := duration - _time
	if remaining < 0.5:
		fade = clampf(remaining / 0.5, 0.0, 1.0)

	# a faint ring on the floor shows the orbit the orbs travel
	draw_arc(lift, orbit_radius, 0.0, TAU, 48,
			Color(color.r, color.g, color.b, 0.12 * fade), 2.0)

	for i in count:
		var orb := _orb_position(i) - global_position
		var pulse := 1.0 + 0.12 * sin(_time * 9.0 + i * 2.1)

		# trailing smudge behind the orbit
		var behind := orb - Vector2.from_angle(_angle + TAU * float(i) / float(maxi(count, 1))) * 16.0
		draw_line(behind, orb, Color(color.r, color.g, color.b, 0.25 * fade), 10.0)
		for j in 2:
			var tail := lift + Vector2.from_angle(_angle + TAU * float(i) / float(maxi(count, 1))
					- 0.22 * float(j + 1)) * orbit_radius
			draw_circle(tail, 7.0 - 2.0 * j, Color(color.r, color.g, color.b, (0.16 - 0.05 * j) * fade))

		draw_circle(orb, 26.0 * pulse, Color(color.r, color.g, color.b, 0.18 * fade))
		draw_circle(orb, 13.0 * pulse, Color(color.r, color.g, color.b, 0.75 * fade))
		draw_circle(orb, 6.0 * pulse, Color(0.95, 0.9, 1.0, 0.9 * fade))
