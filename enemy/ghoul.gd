class_name Ghoul
extends CharacterBody2D
## Floating ghoul. It drifts and sways, hunts the Hero, teleports around them in a puff
## of purple smoke, and from a distance screams to drain the Hero's mana. The supplied
## art is a single pose, so every state (idle, walk, scream, hurt, teleport, death) is
## animated in code: bobbing, leaning, shaking, a white flash and a fade.

signal died(points: int)

enum State { SPAWN, IDLE, WALK, WINDUP, SCREAM, TELEPORT_OUT, TELEPORT_IN, DEAD }

@export var speed: float = 85.0
@export var max_health: int = 80
@export var points: int = 15
@export var detection_range: float = 100000.0
## It floats toward the Hero until this close, then hovers.
@export var hover_distance: float = 170.0
## The scream only drains mana from a Hero this close.
@export var scream_radius: float = 250.0
@export var scream_mp_drain: int = 15
## Seconds between the start of one scream and the next.
@export var scream_cooldown: float = 4.0
## Warning time before the scream is released.
@export var scream_windup: float = 0.7
@export var scream_duration: float = 0.9
## Seconds between teleports while hunting (a random value in this range).
@export var teleport_cooldown_min: float = 6.0
@export var teleport_cooldown_max: float = 9.0
## The teleport lands this far from the Hero, never closer.
@export var teleport_min_distance: float = 190.0
@export var teleport_max_distance: float = 320.0
## Fade-out and fade-in time of a teleport.
@export var teleport_time: float = 0.4
## How far it lazily drifts from where it spawned while nothing is nearby.
@export var wander_radius: float = 150.0

const SHAKE_PIXELS: float = 7.0
const HURT_SECONDS: float = 0.25
const SCREAM_EFFECT: Script = preload("res://enemy/scream_effect.gd")
const GLOW: Script = preload("res://enemy/spawn_effect.gd")
const SFX_AMBIENT: AudioStream = preload("res://assets/audio/ghoul_ambient.wav")
const SFX_TELEPORT: AudioStream = preload("res://assets/audio/ghoul_teleport.wav")
const SFX_HURT: AudioStream = preload("res://assets/audio/ghoul_hurt.wav")
const SFX_DEATH: AudioStream = preload("res://assets/audio/ghoul_death.wav")
const SMOKE: Color = Color(0.55, 0.2, 0.85, 0.7)

var is_dead: bool = false
var state: State = State.IDLE
## The animation being shown: idle, walk, scream, hurt, teleport or death.
var current_animation: StringName = &"idle"

var _health: int
var _cooldown_left: float = 0.0
var _state_time: float = 0.0
var _clock: float = 0.0
var _hurt_left: float = 0.0
var _teleport_left: float = 0.0
var _teleport_dest: Vector2 = Vector2.ZERO
var _ambient_left: float = 0.0
var _hurt_sound_left: float = 0.0
var _home: Vector2 = Vector2.ZERO
var _phase_a: float = 0.0
var _phase_b: float = 0.0
var _fade: Tween
var _hp_bar: EnemyHpBar
var _sfx: Dictionary = {}

@onready var _body: Node2D = $Body
@onready var _sprite: Sprite2D = $Body/Sprite
@onready var _mouth: Marker2D = $Body/Mouth
@onready var _scream_sound: AudioStreamPlayer2D = $ScreamSound


func _ready() -> void:
	_health = max_health
	add_to_group("enemies")
	_phase_a = randf() * TAU
	_phase_b = randf() * TAU
	_clock = randf() * 10.0
	_teleport_left = randf_range(teleport_cooldown_min, teleport_cooldown_max)
	_ambient_left = randf_range(2.0, 6.0)
	_home = global_position
	for key: StringName in [&"ambient", &"teleport", &"hurt", &"death"]:
		var player := AudioStreamPlayer2D.new()
		player.max_distance = 1800.0
		player.stream = {&"ambient": SFX_AMBIENT, &"teleport": SFX_TELEPORT, &"hurt": SFX_HURT, &"death": SFX_DEATH}[key]
		player.volume_db = -10.0 if key == &"ambient" else -4.0
		add_child(player)
		_sfx[key] = player
	_hp_bar = EnemyHpBar.attach(self, &"ghoul", max_health, 196.0)


