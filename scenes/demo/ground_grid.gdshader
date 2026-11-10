shader_type spatial;

// Simple world-space checkerboard with thin tile lines. Because the pattern is
// based on world position it stays fixed while the camera follows the player.

uniform vec3 base_color : source_color = vec3(0.31, 0.38, 0.34);
uniform vec3 tile_color : source_color = vec3(0.35, 0.43, 0.38);
uniform vec3 line_color : source_color = vec3(0.45, 0.53, 0.47);
uniform float cell_size = 2.0;
uniform float pattern_fade_start = 20.0;
uniform float pattern_fade_end = 60.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = world_position.xz / cell_size;
	float distance_fade = 1.0 - smoothstep(pattern_fade_start, pattern_fade_end,
		distance(CAMERA_POSITION_WORLD, world_position));

	float checker = mod(floor(cell.x) + floor(cell.y), 2.0);
	vec3 color = mix(base_color, tile_color, checker * distance_fade);

	vec2 grid = abs(fract(cell - 0.5) - 0.5) / max(fwidth(cell), vec2(0.0001));
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);

	ALBEDO = mix(color, line_color, line * 0.35 * distance_fade);
	ROUGHNESS = 1.0;
}
