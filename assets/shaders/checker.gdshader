shader_type canvas_item;
// World-space checkerboard — the start line and gantry accents.

uniform float cell = 16.0;
uniform vec4 dark : source_color = vec4(0.12, 0.12, 0.13, 1.0);
uniform vec4 light : source_color = vec4(0.93, 0.93, 0.92, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 c = floor(world_pos / cell);
	COLOR = mix(dark, light, mod(c.x + c.y, 2.0));
}