func _physics_process(delta: float) -> void:
	if is_dead or state == State.SPAWN:
		return
	_clock += delta
	_state_time += delta
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_teleport_left = maxf(0.0, _teleport_left - delta)
	_hurt_left = maxf(0.0, _hurt_left - delta)
	_hurt_sound_left = maxf(0.0, _hurt_sound_left - delta)
	_ambient_sound(delta)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var engaged := _can_engage(player)
	velocity = Vector2.ZERO
	match state:
		State.IDLE, State.WALK:
			state = State.IDLE
			if engaged:
				_face(player)
				var distance := global_position.distance_to(player.global_position)
				if _hurt_left <= 0.0:
					if distance > hover_distance:
						velocity = global_position.direction_to(player.global_position) * speed
						state = State.WALK
					if _teleport_left <= 0.0 and _try_teleport(player):
						pass
					elif distance <= scream_radius and _cooldown_left <= 0.0:
						_set_state(State.WINDUP)
			else:
				velocity = _wander()
				if velocity.length() > 4.0:
					_sprite.flip_h = velocity.x > 0.0 # the art faces left
		State.WINDUP:
			if _hurt_left > 0.0 or not engaged or global_position.distance_to(player.global_position) > scream_radius + 60.0:
				_set_state(State.IDLE) # the Hero got away, or the hit broke its concentration
			elif _state_time >= scream_windup:
				_scream(player)
		State.SCREAM:
			if _state_time >= scream_duration:
				_set_state(State.IDLE)
		State.TELEPORT_OUT:
			if _state_time >= teleport_time:
				_arrive()
		State.TELEPORT_IN:
			if _state_time >= teleport_time:
				$CollisionShape2D.disabled = false
				_set_state(State.IDLE)
	move_and_slide()
	_animate()


func take_damage(amount: int) -> void:
	if is_dead or state == State.SPAWN:
		return
	_health -= amount
	_hp_bar.set_health(_health)
	CombatFx.burst(get_parent(), _sprite.global_position, SMOKE, 8, 0.4, 40.0, 120.0, Vector2.UP, 180.0, 60.0)
	if _health <= 0:
		_die()
		return
	_hurt_left = HURT_SECONDS
	if _hurt_sound_left <= 0.0:
		_hurt_sound_left = 0.3
		(_sfx[&"hurt"] as AudioStreamPlayer2D).play()
	var flash := create_tween()
	flash.tween_method(_set_flash, 1.0, 0.0, HURT_SECONDS * 0.8)


## Called by the wave spawner as soon as the ghoul is placed. It stays invisible and
## harmless while the summoning circle plays, then fades in and starts hunting.
func spawn_in(duration: float) -> void:
	state = State.SPAWN
	$CollisionShape2D.set_deferred("disabled", true)
	modulate.a = 0.0
	_body.scale = Vector2(0.7, 0.7)
	var fade := create_tween().set_parallel(true)
	fade.tween_property(self, "modulate:a", 1.0, duration * 0.45).set_delay(duration * 0.35)
	fade.tween_property(_body, "scale", Vector2.ONE, duration * 0.45).set_delay(duration * 0.35)
	await get_tree().create_timer(duration).timeout
	_home = global_position
	_set_state(State.IDLE)
	$CollisionShape2D.disabled = false


func _can_engage(player: Node2D) -> bool:
	return is_instance_valid(player) and _is_alive(player) \
			and global_position.distance_to(player.global_position) <= detection_range


func _is_alive(player: Node2D) -> bool:
	return not ("health" in player) or player.health > 0


func _face(player: Node2D) -> void:
	# the art faces left
	_sprite.flip_h = player.global_position.x > global_position.x
	_mouth.position.x = absf(_mouth.position.x) * (1.0 if _sprite.flip_h else -1.0)


func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0


# Slow, never-repeating drift (two out-of-step sine waves) that is gently pulled back
# toward where the ghoul spawned, so it roams without wandering off.
func _wander() -> Vector2:
	var drift := Vector2(sin(_clock * 0.55 + _phase_a) + 0.5 * sin(_clock * 1.3 + _phase_b),
			cos(_clock * 0.42 + _phase_b) + 0.5 * cos(_clock * 1.1 + _phase_a)) * 22.0
	var away := global_position - _home
	if away.length() > wander_radius:
		drift -= away.normalized() * 40.0
	return drift


