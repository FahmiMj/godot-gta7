extends CharacterBody2D
## Top-down 4-direction player controller.
##
## Animations are named "<state>_<facing>", e.g. walk_left / idle_up.
## The sprite sheet has 5 rows: down, up, left, right, idle.
## Q flash steps forward, E locks the enemy nearest the cursor and hurls homing
## dark fire that explodes on impact, left click turns and lunges a punch toward
## the cursor.

const TRAIL_SHADER := preload("res://assets/shaders/flash_step_trail.gdshader")
const DARK_FIRE_SCENE := preload("res://scenes/dark_fire.tscn")

## Sprite-free attacks. Each is a Node2D that draws itself, so none of them needs
## a new sprite sheet: the Hero only ever reuses its existing poses.
const ECLIPSE_NOVA := preload("res://scripts/attacks/eclipse_nova.gd")
const VOID_LANCE := preload("res://scripts/attacks/void_lance.gd")
const CHAIN_HEX := preload("res://scripts/attacks/chain_hex.gd")
const RUNE_SNARE := preload("res://scripts/attacks/rune_snare.gd")
const SHADOW_ORBS := preload("res://scripts/attacks/shadow_orbs.gd")
const BLOOD_PACT_FX := preload("res://scripts/attacks/blood_pact_fx.gd")
const GRAVITY_WELL := preload("res://scripts/attacks/gravity_well.gd")
const CHAIN_LIGHTNING := preload("res://scripts/attacks/chain_lightning.gd")
const SHOCKWAVE := preload("res://scripts/attacks/shockwave.gd")

## Attacks listed in the cooldown HUD, in display order.
const ABILITY_INFO: Array[Dictionary] = [
	{"id": &"melee", "label": "Punch", "key": "LMB"},
	{"id": &"attack", "label": "Dark Fire", "key": "E"},
	{"id": &"flash", "label": "Flash Step", "key": "Q"},
	{"id": &"nova", "label": "Eclipse Nova", "key": "C"},
	{"id": &"lance", "label": "Void Lance", "key": "R"},
	{"id": &"hex", "label": "Chain Hex", "key": "F"},
	{"id": &"snare", "label": "Rune Snare", "key": "RMB"},
	{"id": &"orbs", "label": "Shadow Orbs", "key": "T"},
	{"id": &"gravity", "label": "Gravity Well", "key": "G"},
	{"id": &"lightning", "label": "Chain Lightning", "key": "X"},
	{"id": &"shockwave", "label": "Shockwave", "key": "V"},
	{"id": &"pact", "label": "Blood Pact", "key": "H"},
]

## Tint used for the brief red flash when the player is hit.
const HIT_FLASH := Color(1.8, 0.3, 0.3)

## The cast animation faces right, so a leftward throw only flips the sprite.
const HAND_OFFSET := Vector2(64.0, -71.0)
## Physics layer the arena walls sit on. Dashes look only at walls, so they still
## pass through enemies (flash step damages whatever it sweeps through).
const WALL_MASK: int = 1
## How far from the cursor dark fire looks for a body to lock onto, in pixels.
const DARK_FIRE_LOCK_RANGE: float = 4096.0

@export var speed: float = 400.0
@export var max_health: int = 200
@export var max_mana: int = 100
## Fraction of incoming damage that actually lands. Boons can lower it.
@export var damage_taken_multiplier: float = 1.0
## Mana spent by one dark fire charge.
@export var mana_cost: int = 30
## Health taken from each enemy the dark fire ball hits.
@export var dark_fire_damage: int = 10
## Seconds without taking damage before a health regen tick.
@export var health_regen_interval: float = 10.0
## Percent of max health restored per regen tick.
@export var health_regen_percent: int = 10
## Seconds between passive mana regen ticks.
@export var mana_regen_interval: float = 4.0
## Percent of max mana restored per regen tick.
@export var mana_regen_percent: int = 10
## How far a flash step teleports, in pixels.
@export var flash_step_distance: float = 300.0
## How long the sprite stays invisible mid-flash-step, in seconds.
@export var flash_step_hide_time: float = 0.06
## How many white afterimages are left along the path.
@export var flash_step_trail_count: int = 4
## How long each afterimage takes to fade out, in seconds.
@export var flash_step_trail_fade: float = 0.3
## Time between dark fire throws, in seconds.
@export var attack_cooldown: float = 1.0
## Time between melee swings, in seconds.
@export var melee_cooldown: float = 0.45
## Health taken from each enemy the punch reaches.
@export var melee_damage: int = 25
## How far the punch reaches in front of the player, in pixels.
@export var melee_range: float = 136.0
## How far the character lunges forward when swinging, in pixels.
@export var melee_lunge_distance: float = 40.0
## How long the lunge takes, in seconds.
@export var melee_lunge_time: float = 0.15
## Health taken from each enemy the flash step passes through.
@export var flash_damage: int = 15
## How close to the dash line an enemy must be to be hit, in pixels.
@export var flash_hit_radius: float = 44.0
## Time between flash steps, in seconds.
@export var flash_step_cooldown: float = 1.2

