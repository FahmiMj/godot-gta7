extends Area2D
## Reward dropped when a batch of enemies is cleared. Heals the player on pickup.

@export var heal_amount: int = 25


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("heal"):
		body.heal(heal_amount)
	# TODO: "new skill" reward once the Hero confirms an upgrade method
	# (proposal: apply_upgrade(upgrade_name: String)).
	queue_free()
