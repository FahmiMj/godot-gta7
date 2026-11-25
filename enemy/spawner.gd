extends Node
## Runs the wave sequence: summon an encounter's enemies, fight until every one is
## dead, drop the treasure chest, wait until its reward is collected, count down,
## then start the next encounter. Waves are tracked internally only; the player never
## sees a wave number. What each wave contains, and the stats its
## enemies get, is defined in WAVES below.

signal wave_started(number: int)
signal wave_cleared(number: int)
signal chest_collected(number: int)
signal all_waves_cleared

const GOBLIN: PackedScene = preload("res://enemy/enemy.tscn")
const SPEAR_GOBLIN: PackedScene = preload("res://enemy/spear_goblin.tscn")
const HAMMER_GOBLIN: PackedScene = preload("res://enemy/hammer_goblin.tscn")
const GHOUL: PackedScene = preload("res://enemy/ghoul.tscn")
## The potion in each wave's chest, by wave order.
const POTIONS: Array[Texture2D] = [
	preload("res://assets/portions/wave_1.webp"),
	preload("res://assets/portions/wave_2.webp"),
	preload("res://assets/portions/wave_3.webp"),
]
const SPAWN_EFFECT: Script = preload("res://enemy/spawn_effect.gd")

## One entry per wave, each a list of groups. A group spawns `count` copies of `scene`
## with `stats` set on top of the scene's own defaults (anything left out keeps the
## default). Stats live inside their own wave's entry, so changing a later wave can
## never alter an earlier one.
const WAVES: Array = [
	[
		{"scene": GOBLIN, "count": 3, "stats": {"max_health": 30}, "color": Color(0.6, 0.25, 1.0), "ring_size": 210.0},
	],
	[
		{"scene": SPEAR_GOBLIN, "count": 5, "stats": {"max_health": 15, "attack_damage": 20}, "color": Color(0.6, 0.25, 1.0), "ring_size": 210.0},
	],
	[
		{"scene": HAMMER_GOBLIN, "count": 4, "stats": {"max_health": 60, "attack_damage": 30}, "color": Color(0.6, 0.25, 1.0), "ring_size": 260.0},
		{"scene": GHOUL, "count": 2, "stats": {"max_health": 80}, "color": Color(0.95, 0.2, 0.4), "ring_size": 280.0},
	],
]

@export var treasure_scene: PackedScene
## Distance from a shared marker for the 2nd, 3rd... enemy placed on it.
@export var spawn_spread: float = 120.0
## Quiet pause before an encounter's summoning circles appear (the same length the
## old wave banner used to take, so the progression timing is unchanged).
@export var encounter_delay: float = 2.3
## Length of the summoning animation; enemies become active when it ends.
@export var spawn_duration: float = 1.3
## Seconds shown in the countdown after the chest reward is collected.
@export var next_wave_countdown: int = 5

var current_wave: int = 0

var _alive: int = 0
var _banner: Label
var _countdown: Label


func _ready() -> void:
	_build_hud()
	# Deferred so every spawn point has joined its group first.
	_run_waves.call_deferred()


func _run_waves() -> void:
	if get_tree().get_nodes_in_group("spawn_points").is_empty():
		push_warning("Spawner: no spawn_points, no waves started.")
		return
	for index in WAVES.size():
		current_wave = index + 1
		await get_tree().create_timer(encounter_delay).timeout
		_spawn_wave(WAVES[index])
		wave_started.emit(current_wave)
		await wave_cleared
		await chest_collected # the next wave never starts before the reward is taken
		if index < WAVES.size() - 1:
			await _count_down()
	_banner.text = "ALL WAVES CLEARED!"
	create_tween().tween_property(_banner, "modulate:a", 1.0, 0.6)
	all_waves_cleared.emit()


func _spawn_wave(groups: Array) -> void:
	var points := get_tree().get_nodes_in_group("spawn_points")
	points.shuffle()
	var total := 0
	for group: Dictionary in groups:
		total += group["count"]
	# Each enemy gets its own marker. Only when there are more enemies than markers
	# does one share, and then it starts spawn_spread away.
	var i := 0
	for group: Dictionary in groups:
		for n in group["count"]:
			var point: Node2D = points[i % points.size()]
			var lap := i / points.size()
			var spot := point.global_position + Vector2.RIGHT.rotated(TAU * i / total) * spawn_spread * lap
			_spawn_one(group, spot)
			i += 1


func _spawn_one(group: Dictionary, spot: Vector2) -> void:
	# The circle goes in first so the enemy is drawn on top of it.
	var effect := SPAWN_EFFECT.new() as Node2D
	effect.set("color", group["color"])
	effect.set("size", group["ring_size"])
	effect.set("duration", spawn_duration)
	add_child(effect)
	effect.global_position = spot

	var enemy := (group["scene"] as PackedScene).instantiate() as Node2D
	var stats: Dictionary = group["stats"]
	for key: String in stats:
		enemy.set(key, stats[key]) # before add_child, so _ready sees the wave's values
	add_child(enemy)
	enemy.global_position = spot
	enemy.call("spawn_in", spawn_duration)
	enemy.connect("died", _on_enemy_died.bind(enemy))
	_alive += 1


func _on_enemy_died(_points: int, enemy: Node2D) -> void:
	_alive -= 1
	if _alive > 0:
		return
	# Last enemy of the wave: only now does the chest appear, where it fell.
	if treasure_scene == null:
		wave_cleared.emit(current_wave)
		chest_collected.emit(current_wave)
		return
	var box := treasure_scene.instantiate() as Node2D
	box.set("potion_texture", POTIONS[mini(current_wave, POTIONS.size()) - 1])
	# Spawner is a plain Node, so local position equals world position.
	box.position = enemy.global_position
	box.connect("collected", func() -> void: chest_collected.emit(current_wave))
	# Deferred: the enemy dies mid-physics, where new Area2Ds can't be added yet.
	add_child.call_deferred(box)
	wave_cleared.emit(current_wave)


func _count_down() -> void:
	for seconds in range(next_wave_countdown, 0, -1):
		_countdown.text = "NEXT ENCOUNTER IN: %d" % seconds
		_countdown.modulate.a = 1.0
		await get_tree().create_timer(1.0).timeout
	_countdown.modulate.a = 0.0


# Top-centre, clear of the health and mana bars in the top-left corner and of the Hero.
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_banner = _make_label(layer, 30, 40)
	_countdown = _make_label(layer, 16, 84)


func _make_label(parent: Node, font_size: int, top: float) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = top + font_size * 1.6
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.92, 0.82, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	parent.add_child(label)
	return label
