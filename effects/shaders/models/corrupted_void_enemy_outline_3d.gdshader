shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

// Palette-driven inverted-hull contour for regular enemies. The magenta
// contribution keeps the corrupted-void family visible while each archetype
// retains its existing energy/accent identity.

uniform vec4 energy_color : source_color = vec4(1.0, 0.035, 0.12, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.58, 0.68, 1.0);
uniform vec4 violet_fringe : source_color = vec4(0.90, 0.04, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.5) = 0.18;
uniform float outline_energy : hint_range(0.0, 5.0) = 1.35;
uniform float fringe_strength : hint_range(0.0, 1.0) = 0.72;

instance uniform vec4 instance_modulate : source_color = vec4(1.0);
instance uniform float instance_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 instance_outline_override : source_color = vec4(0.0);


void vertex() {
	VERTEX += NORMAL * outline_width;
}


void fragment() {
	vec3 active_accent = mix(
		accent_color.rgb,
		instance_outline_override.rgb,
		instance_outline_override.a
	);
	vec3 base_edge = mix(active_accent, energy_color.rgb, 0.22);
	float side_bias = clamp(0.5 - normalize(NORMAL).x * 0.5, 0.0, 1.0);
	float fringe = smoothstep(0.56, 0.94, side_bias) * fringe_strength;
	vec3 color = mix(base_edge, violet_fringe.rgb, fringe);
	color *= max(instance_modulate.rgb, vec3(0.22));
	color = mix(color, vec3(1.0), instance_flash);

	ALBEDO = color;
	EMISSION = mix(color * outline_energy, vec3(2.8), instance_flash);
}
