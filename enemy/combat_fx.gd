class_name CombatFx
extends RefCounted
## Small shared combat effects: pixel bursts (blood, crumble, sparks, smoke), the heavy
## impact ring and screen shake. Everything here is fire-and-forget and frees itself.

const BLOOD: Color = Color(0.72, 0.04, 0.06)
const SHAKE_META: StringName = &"_fx_shake_serial"

static var _square_texture: Texture2D


## A short spray of 2-pixel blood squares at `pos`, flying away from the attacker.
static func blood(parent: Node, pos: Vector2, away: Vector2 = Vector2.UP) -> void:
	burst(parent, pos, BLOOD, 9, 0.38, 70.0, 170.0, (away + Vector2.UP * 0.6).normalized(), 55.0, 520.0)


## The goblin crumbling into pixels when it dies.
static func crumble(parent: Node, pos: Vector2, color: Color) -> void:
	var p := burst(parent, pos, color, 22, 0.7, 25.0, 110.0, Vector2.UP, 120.0, 260.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(22, 26)


## One-shot burst of square pixel particles that fade out. Returns it for tweaking.
static func burst(parent: Node, pos: Vector2, color: Color, amount: int, life: float,
		v_min: float, v_max: float, direction: Vector2, spread: float, gravity: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.texture = _square()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.direction = direction
	p.spread = spread
	p.gravity = Vector2(0, gravity)
	p.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.z_index = 10
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
	return p


static func _square() -> Texture2D:
	if _square_texture == null:
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_square_texture = ImageTexture.create_from_image(image)
	return _square_texture


## Brief camera shake. It moves the camera's `offset` (the follow script drives its
## position), decays to nothing, and a newer shake replaces an older one, so it can
## never build up into a drift.
static func shake(tree: SceneTree, strength: float, duration: float = 0.25) -> void:
	var camera := tree.root.get_viewport().get_camera_2d()
	if camera == null or strength <= 0.0:
		return
	var serial: int = int(camera.get_meta(SHAKE_META, 0)) + 1
	camera.set_meta(SHAKE_META, serial)
	var tween := camera.create_tween()
	tween.tween_method(func(k: float) -> void:
		if camera.get_meta(SHAKE_META, 0) == serial:
			camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - k),
		0.0, 1.0, duration)
	tween.tween_callback(func() -> void:
		if camera.get_meta(SHAKE_META, 0) == serial:
			camera.offset = Vector2.ZERO)


## Dust and an expanding ring where a heavy attack lands; the ring's edge reaches `radius`.
static func shockwave(parent: Node, pos: Vector2, radius: float) -> void:
	var ring := ShockRing.new()
	ring.radius = radius
	parent.add_child(ring)
	ring.global_position = pos
	burst(parent, pos, Color(0.62, 0.55, 0.45), 26, 0.6, 60.0, 220.0, Vector2.UP, 180.0, 120.0).scale_amount_max = 3.0


## The expanding ground ring of a hammer slam.
class ShockRing extends Node2D:
	var radius: float = 120.0
	var _time: float = 0.0

	func _ready() -> void:
		z_index = 5
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive

	func _process(delta: float) -> void:
		_time += delta
		if _time > 0.4:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_time / 0.4, 0.0, 1.0)
		var r := radius * (0.25 + 0.75 * sqrt(k))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6)) # flattened: it lies on the ground
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.75, 0.4, 0.85 * (1.0 - k)), 6.0 * (1.0 - k) + 2.0)
		draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 48, Color(1.0, 0.5, 0.2, 0.5 * (1.0 - k)), 3.0)
