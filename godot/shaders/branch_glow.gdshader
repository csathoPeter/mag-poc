shader_type spatial;
// Az alakító módban kiemelt ág (és ami rajta nő, M8): halvány, lüktető fényburok a faanyag körül. Ugyanaz a csúcs-út,
// mint a fáé (wood.gdshader: növekedés, szél, lekonyulás), csak a gyűrűk kicsit kövérebbek. Additív, a lencse után
// rajzolva (render_priority), mélységteszt nélkül: a lombon át is látszik, mit fogsz meg (a takart részen halványabb
// lenne, de a mélység a lencse után már nem megbízható, ezért egyszerűen mindenhol látszik).
render_mode world_vertex_coords, unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_back, fog_disabled, shadows_disabled;
#include "res://shaders/common.gdshaderinc"
uniform vec3 hi_col : source_color = vec3(1.0, 0.86, 0.55);
uniform float hi_amt = 1.0;
// a burok vastagsága (világ-egységben) a gyűrű sugarán felül
uniform float shell = 0.03;

void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
	vec3 prev = (MODEL_MATRIX * vec4(CUSTOM1.xyz, 1.0)).xyz;
	float b = CUSTOM0.w / max_path * 0.64;
	float g = smoothstep(b, b + 0.045, grow);
	float t = smoothstep(b, b + 0.42, grow);
	vec3 r = VERTEX - c;
	vec3 out_dir = length(r) > 1e-5 ? normalize(r) : NORMAL;
	VERTEX = mix(prev, c, g) + (r * 1.15 + out_dir * shell) * (0.22 * g + 0.78 * t) + sway(c, TIME) + droop_off(c);
}

void fragment() {
	float f = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float pulse = 0.8 + 0.2 * sin(TIME * 3.2);
	ALBEDO = hi_col * (0.2 + f * f * 0.9) * hi_amt * pulse;
}
