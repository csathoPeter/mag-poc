shader_type spatial;
render_mode world_vertex_coords, cull_back;
#include "res://shaders/common.gdshaderinc"
varying float path_v;

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
	AO = 0.72 + 0.28 * ridge;
	vec3 alb = thirsty_col(COLOR.rgb * (0.5 + 0.55 * ridge + 0.25 * fine), thirst * 0.25);
	// télen dér/hó az ágak felfelé néző oldalán (M11)
	float snow = season_snow(dot(normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz), tree_up())) * (0.75 + 0.25 * fine);
	alb = mix(alb, vec3(0.78, 0.82, 0.88), snow * 0.85);
	ALBEDO = col_out(ao_direct(alb, AO, 0.5));
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
	AO_LIGHT_AFFECT = 0.5;
	float lines = smoothstep(0.8, 1.0, fine) * ridge;
	EMISSION = col_out(col_in(glow_col) * (glow_amt * part_on(2.0) * (lines * 4.0 + 0.15) + touch_wave(path_v / max_path) * 1.3));
#ifdef FALL
	if (fall_gone(FRAGCOORD.xy)) {
		discard;
	}
#endif
}
