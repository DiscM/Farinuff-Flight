shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

instance uniform vec4 instance_color : source_color = vec4(0.15, 0.85, 1.0, 1.0);
instance uniform float instance_alpha : hint_range(0.0, 1.0) = 1.0;
instance uniform float instance_emission : hint_range(0.0, 8.0) = 2.0;


void fragment() {
	ALBEDO = instance_color.rgb;
	EMISSION = instance_color.rgb * instance_emission;
	ALPHA = instance_color.a * instance_alpha;
}
