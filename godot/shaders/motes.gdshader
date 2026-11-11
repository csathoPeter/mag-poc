shader_type spatial;
// Lebegő fénypontok: nappal halvány pollen, éjjel szentjánosbogár-szerű fények.
// Két helyen: a bolygó körül (planet.gd) és leszállva a kiválasztott fa körül (seasons.gd, near = 1: melegebb,
// jobban látszó pollen, éjjel lassan fel-felvillanó fények). A mozgás az időből jön, a puffer egyszer készül.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
#include "res://shaders/color_space.gdshaderinc"
uniform float night = 0.0;
uniform vec3 glow_col : source_color = vec3(0.6, 1.0, 0.8);
// a látszó pontok aránya (0–1, évszak szerint), és hogy a fa körüli felhő-e
uniform float amount = 1.0;
uniform float near = 0.0;
varying float tw_v;

void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * mix(0.12, 0.09, near) + INSTANCE_CUSTOM.x * 6.2831;
	c += vec3(sin(t * 1.3), sin(t * 0.9 + 1.0), cos(t * 1.1)) * mix(0.35, 0.5, near);
	float on = step(fract(INSTANCE_CUSTOM.x * 7.13 + INSTANCE_CUSTOM.y * 3.1), amount);
	float size = mix(0.07, 0.12, night) * (0.6 + 0.8 * INSTANCE_CUSTOM.y) * mix(1.0, mix(0.7, 1.15, night), near) * on;
	vec3 wp = c + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	float tw = 0.55 + 0.45 * sin(TIME * (1.2 + INSTANCE_CUSTOM.y) + INSTANCE_CUSTOM.x * 40.0);
	// a fa körül éjjel szentjánosbogár: lassú fel-felvillanás, köztük szinte sötét
	float blink = pow(0.5 + 0.5 * sin(TIME * (0.7 + 0.6 * INSTANCE_CUSTOM.y) + INSTANCE_CUSTOM.x * 40.0), 4.0) * 1.6 + 0.04;
	tw_v = mix(tw, mix(tw, blink, night), near);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.0, r);
	a *= a;
	vec3 day = mix(vec3(1.0, 0.95, 0.82) * 0.35, vec3(1.0, 0.84, 0.5) * 0.6, near);
	ALBEDO = col_out(mix(day, col_in(glow_col) * 1.6, night) * a * tw_v);
}
