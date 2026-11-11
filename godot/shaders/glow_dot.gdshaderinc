#include "res://shaders/color_space.gdshaderinc"
// Fénylő pont a kamera felé fordított négyszögön (a „nagy pillanat” golyói, a mag, a kelésre váró magok jele).
// Olcsó ragyogás: önvilágító mag + puha, additív haló, valódi bloom nélkül (weben is ugyanígy néz ki).
// A MultiMesh példány színe (COLOR: szín és erősség az alfában) és saját adata (INSTANCE_CUSTOM):
//   x: a lüktetés fázisa (0–1), y: 0 = pont, 1 = táguló gyűrű, z: a lüktetés erőssége (0 = nem lüktet)
// A méret a példány x tengelyének hossza (az átmérő).

// a legkisebb látszó méret a távolság arányában, hogy messziről (a bolygó-nézetből) is látsszon
uniform float min_ang = 0.0;
varying vec4 col_v;
varying float ring_v;

void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	s = max(s, distance(c, INV_VIEW_MATRIX[3].xyz) * min_ang);
	float ph = TIME * 1.7 + INSTANCE_CUSTOM.x * 6.2831;
	float p = 1.0 + INSTANCE_CUSTOM.z * sin(ph);
	vec3 wp = c + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s * p;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	col_v = COLOR;
	col_v.a *= 1.0 + INSTANCE_CUSTOM.z * 1.4 * sin(ph);
	ring_v = INSTANCE_CUSTOM.y;
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float edge = 1.0 - smoothstep(0.82, 1.0, r);
	float core = exp(-r * r * 16.0);
	float halo = exp(-r * r * 4.0) * 0.45;
	float ring = exp(-pow((r - 0.7) * 6.0, 2.0)) * 0.8;
	float a = mix(core + halo, ring, ring_v) * edge;
	// a mag közepe fehérbe hajlik, a haló megtartja a pasztell színt
	vec3 c = mix(col_v.rgb, vec3(1.0), core * 0.45 * (1.0 - ring_v));
	ALBEDO = col_out(c * a * max(col_v.a, 0.0));
}
