extends Sprite2D
## Loops the pixel flame spritesheet and adds a thin trail of rising embers.
##
## The sheet's frames are laid out horizontally (hframes), so each torch only
## needs this script and a frame offset to look out of sync with the others.

@export var fps: float = 10.0
@export var ember_count: int = 10

var _time: float = 0.0

static var _ember_texture: ImageTexture
static var _ember_material: CanvasItemMaterial


func _ready() -> void:
	if hframes > 0:
		frame = randi() % hframes
	_time = randf() * (1.0 / maxf(fps, 0.001))
	_spawn_embers()


func _process(delta: float) -> void:
	if fps <= 0.0 or hframes <= 0:
		return
	_time += delta
	var step := 1.0 / fps
	while _time >= step:
		_time -= step
		frame = (frame + 1) % hframes


func _spawn_embers() -> void:
	if ember_count <= 0:
		return

	var embers := CPUParticles2D.new()
	embers.name = "Embers"
	embers.amount = ember_count
	embers.lifetime = 1.6
	embers.preprocess = 1.6
	embers.position = Vector2(0.0, -112.0)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(22.0, 14.0)
	embers.direction = Vector2(0.0, -1.0)
	embers.spread = 30.0
	embers.gravity = Vector2(0.0, -18.0)
	embers.initial_velocity_min = 10.0
	embers.initial_velocity_max = 42.0
	embers.scale_amount_min = 0.35
	embers.scale_amount_max = 0.8
	embers.color = Color(1.0, 0.62, 0.2, 0.85)
	embers.texture = _ember_texture_instance()
	embers.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	embers.material = _ember_material_instance()
	add_child(embers)


static func _ember_texture_instance() -> ImageTexture:
	if _ember_texture == null:
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color(1.0, 1.0, 1.0, 1.0))
		_ember_texture = ImageTexture.create_from_image(image)
	return _ember_texture


static func _ember_material_instance() -> CanvasItemMaterial:
	if _ember_material == null:
		_ember_material = CanvasItemMaterial.new()
		_ember_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _ember_material
