shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
#include "res://shaders/common.gdshaderinc"
#include "res://shaders/soft_light.gdshaderinc"
uniform vec3 petal : source_color = vec3(0.9, 0.5, 0.6);
uniform vec3 petal_tip : source_color = vec3(0.95, 0.7, 0.8);
uniform vec3 throat : source_color = vec3(0.9, 0.7, 0.3);
uniform vec3 stamen : source_color = vec3(0.9, 0.65, 0.2);
// Virágzási ciklus (care.gd): méret (0 = nincs virág), nyílás (0 = zárt bimbó, 1 = nyílt, >1 szétterül),
// hervadás (fakó, barnás), lehullott hányad. pick: a ma leszedett virág helye a növény saját koordinátáiban (xyz)
// és az elhalványulás mértéke (w): az a virág összecsukódik és elsápad.
uniform float bloom_size = 1.0;
uniform float bloom_open = 1.0;
uniform float bloom_fade = 0.0;
uniform float bloom_drop = 0.0;
uniform vec4 pick = vec4(0.0);
// Kerek szirom (puha stílus): a részletes szinten (petal_cut = 1) a körvonalat a shader rajzolja (plant_gen.petal_half),
// a mesh csak befoglaló burok; UV.y a legnagyobb félszélességhez mért oldaltávolság.
uniform float petal_cut = 0.0;
varying float kind_v;
varying float fade_v;
varying float bud_v;
varying float tint_v;
varying float u_v;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 axis = normalize(MODEL_MATRIX[1].xyz);
	float g = smoothstep(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.x + 0.07, grow);
	float open = smoothstep(INSTANCE_CUSTOM.x + 0.03, INSTANCE_CUSTOM.x + 0.15, grow) * bloom_open;
	// a leszedett virág: a helye a növény saját koordinátáiban
	vec3 lp = (tree_inv * vec4(o, 1.0)).xyz;
	float pk = pick.w * (1.0 - smoothstep(0.03, 0.12, distance(lp, pick.xyz)));
	open *= 1.0 - 0.75 * pk;
	// elnyíláskor a virágok egy része már lehullott (példányonként rögzített sorrendben)
	float keep = step(bloom_drop, fract(float(INSTANCE_ID) * 0.6180339 + 0.21));
	g *= bloom_size * keep * (1.0 - 0.3 * pk);
	// évszak (M11): tavasszal teltebb, nagyobb virágok; ősszel kevesebb, télen még kevesebb és kisebb
	float s_keep = step(season.z * 0.18 + season.w * 0.5, fract(float(INSTANCE_ID) * 0.7548777 + 0.37));
	g *= s_keep * (1.0 + 0.16 * season.x - 0.18 * season.w);
	vec3 p = VERTEX - o;
	float along = dot(p, axis);
	p = axis * along + (p - axis * along) * mix(0.32, 1.0, open);
	// szomjasan a virág lekonyul
	float pl = length(p);
	if (droop > 0.0 && pl > 0.0) {
		p = normalize(p - tree_up() * pl * droop * 0.8) * pl;
	}
	VERTEX = o + p * g + sway(o, TIME) + droop_off(o);
	fade_v = max(bloom_fade, pk * 0.85);
	bud_v = 1.0 - clamp(bloom_open, 0.0, 1.0);
	kind_v = COLOR.r;
	tint_v = INSTANCE_CUSTOM.y;
	u_v = (INSTANCE_CUSTOM.x - 0.74) / 0.14;
}

void fragment() {
	if (kind_v < 0.5 && petal_cut > 0.5 && UV.y > sqrt(max(sin(PI * pow(clamp(UV.x, 0.0, 1.0), 0.75)), 0.0))) {
		discard;
	}
	if (kind_v > 0.5) {
		vec3 st_l = col_in(stamen);
		ALBEDO = col_out(st_l);
		soft_fix = soft_fix_of(st_l, ALBEDO);
		ROUGHNESS = 0.8;
	} else {
		vec3 c = mix(col_in(throat), mix(col_in(petal), col_in(petal_tip), smoothstep(0.25, 1.0, UV.x)), smoothstep(0.0, 0.34, UV.x)) * tint_v;
		// a régi csíkok a durva rácson cikcakkosak voltak; puha stílusban a szirom széle felé enyhén világosodik
		c *= mix(0.94 + 0.1 * sin(UV.y * 22.0), 0.95 + 0.08 * UV.y * UV.x, soft_k);
		// bimbóban a szirmok töve zöldes, hervadáskor fakó, barnás krém
		c = mix(c, vec3(0.32, 0.46, 0.22), bud_v * 0.5 * (1.0 - UV.x * 0.6));
		c = mix(c, vec3(dot(c, vec3(0.33))) * vec3(1.05, 0.92, 0.74), fade_v * 0.7);
		vec3 alb = thirsty_col(c, thirst * 0.3);
		ALBEDO = col_out(alb);
		soft_fix = soft_fix_of(alb, ALBEDO);
		ROUGHNESS = 0.5;
		BACKLIGHT = alb * (1.1 * backlight_k());
	}
	EMISSION = col_out(col_in(glow_col) * (glow_amt * (part_on(0.0) * (smoothstep(0.1, 0.9, UV.x) * 3.2 + 0.9) + 0.12) + touch_wave(u_v) * 1.2));
#ifdef FALL
	if (fall_gone(FRAGCOORD.xy)) {
		discard;
	}
#endif
}

void light() {
	// a szirom vékony: hátulról erősen átsüt
	vec3 sp;
	DIFFUSE_LIGHT += soft_light(NORMAL, LIGHT, VIEW, ATTENUATION, LIGHT_COLOR, 1.0, 0.3, sp) * soft_fix;
	SPECULAR_LIGHT += sp;
}
