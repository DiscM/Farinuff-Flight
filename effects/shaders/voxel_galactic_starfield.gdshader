shader_type canvas_item;

// Block-aware galaxy backdrop. The existing nebula recipe is retained, but
// evaluated on a coarse screen grid and quantized into a compact palette so
// the background reads like layered voxel tiles instead of smooth gas.
uniform float u_time = 0.0;
uniform float drift_speed : hint_range(0.0, 0.2) = 0.035;
uniform float nebula_strength : hint_range(0.0, 1.5) = 1.1;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;

uniform vec4 space_color : source_color = vec4(0.003, 0.009, 0.042, 1.0);
uniform vec4 nebula_blue : source_color = vec4(0.02, 0.32, 0.82, 1.0);
uniform vec4 nebula_violet : source_color = vec4(0.08, 0.12, 0.62, 1.0);
uniform vec4 nebula_pink : source_color = vec4(0.12, 0.72, 0.92, 1.0);

uniform float voxel_grid_size : hint_range(48.0, 180.0) = 90.0;
uniform float voxel_palette_steps : hint_range(4.0, 16.0) = 8.0;
uniform float voxel_edge_strength : hint_range(0.0, 0.4) = 0.08;


float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


vec2 hash2(vec2 p) {
	return vec2(
		hash(p + vec2(19.17, 3.41)),
		hash(p + vec2(7.13, 83.73))
	);
}


float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 blend = local * local * (3.0 - 2.0 * local);

	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x),
		blend.y
	);
}


float fbm(vec2 p) {
	float result = 0.0;
	float amplitude = 0.52;
	mat2 rotation = mat2(vec2(0.88, -0.48), vec2(0.48, 0.88));

	for (int octave = 0; octave < 5; octave++) {
		result += value_noise(p) * amplitude;
		p = rotation * p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return result;
}


vec3 star_layer(
	vec2 uv,
	float scale,
	vec2 drift,
	float rarity,
	float radius,
	vec3 tint,
	float glint
) {
	vec2 grid = uv * scale + drift;
	vec2 cell = floor(grid);
	vec2 seed = hash2(cell);
	vec2 star_position = (seed - 0.5) * 0.72;
	vec2 from_star = fract(grid) - 0.5 - star_position;

	float present = smoothstep(rarity, 1.0, seed.x);
	float distance_to_star = length(from_star);
	float core = smoothstep(radius, 0.0, distance_to_star);
	float halo = smoothstep(radius * 5.0, 0.0, distance_to_star) * 0.22;

	float twinkle_rate = mix(1.2, 3.8, seed.y);
	float twinkle = 0.72 + 0.28 * sin(u_time * twinkle_rate + seed.x * 37.0);

	float rays = smoothstep(0.018, 0.0, min(abs(from_star.x), abs(from_star.y)));
	rays *= smoothstep(0.34, 0.0, max(abs(from_star.x), abs(from_star.y)));
	rays *= glint * seed.y;

	return tint * present * (core + halo + rays) * twinkle;
}


void fragment() {
	vec2 cell_uv = fract(UV * voxel_grid_size);
	vec2 quantized_uv = (floor(UV * voxel_grid_size) + 0.5) / voxel_grid_size;
	float aspect_ratio = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = (quantized_uv - 0.5) * vec2(aspect_ratio, 1.0);
	vec2 travel = vec2(u_time * drift_speed * 0.08, -u_time * drift_speed);

	vec2 nebula_uv = uv * 2.15 + travel * 0.18;
	vec2 warp = vec2(
		fbm(nebula_uv * 0.72 + vec2(2.4, 7.1)),
		fbm(nebula_uv * 0.72 + vec2(9.2, 1.8))
	) - 0.5;

	float broad_cloud = fbm(nebula_uv + warp * 1.85);
	float fine_cloud = fbm(nebula_uv * 2.55 - warp * 1.2 + vec2(4.6, -2.3));
	float filaments = 1.0 - abs(fbm(nebula_uv * 3.4 + warp) * 2.0 - 1.0);

	float cloud_mask = smoothstep(0.26, 0.72, broad_cloud * 0.72 + fine_cloud * 0.28);
	float filament_mask = smoothstep(0.36, 0.84, filaments) * cloud_mask;
	float dust_lane = smoothstep(0.38, 0.67, fbm(nebula_uv * 1.7 - warp * 1.4));

	vec3 color = space_color.rgb;
	color += vec3(0.006, 0.01, 0.035) * (1.0 - quantized_uv.y);

	vec3 gas_color = mix(nebula_blue.rgb, nebula_violet.rgb, smoothstep(0.28, 0.82, fine_cloud));
	gas_color = mix(gas_color, nebula_pink.rgb, filament_mask * 0.72);
	color += gas_color * cloud_mask * nebula_strength;
	color += nebula_pink.rgb * filament_mask * 0.12 * nebula_strength;
	color *= mix(1.0, 0.68, dust_lane * cloud_mask * 0.58);

	vec2 star_uv = uv + vec2(0.0, 0.5);
	color += star_layer(
		star_uv, 72.0, travel * 0.35, 0.955, 0.050,
		vec3(0.55, 0.72, 1.0), 0.0
	) * 0.42 * star_brightness;
	color += star_layer(
		star_uv, 43.0, travel * 0.9 + vec2(11.7, 3.2), 0.972, 0.055,
		vec3(0.8, 0.9, 1.0), 0.08
	) * 0.72 * star_brightness;
	color += star_layer(
		star_uv, 25.0, travel * 1.8 + vec2(5.3, 19.1), 0.982, 0.060,
		vec3(1.0, 0.87, 0.76), 0.23
	) * 1.15 * star_brightness;

	vec2 vignette_uv = quantized_uv * (1.0 - quantized_uv.yx);
	float vignette = pow(clamp(vignette_uv.x * vignette_uv.y * 18.0, 0.0, 1.0), 0.18);
	color *= mix(0.62, 1.0, vignette);

	// A single dark edge on each coarse cell gives the nebula a tile-like
	// structure without turning the whole sky into a distracting grid.
	float cell_edge = step(min(cell_uv.x, cell_uv.y), 0.085);
	color = mix(color, color * 0.72, cell_edge * voxel_edge_strength);
	color = floor(max(color, vec3(0.0)) * voxel_palette_steps + 0.5) / voxel_palette_steps;

	COLOR = vec4(color, 1.0);
}
