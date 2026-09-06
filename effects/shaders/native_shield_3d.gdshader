shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

instance uniform vec4 instance_color : source_color = vec4(0.08, 0.65, 1.0, 1.0);
instance uniform float instance_pulse : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.25);
	float bands = pow(0.5 + 0.5 * sin(UV.y * 70.0 - TIME * 3.0), 10.0);
	float scan = 1.0 - smoothstep(0.0, 0.18, abs(fract(UV.y * 8.0 - TIME * 0.7) - 0.5));
	float pulse = 0.82 + 0.18 * instance_pulse;
	vec3 energy = instance_color.rgb;
	ALBEDO = energy;
	EMISSION = energy * pulse * (0.5 + rim * 2.0 + scan * 0.4);
	ALPHA = clamp((rim * 0.58 + bands * 0.1 + scan * 0.06) * instance_pulse, 0.0, 0.78);
}
