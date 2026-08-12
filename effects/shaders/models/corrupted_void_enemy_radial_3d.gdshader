shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Contained aura used by the evolving regular-enemy hulls. The visible mesh is
// a back-plate behind the ship; broken pixel rings prevent it from reading as a
// clean neon circle, while the center stays tied to the enemy palette.

uniform vec4 energy_color : source_color = vec4(1.0, 0.035, 0.12, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.58, 0.68, 1.0);
uniform vec4 violet_fringe : source_color = vec4(0.90, 0.04, 1.0, 1.0);
uniform float evolution_level : hint_range(0.0, 1.0) = 0.0;
uniform float aura_strength : hint_range(0.0, 2.0) = 0.08;
uniform float ring_strength : hint_range(0.0, 2.0) = 0.0;
uniform float ring_count : hint_range(1.0, 12.0) = 4.0;
uniform float emission_strength : hint_range(0.0, 6.0) = 0.8;
uniform float phase_offset = 0.0;
uniform float animation_speed : hint_range(0.0, 2.0) = 1.0;

instance uniform vec4 instance_modulate : source_color = vec4(1.0);
instance uniform float instance_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform float instance_phase_offset = 0.0;
instance uniform vec4 instance_energy_override : source_color = vec4(0.0);
instance uniform vec4 instance_accent_override : source_color = vec4(0.0);

varying vec2 aura_uv;


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


void vertex() {
	aura_uv = UV;
}


void fragment() {
	float time = TIME * animation_speed + phase_offset + instance_phase_offset;
	vec3 active_energy = mix(
		energy_color.rgb,
		instance_energy_override.rgb,
		instance_energy_override.a
	);
	vec3 active_accent = mix(
		accent_color.rgb,
		instance_accent_override.rgb,
		instance_accent_override.a
	);

	// Quantizing the sampling coordinates gives the aura the same stepped pixel
	// language as the model viewport instead of a smooth post-process bloom.
	vec2 centered = aura_uv * 2.0 - 1.0;
	vec2 pixel_center = floor(centered * 48.0 + 0.5) / 48.0;
	float radius = length(pixel_center);
	float angle = atan(pixel_center.y, pixel_center.x);
	float mask = 1.0 - smoothstep(0.84, 1.0, radius);
	float stepped_falloff = floor(clamp(1.0 - radius, 0.0, 1.0) * 8.0) / 8.0;
	float source_falloff = 1.0 - smoothstep(0.02, 0.72, radius);

	// Broken rings and segmented ripples keep the outer field irregular. The
	// hash gates are stable in object UVs, so the pattern does not swim over the
	// ship as it moves through the screen.
	float ring_position = radius * ring_count + time * 0.12;
	float ring_distance = abs(fract(ring_position) - 0.5);
	float ring_line = 1.0 - smoothstep(0.065, 0.19, ring_distance);
	float ring_id = floor(radius * ring_count + 0.5);
	float angle_segment = floor((angle + 3.14159265) * 10.0 / 6.2831853);
	float broken_gate = step(
		0.38,
		hash21(vec2(ring_id, angle_segment) + phase_offset)
	);
	float rings = ring_line * broken_gate * ring_strength;

	float ripple_phase = radius * 31.0 - time * 2.6 + sin(angle * 5.0) * 1.4;
	float ripple = step(0.78, 0.5 + 0.5 * sin(ripple_phase));
	ripple *= step(0.42, hash21(vec2(
		floor(radius * 18.0),
		angle_segment + floor(time * 8.0)
	) + 8.0));
	ripple = ripple * ring_strength * 0.42;

	vec3 radial_color = mix(
		mix(active_energy, active_accent, 0.34),
		violet_fringe.rgb,
		smoothstep(0.24, 0.92, radius)
	);
	float pulse = 0.78 + 0.22 * sin(time * (2.0 + evolution_level * 2.8));
	float alpha = (
		stepped_falloff * 0.10
		+ source_falloff * 0.14
		+ rings * 0.42
		+ ripple * 0.18
	) * aura_strength * pulse * mask;
	alpha *= 0.84 + evolution_level * 0.16;

	vec3 output_color = radial_color * max(instance_modulate.rgb, vec3(0.18));
	output_color = mix(output_color, vec3(2.8), instance_flash);
	ALBEDO = output_color;
	EMISSION = output_color * (0.65 + emission_strength * 0.42);
	ALPHA = clamp(alpha + instance_flash * 0.22, 0.0, 1.0);
}
