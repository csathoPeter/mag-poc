shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
#include "res://shaders/common.gdshaderinc"
#include "res://shaders/soft_light.gdshaderinc"
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
// Ritka módosítás (genes.gd rare_params): 1 tarka levél (krémfehér szegély), 2 ezüstlomb (ezüstös fény), 3 csillámlomb
// (apró, villanó fények a leveleken).
uniform int leaf_fx = 0;
varying vec3 crown_w;
varying float crown_k;
varying float tint_v;
varying float ao_v;
varying float u_v;
varying float up_v;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float g = smoothstep(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.x + 0.07, grow);
	// évszak: ősszel néhány, télen sok levél lehullott (példányonként rögzített sorrendben, puhán)
	float keep = fract(float(INSTANCE_ID) * 0.7548777 + 0.137);
	g *= smoothstep(0.0, 0.015, keep - season_thin());
	vec3 p = (VERTEX - o) * g;
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
// a fajta szerinti karéjokkal, fogakkal, levélkékkel.
float leaf_half(float t) {
	float w = pow(max(sin(PI * pow(t, leaf_pow)), 0.0), 0.8);
	if (leaf_kind == 9) {
		w *= 0.62 + 0.38 * pow(abs(sin(t * PI * 3.0)), 0.6);
	} else if (leaf_kind == 10) {
		// csipkés: apró, a csúcs felé dőlő fogak
		w *= 0.9 + 0.1 * fract(t * 15.0 + 0.3);
	} else if (leaf_kind == 11) {
		// tölgyes: kerek karéjok, mély öblökkel
		w *= 0.5 + 0.5 * pow(abs(sin(t * PI * 4.5 + 0.4)), 0.5);
	} else if (leaf_kind == 12) {
		// ujjas: mélyen tagolt, ujjszerű karéjok
		w *= 0.3 + 0.7 * pow(abs(sin(t * PI * 3.5 + 0.2)), 0.42);
	} else if (leaf_kind == 13) {
		// tollas: különálló levélkék a fő ér mentén
		w *= 0.12 + 0.88 * pow(abs(sin(t * PI * 7.0)), 0.32);
	} else if (leaf_kind == 6) {
		// csúcsos: hosszan kihúzott csúcs
		w *= 1.0 - 0.45 * smoothstep(0.62, 1.0, t);
	}
	return w;
}

void fragment() {
	float t = UV.x;
	float s = abs(UV.y);
	float w = leaf_half(t);
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
	vec3 a = mix(col_in(base), col_in(tip), t * t) * (0.8 + tint_v * 0.42);
	// erezet: fő ér, a csúcs felé dőlő oldalerek (a távolban, ahol vibrálna, elhalványul)
	float rib = 1.0 - smoothstep(0.022, 0.055, s);
	float ph = t * 8.0 - s * 2.6;
	float fw = max(fwidth(ph), 1e-4);
	float side = 1.0 - smoothstep(0.0, max(0.07, fw), abs(fract(ph + 0.5) - 0.5));
	side *= (1.0 - smoothstep(0.15, 0.45, fw)) * smoothstep(0.03, 0.08, s) * (1.0 - smoothstep(0.55, 0.95, s / max(w, 1e-3)));
	float vein = side * (1.0 - rib);
	// a szél finoman világosabb (a részletes szinten), így a körvonal közelről is tiszta
	float edge = leaf_cut * smoothstep(0.75, 1.0, s / max(w, 1e-3)) * (1.0 - smoothstep(0.2, 0.6, fwidth(s) * 40.0));
	vec3 alb = mix(a, a * 1.5 + 0.012, rib * 0.6 + vein * 0.22 + edge * 0.12);
	alb = season_leaf(alb, tint_v, s / max(w, 1e-3), up_v);
	if (leaf_fx == 1) {
		float rim_m = smoothstep(0.56, 0.7, s / max(w, 1e-3)) * (1.0 - rib);
		alb = mix(alb, vec3(0.74, 0.72, 0.46) * (0.9 + tint_v * 0.15), rim_m * 0.9);
	} else if (leaf_fx == 2) {
		alb = mix(alb, vec3(dot(alb, vec3(0.3, 0.5, 0.2))) * vec3(0.9, 0.98, 1.1), 0.5);
	}
	alb = thirsty_col(alb, thirst * 0.55);
	vec3 alb_l = ao_direct(alb, ao_v, 0.45);
	ALBEDO = col_out(alb_l);
	soft_fix = soft_fix_of(alb_l, ALBEDO);
	// a levél fénye a korona egészét követi (egy puha tömb), nem a saját állását
	NORMAL = normalize(mix(soft_face(NORMAL, VIEW), normalize((VIEW_MATRIX * vec4(crown_w, 0.0)).xyz), crown_k));
	ROUGHNESS = 0.55;
	AO = ao_v;
	AO_LIGHT_AFFECT = 0.45;
	// peremfény: a korona széle a légkör és a saját színe keverékével dereng (a körvonal helyett)
	EMISSION = col_out(col_in(glow_col) * (glow_amt * (part_on(1.0) * (rib * 2.2 + vein * 3.5 + 0.25) + 0.06) + touch_wave(u_v) * 0.9)
		+ soft_rim(NORMAL, VIEW, 0.3 * crown_on) * alb);
	if (leaf_fx == 2) {
		// ezüst: a levél lapja a fény felé fordulva csillan, a széle dereng
		ROUGHNESS = 0.3;
		float fr = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
		EMISSION += col_out(vec3(0.55, 0.6, 0.68) * (fr * 0.35 + 0.05 + 0.25 * pow(max(sin(TIME * 0.9 + tint_v * 40.0), 0.0), 12.0)));
	} else if (leaf_fx == 3) {
		// csillám: levelenként ritkán felvillanó fény a levél közepén (nappal és éjjel is)
		float tw = pow(max(sin(TIME * 1.6 + tint_v * 97.0 + ao_v * 13.0), 0.0), 36.0);
		float spot = 1.0 - smoothstep(0.0, 0.55, s / max(w, 1e-3));
		EMISSION += col_out(vec3(1.0, 0.9, 0.62) * (tw * 3.2 * spot + 0.05));
	}
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
