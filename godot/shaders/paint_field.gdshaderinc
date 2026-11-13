// Festett fű (art direction, 2026. 11. 13., art/kor02 „B” sor): a fűmező egy festett felület, nem szőr.
// A talaj (planet.gdshader) és a fűszál (planet_grass.gdshader) ugyanazt a mezőt számolja a bolygó-irányból, így a szál
// töve pontosan a talaj színe, és a szálak csak ecsetvonásként (világosabb csúcs, széllökés) és a látóhatáron látszanak.
// - Széles tónus-sávok: a szél tengelye körül elnyújtott, puha szélű foltok (mint a festett domb sávjai), két léptékben.
//   A sávok nyers értékét a planet.gd számolja a domborzat rácsába (_paint_raw): a talaj csúcspont-színként (COLOR.b),
//   a fű a magasság-textúra G csatornájából olvassa, ugyanazon a háromszögön ugyanúgy interpolálva – így a kettő pontosan
//   egyezik, és a szálaknak csúcspontonként nem kell zajt számolniuk (leszállva ~1 millió csúcspont).
// - A sötét sáv kicsit hűvösebb, a világos melegebb; az árnyékot a light() lilás színnel tölti (soft_light.gdshaderinc).
// paint_k: 0 = a korábbi (szálas) fű, 1 = festett; a fejlesztői „festett fű” kapcsoló, ?fu=regi (main.gd _soft_globals).
global uniform float paint_k;

// ugyanaz a tengely, mint a fű szelének alapértéke (planet_grass.gdshader wind_axis, planet.gd PAINT_AXIS): az ecsetnyomok a
// szél irányában futnak
const vec3 PF_AXIS = vec3(0.2822, 0.9407, 0.1881);

float pf_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float pf_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(pf_hash(i), pf_hash(i + vec3(1, 0, 0)), f.x), mix(pf_hash(i + vec3(0, 1, 0)), pf_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(pf_hash(i + vec3(0, 0, 1)), pf_hash(i + vec3(1, 0, 1)), f.x), mix(pf_hash(i + vec3(0, 1, 1)), pf_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// A tengely mentén összenyomott tér: a foltok a tengely körül körbefutó, elnyújtott sávok lesznek (varrat nélkül).
vec3 pf_warp(vec3 d, float s, float squash) {
	return d * s + PF_AXIS * (dot(d, PF_AXIS) * s * squash);
}

// A mező tónusa (0 sötét – 1 világos) a rácsból interpolált nyers értékből: a puha, de határozott szél itt, az
// interpoláció után készül, így a sávok széle görbe marad (nem a rács háromszögeit követi).
float paint_band(float raw) {
	return smoothstep(0.34, 0.66, raw);
}

// A festett mező színe (lineáris): a fű alapszíne a sávban sötétebb-hűvösebb vagy világosabb-melegebb.
vec3 paint_tone(vec3 field, float band) {
	vec3 dark = field * vec3(0.56, 0.56, 0.7);
	vec3 light = field * vec3(1.14, 1.1, 0.98);
	return mix(dark, light, band);
}

// Második szín (art direction 3. kör, art/kor03): a csúcsok világosabbak és melegebbek, a völgyek a légkör színe felé
// hajlanak (azonos fényességgel). hv: a magasság 0 (legmélyebb völgy) – 1 (legmagasabb csúcs), mint a talaj COLOR.r-je.
// A talaj és a fűszál töve ugyanezzel számol, így a szál töve továbbra is pontosan a talaj színe.
vec3 paint_relief(vec3 c, float hv, vec3 atmo) {
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	vec3 atmo_n = atmo * (dot(c, w) / max(dot(atmo, w), 1e-3));
	vec3 valley = mix(c, atmo_n, 0.28) * 0.86;
	vec3 peak = c * vec3(1.1, 1.06, 0.95);
	return mix(valley, peak, smoothstep(0.2, 0.85, hv));
}

// A gömb pontja a kocka egyik lapján (gnomonikus vetület, a lapok eltolva, hogy ne ismétlődjön a minta): síkbeli
// cellás mintához (kavics). A lapok határán a minta elvágódik – kicsi, a távolban elsimul.
vec2 pf_face_uv(vec3 d) {
	vec3 a = abs(d);
	if (a.y >= a.x && a.y >= a.z) return d.xz / a.y + (d.y > 0.0 ? vec2(11.0, 3.0) : vec2(-7.0, 29.0));
	if (a.x >= a.z) return d.yz / a.x + (d.x > 0.0 ? vec2(41.0, -13.0) : vec2(-23.0, 17.0));
	return d.xy / a.z + (d.z > 0.0 ? vec2(5.0, 53.0) : vec2(-37.0, -31.0));
}

vec2 pf_hash2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

// Kerek kövek egy síkon: cellánként egy kő (dens valószínűséggel), a 3×3 szomszédból a legközelebbi számít.
// x: a kő fedése (puha széllel), y: a kupola (1 a közepén, 0 a szélén).
vec2 pf_pebble(vec2 uv, float s, float dens) {
	vec2 q = uv * s;
	vec2 cell = floor(q);
	float best = 9.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			vec2 h = pf_hash2(c);
			if (h.x > dens) {
				continue;
			}
			vec2 o = pf_hash2(c + 17.31);
			// különböző méret, kicsit nyújtott, elforgatott kő (nem szabályos kör: ettől nem pöttyös)
			float r = mix(0.16, 0.42, fract(h.y * 7.13));
			vec2 dv = q - c - 0.2 - 0.6 * o;
			float an = o.x * 6.2831;
			dv = mat2(vec2(cos(an), sin(an)), vec2(-sin(an), cos(an))) * dv;
			dv.x /= mix(1.0, 1.7, o.y);
			best = min(best, length(dv) / r);
		}
	}
	float aa = clamp(length(fwidth(q)) * 2.0, 0.03, 1.0);
	return vec2(1.0 - smoothstep(1.0 - aa, 1.0, best), clamp(1.0 - best * best, 0.0, 1.0));
}

