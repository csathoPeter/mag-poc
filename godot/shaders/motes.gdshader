shader_type spatial;
// Lebegő fénypontok: nappal halvány pollen, éjjel szentjánosbogár-szerű fények.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform float night = 0.0;
uniform vec3 glow_col : source_color = vec3(0.6, 1.0, 0.8);
varying float tw_v;

void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * 0.12 + INSTANCE_CUSTOM.x * 6.2831;
	c += vec3(sin(t * 1.3), sin(t * 0.9 + 1.0), cos(t * 1.1)) * 0.35;
	float size = mix(0.07, 0.12, night) * (0.6 + 0.8 * INSTANCE_CUSTOM.y);
	vec3 wp = c + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	tw_v = 0.55 + 0.45 * sin(TIME * (1.2 + INSTANCE_CUSTOM.y) + INSTANCE_CUSTOM.x * 40.0);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.0, r);
	a *= a;
	vec3 day = vec3(1.0, 0.95, 0.82) * 0.35;
	ALBEDO = mix(day, glow_col * 1.6, night) * a * tw_v;
}
