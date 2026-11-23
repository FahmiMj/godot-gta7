extends Node2D
## Sandbox only: the real Hero has no "player" group yet, so join it at runtime.
## Nothing is saved into the Hero scene.


func _ready() -> void:
	$Arena/Player.add_to_group("player")
