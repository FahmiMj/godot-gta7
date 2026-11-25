extends SceneTree
## Headless smoke test for the Hero's sprite-free attacks.
##
## Run it with:
##   godot --headless --script res://tools/test_attacks.gd
##
## It spawns the real player and a goblin in an empty arena, fires every attack
## and checks both the plumbing (mana, cooldowns, keybinds) and the damage shapes.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const GOBLIN_SCENE := preload("res://enemy/enemy.tscn")
const DARK_FIRE_SCENE := preload("res://scenes/dark_fire.tscn")
const GRAVITY_WELL := preload("res://scripts/attacks/gravity_well.gd")
const SHOCKWAVE := preload("res://scripts/attacks/shockwave.gd")

const ACTION_NAMES: Array[StringName] = [&"nova", &"lance", &"hex", &"orbs", &"blood_pact",
		&"gravity", &"lightning", &"shockwave"]

var _failures: int = 0
var _arena: Node2D
var _player: Node2D
var _goblin: Node2D


func _initialize() -> void:
	_run()


func _run() -> void:
	_arena = Node2D.new()
	_arena.name = "Arena"
	root.add_child(_arena)

	_player = PLAYER_SCENE.instantiate()
	_arena.add_child(_player)
	_player.global_position = Vector2(400, 300)

	# let the spawn-in animation hand control over
	await create_timer(1.6).timeout
	_check("player finished spawning", not _player._spawning)

	_goblin = GOBLIN_SCENE.instantiate()
	_arena.add_child(_goblin)
	_goblin.global_position = Vector2(500, 300)
	_goblin.max_health = 1000
	_goblin._health = 1000
	_goblin.set_physics_process(false) # stand still and never hit back
	await process_frame

	await _test_keybinds()
	await _test_player_casts()
	await _test_damage_shapes()
	await _test_dark_fire()
	await _test_new_attacks()
	_test_boons()
	await _test_boon_screen()

	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


func _test_keybinds() -> void:
	for action in ACTION_NAMES:
		_check("action '%s' is bound" % action, InputMap.has_action(action))


## Every cast must spend its mana, start its cooldown and refuse a second use.
func _test_player_casts() -> void:
	await _refill()

	var mana_before: int = _player.mana
	_player._cast_eclipse_nova()
	_check("nova spends 25 mana", _player.mana == mana_before - 25)
	_check("nova starts its cooldown", _player._cooldown_left(&"nova") > 0.0)
	var spent: int = _player.mana
	_player._cast_eclipse_nova()
	_check("nova refuses to fire again while cooling", _player.mana == spent)

	await _refill()
	_player._cast_void_lance()
	_check("lance spends 30 mana", _player.mana == 70)
	_check("lance starts its cooldown", _player._cooldown_left(&"lance") > 0.0)

	await _refill()
	_player._cast_chain_hex()
	_check("hex spends 35 mana", _player.mana == 65)
	_check("hex starts its cooldown", _player._cooldown_left(&"hex") > 0.0)

	await _refill()
	_player._cast_shadow_orbs()
	_check("orbs spend 40 mana", _player.mana == 60)
	_check("orbs start their cooldown", _player._cooldown_left(&"orbs") > 0.0)

	await _refill()
	_player._cast_rune_snare(Vector2(500, 300))
	_check("snare spends 20 mana", _player.mana == 80)
	_check("snare starts its cooldown", _player._cooldown_left(&"snare") > 0.0)

	_player.health = 200
	_player.mana = 10
	_player._cast_blood_pact()
	_check("pact trades 25 health", _player.health == 175)
	_check("pact grants 45 mana", _player.mana == 55)
	_player._cast_blood_pact()
	_check("pact refuses to fire again while cooling", _player.health == 175)

	# flash step now has a cooldown of its own, and the HUD reads every attack
	_player.global_position = Vector2(400, 300)
	_player._flash_step()
	_check("flash step starts its cooldown", _player._cooldown_left(&"flash") > 0.0)
	_check("cooldown HUD reports every attack", _player.ability_status().size() == 12)
	await create_timer(_player.flash_step_hide_time + 0.05).timeout
	_player.global_position = Vector2(400, 300)
	_player._flash_step()
	_check("flash step refuses a second dash while cooling", _player.global_position == Vector2(400, 300))

	# clear the field so the damage checks start from a clean slate
	for node in _arena.get_children():
		if node != _player and node != _goblin:
			node.queue_free()
	await process_frame


