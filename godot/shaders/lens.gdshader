shader_type spatial;
// Lencse-utófeldolgozás, két móddal, amelyek között puhán át lehet úszni:
//  - makett (tilt-shift): a kép egy vízszintes sávja éles, fölötte és alatta egyre erősebb az elmosás,
//    mint a tilt-shift objektívvel fotózott városképeken; a bolygó-nézethez.
//  - DSLR-mélységélesség: a fókusztávolságban lévő rész éles, előtte és mögötte a távolság arányában elmosódik
//    (vékony lencse közelítés); leszállva és virágra közelítve.
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
// 0: makett, 1: mélységélesség
uniform float dof_mix = 0.0;
// makett: az éles sáv közepe (0 fent, 1 lent), félszélessége, és az elmosás erőssége a sávon kívül
uniform float band_y = 0.5;
uniform float band = 0.08;
uniform float tilt = 1.0;
// mélységélesség: fókusztávolság és rekesz (nagyobb = sekélyebb mélységélesség)
uniform float focus = 8.0;
uniform float aperture = 0.55;
// a fókusz körüli teljesen éles mélységtartomány (a téma, pl. a fa lombja ne mosódjon el)
uniform float zone = 0.0;
// régi (repülős) kert: a régi sáv a mélység szerinti távoli elmosással
uniform float legacy = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_z(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}

void fragment() {
	float z = view_z(SCREEN_UV, INV_PROJECTION_MATRIX);
	float dy = abs(SCREEN_UV.y - band_y);
	float c_tilt = smoothstep(band, band + 0.36, dy) * tilt;
	float c_dof = clamp(aperture * max(abs(z - focus) - zone, 0.0) / max(z, 0.01), 0.0, 1.0);
	float coc = mix(c_tilt, c_dof, dof_mix);
	if (legacy > 0.5) {
		float far_c = smoothstep(focus + 4.0, focus + 34.0, z);
		float t = smoothstep(0.22, 0.52, abs(SCREEN_UV.y - 0.58));
		coc = max(far_c, t * 0.6);
	}
	coc = clamp(coc, 0.0, 1.0);
	// az elmosás sugara a kép magasságának arányában; a mintavétel képpontonként elforgatva (ne legyen csíkos).
	// A mipmap-szint csak simít, ahol van (a webes renderer képernyő-textúrájának nincs), a sugár attól független.
	float rpx = coc * 0.024 * VIEWPORT_SIZE.y;
	float lod = log2(max(rpx / 4.0, 1.0));
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	if (rpx > 0.75) {
		float spin = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) * 6.2831;
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 2.39996 + spin;
			float r = sqrt((float(i) + 0.5) / 12.0);
			c += textureLod(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * r * rpx / VIEWPORT_SIZE, lod).rgb;
		}
		c /= 13.0;
	}
	ALBEDO = c;
}
