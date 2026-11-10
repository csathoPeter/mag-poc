uniform float grow = 1.0;
uniform float amp = 0.09;
uniform float plant_h = 5.0;
uniform float max_path = 1.0;
// A fa saját kerete (a bolygón a fák ferdén állnak, a szél a fa "felfelé" irányához igazodik).
uniform mat4 tree_xf = mat4(1.0);
uniform mat4 tree_inv = mat4(1.0);
uniform float tree_scale = 1.0;
// Éjszakai fény: szín, erősség (rejtett tulajdonság × éjszaka), melyik rész világít (0 virág, 1 levél, 2 kéreg).
uniform vec3 glow_col : source_color = vec3(0.5, 0.9, 1.0);
uniform float glow_amt = 0.0;
uniform float glow_part = 0.0;
// Gondozás: lekonyulás (0 = egyenes, 1 = lekonyult; öntözéskor rugalmasan, kicsit túllendülve tér vissza, ezért
// rövid ideig negatív is lehet) és a szomjúság fakósága (0–1). Csak a kirajzolást hajlítja, a váz nem változik.
uniform float droop = 0.0;
uniform float thirst = 0.0;
// Érintés óta eltelt idő másodpercben (-1: nincs), a tövétől a csúcsa felé futó fényhullámhoz.
uniform float wave = -1.0;

vec3 sway(vec3 wp, float t) {
	vec3 p = (tree_inv * vec4(wp, 1.0)).xyz * tree_scale;
	float h = max(p.y, 0.0) / plant_h;
	float a = h * h * amp * plant_h / 5.0;
	vec3 off = vec3(sin(t * 0.7 + p.y * 0.4 + p.z * 0.3) * a + sin(t * 1.7 + p.x * 1.3) * a * 0.22, 0.0, cos(t * 0.6 + p.x * 0.35) * a * 0.7);
	return mat3(tree_xf) * off / tree_scale;
}

float part_on(float k) {
	return 1.0 - step(0.5, abs(glow_part - k));
}

float touch_wave(float u) {
	if (wave < 0.0) {
		return 0.0;
	}
	float front = wave * 0.6 - 0.1;
	return exp(-pow((u - front) * 6.0, 2.0)) * (1.0 - smoothstep(1.8, 3.0, wave));
}

// A lekonyulás eltolása egy pontban (világ-koordinátában): a korona lehajlik, a csúcs kissé biccent, a szélső ágak
// jobban lógnak, mint a törzs közelében lévők. Folytonos mező, így az ágak, levelek és virágok együtt maradnak.
vec3 droop_off(vec3 wp) {
	if (droop == 0.0) {
		return vec3(0.0);
	}
	vec3 p = (tree_inv * vec4(wp, 1.0)).xyz * tree_scale;
	float h = max(p.y, 0.0) / plant_h;
	float rr = length(p.xz);
	vec3 off = vec3(p.x, 0.0, p.z) * (0.14 * h);
	off.y = -(0.8 * h * h * plant_h * 0.3 + 0.6 * rr * h);
	off.x += 0.7 * h * h * plant_h * 0.3;
	return mat3(tree_xf) * (off * droop) / tree_scale;
}

// A fa „felfelé” iránya világ-koordinátában (a levél és a virág lekonyulásához).
vec3 tree_up() {
	return normalize(mat3(tree_xf)[1]);
}

// Szomjas szín: fakóbb, kissé sárgás-olajos és sötétebb.
vec3 thirsty_col(vec3 c, float k) {
	float l = dot(c, vec3(0.3, 0.5, 0.2));
	return mix(c, vec3(l) * vec3(1.12, 1.02, 0.66) * 0.92, k);
}
