shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
uniform vec3 moss : source_color = vec3(0.4, 0.5, 0.25);
uniform float amp = 0.09;
varying float tint_v;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float s = sin(TIME * 1.6 + o.x * 2.1 + o.z * 1.7) * 0.05 * UV.x * UV.x * step(0.001, amp);
	VERTEX += vec3(s, 0.0, s * 0.6);
	tint_v = INSTANCE_CUSTOM.y;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = mix(moss * 0.8, moss * 1.9, UV.x) * (0.75 + tint_v * 0.5);
	ROUGHNESS = 0.8;
	SPECULAR = 0.15;
	BACKLIGHT = ALBEDO * 0.5;
}
