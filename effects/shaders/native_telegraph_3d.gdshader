shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4 base_color : source_color = vec4(1.0, 0.12, 0.04, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.82, 0.24, 1.0);
uniform float emission_strength : hint_range(0.0, 8.0) = 3.0;


void fragment() {
	float edge = 1.0 - smoothstep(0.06, 0.46, abs(UV.x - 0.5));
	float pulse = 0.55 + 0.45 * sin(TIME * 18.0);
	float sweep = smoothstep(0.0, 0.22, fract(UV.y * 5.0 - TIME * 2.6));
	float band = max(edge, sweep * 0.5);
	vec3 color = mix(base_color.rgb, accent_color.rgb, pulse * 0.45);
	ALBEDO = color;
	EMISSION = color * emission_strength * (0.55 + band * 0.9);
	ALPHA = clamp(band * (0.42 + pulse * 0.42), 0.0, 0.95);
}