# --- Eclipse Nova: a ring of force around the Hero (C) ---
@export var nova_mana_cost: int = 25
@export var nova_cooldown: float = 3.5
@export var nova_damage: int = 35
@export var nova_radius: float = 190.0

# --- Void Lance: a piercing beam toward the cursor (R) ---
@export var lance_mana_cost: int = 30
@export var lance_cooldown: float = 2.5
@export var lance_damage: int = 45
@export var lance_range: float = 520.0
@export var lance_width: float = 34.0

# --- Chain Hex: a curse that leaps between bodies (F) ---
@export var hex_mana_cost: int = 35
@export var hex_cooldown: float = 5.0
@export var hex_damage: int = 32
@export var hex_first_range: float = 380.0
@export var hex_jump_range: float = 240.0

# --- Rune Snare: a delayed sigil at the cursor (right mouse) ---
@export var snare_mana_cost: int = 20
@export var snare_cooldown: float = 4.0
@export var snare_damage: int = 40
@export var snare_radius: float = 120.0
@export var snare_arm_time: float = 0.65

# --- Shadow Orbs: three orbs that orbit and bite (T) ---
@export var orbs_mana_cost: int = 40
@export var orbs_cooldown: float = 9.0
@export var orbs_damage: int = 12
@export var orbs_duration: float = 6.0

# --- Blood Pact: life traded for mana (H) ---
@export var pact_cooldown: float = 15.0
@export var pact_health_cost: int = 25
@export var pact_mana_gain: int = 45

# --- Unlockable attacks: earned from between-wave boons ---
@export var gravity_mana_cost: int = 35
@export var gravity_cooldown: float = 7.0
@export var gravity_damage: int = 10
@export var gravity_radius: float = 150.0

@export var lightning_mana_cost: int = 30
@export var lightning_cooldown: float = 6.0
@export var lightning_damage: int = 22
@export var lightning_first_range: float = 340.0
@export var lightning_jump_range: float = 260.0

@export var shockwave_mana_cost: int = 20
@export var shockwave_cooldown: float = 5.0
@export var shockwave_damage: int = 28
@export var shockwave_radius: float = 170.0

signal health_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal died

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var spawn_in: AnimatedSprite2D = $SpawnIn
@onready var flash_step_sound: AudioStreamPlayer = $FlashStepSound
@onready var hurt_sound: AudioStreamPlayer = $HurtSound

var health: int = 200
var mana: int = 100
var _health_regen_timer: float = 0.0
var _mana_regen_timer: float = 0.0
var _facing: String = "down"
var _flash_stepping: bool = false
var _casting: bool = false
var _melee_attacking: bool = false
var _dead: bool = false
var _reviving: bool = false
var _spawning: bool = false
var _attack_cooldown_left: float = 0.0
var _melee_cooldown_left: float = 0.0
## Remaining cooldown per ability id, in seconds.
var _cooldowns: Dictionary = {}
## Attacks that start locked and are unlocked by boons.
var _unlocked: Dictionary = {&"gravity": false, &"lightning": false, &"shockwave": false}
var _trail_material: ShaderMaterial
var _hit_flash_tween: Tween


func _ready() -> void:
	health = max_health
	mana = max_mana
	_trail_material = ShaderMaterial.new()
	_trail_material.shader = TRAIL_SHADER
	health_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)
	_start_spawn_in()


