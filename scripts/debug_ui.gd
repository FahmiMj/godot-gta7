extends CanvasLayer
## Debug HUD: pixel health and mana bars plus damage/revive/mana buttons.

## Fraction of max health removed by one press of the damage button.
@export var damage_percent: int = 10
## Fraction of max mana restored by one press of the mana button.
@export var mana_percent: int = 10

const HP_TEXTURES = [
	preload("res://assets/ui/hp/hp_0.png"),
	preload("res://assets/ui/hp/hp_10.png"),
	preload("res://assets/ui/hp/hp_20.png"),
	preload("res://assets/ui/hp/hp_30.png"),
	preload("res://assets/ui/hp/hp_40.png"),
	preload("res://assets/ui/hp/hp_50.png"),
	preload("res://assets/ui/hp/hp_60.png"),
	preload("res://assets/ui/hp/hp_70.png"),
	preload("res://assets/ui/hp/hp_80.png"),
	preload("res://assets/ui/hp/hp_90.png"),
	preload("res://assets/ui/hp/hp_100.png"),
]

const MP_TEXTURES = [
	preload("res://assets/ui/mp/mp_0.png"),
	preload("res://assets/ui/mp/mp_10.png"),
	preload("res://assets/ui/mp/mp_20.png"),
	preload("res://assets/ui/mp/mp_30.png"),
	preload("res://assets/ui/mp/mp_40.png"),
	preload("res://assets/ui/mp/mp_50.png"),
	preload("res://assets/ui/mp/mp_60.png"),
	preload("res://assets/ui/mp/mp_70.png"),
	preload("res://assets/ui/mp/mp_80.png"),
	preload("res://assets/ui/mp/mp_90.png"),
	preload("res://assets/ui/mp/mp_100.png"),
]

@onready var _health_bar: TextureRect = $HealthBar
@onready var _mana_bar: TextureRect = $ManaBar
@onready var _damage_button: Button = $Panel/VBox/DamageButton
@onready var _revive_button: Button = $Panel/VBox/ReviveButton
@onready var _mana_button: Button = $Panel/VBox/ManaButton
@onready var _endless_button: Button = $Panel/VBox/EndlessButton
@onready var _unlock_all_button: Button = $Panel/VBox/UnlockAllButton

var _player: Node
var _cooldown_rows: Array[Dictionary] = []


func _ready() -> void:
	_health_bar.texture = HP_TEXTURES[10]
	_mana_bar.texture = MP_TEXTURES[10]
	_damage_button.text = "Take %d Damage" % damage_percent
	_damage_button.pressed.connect(_on_damage_pressed)
	_revive_button.text = "Revive"
	_revive_button.pressed.connect(_on_revive_pressed)
	_mana_button.text = "Add %d Mana" % mana_percent
	_mana_button.pressed.connect(_on_mana_pressed)
	_endless_button.text = "Endless Mode"
	_endless_button.pressed.connect(_on_endless_pressed)
	_unlock_all_button.text = "Unlock All Attacks"
	_unlock_all_button.pressed.connect(_on_unlock_all_pressed)
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = get_tree().current_scene.find_child("Player", true, false)
	if _player != null:
		if _player.has_signal("health_changed"):
			_player.health_changed.connect(_on_health_changed)
		if _player.has_signal("mana_changed"):
			_player.mana_changed.connect(_on_mana_changed)
		if "health" in _player and "max_health" in _player:
			_on_health_changed(_player.health, _player.max_health)
		if "mana" in _player and "max_mana" in _player:
			_on_mana_changed(_player.mana, _player.max_mana)
		_build_cooldown_panel()


## Temporary HUD: one row per attack with a fill bar and the seconds left.
func _build_cooldown_panel() -> void:
	if not _player.has_method("ability_status"):
		return

	var panel := PanelContainer.new()
	panel.name = "Cooldowns"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -258.0
	panel.offset_right = -12.0
	panel.offset_top = 12.0
	panel.offset_bottom = 12.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_END
	add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var title := Label.new()
	title.text = "COOLDOWNS"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.82, 0.76, 1.0))
	box.add_child(title)

	var status: Array = _player.ability_status()
	for info in status:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 5)
		box.add_child(row)

		var key := Label.new()
		key.text = String(info["key"])
		key.custom_minimum_size = Vector2(32, 0)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key.add_theme_font_size_override("font_size", 10)
		key.add_theme_color_override("font_color", Color(0.68, 0.62, 0.88))
		row.add_child(key)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(126, 13)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = 1.0
		row.add_child(bar)

		var value := Label.new()
		value.custom_minimum_size = Vector2(40, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.add_theme_font_size_override("font_size", 10)
		row.add_child(value)

		_cooldown_rows.append({"bar": bar, "value": value})


func _process(_delta: float) -> void:
	if _player == null or _cooldown_rows.is_empty():
		return
	var status: Array = _player.ability_status()
	for i in mini(status.size(), _cooldown_rows.size()):
		var info: Dictionary = status[i]
		var row: Dictionary = _cooldown_rows[i]
		var bar: ProgressBar = row["bar"]
		var value: Label = row["value"]
		if bool(info.get("locked", false)):
			bar.value = 0.0
			value.text = "LOCKED"
			value.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52))
			continue
		var left: float = info["left"]
		var total: float = maxf(float(info["total"]), 0.001)
		bar.value = clampf(1.0 - left / total, 0.0, 1.0)
		if left > 0.05:
			value.text = "%.1f" % left
			value.add_theme_color_override("font_color", Color(0.62, 0.62, 0.72))
		else:
			value.text = "READY"
			value.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7))


## Temporary debug: keep the wave loop cycling instead of ending after wave 3.
func _on_endless_pressed() -> void:
	var spawner := get_tree().get_first_node_in_group("wave_spawner")
	if spawner == null or not spawner.has_method("enable_endless"):
		return
	spawner.enable_endless()
	_endless_button.text = "Endless: ON"
	_endless_button.disabled = true


## Temporary debug: skip the boon grind and open every locked attack.
func _on_unlock_all_pressed() -> void:
	if _player == null or not _player.has_method("unlock_all_attacks"):
		return
	_player.unlock_all_attacks()
	_unlock_all_button.text = "All Attacks Unlocked"
	_unlock_all_button.disabled = true


func _on_damage_pressed() -> void:
	if _player != null and _player.has_method("take_damage"):
		var max_hp: int = int(_player.get("max_health"))
		var amount: int = maxi(1, int(round(float(max_hp) * float(damage_percent) / 100.0)))
		_player.take_damage(amount)


func _on_revive_pressed() -> void:
	if _player != null and _player.has_method("revive"):
		_player.revive()


func _on_mana_pressed() -> void:
	if _player != null and _player.has_method("restore_mana"):
		var max_mp: int = int(_player.get("max_mana"))
		var amount: int = maxi(1, int(round(float(max_mp) * float(mana_percent) / 100.0)))
		_player.restore_mana(amount)


func _on_health_changed(current: int, maximum: int) -> void:
	_health_bar.texture = HP_TEXTURES[_bar_step(current, maximum)]
	_damage_button.disabled = current <= 0
	_revive_button.disabled = current > 0


func _on_mana_changed(current: int, maximum: int) -> void:
	_mana_bar.texture = MP_TEXTURES[_bar_step(current, maximum)]
	_mana_button.disabled = current >= maximum


## Maps a value to its 0-10 texture index, snapped up to the nearest tenth.
static func _bar_step(current: int, maximum: int) -> int:
	if maximum <= 0 or current <= 0:
		return 0
	return clampi(int((current * 10 + maximum - 1) / maximum), 0, 10)
