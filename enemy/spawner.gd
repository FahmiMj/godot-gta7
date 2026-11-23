extends Node
## Spawns one batch of enemies at random "spawn_points" markers.

@export var enemy_scene: PackedScene
@export var treasure_scene: PackedScene
@export var enemy_count: int = 3
@export var spawn_spread: float = 24.0

var _alive: int = 0


func _ready() -> void:
	# Deferred so every spawn point has joined its group first.
	spawn_batch.call_deferred()


func spawn_batch() -> void:
	var spawn_points := get_tree().get_nodes_in_group("spawn_points")
	if spawn_points.is_empty() or enemy_scene == null:
		push_warning("Spawner: no spawn_points or no enemy_scene, nothing spawned.")
		return

	for i in enemy_count:
		var point: Node2D = spawn_points.pick_random()
		var enemy := enemy_scene.instantiate() as Enemy
		add_child(enemy)
		# Random offset so enemies sharing a point don't stack exactly.
		enemy.global_position = point.global_position + Vector2(
			randf_range(-spawn_spread, spawn_spread),
			randf_range(-spawn_spread, spawn_spread),
		)
		enemy.died.connect(_on_enemy_died.bind(enemy))
		_alive += 1


func _on_enemy_died(_points: int, enemy: Enemy) -> void:
	_alive -= 1
	if _alive > 0 or treasure_scene == null:
		return
	var box := treasure_scene.instantiate() as Node2D
	# Spawner is a plain Node, so local position equals world position.
	box.position = enemy.global_position
	# Deferred: the enemy dies mid-physics, where new Area2Ds can't be added yet.
	add_child.call_deferred(box)
