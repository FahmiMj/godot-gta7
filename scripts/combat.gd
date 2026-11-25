class_name Combat
extends RefCounted
## Shared hit-testing and damage helpers for the Hero's attacks.
##
## Enemies never expose a hitbox to the player: they sit in the "enemies" group and
## take damage through take_damage(). An attack therefore describes a shape - circle,
## cone or line - and lets these helpers walk the group. Everything is a static call,
## so an attack script needs no node of its own to reach the battlefield.

const ENEMY_GROUP: StringName = &"enemies"


## Every living enemy in the tree, as positions we can test against a shape.
static func enemies(tree: SceneTree) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node in tree.get_nodes_in_group(ENEMY_GROUP):
		if node is Node2D and is_alive(node):
			found.append(node)
	return found


## True while the enemy is still worth hitting (it may already be dying).
static func is_alive(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	var dead: Variant = target.get("is_dead")
	return dead == null or not bool(dead)


## Enemies whose center lies within `radius` of `origin`.
static func hits_in_circle(tree: SceneTree, origin: Vector2, radius: float) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for enemy in enemies(tree):
		if enemy.global_position.distance_to(origin) <= radius:
			found.append(enemy)
	return found


## Enemies whose center lies within `radius` of the line start->end.
static func hits_along_line(tree: SceneTree, start: Vector2, end: Vector2, radius: float) -> Array[Node2D]:
	var found: Array[Node2D] = []
	var segment := end - start
	var length := segment.length()
	if length <= 0.0:
		return found
	var direction := segment / length
	for enemy in enemies(tree):
		var to: Vector2 = enemy.global_position - start
		var t := clampf(to.dot(direction), 0.0, length)
		if enemy.global_position.distance_to(start + direction * t) <= radius:
			found.append(enemy)
	return found


## Enemies inside a wedge opening from `origin` toward `forward`, up to `reach`
## and `half_angle_deg` to either side of it.
static func hits_in_cone(tree: SceneTree, origin: Vector2, forward: Vector2,
		reach: float, half_angle_deg: float) -> Array[Node2D]:
	var found: Array[Node2D] = []
	var aim := forward.normalized()
	var half_angle := deg_to_rad(half_angle_deg)
	for enemy in enemies(tree):
		var to: Vector2 = enemy.global_position - origin
		var distance := to.length()
		if distance > reach:
			continue
		# anything standing on top of the caster counts as in front
		if distance < 1.0 or absf(aim.angle_to(to)) <= half_angle:
			found.append(enemy)
	return found


## The closest living enemy to `from` within `max_range`, skipping `exclude`.
static func nearest(tree: SceneTree, from: Vector2, max_range: float,
		exclude: Array = []) -> Node2D:
	var best: Node2D = null
	var best_distance := max_range
	for enemy in enemies(tree):
		if enemy in exclude:
			continue
		var distance := enemy.global_position.distance_to(from)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Applies `amount` to every target that can still take it. Returns the hit count.
static func damage(targets: Array, amount: int) -> int:
	var hits := 0
	for target in targets:
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(amount)
			hits += 1
	return hits


## Shoves every target away from `from` and briefly stuns it. Enemies decide
## whether they can be interrupted; the ghoul has no stagger and simply ignores it.
static func stagger(targets: Array, from: Vector2, force: float = 150.0) -> void:
	for target in targets:
		if is_instance_valid(target) and target.has_method("stagger"):
			target.stagger(from, force)
