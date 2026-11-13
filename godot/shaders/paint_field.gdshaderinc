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
