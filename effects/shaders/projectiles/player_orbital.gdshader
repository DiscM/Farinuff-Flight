shader_type canvas_item;
render_mode blend_add;

// Rotating player orbital with a stable central core and moving energy shell.
uniform vec4 core_color : source_color = vec4(0.78, 1.0, 0.96, 1.0);
uniform vec4 shell_color : source_color = vec4(0.04, 0.9, 0.72, 1.0);
uniform float phase_offset = 0.0;

varying vec4 projectile_modulate;


void vertex() {
	projectile_modulate = COLOR;
}


void fragment() {
	vec4 vertex_color = projectile_modulate;
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	float angle = atan(point.y, point.x);
	float time = TIME * 4.5 + phase_offset;

	float core = smoothstep(0.32, 0.02, radius);
	float shell = smoothstep(0.055, 0.0, abs(radius - 0.52));
	float halo = smoothstep(0.96, 0.34, radius);
	float rotating_charge = pow(max(0.0, sin(angle * 3.0 - time)), 3.0);
	rotating_charge *= smoothstep(0.72, 0.25, radius);

	vec3 color = shell_color.rgb * (halo * 0.28 + shell * 1.15);
	color += core_color.rgb * core * 1.35;
	color += mix(shell_color.rgb, core_color.rgb, 0.5) * rotating_charge * 0.8;

	float alpha = clamp(core + shell + halo * 0.48 + rotating_charge * 0.45, 0.0, 1.0);
	COLOR = vec4(color * vertex_color.rgb, alpha * vertex_color.a);
}
