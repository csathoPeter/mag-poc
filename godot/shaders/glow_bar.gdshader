shader_type spatial;
// A kettős spirál bázispár-kötései: vékony, önvilágító pálcák (MultiMesh-henger), a közepük fényesebb,
// a szélük áttetsző, így fénycsőnek hatnak. Szín és átlátszóság a példány színéből (COLOR).
// Nem additív: így a pasztell szín világos háttér előtt is megmarad (nem fehéredik ki).
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_back, fog_disabled, shadows_disabled;
varying vec4 col_v;

void vertex() {
	col_v = COLOR;
}

void fragment() {
	float f = abs(dot(NORMAL, VIEW));
	ALBEDO = col_v.rgb * (0.85 + 0.3 * f * f);
	ALPHA = clamp(col_v.a * (0.35 + 0.65 * f), 0.0, 1.0);
}