## Each attack is set up directly so the geometry is deterministic.
func _test_damage_shapes() -> void:
	await _set_goblin_health(1000)

	var nova := EclipseNova.new()
	_arena.add_child(nova)
	nova.setup(Vector2(400, 300))
	await process_frame
	_check("nova deals 35 in its ring", _goblin._health == 965)

	await _set_goblin_health(1000)
	var lance := VoidLance.new()
	_arena.add_child(lance)
	lance.setup(Vector2(400, 300), Vector2.RIGHT)
	await process_frame
	_check("lance deals 45 along its line", _goblin._health == 955)

	await _set_goblin_health(1000)
	var hex := ChainHex.new()
	_arena.add_child(hex)
	hex.setup(Vector2(400, 300), _goblin)
	await process_frame
	_check("hex deals 32 to the first body", _goblin._health == 968)

	await _set_goblin_health(1000)
	var snare := RuneSnare.new()
	_arena.add_child(snare)
	snare.setup(Vector2(500, 300))
	await create_timer(snare.arm_time + 0.15).timeout
	_check("snare deals 40 when it arms", _goblin._health == 960)

	await _set_goblin_health(1000)
	var orbs := ShadowOrbs.new()
	_arena.add_child(orbs)
	orbs.setup(_player, 12, 1.0)
	await create_timer(0.5).timeout
	_check("orbs bite a body inside their orbit", _goblin._health < 1000)

	# every effect is fire-and-forget: give the longest one time to expire
	await create_timer(1.8).timeout
	_check("attacks clean themselves up", _attack_nodes().is_empty())


## E's dark fire locks the body nearest the cursor, homes, then blasts on impact.
func _test_dark_fire() -> void:
	# a second body near the cursor proves the lock ignores distance from the Hero
	var other: Node2D = GOBLIN_SCENE.instantiate()
	_arena.add_child(other)
	other.global_position = Vector2(200, 300)
	other.max_health = 1000
	other._health = 1000
	other.set_physics_process(false)
	await process_frame
	_check("dark fire locks the enemy nearest the cursor",
			_player._dark_fire_lock(Vector2(205, 300)) == other)
	other.queue_free()
	await process_frame

	await _set_goblin_health(1000)
	_goblin.global_position = Vector2(500, 300)
	var fire = DARK_FIRE_SCENE.instantiate()
	_arena.add_child(fire)
	fire.global_position = Vector2(400, 300)
	fire.set_physics_process(false)
	fire.damage = 10
	fire.blast_radius = 136.0
	fire.setup(Vector2(430, 300), _goblin)
	_check("dark fire locks its target", fire._target == _goblin)
	_check("dark fire aims at its lock", fire._direction.dot(Vector2.RIGHT) > 0.99)

	_goblin.global_position = Vector2(500, 200)
	fire._physics_process(0.1)
	_check("dark fire curves toward its lock", fire._direction.y < -0.05)

	# Impact blast: 120 px away is inside the punch's 136 px reach.
	await _set_goblin_health(1000)
	_goblin.global_position = Vector2(600, 300)
	fire.global_position = Vector2(480, 300)
	fire._on_hitbox_body_entered(_goblin)
	await process_frame
	_check("dark fire blast hits inside its radius", _goblin._health == 990)
	_check("dark fire frees itself after impact", not is_instance_valid(fire))

	# ...and a body just outside that reach is untouched.
	await _set_goblin_health(1000)
	_goblin.global_position = Vector2(650, 300)
	var far_fire = DARK_FIRE_SCENE.instantiate()
	_arena.add_child(far_fire)
	far_fire.global_position = Vector2(480, 300)
	far_fire.set_physics_process(false)
	far_fire.damage = 10
	far_fire.blast_radius = 136.0
	far_fire._on_hitbox_body_entered(_goblin)
	await process_frame
	_check("dark fire blast respects its radius", _goblin._health == 1000)


