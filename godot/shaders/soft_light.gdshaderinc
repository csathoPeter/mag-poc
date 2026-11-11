// Puha, stilizált fény (2026. 11., DESIGN.md Art design): körvonal nélküli, festményszerű kép.
// - Körbefutó szórt fény puha lépcsőkkel: a fény és az árnyék határa széles, az árnyékos oldal sem fekete.
// - Színes árnyék: ahol kevés a közvetlen fény, ott a légkörből jövő lilás-kékes szín tölt (sötétítés helyett).
// - Átsütő fény (a nap felé nézve a levél, szirom, fűszál széle világít) és halk fényfolt.
// - Peremfény a légkör színében (a fragmentben, EMISSION-ként): a körvonal helyett ettől válik ki a forma a háttérből.
// A globális uniformokat a main.gd állítja (_soft_globals): a légkör árnyalatából és a napszakból.
// soft_k: 0 = a régi (Lambert) fény, 1 = a puha stílus; a fejlesztői „puha”/„régi” gomb ezzel vált (a régi kép közelítése).
// Minden érték lineáris; a DIFFUSE_LIGHT-ot a motor utána szorozza az albedóval.
global uniform vec3 shade_tint;
global uniform vec3 rim_col;
global uniform float soft_k;

// A saját light() függvény eredményét a Compatibility (web) renderer a még sRGB-kódolt albedóval szorozza (col_out után),
// a Mobile a lineárissal; ettől weben a közvetlen fény 2–3× erősebb volt, a sötétebb csatornákon jobban (a füvön mérve:
// csak környezeti fénnyel a kettő egyezik). A light()-ban ezzel szorozzuk a közvetlen fényt: weben lineáris / kódolt.
vec3 light_albedo_fix(vec3 albedo) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return col_in(albedo) / max(albedo, vec3(1e-4));
#else
	return vec3(1.0);
#endif
}

// Kétoldalú lap (levél, fűszál, szirom) normálja a néző felé fordítva. A két renderer a hátoldal normálját nem
// egyformán fordítja meg; a puha normállal (korona, szőnyeg) keverve weben ettől más lett a fény (mérve).
vec3 soft_face(vec3 n, vec3 v) {
	return dot(n, v) < 0.0 ? -n : n;
}

// A közvetlen fény ereje a felület és a fény szögéből (0–1).
float soft_diffuse(float ndl) {
	float w = clamp(ndl * 0.5 + 0.5, 0.0, 1.0);
	float ramp = 0.16 * smoothstep(0.18, 0.5, w) + 0.84 * smoothstep(0.42, 0.82, w);
	return mix(max(ndl, 0.0), ramp, soft_k);
}

// Egy fény hozzájárulása: a visszatérési érték a DIFFUSE_LIGHT-hoz, spec a SPECULAR_LIGHT-hoz adandó.
// sss: az átsütő fény erőssége (0: nincs), spec_k: a fényfolt erőssége.
vec3 soft_light(vec3 n, vec3 l, vec3 v, float att, vec3 lc, float sss, float spec_k, out vec3 spec) {
	float d = soft_diffuse(dot(n, l)) * att;
	float back = pow(clamp(-dot(v, l), 0.0, 1.0), 3.0) * sss * att;
	vec3 h = normalize(l + v);
	spec = lc * (pow(max(dot(n, h), 0.0), mix(24.0, 14.0, soft_k)) * spec_k * d / PI);
	return lc * ((d + back * vec3(1.0, 0.95, 0.78)) / PI) + shade_tint * ((1.0 - d) * soft_k);
}

// Peremfény (lineáris, az EMISSION-hoz): a nézetből elforduló felületeken a légkör színe.
vec3 soft_rim(vec3 n, vec3 v, float k) {
	float fr = 1.0 - clamp(dot(n, v), 0.0, 1.0);
	return rim_col * (fr * fr * fr * k * soft_k);
}
