extends CanvasLayer
## Temporary debug HUD: shows health and damage/revive buttons.

@export var damage_amount: int = 50

@onready var _label: Label = $Panel/VBox/HealthLabel
@onready var _damage_button: Button = $Panel/VBox/DamageButton
@onready var _revive_button: Button = $Panel/VBox/ReviveButton

var _player: Node


func _ready() -> void:
	_damage_button.text = "Take %d Damage" % damage_amount
	_damage_button.pressed.connect(_on_damage_pressed)
	_revive_button.text = "Revive"
	_revive_button.pressed.connect(_on_revive_pressed)
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = get_tree().current_scene.find_child("Player", true, false)
	if _player != null:
		if _player.has_signal("health_changed"):
			_player.health_changed.connect(_on_health_changed)
		if "health" in _player and "max_health" in _player:
			_on_health_changed(_player.health, _player.max_health)


func _on_damage_pressed() -> void:
	if _player != null and _player.has_method("take_damage"):
		_player.take_damage(damage_amount)


func _on_revive_pressed() -> void:
	if _player != null and _player.has_method("revive"):
		_player.revive()


func _on_health_changed(current: int, maximum: int) -> void:
	_label.text = "HP: %d / %d" % [current, maximum]
	_damage_button.disabled = current <= 0
	_revive_button.disabled = current > 0
