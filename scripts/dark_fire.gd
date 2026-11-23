extends Node2D
## The dark fire ball thrown by the player.
##
## The ball itself is the mage's own fire art from the attack sheet, wrapped in
## a warm additive glow, trailing embers, and bursting when it has flown far
## enough.

const BALL_TEXTURE := preload("res://assets/sprites/dark_fire_ball.png")
const CORE_SCALE := 0.5
const GLOW_SIZE := 32

@export var speed: float = 620.0
@export var max_distance: float = 1400.0
## Health taken from each enemy the ball passes through (once per enemy).
@export var damage: int = 10

var _direction: Vector2 = Vector2.RIGHT
var _travelled: float = 0.0
var _time: float = 0.0
var _core: Sprite2D
var _already_hit: Array[Node2D] = []

static var _glow_texture: Texture2D


## Soft purple-white ember used for the halo, light and particles.
static func glow_texture() -> Texture2D:
	if _glow_texture != null:
		return _glow_texture

	var image := Image.create(GLOW_SIZE, GLOW_SIZE, false, Image.FORMAT_RGBA8)
	for y in GLOW_SIZE:
		for x in GLOW_SIZE:
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(GLOW_SIZE) * 2.0 - Vector2.ONE
			var distance := uv.length()
			var alpha := pow(clampf(1.0 - distance, 0.0, 1.0), 2.2)
			var hot := pow(clampf(1.0 - distance * 2.0, 0.0, 1.0), 3.0)
			var color := Color(0.55, 0.2, 1.0).lerp(Color(0.95, 0.85, 1.0), hot)
			color.a = alpha
			image.set_pixel(x, y, color)
	_glow_texture = ImageTexture.create_from_image(image)
	return _glow_texture


static func additive_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


## Aims the ball at a world-space point.
func setup(target: Vector2) -> void:
	var offset := target - global_position
	_direction = Vector2.RIGHT if offset.length_squared() < 0.01 else offset.normalized()
	rotation = _direction.angle()


func _ready() -> void:
	$HitBox.body_entered.connect(_on_hitbox_body_entered)

	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.texture = glow_texture()
	glow.scale = Vector2(2.6, 2.6)
	glow.modulate = Color(0.7, 0.45, 1.0, 0.8)
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.material = additive_material()
	add_child(glow)

	_core = Sprite2D.new()
	_core.name = "Core"
	_core.texture = BALL_TEXTURE
	_core.scale = Vector2(CORE_SCALE, CORE_SCALE)
	_core.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_core)

	var light := PointLight2D.new()
	light.texture = glow_texture()
	light.color = Color(0.65, 0.35, 1.0)
	light.energy = 1.4
	light.scale = Vector2(3.5, 3.5)
	add_child(light)

	var trail := CPUParticles2D.new()
	trail.name = "Trail"
	trail.texture = glow_texture()
	trail.amount = 24
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.direction = Vector2.LEFT
	trail.spread = 30.0
	trail.initial_velocity_min = 20.0
	trail.initial_velocity_max = 70.0
	trail.scale_amount_min = 0.2
	trail.scale_amount_max = 0.45
	trail.color = Color(0.7, 0.35, 1.0, 0.7)
	trail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	trail.material = additive_material()
	trail.emitting = true
	add_child(trail)


func _physics_process(delta: float) -> void:
	_time += delta
	var step := speed * delta
	position += _direction * step
	_travelled += step
	rotation = _direction.angle()

	if _core != null:
		_core.scale = Vector2(CORE_SCALE, CORE_SCALE) * (1.0 + 0.06 * sin(_time * 34.0))

	if _travelled >= max_distance:
		_burst()


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body in _already_hit or not body.has_method("take_damage"):
		return
	_already_hit.append(body)
	body.take_damage(damage)


func _burst() -> void:
	var burst := CPUParticles2D.new()
	burst.name = "DarkFireBurst"
	burst.texture = glow_texture()
	burst.one_shot = true
	burst.amount = 28
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 70.0
	burst.initial_velocity_max = 230.0
	burst.scale_amount_min = 0.2
	burst.scale_amount_max = 0.5
	burst.color = Color(0.75, 0.4, 1.0, 0.9)
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	burst.material = additive_material()
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.emitting = true
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)
	queue_free()
