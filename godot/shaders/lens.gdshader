shader_type spatial;
// Lencse-utófeldolgozás, két móddal, amelyek között puhán át lehet úszni:
//  - makett (tilt-shift): a kép egy vízszintes sávja éles, fölötte és alatta egyre erősebb az elmosás,
//    mint a tilt-shift objektívvel fotózott városképeken; a bolygó-nézethez.
//  - DSLR-mélységélesség: a fókusztávolságban lévő rész éles, előtte és mögötte a távolság arányában elmosódik
//    (vékony lencse közelítés); leszállva és virágra közelítve.
// Mélységtudatos gyűjtés: egy minta csak akkor kerül a képpont elmosásába, ha mögötte van (a háttér a saját körén
// belül elmosódik), vagy ha előtte van, de a saját elmosása elér idáig. Így az éles fa nem folyik bele a mögötte
// lévő elmosott háttérbe (nincs glória), az elmosott előtér viszont puhán rálóg.
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

// a legnagyobb elmosás sugara a kép magasságának arányában
const float MAX_R = 0.024;
const int TAPS = 20;

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

// az elmosás mértéke (0..1) egy képpontban: a makett-sáv a képernyő helyéből, a mélységélesség a mélységből
float coc(vec2 uv, float z) {
	float c_tilt = smoothstep(band, band + 0.36, abs(uv.y - band_y)) * tilt;
	float c_dof = aperture * max(abs(z - focus) - zone, 0.0) / max(z, 0.01);
	float c = mix(c_tilt, c_dof, dof_mix);
	if (legacy > 0.5) {
		float far_c = smoothstep(focus + 4.0, focus + 34.0, z);
		float t = smoothstep(0.22, 0.52, abs(uv.y - 0.58));
		c = max(far_c, t * 0.6);
	}
	return clamp(c, 0.0, 1.0);
}

void fragment() {
	float z = view_z(SCREEN_UV, INV_PROJECTION_MATRIX);
	float k = MAX_R * VIEWPORT_SIZE.y;
	float rc = coc(SCREEN_UV, z) * k;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	if (rc > 0.75) {
		// a mipmap-szint csak simít, ahol van; weben a 3D képernyő-textúra szintjeit a ragyogás használja, ott 0
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		float lod = 0.0;
#else
		float lod = log2(max(rc / 5.0, 1.0));
#endif
		float spin = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) * 6.2831;
		vec3 sum = c;
		float wsum = 1.0;
		// kis elmosáshoz kevesebb minta is elég
		int taps = rc < 6.0 ? 8 : TAPS;
		for (int i = 0; i < taps; i++) {
			float a = float(i) * 2.39996 + spin;
			float rho = sqrt((float(i) + 0.5) / float(taps)) * rc;
			// a minta négy képpont közös sarkára esik: a bilineáris szűrés így négyet átlagol (kevesebb szemcse)
			vec2 uv = round(FRAGCOORD.xy + vec2(cos(a), sin(a)) * rho) / VIEWPORT_SIZE;
			float zi = view_z(uv, INV_PROJECTION_MATRIX);
			// előtte lévő minta csak akkor számít, ha a saját elmosása elér idáig
			float w = zi < z * 0.97 ? clamp(coc(uv, zi) * k - rho + 1.0, 0.0, 1.0) : 1.0;
			sum += textureLod(screen_tex, uv, lod).rgb * w;
			wsum += w;
		}
		c = sum / wsum;
	}
	ALBEDO = c;
}
