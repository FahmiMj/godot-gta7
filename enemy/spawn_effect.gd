extends Node2D
## Summoning circle shown where an enemy spawns. It reuses the arena's own summoning
## ring texture: the circle opens and spins, sparks rise as the enemy materialises,
## then it fades. Purely visual: it never creates or moves an enemy.

const RING_TEXTURE: Texture2D = preload("res://assets/summon_ring.png")

var color: Color = Color(0.6, 0.25, 1.0)
var duration: float = 1.3
## Diameter of the circle in pixels.
var size: float = 210.0


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var ring := Sprite2D.new()
	ring.texture = RING_TEXTURE
	ring.material = additive
	ring.modulate = Color(color.r, color.g, color.b, 0.0)
	ring.scale = Vector2.ONE * size / RING_TEXTURE.get_width() * 0.2
	add_child(ring)

	var open_scale := Vector2.ONE * size / RING_TEXTURE.get_width()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", open_scale, duration * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(ring, "modulate:a", 0.95, duration * 0.4)
	tween.tween_property(ring, "rotation", PI, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration * 0.25).set_delay(duration * 0.75)
	tween.tween_property(ring, "scale", open_scale * 1.15, duration * 0.25).set_delay(duration * 0.75)

	var sparks := CPUParticles2D.new()
	sparks.texture = glow_texture()
	sparks.material = additive
	sparks.one_shot = true
	sparks.emitting = false
	sparks.amount = 28
	sparks.lifetime = 0.8
	sparks.explosiveness = 0.6
	sparks.direction = Vector2.UP
	sparks.spread = 50.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 50.0
	sparks.initial_velocity_max = 140.0
	sparks.scale_amount_min = 0.25
	sparks.scale_amount_max = 0.6
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = size * 0.3
	sparks.color = Color(color.r, color.g, color.b, 0.9)
	add_child(sparks)
	get_tree().create_timer(duration * 0.35).timeout.connect(func() -> void: sparks.emitting = true)

	get_tree().create_timer(duration + 0.9).timeout.connect(queue_free)


static func glow_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture
