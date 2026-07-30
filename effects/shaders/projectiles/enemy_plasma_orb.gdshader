shader_type canvas_item;
render_mode blend_add;

// Hostile plasma orb, restyled to the PixelPlanets recipe: radial shading is
// posterized into three flat bands (dark rim, class-tint mid, hot core) on a
// chunky pixel grid, with checkerboard dither at the band boundaries. The
// reflected-shock ring stays as a flat gameplay tell.

uniform float phase_offset = 0.0;
uniform float reflected_amount : hint_range(0.0, 1.0) = 0.0;
uniform float orb_pixels : hint_range(8.0, 32.0) = 16.0;

varying vec4 projectile_modulate;


void vertex() {
	projectile_modulate = COLOR;
}


void fragment() {
	vec4 projectile_tint = projectile_modulate;
	vec2 puv = (floor(UV * orb_pixels) + 0.5) / orb_pixels;
	vec2 point = puv * 2.0 - 1.0;
	float radius = length(point);
	float angle = atan(point.y, point.x);
	float time = TIME * 9.0 + phase_offset;
	bool dith = mod(FRAGCOORD.x + FRAGCOORD.y, 2.0) < 1.0;

	// Posterized radial bands; checker pixels nudge the boundary outward.
	float rr = radius + (dith ? 0.045 : 0.0);
	float band = clamp(floor((1.05 - rr) * 3.0), 0.0, 2.0);

	float tint_energy = max(max(projectile_tint.r, projectile_tint.g), projectile_tint.b);
	vec3 tint = projectile_tint.rgb / max(tint_energy, 0.001);
	tint_energy = clamp(tint_energy, 0.7, 3.0);

	vec3 color = tint * tint_energy * 0.42;
	if (band > 0.5) {
		color = tint * tint_energy * 0.85;
	}
	if (band > 1.5) {
		color = vec3(1.0, 0.96, 0.86);
	}
	float turbulence = 0.78 + 0.22 * step(0.0, sin(angle * 6.0 - time + radius * 19.0));
	color *= turbulence;

	float shell = step(abs(radius - 0.47), 0.05);
	color += tint * shell * 0.7;

	float reflected_ring = step(abs(radius - (0.68 + sin(time * 0.55) * 0.035)), 0.05);
	reflected_ring *= reflected_amount;
	color += vec3(0.12, 1.0, 0.6) * reflected_ring * 1.4;
	color = mix(color, color * vec3(0.3, 1.15, 0.72), reflected_amount * 0.38);

	float alpha = 0.0;
	if (radius <= 1.0) {
		alpha = band > 0.5 ? 1.0 : (dith ? 0.75 : 0.45);
	}
	alpha = clamp(alpha + shell + reflected_ring, 0.0, 1.0);
	COLOR = vec4(color, alpha * projectile_tint.a);
}
