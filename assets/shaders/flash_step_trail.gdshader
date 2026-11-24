shader_type canvas_item;

// Draws the sprite as a flat white silhouette, keeping its alpha shape.
// Used by the flash step afterimages so the trail reads as pure white.
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(1.0, 1.0, 1.0, tex.a * COLOR.a);
}
