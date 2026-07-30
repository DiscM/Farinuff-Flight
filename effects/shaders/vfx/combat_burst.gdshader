shader_type canvas_item;
render_mode unshaded, blend_add;

// Shared treatment for the original draw-call combat VFX. It brings the
// procedural geometry into the same neon-energy language as the projectile
// and evolution shaders without relying on an imported texture.
uniform vec4 primary_color : source_color = vec4(0.04, 0.78, 1.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.76, 0.16, 1.0, 1.0);
uniform vec4 hot_color : source_color = vec4(0.92, 1.0, 1.0, 1.0);
uniform float energy : hint_range(0.0, 2.0) = 1.0;
uniform float pixel_size : hint_range(1.0, 6.0) = 2.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.42;
uniform float reduced_flashing : hint_range(0.0, 1.0) = 0.0;
uniform float phase_offset = 0.0;

varying vec4 source_tint;


float bayer4(vec2 point) {
	vec2 cell = mod(floor(point), 4.0);
	float row_0 = 0.0;
	float row_1 = 0.0;
	float row_2 = 0.0;
	float row_3 = 0.0;

	if (cell.x < 1.0) {
		row_0 = 0.0;
		row_1 = 12.0;
		row_2 = 3.0;
		row_3 = 15.0;
	} else if (cell.x < 2.0) {
		row_0 = 8.0;
		row_1 = 4.0;
		row_2 = 11.0;
		row_3 = 7.0;
	} else if (cell.x < 3.0) {
		row_0 = 2.0;
		row_1 = 14.0;
		row_2 = 1.0;
		row_3 = 13.0;
	} else {
		row_0 = 10.0;
		row_1 = 6.0;
		row_2 = 9.0;
		row_3 = 5.0;
	}

	float value = row_3;
	if (cell.y < 1.0) {
		value = row_0;
	} else if (cell.y < 2.0) {
		value = row_1;
	} else if (cell.y < 3.0) {
		value = row_2;
	}
	return (value + 0.5) / 16.0;
}


void vertex() {
	source_tint = COLOR;
	float snap = max(pixel_size, 1.0);
	VERTEX = floor(VERTEX / snap + 0.5) * snap;
}


void fragment() {
	vec4 source = source_tint;
	float threshold = bayer4(FRAGCOORD.xy / max(pixel_size, 1.0));

	float strongest_channel = max(max(source.r, source.g), source.b);
	float secondary_weight = smoothstep(-0.08, 0.36, source.r - source.g);
	vec3 palette_color = mix(primary_color.rgb, secondary_color.rgb, secondary_weight);
	float channel_whiteness = min(min(source.r, source.g), source.b);
	float hot_weight = smoothstep(0.58, 0.92, channel_whiteness);
	palette_color = mix(palette_color, hot_color.rgb, hot_weight);

	// Four-level posterization and ordered coverage echo the authored pixel
	// planet treatment while retaining the silhouette of each draw primitive.
	float levels = 4.0;
	vec3 posterized = floor(
		palette_color * levels + vec3(threshold * dither_strength)
	) / levels;
	float source_energy = mix(0.62, 1.28, clamp(strongest_channel, 0.0, 1.0));
	float pulse_amount = mix(0.13, 0.025, reduced_flashing);
	float pulse = 1.0 + sin(TIME * 9.0 + phase_offset) * pulse_amount;
	vec3 output_color = posterized * source_energy * energy * pulse;

	float ordered_alpha = step(threshold, clamp(source.a, 0.0, 1.0));
	float output_alpha = mix(source.a, ordered_alpha, dither_strength);
	output_alpha *= mix(1.0, 0.74, reduced_flashing);

	COLOR = vec4(output_color, output_alpha);
}