## Materializes the dark mage: orbs gather, wings burst open, then the body
## takes over. Movement, attacks and damage wait for it to finish.
func _start_spawn_in() -> void:
	_spawning = true
	sprite.visible = false
	spawn_in.visible = true
	spawn_in.play("spawn")
	await spawn_in.animation_finished
	if not is_inside_tree():
		return
	spawn_in.visible = false
	sprite.visible = true
	_spawning = false
	_play("idle")


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	_melee_cooldown_left = maxf(0.0, _melee_cooldown_left - delta)
	for id in _cooldowns:
		_cooldowns[id] = maxf(0.0, float(_cooldowns[id]) - delta)

	if _dead or _spawning:
		velocity = Vector2.ZERO
		return

	_regenerate(delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# planting the feet mid-swing is what sells the punch
	if _melee_attacking:
		velocity = Vector2.ZERO
		return

	velocity = input_dir * speed
	move_and_slide()

	# the spell animation owns the sprite until the throw and recovery finish
	if _casting:
		return

	if input_dir == Vector2.ZERO:
		_play("idle")
		return

	# prefer the dominant axis so diagonals don't flicker between rows
	if absf(input_dir.x) > absf(input_dir.y):
		_facing = "right" if input_dir.x > 0.0 else "left"
	else:
		_facing = "down" if input_dir.y > 0.0 else "up"
	_play("walk")


func _play(state: String) -> void:
	var anim := "%s_%s" % [state, _facing]
	if sprite.animation != anim:
		sprite.play(anim)


## Passive regen: health only after a damage-free stretch, mana on its own timer.
func _regenerate(delta: float) -> void:
	if health < max_health:
		_health_regen_timer += delta
		if _health_regen_timer >= health_regen_interval:
			_health_regen_timer -= health_regen_interval
			heal(_percent_of(max_health, health_regen_percent))
	else:
		_health_regen_timer = 0.0

	if mana < max_mana:
		_mana_regen_timer += delta
		if _mana_regen_timer >= mana_regen_interval:
			_mana_regen_timer -= mana_regen_interval
			restore_mana(_percent_of(max_mana, mana_regen_percent))
	else:
		_mana_regen_timer = 0.0


static func _percent_of(maximum: int, percent: int) -> int:
	return maxi(1, int(round(float(maximum) * float(percent) / 100.0)))


## Restores health without exceeding max_health and reports the change.
func heal(amount: int) -> void:
	if _dead or _reviving or amount <= 0:
		return
	var next_health := mini(max_health, health + amount)
	if next_health == health:
		return
	health = next_health
	health_changed.emit(health, max_health)


## Adds mana, clamped to max_mana, and reports the change.
func restore_mana(amount: int) -> void:
	if amount <= 0:
		return
	var next_mana := mini(max_mana, mana + amount)
	if next_mana == mana:
		return
	mana = next_mana
	mana_changed.emit(mana, max_mana)


## Applies one between-wave boon. Called by the wave spawner.
func apply_boon(id: StringName) -> void:
	match id:
		&"power":
			melee_damage = int(round(melee_damage * 1.2))
			dark_fire_damage = int(round(dark_fire_damage * 1.2))
			nova_damage = int(round(nova_damage * 1.2))
			lance_damage = int(round(lance_damage * 1.2))
			hex_damage = int(round(hex_damage * 1.2))
			snare_damage = int(round(snare_damage * 1.2))
			orbs_damage = int(round(orbs_damage * 1.2))
			gravity_damage = int(round(gravity_damage * 1.2))
			lightning_damage = int(round(lightning_damage * 1.2))
			shockwave_damage = int(round(shockwave_damage * 1.2))
		&"swiftness":
			speed *= 1.12
		&"vitality":
			max_health += 20
			if not _dead:
				health = mini(max_health, health + 20)
			health_changed.emit(health, max_health)
		&"focus":
			max_mana += 20
			mana = mini(max_mana, mana + 20)
			mana_changed.emit(mana, max_mana)
		&"haste":
			attack_cooldown = maxf(0.15, attack_cooldown * 0.92)
			melee_cooldown = maxf(0.15, melee_cooldown * 0.92)
			flash_step_cooldown = maxf(0.2, flash_step_cooldown * 0.92)
			nova_cooldown = maxf(0.3, nova_cooldown * 0.92)
			lance_cooldown = maxf(0.3, lance_cooldown * 0.92)
			hex_cooldown = maxf(0.5, hex_cooldown * 0.92)
			snare_cooldown = maxf(0.5, snare_cooldown * 0.92)
			orbs_cooldown = maxf(0.5, orbs_cooldown * 0.92)
			pact_cooldown = maxf(1.0, pact_cooldown * 0.92)
			gravity_cooldown = maxf(0.5, gravity_cooldown * 0.92)
			lightning_cooldown = maxf(0.5, lightning_cooldown * 0.92)
			shockwave_cooldown = maxf(0.5, shockwave_cooldown * 0.92)
		&"armor":
			damage_taken_multiplier = maxf(0.35, damage_taken_multiplier * 0.88)
		&"unlock_gravity":
			_unlocked[&"gravity"] = true
		&"unlock_lightning":
			_unlocked[&"lightning"] = true
		&"unlock_shockwave":
			_unlocked[&"shockwave"] = true


## True when the attack is available. Normal attacks start unlocked.
func has_attack(id: StringName) -> bool:
	return bool(_unlocked.get(id, true))


## Debug helper: opens every boon-locked attack at once.
func unlock_all_attacks() -> void:
	for id in _unlocked:
		_unlocked[id] = true


## Pays a mana cost up front; returns false (and spends nothing) when short.
func _spend_mana(amount: int) -> bool:
	if amount <= 0:
		return true
	if mana < amount:
		return false
	mana -= amount
	mana_changed.emit(mana, max_mana)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if _dead or _spawning:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _melee_cooldown_left <= 0.0 and not _casting and not _melee_attacking:
			_face_toward(get_canvas_transform().affine_inverse() * event.position)
			_melee_attack()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cast_rune_snare(get_canvas_transform().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("flash_step") and not _flash_stepping \
			and _cooldown_left(&"flash") <= 0.0:
		_flash_step()
	elif event.is_action_pressed("attack") and _attack_cooldown_left <= 0.0 and not _casting:
		if _spend_mana(mana_cost):
			_attack()
	elif event.is_action_pressed("nova"):
		_cast_eclipse_nova()
	elif event.is_action_pressed("lance"):
		_cast_void_lance()
	elif event.is_action_pressed("hex"):
		_cast_chain_hex()
	elif event.is_action_pressed("orbs"):
		_cast_shadow_orbs()
	elif event.is_action_pressed("gravity"):
		_cast_gravity_well()
	elif event.is_action_pressed("lightning"):
		_cast_chain_lightning()
	elif event.is_action_pressed("shockwave"):
		_cast_shockwave()
	elif event.is_action_pressed("blood_pact"):
		_cast_blood_pact()


func take_damage(amount: int) -> void:
	if _dead or _reviving or _spawning:
		return
	amount = maxi(1, int(round(float(amount) * damage_taken_multiplier)))
	health = maxi(0, health - amount)
	_health_regen_timer = 0.0
	health_changed.emit(health, max_health)
	_flash_hit()
	hurt_sound.play()
	if health <= 0:
		_die()


## Flashes the sprite red for a beat so a hit is readable at a glance.
func _flash_hit() -> void:
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	sprite.modulate = HIT_FLASH
	_hit_flash_tween = create_tween()
	_hit_flash_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)


func _die() -> void:
	if _dead:
		return
	_dead = true
	_casting = false
	_melee_attacking = false
	velocity = Vector2.ZERO
	sprite.flip_h = false
	sprite.play("wither")
	died.emit()
	await sprite.animation_finished
	# hold the final withered frame
	if _dead:
		sprite.frame = sprite.sprite_frames.get_frame_count("wither") - 1
		sprite.pause()


func revive() -> void:
	if not _dead or _reviving:
		return
	_reviving = true
	sprite.flip_h = false
	sprite.modulate = Color.WHITE
	sprite.play_backwards("wither")
	await sprite.animation_finished
	health = max_health
	mana = max_mana
	_health_regen_timer = 0.0
	_mana_regen_timer = 0.0
	_dead = false
	_reviving = false
	_casting = false
	_melee_attacking = false
	_facing = "down"
	health_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)
	_cooldowns.clear()
	_play("idle")


