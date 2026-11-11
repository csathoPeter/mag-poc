// Évszakok (M11, seasons.gd): a valódi dátum (+ teszt-eltolás) szerinti súlyok, globális uniformként:
// x tavasz, y nyár, z ősz, w tél (összegük 1, a határokon napról napra puhán átúsznak). A nyár a semleges, „telt” kép:
// csak hangulat, a DNS-ből adódó színek felismerhetők maradnak.
global uniform vec4 season;

float season_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// A lehullott levelek aránya: ősszel kevés, télen sok (a lomb ritkább).
float season_thin() {
	return season.z * 0.12 + season.w * 0.4;
}

// Levélszín (lineáris): tavasszal világosabb, üdébb; ősszel levelenként arany / narancs / rozsdás árnyalat felé húz
// (a fényerő marad, a saját szín átlátszik); télen kissé fakóbb, a széle és a felfelé néző lemeze deres.
// k: a levél saját véletlen száma (0–1), edge: a széltől való távolság (1 = a szélén), up: mennyire néz felfelé.
vec3 season_leaf(vec3 c, float k, float edge, float up) {
	float l = season_luma(c);
	c = mix(c, c * 1.35 + vec3(0.012, 0.02, 0.0), season.x * 0.8);
	vec3 warm = k < 0.42 ? vec3(0.8, 0.5, 0.05) : (k < 0.78 ? vec3(0.85, 0.24, 0.04) : vec3(0.55, 0.08, 0.04));
	warm *= l / max(season_luma(warm), 1e-4);
	c = mix(c, warm, season.z * (0.16 + 0.3 * fract(k * 7.31)));
	c = mix(c, vec3(l), season.w * 0.28);
	float frost = season.w * clamp(0.5 * smoothstep(0.55, 1.0, edge) + 0.45 * smoothstep(0.5, 0.95, up), 0.0, 1.0);
	return mix(c, vec3(0.74, 0.8, 0.88) * max(l * 2.2, 0.35), frost * 0.6);
}

// Hó/dér a felfelé néző felületeken (az ágak teteje): 0–1.
float season_snow(float up) {
	return season.w * smoothstep(0.3, 0.8, up);
}
