shader_type spatial;
render_mode world_vertex_coords, cull_back;
#include "res://shaders/common.gdshaderinc"
#include "res://shaders/soft_light.gdshaderinc"
varying float path_v;
// Ritka módosítás (genes.gd rare_params): 1 aranykéreg (fémesebb fény, a bordákon lassan végigfutó csillanás).
uniform int wood_fx = 0;

void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
	vec3 prev = (MODEL_MATRIX * vec4(CUSTOM1.xyz, 1.0)).xyz;
	float b = CUSTOM0.w / max_path * 0.64;
	float g = smoothstep(b, b + 0.045, grow);
	float t = smoothstep(b, b + 0.42, grow);
	VERTEX = mix(prev, c, g) + (VERTEX - c) * (0.22 * g + 0.78 * t) + sway(c, TIME) + droop_off(c);
	path_v = CUSTOM0.w;
}

void fragment() {
	float a = atan(UV.y, UV.x);
	float ridge = 0.5 + 0.5 * sin(a * 7.0 + sin(path_v * 5.0 + a * 2.0) * 1.7);
	float fine = 0.5 + 0.5 * sin(a * 19.0 + path_v * 9.0 + sin(path_v * 23.0) * 2.0);
	// puha stílus: a kéreg mintája csak ott, ahol a képen elég nagy (különben csíkos, vibráló), kisebb kontraszttal,
	// és a koromfekete kéreg is kap egy kis fényt (pasztell: nincs fekete)
	float px = length(fwidth(UV)) + fwidth(path_v);
	ridge = mix(ridge, mix(0.5, ridge, clamp(1.0 - px * 5.0, 0.0, 1.0)), soft_k);
	fine = mix(fine, mix(0.5, fine, clamp(1.0 - px * 14.0, 0.0, 1.0)), soft_k);
	AO = 0.72 + 0.28 * ridge;
	vec3 tone = mix(COLOR.rgb * (0.5 + 0.55 * ridge + 0.25 * fine), COLOR.rgb * (0.72 + 0.34 * ridge + 0.12 * fine) * 0.92 + vec3(0.014, 0.012, 0.018), soft_k);
	vec3 alb = thirsty_col(tone, thirst * 0.25);
	// télen dér/hó az ágak felfelé néző oldalán (M11)
	float snow = season_snow(dot(normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz), tree_up())) * (0.75 + 0.25 * fine);
	alb = mix(alb, vec3(0.78, 0.82, 0.88), snow * 0.85);
	vec3 alb_l = ao_direct(alb, AO, 0.5);
	ALBEDO = col_out(alb_l);
	soft_fix = soft_fix_of(alb_l, ALBEDO);
	ROUGHNESS = wood_fx == 1 ? 0.38 : 0.92;
	AO_LIGHT_AFFECT = 0.5;
	float lines = smoothstep(0.8, 1.0, fine) * ridge;
	EMISSION = col_out(col_in(glow_col) * (glow_amt * part_on(2.0) * (lines * 4.0 + 0.15) + touch_wave(path_v / max_path) * 1.3)
		+ soft_rim(NORMAL, VIEW, 0.06) * alb);
	if (wood_fx == 1) {
		float glint = pow(max(sin(path_v * 2.4 - TIME * 1.1 + a), 0.0), 18.0) * ridge;
		EMISSION += col_out(vec3(1.0, 0.78, 0.36) * (glint * 0.9 + 0.06));
	}
#ifdef FALL
	if (fall_gone(FRAGCOORD.xy)) {
		discard;
	}
#endif
}

void light() {
	vec3 sp;
	DIFFUSE_LIGHT += soft_light(NORMAL, LIGHT, VIEW, ATTENUATION, LIGHT_COLOR, 0.0, 0.12, sp) * soft_fix;
	SPECULAR_LIGHT += sp;
}