## Vanishes for a moment, reappears flash_step_distance ahead in the facing direction.
func _flash_step() -> void:
	if _flash_stepping or _cooldown_left(&"flash") > 0.0:
		return
	_flash_stepping = true
	_cooldowns[&"flash"] = flash_step_cooldown
	var origin := global_position
	var target := _step_target(origin, _facing_vector() * flash_step_distance)
	_spawn_trail(origin.distance_to(target))
	flash_step_sound.play()
	# damage any enemy swept through on the dash line (stop at the wall)
	var dash_start := global_position
	var dash_end := target
	_hit_enemies_along_segment(dash_start, dash_end, flash_damage, flash_hit_radius)
	CombatFx.burst(get_parent(), origin, Color(0.62, 0.35, 1.0), 18, 0.4, 70.0, 220.0,
			Vector2.UP, 180.0, 30.0)
	sprite.visible = false
	global_position = target
	CombatFx.burst(get_parent(), target, Color(0.85, 0.75, 1.0), 22, 0.45, 50.0, 190.0,
			Vector2.UP, 180.0, 20.0)
	CombatFx.shake(get_tree(), 4.0, 0.14)
	await get_tree().create_timer(flash_step_hide_time).timeout
	sprite.visible = true
	_flash_stepping = false


## Damages every enemy whose center is within range and roughly in front of the
## player (used for the melee punch). Returns how many it hit.
func _hit_enemies_in_front(damage: int, range: float) -> int:
	var forward := _facing_vector()
	var origin := global_position
	var hits := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var to: Vector2 = enemy.global_position - origin
		if to.length() > range:
			continue
		if to.dot(forward) < -16.0:
			continue
		enemy.take_damage(damage)
		hits += 1
	return hits


