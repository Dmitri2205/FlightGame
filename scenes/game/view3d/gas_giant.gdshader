shader_type spatial;
// Газовый гигант (как Юпитер): полосы по широте с завихрениями.

uniform vec3 color_a : source_color = vec3(0.85, 0.7, 0.55);
uniform vec3 color_b : source_color = vec3(0.6, 0.38, 0.25);
uniform vec3 color_c : source_color = vec3(0.95, 0.9, 0.8);
uniform float bands = 14.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float warp = noise(uv * vec2(8.0, 20.0) + TIME * 0.01) * 0.08;
	float b = sin((uv.y + warp) * bands * 6.2831);
	vec3 col = mix(color_a, color_b, smoothstep(-0.2, 0.6, b));
	col = mix(col, color_c, smoothstep(0.7, 1.0, b) * 0.6);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
