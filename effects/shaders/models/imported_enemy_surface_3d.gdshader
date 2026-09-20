shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// PBR bridge for authored Blender materials. The adapter copies each GLB
// surface into these uniforms while instance uniforms keep pooled damage and
// generation feedback cheap and per-enemy.
uniform vec4 base_color : source_color = vec4(0.18, 0.24, 0.34, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_disable;
uniform bool has_albedo_texture = false;
uniform sampler2D emission_texture : source_color, filter_nearest_mipmap, repeat_disable;
uniform bool has_emission_texture = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_strength : hint_range(0.0, 12.0) = 0.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.05, 1.0) = 0.5;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.34;

instance uniform vec4 instance_modulate : source_color = vec4(1.0);
instance uniform float instance_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform float instance_phase_offset = 0.0;
instance uniform float instance_animation_time = 0.0;
instance uniform vec4 instance_energy_override : source_color = vec4(0.0);
instance uniform vec4 instance_accent_override : source_color = vec4(0.0);


void fragment() {
	vec2 atlas_uv = UV * uv_scale + uv_offset;
	vec3 painted = has_albedo_texture ? texture(albedo_texture, atlas_uv).rgb : vec3(1.0);
	vec3 surface_color = base_color.rgb * painted;
	vec3 surface_emission = emission_color.rgb;
	if (has_emission_texture) {
		surface_emission *= texture(emission_texture, atlas_uv).rgb;
	}
	vec3 active_energy = mix(
		surface_emission,
		instance_energy_override.rgb,
		instance_energy_override.a
	);
	vec3 active_accent = mix(
		surface_color,
		instance_accent_override.rgb,
		instance_accent_override.a
	);
	float pulse = 0.90 + 0.10 * sin(
		instance_animation_time * 2.2 + instance_phase_offset
	);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.5);

	// Shared cool alloy in shadows preserves class-colored armor panels.
	float body_luminance = dot(surface_color, vec3(0.2126, 0.7152, 0.0722));
	vec3 armor = mix(vec3(body_luminance), surface_color, 0.68);
	vec3 authored_body = mix(armor, vec3(0.055, 0.065, 0.11), 0.14) * instance_modulate.rgb;
	ALBEDO = mix(authored_body, vec3(1.0), instance_flash);
	METALLIC = metallic;
	ROUGHNESS = roughness;

	vec3 authored_glow = mix(surface_emission, vec3(0.58, 0.14, 0.78), 0.45) * min(emission_strength, 2.2);
	vec3 feedback_rim = mix(active_energy, vec3(0.58, 0.14, 0.78), 0.65) * rim * rim_strength * pulse;
	vec3 combined_glow = (authored_glow + feedback_rim) * max(
		instance_modulate.rgb,
		vec3(0.18)
	);
	EMISSION = mix(combined_glow + authored_body * 0.085, vec3(2.8), instance_flash);
}
