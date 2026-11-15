// First-person sky (v0.5): horizon-to-zenith gradient driven by DayNight, a soft sun (pale moon at
// night), drifting cumulus from layered value noise, overcast in rain, twinkling stars at night.
// The radiance cubemap pass gets the cheap gradient only.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.35, 0.5, 0.7);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.76, 0.78);
uniform vec3 ground_color : source_color = vec3(0.25, 0.27, 0.24);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.8);
uniform vec3 cloud_light : source_color = vec3(0.95, 0.93, 0.9);
uniform vec3 cloud_dark : source_color = vec3(0.55, 0.58, 0.62);
uniform float cloud_cover = 0.45;
uniform float night = 0.0;
uniform float cloud_time = 0.0;
uniform sampler2D cloud_noise : repeat_enable, filter_linear;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * texture(cloud_noise, p * 0.11).r;
		p = p * 2.03 + vec2(0.37, 0.61);
		a *= 0.5;
	}
	return v / 0.9375;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, zenith_color, smoothstep(0.0, 0.6, h));
	col = mix(col, ground_color, smoothstep(0.0, -0.12, h));
	if (AT_CUBEMAP_PASS) {
		COLOR = col;
	} else {
		vec3 L = LIGHT0_DIRECTION;
		float sd = dot(d, L);
		// Sun (day) or moon (night) and the glow around it.
		float disc_size = mix(0.9993, 0.99965, night);
		float disc = smoothstep(disc_size, disc_size + 0.00015, sd);
		vec3 body = mix(sun_color * 3.5, vec3(0.85, 0.88, 0.95) * 1.4, night);
		float glow = pow(max(sd, 0.0), 24.0) * 0.35 * (1.0 - night * 0.7) + pow(max(sd, 0.0), 4.0) * 0.12 * (1.0 - night);
		col += sun_color * glow;
		// Stars.
		if (night > 0.01 && h > 0.0) {
			vec2 sp = d.xz / (h + 0.3) * 160.0;
			vec2 cell = floor(sp);
			float star = step(0.985, hash(cell)) * smoothstep(0.6, 0.0, length(fract(sp) - 0.5));
			star *= 0.6 + 0.4 * sin(TIME * (1.5 + hash(cell + 3.0) * 3.0) + hash(cell) * 30.0);
			col += vec3(star) * night * smoothstep(0.0, 0.25, h) * (1.0 - cloud_cover);
		}
		col += body * disc * (1.0 - smoothstep(0.55, 0.9, cloud_cover));
		// Clouds on a dome.
		if (h > 0.0) {
			vec2 cp = d.xz / (h + 0.12) * 1.6 + vec2(cloud_time * 0.012, cloud_time * 0.004);
			float n = fbm(cp);
			float c = smoothstep(1.0 - cloud_cover - 0.15, 1.0 - cloud_cover + 0.35, n);
			float lit = clamp(0.55 + 0.45 * fbm(cp * 1.8 + L.xz * 0.3), 0.0, 1.0);
			vec3 cc = mix(cloud_dark, cloud_light, lit);
			cc = mix(cc, sun_color * 1.2, pow(max(sd, 0.0), 6.0) * 0.4 * (1.0 - night));
			c *= smoothstep(0.0, 0.12, h);
			col = mix(col, cc, c * 0.92);
		}
		COLOR = col;
	}
}