## The boon-unlocked attacks are locked at first, then damage once unlocked.
func _test_new_attacks() -> void:
	_check("gravity starts locked", not _player.has_attack(&"gravity"))
	_check("lightning starts locked", not _player.has_attack(&"lightning"))
	_check("shockwave starts locked", not _player.has_attack(&"shockwave"))
	_check("locked gravity cannot start", not _player._begin_ability(&"gravity", 0, 0.0))

	_player.apply_boon(&"unlock_gravity")
	_player.apply_boon(&"unlock_lightning")
	_player.apply_boon(&"unlock_shockwave")
	_check("boons unlock gravity", _player.has_attack(&"gravity"))
	_check("boons unlock lightning", _player.has_attack(&"lightning"))
	_check("boons unlock shockwave", _player.has_attack(&"shockwave"))

	# the debug button should open every locked attack at once
	_player._unlocked[&"gravity"] = false
	_player.unlock_all_attacks()
	_check("debug unlock opens every attack", _player.has_attack(&"gravity"))

	await _set_goblin_health(1000)
	_goblin.global_position = Vector2(500, 300)
	var well = GRAVITY_WELL.new()
	_arena.add_child(well)
	well.setup(Vector2(500, 300))
	await create_timer(0.5).timeout
	_check("gravity well damages a body in its pull", _goblin._health < 1000)
	well.queue_free()
	await process_frame

	await _set_goblin_health(1000)
	_goblin.global_position = Vector2(500, 300)
	var wave = SHOCKWAVE.new()
	_arena.add_child(wave)
	wave.setup(Vector2(500, 300))
	await process_frame
	_check("shockwave deals 28 in its ring", _goblin._health == 972)

	_player.global_position = Vector2(400, 300)
	_player.mana = _player.max_mana
	_player._cast_shockwave()
	_check("shockwave starts its cooldown", _player._cooldown_left(&"shockwave") > 0.0)

	await _set_goblin_health(1000)
	_goblin.global_position = Vector2(500, 300)
	_player.global_position = Vector2(400, 300)
	_player.mana = _player.max_mana
	_player._cast_chain_lightning()
	_check("chain lightning starts its cooldown", _player._cooldown_left(&"lightning") > 0.0)
	await process_frame
	_check("chain lightning damages the first body", _goblin._health < 1000)


## The between-wave gifts must actually change the Hero's stats.
func _test_boons() -> void:
	var speed_before: float = _player.speed
	_player.apply_boon(&"swiftness")
	_check("swiftness boon raises move speed", _player.speed > speed_before)

	var hp_before: int = _player.max_health
	_player.apply_boon(&"vitality")
	_check("vitality boon raises max health", _player.max_health == hp_before + 20)

	var mana_before: int = _player.max_mana
	_player.apply_boon(&"focus")
	_check("focus boon raises max mana", _player.max_mana == mana_before + 20)

	var damage_before: int = _player.nova_damage
	_player.apply_boon(&"power")
	_check("power boon raises attack damage", _player.nova_damage > damage_before)

	var cooldown_before: float = _player.nova_cooldown
	_player.apply_boon(&"haste")
	_check("haste boon shortens cooldowns", _player.nova_cooldown < cooldown_before)

	_player.apply_boon(&"armor")
	_check("armor boon reduces incoming damage", _player.damage_taken_multiplier < 1.0)


## The boon card must stay inside the viewport and still apply a pick.
func _test_boon_screen() -> void:
	_player.add_to_group("player")
	var point := Node2D.new()
	point.add_to_group("spawn_points")
	_arena.add_child(point)
	var spawner: Node = load("res://enemy/spawner.gd").new()
	_arena.add_child(spawner)
	await process_frame
	spawner.enable_endless()
	_check("endless switch turns on", spawner.endless)

	spawner._offer_boon()
	await process_frame
	await process_frame

	var layer: CanvasLayer = spawner._boon_layer
	var margin: Control = layer.get_child(1) as Control
	var center: Control = margin.get_child(0) as Control
	var panel: Control = center.get_child(0) as Control
	var screen := root.get_visible_rect().size
	_check("boon card fits the viewport width", panel.size.x <= screen.x)
	_check("boon card fits the viewport height", panel.size.y <= screen.y)

	var speed_before: float = _player.speed
	spawner._choose_boon(&"swiftness")
	await process_frame
	await process_frame
	_check("boon card applies the picked gift", _player.speed > speed_before)

	spawner.queue_free()
	point.queue_free()
	await process_frame


func _attack_nodes() -> Array:
	var left: Array = []
	for node in _arena.get_children():
		if node is EclipseNova or node is VoidLance or node is ChainHex \
				or node is RuneSnare or node is ShadowOrbs:
			left.append(node)
	return left


func _set_goblin_health(value: int) -> void:
	_goblin._health = value
	await process_frame


func _refill() -> void:
	_player.mana = _player.max_mana
	await process_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)
