// Tree and bush canopies: world-space pixel leaf mask breaks up the blob silhouettes.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

#include "res://versions/v01/shaders/cut_common.gdshaderinc"

uniform sampler2D leaf_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(0.4, 0.45, 0.25, 1.0);
uniform float leaf_meters = 1.2;
uniform float coverage = 0.5;
uniform float sway = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * 0.9 + w.x * 0.15 + w.z * 0.11;
	VERTEX.x += sin(t) * 0.04 * sway * max(VERTEX.y - 2.0, 0.0) * 0.15;
	VERTEX.z += cos(t * 0.8) * 0.03 * sway * max(VERTEX.y - 2.0, 0.0) * 0.15;
	wpos = w;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	if (rz_cut(wpos, VERTEX, VIEW_MATRIX, CAMERA_DIRECTION_WORLD, FRAGCOORD.xy)) {
		discard;
	}
	vec3 an = abs(wnrm);
	vec2 uv = an.y > 0.6 ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
	vec4 m = texture(leaf_tex, uv / leaf_meters);
	vec4 m2 = texture(leaf_tex, uv / (leaf_meters * 0.47) + vec2(0.31, 0.17));
	float a = max(m.a, m2.a * 0.8);
	// Interior (back) faces stay mostly solid so canopies keep their mass.
	float need = FRONT_FACING ? coverage : 0.15;
	if (a < need) {
		discard;
	}
	vec3 c = tint.rgb * m.rgb;
	if (!FRONT_FACING) {
		c *= 0.6;
		NORMAL = -NORMAL;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
