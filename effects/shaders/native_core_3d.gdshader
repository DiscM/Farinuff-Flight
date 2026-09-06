shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

instance uniform vec4 instance_color : source_color = vec4(0.15, 0.85, 1.0, 1.0);
instance uniform float instance_alpha : hint_range(0.0, 1.0) = 1.0;
instance uniform float instance_intensity : hint_range(0.0, 4.0) = 1.0;
instance uniform float instance_phase = 0.0;


void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.8);
	float core = 1.0 - smoothstep(0.05, 0.95, length(UV - vec2(0.5)) * 2.0);
	float pulse = 0.78 + 0.22 * sin(TIME * 10.0 + instance_phase);
	vec3 color = mix(instance_color.rgb, vec3(0.92, 0.99, 1.0), core * 0.72);
	float alpha = clamp((core * 0.72 + rim * 0.62) * pulse, 0.0, 1.0) * instance_alpha;
	ALBEDO = color;
	EMISSION = color * instance_intensity * (0.62 + core * 1.05 + rim * 0.46);
	ALPHA = alpha;
}
