shader_type spatial;
// Évszakos részecskék a kiválasztott (leszállt) fa körül (M11, seasons.gd): ősszel hulló levelek, tavasszal szálló
// szirmok, télen lassan szállingózó hópelyhek. Minden mozgás itt, időből és a példány saját számaiból születik: a
// MultiMesh puffere egyszer készül, képkockánként semmi nem frissül (olcsó, és weben is biztosan mozog).
// A csomópont a fa tövénél áll, a fa „felfelé” irányával (helyi y), így minden a fa keretében számolódik.
// INSTANCE_CUSTOM: x, y: a részecske két véletlen száma, z: melyik fajta lehet (az évszak súlyaival összevetve).
render_mode cull_disabled, shadows_disabled;
#include "res://shaders/color_space.gdshaderinc"
#include "res://shaders/season.gdshaderinc"
// a fa magassága és a lomb sugara (világ-egységben), a bolygó sugara (a talaj görbüléséhez)
uniform float tree_h = 5.0;
uniform float crown_r = 2.5;
uniform float planet_r = 6.0;
uniform vec3 leaf_col : source_color = vec3(0.3, 0.6, 0.25);
uniform vec3 petal_col : source_color = vec3(0.95, 0.7, 0.8);
uniform float night = 0.0;
// 0 = nem látszik (a csomópont elrejtve sem fut), 1 = teljes
uniform float amount = 1.0;
varying float kind_v;
varying float k_v;
varying vec2 q_v;

float h1(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

void vertex() {
	float a = INSTANCE_CUSTOM.x;
	float b = INSTANCE_CUSTOM.y;
	float u = INSTANCE_CUSTOM.z;
	float f_leaf = season.z * 0.75 * amount;
	float f_snow = season.w * 0.95 * amount;
	float f_petal = season.x * 0.4 * amount;
	// 0 levél, 1 szirom, 2 hópehely, 3 nincs
	float kind = u < f_leaf ? 0.0 : (u < f_leaf + f_snow ? 2.0 : (u < f_leaf + f_snow + f_petal ? 1.0 : 3.0));
	float period = kind == 2.0 ? 14.0 + b * 6.0 : (kind == 1.0 ? 9.0 + b * 4.0 : 10.0 + b * 5.0);
	float tt = TIME / period + a;
	float cyc = floor(tt);
	float f = fract(tt);
	// minden körben új helyről indul
	float r1 = h1(cyc + a * 91.0);
	float r2 = h1(cyc * 1.7 + b * 53.0);
	float r3 = h1(cyc * 2.3 + a * 17.0 + b);
	float ang = r1 * 6.2831;
	float rr = kind == 2.0 ? sqrt(r2) * crown_r * 1.7 : mix(0.25, 1.0, sqrt(r2)) * crown_r;
	float y0 = kind == 2.0 ? tree_h * (1.15 + r3 * 0.4) : tree_h * mix(0.4, 0.92, r3);
	vec3 p0 = vec3(cos(ang) * rr, y0, sin(ang) * rr);
	// sodródás és libegés (a levél és a szirom jobban, a hó alig)
	float sway_k = kind == 2.0 ? 0.12 : 0.32;
	vec3 drift = vec3(0.55, 0.0, 0.25) * f * (kind == 2.0 ? 0.6 : 1.4);
	vec3 p = p0 + drift;
	p.x += sin(f * period * 1.3 + a * 20.0) * sway_k;
	p.z += cos(f * period * 1.1 + b * 20.0) * sway_k;
	float ground = -dot(p.xz, p.xz) / (2.0 * planet_r) + 0.04;
	p.y = mix(y0, ground, f);
	// méret: kinő az elején, a talajon elfogy
	float size = (kind == 2.0 ? 0.06 : (kind == 1.0 ? 0.12 : 0.17)) * tree_h / 5.0;
	size *= smoothstep(0.0, 0.05, f) * (1.0 - smoothstep(0.9, 1.0, f)) * step(kind, 2.5);
	vec3 v = VERTEX * size;
	vec3 n = vec3(0.0, 0.0, 1.0);
	if (kind < 1.5) {
		// pörgés-billegés a levél saját tengelye körül
		float spin = TIME * (1.2 + b * 1.6) + a * 10.0;
		float tilt = sin(TIME * (0.9 + a) + b * 6.0) * 1.1;
		mat3 rz = mat3(vec3(cos(spin), sin(spin), 0.0), vec3(-sin(spin), cos(spin), 0.0), vec3(0.0, 0.0, 1.0));
		mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(tilt), sin(tilt)), vec3(0.0, -sin(tilt), cos(tilt)));
		v = rx * rz * v;
		n = rx * rz * n;
	} else {
		// a hópehely a kamera felé fordul
		mat3 inv = transpose(mat3(MODEL_MATRIX));
		v = inv * (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * size;
		n = inv * INV_VIEW_MATRIX[2].xyz;
	}
	VERTEX = p + v;
	NORMAL = n;
	kind_v = kind;
	k_v = b;
	q_v = UV;
}

void fragment() {
	vec2 q = q_v - 0.5;
	vec3 c;
	if (kind_v < 0.5) {
		// levél: hegyes ovális, ősszel meleg árnyalat (levelenként más), a fa saját színe átlátszik
		float w = 0.36 * pow(max(sin(3.14159 * (q.y + 0.5)), 0.0), 0.8);
		if (abs(q.x) > w) {
			discard;
		}
		c = season_leaf(col_in(leaf_col), k_v, 0.0, 0.0);
		vec3 warm = k_v < 0.42 ? vec3(0.8, 0.5, 0.05) : (k_v < 0.78 ? vec3(0.85, 0.24, 0.04) : vec3(0.55, 0.08, 0.04));
		c = mix(c, warm * 0.8, 0.35) * (0.9 + 0.2 * smoothstep(0.05, 0.0, abs(q.x)));
		ROUGHNESS = 0.6;
		BACKLIGHT = c * 0.4 * backlight_k();
	} else if (kind_v < 1.5) {
		// szirom: lekerekített csepp
		float w = 0.42 * sqrt(max(0.5 - q.y, 0.0)) * smoothstep(-0.5, -0.2, q.y);
		if (abs(q.x) > w) {
			discard;
		}
		c = col_in(petal_col) * (0.85 + 0.25 * (0.5 - q.y));
		ROUGHNESS = 0.5;
		BACKLIGHT = c * 0.6 * backlight_k();
	} else {
		// hópehely: puha fehér pötty, éjjel halványan dereng
		float r = length(q) * 2.0;
		if (r > 1.0) {
			discard;
		}
		c = vec3(0.92, 0.95, 1.0);
		EMISSION = col_out(vec3(0.6, 0.7, 0.9) * (1.0 - r) * (0.15 + 0.5 * night));
	}
	ALBEDO = col_out(c);
}