func _ambient_sound(delta: float) -> void:
	_ambient_left -= delta
	if _ambient_left > 0.0:
		return
	_ambient_left = randf_range(5.0, 10.0) # random gaps: never every frame, never a loop
	(_sfx[&"ambient"] as AudioStreamPlayer2D).pitch_scale = randf_range(0.85, 1.15)
	(_sfx[&"ambient"] as AudioStreamPlayer2D).play()


func _scream(player: Node2D) -> void:
	_set_state(State.SCREAM)
	_cooldown_left = scream_cooldown
	_scream_sound.play()
	var effect := SCREAM_EFFECT.new() as Node2D
	effect.set("radius", scream_radius)
	effect.set("duration", scream_duration)
	get_parent().add_child(effect)
	effect.global_position = _mouth.global_position
	# One drain per scream, and only for a living Hero inside the radius.
	if _is_alive(player) and global_position.distance_to(player.global_position) <= scream_radius:
		_drain_mana(player)


# The Hero has no public mana-drain method: lower its mana (never below 0) and
# announce it on its own signal so the mana bar updates.
func _drain_mana(player: Node2D) -> void:
	if not ("mana" in player):
		return
	player.mana = maxi(0, player.mana - scream_mp_drain)
	if player.has_signal("mana_changed"):
		player.mana_changed.emit(player.mana, player.max_mana)


# ---- teleporting ----

func _try_teleport(player: Node2D) -> bool:
	var spot := find_teleport_spot(player)
	if spot == Vector2.INF:
		_teleport_left = 1.0 # nowhere safe right now: look again soon
		return false
	_teleport_dest = spot
	_set_state(State.TELEPORT_OUT)
	$CollisionShape2D.set_deferred("disabled", true)
	_smoke(global_position)
	(_sfx[&"teleport"] as AudioStreamPlayer2D).play()
	_fade_to(0.0)
	return true


# At the moment of the vanish a second puff marks where it will reappear.
func _arrive() -> void:
	global_position = _teleport_dest
	_home = _teleport_dest
	_smoke(global_position)
	_teleport_left = randf_range(teleport_cooldown_min, teleport_cooldown_max)
	_set_state(State.TELEPORT_IN)
	_fade_to(1.0)


func _fade_to(alpha: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, teleport_time)


## A safe place to reappear: between `teleport_min_distance` and `teleport_max_distance`
## from the Hero, inside the arena (nothing solid between it and the Hero), not inside
## any obstacle or other body. Returns Vector2.INF when it finds none.
func find_teleport_spot(player: Node2D) -> Vector2:
	var space := get_world_2d().direct_space_state
	var circle := CircleShape2D.new()
	circle.radius = ($CollisionShape2D as CollisionShape2D).shape.radius + 6.0
	for attempt in 12:
		var spot := player.global_position + Vector2.from_angle(randf() * TAU) \
				* randf_range(teleport_min_distance, teleport_max_distance)
		var ray := PhysicsRayQueryParameters2D.create(player.global_position, spot, 1, [player.get_rid(), get_rid()])
		if not space.intersect_ray(ray).is_empty():
			continue # a wall lies between: that spot is behind it, or out of the map
		var shape := PhysicsShapeQueryParameters2D.new()
		shape.shape = circle
		shape.transform = Transform2D(0.0, spot)
		shape.collision_mask = 1 | 4
		shape.exclude = [player.get_rid(), get_rid()]
		if not space.intersect_shape(shape, 1).is_empty():
			continue # inside an obstacle or another enemy
		return spot
	return Vector2.INF


# Purple ghost smoke: soft blobs that drift up and fade.
func _smoke(at: Vector2) -> void:
	var puff := CPUParticles2D.new()
	puff.texture = GLOW.glow_texture()
	puff.one_shot = true
	puff.amount = 16
	puff.lifetime = 0.9
	puff.explosiveness = 0.85
	puff.direction = Vector2.UP
	puff.spread = 180.0
	puff.initial_velocity_min = 25.0
	puff.initial_velocity_max = 90.0
	puff.gravity = Vector2(0, -35)
	puff.scale_amount_min = 1.2
	puff.scale_amount_max = 2.6
	puff.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 24.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.6, 0.22, 0.9, 0.7))
	ramp.set_color(1, Color(0.3, 0.05, 0.5, 0.0))
	puff.color_ramp = ramp
	puff.z_index = 9
	get_parent().add_child(puff)
	puff.global_position = at + Vector2(0, -60)
	puff.emitting = true
	get_tree().create_timer(1.3).timeout.connect(puff.queue_free)


