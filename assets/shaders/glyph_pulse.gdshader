shader_type canvas_item;

// Breathing purple light that sweeps around the hieroglyph band like a windmill.

uniform float breathe_speed : hint_range(0.05, 3.0) = 0.5;
uniform float spin_speed : hint_range(0.0, 2.0) = 0.12;
uniform float blade_count : hint_range(2.0, 10.0) = 4.0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.2;
uniform vec3 glow_tint : source_color = vec3(0.72, 0.42, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// angle around the arena centre drives the rotating pinwheel bands
	vec2 p = UV - vec2(0.5);
	float ang = atan(p.y, p.x);
	float sweep = 0.5 + 0.5 * cos(ang * blade_count - TIME * spin_speed * TAU);
	sweep = pow(sweep, 1.6);

	// slow global breathing so the whole carving softly brightens and dims
	float breathe = 0.5 + 0.5 * sin(TIME * breathe_speed * TAU);
	float pulse = sweep * (0.25 + 0.75 * breathe);

	// glyphs closest to the central emblem burn a little brighter than the wall band,
	// even at the dim end of the windmill sweep
	float centre = 1.0 - smoothstep(0.06, 0.38, length(p));
	float rest = mix(base_alpha, 0.42, centre);
	float boost = mix(1.0, 1.3, centre);

	float alpha = clamp(tex.a * mix(rest, 1.0, pulse) * boost, 0.0, 1.0);
	vec3 col = mix(tex.rgb, tex.rgb + glow_tint * 0.4, pulse) * mix(1.0, 1.12, centre);
	COLOR = vec4(col, alpha);
}
