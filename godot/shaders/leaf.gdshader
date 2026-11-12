shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
#include "res://shaders/common.gdshaderinc"
#include "res://shaders/soft_light.gdshaderinc"
#include "res://shaders/craft.gdshaderinc"
uniform vec3 base : source_color = vec3(0.2, 0.5, 0.2);
uniform vec3 tip : source_color = vec3(0.4, 0.7, 0.3);
// Levélforma (M11): a részletes szinten (leaf_cut = 1) a körvonalat a shader rajzolja a levélforma-génből (SDF), a mesh
// csak egy befoglaló burok (plant_gen.leaf_mesh). UV.x: a levél hossza mentén (0 tő, 1 csúcs), UV.y: előjeles
// oldaltávolság a főértől a levél legnagyobb félszélességéhez mérve. A távolabbi szinteken a mesh sokszöge a forma.
uniform float leaf_cut = 0.0;
uniform float leaf_pow = 1.0;
// a levélforma-gén (genes.gd LEAF) sorszáma: 5 szív, 6 csúcsos, 9 karéjos, 10 csipkés, 11 tölgyes, 12 ujjas, 13 tollas
uniform int leaf_kind = 3;
// A lombkorona ellipszoidja a fa saját keretében (plant_gen.crown()); crown_on = 0: a levél egyedül (levéltábla).
uniform vec3 crown_c = vec3(0.0, 3.0, 0.0);
uniform vec3 crown_e = vec3(2.0);
uniform float crown_on = 0.0;
varying vec3 crown_w;
varying float crown_k;
varying float tint_v;
varying float ao_v;
varying float u_v;
varying float up_v;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float g = smoothstep(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.x + 0.07, grow);
	// fejlődés: a levél akkor bújik ki, amikor az ága odaér, és még pár napig nő
	float bd = INSTANCE_CUSTOM.w;
	g *= smoothstep(bd, bd + 0.04, age) * mix(0.55, 1.0, smoothstep(bd, bd + 0.12, age));
	// évszak: ősszel néhány, télen sok levél lehullott (példányonként rögzített sorrendben, puhán)
	float keep = fract(float(INSTANCE_ID) * 0.7548777 + 0.137);
	g *= smoothstep(0.0, 0.015, keep - season_thin());
	vec3 p = (VERTEX - o) * g;
	// kézműves (craft.gdshaderinc): a levél két fele nem egyforma széles, a csúcsa oldalra hajlik, a lemeze kicsit
	// jobban vagy kevésbé hajlik fel – levelenként más, mindhárom részletességi szinten ugyanúgy
	if (craft > 0.5) {
		vec3 h = craft_rand3(INSTANCE_CUSTOM.y);
		vec3 ax = MODEL_MATRIX[0].xyz;
		vec3 axn = normalize(ax);
		float tt = UV.x * UV.x;
		p += axn * abs(dot(p, axn)) * h.x * 0.5;
		p += (ax * h.y * 0.38 + MODEL_MATRIX[2].xyz * h.z * 0.32) * tt * g;
	}
	p.z += sin(TIME * 2.3 + o.x * 6.0 + o.z * 4.0) * 0.012 * UV.x * step(0.001, amp);
	// szomjasan a levél lehajlik (a hossza marad)
	float pl = length(p);
	if (droop > 0.0 && pl > 0.0) {
		p = normalize(p - tree_up() * pl * droop * 0.9) * pl;
	}
#ifdef FALL
	// a lehulló ág levelei szétszóródnak, és pörögve, imbolyogva lassabban hullanak
	vec3 rnd = fract(sin(vec3(INSTANCE_CUSTOM.y * 91.7, INSTANCE_CUSTOM.z * 47.3, INSTANCE_CUSTOM.x * 13.1) + o * 3.7) * 4375.5) - 0.5;
	vec3 up = tree_up();
	vec3 sx = normalize(cross(up, vec3(0.37, 0.53, 0.76)));
	vec3 sz = cross(up, sx);
	float ft = fall_t * fall_t;
	o += (sx * rnd.x * 1.4 + sz * rnd.z * 1.4 + up * (0.35 + rnd.y * 0.4)) * ft
		+ (sx * sin(TIME * 3.1 + rnd.x * 9.0) + sz * cos(TIME * 2.7 + rnd.z * 9.0)) * 0.1 * fall_t;
	float ang = fall_t * (rnd.y * 9.0 + 3.0);
	vec3 ax = normalize(sx * rnd.z + sz * rnd.x + up * 0.3);
	p = p * cos(ang) + cross(ax, p) * sin(ang) + ax * dot(ax, p) * (1.0 - cos(ang));
	VERTEX = o + p;
