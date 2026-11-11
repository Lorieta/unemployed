shader_type spatial;

// Organic ground. The old world-space checkerboard is gone: the surface is now
// built from layered value noise — broad meadow patches, mid-scale clumps and a
// fine blade-level grain — with dry worn earth where the large noise dips. The
// original uniforms are kept (same names, same scene file): base_color is the
// deep grass, tile_color the lush highlights, line_color the dry patches, and
// cell_size drives the scale of the large patches.

uniform vec3 base_color : source_color = vec3(0.26, 0.35, 0.2);
uniform vec3 tile_color : source_color = vec3(0.36, 0.47, 0.25);
uniform vec3 line_color : source_color = vec3(0.52, 0.47, 0.28);
uniform float cell_size = 2.0;
uniform float pattern_fade_start = 20.0;
uniform float pattern_fade_end = 60.0;

varying vec3 world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float distance_fade = 1.0 - smoothstep(pattern_fade_start, pattern_fade_end,
		distance(CAMERA_POSITION_WORLD, world_position));

	// Broad meadow patches; the detail fades with distance so the horizon
	// stays clean and cheap.
	float patches = fbm(p / max(cell_size, 0.25));
	float clumps = fbm(p * 1.7);
	float grain = value_noise(p * 24.0);

	vec3 color = mix(base_color, tile_color, clamp(patches, 0.0, 1.0) * 0.85);

	// Dry, trampled earth shows through where the low-frequency noise dips.
	float dryness = smoothstep(0.62, 0.85, fbm(p * 0.6 + 17.3));
	color = mix(color, line_color, dryness * 0.45 * distance_fade);

	// Blade-level speckle and brighter clump tips, close to the camera only.
	color += (grain - 0.5) * 0.055 * distance_fade;
	color += smoothstep(0.72, 1.0, clumps) * 0.05 * distance_fade;

	ALBEDO = color;
	ROUGHNESS = 1.0;
}
