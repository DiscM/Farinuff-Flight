shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.22, 0.34, 0.43, 1.0);
uniform float emissive_surface = 0.0;
uniform float metallic = 0.45;
uniform float roughness = 0.44;
instance uniform vec4 instance_modulate : source_color = vec4(1.0);
instance uniform float instance_flash = 0.0;
instance uniform float instance_phase_offset = 0.0;

void fragment() {
	float luminance = dot(base_color.rgb, vec3(0.2126, 0.7152, 0.0722));
	// Keep authored panel contrast, with one alloy and one energy family.
	vec3 alloy = mix(vec3(0.035, 0.075, 0.12), vec3(0.30, 0.43, 0.49), pow(luminance, 0.7));
	vec3 cyan = vec3(0.035, 0.72, 0.9);
	vec3 ice = vec3(0.65, 0.94, 1.0);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.3);
	ALBEDO = mix(mix(alloy, cyan * 0.6, emissive_surface), vec3(1.0), instance_flash) * instance_modulate.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = (alloy * 0.13 + cyan * rim * 0.62 + mix(cyan, ice, 0.4) * emissive_surface * 1.45) * instance_modulate.rgb;
	EMISSION += ice * instance_flash * 1.5;
}
