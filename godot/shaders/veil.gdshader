shader_type spatial;
// Fátyol a világ előtt a kettős spirál alatt: ugyanaz a sötét lila köd, mint a DNS-tábla mögött, így a tábla
// eltűnésekor nincs vágás. A szélek felé alig sötétebb. A lencse után, a spirál előtt rajzolódik.
// A 3D-ben a keverés lineáris fényben, tónusleképezés előtt történik: ugyanakkora sötétítéshez nagyobb alfa kell,
// mint a 2D-s tábla .42-es fátylához (amount ≈ .9), mert az ég fényes (HDR), és a tónusleképezés összenyomja.
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.04, 0.02, 0.10, 1.0);
uniform float amount = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	ALBEDO = tint.rgb;
	float k = amount;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// weben a keverés a megjelenített (sRGB) színekben történik, mint a 2D-ben: ott a tábla .42-es fátyla a mérce
	k *= 0.5;
#endif
	// enyhe vignetta; 1 alá kell maradnia, különben a fényes (HDR) égen éles ovális határ látszana
	ALPHA = clamp(k * (0.96 + 0.07 * dot(d, d)), 0.0, 0.97);
}