#else
	VERTEX = o + p + sway(o, TIME) + droop_off(o);
#endif
	tint_v = INSTANCE_CUSTOM.y;
	ao_v = INSTANCE_CUSTOM.z;
	u_v = (INSTANCE_CUSTOM.x - 0.05) / 0.64;
	// a levéllemez mennyire néz felfelé (a dérhez), kétoldalú levélnél mindegy, melyik oldala
	up_v = abs(dot(normalize(NORMAL), tree_up()));
	// puha lomb: a korona felszínének normálja a levél helyén (az ellipszoid gradiense); a belső levelek kevésbé követik
	vec3 q = ((tree_inv * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz - crown_c) / crown_e;
	crown_w = mat3(tree_xf) * (q / crown_e);
	crown_k = crown_on * soft_k * 0.78 * smoothstep(0.12, 0.65, length(q));
#ifdef FALL
	crown_k = 0.0;
#endif
}

// A levél félszélessége a hossz mentén (0–1, a legszélesebb ponthoz mérve): ugyanaz az alapforma, mint a mesh-é,
// a fajta szerinti karéjokkal, fogakkal, levélkékkel. hk > 0 (kézműves): a karéjok, fogak nem egyforma közönként és
// méretben jönnek, a körvonal kicsit hullámzik, mintha ollóval vágták volna – a két oldalon (side) és levelenként (k) másképp.
// A kézműves eltérés csak keskenyít, így a forma a mesh befoglaló burkán belül marad.
float leaf_half(float t, float side, float k, float hk) {
	float w = pow(max(sin(PI * pow(t, leaf_pow)), 0.0), 0.8);
	float tw = t + hk * (0.03 * sin(t * 7.0 + k * 31.0 + side * 2.0) + 0.015 * sin(t * 17.0 + k * 53.0));
	if (leaf_kind == 9) {
		w *= 0.62 + 0.38 * pow(abs(sin(tw * PI * 3.0)), 0.6);
	} else if (leaf_kind == 10) {
		// csipkés: apró, a csúcs felé dőlő fogak (kézzel: fogankét más mélységgel)
		float ph = tw * 15.0 + 0.3;
		float dep = mix(0.1, 0.05 + 0.1 * craft_hash(vec2(floor(ph), k * 71.0 + side)), hk);
		w *= 1.0 - dep + dep * fract(ph);
	} else if (leaf_kind == 11) {
		// tölgyes: kerek karéjok, mély öblökkel
		w *= 0.5 + 0.5 * pow(abs(sin(tw * PI * 4.5 + 0.4)), 0.5);
	} else if (leaf_kind == 12) {
		// ujjas: mélyen tagolt, ujjszerű karéjok
		w *= 0.3 + 0.7 * pow(abs(sin(tw * PI * 3.5 + 0.2)), 0.42);
	} else if (leaf_kind == 13) {
		// tollas: különálló levélkék a fő ér mentén
		w *= 0.12 + 0.88 * pow(abs(sin(tw * PI * 7.0)), 0.32);
	} else if (leaf_kind == 6) {
		// csúcsos: hosszan kihúzott csúcs
		w *= 1.0 - 0.45 * smoothstep(0.62, 1.0, t);
	}
	// ollóval vágott szél: lassú hullámzás, a vízfestéknél kicsit erősebb (a festék széle szabálytalanabb)
	w *= 1.0 - hk * (0.05 + 0.035 * craft_water()) * craft_noise(vec2(t * 9.0 + k * 40.0, side * 5.0 + k * 13.0));
	return w;
}

