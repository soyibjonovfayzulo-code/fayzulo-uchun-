// Overlay for the focused interactable: soft pulsing additive rim.
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, depth_test_disabled;

#include "res://versions/v02/shaders/cut_common.gdshaderinc"

uniform vec4 color : source_color = vec4(0.9, 0.75, 0.35, 1.0);
uniform float strength = 0.12;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (rz_cut(wpos, VERTEX, VIEW_MATRIX, CAMERA_DIRECTION_WORLD, FRAGCOORD.xy)) {
		discard;
	}
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float pulse = 0.75 + 0.25 * sin(TIME * 5.0);
	ALBEDO = color.rgb * (strength + rim * 0.35) * pulse;
}