## Damages every enemy whose center lies within radius of the line segment
## start->end (used for the flash step dash).
func _hit_enemies_along_segment(start: Vector2, end: Vector2, damage: int, radius: float) -> void:
	var segment := end - start
	var length := segment.length()
	if length <= 0.0:
		return
	var direction := segment / length
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var to: Vector2 = enemy.global_position - start
		var t := clampf(to.dot(direction), 0.0, length)
		var closest := start + direction * t
		if enemy.global_position.distance_to(closest) <= radius:
			enemy.take_damage(damage)


## Stops a dash at the first wall so it cannot leave the arena. Enemies are not
## considered: flash step and the punch lunge both pass over their bodies.
func _step_target(origin: Vector2, offset: Vector2, mask: int = WALL_MASK) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(origin, origin + offset, mask)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return origin + offset
	return (hit["position"] as Vector2) - offset.normalized() * 26.0


## Leaves flat white silhouettes of the current frame along the travel path.
func _spawn_trail(distance: float = -1.0) -> void:
	var frame := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
	if frame == null or frame.atlas == null:
		return

	if distance < 0.0:
		distance = flash_step_distance
	var direction := _facing_vector()
	var parent := get_parent()
	for i in flash_step_trail_count:
		var progress := float(i + 1) / float(flash_step_trail_count + 1)
		var ghost := Sprite2D.new()
		ghost.name = "FlashStepTrail%d" % (i + 1)
		ghost.texture = frame.atlas
		ghost.region_enabled = true
		ghost.region_rect = frame.region
		ghost.offset = sprite.offset
		ghost.flip_h = sprite.flip_h
		ghost.flip_v = sprite.flip_v
		ghost.texture_filter = sprite.texture_filter
		ghost.material = _trail_material
		ghost.modulate = Color(1.0, 1.0, 1.0, 0.8)

		# sit just behind the player in draw order so the real sprite stays on top
		parent.add_child(ghost)
		parent.move_child(ghost, get_index())
		ghost.global_position = global_position + direction * distance * progress

		var tween := ghost.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, flash_step_trail_fade)
		tween.tween_callback(ghost.queue_free)


## Swings the punch that matches the way the player is currently facing.
## The sheet already has a dedicated row per direction, so no flipping is
## needed - attack_left really is drawn facing left.
func _melee_attack() -> void:
	_melee_attacking = true
	_melee_cooldown_left = melee_cooldown
	velocity = Vector2.ZERO
	sprite.flip_h = false

	var anim := "attack_%s" % _facing
	if not sprite.sprite_frames.has_animation(anim):
		anim = "attack_down"
	sprite.play(anim)

	# the punch lands immediately: hurt anything in reach in front of us
	var hits := _hit_enemies_in_front(melee_damage, melee_range)
	CombatFx.slash(get_parent(), global_position + _facing_vector() * 26.0,
			_facing_vector(), melee_range * 0.74)
	if hits > 0:
		CombatFx.shake(get_tree(), 3.5, 0.12)

	# lunge a short step in the attack direction so the punch feels weighty. Not
	# when it already connected, though: that would step onto the goblin's sprite.
	if hits == 0:
		var direction := _facing_vector()
		var lunge_target := _step_target(global_position, direction * melee_lunge_distance)
		# don't step backwards when a wall already sits inside the lunge's margin
		if (lunge_target - global_position).dot(direction) > 4.0:
			var lunge := create_tween()
			lunge.tween_property(self, "global_position", lunge_target, melee_lunge_time)

	await sprite.animation_finished
	_melee_attacking = false
	# dying mid-swing hands the sprite over to the wither animation
	if _dead or _reviving:
		return
	_play("idle")


