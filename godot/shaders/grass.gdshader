shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
uniform vec3 moss : source_color = vec3(0.4, 0.5, 0.25);
uniform float amp = 0.09;
uniform vec3 glow_col : source_color = vec3(0.5, 1.0, 0.8);
uniform float glow_amt = 0.0;
varying float tint_v;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 n = normalize(MODEL_MATRIX[1].xyz);
	float s = sin(TIME * 1.6 + o.x * 2.1 + o.z * 1.7) * 0.05 * UV.x * UV.x * step(0.001, amp);
	vec3 w = vec3(s, 0.0, s * 0.6);
	VERTEX += w - n * dot(w, n);
	tint_v = INSTANCE_CUSTOM.y;
	NORMAL = n;
}

void fragment() {
	ALBEDO = mix(moss * 0.8, moss * 1.9, UV.x) * (0.75 + tint_v * 0.5);
	ROUGHNESS = 0.8;
	SPECULAR = 0.15;
	BACKLIGHT = ALBEDO * 0.5;
	EMISSION = glow_col * glow_amt * smoothstep(0.8, 1.0, tint_v) * UV.x * UV.x * 1.4;
}
