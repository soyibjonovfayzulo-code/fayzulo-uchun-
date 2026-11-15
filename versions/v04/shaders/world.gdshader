// Universal lit material for buildings, ground and props: world-space pixel texturing,
// optional vertex tint, two-tone stairwell paint, night emission, the player cutaway and, in the rain,
// wet darkened ground with glossy puddles (screen-space reflections pick up lamps and fires).
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_back;

#include "res://versions/v04/shaders/cut_common.gdshaderinc"

global uniform float night_factor;
global uniform float rain_wet;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform bool has_tex = true;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 tex_meters = vec2(1.0, 1.0);
uniform bool use_vertex_color = false;
uniform bool cuttable = true;
uniform bool two_tone = false;
uniform vec4 low_color : source_color = vec4(0.33, 0.43, 0.36, 1.0);
uniform float two_tone_height = 1.45;
uniform float level_height = 2.8;
uniform float emission_night = 0.0;
uniform float emission_always = 0.0;
uniform vec4 emission_color : source_color = vec4(1.0, 0.86, 0.6, 1.0);

varying vec3 wpos;
varying vec3 wnrm;

float rz_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	if (cuttable && rz_cut(wpos, VERTEX, VIEW_MATRIX, CAMERA_DIRECTION_WORLD, FRAGCOORD.xy)) {
		discard;
	}
	vec3 c = tint.rgb;
	if (two_tone) {
		float hy = mod(wpos.y + 0.02, level_height);
		c = hy < two_tone_height ? low_color.rgb : tint.rgb;
		if (abs(hy - two_tone_height) < 0.035) c *= 0.55;
	}
	if (has_tex) {
		vec3 an = abs(wnrm);
		vec2 uv;
		if (an.y >= an.x && an.y >= an.z) {
			uv = wpos.xz;
		} else if (an.x >= an.z) {
			uv = vec2(wpos.z, -wpos.y);
		} else {
			uv = vec2(wpos.x, -wpos.y);
		}
		c *= texture(albedo_tex, uv / tex_meters).rgb;
	}
	if (use_vertex_color) {
		c *= COLOR.rgb;
	}
	float wet = 0.0;
	float puddle = 0.0;
	if (!cuttable && wnrm.y > 0.7 && rain_wet > 0.001) {
		wet = rain_wet;
		// Pixel-snapped puddle mask so reflections stay crisp like the rest of the world.
		vec2 q = floor(wpos.xz * 8.0) / 8.0;
		float n = rz_vnoise(q * 0.35) * 0.65 + rz_vnoise(q * 1.3) * 0.35;
		puddle = smoothstep(0.62 - rain_wet * 0.12, 0.66 - rain_wet * 0.12, n) * rain_wet;
		c *= mix(1.0, 0.68, wet);
		c = mix(c, c * vec3(0.55, 0.6, 0.68), puddle);
	}
	ALBEDO = c;
	ROUGHNESS = mix(1.0, 0.55, wet * 0.6);
	ROUGHNESS = mix(ROUGHNESS, 0.06, puddle);
	SPECULAR = mix(0.0, 0.25, wet) + puddle * 0.45;
	METALLIC = 0.0;
	EMISSION = emission_color.rgb * (emission_always + emission_night * night_factor);
}
