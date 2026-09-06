shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

instance uniform vec4 instance_color : source_color = vec4(0.15, 0.85, 1.0, 1.0);
instance uniform vec4 instance_accent : source_color = vec4(0.85, 1.0, 1.0, 1.0);
instance uniform float instance_alpha : hint_range(0.0, 1.0) = 1.0;
instance uniform float instance_emission : hint_range(0.0, 8.0) = 2.0;
instance uniform float instance_phase = 0.0;


void fragment() {
	vec2 centered = UV - vec2(0.5);
	float tube = length(centered) * 2.0;
	float edge = 1.0 - smoothstep(0.12, 1.0, tube);
	float band = 0.72 + 0.28 * sin(UV.x * 34.0 - TIME * 8.0 + instance_phase);
	float scan = 0.78 + 0.22 * sin(UV.y * 18.0 + TIME * 5.0);
	vec3 color = mix(instance_color.rgb, instance_accent.rgb, clamp(band * 0.72, 0.0, 1.0));
	float alpha = edge * band * scan * instance_alpha * instance_color.a;
	ALBEDO = color;
	EMISSION = color * instance_emission * (0.46 + edge * 0.72);
	ALPHA = alpha;
}
