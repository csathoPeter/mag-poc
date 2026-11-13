shader_type spatial;
// Szálankénti fű a bolygón. Az ötletek a 2Retr0/GodotGrass projektből (MIT) és a Ghost of Tsushima GDC-előadásból jönnek:
// magassággal arányos hajlás (íves szál), egységes szél, nézetből oldalra eső szálak kiszélesítése,
// lekerekített normál, tő felé sötétedő szín, puha szórt fény és hátulról átsütő fény.
// Egy példány egy csomó (több szál). A csomó helyét, irányát és méretét itt számoljuk a csempe és a példány sorszámából
// (hash), a magasságot a felszín rácsából: a fű a bolygóhoz rögzített, és sosem generálódik újra.
// Sűrűség: a csempén belül a sorban hátrébb lévő csomók csak sűrűbb fűnél látszanak (közel a kamerához és a nézett
// ponthoz); a határon puhán előnőnek, nem pattannak elő.
// Csak spatial shader + MultiMesh, így a webes (Compatibility) rendererrel is működik.
render_mode cull_disabled, shadows_disabled, skip_vertex_transform;
// Színtér (M11): a színeket a planet.gd eleve lineárisan adja (sima vec3, nem source_color – így képpontonként nincs
// col_in), a kimenetet col_out()-tal írjuk (weben így egyezik a két renderer).
// Puha stílus (soft_light.gdshaderinc): a mező szőnyegként árnyékolódik, világosabb tő, színes árnyék, évszakos szín.
#include "res://shaders/color_space.gdshaderinc"
#include "res://shaders/season.gdshaderinc"
#include "res://shaders/soft_light.gdshaderinc"
// Festett fű (2026. 11. 13.): a szál töve a festett talaj színe (ugyanaz a mező, paint_field.gdshaderinc), a csúcsa kicsit
// világosabb; a fény a talajéval azonos (a felszín normálja), így a mező egy festett felület, a szálak ecsetvonások.
#include "res://shaders/paint_field.gdshaderinc"

uniform vec3 base_lin = vec3(0.013, 0.04, 0.01);
uniform vec3 tip_lin = vec3(0.32, 0.52, 0.17);
uniform vec3 sss_lin = vec3(1.0, 0.71, 0.32);
uniform vec3 glow_lin = vec3(0.21, 1.0, 0.6);
// a fű alapszíne lineárisan (a talaj grass uniformja; a festett mező ebből számol)
uniform vec3 field_lin = vec3(0.2, 0.4, 0.15);
uniform float night = 0.0;
uniform float wind = 1.35;
// A szél a bolygó körül kering e tengely körül.
uniform vec3 wind_axis = vec3(0.3, 1.0, 0.2);

// elhelyezés: a csomópont egy csempecsoport közepén áll; a csoport group × group csempéjéből a planet.gd annyi szálat
// tesz a pufferbe, amennyi ott kell (csempénként a sor eleje).
// A részletes (hi_layer) csomópont a kamerához hi_dist-nél közelebbi csempék szálait rajzolja, a másik a többit.
uniform bool hi_layer = false;
uniform int tiles_n = 6;
uniform int group = 3;
uniform int res = 40;
uniform int seed = 0;
// a felszín magassága laponként (res+1)² rácsban, a lapok egymás alatt
uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform vec3 planet_pos = vec3(0.0);
uniform float planet_r = 6.0;
// a csempe közepétől a legtávolabbi sarkáig (egységgömbön)
uniform float tile_rad = 0.25;
uniform float blade_h = 0.4;
// sűrűség, csomó / egység²
uniform float near_w = 140.0;
uniform float base_w = 8.0;
uniform vec3 cam_pos = vec3(0.0);
uniform float cam_r = 3.0;
uniform float cam_far = 12.0;
uniform vec3 focus_pt = vec3(0.0);
uniform float focus_r = 4.5;
uniform float focus_k = 0.0;
uniform float focus_far = 9.9;
uniform float hi_dist = 6.5;
// festett fűnél a szálak a kamera magasságától függnek (a bolygó sugarában): alacsonyan (leszállva, légi nézet) mind
// látszik, paint_alt.x fölött halványulnak, paint_alt.y fölött (kívülről) egy sem
uniform vec2 paint_alt = vec2(1.1, 2.0);

varying float hf_v;
varying float rnd_v;
varying float clump_v;
varying float gust_v;
varying vec3 side_v;
varying vec3 up_v;
varying float band_v;

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

