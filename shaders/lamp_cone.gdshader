// Soft light cone under a street lamp at night (fake volumetric), brighter in the rain.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

global uniform float rain_wet;

uniform vec4 color : source_color = vec4(1.0, 0.78, 0.48, 1.0);
uniform float strength = 0.055;

varying float vy;

void vertex() {
	vy = UV.y;
}

void fragment() {
	// UV.y: 0 at the lamp, 1 at the ground; fade at both ends and towards the rim.
	float along = smoothstep(0.0, 0.12, vy) * (1.0 - smoothstep(0.75, 1.0, vy));
	float rim = pow(abs(dot(NORMAL, VIEW)), 3.0);
	ALBEDO = color.rgb * strength * along * rim * (1.0 + rain_wet * 1.2);
}
