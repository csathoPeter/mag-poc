shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
#include "res://shaders/common.gdshaderinc"
uniform vec3 petal : source_color = vec3(0.9, 0.5, 0.6);
uniform vec3 petal_tip : source_color = vec3(0.95, 0.7, 0.8);
uniform vec3 throat : source_color = vec3(0.9, 0.7, 0.3);
uniform vec3 stamen : source_color = vec3(0.9, 0.65, 0.2);
varying float kind_v;
varying float tint_v;
varying float u_v;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 axis = normalize(MODEL_MATRIX[1].xyz);
	float g = smoothstep(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.x + 0.07, grow);
	float open = smoothstep(INSTANCE_CUSTOM.x + 0.03, INSTANCE_CUSTOM.x + 0.15, grow);
	vec3 p = VERTEX - o;
	float along = dot(p, axis);
	p = axis * along + (p - axis * along) * mix(0.32, 1.0, open);
	VERTEX = o + p * g + sway(o, TIME);
	kind_v = COLOR.r;
	tint_v = INSTANCE_CUSTOM.y;
	u_v = (INSTANCE_CUSTOM.x - 0.74) / 0.14;
}

void fragment() {
	if (kind_v > 0.5) {
		ALBEDO = stamen;
		ROUGHNESS = 0.8;
	} else {
		vec3 c = mix(throat, mix(petal, petal_tip, smoothstep(0.25, 1.0, UV.x)), smoothstep(0.0, 0.34, UV.x)) * tint_v;
		ALBEDO = c * (0.94 + 0.1 * sin(UV.y * 22.0));
		ROUGHNESS = 0.5;
		SPECULAR = 0.3;
		BACKLIGHT = ALBEDO * 1.1;
	}
	EMISSION = glow_col * (glow_amt * (part_on(0.0) * (smoothstep(0.1, 0.9, UV.x) * 3.2 + 0.9) + 0.12) + touch_wave(u_v) * 1.2);
}
