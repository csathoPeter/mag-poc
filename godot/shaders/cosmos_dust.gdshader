shader_type spatial;
// A kozmosz csillagpora (cosmos.gd): apró, kamera felé fordított fénypontok egy egyszer feltöltött MultiMesh-ben,
// különböző mélységben (a kamera mozgásával parallaxis). A példány színe: szín + fényesség (alfa); a méret a példány
// x tengelyének hossza. Lassú, halk pislákolás a helyből számolt fázissal.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
#include "res://shaders/color_space.gdshaderinc"

uniform float fade = 1.0;
// a legkisebb látszó méret (radián), hogy messziről is látsszon
uniform float min_ang = 0.0026;
varying vec4 col_v;

void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	s = max(s, distance(c, INV_VIEW_MATRIX[3].xyz) * min_ang);
	vec3 wp = c + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	float ph = fract(sin(dot(c, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 6.2831;
	col_v = COLOR;
	col_v.a *= 0.8 + 0.2 * sin(TIME * (0.6 + 0.9 * fract(ph)) + ph);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float core = exp(-r * r * 18.0);
	float halo = exp(-r * r * 5.0) * 0.35;
	float a = (core + halo) * (1.0 - smoothstep(0.8, 1.0, r));
	vec3 c = mix(col_v.rgb, vec3(1.0), core * 0.5);
	ALBEDO = col_out(c * a * col_v.a * fade);
}
