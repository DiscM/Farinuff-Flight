shader_type spatial;
render_mode unshaded, cull_disabled;

// Spatial counterpart to galactic_starfield.gdshader. It lets the same
// blue/violet nebula palette sit physically behind a 2.5D ship layer.
uniform float u_time = 18.0;
uniform float nebula_strength : hint_range(0.0, 1.5) = 1.08;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;
uniform vec4 space_color : source_color = vec4(0.003, 0.009, 0.042, 1.0);
uniform vec4 nebula_blue : source_color = vec4(0.02, 0.32, 0.82, 1.0);
uniform vec4 nebula_violet : source_color = vec4(0.08, 0.12, 0.62, 1.0);
uniform vec4 nebula_pink : source_color = vec4(0.12, 0.72, 0.92, 1.0);


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


vec2 hash22(vec2 point) {
	return vec2(
		hash21(point + vec2(19.17, 3.41)),
		hash21(point + vec2(7.13, 83.73))
	);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), blend.x),
		blend.y
	);
}


float fbm(vec2 point) {
	float result = 0.0;
	float amplitude = 0.52;
	mat2 rotation = mat2(vec2(0.88, -0.48), vec2(0.48, 0.88));
	for (int octave = 0; octave < 5; octave++) {
		result += value_noise(point) * amplitude;
		point = rotation * point * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return result;
}


vec3 star_layer(vec2 uv, float scale, float rarity, float radius, vec3 tint, float glint) {
	vec2 grid = uv * scale;
	vec2 cell = floor(grid);
	vec2 seed = hash22(cell);
	vec2 star_position = (seed - 0.5) * 0.72;
	vec2 from_star = fract(grid) - 0.5 - star_position;
	float present = smoothstep(rarity, 1.0, seed.x);
	float distance_to_star = length(from_star);
	float core = smoothstep(radius, 0.0, distance_to_star);
	float halo = smoothstep(radius * 5.0, 0.0, distance_to_star) * 0.22;
	float rays = smoothstep(0.018, 0.0, min(abs(from_star.x), abs(from_star.y)));
	rays *= smoothstep(0.34, 0.0, max(abs(from_star.x), abs(from_star.y)));
	return tint * present * (core + halo + rays * glint);
}


void fragment() {
	vec2 uv = (UV - 0.5) * vec2(1.78, 1.0);
	vec2 nebula_uv = uv * 2.15 + vec2(u_time * 0.003, -u_time * 0.008);
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
	vec3 gas_color = mix(nebula_blue.rgb, nebula_violet.rgb, smoothstep(0.28, 0.82, fine_cloud));
	gas_color = mix(gas_color, nebula_pink.rgb, filament_mask * 0.72);
	color += gas_color * cloud_mask * nebula_strength;
	color += nebula_pink.rgb * filament_mask * 0.12 * nebula_strength;
	color *= mix(1.0, 0.68, dust_lane * cloud_mask * 0.58);
	color += star_layer(uv, 72.0, 0.955, 0.05, vec3(0.55, 0.72, 1.0), 0.0) * 0.42 * star_brightness;
	color += star_layer(uv + vec2(11.7, 3.2), 43.0, 0.972, 0.055, vec3(0.8, 0.9, 1.0), 0.08) * 0.72 * star_brightness;
	color += star_layer(uv + vec2(5.3, 19.1), 25.0, 0.982, 0.06, vec3(1.0, 0.87, 0.76), 0.23) * 1.15 * star_brightness;

	vec2 vignette_uv = UV * (1.0 - UV.yx);
	float vignette = pow(clamp(vignette_uv.x * vignette_uv.y * 18.0, 0.0, 1.0), 0.18);
	color *= mix(0.62, 1.0, vignette);
	ALBEDO = color;
	EMISSION = color;
}
