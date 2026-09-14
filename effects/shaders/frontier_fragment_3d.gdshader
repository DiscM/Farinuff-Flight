shader_type spatial;
render_mode cull_disabled, depth_draw_never;

instance uniform vec4 fragment_color : source_color = vec4(1.0, 0.55, 0.22, 1.0);
instance uniform float fragment_fade = 1.0;
instance uniform float fragment_heat = 1.0;

void fragment() {
	ALBEDO = mix(vec3(0.10, 0.13, 0.18), fragment_color.rgb, 0.22 + fragment_heat * 0.4);
	ROUGHNESS = 0.65;
	EMISSION = fragment_color.rgb * (0.12 + fragment_heat * 1.8);
	ALPHA = fragment_fade;
}
