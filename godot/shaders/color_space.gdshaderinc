// Színtér a két renderer között (M11, webes színek).
// A Mobile (natív) renderer az ALBEDO-t, az EMISSION-t és az ég COLOR-ját lineárisnak veszi, a source_color uniformokat
// lineárisra alakítva adja. A Compatibility (webes, Godot 4.7) mindhármat sRGB-nek veszi (a shader után alakítja
// lineárisra: scene.glsl „albedo = srgb_to_linear(albedo)”), a source_color uniformot pedig átalakítás nélkül adja.
// A mi shadereink lineárisan számolnak (szorzás, keverés, összeadás), ezért weben ugyanaz a kód sötétebb, kontrasztosabb,
// a sötét részek (éjszaka, kéreg, árnyék) szinte feketék lettek. Javítás: a source_color uniformot col_in()-nel olvassuk
// (weben linearizál), a kimenetet col_out()-tal írjuk (weben visszakódol sRGB-re). Natívan mindkettő üres.
// A csúcs- és példányszínek (COLOR) és a számkonstansok nálunk mindig lineárisak, azokhoz nem kell col_in().

vec3 col_in(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
#else
	return c;
#endif
}

vec3 col_out(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	c = max(c, vec3(0.0));
	return mix((pow(c, vec3(1.0 / 2.4)) * 1.055) - vec3(0.055), c * 12.92, lessThan(c, vec3(0.0031308)));
#else
	return c;
#endif
}

// A Compatibility renderer az AO_LIGHT_AFFECT-et nem alkalmazza a közvetlen (nap)fényre, csak a környezetire (a lomb
// belseje így világosabb, laposabb volt weben). Közelítés: weben az albedót is sötétítjük ennyivel.
vec3 ao_direct(vec3 albedo, float ao, float affect) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return albedo * mix(1.0, ao, affect * 0.8);
#else
	return albedo;
#endif
}

// Az átsütő fény (BACKLIGHT) a Compatibility rendererben jóval erősebb (a 14 levélforma tábláján, --shot=…,leaves
// mérve: 0,3-del szorozva egyezik a Mobile rendererrel, M11).
float backlight_k() {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return 0.3;
#else
	return 1.0;
#endif
}
