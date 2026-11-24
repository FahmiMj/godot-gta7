extends CharacterBody2D
## Sandbox stand-in for the Hero. Move with WASD/arrows, Space hits nearby enemies.


func _ready() -> void:
	add_to_group("player")


func _physics_process(_delta: float) -> void:
	velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * 200.0
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < 80.0:
			enemy.take_damage(10)


func take_damage(amount: int) -> void:
	print("player took ", amount)


func heal(amount: int) -> void:
	print("player healed ", amount)