uint hash_u(uint x) {
	x ^= x >> 16u;
	x *= 2146121005u;
	x ^= x >> 15u;
	x *= 2221713035u;
	x ^= x >> 16u;
	return x;
}

float rnd(uint key, uint i) {
	return float(hash_u(key + i * 2654435761u) >> 8u) / 16777216.0;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// a kocka lapjai ugyanabban a sorrendben, mint a planet.gd FACES tömbje
vec3 face_n(int f) {
	if (f == 0) return vec3(0.0, 1.0, 0.0);
	if (f == 1) return vec3(0.0, -1.0, 0.0);
	if (f == 2) return vec3(-1.0, 0.0, 0.0);
	if (f == 3) return vec3(1.0, 0.0, 0.0);
	if (f == 4) return vec3(0.0, 0.0, -1.0);
	return vec3(0.0, 0.0, 1.0);
}

int face_of(vec3 c) {
	vec3 a = abs(c);
	if (a.y >= a.x && a.y >= a.z) return c.y > 0.0 ? 0 : 1;
	if (a.x >= a.z) return c.x < 0.0 ? 2 : 3;
	return c.z < 0.0 ? 4 : 5;
}

// magasság (x), a festett mező nyers sáv-értéke (y) és a fűtakaró (z: 0 a kőzeten) a lap (a, b) pontjában, a felszín
// háromszögein belül lineárisan (mint a háló: a talaj ugyanígy interpolálja a csúcspont-színét)
vec3 height_at(int f, float a, float b) {
	float gx = (a * 0.5 + 0.5) * float(res);
	float gy = (b * 0.5 + 0.5) * float(res);
	int i0 = clamp(int(floor(gx)), 0, res - 1);
	int j0 = clamp(int(floor(gy)), 0, res - 1);
	float fx = clamp(gx - float(i0), 0.0, 1.0);
	float fy = clamp(gy - float(j0), 0.0, 1.0);
	int row = f * (res + 1) + j0;
	vec3 h00 = texelFetch(height_tex, ivec2(i0, row), 0).rgb;
	vec3 h10 = texelFetch(height_tex, ivec2(i0 + 1, row), 0).rgb;
	vec3 h01 = texelFetch(height_tex, ivec2(i0, row + 1), 0).rgb;
	vec3 h11 = texelFetch(height_tex, ivec2(i0 + 1, row + 1), 0).rgb;
	if (fx + fy < 1.0) {
		return h00 + fx * (h10 - h00) + fy * (h01 - h00);
	}
	return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fy) * (h10 - h11);
}

// sűrűség-tényező egy pont körül: r0-on belül 1, kifelé a távolság négyzetével ritkul (a képen így egyenletes), r1-nél 0
float fall(float d, float r0, float r1) {
	float f = d < r0 ? 1.0 : r0 * r0 / (d * d);
	return f * (1.0 - smoothstep(r1 * 0.55, r1, d));
}

