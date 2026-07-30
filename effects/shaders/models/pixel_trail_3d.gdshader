shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// PixelPlanets-style engine trail: the fade down the tail is posterized into
// discrete bands and the band edges dissolve through the same checkerboard
// dither grid as the hull shading. No smooth gradients.

uniform vec4 trail_color : source_color = vec4(0.02, 0.72, 1.0, 1.0);
uniform float trail_energy : hint_range(0.0, 6.0) = 2.6;
uniform float trail_bands : hint_range(2.0, 5.0) = 3.0;
instance uniform float instance_phase_offset = 0.0;


void fragment() {
	float pulse = 0.82 + 0.18 * sin(TIME * 9.0 + instance_phase_offset);
	float tail = 1.0 - UV.y;
	bool dith = mod(FRAGCOORD.x + FRAGCOORD.y, 2.0) < 1.0;
	tail += dith ? 0.45 / trail_bands : 0.0;
	float band = clamp(floor(tail * trail_bands), 0.0, trail_bands - 1.0);
	float strength = ((band + 1.0) / trail_bands) * pulse;
	float hot_core = step(abs(UV.x * 2.0 - 1.0), 0.36);
	vec3 color = mix(trail_color.rgb, vec3(0.90, 0.98, 1.0), hot_core * 0.65);
	ALBEDO = color * trail_energy * 0.4;
	ALPHA = strength;
}
