shader_type sky;
#include "res://shaders/color_space.gdshaderinc"
// Az űr a bolygók körül: nappal álomszerű pasztell köd, alkonyatkor rózsaszín-lila, éjjel mélykék csillagokkal.
// A színátmenet a fény irányához igazodik, nem a "fent"-hez, mert a bolygót bármerre lehet forgatni.
uniform float night = 0.0;
uniform float dusk = 0.0;
// a kozmosz (a kicsinyítés utolsó fokozata, sky_stars.gd): mély, sötét űr, fényes háttércsillagok
uniform float cosmos = 0.0;
uniform vec3 day_a : source_color = vec3(1.0, 0.87, 0.78);
uniform vec3 day_b : source_color = vec3(0.76, 0.74, 0.96);
uniform vec3 day_c : source_color = vec3(0.72, 0.93, 0.9);
uniform vec3 dusk_a : source_color = vec3(1.0, 0.64, 0.7);
uniform vec3 dusk_b : source_color = vec3(0.42, 0.33, 0.68);
uniform vec3 night_a : source_color = vec3(0.09, 0.1, 0.27);
uniform vec3 night_b : source_color = vec3(0.015, 0.02, 0.07);
// 0: előre kiszámolt 3D zajtextúra (olcsó), 1: köd nélkül (mérés), 2: a régi, pixelenként számolt zaj (mérés)
uniform int mode = 0;
uniform sampler3D nebula : filter_linear, repeat_enable;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

float stars(vec3 d, float scale, float thr) {
	vec3 p = d * scale;
	vec3 cell = floor(p);
	float h = hash(cell + 7.0);
	vec3 off = vec3(hash(cell + 1.0), hash(cell + 2.0), hash(cell + 3.0)) - 0.5;
	float r = length(fract(p) - 0.5 - off * 0.5);
	return step(thr, h) * smoothstep(0.3, 0.0, r) * (0.5 + 0.5 * hash(cell + 9.0));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float l = dot(d, LIGHT0_DIRECTION) * 0.5 + 0.5;
	float n1 = 0.5;
	float n2 = 0.5;
	if (mode == 0) {
		n1 = texture(nebula, d * 0.5 + 0.5).r;
		n2 = texture(nebula, d * 1.05 + n1 * 0.35 + 0.3).r;
	} else if (mode == 2) {
		n1 = fbm(d * 2.2);
		n2 = fbm(d * 4.5 + n1 * 1.5);
	}
	vec3 day = mix(mix(col_in(day_b), col_in(day_c), smoothstep(0.35, 0.65, n1)), col_in(day_a), smoothstep(0.45, 1.0, l));
	day = mix(day, day * 1.05 + 0.05, smoothstep(0.5, 0.75, n2));
	vec3 du = mix(col_in(dusk_b), col_in(dusk_a), pow(l, 1.4));
	du = mix(du, du * 1.12 + 0.03, smoothstep(0.5, 0.78, n2));
	vec3 ni = mix(col_in(night_b), col_in(night_a), smoothstep(0.3, 0.75, n1) * 0.8 + l * 0.25);
	ni += vec3(0.32, 0.14, 0.45) * smoothstep(0.52, 0.85, n2) * 0.3;
	vec3 c = mix(mix(day, du, dusk), ni, night);
	vec3 deep = mix(col_in(night_b) * 0.6, col_in(night_a) * 0.55, smoothstep(0.3, 0.8, n1) * 0.7);
	deep += vec3(0.22, 0.1, 0.35) * smoothstep(0.55, 0.88, n2) * 0.22;
	c = mix(c, deep, cosmos);
	float s = stars(d, 170.0, 0.975) + stars(d, 60.0, 0.993) * 1.6;
	c += vec3(0.95, 0.95, 1.0) * s * mix(mix(0.08, 1.0, night), 0.8, cosmos);
	COLOR = col_out(c);
}
