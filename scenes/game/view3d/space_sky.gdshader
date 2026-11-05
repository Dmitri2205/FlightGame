shader_type sky;
// Космос: тёмный градиент, звёзды и лёгкие туманности.

uniform vec3 top_color : source_color = vec3(0.01, 0.01, 0.04);
uniform vec3 horizon_color : source_color = vec3(0.10, 0.06, 0.16);
uniform vec3 nebula_color : source_color = vec3(0.35, 0.12, 0.45);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void sky() {
	vec3 dir = EYEDIR;
	float h = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.5));
	float neb = noise(dir * 3.0) * noise(dir * 7.0 + 3.0);
	col += nebula_color * smoothstep(0.25, 0.6, neb) * 0.5;
	vec3 cell = floor(dir * 220.0);
	float star = step(0.997, hash(cell));
	col += vec3(star) * (0.6 + 0.4 * hash(cell + 5.0));
	COLOR = col;
}
