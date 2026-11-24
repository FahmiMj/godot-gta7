shader_type canvas_item;

// Slow ritual rotation plus a breathing glow for the four corner summoning rings.

uniform float spin_speed : hint_range(-2.0, 2.0) = 0.055;
uniform float pulse_speed : hint_range(0.05, 3.0) = 0.32;
uniform vec3 glow_tint : source_color = vec3(0.38, 0.66, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.65;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float angle = TIME * spin_speed * TAU;
	float c = cos(angle);
	float s = sin(angle);
	vec2 spun = mat2(vec2(c, s), vec2(-s, c)) * p;
	vec4 tex = texture(TEXTURE, spun + vec2(0.5));

	float breathe = 0.72 + 0.28 * sin(TIME * pulse_speed * TAU);
	vec3 col = tex.rgb + glow_tint * tex.a * glow_strength * breathe;
	COLOR = vec4(col, tex.a * (0.72 + 0.28 * breathe));
}