# All motion is an offset on the Body node, rebuilt every frame from zero, so
# shaking can never move the ghoul itself.
func _animate() -> void:
	var offset := Vector2.ZERO
	var stretch := Vector2.ONE
	var lean := 0.0
	var tint := Color.WHITE
	match state:
		State.IDLE:
			current_animation = &"idle"
			# eerie float: two bobs, a slow sideways sway, a lean and a faint flicker
			offset = Vector2(sin(_clock * 1.3 + _phase_a) * 6.0, sin(_clock * 2.2) * 5.0 + sin(_clock * 0.9 + _phase_b) * 4.0)
			lean = sin(_clock * 1.1 + _phase_b) * 0.08
			var breathe := 1.0 + sin(_clock * 1.7) * 0.03
			stretch = Vector2(breathe, 2.0 - breathe)
			tint.a = 0.88 + 0.12 * sin(_clock * 2.9 + _phase_a)
		State.WALK:
			current_animation = &"walk"
			offset.y = sin(_clock * 5.0) * 7.0
			lean = clampf(velocity.x / speed, -1.0, 1.0) * 0.12
		State.WINDUP:
			current_animation = &"scream"
			var ready := clampf(_state_time / scream_windup, 0.0, 1.0)
			offset = Vector2(sin(_clock * 60.0), cos(_clock * 53.0)) * lerpf(1.0, 3.0, ready)
			stretch = Vector2.ONE * (1.0 + 0.04 * ready)
			tint = Color.WHITE.lerp(Color(1.0, 0.55, 0.85), ready)
		State.SCREAM:
			current_animation = &"scream"
			var fade := 1.0 - clampf(_state_time / scream_duration, 0.0, 1.0)
			offset = Vector2(sin(_clock * 95.0), cos(_clock * 83.0) * 0.6) * SHAKE_PIXELS * (0.4 + 0.6 * fade)
			var pulse := absf(sin(_clock * 14.0)) * (0.4 + 0.6 * fade)
			stretch = Vector2(1.0 - 0.05 * pulse, 1.0 + 0.11 * pulse) # the mouth gapes: tall, narrow pulses
			tint = Color(1.0, 0.7, 0.95)
		State.TELEPORT_OUT, State.TELEPORT_IN:
			current_animation = &"teleport"
			var k := clampf(_state_time / teleport_time, 0.0, 1.0)
			var shrink := k if state == State.TELEPORT_OUT else 1.0 - k
			stretch = Vector2(1.0 - 0.5 * shrink, 1.0 + 0.5 * shrink) # stretched thin, like being sucked away
			tint = Color(0.8, 0.5, 1.0)
	if _hurt_left > 0.0:
		current_animation = &"hurt"
	_body.position = offset
	_body.rotation = lean
	_body.scale = stretch
	_sprite.modulate = tint


# Plays on its own node under the arena, so the wail is not cut off when the ghoul is freed.
func _play_death_sound() -> void:
	var voice := _sfx[&"death"] as AudioStreamPlayer2D
	remove_child(voice)
	get_parent().add_child(voice)
	voice.global_position = global_position
	voice.finished.connect(voice.queue_free)
	voice.play()


func _set_flash(value: float) -> void:
	(_sprite.material as ShaderMaterial).set_shader_parameter("flash", value)


func _die() -> void:
	is_dead = true
	state = State.DEAD
	current_animation = &"death"
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_scream_sound.stop()
	_play_death_sound()
	_smoke(global_position)
	_hp_bar.visible = false
	died.emit(points)
	# Game autoload is optional for now: skip points if it is missing.
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("add_score"):
		game.add_score(points)

	remove_from_group("enemies")
	$CollisionShape2D.set_deferred("disabled", true)
	_set_flash(0.6)
	_sprite.modulate = Color.WHITE
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_body, "position:y", -34.0, 0.9)
	fade.tween_property(_body, "scale", Vector2(1.2, 0.8), 0.9)
	fade.tween_property(self, "modulate:a", 0.0, 0.9)
	await fade.finished
	queue_free()
