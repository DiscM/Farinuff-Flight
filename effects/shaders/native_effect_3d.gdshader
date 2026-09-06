shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

instance uniform vec4 instance_color : source_color = vec4(0.15, 0.85, 1.0, 1.0);
instance uniform vec4 instance_accent : source_color = vec4(0.85, 1.0, 1.0, 1.0);
instance uniform float instance_alpha : hint_range(0.0, 1.0) = 1.0;
instance uniform float instance_emission : hint_range(0.0, 8.0) = 2.0;
instance uniform float instance_phase = 0.0;


void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radius = length(centered);
	float disc = 1.0 - smoothstep(0.08, 1.0, radius);
	float rim = 1.0 - smoothstep(0.28, 0.84, radius);
	float bands = 0.76 + 0.24 * sin((UV.x + UV.y) * 22.0 + instance_phase);
	float accent = clamp(rim * 0.72 + abs(centered.x) * 0.18, 0.0, 1.0);
	vec3 color = mix(instance_color.rgb, instance_accent.rgb, accent);
	float alpha = disc * bands * instance_alpha * instance_color.a;
	ALBEDO = color;
	EMISSION = color * instance_emission * (0.55 + rim * 0.9);
	ALPHA = alpha;
}
