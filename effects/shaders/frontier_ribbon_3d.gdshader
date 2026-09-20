shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

void fragment() {
	float core = pow(1.0 - abs(UV.x * 2.0 - 1.0), 1.4);
	vec3 cyan = vec3(0.04, 0.63, 0.88);
	vec3 ice = vec3(0.55, 0.93, 1.0);
	vec3 energy = mix(cyan, ice, core * COLOR.r);
	// Nozzle vertices carry thrust in negative V. A brief ignition reaches
	// white at the center while the world-space wake retains its quiet cyan.
	float nozzle_power = max(-UV.y, 0.0);
	float white_peak = clamp((nozzle_power - 0.9) * 0.85, 0.0, 0.65);
	energy = mix(energy, vec3(0.93, 0.99, 1.0), white_peak * core);
	ALBEDO = energy;
	EMISSION = energy * (0.55 + core * 1.2) * (1.0 + max(nozzle_power - 0.9, 0.0) * 0.45);
	ALPHA = COLOR.a * (0.16 + core * 0.84);
}
