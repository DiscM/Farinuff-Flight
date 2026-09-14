shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 warning_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
// Geometry includes six pixels of feathering outside each true lane edge.
instance uniform vec2 lane_size = vec2(18.0, 1600.0);
instance uniform float charge_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * (lane_size.x + 12.0), UV.y * lane_size.y);
	float across = abs(p.x);
	float half_width = lane_size.x * 0.5;
	float aa = max(fwidth(p.x), 0.65);
	float edge_distance = abs(across - half_width);
	float edge = 1.0 - smoothstep(0.65, 0.65 + aa, edge_distance);
	float halo = exp(-edge_distance * 0.65) * 0.18;
	float inside = 1.0 - smoothstep(half_width - aa, half_width + aa, across);
	float center = 1.0 - smoothstep(0.45, 0.45 + aa, across);
	// Arrow tips and the moving dash travel from the emitter toward the end.
	float spacing = 100.0;
	float phase = mod(p.y - charge_progress * 200.0 + across * 0.7, spacing);
	float arrow_distance = min(phase, spacing - phase);
	float arrow_aa = max(fwidth(p.y), 0.8);
	float arrows = (1.0 - smoothstep(1.0, 1.0 + arrow_aa, arrow_distance)) * inside;
	float ends = smoothstep(0.0, 24.0, p.y) * smoothstep(0.0, 36.0, lane_size.y - p.y);
	float urgency = smoothstep(0.6, 1.0, charge_progress);
	float alpha = inside * (0.035 + urgency * 0.025) + halo + edge * (0.38 + urgency * 0.32);
	alpha += center * 0.12 + arrows * (0.28 + urgency * 0.2);
	vec3 color = mix(warning_color.rgb, vec3(1.0, 0.96, 0.85), edge * urgency * 0.35);
	ALBEDO = color;
	EMISSION = color * 0.35;
	ALPHA = clamp(alpha * ends * warning_color.a, 0.0, 0.85);
}
