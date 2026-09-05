shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	float bands = pow(0.5 + 0.5 * sin(UV.y * 70.0 - TIME * 3.0), 10.0);
	vec3 energy = vec3(0.08, 0.65, 1.0);
	ALBEDO = energy;
	EMISSION = energy * (0.5 + rim * 2.0);
	ALPHA = clamp(rim * 0.55 + bands * 0.09, 0.0, 0.7);
}
