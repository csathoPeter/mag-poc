shader_type spatial;
// Díszek a kopár bolygókon (2026. 11. 13., props.gd): kövek, kavicsok, gombák, lóhere, páfrány, kis virágok a
// Quaternius Stylized Nature MegaKitből (CC0). A modell saját festett textúrája adja a rajzolatot; a színe a bolygó
// színe felé húz (tint_k), hogy egy palettán legyen a talajjal; a fény a puha stílusé (soft_light.gdshaderinc), mint
// a fűé. A levél / szirom változat (#define CUT, props.gd) az átlátszó részt kivágja – külön shader, mert a discard
// a többi dísznél is lassítaná a rajzolást.
render_mode cull_disabled;
#include "res://shaders/color_space.gdshaderinc"
#include "res://shaders/soft_light.gdshaderinc"

// a modell textúrája; nem source_color: az sRGB → lineáris átalakítás itt történik, így a két renderer ugyanazt kapja
uniform sampler2D tex : filter_linear_mipmap, repeat_enable;
// a bolygó színe (lineáris) és mennyire húz felé (0: a textúra színe, 1: a textúra fényessége a bolygó színével)
uniform vec3 tint_lin = vec3(1.0);
uniform float tint_k = 0.0;
// levél / szirom: kétoldalú lap, átsütő fény
uniform float leafy = 0.0;

varying float bright_v;

void vertex() {
	// példányonként kicsit más tónus (props.gd: INSTANCE_CUSTOM.r)
	bright_v = INSTANCE_CUSTOM.r;
}

void fragment() {
	vec4 t = texture(tex, UV);
#ifdef CUT
	if (t.a < 0.5) {
		discard;
	}
#endif
	vec3 c = pow(t.rgb, vec3(2.2));
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	vec3 tinted = tint_lin * (dot(c, w) / max(dot(tint_lin, w), 1e-3));
	c = mix(c, tinted, tint_k) * bright_v;
	ALBEDO = col_out(c);
	soft_fix = soft_fix_of(c, ALBEDO);
	NORMAL = mix(NORMAL, soft_face(NORMAL, VIEW), leafy);
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	EMISSION = col_out(soft_rim(NORMAL, VIEW, 0.6));
}

void light() {
	vec3 spec;
	DIFFUSE_LIGHT += soft_light(NORMAL, LIGHT, VIEW, ATTENUATION, LIGHT_COLOR, 0.6 * leafy, 0.0, spec) * soft_fix;
}
