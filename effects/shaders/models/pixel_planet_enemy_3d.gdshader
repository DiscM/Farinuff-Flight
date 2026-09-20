shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// PixelPlanets-inspired armor: quantized coordinates, noise-shaped light bands,
// three palette entries, and checker dithering only at the band boundaries.
// Reference: Deep-Fold's MIT-licensed NoAtmosphere and GasLayers shaders.
// See res://effects/shaders/PixelPlanets/LICENSE and design/pixel-enemies/README.md.
// Mesh normals supply the form that the 2D planets synthesize with a sphere.
uniform vec4 base_color : source_color = vec4(0.64, 0.025, 0.035, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_disable;
uniform bool has_albedo_texture = false;
uniform sampler2D emission_texture : source_color, filter_nearest_mipmap, repeat_disable;
uniform bool has_emission_texture = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_strength : hint_range(0.0, 12.0) = 0.0;
uniform vec4 shadow_color : source_color = vec4(0.13, 0.10, 0.23, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.79, 0.65, 1.0);
uniform vec3 key_light_direction = vec3(-0.48, 0.35, 0.80);
uniform float terrain_scale : hint_range(0.1, 5.0) = 1.35;
uniform float terrain_strength : hint_range(0.0, 1.0) = 0.72;
uniform float shadow_border : hint_range(0.0, 1.0) = 0.40;
uniform float light_border : hint_range(0.0, 1.0) = 0.72;
uniform float dither_width : hint_range(0.0, 0.2) = 0.065;

// Keep the first six slots identical to imported_enemy_surface_3d.gdshader.
// Every surface on an actor shares its feedback, never a mutable material.
instance uniform vec4 instance_modulate : source_color = vec4(1.0);
instance uniform float instance_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform float instance_phase_offset = 0.0;
instance uniform float instance_animation_time = 0.0;
instance uniform vec4 instance_energy_override : source_color = vec4(0.0);
instance uniform vec4 instance_accent_override : source_color = vec4(0.0);
instance uniform float instance_pixel_density = 8.0;
// Static mesh-to-hull rows align separate GLB parts on one actor-local grid.
instance uniform vec4 instance_hull_row_x = vec4(1.0, 0.0, 0.0, 0.0);
instance uniform vec4 instance_hull_row_y = vec4(0.0, 1.0, 0.0, 0.0);
instance uniform vec4 instance_hull_row_z = vec4(0.0, 0.0, 1.0, 0.0);

varying vec3 hull_position;
varying vec3 hull_normal;

float hash_cell(vec2 cell) {
	cell = fract(cell * vec2(123.34, 456.21));
	cell += dot(cell, cell + 45.32 + instance_phase_offset);
	return fract(cell.x * cell.y);
}

float value_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 fraction = fract(position);
	vec2 curve = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(
		mix(hash_cell(cell), hash_cell(cell + vec2(1.0, 0.0)), curve.x),
		mix(hash_cell(cell + vec2(0.0, 1.0)), hash_cell(cell + vec2(1.0)), curve.x),
		curve.y
	);
}

float terrain(vec2 position) {
	float value = 0.0;
	float weight = 0.5;
	// Fixed cost; the planet shader's configurable 20 octaves are unnecessary
	// on a moving hull that occupies a few dozen pixels.
	for (int octave = 0; octave < 3; octave++) {
		value += value_noise(position) * weight;
		position = position * 2.03 + vec2(7.1, 3.7);
		weight *= 0.5;
	}
	return value;
}

void vertex() {
	vec4 point = vec4(VERTEX, 1.0);
	hull_position = vec3(
		dot(instance_hull_row_x, point),
		dot(instance_hull_row_y, point),
		dot(instance_hull_row_z, point)
	);
	hull_normal = normalize(vec3(
		dot(instance_hull_row_x.xyz, NORMAL),
		dot(instance_hull_row_y.xyz, NORMAL),
		dot(instance_hull_row_z.xyz, NORMAL)
	));
}

void fragment() {
	// Texture paint remains under the existing stepped lighting. UV sampling is
	// nearest-filtered to preserve the atlas's deliberately crisp markings.
	vec2 atlas_uv = UV * uv_scale + uv_offset;
	vec3 painted = has_albedo_texture ? texture(albedo_texture, atlas_uv).rgb : vec3(1.0);
	vec3 surface_color = base_color.rgb * painted;
	vec3 surface_emission = emission_color.rgb;
	if (has_emission_texture) {
		surface_emission *= texture(emission_texture, atlas_uv).rgb;
	}
	// Dominant-axis mapping also gives vertical armor faces square cells.
	vec3 axis = abs(hull_normal);
	vec2 surface_position = hull_position.xz;
	if (axis.x > axis.y && axis.x > axis.z) {
		surface_position = hull_position.zy;
	} else if (axis.z > axis.y) {
		surface_position = hull_position.xy;
	}
	float density = max(instance_pixel_density, 1.0);
	vec2 cell = floor(surface_position * density);
	vec2 pixel_position = (cell + 0.5) / density;
	float checker = mod(cell.x + cell.y, 2.0);
	// Terrain and checker share the grid and stay attached during turns/drift.
	vec2 land_position = pixel_position * terrain_scale + vec2(4.7, 12.3);
	float land = terrain(land_position);
	float clouds = terrain(land_position * vec2(0.7, 1.5) + land * 1.8);
	float light = clamp(dot(normalize(NORMAL), normalize(key_light_direction)), 0.0, 1.0);
	float shade = 0.15 + light * 0.78 + (clouds - 0.43) * terrain_strength;
	// Dither only within a narrow shade transition, not across the whole hull.
	float middle = step(shadow_border + checker * dither_width, shade);
	float bright = step(light_border + checker * dither_width, shade);

	float panel_luma = dot(surface_color, vec3(0.2126, 0.7152, 0.0722));
	float panel = smoothstep(0.015, 0.12, panel_luma);
	vec3 dark_tone = mix(surface_color * 0.30, shadow_color.rgb, panel * 0.72);
	vec3 middle_tone = mix(dark_tone, surface_color, 0.66);
	vec3 light_tone = mix(surface_color, highlight_color.rgb, panel * 0.14);
	vec3 color = mix(dark_tone, middle_tone, middle);
	color = mix(color, light_tone, bright);
	vec3 glow = vec3(0.0);

	if (emission_strength > 0.0) {
		vec3 energy = mix(surface_emission, instance_energy_override.rgb, instance_energy_override.a * 0.55);
		vec3 accent = mix(highlight_color.rgb, instance_accent_override.rgb, instance_accent_override.a);
		// Pause-aware, stepped reactor light. Armor itself never scrolls.
		float time = floor(instance_animation_time * 8.0) / 8.0;
		float pulse = step(0.2, sin(time * 2.2 + instance_phase_offset));
		float hot_cell = step(0.74, hash_cell(cell + vec2(23.1, 8.4))) * pulse;
		color = mix(energy * 0.82, accent, hot_cell * 0.48);
		// Reactor paint/slots also remain legible beneath generation feedback.
		color *= painted;
		glow = color * min(emission_strength, 1.2) * (0.24 + pulse * 0.08);
	}

	// Feedback applies after both armor and reactor shading, including glow.
	float flash = clamp(instance_flash, 0.0, 1.0);
	ALBEDO = mix(color * instance_modulate.rgb, vec3(1.0), flash);
	EMISSION = mix(glow * instance_modulate.rgb, vec3(1.5), flash);
}
