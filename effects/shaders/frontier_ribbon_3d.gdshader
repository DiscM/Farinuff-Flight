shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

void fragment() {
	float core = pow(1.0 - abs(UV.x * 2.0 - 1.0), 1.4);
	vec3 cyan = vec3(0.04, 0.63, 0.88);
	vec3 ice = vec3(0.55, 0.93, 1.0);
	vec3 energy = mix(cyan, ice, core * COLOR.r);
	ALBEDO = energy;
	EMISSION = energy * (0.55 + core * 1.2);
	ALPHA = COLOR.a * (0.16 + core * 0.84);
}
