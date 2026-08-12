shader_type canvas_item;
render_mode blend_add;

// Block-aware variant of player_bolt.gdshader. It keeps the same gameplay
// uniforms while replacing smooth energy transitions with stepped faces,
// chunky cells, and a restrained four-color voxel ramp.
uniform vec4 core_color : source_color = vec4(0.82, 1.0, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.02, 0.72, 1.0, 1.0);
uniform float piercing_amount : hint_range(0.0, 1.0) = 0.0;
uniform float explosive_amount : hint_range(0.0, 1.0) = 0.0;
uniform float zigzag_amount : hint_range(0.0, 1.0) = 0.0;
uniform float phase_offset = 0.0;
uniform float bolt_pixels : hint_range(8.0, 32.0) = 16.0;
uniform float voxel_cell_scale : hint_range(4.0, 16.0) = 8.0;
uniform float voxel_face_contrast : hint_range(0.0, 0.4) = 0.12;

varying vec4 projectile_modulate;


void vertex() {
	projectile_modulate = COLOR;
}


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


float capsule_sdf(vec2 point, vec2 start, vec2 end, float radius) {
	vec2 from_start = point - start;
	vec2 axis = end - start;
	float projection = clamp(dot(from_start, axis) / dot(axis, axis), 0.0, 1.0);
	return length(from_start - axis * projection) - radius;
}


void fragment() {
	vec4 vertex_color = projectile_modulate;
	vec2 puv = (floor(UV * bolt_pixels) + 0.5) / bolt_pixels;
	vec2 point = puv * 2.0 - 1.0;
	vec2 cell_id = floor(puv * voxel_cell_scale);
	vec2 cell_uv = fract(puv * voxel_cell_scale);
	float time = TIME * 12.0 + phase_offset;
	bool dith = mod(FRAGCOORD.x + FRAGCOORD.y, 2.0) < 1.0;

	float distance_to_body = capsule_sdf(point, vec2(0.0, 0.46), vec2(0.0, -0.48), 0.13);
	float body = step(distance_to_body, 0.045);
	float mid = step(distance_to_body, -0.02);
	float hot_core = step(distance_to_body, -0.085);
	float halo = step(distance_to_body, 0.20) * (1.0 - body);

	// Each block gets a small face bias, not random noise. This keeps the bolt
	// readable at the game's low resolution while breaking up the smooth tube.
	float face_hash = hash21(cell_id);
	float face_light = 1.0 + (step(0.48, face_hash) - 0.5) * voxel_face_contrast;
	float cell_seam = step(min(cell_uv.x, cell_uv.y), 0.10) * body;
	float flow = step(0.0, sin(point.y * 22.0 + time)) * 0.20;
	float tail = step(0.30, point.y);
	tail *= step(abs(point.x + sin(point.y * 17.0 + time) * 0.035), 0.16);
	tail *= 0.55 + 0.45 * step(0.5, fract(point.y * 6.0 - time * 0.15));

	float piercing_spine = step(abs(point.x), 0.045);
	piercing_spine *= step(abs(point.y), 0.80) * piercing_amount;

	float ring_radius = length(point * vec2(1.0, 0.82));
	float explosive_ring = step(abs(ring_radius - 0.43), 0.05);
	explosive_ring *= (0.70 + 0.30 * step(0.0, sin(time * 0.72))) * explosive_amount;

	float arc_position = 0.34 + sin(point.y * 13.0 - time * 1.2) * 0.065;
	float electric_arcs = step(abs(abs(point.x) - arc_position), 0.045);
	electric_arcs *= step(abs(point.y), 0.80) * zigzag_amount;

	vec3 color = glow_color.rgb * 0.42 * body;
	color = mix(color, glow_color.rgb, mid);
	color = mix(color, core_color.rgb, hot_core);
	color *= face_light * (0.92 + flow);
	color += glow_color.rgb * halo * (dith ? 0.52 : 0.28);
	color += core_color.rgb * piercing_spine * 1.4;
	color += vec3(1.0, 0.28, 0.035) * explosive_ring * 1.25;
	color += vec3(0.38, 0.62, 1.0) * electric_arcs;
	color += glow_color.rgb * tail * 0.7;
	color = mix(color, color * vec3(0.55, 0.70, 0.84), cell_seam * 0.55);

	float alpha = clamp(body + halo * (dith ? 0.9 : 0.55) + tail * 0.7
		+ piercing_spine + explosive_ring + electric_arcs, 0.0, 1.0);
	COLOR = vec4(color * vertex_color.rgb, alpha * vertex_color.a);
}
