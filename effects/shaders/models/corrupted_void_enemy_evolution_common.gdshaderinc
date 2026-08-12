// Shared implementation for the four regular-enemy corrupted-void stages.
// Each stage wrapper defines VOID_STAGE before including this file. Keeping the
// interface identical lets the material library swap stages without changing
// per-instance feedback or palette overrides.

uniform vec4 base_color : source_color = vec4(0.18, 0.24, 0.34, 1.0);
uniform vec4 energy_color : source_color = vec4(1.0, 0.035, 0.12, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.58, 0.68, 1.0);
uniform vec4 violet_shadow : source_color = vec4(0.09, 0.012, 0.18, 1.0);
uniform vec4 violet_fringe : source_color = vec4(0.90, 0.04, 1.0, 1.0);
uniform float violet_bias : hint_range(0.0, 1.0) = 0.34;
uniform float rim_power : hint_range(0.5, 8.0) = 2.0;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.34;
uniform float rim_strength : hint_range(0.0, 5.0) = 1.55;
uniform float fringe_strength : hint_range(0.0, 2.0) = 0.72;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.05, 1.0) = 0.86;
uniform float evolution_level : hint_range(0.0, 1.0) = 0.0;
uniform float circuit_amount : hint_range(0.0, 1.0) = 0.25;
uniform float heat_amount : hint_range(0.0, 1.0) = 0.0;
uniform float apex_amount : hint_range(0.0, 1.0) = 0.0;
uniform float emission_strength : hint_range(0.0, 6.0) = 0.7;
uniform float phase_offset = 0.0;
uniform float pattern_scale : hint_range(0.5, 12.0) = 3.6;
uniform float animation_speed : hint_range(0.0, 2.0) = 1.0;

// Stage-specific detail controls. The material library supplies the authored
// values; these defaults keep the shader useful when inspected by itself.
uniform float fracture_density : hint_range(0.0, 1.0) = 0.15;
uniform float node_amount : hint_range(0.0, 1.0) = 0.0;
uniform float reactor_focus : hint_range(0.0, 1.0) = 0.0;

