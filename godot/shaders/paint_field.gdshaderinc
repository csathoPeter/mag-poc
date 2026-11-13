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

// A felszíntakaró textúrája (art direction 3. kör, Péter ötlete: mipmap + bump map): csempézhető, kódból generált
// adat-textúra (tools/gen_ground_tex.py → textures/talaj_*.png; RG = normál, B = árnyalás, A = fedés), mipmapekkel – a
// távolban magától elsimul. A gömbön három irányból vetítve (triplanáris, varrat nélkül). A normál-eltérés a bolygó
// tárgyterében jön vissza (a domborzat gradiense a világ tengelyei mentén, így a gömb minden oldalán ugyanonnan világít).
// p: a pont a bolygó tárgyterében, csempe-egységben; d: egységirány (a súlyokhoz). out pert: a normál eltérése.
vec4 paint_tex(sampler2D tex, vec3 p, vec3 d, out vec3 pert) {
	vec3 w = d * d;
	w *= w;
	w /= dot(w, vec3(1.0));
	vec4 tx = texture(tex, p.yz);
	vec4 ty = texture(tex, p.xz);
	vec4 tz = texture(tex, p.xy);
	vec2 nx = tx.rg * 2.0 - 1.0;
	vec2 ny = ty.rg * 2.0 - 1.0;
	vec2 nz = tz.rg * 2.0 - 1.0;
	pert = vec3(0.0, nx.x, nx.y) * w.x + vec3(ny.x, 0.0, ny.y) * w.y + vec3(nz.x, nz.y, 0.0) * w.z;
	return tx * w.x + ty * w.y + tz * w.z;
}

// A takaró színe a textúrából (cover_kind: 1 moha, 2 páfrány, 3 kavics; 0 fű: változatlan). t: a paint_tex eredménye,
// c: a festett mező színe, d: egységirány, hv: magasság (0 völgy – 1 csúcs). out k: a bump ereje ezen a ponton.
// Kavics: homok, a kövek csak foltokban (főleg a völgyekben), a kő tónusa a bolygó színéből; moha: párnák, köztük
// sötétebb, hűvösebb rés; páfrány: a moha-textúra halkan (a csomókat a levélkés szálak adják).
vec3 paint_cover(vec3 c, vec4 t, vec3 d, int kind, float hv, out float k) {
	k = 0.0;
	if (kind == 0) {
		return c;
	}
	float shade = t.b * 2.0;
	if (kind == 3) {
		float patch = smoothstep(0.3, 0.6, pf_noise(d * 6.0 + 2.9)) * (1.0 - 0.6 * smoothstep(0.5, 0.85, hv));
		vec3 sand = c * vec3(1.08, 1.05, 1.0);
		vec3 grit = sand * mix(1.0, shade, 0.6);
		// a kő tónusa kőnként más (a textúra B csatornája 0,42–0,58), a homoknál sötétebb, kicsit hűvösebb
		// (a név nem „rock”: a planet.gdshader-nek ilyen nevű uniformja van, és a Mobile renderer fordítója azt vette)
		vec3 stone_c = c * mix(0.58, 0.9, clamp((t.b - 0.42) / 0.16, 0.0, 1.0)) * vec3(0.95, 0.94, 1.04);
		k = patch;
		return mix(sand, mix(grit, stone_c, t.a), patch);
	}
	// moha: halk rés a párnák közt, a párna teteje kicsit világosabb; foltokban erősebb (a völgyekben), máshol szinte
	// sima – így nem macskakő / terítőminta, és a csempe ismétlődése sem tűnik fel
	vec3 crev = c * vec3(0.74, 0.75, 0.84);
	vec3 pc = mix(crev, c * mix(0.92, 1.1, shade), t.a);
	float patch = mix(0.3, 1.0, smoothstep(0.3, 0.7, pf_noise(d * 5.0 + 8.3))) * (1.0 - 0.5 * smoothstep(0.55, 0.9, hv));
	float s = (kind == 1 ? 1.0 : 0.45) * patch;
	k = s;
	return mix(c, pc, s);
}
