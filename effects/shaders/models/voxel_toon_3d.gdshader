shader_type spatial;
render_mode unshaded, cull_back;

// First-pass voxel treatment for the shared 3D fleet renderer. The mesh still
// supplies the silhouette; this shader makes the presentation block-aware by
// quantizing facet lighting, limiting the palette, and adding restrained cell
// variation. It deliberately keeps the pixel_toon_3d uniform contract so the
// material library and player upgrade assembly can switch styles without
// changing gameplay or model attachment code.

uniform vec4 base_color : source_color = vec4(0.18, 0.24, 0.34, 1.0);
uniform vec4 energy_color : source_color = vec4(0.02, 0.72, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.76, 0.95, 1.0, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.55;
uniform float roughness : hint_range(0.05, 1.0) = 0.3;
uniform float evolution_level : hint_range(0.0, 1.0) = 0.0;
uniform float circuit_amount : hint_range(0.0, 1.0) = 0.25;
uniform float heat_amount : hint_range(0.0, 1.0) = 0.0;
uniform float apex_amount : hint_range(0.0, 1.0) = 0.0;
uniform float emission_strength : hint_range(0.0, 4.0) = 0.7;
uniform float phase_offset = 0.0;
uniform float pattern_scale : hint_range(0.5, 12.0) = 3.6;
uniform float animation_speed : hint_range(0.0, 2.0) = 1.0;

uniform vec3 key_light_dir = vec3(-0.53, 0.12, 0.84);
uniform float band_count : hint_range(2.0, 6.0) = 4.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;
uniform float emissive_surface : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(0.0);

// Voxel controls are intentionally small and stable at the game's 2x
// low-resolution ship viewport. The geometry remains responsible for the
// silhouette while these controls make smooth imported meshes read as blocks.
uniform float voxel_normal_steps : hint_range(2.0, 8.0) = 4.0;
uniform float voxel_palette_variation : hint_range(0.0, 0.4) = 0.08;
uniform float voxel_edge_strength : hint_range(0.0, 1.0) = 0.06;

instance uniform vec4 instance_modulate : source_color = vec4(1.0);
instance uniform float instance_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform float instance_phase_offset = 0.0;
instance uniform vec4 instance_energy_override : source_color = vec4(0.0);
instance uniform vec4 instance_accent_override : source_color = vec4(0.0);

varying vec3 model_position;


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


float hash31(vec3 point) {
	return fract(sin(dot(point, vec3(17.13, 41.71, 73.27))) * 43758.5453);
}


vec3 quantize_normal(vec3 normal, float steps) {
	vec3 snapped = floor(normalize(normal) * steps + vec3(0.5)) / steps;
	return normalize(snapped + vec3(0.0001));
}


void vertex() {
	model_position = VERTEX;
}


void fragment() {
	float time = TIME * animation_speed + phase_offset + instance_phase_offset;
	float pulse = 0.72 + 0.28 * sin(time * (2.3 + evolution_level * 2.2));
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

	vec3 voxel_normal = quantize_normal(NORMAL, voxel_normal_steps);
	float ndl = clamp(dot(voxel_normal, normalize(key_light_dir)), 0.0, 1.0);
	float light_value = 0.16 + 0.84 * ndl;
	bool dith = mod(FRAGCOORD.x + FRAGCOORD.y, 2.0) < 1.0;
	light_value += (dith ? 0.45 / band_count : 0.0) * dither_strength;
	float band = clamp(floor(light_value * band_count), 0.0, band_count - 1.0);
	float shade = 0.24 + band * 0.285;
	vec3 body = base_color.rgb * shade;
	if (band >= band_count - 0.5) {
		body = body * 0.88 + vec3(0.12);
	}

	// Keep color variation within the same four-step ramp so voxel faces do
	// not turn into noisy procedural texture.
	float cell_variation = hash31(floor(model_position * 5.0));
	body *= 1.0 + (cell_variation - 0.5) * voxel_palette_variation;

	// A restrained cell seam helps smooth fallback meshes read as block-built;
	// authored voxel meshes can reduce this parameter without changing code.
	vec3 cell_position = abs(fract(model_position * 5.0) - 0.5);
	float cell_edge = 1.0 - smoothstep(
		0.40,
		0.49,
		min(cell_position.x, min(cell_position.y, cell_position.z))
	);
	body = mix(body, body * 0.70, cell_edge * voxel_edge_strength);

	vec2 panel_uv = model_position.xz * pattern_scale;
	vec2 panel_cell = floor(panel_uv);
	vec2 panel_edge = abs(fract(panel_uv) - 0.5);
	float circuit_line = 1.0 - smoothstep(0.035, 0.105, min(panel_edge.x, panel_edge.y));
	float circuit_gate = step(0.44, hash21(panel_cell + phase_offset));
	float scan = step(
		0.30,
		1.0 - abs(fract(model_position.z * 0.34 - time * 0.24 + phase_offset) - 0.5) * 2.0
	);
	float circuitry = circuit_line * circuit_gate * circuit_amount * (0.5 + scan * 0.5);
	body = mix(body, active_accent, clamp(circuitry, 0.0, 1.0));

	float vein_path = abs(
		fract(
			model_position.x * 1.8
			+ model_position.z * 2.2
			+ sin(model_position.z * 8.0 + phase_offset + instance_phase_offset) * 0.17
		) - 0.5
	);
	float heat_veins = step(vein_path, 0.055) * heat_amount * (0.7 + pulse * 0.3);
	body = mix(body, vec3(1.0, 0.16, 0.03), clamp(heat_veins, 0.0, 1.0));

	float interference_row = floor(model_position.z * 9.0);
	float interference = step(
		0.80,
		hash21(vec2(interference_row, floor(time * 10.0) + phase_offset + instance_phase_offset))
	) * apex_amount;
	body = mix(body, active_accent, interference);

	float rim_f = 1.0 - clamp(dot(voxel_normal, normalize(VIEW)), 0.0, 1.0);
	float rim = step(0.66, rim_f) * (0.20 + evolution_level * 0.30);
	body = mix(body, active_energy, rim);

	body *= instance_modulate.rgb;
	body = mix(body, vec3(1.0), instance_flash);

	vec3 glow_base = mix(active_energy, glow_color.rgb, glow_color.a);
	vec3 glow = glow_base * (1.45 + (dith ? 0.25 : 0.0)) * max(emission_strength, 0.6);
	vec3 pixel_color = mix(body, glow, emissive_surface);

	ALBEDO = pixel_color;
	EMISSION = vec3(1.2) * instance_flash;
}
