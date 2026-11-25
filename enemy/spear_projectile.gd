class_name SpearProjectile
extends Area2D
## A thrown spear. It flies in a straight line along the ground, hurts the Hero once on
## contact, and breaks on the Hero, on a wall, or at the end of its range. The spear
## is drawn lifted above its ground position, so it passes over the Hero's body
## while the hit test follows the Hero's feet collision, like the Hero's own fireballs.

const LIFT: float = 64.0
const WOOD: Color = Color(0.45, 0.28, 0.14)
const STEEL: Color = Color(0.82, 0.84, 0.88)
const LENGTH: float = 64.0

var damage: int = 20
var speed: float = 520.0
var max_distance: float = 700.0

var _direction: Vector2 = Vector2.RIGHT
var _travelled: float = 0.0
var _spent: bool = false


## Fire from the current position toward `direction` (a unit vector).
func launch(direction: Vector2) -> void:
	_direction = direction.normalized()
	rotation = _direction.angle()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # the Hero and the walls
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	z_index = 6


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var step := speed * delta
	position += _direction * step
	_travelled += step
	if _travelled >= max_distance:
		_break()


func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	if body.is_in_group("player"):
		if body.has_method("take_damage") and (not ("health" in body) or body.health > 0):
			body.take_damage(damage) # once: the spear is spent below
		_break(true)
	elif not body.is_in_group("enemies"):
		_break() # a wall


func _break(hit_player: bool = false) -> void:
	_spent = true
	set_deferred("monitoring", false)
	var color := Color(1.0, 0.9, 0.7) if hit_player else STEEL
	CombatFx.burst(get_parent(), global_position + Vector2(0, -LIFT * 0.5), color, 8, 0.3, 60.0, 150.0, -_direction, 70.0, 300.0)
	queue_free()


func _draw() -> void:
	# Drawn in local space (pointing +x), lifted above the ground position. Pixel-style:
	# a wooden shaft, a steel head, and a short shadow on the ground.
	draw_set_transform(Vector2(0, -LIFT), 0.0, Vector2.ONE)
	draw_rect(Rect2(-LENGTH * 0.5, -1.5, LENGTH * 0.8, 3.0), WOOD)
	draw_colored_polygon(PackedVector2Array([
		Vector2(LENGTH * 0.3, -4.0), Vector2(LENGTH * 0.5, 0.0), Vector2(LENGTH * 0.3, 4.0)]), STEEL)
	draw_rect(Rect2(-LENGTH * 0.5, -2.0, 6.0, 4.0), Color(0.3, 0.18, 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-LENGTH * 0.3, -1.0, LENGTH * 0.6, 2.0), Color(0, 0, 0, 0.35))
