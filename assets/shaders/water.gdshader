shader_type canvas_item;
// The sea: deep water with drifting swells, a shallow turquoise shelf
// hugging the island, and a foamed waterline. Everything is computed in
// world space from the land rectangle, so the physical water area stays
// rectangular while the visible coastline wobbles organically.

uniform vec4 deep_color : source_color = vec4(0.07, 0.21, 0.33, 1.0);
uniform vec4 swell_color : source_color = vec4(0.1, 0.28, 0.41, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.22, 0.5, 0.55, 1.0);
uniform vec4 foam_color : source_color = vec4(0.88, 0.95, 0.94, 1.0);
uniform vec2 land_center = vec2(0.0, -600.0);
uniform vec2 land_extents = vec2(2900.0, 2100.0);
uniform float shore_width = 170.0;
uniform float coast_wobble = 35.0;
uniform float swell_scale = 0.0012;

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
	// Signed-ish distance to the land rectangle, wobbled by noise so the
	// coast reads hand-drawn rather than boxed.
	vec2 q = abs(world_pos - land_center) - land_extents;
	float dist = length(max(q, vec2(0.0)));
	dist += (vnoise(world_pos * 0.004) - 0.5) * 2.0 * coast_wobble;

	vec2 p = world_pos * swell_scale;
	float n = vnoise(p + TIME * vec2(0.045, 0.028));
	n += 0.5 * vnoise(p * 2.7 - TIME * vec2(0.03, 0.05));
	n /= 1.5;
	vec4 color = mix(deep_color, swell_color, smoothstep(0.3, 0.75, n));

	float shore = 1.0 - smoothstep(0.0, shore_width, dist);
	color = mix(color, shallow_color, shore * 0.9);

	// A bright lapping line at the waterline plus faint rolling crests
	// that fade out with depth.
	float lap = smoothstep(34.0, 8.0, abs(dist - 24.0 - 10.0 * sin(TIME * 0.9 + world_pos.x * 0.01 + world_pos.y * 0.013)));
	float crest = sin(dist * 0.05 - TIME * 1.1) * 0.5 + 0.5;
	float roll = smoothstep(0.78, 0.97, crest) * smoothstep(200.0, 60.0, dist) * step(2.0, dist);
	float foam = clamp(lap + roll * (0.3 + 0.7 * vnoise(world_pos * 0.02)), 0.0, 1.0);
	COLOR = mix(color, foam_color, foam * 0.75);
}