uniform vec3 key_light_dir = vec3(-0.53, 0.12, 0.84);
uniform float band_count : hint_range(2.0, 6.0) = 4.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;
uniform float emissive_surface : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(0.0);

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
	float stage = float(VOID_STAGE);
	float stage_level = clamp((stage - 1.0) / 3.0, 0.0, 1.0);
	float time = TIME * animation_speed + phase_offset + instance_phase_offset;
	float pulse = 0.78 + 0.22 * sin(time * (2.2 + stage_level * 2.6));
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

	// Posterized light bands keep the low-resolution silhouette readable while
	// the palette-tinted violet shadow carries the corrupted-void identity.
	float ndl = clamp(
		dot(normalize(NORMAL), normalize(key_light_dir)),
		0.0,
		1.0
	);
	float light_value = 0.12 + 0.88 * ndl;
	bool dith = mod(FRAGCOORD.x + FRAGCOORD.y, 2.0) < 1.0;
	light_value += (dith ? 0.34 / band_count : 0.0) * dither_strength;
	float band = clamp(
		floor(light_value * band_count),
		0.0,
		band_count - 1.0
	);
	float shade = 0.28 + band * 0.22;
	vec3 palette_shadow = active_energy * (0.22 + stage_level * 0.035);
	palette_shadow += active_accent * (0.06 + stage_level * 0.025);
	vec3 body_tint = mix(
		palette_shadow,
		violet_shadow.rgb,
		violet_bias + stage_level * 0.06
	);
	vec3 body = body_tint * shade;

	// Preserve just enough authored material to separate the GLB's facets.
	float authored_luma = dot(base_color.rgb, vec3(0.2126, 0.7152, 0.0722));
	body += body_tint * (0.012 + authored_luma * 0.035);

	// Gen II adds an intentional conduit lattice. The hash gate breaks it into
	// readable runs instead of painting a uniform grid over the whole hull.
	vec2 panel_uv = model_position.xz * pattern_scale;
	vec2 panel_cell = floor(panel_uv);
	vec2 panel_local = fract(panel_uv) - 0.5;
	float grid_x = 1.0 - smoothstep(0.026, 0.075, abs(panel_local.x));
	float grid_y = 1.0 - smoothstep(0.026, 0.075, abs(panel_local.y));
	float lattice = max(grid_x, grid_y);
	float lattice_gate = step(
		0.45,
		hash21(panel_cell + vec2(4.7, 12.3) + phase_offset)
	);
	float crack_path = abs(
		fract(
			model_position.x * 1.8
			+ model_position.z * 2.2
			+ sin(model_position.z * 8.0 + time) * 0.17
		) - 0.5
	);
	float crack_line = 1.0 - smoothstep(0.022, 0.070, crack_path);
	float crack_gate = step(
		0.52,
		hash21(panel_cell + phase_offset + instance_phase_offset)
	);
	float fractures = max(
		crack_line * crack_gate,
		lattice * lattice_gate * (0.28 + stage_level * 0.18)
	);
	fractures *= circuit_amount * (0.64 + fracture_density * 0.36);
	body = mix(body, active_accent * (0.44 + pulse * 0.22), fractures);

	// Small junction points make the latter two stages read as a network rather
	// than random cracks. They stay sparse in Gen II and become denser in Gen IV.
	float node = 1.0 - smoothstep(0.025, 0.105, length(panel_local));
	float node_gate = step(
		0.60,
		hash21(panel_cell + vec2(21.7, 3.1) + instance_phase_offset)
	);
	float nodes = node * node_gate * node_amount;
	body = mix(body, active_accent * (0.70 + pulse * 0.28), nodes);

	// Gen III's heat layer follows broken diagonal veins and shifts toward the
	// enemy's own energy color instead of introducing a foreign palette.
	float vein_path = abs(
		fract(
			model_position.x * 1.8
			+ model_position.z * 2.2
			+ sin(model_position.z * 8.0 + time + instance_phase_offset) * 0.17
		) - 0.5
	);
	float heat_veins = 1.0 - smoothstep(0.018, 0.072, vein_path);
	heat_veins *= heat_amount * (0.64 + pulse * 0.46);
	body = mix(body, active_energy * (0.68 + pulse * 0.20), heat_veins);

	// Gen IV breaks selected rows into short interference fragments. The
	// fragment gate is deliberately sparse so the radial aura remains the focal
	// escalation rather than becoming a full-screen scanline wash.
	float interference_row = floor(model_position.z * (8.0 + stage * 2.0));
	float interference_gate = step(
		0.78,
		hash21(vec2(
			interference_row,
			floor(time * 10.0) + phase_offset + instance_phase_offset
		))
	);
	float interference = interference_gate * apex_amount;
	float apex_wave = sin(
		model_position.z * 16.0
		- time * 7.0
		+ model_position.x * 4.0
	);
	apex_wave = (0.5 + 0.5 * apex_wave) * apex_amount;
	body = mix(body, active_accent * 1.18, interference * 0.48);

	// The violet template's bright rim is palette-driven: the enemy accent owns
	// most of the edge, with a one-sided violet/magenta fringe.
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, rim_power);
	float rim = smoothstep(rim_threshold, 0.90, fresnel);
	float side_bias = clamp(0.5 - normalize(NORMAL).x * 0.5, 0.0, 1.0);
	float fringe = rim * smoothstep(0.56, 0.94, side_bias);
	vec3 edge_color = mix(
		active_accent,
		violet_fringe.rgb,
		clamp(fringe * fringe_strength * (0.70 + apex_amount * 0.30), 0.0, 1.0)
	);
	edge_color *= 0.86 + pulse * 0.14;
	body += edge_color * rim * 0.18;

	// Authored emissive surfaces remain the reactor/core focal point. The later
	// stages increase focus without erasing the hull's dark facets.
	vec3 source_glow = mix(active_energy, glow_color.rgb, glow_color.a);
	float core = emissive_surface * (0.92 + pulse * 0.08);
	vec3 core_glow = source_glow * core * (1.30 + emission_strength * 0.44);
	core_glow *= 1.0 + reactor_focus * 0.55;
	core_glow += active_accent * (0.04 + stage_level * 0.08);
	core_glow += violet_fringe.rgb * apex_amount * 0.10;
	core_glow += active_energy * heat_amount * (0.16 + pulse * 0.12);
	core_glow += active_accent * nodes * 0.28;
	core_glow += active_accent * apex_wave * 0.14;

	body *= instance_modulate.rgb;
	body = mix(body, vec3(1.0), instance_flash);
	core_glow *= max(instance_modulate.rgb, vec3(0.18));
	core_glow = mix(core_glow, vec3(2.8), instance_flash);

	ALBEDO = body;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = edge_color * rim * rim_strength + core_glow;
}
