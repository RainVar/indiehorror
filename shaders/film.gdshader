shader_type canvas_item;
render_mode unshaded;
uniform float danger : hint_range(0.0, 1.0) = 0.0;
uniform float grain_strength : hint_range(0.0, 0.1) = 0.018;
uniform bool reduced_motion = false;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.3, 1.35, length(p * vec2(0.82, 0.8)));
	float t = reduced_motion ? 0.0 : floor(TIME * 12.0);
	float noise = fract(sin(dot(floor(FRAGCOORD.xy / 2.0), vec2(12.9898, 78.233)) + t) * 43758.5453);
	COLOR = vec4(mix(vec3(0.005,0.009,0.008),vec3(0.18,0.012,0.006),danger * 0.45), edge * (0.48 + danger * 0.2) + noise * grain_strength);
}
