shader_type spatial;
// A kis bolygó gyűrűje (M7, planet_system.gd): mint a ring.gdshader, de átlátszatlan (pontrácsos áttetszés), hogy a
// lencse-utófeldolgozás ne fedje le.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/color_space.gdshaderinc"
uniform vec3 col_a : source_color = vec3(0.9, 0.8, 0.95);
uniform vec3 col_b : source_color = vec3(0.8, 0.95, 0.9);
uniform float night = 0.0;
uniform float seed = 0.0;
uniform float fade = 1.0;

void fragment() {
	float x = UV.x;
	float bands = 0.5 + 0.5 * sin(x * 38.0 + seed) * sin(x * 13.0 + seed * 2.0);
	float edge = smoothstep(0.0, 0.12, x) * smoothstep(1.0, 0.8, x);
	float a = edge * (0.3 + 0.45 * bands) * fade;
	ivec2 q = ivec2(FRAGCOORD.xy) % 4;
	int b[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	if ((float(b[q.y * 4 + q.x]) + 0.5) / 16.0 > a) {
		discard;
	}
	ALBEDO = col_out(mix(col_in(col_a), col_in(col_b), bands) * mix(1.0, 0.45, night));
}
