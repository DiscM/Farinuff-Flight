shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// 3D translation of the enemy-evolution sprite treatment. The script preserves
// each GLB surface's authored base color while these uniforms add the shared
// animated energy language.
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

// Per-entity feedback stays instance-local so every enemy of a matching class
// and generation can share the same surface materials.
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

	// Project the sprite shader's circuit buses across the ship's X/Z plane.
	vec2 panel_uv = model_position.xz * pattern_scale;
	vec2 panel_cell = floor(panel_uv);
	vec2 panel_edge = abs(fract(panel_uv) - 0.5);
	float circuit_line = 1.0 - smoothstep(0.035, 0.105, min(panel_edge.x, panel_edge.y));
	float circuit_gate = step(0.44, hash21(panel_cell + phase_offset + instance_phase_offset));
	float scan = 1.0 - smoothstep(
		0.0,
		0.52,
		abs(fract(model_position.z * 0.34 - time * 0.24 + phase_offset) - 0.5)
	);
	float circuitry = circuit_line * circuit_gate * circuit_amount * (0.34 + scan * 0.9);

	// Generation III's hot diagonal veins wrap naturally around the low-poly
	// hull because the pattern is evaluated in object space.
	float vein_path = abs(
		fract(
			model_position.x * 1.8
			+ model_position.z * 2.2
			+ sin(model_position.z * 8.0 + phase_offset + instance_phase_offset) * 0.17
		) - 0.5
	);
	float heat_veins = (1.0 - smoothstep(0.025, 0.095, vein_path));
	heat_veins *= heat_amount * (0.68 + pulse * 0.42);

	// The apex state breaks selected horizontal rows into bright interference.
	float interference_row = floor(model_position.z * 9.0);
	float interference_gate = step(
		0.80,
		hash21(vec2(interference_row, floor(time * 10.0) + phase_offset + instance_phase_offset))
	);
	float interference = interference_gate * apex_amount;
	float apex_wave = 0.5 + 0.5 * sin(model_position.z * 16.0 - time * 7.0 + model_position.x * 4.0);
	apex_wave *= apex_amount;

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.6);
	vec3 body = base_color.rgb;
	body = mix(body, active_energy, evolution_level * 0.08);
	body = mix(body, active_accent, circuitry * 0.74);
	body += vec3(1.0, 0.13, 0.025) * heat_veins * 0.7;
	body = mix(body, active_accent * 1.22, interference * 0.48);
	body *= instance_modulate.rgb;
	body = mix(body, vec3(1.0), instance_flash);

	ALBEDO = body;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = 0.72;

	vec3 energy = active_energy * fresnel * (0.32 + evolution_level * 0.62);
	energy += active_accent * circuitry;
	energy += vec3(1.0, 0.16, 0.025) * heat_veins * 1.2;
	energy += active_accent * (interference * 1.4 + apex_wave * 0.16);
	energy += active_energy * emission_strength * 0.08 * pulse;
	energy *= max(instance_modulate.rgb, vec3(0.18));
	EMISSION = mix(energy * emission_strength, vec3(2.4), instance_flash);
}
