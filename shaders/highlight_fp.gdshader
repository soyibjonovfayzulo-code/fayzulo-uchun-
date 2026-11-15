// First-person variant of the focus highlight: depth-tested (no glow through walls or stacked faces)
// and much fainter, a warm rim that breathes so the object under the crosshair reads at arm's length.
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;

uniform vec4 color : source_color = vec4(0.9, 0.72, 0.35, 1.0);

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float pulse = 0.7 + 0.3 * sin(TIME * 4.0);
	ALBEDO = color.rgb * (0.03 + pow(rim, 2.0) * 0.22) * pulse;
}
