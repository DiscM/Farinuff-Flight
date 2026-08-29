shader_type spatial;
render_mode unshaded, cull_back;

// PixelPlanets-style toon treatment for the 3D ship fleet. Replaces the neon
// PBR look with the recipe the background planet shaders use: light from one
// origin posterized into discrete bands, checkerboard dither at the band
// boundaries, and flat emissive surfaces for engines/reactors.
//
// The uniform and instance-uniform interface matches neon_ship_3d.gdshader so
// the material library, player assembly, and synchronizer keep working
// unchanged. metallic/roughness are accepted for parity but unused.

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

// Pixel-style parameters.
// Direction toward the key light in view space (upper-left, camera side);
// derived from the layer's KeyLight rotation (-52, -24, 0).
uniform vec3 key_light_dir = vec3(-0.53, 0.12, 0.84);
uniform float band_count : hint_range(2.0, 6.0) = 4.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;
// 1.0 when the GLB surface is authored emissive (engines, reactors, canopy):
// those pixels stay hot with a dither sparkle instead of taking light bands.
uniform float emissive_surface : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(0.0);

// Per-entity feedback stays instance-local so every enemy of a matching class
// and generation can share the same surface materials.
instance uniform vec4 instance_modulate : source_color = vec4(1.0);
instance uniform float instance_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform float instance_phase_offset = 0.0;
instance uniform vec4 instance_base_override : source_color = vec4(0.0);
instance uniform vec4 instance_energy_override : source_color = vec4(0.0);
instance uniform vec4 instance_accent_override : source_color = vec4(0.0);
instance uniform vec4 instance_glow_override : source_color = vec4(0.0);

varying vec3 model_position;


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


void vertex() {
	model_position = VERTEX;
}


void fragment() {
	float time = TIME * animation_speed + phase_offset + instance_phase_offset;
	float pulse = 0.72 + 0.28 * sin(time * (2.3 + evolution_level * 2.2));
	vec3 active_base = mix(
		base_color.rgb,
		instance_base_override.rgb,
		instance_base_override.a
	);
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

	// Posterized light bands from one fixed key light (the planet recipe).
	float ndl = clamp(dot(normalize(NORMAL), normalize(key_light_dir)), 0.0, 1.0);
	float light_value = 0.16 + 0.84 * ndl;
	// The same dither() the PixelPlanets shaders use: a 2px checkerboard that
	// nudges boundary pixels into the next band.
	bool dith = mod(FRAGCOORD.x + FRAGCOORD.y, 2.0) < 1.0;
	light_value += (dith ? 0.45 / band_count : 0.0) * dither_strength;
	float band = clamp(floor(light_value * band_count), 0.0, band_count - 1.0);
	float shade = 0.28 + band * 0.285;
	vec3 body = active_base * shade;
	if (band >= band_count - 0.5) {
		// The lit limb lifts toward white, like a planet's day side.
		body = body * 0.88 + vec3(0.12);
	}

	// Evolution overlays painted as flat pixels after the banding, never
	// blended gradients: circuit buses, heat veins, apex interference.
	vec2 panel_uv = model_position.xz * pattern_scale;
	vec2 panel_cell = floor(panel_uv);
	vec2 panel_edge = abs(fract(panel_uv) - 0.5);
	float circuit_line = 1.0 - smoothstep(0.035, 0.105, min(panel_edge.x, panel_edge.y));
	float circuit_gate = step(0.44, hash21(panel_cell + phase_offset + instance_phase_offset));
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

	// Rim light as a stepped band instead of a fresnel gradient.
	float rim_f = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = step(0.66, rim_f) * (0.20 + evolution_level * 0.30);
	body = mix(body, active_energy, rim);

	body *= instance_modulate.rgb;
	body = mix(body, vec3(1.0), instance_flash);

	// Emissive GLB surfaces (engines, reactors, canopy glass) ignore the light
	// bands and stay hot, with a checker sparkle from the same dither grid.
	vec4 active_glow = mix(glow_color, instance_glow_override, instance_glow_override.a);
	vec3 glow_base = mix(active_energy, active_glow.rgb, active_glow.a);
	vec3 glow = glow_base * (1.45 + (dith ? 0.25 : 0.0)) * max(emission_strength, 0.6);
	vec3 pixel_color = mix(body, glow, emissive_surface);

	ALBEDO = pixel_color;
	EMISSION = vec3(1.2) * instance_flash;
}
