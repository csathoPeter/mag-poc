shader_type spatial;
// Bolygógyűrű: áttetsző, finoman csíkos szalag.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
#include "res://shaders/color_space.gdshaderinc"
uniform vec3 col_a : source_color = vec3(0.9, 0.8, 0.95);
uniform vec3 col_b : source_color = vec3(0.8, 0.95, 0.9);
uniform float night = 0.0;
uniform float seed = 0.0;

void fragment() {
	float x = UV.x;
	float bands = 0.5 + 0.5 * sin(x * 38.0 + seed) * sin(x * 13.0 + seed * 2.0);
	float edge = smoothstep(0.0, 0.12, x) * smoothstep(1.0, 0.8, x);
	vec3 c = mix(col_in(col_a), col_in(col_b), bands);
	ALBEDO = col_out(c * mix(1.0, 0.45, night));
	ALPHA = edge * (0.25 + 0.4 * bands);
}