void vertex() {
	int gn = tiles_n / group;
	vec3 c = normalize(MODEL_MATRIX[3].xyz - planet_pos);
	int f = face_of(c);
	vec3 n = face_n(f);
	vec3 u = n.yzx;
	vec3 v = cross(n, u);
	float ac = atan(dot(c, u) / dot(c, n)) * 4.0 / PI;
	float bc = atan(dot(c, v) / dot(c, n)) * 4.0 / PI;
	int gi = clamp(int(floor((ac * 0.5 + 0.5) * float(gn))), 0, gn - 1);
	int gj = clamp(int(floor((bc * 0.5 + 0.5) * float(gn))), 0, gn - 1);
	// a példány mátrixa csak két számot hordoz: 1. oszlop hossza = helyi csempe-index, 2. oszlopé = a szál sorszáma
	float sc = length(MODEL_MATRIX[2].xyz);
	int lt = int(round(length(MODEL_MATRIX[0].xyz) / sc));
	int k = int(round(length(MODEL_MATRIX[1].xyz) / sc));
	int ti = gi * group + lt / group;
	int tj = gj * group + lt % group;
	int tile = (f * tiles_n + ti) * tiles_n + tj;
	float stp = 2.0 / float(tiles_n);

	// a csempe legnagyobb sűrűsége (a kamerához és a nézett ponthoz legközelebbi pontján); a planet.gd ugyanígy számol
	vec3 tc = planet_pos + normalize(n + u * tan((-1.0 + (float(ti) + 0.5) * stp) * PI * 0.25) + v * tan((-1.0 + (float(tj) + 0.5) * stp) * PI * 0.25)) * planet_r;
	float tr = tile_rad * planet_r;
	float dct = distance(tc, cam_pos) - tr;
	float wb = mix(base_w, near_w, max(fall(max(dct, 0.0), cam_r, cam_far), focus_k * fall(max(distance(tc, focus_pt) - tr, 0.0), focus_r, focus_far)));

	uint key = hash_u(hash_u(uint(tile) + uint(seed) * 977u) + uint(k));
	// a csomó helye a csempén belül (a lap paraméterterében egyenletesen)
	// egyenletes szórás (kopasz foltok ellen): a csempén belül a k-adik csomó helye az R2 kis eltérésű sorozatból, enyhe rázással
	// és csempénkénti eltolással. A sor bármely eleje egyenletesen fed, így ritka és sűrű fűnél sincs csomósodás, lyuk.
	float tile_r = rnd(hash_u(uint(tile) + uint(seed) * 977u), 9u);
	float a = -1.0 + (float(ti) + fract(tile_r + float(k) * 0.7548776662 + (rnd(key, 1u) - 0.5) * 0.18)) * stp;
	float b = -1.0 + (float(tj) + fract(tile_r * 1.7 + float(k) * 0.5698402910 + (rnd(key, 2u) - 0.5) * 0.18)) * stp;
	float ta = tan(a * PI * 0.25);
	float tb = tan(b * PI * 0.25);
	// sorrend szerinti sűrűség: ez a csomó ennél a sűrűségnél (csomó / egység²) jelenik meg
	float jac = PI * PI / 16.0 * (1.0 + ta * ta) * (1.0 + tb * tb) / pow(1.0 + ta * ta + tb * tb, 1.5);
	float rank = (float(k) + 0.5) / (stp * stp * jac * planet_r * planet_r);

	hf_v = UV.y;
	rnd_v = 0.0;
	clump_v = 0.0;
	gust_v = 0.0;
	side_v = vec3(0.0, 1.0, 0.0);
	vec3 dir = normalize(n + u * ta + v * tb);
	up_v = normalize(mat3(VIEW_MATRIX) * dir);
	band_v = 0.5;
	vec3 root = vec3(0.0);
	float dcam = 0.0;
	float cover = 1.0;
	float paint_vis = 1.0 - smoothstep(paint_alt.x, paint_alt.y, (distance(cam_pos, planet_pos) - planet_r) / planet_r);
	bool mine = false;
	if (rank < wb) {
		vec3 hb = height_at(f, a, b);
		root = planet_pos + dir * planet_r * (1.0 + hb.x - 0.003);
		band_v = hb.y;
		cover = hb.z;
		dcam = distance(root, cam_pos);
		// a kamerához közeli szálakat a részletes csomópont rajzolja, a többit az egyszerű (szálanként, pontos határral)
		mine = hi_layer == (dcam < hi_dist);
		// festett fűnél kívülről nincs szál: a bolygó sima, festett gömb, és a háromszögek kiesnek
		mine = mine && (paint_k * soft_k < 0.5 || paint_vis > 0.0);
	}
	if (!mine) {
		// ez a csomó itt nem látszik: a képen kívülre tesszük, a háromszögei kiesnek
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	} else {
		float fk = max(fall(dcam, cam_r, cam_far), focus_k * fall(distance(root, focus_pt), focus_r, focus_far));
		float grow = smoothstep(rank, rank * 1.35, mix(base_w, near_w, fk));

		float rnd1 = rnd(key, 5u);
		float rnd2 = rnd(key, 6u);
		float clump = smoothstep(0.2, 0.8, vnoise(dir * 9.0 + vec3(float(seed % 97))));
		float hgt = blade_h * mix(0.85, 1.2, clump) * mix(0.75, 1.2, rnd(key, 4u)) * grow;
		// festett fűnél rövidebb szálak: szőnyeg, nem bunda; a kőzeten nincs szál, és távolabb puhán eltűnnek
		float pkv = paint_k * soft_k;
		hgt *= mix(1.0, 0.62 * smoothstep(0.25, 0.75, cover) * paint_vis, pkv);
		vec3 ref = abs(dir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
		vec3 e1 = normalize(cross(ref, dir));
		vec3 e2 = cross(dir, e1);
		float ang = rnd(key, 3u) * 6.2831;
		vec3 bx = e1 * cos(ang) + e2 * sin(ang);
		mat3 rb = mat3(bx, dir, cross(bx, dir));

		// CUSTOM0 (csúcspontonként): xy = a szál töve a csomóban, z = félszélesség, w = oldal (-1, 0, 1)
		// UV.y = magasság a szálon belül (0 tő, 1 csúcs)
		float hf = UV.y;

		// szél: a tengely körül keringő irány; a széllökések hullámként futnak körbe a bolygón (varrat nélkül)
		vec3 rp = root - planet_pos;
		vec3 ax = normalize(wind_axis);
		vec3 bx2 = normalize(cross(ax, vec3(1.0, 0.0, 0.0)));
		vec3 cx = cross(ax, bx2);
		float phi = atan(dot(rp, cx), dot(rp, bx2));
		float along = dot(rp, ax);
		// erősebb szél (2026. 11. 11.): nagyobb, lassabban gördülő lökések, köztük is marad egy kis lengés
		float gust = 0.5 + 0.5 * sin(phi * 7.0 + along * 0.8 - TIME * 1.3);
		gust *= 0.45 + 0.55 * (0.5 + 0.5 * sin(phi * 3.0 + along * 1.7 - TIME * 0.7));
		gust = 0.15 + 0.85 * gust;
		vec3 wdir = cross(ax, dir);
		wdir = length(wdir) > 0.001 ? normalize(wdir) : vec3(1.0, 0.0, 0.0);
		float strength = wind * gust;

		// a csomó a véletlen irány és a szél iránya között áll
		vec3 wl = transpose(rb) * wdir;
		vec2 rd = vec2(sin(rnd1 * 6.2831), cos(rnd1 * 6.2831));
		vec2 wd = normalize(wl.xz + vec2(1e-5));
		vec2 d = normalize(mix(rd, wd, clamp(0.4 + strength * 0.5, 0.0, 0.95)));
		mat3 ry = rot_y(atan(d.x, d.y));
		// hajlás: minél magasabban van a pont, annál jobban (íves szál); minden szál a saját töve körül hajlik.
		// A részletes szál a váltási távolság felé kiegyenesedik, így ott pont olyan, mint az egyszerű (nincs pattanás).
		float straight = smoothstep(hi_dist - 2.5, hi_dist, dcam);
		// hajlás: alap dőlés + a lökés + szálanként saját lengés (a lökésben erősebb); legfeljebb ~65°, hogy ne feküdjön le
		float flutter = sin(TIME * 2.4 + rnd1 * 20.0) * 0.6 + sin(TIME * 4.1 + rnd2 * 13.0) * 0.4;
		float bend = min(mix(0.12, 0.38, rnd2) + strength * 0.62 + flutter * (0.05 + 0.12 * strength), 1.15) * mix(hf, 1.0, straight);
		mat3 r = ry * rot_x(bend);
		vec3 base = vec3(CUSTOM0.x, 0.0, CUSTOM0.y);
		vec3 side_l = normalize(cross(vec3(0.0, 1.0, 0.0), NORMAL));
		vec3 lp = ry * base + r * (VERTEX - base);
		vec3 ln = r * NORMAL;

		// nézetből oldalra eső szálak kiszélesítése, a távoliak eleve szélesebbek (így ritkább fű is dúsnak hat)
		mat3 vr = mat3(VIEW_MATRIX) * rb;
		vec3 vv = (VIEW_MATRIX * vec4(root, 1.0)).xyz + vr * lp * hgt;
		vec3 nv = normalize(vr * ln);
		float edge = 1.0 - abs(dot(nv, normalize(-vv)));
		float far = clamp(length(vv) * 0.05 - 0.5, 0.0, 1.2);
		vv.x += (edge * edge * edge * edge * 1.5 + far) * CUSTOM0.z * hgt * CUSTOM0.w;
		VERTEX = vv;
		NORMAL = nv;
		POSITION = PROJECTION_MATRIX * vec4(vv, 1.0);

		side_v = normalize(vr * (r * side_l));
		hf_v = hf;
		rnd_v = rnd1;
		clump_v = clump;
		gust_v = gust;
	}
}

void fragment() {
#ifdef FROND
	// páfrány (puha stílus, a planet.gd a #define FROND változatot adja): a szál széle levélkékre tagolt, nem egy széles
	// fűrészfog. Külön változat, mert a discard a sima fűnél is lassítaná a rajzolást (telefonon a korai mélységteszt kiesik).
	float lobe = 0.12 + 0.88 * pow(abs(sin(hf_v * PI * 4.5 + 0.35 + hf_v * hf_v * 3.0)), 0.35);
	if (abs(UV.x * 2.0 - 1.0) > lobe) {
		discard;
	}
#endif
	// lekerekített normál: a szál két széle kicsit kifelé néz
	NORMAL = normalize(NORMAL + side_v * (UV.x * 2.0 - 1.0) * 0.45);
	NORMAL = mix(NORMAL, soft_face(NORMAL, VIEW), soft_k);
	// puha stílus: a mező egy szőnyegként kap fényt (a felszín normálja felé), nem szálanként; ettől nem szőrös, zajos
	float pk = paint_k * soft_k;
	NORMAL = normalize(mix(NORMAL, up_v, mix(0.6, 1.0, paint_k) * soft_k));
	float h = hf_v;
	// a tő sötétebb a csúcsnál, de puha stílusban nem fekete
	vec3 base_l = base_lin * mix(1.0, 1.15, soft_k);
	vec3 tip_l = tip_lin;
	vec3 tip = tip_l * (0.85 + 0.3 * clump_v);
	vec3 c = mix(base_l, tip, h * h);
	// a tő felé sötétedik; puha stílusban jóval kevésbé (a sötét tövek adták a szálas, pixeles hatást)
	c *= mix(mix(0.45, 0.66, soft_k), 1.0, h);
	c *= 0.9 + 0.2 * rnd_v;
	// széllökés: a meghajló szálak csúcsa világosabb, így a hullámok végigfutnak a mezőn
	c *= 1.0 + 0.4 * gust_v * h;
	// távolban egyszínűbb, hogy ne vibráljon
	float far = exp(-length(VERTEX) * 0.035);
	c = mix(mix(base_l, tip_l, 0.55) * 0.75, c, far);
	// festett fű: a tő a talaj színe, a csúcs felé világosodik (ecsetvonás), a széllökés halkan világosít
	vec3 root_c = paint_tone(field_lin, paint_band(band_v));
	vec3 pc = root_c * mix(1.0, 1.22, h * h) * (0.96 + 0.08 * rnd_v) * (1.0 + 0.25 * gust_v * h * h);
	c = mix(c, pc, pk);
	// évszak (mint a talajnál, planet.gdshader): tavasszal üdébb, ősszel okkeres, télen a csúcsa deres
	float ml = season_luma(c);
	c = mix(c, c * vec3(1.02, 1.18, 0.92), season.x * 0.6);
	c = mix(c, vec3(ml) * vec3(1.45, 1.0, 0.42), season.z * 0.42);
	c = mix(c, vec3(0.74, 0.8, 0.88) * max(ml * 2.0, 0.3), season.w * (0.25 + 0.45 * h * h));
	ALBEDO = col_out(c);
	soft_fix = soft_fix_of(c, ALBEDO);
	ROUGHNESS = mix(1.0, 0.45, h);
	SPECULAR = 0.25;
	EMISSION = col_out(glow_lin * night * step(0.93, rnd_v) * h * h * 1.2);
}

void light() {
	// puha szórt fény (sosem teljesen sötét) + hátulról átsütő fény
	float diff = mix(pow(4.0, dot(NORMAL, LIGHT)) / 4.0, soft_diffuse(dot(NORMAL, LIGHT)), soft_k);
	float sss = max(-dot(VIEW, LIGHT), 0.0) * 0.55 * hf_v * (1.0 - 0.6 * paint_k * soft_k);
	DIFFUSE_LIGHT += ((diff + sss * sss_lin) * ATTENUATION * LIGHT_COLOR / PI + shade_tint * ((1.0 - diff * ATTENUATION) * soft_k))
		* soft_fix;
	vec3 hv = normalize(LIGHT + VIEW);
	// a fényfolt puha stílusban nincs: a szőnyeg-normálon az egész mező csillogna (weben ráadásul erősebb)
	SPECULAR_LIGHT += pow(max(dot(NORMAL, hv), 0.0), 24.0) * diff * hf_v * 0.35 * (1.0 - soft_k) * ATTENUATION * LIGHT_COLOR / PI;
}