## Plays the conjure animation and releases the ball when the hand is thrust out.
func _attack() -> void:
	_casting = true
	_attack_cooldown_left = attack_cooldown

	var aim := get_global_mouse_position() - global_position
	sprite.flip_h = aim.x < -4.0

	sprite.play("cast")
	await sprite.animation_finished
	_throw_dark_fire(_hand_position())

	sprite.play("cast_recover")
	await sprite.animation_finished
	sprite.flip_h = false
	_casting = false


## World position of the fireball in the release pose, mirrored for left throws.
func _hand_position() -> Vector2:
	return global_position + Vector2(-HAND_OFFSET.x if sprite.flip_h else HAND_OFFSET.x, HAND_OFFSET.y)


func _throw_dark_fire(spawn_position: Vector2) -> void:
	var cursor := get_global_mouse_position()
	var target := cursor
	if target.distance_to(spawn_position) < 8.0:
		target = spawn_position + _facing_vector() * 100.0

	var fire := DARK_FIRE_SCENE.instantiate()
	get_parent().add_child(fire)
	fire.global_position = spawn_position
	fire.damage = dark_fire_damage
	# The blast reaches as far as the punch, so E clears a small pack.
	fire.blast_radius = melee_range
	fire.setup(target, _dark_fire_lock(cursor))


## The enemy closest to the cursor that the next dark fire homes onto.
func _dark_fire_lock(cursor: Vector2) -> Node2D:
	return Combat.nearest(get_tree(), cursor, DARK_FIRE_LOCK_RANGE)


## Snaps the attack direction to the nearest of the four animation rows.
func _face_toward(world_point: Vector2) -> void:
	var aim := world_point - global_position
	if aim.length_squared() < 4.0:
		return
	if absf(aim.x) > absf(aim.y):
		_facing = "right" if aim.x > 0.0 else "left"
	else:
		_facing = "down" if aim.y > 0.0 else "up"


func _facing_vector() -> Vector2:
	match _facing:
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		"up":
			return Vector2.UP
		_:
			return Vector2.DOWN


# ---- sprite-free spells ----
#
# Every one of these is a Node2D that draws itself, so no new art is involved: the
# Hero's pose is left alone and the effect carries the whole read. They all share
# the same gate (ready, enough mana, not mid-punch or mid-cast).

## True when `id` is off cooldown and its mana price is paid; starts the cooldown.
func _begin_ability(id: StringName, price: int, cooldown: float) -> bool:
	if _dead or _spawning or _casting or _melee_attacking or _flash_stepping:
		return false
	if not bool(_unlocked.get(id, true)):
		return false
	if _cooldown_left(id) > 0.0:
		return false
	if not _spend_mana(price):
		return false
	_cooldowns[id] = cooldown
	return true


func _cooldown_left(id: StringName) -> float:
	return float(_cooldowns.get(id, 0.0))


## Snapshot for the cooldown HUD: one entry per attack in ABILITY_INFO.
func ability_status() -> Array[Dictionary]:
	var status: Array[Dictionary] = []
	for info in ABILITY_INFO:
		var id: StringName = info["id"]
		var left := 0.0
		match id:
			&"melee":
				left = _melee_cooldown_left
			&"attack":
				left = _attack_cooldown_left
			_:
				left = _cooldown_left(id)
		status.append({"id": id, "label": info["label"], "key": info["key"],
				"left": left, "total": _cooldown_duration(id),
				"locked": not bool(_unlocked.get(id, true))})
	return status


func _cooldown_duration(id: StringName) -> float:
	match id:
		&"melee":
			return melee_cooldown
		&"attack":
			return attack_cooldown
		&"flash":
			return flash_step_cooldown
		&"nova":
			return nova_cooldown
		&"lance":
			return lance_cooldown
		&"hex":
			return hex_cooldown
		&"snare":
			return snare_cooldown
		&"orbs":
			return orbs_cooldown
		&"gravity":
			return gravity_cooldown
		&"lightning":
			return lightning_cooldown
		&"shockwave":
			return shockwave_cooldown
		&"pact":
			return pact_cooldown
	return 0.0


