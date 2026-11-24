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

var _player: Node


func _ready() -> void:
	_health_bar.texture = HP_TEXTURES[10]
	_mana_bar.texture = MP_TEXTURES[10]
	_damage_button.text = "Take %d Damage" % damage_percent
	_damage_button.pressed.connect(_on_damage_pressed)
	_revive_button.text = "Revive"
	_revive_button.pressed.connect(_on_revive_pressed)
	_mana_button.text = "Add %d Mana" % mana_percent
	_mana_button.pressed.connect(_on_mana_pressed)
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
