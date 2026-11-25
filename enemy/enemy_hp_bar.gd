class_name EnemyHpBar
extends Node2D
## Health bar floating above an enemy, built from the supplied HP-bar art (a heart bar
## for goblins, a skull bar for ghouls). The fill shrinks with the enemy's health.

const SKINS: Dictionary = {
	&"goblin": ["res://assets/goblin_sprites/hp_goblin_under.png", "res://assets/goblin_sprites/hp_goblin_fill.png", "res://assets/goblin_sprites/hp_goblin_icon.png"],
	&"ghoul": ["res://assets/ghoul_sprites/hp_ghoul_under.png", "res://assets/ghoul_sprites/hp_ghoul_fill.png", "res://assets/ghoul_sprites/hp_ghoul_icon.png"],
}

var bar: TextureProgressBar


## Builds a bar on `enemy`, `height` pixels above its feet. `skin` is &"goblin" or &"ghoul".
static func attach(enemy: Node2D, skin: StringName, max_health: int, height: float) -> EnemyHpBar:
	var hp := EnemyHpBar.new()
	var paths: Array = SKINS[skin]
	hp.bar = TextureProgressBar.new()
	hp.bar.texture_under = load(paths[0])
	hp.bar.texture_progress = load(paths[1])
	hp.bar.min_value = 0
	hp.bar.max_value = max_health
	hp.bar.value = max_health
	hp.bar.step = 0.0
	hp.bar.nine_patch_stretch = false
	hp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var icon := Sprite2D.new()
	icon.texture = load(paths[2])
	var size: Vector2 = hp.bar.texture_under.get_size()
	var total := size.x + icon.texture.get_width() + 3.0
	icon.centered = false
	icon.position = Vector2(-total / 2.0, -size.y / 2.0 + (size.y - icon.texture.get_height()) / 2.0)
	hp.bar.position = Vector2(-total / 2.0 + icon.texture.get_width() + 3.0, -size.y / 2.0)
	hp.add_child(icon)
	hp.add_child(hp.bar)
	hp.scale = Vector2(1.15, 1.15)
	hp.position = Vector2(0, -height)
	hp.z_index = 8
	enemy.add_child(hp)
	return hp


## Shows `health`, clamped so the bar can never go negative or past its maximum.
func set_health(health: int) -> void:
	bar.value = clampi(health, 0, int(bar.max_value))


func get_health() -> float:
	return bar.value
