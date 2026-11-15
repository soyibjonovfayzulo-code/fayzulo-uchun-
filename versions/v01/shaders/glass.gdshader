shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert, depth_draw_never;

#include "res://versions/v01/shaders/cut_common.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.45, 0.55, 0.6, 1.0);
uniform float opacity = 0.45;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (rz_cut(wpos, VERTEX, VIEW_MATRIX, CAMERA_DIRECTION_WORLD, FRAGCOORD.xy)) {
		discard;
	}
	float streak = fract((wpos.x + wpos.z) * 1.7 + wpos.y * 0.6);
	ALBEDO = tint.rgb * (streak < 0.12 ? 1.35 : 1.0);
	ALPHA = opacity;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
}
