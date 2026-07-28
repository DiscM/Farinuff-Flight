shader_type canvas_item;
render_mode blend_add;

// Directional player bolt with upgrade-readable energy layers.
uniform vec4 core_color : source_color = vec4(0.82, 1.0, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.02, 0.72, 1.0, 1.0);
uniform float piercing_amount : hint_range(0.0, 1.0) = 0.0;
uniform float explosive_amount : hint_range(0.0, 1.0) = 0.0;
uniform float zigzag_amount : hint_range(0.0, 1.0) = 0.0;
uniform float phase_offset = 0.0;

varying vec4 projectile_modulate;


void vertex() {
	projectile_modulate = COLOR;
}


float capsule_sdf(vec2 point, vec2 start, vec2 end, float radius) {
	vec2 from_start = point - start;
	vec2 axis = end - start;
	float projection = clamp(dot(from_start, axis) / dot(axis, axis), 0.0, 1.0);
	return length(from_start - axis * projection) - radius;
}


void fragment() {
	vec4 vertex_color = projectile_modulate;
	vec2 point = UV * 2.0 - 1.0;
	float time = TIME * 12.0 + phase_offset;

	float distance_to_body = capsule_sdf(point, vec2(0.0, 0.46), vec2(0.0, -0.48), 0.13);
	float body = 1.0 - smoothstep(-0.035, 0.055, distance_to_body);
	float hot_core = 1.0 - smoothstep(-0.085, -0.01, distance_to_body);
	float halo = exp(-max(distance_to_body, 0.0) * 7.2);
	halo *= smoothstep(1.12, 0.58, length(point));

	float flow = 0.72 + 0.28 * sin(point.y * 22.0 + time);
	float tail = smoothstep(0.28, 0.92, point.y);
	tail *= smoothstep(0.22, 0.0, abs(point.x + sin(point.y * 17.0 + time) * 0.035));

	// Piercing rounds gain a razor-white axial spear.
	float piercing_spine = smoothstep(0.045, 0.0, abs(point.x));
	piercing_spine *= smoothstep(0.82, 0.2, abs(point.y));
	piercing_spine *= piercing_amount;

	// Explosive rounds carry a pulsing amber containment ring.
	float ring_radius = length(point * vec2(1.0, 0.82));
	float explosive_ring = smoothstep(0.05, 0.0, abs(ring_radius - 0.43));
	explosive_ring *= (0.68 + 0.32 * sin(time * 0.72)) * explosive_amount;

	// Zigzag stacks expose electrical rails along both sides of the bolt.
	float arc_position = 0.34 + sin(point.y * 13.0 - time * 1.2) * 0.065;
	float electric_arcs = smoothstep(0.035, 0.0, abs(abs(point.x) - arc_position));
	electric_arcs *= smoothstep(0.82, 0.2, abs(point.y)) * zigzag_amount;

	vec3 bolt_color = mix(glow_color.rgb, core_color.rgb, hot_core);
	vec3 color = bolt_color * (body * (0.9 + flow * 0.35) + halo * 0.3);
	color += core_color.rgb * piercing_spine * 1.4;
	color += vec3(1.0, 0.28, 0.035) * explosive_ring * 1.25;
	color += vec3(0.38, 0.62, 1.0) * electric_arcs;
	color += glow_color.rgb * tail * 0.6;

	float alpha = clamp(body + halo * 0.42 + tail * 0.55 + piercing_spine + explosive_ring + electric_arcs, 0.0, 1.0);
	COLOR = vec4(color * vertex_color.rgb, alpha * vertex_color.a);
}
