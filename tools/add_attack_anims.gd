extends SceneTree
## Adds the four directional melee attacks to assets/player_frames.tres.
##
## Each strip is 5 frames of 224x192 (wider than the walk cells because the
## slash arcs reach past the body). Run with:
##   godot --headless --path . --script res://tools/add_attack_anims.gd

const STRIPS := {
	"attack_down": "res://assets/sprites/attacks/attack_down.png",
	"attack_up": "res://assets/sprites/attacks/attack_up.png",
	"attack_left": "res://assets/sprites/attacks/attack_left.png",
	"attack_right": "res://assets/sprites/attacks/attack_right.png",
}
const CELL := Vector2(224.0, 192.0)
const FPS := 12.0


func _init() -> void:
	var frames: SpriteFrames = load("res://assets/player_frames.tres")
	if frames == null:
		push_error("player_frames.tres did not load")
		quit(1)
		return

	for anim in STRIPS:
		var path: String = STRIPS[anim]
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("missing texture: " + path)
			quit(1)
			return

		if frames.has_animation(anim):
			frames.remove_animation(anim)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, FPS)
		frames.set_animation_loop(anim, false)

		var count := int(tex.get_width() / CELL.x)
		for i in count:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * CELL.x, 0.0, CELL.x, CELL.y)
			frames.add_frame(anim, at)
		print("%s: %d frames" % [anim, count])

	var err := ResourceSaver.save(frames, "res://assets/player_frames.tres")
	print("save -> ", err)
	print("animations: ", frames.get_animation_names())
	quit()
