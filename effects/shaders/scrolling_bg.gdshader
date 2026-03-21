shader_type canvas_item;
// Scrolling procedural nebula background for the game scene.

uniform float scroll_speed : hint_range(0.01, 0.5) = 0.04;

float hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0,0)), hash(i + vec2(1,0)), u.x),
		mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float time = TIME * scroll_speed;

	// Nebula clouds
	vec2 q = uv + vec2(time * 0.3, time * 0.15);
	float f = fbm(q * 3.0);
	f += 0.5 * fbm(q * 6.0 + vec2(f));

	vec3 nebula_color = mix(
		vec3(0.02, 0.01, 0.08),  // dark navy
		vec3(0.22, 0.05, 0.35),  // deep purple
		clamp(f * 1.4, 0.0, 1.0)
	);
	nebula_color = mix(nebula_color,
		vec3(0.05, 0.18, 0.45), // blue tinge on the edges
		clamp(f * f * 0.8, 0.0, 1.0)
	);

	// Parallax stars: two layers at different speeds
	// Fast small stars
	vec2 star_uv1 = fract(uv * 80.0 + vec2(0.0, time * 3.0));
	float star1 = step(0.985, hash(floor(uv * 80.0)));
	star1 *= smoothstep(0.07, 0.0, length(star_uv1 - 0.5));

	// Slow large stars
	vec2 star_uv2 = fract(uv * 40.0 + vec2(0.0, time * 1.4));
	float star2 = step(0.97, hash(floor(uv * 40.0 + vec2(17.3, 4.1))));
	star2 *= smoothstep(0.15, 0.0, length(star_uv2 - 0.5));

	vec3 col = nebula_color + vec3(star1 * 1.5) + vec3(star2 * 0.9, star2 * 0.85, star2);

	COLOR = vec4(col, 1.0);
}
