extends SceneTree
## Smoke test: the player scene loads, a left-click swing plays the directional
## animation, and the controller falls back to idle afterwards.
##   godot --headless --path . --script res://tools/test_melee.gd


func _init() -> void:
	var player: Node = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame

	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	for facing in ["down", "up", "left", "right"]:
		player._facing = facing
		player._melee_attack()
		await process_frame
		var anim := sprite.animation
		var frames := sprite.sprite_frames.get_frame_count(anim)
		var size := sprite.sprite_frames.get_frame_texture(anim, 0).get_size()
		print("%s -> %s (%d frames, %s)" % [facing, anim, frames, size])
		await create_timer(0.7).timeout
		print("   back to: ", sprite.animation)

	# cooldown blocks a second swing
	player._facing = "down"
	player._melee_cooldown_left = 0.0
	player._melee_attack()
	await create_timer(0.1).timeout
	var before := sprite.animation
	player._melee_cooldown_left = 5.0
	player._melee_attack()
	print("cooldown respected: ", sprite.animation == before)

	quit()
