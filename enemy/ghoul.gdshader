shader_type canvas_item;

// The ghoul art sits on an opaque black background: key it out by brightness
// (soft edge), and allow a white hit flash.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float a = smoothstep(0.05, 0.22, max(COLOR.r, max(COLOR.g, COLOR.b)));
	vec3 c = mix(COLOR.rgb, vec3(1.0), flash);
	COLOR = vec4(c, a * COLOR.a);
}
