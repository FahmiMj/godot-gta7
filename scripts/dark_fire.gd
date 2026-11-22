extends Node2D
## Dark fire ball. Travels toward a target point, flickering with a purple
## additive glow and a smoky trail, then bursts into embers.

const TEXTURE_SIZE := 48

@export var speed: float = 620.0
@export var max_distance: float = 1400.0

var _direction: Vector2 = Vector2.RIGHT
var _travelled: float = 0.0
var _time: float = 0.0
var _core: Sprite2D

static var _flame_texture: Texture2D


## Soft violet blob with a white-hot centre, generated once and shared.
static func flame_texture() -> Texture2D:
	if _flame_texture != null:
		return _flame_texture

	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(TEXTURE_SIZE) * 2.0 - Vector2.ONE
			var distance := uv.length()
			var edge := 1.0 + 0.18 * sin(uv.x * 9.0 + uv.y * 7.0)
			var alpha := pow(clampf(1.0 - distance / edge, 0.0, 1.0), 2.0)
			var core := clampf(1.0 - distance * 1.7, 0.0, 1.0)
			var color := Color(0.45, 0.08, 0.8).lerp(Color(1.0, 0.9, 1.0), pow(core, 3.0))
			color.a = alpha
			image.set_pixel(x, y, color)
	_flame_texture = ImageTexture.create_from_image(image)
	return _flame_texture


static func additive_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


## A ready-to-use glowing flame sprite; callers own and free it.
static func make_flame_sprite(flame_scale: Vector2) -> Sprite2D:
	var flame := Sprite2D.new()
	flame.texture = flame_texture()
	flame.scale = flame_scale
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	flame.material = additive_material()
	return flame


## Aims the ball at a world-space point.
func setup(target: Vector2) -> void:
	var offset := target - global_position
	_direction = Vector2.RIGHT if offset.length_squared() < 0.01 else offset.normalized()
	rotation = _direction.angle() + PI * 0.5


func _ready() -> void:
	_core = make_flame_sprite(Vector2(0.9, 1.3))
	_core.name = "Core"
	add_child(_core)

	var light := PointLight2D.new()
	light.texture = flame_texture()
	light.color = Color(0.62, 0.28, 1.0)
	light.energy = 1.2
	light.scale = Vector2(3.0, 3.0)
	add_child(light)

	var trail := CPUParticles2D.new()
	trail.texture = flame_texture()
	trail.amount = 20
	trail.lifetime = 0.4
	trail.local_coords = false
	trail.direction = Vector2.LEFT
	trail.spread = 180.0
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 45.0
	trail.scale_amount_min = 0.15
	trail.scale_amount_max = 0.4
	trail.color = Color(0.55, 0.2, 0.95, 0.5)
	trail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	trail.material = additive_material()
	trail.emitting = true
	add_child(trail)


func _physics_process(delta: float) -> void:
	_time += delta
	var step := speed * delta
	position += _direction * step
	_travelled += step
	rotation = _direction.angle() + PI * 0.5

	if _core != null:
		_core.scale = Vector2(0.9, 1.3) * (1.0 + 0.1 * sin(_time * 42.0))

	if _travelled >= max_distance:
		_burst()


func _burst() -> void:
	var burst := CPUParticles2D.new()
	burst.name = "DarkFireBurst"
	burst.texture = flame_texture()
	burst.one_shot = true
	burst.amount = 26
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 70.0
	burst.initial_velocity_max = 230.0
	burst.scale_amount_min = 0.2
	burst.scale_amount_max = 0.5
	burst.color = Color(0.6, 0.25, 1.0, 0.85)
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	burst.material = additive_material()
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.emitting = true
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)
	queue_free()
