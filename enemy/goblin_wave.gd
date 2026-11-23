extends Node2D
## One wave of goblins for the real game: the spawner plus its spawn points.
## The Hero is expected to join group "player" itself; until it does, join it here.


func _ready() -> void:
	var hero := get_parent().get_node_or_null("Player")
	if hero and not hero.is_in_group("player"):
		hero.add_to_group("player")
