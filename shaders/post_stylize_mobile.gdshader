// Mobile-compatible full-screen stylisation pass (Forward Mobile / Vulkan Mobile):
// pixel-art outlines from depth discontinuities, cool shadows / warm highlights grading and film grain.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

global uniform vec3 cut_player_pos;
global uniform float cut_radius;
global uniform float night_factor;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float outline_strength = 0.5;
uniform float grade_strength = 1.0;
uniform float grain = 0.007;
uniform float perspective = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

vec3 view_pos(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.xyz / v.w;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	vec3 p0 = view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
	float edge = 0.0;
	vec2 offs[4] = vec2[4](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offs[i];
		vec3 p = view_pos(uv, INV_PROJECTION_MATRIX);
		float dz = p0.z - p.z;
		float rel = dz / max(-p0.z, 0.05);
		edge = max(edge, mix(smoothstep(0.35, 0.8, dz), smoothstep(0.09, 0.2, rel) * smoothstep(0.03, 0.12, dz), perspective));
	}
	if (texture(depth_tex, SCREEN_UV).r <= 0.00001) edge = 0.0;
	vec3 pv = (VIEW_MATRIX * vec4(cut_player_pos, 1.0)).xyz;
	float in_cut = 1.0 - smoothstep(cut_radius - 0.5, cut_radius + 0.8, length(p0.xy - pv.xy));
	edge *= 1.0 - in_cut * 0.85 * (1.0 - perspective);
	edge *= 1.0 - perspective * smoothstep(35.0, 90.0, -p0.z);
	col *= 1.0 - edge * outline_strength;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 shadow_tint = mix(vec3(0.9, 0.97, 1.06), vec3(0.82, 0.9, 1.12), night_factor);
	col = mix(col, col * shadow_tint, (1.0 - l) * 0.45 * grade_strength);
	col = mix(col, col * vec3(1.07, 1.0, 0.9), smoothstep(0.45, 1.0, l) * 0.3 * grade_strength);
	col = mix(vec3(l), col, 1.0 - 0.06 * grade_strength);
	col += (hash(FRAGCOORD.xy + vec2(TIME * 37.0, TIME * 11.0)) - 0.5) * grain;
	ALBEDO = col;
}

