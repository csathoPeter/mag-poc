shader_type spatial;
// A kozmosz távoli galaxisai és ködei (cosmos.gd), egy-egy négyszögön, kódból rajzolva (nincs textúra).
//  kind 0: spirálgalaxis (logaritmikus spirálkarok, csomós fényfoltok, fényes mag), a négyszög a térben áll (döntött
//          korong, perspektívával); kind 1: elliptikus galaxis (puha, sárgás tojás); kind 2: köd (a kamera felé
//          fordul, fbm-felhő két színnel).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
#include "res://shaders/color_space.gdshaderinc"

uniform int kind = 0;
uniform float fade = 1.0;
uniform float strength = 1.0;
uniform vec3 col_core : source_color = vec3(1.0, 0.9, 0.75);
uniform vec3 col_arm : source_color = vec3(0.6, 0.65, 1.0);
uniform float arms = 2.0;
uniform float twist = 2.6;
uniform float seed = 0.0;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm2(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * noise2(p);
		p = p * 2.07 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	if (kind == 2) {
		// a köd a kamera felé fordul
		vec3 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float s = length(MODEL_MATRIX[0].xyz);
		vec3 wp = c + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	} else {
		// (ha a POSITION-t az egyik ág írja, a másiknak is kell: különben a csúcsok összeesnek)
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	vec3 c = vec3(0.0);
	if (kind == 0) {
		float a = atan(p.y, p.x);
		float arm = cos(arms * (a - twist * log(r + 0.04)) + seed);
		float band = pow(0.5 + 0.5 * arm, 2.6);
		float clump = 0.55 + 0.75 * fbm2(p * 7.0 + seed);
		float disk = exp(-r * 3.2) * (1.0 - smoothstep(0.75, 1.0, r));
		float core = exp(-r * r * 60.0) * 1.6 + exp(-r * r * 9.0) * 0.35;
		c = col_in(col_arm) * disk * band * clump * 1.1 + col_in(col_core) * (core + disk * 0.25);
	} else if (kind == 1) {
		float e = exp(-r * r * 5.0);
		c = col_in(col_core) * (e * 0.45 + exp(-r * r * 40.0) * 0.8) * (1.0 - smoothstep(0.8, 1.0, r));
	} else {
		float n = fbm2(p * 1.6 + seed);
		float m = fbm2(p * 3.1 - seed * 1.3 + n * 1.8);
		// kerek lecsengés: a négyszög széle sosem látszik
		float shape = exp(-r * r * 3.0) * (1.0 - smoothstep(0.55, 0.98, r)) * smoothstep(0.35, 0.8, n + 0.25 * m);
		c = mix(col_in(col_arm), col_in(col_core), smoothstep(0.35, 0.75, m)) * shape * 0.55;
	}
	ALBEDO = col_out(c * strength * fade);
}
