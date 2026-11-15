shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://versions/v04/shaders/cut_common.gdshaderinc"

uniform bool powered = false;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (rz_cut(wpos, VERTEX, VIEW_MATRIX, CAMERA_DIRECTION_WORLD, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = vec3(0.12, 0.14, 0.13);
	ROUGHNESS = 0.3;
	if (powered) {
		float n = hash(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 24.0));
		EMISSION = vec3(0.55, 0.6, 0.65) * (0.4 + n * 0.8);
	}
}