void fragment() {
	float t = UV.x;
	float s = abs(UV.y);
	float side = UV.y < 0.0 ? -1.0 : 1.0;
	float hk = craft_on();
	float paper = craft_paper();
	float water = craft_water();
	float k = tint_v;
	float w = leaf_half(t, side, k, hk);
	if (leaf_cut > 0.5) {
		float out_k = s - w;
		// szív alakú: bemetszés a levélnyélnél
		if (leaf_kind == 5) {
			out_k = max(out_k, 0.1 * (1.0 - smoothstep(0.0, 0.32, s)) - t);
		}
		if (out_k > 0.0) {
			discard;
		}
	}
	float dw = s / max(w, 1e-3);
	// a körvonaltól mért távolság képpontban (a részletes szinten): a papír vágott széle, a festék száradási vonala
	float fs = max(fwidth(s), 1e-4);
	float edge_px = (w - s) / fs;
	// a finom minták (szál, szemcse) ott halványulnak el, ahol a képen már vibrálnának; a körvonal-vonal pedig ott,
	// ahol a levél már csak pár képpont széles
	float fine = 1.0 - smoothstep(0.08, 0.3, fwidth(t) * 12.0);
	float line_ok = leaf_cut * (1.0 - smoothstep(0.12, 0.35, fs));
	// foltos szín: a levélen belül lassan változó árnyalat (a festék / a papír nem egyenletes)
	float mott = craft_noise(vec2(t * 2.6, UV.y * 2.2) + k * 23.0);
	float grad = t * t;
	if (paper > 0.5) {
		// papír: két-három egyszínű, kézzel vágott sáv a tőtől a csúcsig (mintha rétegesen ragasztották volna)
		float gb = t * 2.2 + (craft_noise(vec2(UV.y * 2.5, t * 3.0) + k * 9.0) - 0.5) * 0.7;
		grad = clamp(floor(gb + 0.5) / 2.2, 0.0, 1.0) * 0.85;
	} else if (water > 0.5) {
		// akvarell: a tő és a csúcs színe nem egyenes átmenetben, hanem foltosan folyik egymásba
		grad = clamp(t * t + (mott - 0.5) * 0.8, 0.0, 1.0);
	}
	vec3 a = mix(col_in(base), col_in(tip), grad) * (0.8 + tint_v * 0.42);
	a *= 1.0 + hk * (mott - 0.5) * mix(0.1, 0.3, water);
	// akvarell: minden levelet külön festettek, kicsit más tónussal és melegséggel
	vec3 hr = craft_rand3(k + 0.37);
	a *= 1.0 + water * vec3(hr.x * 0.22 + hr.y * 0.08, hr.x * 0.22, hr.x * 0.22 - hr.y * 0.08);
	// erezet: fő ér, a csúcs felé dőlő oldalerek (a távolban, ahol vibrálna, elhalványul); kézzel: a fő ér kicsit
	// kanyarog, az oldalerek nem egyforma közönként és szögben ágaznak el
	float yc = hk * 0.06 * sin(t * 4.0 + k * 19.0) * t;
	float sr = abs(UV.y - yc);
	float rib = 1.0 - smoothstep(0.022 - 0.008 * hk, 0.055 - 0.025 * hk, sr);
	float ph = t * 8.0 - sr * (2.6 + hk * 0.8 * sin(k * 29.0 + side)) + hk * 0.3 * sin(t * 11.0 + side * 5.0 + k * 41.0);
	float fw = max(fwidth(ph), 1e-4);
	float side_v = 1.0 - smoothstep(0.0, max(0.07 - 0.03 * hk, fw), abs(fract(ph + 0.5) - 0.5));
	side_v *= (1.0 - smoothstep(0.15, 0.45, fw)) * smoothstep(0.03, 0.08, sr) * (1.0 - smoothstep(0.55, 0.95, dw));
	float vein = side_v * (1.0 - rib);
	// a szél finoman világosabb (a részletes szinten), így a körvonal közelről is tiszta
	float edge = leaf_cut * smoothstep(0.75, 1.0, dw) * (1.0 - smoothstep(0.2, 0.6, fwidth(s) * 40.0));
	vec3 alb = mix(a, a * 1.5 + 0.012, (rib * 0.6 + vein * 0.22 + edge * 0.12) * (1.0 - hk));
	// papírszál: hosszanti, kicsit ferde rostok (nappal a felületen, éjjel átsütve)
	float fib = paper > 0.5 ? craft_noise(vec2(t * 30.0 + UV.y * 6.0, UV.y * 5.0) + k * 37.0) : 0.5;
	if (paper > 0.5) {
		// az erek a papírba nyomott vonalak (kicsit sötétebbek), a lap a fő ér mentén meg van hajtva
		alb *= 1.0 - rib * 0.22 - vein * 0.12;
		alb *= mix(1.0, 0.8, step(yc, UV.y));
		alb *= 1.0 + (fib - 0.5) * 0.2 * fine;
		// a vágott szél fehéres magja (a papír belseje): kb. másfél képpontos világos perem a körvonal mentén
		float cut = line_ok * (1.0 - smoothstep(0.6, 1.8, edge_px));
		alb = mix(alb, vec3(0.86, 0.88, 0.8) * (0.55 + 0.45 * dot(alb, vec3(1.2))), cut * 0.55);
	}
	if (water > 0.5) {
		// a festés: az erek a kihagyott, világosabb papír (vékonyan), a festék foltokban szárad (sötétebb peremű
		// „virágok”), a papír mélyedéseiben szemcsésen összegyűlik
		alb = mix(alb, alb * 1.3 + 0.01, rib * 0.45 + vein * 0.15);
		float bl = craft_noise(vec2(t * 2.4, UV.y * 1.7) + k * 17.0);
		float bloom = smoothstep(0.5, 0.54, bl) - smoothstep(0.54, 0.62, bl);
		float gran = craft_noise(vec2(t * 13.0, UV.y * 11.0) + k * 11.0);
		float grain = craft_noise(vec2(t * 41.0, UV.y * 37.0) - k * 7.0);
		alb *= (1.0 - bloom * 0.16) * (1.0 + (gran - 0.5) * 0.24 + (grain - 0.5) * 0.14 * fine);
		// ahol a víz széthúzta, halványabb, a papír átlátszik rajta
		alb = mix(alb, alb * 1.15 + 0.015, (1.0 - smoothstep(0.3, 0.52, bl)) * 0.7);
		// a festék a szélén megszárad és sötétebb, telítettebb csíkot hagy, a legszélén vékony száradási vonallal
		float pool = smoothstep(0.62, 0.97, dw) * (0.6 + 0.6 * mott) * mix(0.5, 1.0, leaf_cut);
		pool = max(pool, line_ok * (1.0 - smoothstep(0.8, 2.2, edge_px)) * 0.9);
		alb = mix(alb, alb * alb * 1.1 + alb * 0.4, clamp(pool, 0.0, 1.0) * 0.7);
	}
	alb = season_leaf(alb, tint_v, dw, up_v);
	alb = thirsty_col(alb, thirst * 0.55);
	vec3 alb_l = ao_direct(alb, ao_v, 0.45);
	ALBEDO = col_out(alb_l);
	soft_fix = soft_fix_of(alb_l, ALBEDO);
	// a levél fénye a korona egészét követi (egy puha tömb), nem a saját állását
	NORMAL = normalize(mix(soft_face(NORMAL, VIEW), normalize((VIEW_MATRIX * vec4(crown_w, 0.0)).xyz), crown_k));
	ROUGHNESS = 0.55 + 0.3 * hk;
	AO = ao_v;
	AO_LIGHT_AFFECT = 0.45;
	// éjszakai fény: az erekben dereng; papírnál a lap egésze, mint egy lampion (a rostok és a hajtás látszanak,
	// a széle sűrűbb, ott halványabb)
	float glow_pat = rib * 2.2 + vein * 3.5 + 0.25;
	if (paper > 0.5) {
		glow_pat = (0.9 + 0.7 * fib * fine + rib * 0.8) * (1.0 - 0.55 * dw * dw) * mix(1.0, 0.8, step(yc, UV.y));
	}
	// peremfény: a korona széle a légkör és a saját színe keverékével dereng (a körvonal helyett)
	EMISSION = col_out(col_in(glow_col) * (glow_amt * (part_on(1.0) * glow_pat + 0.06) + touch_wave(u_v) * 0.9)
		+ soft_rim(NORMAL, VIEW, 0.3 * crown_on) * alb);
#ifdef FALL
	if (fall_gone(FRAGCOORD.xy)) {
		discard;
	}
#endif
}

void light() {
	vec3 sp;
	DIFFUSE_LIGHT += soft_light(NORMAL, LIGHT, VIEW, ATTENUATION, LIGHT_COLOR, 0.75, 0.25, sp) * soft_fix;
	SPECULAR_LIGHT += sp;
}
