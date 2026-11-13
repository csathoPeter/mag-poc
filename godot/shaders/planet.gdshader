shader_type spatial;
// Bolygófelszín: kőzet a meredek és magas részeken, felszíntakaró a laposon; a peremen a légkör pasztell párája.
// A fű alatti talaj maga is fűszínű, szálas mintájú (mint a sűrű fű árnyékos belseje), így a szálak közti hézag nem kopasz.
#include "res://shaders/color_space.gdshaderinc"
#include "res://shaders/season.gdshaderinc"
#include "res://shaders/soft_light.gdshaderinc"
#include "res://shaders/paint_field.gdshaderinc"
uniform vec3 rock : source_color = vec3(0.6, 0.55, 0.6);
uniform vec3 grass : source_color = vec3(0.5, 0.7, 0.5);
uniform vec3 atmo : source_color = vec3(0.8, 0.7, 0.9);
uniform float night = 0.0;
// a domborzat megjelenése (M7): 0 = csupasz, sima gömb; az első fánál 1-re nő
uniform float shape = 1.0;
varying float h_v;
varying float band_v;
varying float patch_v;
varying float slope_v;
varying vec3 pos_v;

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
	vec3 unit = normalize(VERTEX);
	VERTEX = mix(unit, VERTEX, shape);
	NORMAL = normalize(mix(unit, NORMAL, shape));
	h_v = COLOR.r;
	patch_v = COLOR.g;
	band_v = COLOR.b;
	slope_v = dot(normalize(NORMAL), normalize(VERTEX));
	pos_v = VERTEX;
}

void fragment() {
	float g = smoothstep(0.82, 0.95, slope_v) * (1.0 - smoothstep(0.78, 0.97, h_v));
	// festett fű: a rövid szálak nem takarják a kőzetet, ezért a fű borítja a talaj nagyobb részét (csak a meredek
	// sziklák és a legmagasabb csúcsok kőzetek); a planet.gd _paint_cover ugyanezt süti a fű textúrájába
	g = mix(g, smoothstep(0.42, 0.66, slope_v) * (1.0 - smoothstep(0.93, 1.0, h_v)), paint_k * soft_k);
	// szálas minta: apró foltok, a távolban (ahol vibrálna) elsimul
	float fine = vnoise(pos_v * 90.0) * 0.6 + vnoise(pos_v * 210.0) * 0.4;
	float fade = clamp(1.0 - length(fwidth(pos_v * 210.0)) * 0.8, 0.0, 1.0);
	fine = mix(0.5, fine, fade);
	vec3 rock_l = col_in(rock);
	vec3 grass_l = col_in(grass);
	vec3 atmo_l = col_in(atmo);
	// a talaj a fű tövének színéhez igazodik (puha stílusban kisebb kontraszttal, hogy a hézag ne üssön el)
	vec3 meadow = grass_l * mix(mix(0.42, 0.85, fine), mix(0.5, 0.78, fine), soft_k) * 0.8;
	// festett fű (paint_field.gdshaderinc): a talaj maga a fűmező – széles tónus-sávok, a szálas apró minta helyett
	// halk, a sávokkal futó ecsetnyomok (a távolban elsimulnak); a fűszál töve ugyanezt a színt kapja
	vec3 dn = normalize(pos_v);
	float brush = pf_noise(pf_warp(dn, 26.0, 3.5) + 17.0) * 0.7 + pf_noise(pf_warp(dn, 61.0, 4.0) + 3.0) * 0.3;
	float bfade = clamp(1.0 - length(fwidth(dn * 26.0)) * 1.2, 0.0, 1.0);
	vec3 painted = paint_tone(grass_l, paint_band(band_v)) * (1.0 + (brush - 0.5) * 0.2 * bfade);
	meadow = mix(meadow, painted, paint_k * soft_k);
	// évszak (M11): tavasszal üdébb, ősszel melegebb (okkeres) a felszíntakaró; télen deres, fehéres
	float ml = season_luma(meadow);
	meadow = mix(meadow, meadow * vec3(1.02, 1.18, 0.92), season.x * 0.6);
	meadow = mix(meadow, vec3(ml) * vec3(1.45, 1.0, 0.42), season.z * 0.42);
	// festett fűnél a kőzet színe a fűhöz simul (egy festményen egy paletta), így a sziklák nem ütnek el foltként
	vec3 rock_c = mix(rock_l * (0.8 + 0.3 * h_v), mix(rock_l, grass_l * 0.8, 0.35), paint_k * soft_k);
	vec3 c = mix(rock_c, meadow, g);
	float frost = season.w * (0.45 + 0.35 * fine) * mix(0.55, 1.0, smoothstep(0.6, 0.9, slope_v));
	c = mix(c, vec3(0.8, 0.84, 0.9), frost * 0.55);
	// a fű alatti talaj egyszínű (a világos foltok kopasznak hatottak a szálak között); a kőzeten marad a foltosság
	c *= mix(0.9 + 0.18 * patch_v, 1.0, g);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	// a légkör rózsaszínes pereme csak a kőzeten: leszállva lapos szögből a fű alatti talajt is beszínezte, a rések kivilágítottak
	vec3 alb = mix(c, atmo_l, fr * 0.45 * (1.0 - g));
	ALBEDO = col_out(alb);
	soft_fix = soft_fix_of(alb, ALBEDO);
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
	// télen apró dér-csillanások (a felszínhez rögzítve, lassan pislákolva; a távolban, ahol vibrálna, elhalványulnak)
	vec3 cell = floor(pos_v * 260.0);
	float glint = step(0.93, hash(cell)) * (0.5 + 0.5 * sin(TIME * 1.3 + hash(cell + 3.1) * 40.0)) * fade * season.w;
	EMISSION = col_out(atmo_l * fr * mix(0.22, 0.16, night) + grass_l * night * 0.05 * g + vec3(0.85, 0.92, 1.0) * glint * mix(0.35, 0.7, night));
}

// Festett fűnél a talaj is puha fényt kap (széles átmenet, a kevés fényű részen lilás árnyék-szín, soft_light.gdshaderinc),
// mint a fűszál: így a szálak és a talaj egy felület. paint_k = 0-nál a korábbi Lambert-fény.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float pk = paint_k * soft_k;
	float d = mix(max(ndl, 0.0), soft_diffuse(ndl), pk) * ATTENUATION;
	DIFFUSE_LIGHT += (LIGHT_COLOR * (d / PI) + shade_tint * ((1.0 - d) * pk)) * soft_fix;
}

