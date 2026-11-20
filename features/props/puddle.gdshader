shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

void fragment() {
	vec2 patch = (UV - vec2(0.5)) * 2.0;
	float edge = 1.0 - smoothstep(0.65, 1.0, length(patch));
	float grazing = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = mix(vec3(0.025, 0.033, 0.038), vec3(0.06, 0.085, 0.11), grazing);
	METALLIC = 0.1;
	ROUGHNESS = 0.14 + sin(UV.x * 53.0 + UV.y * 17.0) * 0.015;
	SPECULAR = 0.8;
	// A faint sky tint at grazing angles keeps unlit water from reading as a hole.
	EMISSION = vec3(0.015, 0.024, 0.036) * grazing;
	ALPHA = edge * mix(0.45, 0.8, grazing);
}
