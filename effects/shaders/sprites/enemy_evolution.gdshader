shader_type canvas_item;
render_mode unshaded;

// Shared enemy treatment. The controller changes these values for each
// evolution generation while the authored sprite remains the visual anchor.
uniform vec4 energy_color : source_color = vec4(0.12, 0.72, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.76, 0.95, 1.0, 1.0);
uniform float evolution_level : hint_range(0.0, 1.0) = 0.0;
uniform float outline_strength : hint_range(0.0, 1.5) = 0.55;
uniform float circuit_amount : hint_range(0.0, 1.0) = 0.05;
uniform float heat_amount : hint_range(0.0, 1.0) = 0.0;
uniform float apex_amount : hint_range(0.0, 1.0) = 0.0;
uniform float emission_strength : hint_range(0.0, 1.0) = 0.12;
uniform float phase_offset = 0.0;

varying vec4 sprite_modulate;


void vertex() {
	sprite_modulate = COLOR;
}


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = fract(point);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float lower_left = hash21(cell);
	float lower_right = hash21(cell + vec2(1.0, 0.0));
	float upper_left = hash21(cell + vec2(0.0, 1.0));
	float upper_right = hash21(cell + vec2(1.0, 1.0));
	return mix(
		mix(lower_left, lower_right, blend.x),
		mix(upper_left, upper_right, blend.x),
		blend.y
	);
}


void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE * (1.0 + evolution_level * 0.85);
	float time = TIME + phase_offset;

	// All evolution strips contain four horizontal frames. Converting the
	// atlas UV back to frame-local UV keeps patterns locked to the ship.
	vec2 local_uv = vec2(fract(UV.x * 4.0), UV.y);
	vec2 centered_uv = local_uv * 2.0 - 1.0;

	float nearby_alpha = 0.0;
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + pixel).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - pixel).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);

	float pulse = 0.72 + 0.28 * sin(time * (2.3 + evolution_level * 2.2));
	float outer_outline = max(nearby_alpha - texel.a, 0.0) * outline_strength;
	outer_outline *= 0.72 + pulse * 0.38;

	float horizontal_bus = 1.0 - smoothstep(
		0.035,
		0.09,
		abs(fract(local_uv.y * 8.0 + floor(local_uv.x * 5.0) * 0.19) - 0.5)
	);
	float vertical_bus = 1.0 - smoothstep(
		0.035,
		0.09,
		abs(fract(local_uv.x * 7.0 + floor(local_uv.y * 6.0) * 0.23) - 0.5)
	);
	float circuit_gate = step(
		0.46,
		value_noise(floor(local_uv * vec2(8.0, 7.0)) + phase_offset)
	);
	float circuitry = max(horizontal_bus, vertical_bus) * circuit_gate;
	float circuit_scan = smoothstep(
		0.28,
		0.0,
		abs(local_uv.y - fract(time * 0.24 + phase_offset * 0.13))
	);
	circuitry *= (0.32 + circuit_scan * 0.9) * circuit_amount * texel.a;

	float vein_path = abs(
		fract(
			local_uv.x * 4.5
			+ local_uv.y * 5.0
			+ sin(local_uv.y * 21.0 + phase_offset) * 0.17
		) - 0.5
	);
	float heat_veins = (1.0 - smoothstep(0.025, 0.085, vein_path));
	heat_veins *= heat_amount * texel.a * (0.64 + pulse * 0.46);

	float interference_row = floor(local_uv.y * 26.0);
	float interference_gate = step(
		0.78,
		hash21(vec2(interference_row, floor(time * 10.0) + phase_offset))
	);
	float interference = interference_gate * apex_amount * texel.a;
	float apex_wave = sin(centered_uv.y * 16.0 - time * 7.0 + centered_uv.x * 4.0);
	apex_wave = (0.5 + 0.5 * apex_wave) * apex_amount * texel.a;

	float luminance = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
	float body_energy = texel.a * emission_strength * (0.42 + luminance * 0.58);
	body_energy *= 0.78 + pulse * 0.34;

	vec3 body_color = texel.rgb;
	body_color += energy_color.rgb * body_energy;
	body_color = mix(body_color, accent_color.rgb, circuitry * 0.7);
	body_color += accent_color.rgb * heat_veins * 0.78;
	body_color += energy_color.rgb * apex_wave * 0.18;
	body_color = mix(body_color, accent_color.rgb * 1.22, interference * 0.42);

	vec3 outline_color = mix(energy_color.rgb, accent_color.rgb, pulse * 0.32);
	float output_alpha = max(texel.a, outer_outline);
	float body_weight = texel.a / max(output_alpha, 0.001);
	vec3 output_color = mix(outline_color, body_color, body_weight);
	output_color += accent_color.rgb * interference * 0.34;

	COLOR = vec4(
		output_color * sprite_modulate.rgb,
		output_alpha * sprite_modulate.a
	);
}
