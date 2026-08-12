shader_type canvas_item;
render_mode blend_add;

// Block-aware variant of enemy_plasma_orb.gdshader. Hostile and reflected
// states remain driven by the same tint and reflected_amount uniforms.
uniform float phase_offset = 0.0;
uniform float reflected_amount : hint_range(0.0, 1.0) = 0.0;
uniform float orb_pixels : hint_range(8.0, 32.0) = 16.0;
uniform float voxel_cell_scale : hint_range(4.0, 16.0) = 8.0;
uniform float voxel_face_contrast : hint_range(0.0, 0.4) = 0.16;

varying vec4 projectile_modulate;


void vertex() {
	projectile_modulate = COLOR;
}


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


void fragment() {
	vec4 projectile_tint = projectile_modulate;
	vec2 puv = (floor(UV * orb_pixels) + 0.5) / orb_pixels;
	vec2 point = puv * 2.0 - 1.0;
	vec2 cell_id = floor(puv * voxel_cell_scale);
	vec2 cell_uv = fract(puv * voxel_cell_scale);
	float square_radius = max(abs(point.x), abs(point.y));
	float radial_radius = length(point);
	float angle = atan(point.y, point.x);
	float time = TIME * 9.0 + phase_offset;
	bool dith = mod(FRAGCOORD.x + FRAGCOORD.y, 2.0) < 1.0;

	float tint_energy = max(max(projectile_tint.r, projectile_tint.g), projectile_tint.b);
	vec3 tint = projectile_tint.rgb / max(tint_energy, 0.001);
	tint_energy = clamp(tint_energy, 0.7, 3.0);

	// Square-radius bands create stepped voxel corners while radial bands keep
	// the orb recognizable as plasma rather than a flat UI icon.
	float shell = step(abs(square_radius - 0.53), 0.12);
	float body = step(square_radius, 0.78);
	float mid = step(square_radius, 0.56);
	float hot_core = step(square_radius, 0.28);
	float cell_light = 1.0 + (step(0.48, hash21(cell_id)) - 0.5) * voxel_face_contrast;
	float cell_seam = step(min(cell_uv.x, cell_uv.y), 0.10) * body;
	float turbulence = 0.80 + 0.20 * step(0.0, sin(angle * 6.0 - time + radial_radius * 19.0));

	vec3 color = tint * tint_energy * 0.36 * body;
	color = mix(color, tint * tint_energy * 0.78, mid);
	color = mix(color, vec3(1.0, 0.96, 0.86), hot_core);
	color *= cell_light * turbulence;
	color += tint * shell * 0.68;
	color = mix(color, color * vec3(0.42, 0.62, 0.82), cell_seam * 0.5);

	float reflected_ring = step(abs(radial_radius - (0.68 + sin(time * 0.55) * 0.035)), 0.05);
	reflected_ring *= reflected_amount;
	color += vec3(0.12, 1.0, 0.6) * reflected_ring * 1.4;
	color = mix(color, color * vec3(0.3, 1.15, 0.72), reflected_amount * 0.38);

	float alpha = body * (mid > 0.5 ? 1.0 : (dith ? 0.78 : 0.5));
	alpha = clamp(alpha + shell + reflected_ring, 0.0, 1.0);
	COLOR = vec4(color, alpha * projectile_tint.a);
}
