shader_type canvas_item;
// CRT monitor post-processing overlay.
// Applies: barrel distortion, scanlines, vignette, and chromatic aberration.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float aberration_strength : hint_range(0.0, 0.01) = 0.004;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.12;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.8;
uniform float barrel_distortion : hint_range(0.0, 0.3) = 0.06;

vec2 barrel(vec2 uv) {
	vec2 cc = uv - 0.5;
	float dist = dot(cc, cc);
	return uv + cc * dist * barrel_distortion;
}

void fragment() {
	vec2 uv = barrel(SCREEN_UV); // Must use SCREEN_UV for post-processing

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		// Outside barrel-bent area — render solid black border
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Chromatic aberration — split R/G/B channels slightly
		vec2 offset = (uv - 0.5) * aberration_strength;
		float r = texture(screen_texture, uv + offset).r;
		float g = texture(screen_texture, uv).g;
		float b = texture(screen_texture, uv - offset).b;
		vec4 col = vec4(r, g, b, 1.0);

		// Scanlines — horizontal dark bands
		float scanline = sin(uv.y * 800.0) * 0.5 + 0.5;
		scanline = 1.0 - scanline_intensity * (1.0 - scanline);
		col.rgb *= scanline;

		// Vignette — darkens the corners in an oval
		vec2 vig_uv = uv * (1.0 - uv.yx);
		float vignette = vig_uv.x * vig_uv.y * 15.0;
		vignette = clamp(pow(vignette, vignette_strength * 0.5), 0.0, 1.0);
		col.rgb *= vignette;

		COLOR = col;
	}
}
