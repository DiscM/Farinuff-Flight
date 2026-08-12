shader_type canvas_item;
render_mode blend_add;

// Small block-built orbital weapon with the same phase and palette controls
// as player_orbital.gdshader.
uniform vec4 core_color : source_color = vec4(0.78, 1.0, 0.96, 1.0);
uniform vec4 shell_color : source_color = vec4(0.04, 0.9, 0.72, 1.0);
uniform float phase_offset = 0.0;
uniform float voxel_cell_scale : hint_range(4.0, 16.0) = 8.0;
uniform float voxel_face_contrast : hint_range(0.0, 0.4) = 0.14;

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
	vec4 vertex_color = projectile_modulate;
	vec2 puv = (floor(UV * voxel_cell_scale * 2.0) + 0.5) / (voxel_cell_scale * 2.0);
	vec2 point = puv * 2.0 - 1.0;
	vec2 cell_id = floor(puv * voxel_cell_scale);
	vec2 cell_uv = fract(puv * voxel_cell_scale);
	float square_radius = max(abs(point.x), abs(point.y));
	float diamond_radius = abs(point.x) + abs(point.y);
	float angle = atan(point.y, point.x);
	float time = TIME * 4.5 + phase_offset;
	bool dith = mod(FRAGCOORD.x + FRAGCOORD.y, 2.0) < 1.0;

	float core = step(square_radius, 0.32) * step(diamond_radius, 0.58);
	float shell = step(abs(square_radius - 0.50), 0.095) * step(diamond_radius, 1.03);
	float halo = step(square_radius, 0.82);
	float rotating_charge = step(0.48, fract(angle / TAU * 3.0 - time * 0.07));
	rotating_charge *= step(square_radius, 0.70) * (1.0 - core);

	float face_light = 1.0 + (step(0.48, hash21(cell_id)) - 0.5) * voxel_face_contrast;
	float cell_seam = step(min(cell_uv.x, cell_uv.y), 0.10) * (core + shell);
	vec3 color = shell_color.rgb * halo * (dith ? 0.20 : 0.12);
	color += shell_color.rgb * shell * 1.0;
	color += core_color.rgb * core * 1.35;
	color += mix(shell_color.rgb, core_color.rgb, 0.5) * rotating_charge * 0.82;
	color *= face_light;
	color = mix(color, color * vec3(0.45, 0.68, 0.84), cell_seam * 0.5);

	float alpha = clamp(core + shell + halo * (dith ? 0.50 : 0.28)
		+ rotating_charge * 0.45, 0.0, 1.0);
	COLOR = vec4(color * vertex_color.rgb, alpha * vertex_color.a);
}
