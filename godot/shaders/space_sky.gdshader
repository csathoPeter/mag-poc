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
// Festett ég (art direction, 2026. 11. 13., art/kor02 „B” sor): gouache-szerű felhők a köd-textúrából – a nap felőli
// oldaluk meleg, világos, az árnyékos oldaluk lilás (alkonyatkor rózsás / lila, éjjel halvány sötétkék); a kozmoszban
// nincsenek. paint_k: a festett stílus kapcsolója (a fűvel közös: ?fu=regi, fejlesztői „festett fű”).
global uniform float paint_k;

// a felhő sűrűsége (0–1) egy irányban: nagy, kerek tömbök (két lépték), puha, de határozott, kicsit hullámos széllel
float cloud_raw(vec3 d) {
	float big = texture(nebula, d * 0.62 + vec3(0.13, 0.41, 0.77)).r;
	float det = texture(nebula, d * 2.6 + vec3(0.71, 0.29, 0.05)).r;
	return big * 0.7 + det * 0.3;
}

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
	// festett felhők: a sűrűség a nap felé eső szomszédban kisebb → az a nap felőli (világos) perem
	if (mode == 0 && paint_k > 0.0 && cosmos < 0.999) {
		vec3 L = LIGHT0_DIRECTION;
		vec3 tl = L - d * dot(d, L);
		float tlen = length(tl);
		vec3 dl = normalize(d + (tlen > 1e-4 ? tl / tlen : vec3(0.0)) * 0.06);
		float cr = cloud_raw(d);
		// a sűrűség felső ~20%-a felhő (a köd-textúra mediánja ~0,49, szórása ~0,15): tiszta égen külön gomolyok
		float cov = smoothstep(0.585, 0.615, cr);
		float lit = clamp((cr - cloud_raw(dl)) * 16.0 + 0.5, 0.0, 1.0);
		// a felhő közepe felé kicsit árnyékosabb (vastagabb)
		float core = smoothstep(0.62, 0.72, cr);
		vec3 day_lit = mix(vec3(1.0, 0.985, 0.96), col_in(day_a), 0.2);
		vec3 day_sh = mix(col_in(day_b), vec3(0.56, 0.54, 0.82), 0.6);
		vec3 du_lit = mix(col_in(dusk_a), vec3(1.0, 0.86, 0.72), 0.45);
		vec3 du_sh = mix(col_in(dusk_b), col_in(dusk_a), 0.25);
		vec3 ni_lit = col_in(night_a) * 1.7 + vec3(0.02, 0.03, 0.06);
		vec3 ni_sh = col_in(night_b) * 1.6 + vec3(0.01, 0.01, 0.03);
		vec3 cl_lit = mix(mix(day_lit, du_lit, dusk), ni_lit, night);
		vec3 cl_sh = mix(mix(day_sh, du_sh, dusk), ni_sh, night);
		vec3 cl = mix(cl_sh, cl_lit, smoothstep(0.25, 0.75, lit) * mix(1.0, 0.8, core));
		float a = cov * mix(0.97, 0.55, night) * (1.0 - cosmos) * paint_k;
		c = mix(c, cl, a);
	}
	vec3 deep = mix(col_in(night_b) * 0.6, col_in(night_a) * 0.55, smoothstep(0.3, 0.8, n1) * 0.7);
	deep += vec3(0.22, 0.1, 0.35) * smoothstep(0.55, 0.88, n2) * 0.22;
	c = mix(c, deep, cosmos);
	float s = stars(d, 170.0, 0.975) + stars(d, 60.0, 0.993) * 1.6;
	c += vec3(0.95, 0.95, 1.0) * s * mix(mix(0.08, 1.0, night), 0.8, cosmos);
	COLOR = col_out(c);
}
