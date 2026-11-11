shader_type spatial;
// Kis bolygó a háttérben (M7, planet_system.gd): egy alacsony felbontású gömb a bolygó színeivel – kőzet és
// felszíntakaró foltokban (a bolygókódból), a peremen a légkör párája, a fák apró színes pöttyök (legfeljebb 16).
// Születéskor fehéren izzó fénygömbből bomlik ki (bloom). Átlátszatlan (az átlátszó tárgyakat a lencse-utófeldolgozás
// lefedné), kicsinyítéskor rendezett pontrácsos áttűnéssel tűnik elő (fade).
render_mode cull_back, shadows_disabled, fog_disabled;
uniform vec3 rock : source_color = vec3(0.6, 0.55, 0.6);
uniform vec3 grass : source_color = vec3(0.5, 0.7, 0.5);
uniform vec3 atmo : source_color = vec3(0.8, 0.7, 0.9);
uniform float seed = 0.0;
uniform float night = 0.0;
// a foltok erőssége (csupasz bolygón 0: egyszínű gyöngyház)
uniform float patches = 1.0;
// születés: 1 = fehéren izzó fénygömb, 0 = a saját színe
uniform float bloom = 0.0;
uniform float fade = 1.0;
uniform int dot_n = 0;
// xyz: a fa iránya a gömbön, w: a pötty mérete (radián)
uniform vec4 dots[16];
// rgb: szín, a: 0 = kikelt fa, 1 = kikelésre vár (meleg, lüktet), 2 = a földben váró mag (halvány)
uniform vec4 dot_cols[16];
varying vec3 obj_n;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	obj_n = normalize(VERTEX);
}

void fragment() {
	if (fade < 0.999) {
		// rendezett (Bayer 4×4) pontrács: puha áttűnés átlátszóság nélkül
		ivec2 q = ivec2(FRAGCOORD.xy) % 4;
		int b[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
		if ((float(b[q.y * 4 + q.x]) + 0.5) / 16.0 > fade) {
			discard;
		}
	}
	vec3 n = normalize(obj_n);
	vec3 o = vec3(seed, seed * 1.7, seed * 0.6);
	float h = vnoise(n * 2.4 + o) * 0.65 + vnoise(n * 5.3 + o * 1.3) * 0.35;
	float g = mix(0.55, smoothstep(0.38, 0.6, h), patches);
	vec3 c = mix(rock * (0.82 + 0.3 * h), grass * (0.8 + 0.3 * vnoise(n * 11.0 + o)), g);
	vec3 e = vec3(0.0);
	for (int i = 0; i < 16; i++) {
		if (i >= dot_n) {
			break;
		}
		float r = dots[i].w;
		float k = smoothstep(cos(r), cos(r * 0.35), dot(n, dots[i].xyz));
		float kind = dot_cols[i].a;
		vec3 col = dot_cols[i].rgb;
		if (kind < 0.5) {
			c = mix(c, col, k * 0.92);
			e += col * k * (0.05 + 0.55 * night);
		} else {
			float pulse = kind < 1.5 ? 0.55 + 0.45 * sin(TIME * 2.4 + float(i) * 1.7) : 0.35;
			c = mix(c, col, k * 0.6);
			e += col * k * pulse * (kind < 1.5 ? 1.1 : 0.4);
		}
	}
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(mix(c, atmo, fr * 0.45), vec3(1.0, 0.98, 0.94), bloom);
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
	EMISSION = atmo * fr * mix(0.3, 0.22, night) + e + vec3(1.0, 0.96, 0.9) * bloom * 2.2 + grass * night * 0.05;
}
