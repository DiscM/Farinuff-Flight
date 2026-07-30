shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

// Inverted-hull silhouette outline for the pixel toon fleet. Where the neon
// outline glowed in each class's energy color, the pixel style draws the
// shared "void" rim every planet has: a flat, unlit, near-black band exactly
// one low-res buffer pixel thick.

uniform vec4 outline_color : source_color = vec4(0.016, 0.020, 0.043, 1.0);
uniform float outline_width : hint_range(0.0, 0.5) = 0.18;
// Kept for interface parity with neon_outline_3d.gdshader; unused.
uniform float outline_energy : hint_range(0.0, 5.0) = 1.8;
instance uniform vec4 instance_modulate : source_color = vec4(1.0);
instance uniform float instance_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 instance_outline_override : source_color = vec4(0.0);


void vertex() {
	VERTEX += NORMAL * outline_width;
}


void fragment() {
	vec3 color = mix(
		outline_color.rgb,
		instance_outline_override.rgb,
		instance_outline_override.a
	);
	color = mix(color, vec3(1.0), instance_flash);
	ALBEDO = color;
}
