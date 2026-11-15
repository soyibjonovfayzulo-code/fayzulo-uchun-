// Grass and weed clumps (MultiMesh): pixel blades, per-instance tint (September greens and straw),
// tips sway with the global wind, lit like the ground under them.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

global uniform float wind;

uniform sampler2D tuft_tex : source_color, filter_nearest;

varying vec3 tint;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float top = 1.0 - UV.y;
	float t = TIME * (1.3 + wind) + w.x * 0.45 + w.z * 0.31;
	float k = top * top * (0.035 + wind * 0.07);
	VERTEX.x += sin(t) * k;
	VERTEX.z += cos(t * 0.73) * k * 0.8;
	tint = COLOR.rgb;
}

void fragment() {
	vec4 m = texture(tuft_tex, UV);
	if (m.a < 0.5) {
		discard;
	}
	ALBEDO = tint * (m.rgb * 0.9 + 0.1) * mix(0.62, 1.0, 1.0 - UV.y);
	ROUGHNESS = 1.0;
}
