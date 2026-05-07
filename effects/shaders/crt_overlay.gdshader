shader_type canvas_item;
// CRT monitor post-processing overlay.
// Applies: barrel distortion, scanlines, vignette, and chromatic aberration.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float aberration_strength : hint_range(0.0, 0.01) = 0.004;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float scanline_count : hint_range(50.0, 800.0) = 180.0;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.6;
uniform float barrel_distortion : hint_range(0.0, 0.5) = 0.15;
uniform bool apply_distortion = false;
uniform float contrast : hint_range(0.0, 2.0) = 1.25;
uniform float brightness : hint_range(0.0, 2.0) = 1.1;

vec2 barrel(vec2 uv) {
	vec2 cc = uv - 0.5;
	float dist = dot(cc, cc);
	// More pronounced spherical warp
	return uv + cc * dist * (barrel_distortion + dist * 0.2);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (apply_distortion) {
		uv = barrel(SCREEN_UV);
	}

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
		// Animated with a slow scroll and high-frequency flicker
		float s_small = sin(uv.y * scanline_count + TIME * 1.25);
		float s_big = sin(uv.y * (scanline_count * 0.5) - TIME * 0.8);
		
		// Blend: small lines are the base, big lines add periodic "thicker" gaps
		float scanline = (s_small * 0.6 + s_big * 0.4) * 0.5 + 0.5;
		
		// Subtle, low-frequency brightness variation (no high-speed flicker that
		// causes visible blinking on sub-pixel elements like stars)
		float flicker = sin(TIME * 4.0) * 0.005 + 0.995;
		
		// Vary the width/intensity of the lines across the screen for non-uniformity
		float width_var = sin(uv.y * 12.0 - TIME * 0.4) * 0.15 + 1.45;
		
		scanline = pow(scanline, width_var) * flicker;
		scanline = 1.0 - scanline_intensity * (1.0 - scanline);
		col.rgb *= scanline;

		// Vignette — darkens the corners in an oval
		vec2 vig_uv = uv * (1.0 - uv.yx);
		float vignette = vig_uv.x * vig_uv.y * 15.0;
		vignette = clamp(pow(vignette, vignette_strength * 0.5), 0.0, 1.0);
		col.rgb *= vignette;

		// Contrast and Brightness adjustment
		col.rgb = (col.rgb - 0.5) * contrast + 0.5;
		col.rgb += (brightness - 1.0);

		COLOR = col;
	}
}
