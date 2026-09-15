shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
instance uniform float charge_progress = 0.0;
void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	float disk = 1.0 - smoothstep(0.96, 1.0, radius);
	float edge = smoothstep(0.91, 0.95, radius) * disk;
	float fill = (1.0 - smoothstep(charge_progress - 0.025, charge_progress + 0.025, radius)) * disk;
	ALBEDO = vec3(1.0, 0.27, 0.035);
	ALPHA = disk * 0.10 + edge * 0.8 + fill * 0.16;
}
