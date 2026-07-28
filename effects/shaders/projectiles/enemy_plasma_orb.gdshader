shader_type canvas_item;
render_mode blend_add;

// Hostile plasma keeps the color selected by each enemy attack while adding
// an animated core, rotating turbulence, and a distinct reflected shock ring.
uniform float phase_offset = 0.0;
uniform float reflected_amount : hint_range(0.0, 1.0) = 0.0;

varying vec4 projectile_modulate;


void vertex() {
	projectile_modulate = COLOR;
}


void fragment() {
	vec4 projectile_tint = projectile_modulate;
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	float angle = atan(point.y, point.x);
	float time = TIME * 9.0 + phase_offset;

	float body = smoothstep(0.55, 0.2, radius);
	float core = smoothstep(0.26, 0.04, radius);
	float halo = smoothstep(0.98, 0.34, radius);
	float shell = smoothstep(0.055, 0.0, abs(radius - 0.47));
	float turbulence = 0.66 + 0.34 * sin(angle * 6.0 - time + radius * 19.0);

	float tint_energy = max(max(projectile_tint.r, projectile_tint.g), projectile_tint.b);
	vec3 tint = projectile_tint.rgb / max(tint_energy, 0.001);
	tint_energy = clamp(tint_energy, 0.7, 3.0);

	vec3 color = tint * tint_energy * (body * (0.72 + turbulence * 0.48) + halo * 0.2);
	color += vec3(1.0, 0.96, 0.86) * core * (1.1 + turbulence * 0.35);
	color += tint * shell * 0.85;

	float reflected_ring = smoothstep(0.045, 0.0, abs(radius - (0.68 + sin(time * 0.55) * 0.035)));
	reflected_ring *= reflected_amount;
	color += vec3(0.12, 1.0, 0.6) * reflected_ring * 1.4;
	color = mix(color, color * vec3(0.3, 1.15, 0.72), reflected_amount * 0.38);

	float alpha = clamp(body + halo * 0.5 + shell + reflected_ring, 0.0, 1.0);
	COLOR = vec4(color, alpha * projectile_tint.a);
}
