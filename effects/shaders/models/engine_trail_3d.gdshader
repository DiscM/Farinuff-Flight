shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 trail_color : source_color = vec4(0.02, 0.72, 1.0, 1.0);
uniform float trail_energy : hint_range(0.0, 6.0) = 2.6;
instance uniform float instance_phase_offset = 0.0;


void fragment() {
	float pulse = 0.78 + 0.22 * sin(TIME * 9.0 + instance_phase_offset);
	float tail_fade = pow(1.0 - UV.y, 1.35);
	float hot_core = pow(1.0 - abs(UV.x * 2.0 - 1.0), 2.2);
	vec3 color = mix(trail_color.rgb, vec3(0.88, 0.98, 1.0), hot_core * 0.68);
	float strength = tail_fade * pulse * (0.58 + hot_core * 0.56);
	ALBEDO = color;
	EMISSION = color * trail_energy * strength;
	ALPHA = strength * trail_color.a;
}
