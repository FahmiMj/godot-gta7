extends Area2D
## Reward dropped when a batch of enemies is cleared.
## Stand next to it and press O: the chest opens and a healing potion appears.
## Press O again to drink it, which restores the player's health to full.

@onready var _potion: Sprite2D = $Potion
@onready var _prompt: Label = $Prompt

var _player: Node2D # the player currently within reach
var _opened: bool = false
var _taken: bool = false


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_O:
		interact()


func interact() -> void:
	if _player == null or _taken:
		return
	if not _opened:
		_opened = true
		_potion.show()
		create_tween().tween_property(_potion, "position:y", -50.0, 0.2).from(-36.0)
	elif _drink(_player):
		_taken = true # one potion, one drink
		_potion.hide()
		queue_free()
	_update_prompt()


# Restores the player to full health through its own health system. Does nothing
# (and keeps the potion) if the player is dead, since a dead hero must be revived.
func _drink(player: Node2D) -> bool:
	if not ("health" in player and "max_health" in player) or player.health <= 0:
		return false
	if player.has_method("heal"):
		player.heal(player.max_health - player.health)
	else:
		# The Hero has no heal() yet: set its health and announce it on its own signal
		# so health bars and the HUD update.
		player.health = player.max_health
		player.health_changed.emit(player.health, player.max_health)
	return true


func _update_prompt() -> void:
	_prompt.visible = _player != null and not _taken
	_prompt.text = "[O] Take potion" if _opened else "[O] Open chest"
	_prompt.reset_size()
	_prompt.position.x = -_prompt.size.x * _prompt.scale.x / 2.0


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body
		_update_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		_update_prompt()
