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
// pastel_k: a pasztell sáv erőssége (2026. 11. 13., célkép: docs/art/targets/). 0 = a színek változatlanok; 1 = nincs sötét
// tónus, kisebb telítettség. Éjjel a main.gd lejjebb veszi, hogy a biolumineszcencia sötét háttér előtt világítson.
global uniform float pastel_k;
// crown_puff: 0 = a korona egy puha tömb (egy ellipszoid), 1 = felhőcsomók (pamacsok) – lásd leaf.gdshader.
global uniform float crown_puff;

// Pasztell sáv (lineáris be/ki): a szín tónusát egy világos sávba húzza, a telítettséget visszafogja. A DNS-ből jövő
// árnyalat (merre áll a szín-keréken) nem változik, így egy magenta virág magenta marad, csak pasztell.
// A célkép mérése: a legsötétebb folt is ~0,6-os világosságú, a fő színek telítettsége 0,1–0,3.
vec3 soft_pastel(vec3 lin, float amt) {
	float k = clamp(pastel_k * soft_k * amt, 0.0, 1.0);
	vec3 d = sqrt(max(lin, vec3(0.0)));		// közelítő kijelző-tér (gamma 2), itt a lépték egyenletesebb
	float l = dot(d, vec3(0.299, 0.587, 0.114));
	vec3 ch = d - vec3(l);					// a szín (a szürkétől való eltérés) – ez marad, csak a tónus emelkedik
	float l2 = mix(l, 0.34 + 0.62 * l, k);	// a tónus a ~0,34–0,96 sávba: nincs fekete, a fehér sem ég ki
	d = clamp(vec3(l2) + ch * (1.0 - 0.08 * k), 0.0, 1.0);
	return d * d;
}

// A saját light() függvény eredményét a Compatibility (web) renderer a még sRGB-kódolt albedóval szorozza (col_out után),
// a Mobile a lineárissal; ettől weben a közvetlen fény 2–3× erősebb volt, a sötétebb csatornákon jobban (a füvön mérve:
// csak környezeti fénnyel a kettő egyezik). A fragmentben egyszer kiszámoljuk a lineáris / kódolt arányt (soft_fix_of),
// a light() ezzel szorozza a közvetlen fényt. (Fényenként újraszámolva képpontonként még egy pow() lenne – a fű sok
// egymást takaró szálán ez drága.)
varying vec3 soft_fix;

vec3 soft_fix_of(vec3 lin, vec3 enc) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return lin / max(enc, vec3(1e-4));
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