// A felszíntakaró festett mintája a talajon (art direction 3. kör), cover_kind szerint: 1 moha (bársonyos párnák, köztük
// sötétebb, hűvösebb rések), 2 páfrány (nagyobb, halkabb levélcsomók), 3 kavics (homok, foltokban halk, változatos
// kövek, a kupolájuk világosabb). 0 (fű): változatlan. d: egységirány, c: a festett mező színe. A minta a távolban (ahol
// vibrálna) a mező színébe simul (fwidth).
vec3 paint_cover(vec3 c, vec3 d, int kind, float hv) {
	if (kind == 0) {
		return c;
	}
	vec3 crev = c * vec3(0.5, 0.52, 0.66);
	if (kind == 3) {
		// kavics (art direction 3. kör): homokos alap, a kövek csak foltokban (főleg a völgyekben, a lejtők alján), halk
		// kontraszttal – festett textúra, nem pöttyös bolygó. Péter: az egyenletesen szórt, kontrasztos kövektől pöttyös lett.
		vec3 sand = c * vec3(1.08, 1.05, 1.0);
		vec2 uv = pf_face_uv(d);
		float f2 = clamp(1.0 - length(fwidth(uv * 34.0)) * 1.6, 0.0, 1.0);
		float patch = smoothstep(0.52, 0.8, pf_noise(d * 7.0 + 2.9)) * (1.0 - 0.75 * smoothstep(0.45, 0.8, hv));
		vec2 pb = (f2 > 0.0 && patch > 0.0) ? pf_pebble(uv + 3.7, 34.0, 0.7) : vec2(0.0);
		float k = pb.x * f2 * patch;
		// a foltban a homok is kicsit sötétebb, szemcsésebb (a kövek közti árnyék)
		sand *= 1.0 - 0.08 * patch * f2;
		vec3 rock = c * mix(0.78, 1.0, pb.y) * vec3(0.97, 0.96, 1.02);
		return mix(sand, rock, k);
	}
	float s1 = kind == 1 ? 11.0 : 7.5;
	float s2 = kind == 1 ? 29.0 : 19.0;
	float f1 = clamp(1.0 - length(fwidth(d * s1)) * 1.4, 0.0, 1.0);
	float f2 = clamp(1.0 - length(fwidth(d * s2)) * 1.4, 0.0, 1.0);
	float n1 = pf_noise(d * s1 + 7.1);
	float n2 = pf_noise(d * s2 + 2.3);
	float m = mix(n1, n1 * 0.55 + n2 * 0.45, f2);
	float cush = smoothstep(0.34, 0.5, m);
	float dome = smoothstep(0.42, 0.85, m);
	vec3 pc = mix(crev, c * mix(0.88, 1.22, dome), cush);
	// a páfrány alatti talaj halkabb (a csomókat a levélkés szálak adják)
	return mix(c, pc, f1 * (kind == 1 ? 1.0 : 0.6));
}

