extends Area2D
## Reward dropped when a batch of enemies is cleared.
## Click the chest with the mouse, from anywhere: it bursts open in a golden glow and a
## healing potion rises out. Click the potion to drink it, which restores the player's
## health to full. Neither click needs the player to be anywhere near.

## Emitted once, when the potion has been drunk.
signal collected

## The potion shown in this chest. The wave director sets it per wave; when left empty
## the potion from the scene (the original health potion) is used.
var potion_texture: Texture2D

const GLOW: Script = preload("res://enemy/spawn_effect.gd")

@onready var _chest_sprite: Sprite2D = $Sprite2D
@onready var _potion: Sprite2D = $Potion
@onready var _prompt: Label = $Prompt
@onready var _chest_click: Area2D = $ChestClick
@onready var _potion_click: Area2D = $PotionClick

var _opened: bool = false
var _taken: bool = false


func _ready() -> void:
	add_to_group("pickups")
	if potion_texture != null:
		# All potion art is drawn on a similar canvas; keep the on-screen size the same.
		_potion.scale *= 2080.0 / potion_texture.get_width()
		_potion.texture = potion_texture
	_chest_click.input_event.connect(_on_click_area_input.bind(&"chest"))
	_potion_click.input_event.connect(_on_click_area_input.bind(&"potion"))
	_update_prompt()


func _on_click_area_input(_viewport: Node, event: InputEvent, _shape: int, target: StringName) -> void:
	if _taken or not _is_left_click(event):
		return
	if target == &"chest" and not _opened:
		_open() # no distance check: the chest opens remotely, and only once
	elif target == &"potion" and _opened:
		_drink_potion()


func _is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _open() -> void:
	_opened = true
	_potion.show()
	_potion_click.get_node("CollisionShape2D").set_deferred("disabled", false)
	_chest_click.get_node("CollisionShape2D").set_deferred("disabled", true)
	_play_open_effect()
	_update_prompt()


func _drink_potion() -> void:
	if not _drink(get_tree().get_first_node_in_group("player") as Node2D):
		return # a dead hero cannot drink; the potion stays
	_taken = true # one potion, one drink
	_potion.hide()
	_potion_click.get_node("CollisionShape2D").set_deferred("disabled", true)
	collected.emit()
	queue_free()


# Restores the player to full health through its own health system. Does nothing
# (and keeps the potion) if the player is dead, since a dead hero must be revived.
func _drink(player: Node2D) -> bool:
	if player == null or not ("health" in player and "max_health" in player) or player.health <= 0:
		return false
	if player.has_method("heal"):
		player.heal(player.max_health - player.health)
	else:
		# The Hero has no heal() yet: set its health and announce it on its own signal
		# so health bars and the HUD update.
		player.health = player.max_health
		player.health_changed.emit(player.health, player.max_health)
	return true


# Chest pops, a golden flash and sparks burst out, and the potion rises from inside.
func _play_open_effect() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var base := _chest_sprite.scale
	var pop := create_tween()
	pop.tween_property(_chest_sprite, "scale", base * 1.12, 0.12)
	pop.tween_property(_chest_sprite, "scale", base, 0.2)

	# A soft golden glow around the chest: swells as it opens, breathes once or twice,
	# then fades away completely.
	var glow := Sprite2D.new()
	glow.texture = GLOW.glow_texture()
	glow.material = additive
	glow.modulate = Color(1.0, 0.78, 0.32, 0.0)
	glow.position = Vector2(0, -10)
	glow.scale = Vector2.ONE * 3.0
	glow.z_index = -1 # behind the chest, so it never hides it
	add_child(glow)
	var light := create_tween().set_parallel(true)
	light.tween_property(glow, "modulate:a", 0.6, 0.25)
	light.tween_property(glow, "scale", Vector2.ONE * 5.0, 0.5).set_ease(Tween.EASE_OUT)
	light.chain().tween_property(glow, "modulate:a", 0.3, 0.45)
	light.chain().tween_property(glow, "modulate:a", 0.45, 0.4)
	light.chain().tween_property(glow, "modulate:a", 0.0, 0.8)
	light.chain().tween_callback(glow.queue_free)

	var sparks := _sparkles(22, 0.7, 0.9, 60.0, 150.0)
	sparks.position = Vector2(0, -8)
	add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(1.2).timeout.connect(sparks.queue_free)
	# a few slow twinkles drifting up while the glow lasts
	var twinkle := _sparkles(12, 1.4, 0.15, 15.0, 45.0)
	twinkle.position = Vector2(0, -20)
	twinkle.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	twinkle.emission_rect_extents = Vector2(40, 18)
	twinkle.gravity = Vector2(0, -25)
	twinkle.scale_amount_max = 0.25
	add_child(twinkle)
	twinkle.emitting = true
	get_tree().create_timer(2.0).timeout.connect(twinkle.queue_free)

	create_tween().tween_property(_potion, "position:y", -60.0, 0.3).from(-14.0).set_ease(Tween.EASE_OUT)


func _sparkles(amount: int, life: float, burst: float, v_min: float, v_max: float) -> CPUParticles2D:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var p := CPUParticles2D.new()
	p.texture = GLOW.glow_texture()
	p.material = additive
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = burst
	p.direction = Vector2.UP
	p.spread = 70.0
	p.gravity = Vector2(0, 90)
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.35
	p.color = Color(1.0, 0.85, 0.4, 0.9)
	return p


func _update_prompt() -> void:
	_prompt.visible = not _taken
	_prompt.text = "Click the potion" if _opened else "Click to open"
	_prompt.reset_size()
	_prompt.position.x = -_prompt.size.x * _prompt.scale.x / 2.0
