shader_type canvas_item;

// A whisper of shadow at the screen edges. Keeps the hand-framed HUD from
// feeling pasted on top of the world.

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float distance_from_center = length(uv * vec2(1.0, 1.14));
	float edge = smoothstep(0.62, 1.32, distance_from_center);
	float alpha = edge * 0.34;
	COLOR = vec4(0.018, 0.014, 0.009, alpha);
}
