shader_type canvas_item;
// Only applies barrel distortion to the entire screen.
// Purpose: A final post-processing pass to curve the Game and UI together.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float barrel_distortion : hint_range(0.0, 0.5) = 0.15;

vec2 barrel(vec2 uv) {
	vec2 cc = uv - 0.5;
	float dist = dot(cc, cc);
	// Spherical warp
	return uv + cc * dist * (barrel_distortion + dist * 0.2);
}

void fragment() {
	vec2 uv = barrel(SCREEN_UV);
	
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		COLOR = texture(screen_texture, uv);
	}
}
