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
signal boon_chosen(id: StringName)

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
## One is offered after each chest except the last. Every boon stacks.
const BOONS: Array[Dictionary] = [
	{"id": &"power", "name": "Bloodthirst", "text": "All attacks +20% damage"},
	{"id": &"swiftness", "name": "Windstep", "text": "Move 12% faster"},
	{"id": &"vitality", "name": "Iron Heart", "text": "+20 max health, heal 20"},
	{"id": &"focus", "name": "Deep Well", "text": "+20 max mana, restore 20"},
	{"id": &"haste", "name": "Quickening", "text": "All cooldowns 8% shorter"},
	{"id": &"armor", "name": "Stone Skin", "text": "Take 12% less damage"},
	{"id": &"unlock_gravity", "name": "Gravity Well", "text": "Unlock G — drags and damages", "unlock": &"gravity"},
	{"id": &"unlock_lightning", "name": "Chain Lightning", "text": "Unlock X — leaps between foes", "unlock": &"lightning"},
	{"id": &"unlock_shockwave", "name": "Shockwave", "text": "Unlock V — hurls enemies back", "unlock": &"shockwave"},
]

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
## Temporary debug switch: keep cycling the wave list instead of stopping after WAVES.
var endless: bool = false

var _alive: int = 0
var _banner: Label
var _countdown: Label
var _boon_layer: CanvasLayer
var _boon_picked: bool = false
var _run_active: bool = false
var _finished: bool = false


func _ready() -> void:
	add_to_group("wave_spawner")
	_build_hud()
	# Deferred so every spawn point has joined its group first.
	_run_waves.call_deferred()


func _run_waves() -> void:
	if get_tree().get_nodes_in_group("spawn_points").is_empty():
		push_warning("Spawner: no spawn_points, no waves started.")
		return
	_run_active = true
	_finished = false
	_banner.text = ""
	_banner.modulate.a = 0.0
	var index := 0
	while true:
		current_wave += 1
		await get_tree().create_timer(encounter_delay).timeout
		_spawn_wave(WAVES[index])
		wave_started.emit(current_wave)
		await wave_cleared
		await chest_collected # the next wave never starts before the reward is taken
		var last := index == WAVES.size() - 1
		if last and not endless:
			break
		await _offer_boon()
		await _count_down()
		index = 0 if last else index + 1
	_run_active = false
	_finished = true
	_banner.text = "ALL WAVES CLEARED!"
	create_tween().tween_property(_banner, "modulate:a", 1.0, 0.6)
	all_waves_cleared.emit()


## Temporary debug switch: keep cycling the waves forever. If the normal run has
## already ended, this also starts a fresh endless run.
func enable_endless() -> void:
	if endless:
		return
	endless = true
	if _finished and not _run_active:
		_banner.text = ""
		_banner.modulate.a = 0.0
		_run_waves.call_deferred()


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


## Between waves: three random gifts, pick one. The game waits for the choice.
func _offer_boon() -> void:
	_boon_picked = false
	var player := get_tree().get_first_node_in_group("player")
	var unlocks: Array = []
	var stats: Array = []
	for boon: Dictionary in BOONS:
		var unlock: StringName = boon.get("unlock", &"")
		if unlock != &"" and is_instance_valid(player) and player.has_method("has_attack") \
				and player.has_attack(unlock):
			continue # this attack is already unlocked: don't offer it again
		if unlock == &"":
			stats.append(boon)
		else:
			unlocks.append(boon)
	unlocks.shuffle()
	stats.shuffle()
	# Always show a new attack if one is left, then fill the rest with stat boons.
	var choices: Array = []
	if not unlocks.is_empty():
		choices.append(unlocks.pop_front())
	while choices.size() < 3 and not stats.is_empty():
		choices.append(stats.pop_front())
	while choices.size() < 3 and not unlocks.is_empty():
		choices.append(unlocks.pop_front())
	choices.shuffle()

	_boon_layer = CanvasLayer.new()
	_boon_layer.layer = 30
	add_child(_boon_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.05, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_boon_layer.add_child(shade)

	# Margin + centre containers keep the card on screen at any window size.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_boon_layer.add_child(margin)

	var center := CenterContainer.new()
	margin.add_child(center)

	var screen_width := get_viewport().get_visible_rect().size.x
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(maxf(240.0, minf(560.0, screen_width - 32.0)), 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "CHOOSE A BOON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.92, 0.82, 1.0))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "The horde grows. Take one gift."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
	box.add_child(subtitle)

	for boon: Dictionary in choices:
		var button := Button.new()
		button.text = "%s  —  %s" % [boon["name"], boon["text"]]
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_choose_boon.bind(boon["id"]))
		box.add_child(button)

	var chosen: StringName = await boon_chosen
	if is_instance_valid(player) and player.has_method("apply_boon"):
		player.apply_boon(chosen)
	if is_instance_valid(_boon_layer):
		_boon_layer.queue_free()
	_boon_layer = null
	await get_tree().process_frame


func _choose_boon(id: StringName) -> void:
	if _boon_picked:
		return
	_boon_picked = true
	boon_chosen.emit(id)


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
