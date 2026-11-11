shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, world_vertex_coords;

// One quad draws the whole enemy health bar: a dark pill plate with a gold rim,
// a pale "wound" ghost that lingers where the last hits landed, and a fill that
// shifts green -> amber -> red, shades top to bottom, and pulses when the beast
// is nearly down. The ratios arrive as uniforms, so the billboard never has to
// fight the node's scale the way the old scaled-quad fill did. Spatial shaders
// have no billboard render mode, so the quad turns to face the camera by hand.

uniform float ratio : hint_range(0.0, 1.0) = 1.0;
uniform float ghost : hint_range(0.0, 1.0) = 1.0;
uniform vec4 frame_color : source_color = vec4(0.05, 0.04, 0.03, 0.9);
uniform vec4 rim_color : source_color = vec4(0.83, 0.68, 0.35, 0.95);
uniform vec4 hp_high : source_color = vec4(0.6, 0.78, 0.34, 1.0);
uniform vec4 hp_mid : source_color = vec4(0.86, 0.65, 0.22, 1.0);
uniform vec4 hp_low : source_color = vec4(0.78, 0.2, 0.14, 1.0);
uniform vec4 ghost_color : source_color = vec4(1.0, 0.9, 0.75, 0.8);

// Y-axis billboard: spin the quad around world up so it always faces the
// camera, wherever the monster happens to be turned.
void vertex() {
	vec3 to_cam = CAMERA_POSITION_WORLD - NODE_POSITION_WORLD;
	to_cam.y = 0.0;
	float len = length(to_cam);
	vec3 forward = vec3(0.0, 0.0, 1.0);
	if (len > 0.001) {
		forward = to_cam / len;
	}
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
	vec3 local = VERTEX - NODE_POSITION_WORLD;
	VERTEX = NODE_POSITION_WORLD + right * local.x + vec3(0.0, 1.0, 0.0) * local.y;
}

// Signed distance to a rounded rectangle centred on p.
float rounded_rect(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void fragment() {
	vec2 uv = UV;
	float top = 1.0 - uv.y; // QuadMesh UV y runs top to bottom.
	vec2 p = uv * 2.0 - vec2(1.0);

	float outer = rounded_rect(p, vec2(0.98, 0.95), 0.5);
	float plate = 1.0 - smoothstep(-0.03, 0.03, outer);
	if (plate <= 0.002) {
		discard;
	}
	float inner = rounded_rect(p, vec2(0.8, 0.77), 0.36);
	float well = 1.0 - smoothstep(-0.02, 0.02, inner);

	// Fill and ghost are anchored to the left edge of the well.
	float left = -0.8;
	float span = 1.6;
	float fill_edge = left + span * ratio;
	float ghost_edge = left + span * ghost;
	float fill_mask = well * (1.0 - smoothstep(fill_edge - 0.02, fill_edge + 0.02, p.x));
	float ghost_mask = well * (1.0 - smoothstep(ghost_edge - 0.02, ghost_edge + 0.02, p.x)) * (1.0 - fill_mask);

	// Colour bands blend smoothly from red through amber to moss green.
	vec3 hp_color = mix(hp_low.rgb, hp_mid.rgb, smoothstep(0.12, 0.55, ratio));
	hp_color = mix(hp_color, hp_high.rgb, smoothstep(0.5, 0.85, ratio));
	// Vertical shading plus a soft shine along the top of the fill.
	hp_color *= 0.88 + 0.24 * top;
	hp_color += vec3(0.12) * smoothstep(0.6, 0.95, top);
	// Danger pulse when the beast is nearly spent.
	if (ratio < 0.3) {
		hp_color *= 0.82 + 0.3 * sin(TIME * 7.0);
	}

	vec4 col = frame_color * plate;
	col = mix(col, vec4(0.02, 0.017, 0.014, 0.96), well);
	vec4 ghost_px = ghost_color * ghost_mask;
	col = mix(col, ghost_px, ghost_px.a);
	vec4 fill_px = vec4(hp_color, 1.0) * fill_mask;
	col = mix(col, fill_px, fill_px.a);
	float rim = plate * (1.0 - well);
	col = mix(col, rim_color, rim);
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
