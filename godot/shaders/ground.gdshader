shader_type spatial;
uniform vec3 moss : source_color = vec3(0.4, 0.5, 0.25);
varying vec3 world_v;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() { world_v = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float tex = n(world_v.xz * 1.1) * 0.5 + n(world_v.xz * 3.7) * 0.3 + n(world_v.xz * 11.0) * 0.2;
	ALBEDO = moss * (0.62 + 0.62 * tex);
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
