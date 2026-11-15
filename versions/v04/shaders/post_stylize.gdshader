// Full-screen stylisation pass (a quad in front of the game camera, drawn first among transparents):
// pixel-art outlines from depth and normal discontinuities, cool shadows / warm highlights grading and
// a faint film grain. Outlines fade out inside the wall cutaway around the player so the dither stays clean.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

global uniform vec3 cut_player_pos;
global uniform float cut_radius;
global uniform float night_factor;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform float outline_strength = 0.5;
uniform float grade_strength = 1.0;
uniform float grain = 0.007;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

vec3 view_pos(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.xyz / v.w;
}

vec3 view_normal(vec2 uv) {
	return normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	vec3 p0 = view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 n0 = view_normal(SCREEN_UV);
	float edge = 0.0;
	vec2 offs[4] = vec2[4](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offs[i];
		vec3 p = view_pos(uv, INV_PROJECTION_MATRIX);
		// Only the nearer side of a silhouette gets the line (crisp single-pixel outlines).
		float dz = p0.z - p.z;
		edge = max(edge, smoothstep(0.35, 0.8, dz));
		float nd = 1.0 - dot(n0, view_normal(uv));
		edge = max(edge, smoothstep(0.35, 0.75, nd) * 0.55);
	}
	// No outlines on the sky/background or inside the cutaway circle.
	if (texture(depth_tex, SCREEN_UV).r <= 0.00001) edge = 0.0;
	vec3 pv = (VIEW_MATRIX * vec4(cut_player_pos, 1.0)).xyz;
	float in_cut = 1.0 - smoothstep(cut_radius - 0.5, cut_radius + 0.8, length(p0.xy - pv.xy));
	edge *= 1.0 - in_cut * 0.85;
	col *= 1.0 - edge * outline_strength;
	// Grading: cool, slightly desaturated shadows, warm highlights; night pushes blue.
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 shadow_tint = mix(vec3(0.9, 0.97, 1.06), vec3(0.82, 0.9, 1.12), night_factor);
	col = mix(col, col * shadow_tint, (1.0 - l) * 0.45 * grade_strength);
	col = mix(col, col * vec3(1.07, 1.0, 0.9), smoothstep(0.45, 1.0, l) * 0.3 * grade_strength);
	col = mix(vec3(l), col, 1.0 - 0.06 * grade_strength);
	col += (hash(FRAGCOORD.xy + vec2(TIME * 37.0, TIME * 11.0)) - 0.5) * grain;
	ALBEDO = col;
}
