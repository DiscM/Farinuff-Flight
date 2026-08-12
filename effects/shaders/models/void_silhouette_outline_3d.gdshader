shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

// Electric inverted-hull contour for the void silhouette. The dark expanded
// hull is intentionally kept behind the main body as a one-pixel separation
// band; the body shader supplies the inner cyan/lime and magenta fringe.

uniform vec4 rim_color : source_color = vec4(0.12, 1.0, 0.72, 1.0);
uniform vec4 fringe_color : source_color = vec4(1.0, 0.03, 0.55, 1.0);
uniform float outline_width : hint_range(0.0, 0.5) = 0.18;
uniform float outline_energy : hint_range(0.0, 5.0) = 1.25;
uniform float fringe_strength : hint_range(0.0, 1.0) = 0.72;

instance uniform vec4 instance_modulate : source_color = vec4(1.0);
instance uniform float instance_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 instance_outline_override : source_color = vec4(0.0);


void vertex() {
	VERTEX += NORMAL * outline_width;
}


void fragment() {
	vec3 active_rim = mix(
		rim_color.rgb,
		instance_outline_override.rgb,
		instance_outline_override.a
	);
	float side_bias = clamp(0.5 - normalize(NORMAL).x * 0.5, 0.0, 1.0);
	float fringe = smoothstep(0.58, 0.94, side_bias) * fringe_strength;
	vec3 color = mix(active_rim, fringe_color.rgb, fringe);
	color *= max(instance_modulate.rgb, vec3(0.22));
	color = mix(color, vec3(1.0), instance_flash);

	ALBEDO = color;
	EMISSION = mix(color * outline_energy, vec3(2.8), instance_flash);
}
