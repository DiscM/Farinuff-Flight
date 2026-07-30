shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

// Inverted-hull outline: intentionally broad enough to survive the game's
// top-down camera and the CRT scanline pass.
uniform vec4 outline_color : source_color = vec4(0.02, 0.72, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.12) = 0.035;
uniform float outline_energy : hint_range(0.0, 5.0) = 1.8;
instance uniform vec4 instance_modulate : source_color = vec4(1.0);
instance uniform float instance_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 instance_outline_override : source_color = vec4(0.0);


void vertex() {
	VERTEX += NORMAL * outline_width;
}


void fragment() {
	vec3 active_outline = mix(
		outline_color.rgb,
		instance_outline_override.rgb,
		instance_outline_override.a
	);
	vec3 color = active_outline * max(instance_modulate.rgb, vec3(0.22));
	color = mix(color, vec3(1.0), instance_flash);
	ALBEDO = color;
	EMISSION = mix(color * outline_energy, vec3(2.8), instance_flash);
}
