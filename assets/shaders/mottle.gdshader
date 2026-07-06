shader_type canvas_item;
// Static two-tone value-noise mottling. Breaks up the big flat fields
// (grass, sand, rock) without any texture assets — one shader, themed
// per zone by its color uniforms.

uniform vec4 base_color : source_color = vec4(0.22, 0.43, 0.18, 1.0);
uniform vec4 detail_color : source_color = vec4(0.18, 0.37, 0.15, 1.0);
uniform float noise_scale = 0.006;
uniform float detail_strength = 0.85;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world_pos * noise_scale;
	float n = vnoise(p) * 0.65 + vnoise(p * 3.1) * 0.35;
	COLOR = mix(base_color, detail_color, smoothstep(0.25, 0.8, n) * detail_strength);
	COLOR.a = base_color.a;
}
