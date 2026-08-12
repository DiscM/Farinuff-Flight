shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Void silhouette treatment for the butterfly player and its attached
// hardware. The hull stays nearly black so the shape reads as a silhouette;
// a screen-facing fresnel contour and authored emissive surfaces carry the
// readable color.

uniform vec4 silhouette_color : source_color = vec4(0.005, 0.008, 0.024, 1.0);
uniform vec4 base_color : source_color = vec4(0.18, 0.24, 0.34, 1.0);
uniform vec4 energy_color : source_color = vec4(0.02, 0.72, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.76, 0.95, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.12, 1.0, 0.72, 1.0);
uniform vec4 fringe_color : source_color = vec4(1.0, 0.03, 0.55, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.38;
uniform float rim_strength : hint_range(0.0, 5.0) = 1.45;
uniform float fringe_strength : hint_range(0.0, 2.0) = 0.72;
uniform float scan_amount : hint_range(0.0, 1.0) = 0.08;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.05, 1.0) = 0.85;
uniform float evolution_level : hint_range(0.0, 1.0) = 0.25;
uniform float circuit_amount : hint_range(0.0, 1.0) = 0.0;
uniform float heat_amount : hint_range(0.0, 1.0) = 0.0;
uniform float apex_amount : hint_range(0.0, 1.0) = 0.0;
uniform float emission_strength : hint_range(0.0, 6.0) = 1.0;
uniform float emissive_surface : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(0.0);
uniform float phase_offset = 0.0;
uniform float pattern_scale : hint_range(0.5, 12.0) = 3.6;
uniform float animation_speed : hint_range(0.0, 2.0) = 1.0;

// These instance uniforms mirror the other ship shaders so the existing
// synchronizer can continue to drive hit flashes and per-entity tints.
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
	float pulse = 0.82 + 0.18 * sin(time * 2.4);
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

	// A discrete plane value keeps the body from becoming a flat black cutout
	// while preserving the chunky low-poly/pixel read of the current renderer.
	vec3 key_light = normalize(vec3(-0.44, 0.76, 0.48));
	float plane_light = clamp(dot(normalize(NORMAL), key_light), 0.0, 1.0);
	float plane_band = floor(plane_light * 3.0) / 2.0;
	vec3 body = silhouette_color.rgb * (0.72 + plane_band * 0.10);

	// Keep a tiny amount of the authored material color in the shadow so
	// different modules do not collapse into one indistinguishable black mass.
	float authored_luma = dot(base_color.rgb, vec3(0.2126, 0.7152, 0.0722));
	body += active_energy * (0.012 + authored_luma * 0.018);

	// Screen-facing fresnel makes the silhouette trace itself without needing
	// a post-process blur. The companion inverted hull adds the dark separation
	// band behind this edge.
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, rim_power);
	float rim = smoothstep(rim_threshold, 0.90, fresnel);
	float side_bias = clamp(0.5 - normalize(NORMAL).x * 0.5, 0.0, 1.0);
	float fringe = rim * smoothstep(0.58, 0.94, side_bias) * fringe_strength;
	float grid = mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0);
	float scan = 1.0 - scan_amount + scan_amount * (
		0.5 + 0.5 * sin(model_position.z * 18.0 - time * 4.0)
	);
	vec3 contour = mix(rim_color.rgb, fringe_color.rgb, clamp(fringe, 0.0, 1.0));
	contour *= scan * (0.84 + grid * 0.08) * pulse;
	body += contour * rim * 0.22;

	// Authored emissive GLB surfaces are the bright energy cores: engine
	// lights, eye-spots, canopy inserts, and upgrade accents retain their
	// source emission instead of being swallowed by the silhouette.
	vec3 source_glow = mix(active_energy, glow_color.rgb, glow_color.a);
	float core = emissive_surface * (0.92 + pulse * 0.08);
	vec3 core_glow = source_glow * core * (1.35 + emission_strength * 0.42);

	// A restrained, dithered accent sweep gives upgraded modules a little life
	// without turning the whole hull into a moving gradient.
	float cell_gate = step(
		0.84,
		hash21(floor(model_position.xz * pattern_scale) + time * 0.25)
	);
	float accent_spark = cell_gate * circuit_amount * (0.35 + apex_amount * 0.65);
	core_glow += active_accent * accent_spark * 0.32;
	core_glow += vec3(1.0, 0.12, 0.025) * heat_amount * 0.22;

	body *= instance_modulate.rgb;
	body = mix(body, vec3(1.0), instance_flash);
	core_glow *= max(instance_modulate.rgb, vec3(0.18));
	core_glow = mix(core_glow, vec3(2.8), instance_flash);

	ALBEDO = body;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = contour * rim * rim_strength + core_glow;
}
