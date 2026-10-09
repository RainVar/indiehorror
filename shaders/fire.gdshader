shader_type spatial;
render_mode unshaded, cull_disabled;

void vertex() {
	float tip = clamp(UV.y, 0.0, 1.0);
	VERTEX.x += sin(TIME * 7.0 + VERTEX.y * 3.0) * 0.14 * tip;
	VERTEX.z += cos(TIME * 5.0 + VERTEX.y * 4.0) * 0.09 * tip;
}

void fragment() {
	vec3 ember = vec3(0.85, 0.08, 0.008);
	vec3 core = vec3(1.0, 0.55, 0.025);
	ALBEDO = mix(core, ember, clamp(UV.y, 0.0, 1.0));
	EMISSION = ALBEDO * 1.3;
}