## C - Eclipse Nova: a ring of force that shoves and hurts everything around the Hero.
func _cast_eclipse_nova() -> void:
	if not _begin_ability(&"nova", nova_mana_cost, nova_cooldown):
		return
	var nova := ECLIPSE_NOVA.new()
	get_parent().add_child(nova)
	nova.radius = nova_radius
	nova.damage = nova_damage
	nova.setup(global_position)


## R - Void Lance: a piercing beam toward the cursor.
func _cast_void_lance() -> void:
	if not _begin_ability(&"lance", lance_mana_cost, lance_cooldown):
		return
	var aim := get_global_mouse_position() - global_position
	var direction := aim.normalized() if aim.length_squared() > 16.0 else _facing_vector()
	_face_toward(global_position + direction)
	var lance := VOID_LANCE.new()
	get_parent().add_child(lance)
	lance.width = lance_width
	lance.damage = lance_damage
	lance.setup(global_position, direction, lance_range)


## F - Chain Hex: a curse that leaps from body to body, losing bite each jump.
func _cast_chain_hex() -> void:
	# pick the first body first: a hex with nothing to jump to costs no mana
	var first := Combat.nearest(get_tree(), global_position, hex_first_range)
	if first == null:
		return
	if not _begin_ability(&"hex", hex_mana_cost, hex_cooldown):
		return
	var hex := CHAIN_HEX.new()
	get_parent().add_child(hex)
	hex.damage = hex_damage
	hex.jump_range = hex_jump_range
	hex.setup(global_position, first)


## Right mouse - Rune Snare: a sigil dropped at the cursor that blows after a beat.
func _cast_rune_snare(world_point: Vector2) -> void:
	if not _begin_ability(&"snare", snare_mana_cost, snare_cooldown):
		return
	var snare := RUNE_SNARE.new()
	get_parent().add_child(snare)
	snare.radius = snare_radius
	snare.damage = snare_damage
	snare.arm_time = snare_arm_time
	snare.setup(world_point)


## T - Shadow Orbs: three orbs that orbit the Hero and bite what they sweep through.
func _cast_shadow_orbs() -> void:
	if not _begin_ability(&"orbs", orbs_mana_cost, orbs_cooldown):
		return
	var orbs := SHADOW_ORBS.new()
	get_parent().add_child(orbs)
	orbs.setup(self, orbs_damage, orbs_duration)


## G - Gravity Well: a vortex that drags enemies together and grinds them.
func _cast_gravity_well() -> void:
	if not _begin_ability(&"gravity", gravity_mana_cost, gravity_cooldown):
		return
	var well := GRAVITY_WELL.new()
	get_parent().add_child(well)
	well.radius = gravity_radius
	well.damage = gravity_damage
	well.setup(get_global_mouse_position())


## X - Chain Lightning: a bolt that leaps between bodies with a gentler falloff.
func _cast_chain_lightning() -> void:
	var first := Combat.nearest(get_tree(), global_position, lightning_first_range)
	if first == null:
		return
	if not _begin_ability(&"lightning", lightning_mana_cost, lightning_cooldown):
		return
	var bolt := CHAIN_LIGHTNING.new()
	get_parent().add_child(bolt)
	bolt.damage = lightning_damage
	bolt.jump_range = lightning_jump_range
	bolt.setup(global_position, first)


## V - Shockwave: a close blast that hurls everything back.
func _cast_shockwave() -> void:
	if not _begin_ability(&"shockwave", shockwave_mana_cost, shockwave_cooldown):
		return
	var wave := SHOCKWAVE.new()
	get_parent().add_child(wave)
	wave.radius = shockwave_radius
	wave.damage = shockwave_damage
	wave.setup(global_position)


## H - Blood Pact: spend life for mana. Never spends the last of the Hero's life.
func _cast_blood_pact() -> void:
	if _dead or _spawning or _casting or _melee_attacking:
		return
	if _cooldown_left(&"pact") > 0.0:
		return
	if health <= pact_health_cost or mana >= max_mana:
		return
	_cooldowns[&"pact"] = pact_cooldown
	health -= pact_health_cost
	_health_regen_timer = 0.0
	health_changed.emit(health, max_health)
	restore_mana(pact_mana_gain)
	var fx := BLOOD_PACT_FX.new()
	get_parent().add_child(fx)
	fx.setup(global_position)
