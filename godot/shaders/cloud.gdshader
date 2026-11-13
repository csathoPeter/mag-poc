shader_type spatial;
// Festett gomolyfelhők (2026. 11. 13., clouds.gd): a Nano Banana Pro festette felhők (art/felho → textures/felhok.png,
// 4×2 cellás atlasz) a bolygó körüli távoli gömbhéjon, mindig a kamera felé fordulva (billboard), napszak szerint
// színezve: nappal ahogy festve vannak, alkonyatkor rózsásabb fény és lilább árnyék, éjjel halvány sötétkék. A lencse után
// rajzolódnak (render_priority, clouds.gd), így élesek maradnak; mélységet nem írnak.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
#include "res://shaders/color_space.gdshaderinc"

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform float night = 0.0;
uniform float dusk = 0.0;
// láthatóság (0–1): a kozmoszban, az átfogó nézetben és régi stílusban 0 (clouds.gd)
uniform float vis = 1.0;
// a légkör színe (lineáris): halkan a felhőbe is (egy palettán a bolygóval)
uniform vec3 atmo_lin = vec3(0.8, 0.75, 0.9);

varying vec2 cell_uv;
varying float tone_v;

void vertex() {
	// INSTANCE_CUSTOM: x = atlasz-cella (0–7), y = szélesség (világ-egység), z = tónus (0,9–1,05)
	// a kamera felé fordított négyszög világ-térben (mint a glow_dot.gdshaderinc), a kamera „fent”-jével
	vec3 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float w = INSTANCE_CUSTOM.y;
	vec3 wp = c + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * w;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	float cell = INSTANCE_CUSTOM.x;
	cell_uv = (UV + vec2(mod(cell, 4.0), floor(cell / 4.0))) / vec2(4.0, 2.0);
	tone_v = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec4 t = texture(atlas, cell_uv);
	// a textúra sRGB adat (nem source_color): itt alakítjuk lineárisra, így a két renderer ugyanazt kapja
	vec3 c = pow(t.rgb, vec3(2.2)) * tone_v;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 w = vec3(0.2126, 0.7152, 0.0722);
	vec3 atmo_n = atmo_lin * (l / max(dot(atmo_lin, w), 1e-3));
	c = mix(c, atmo_n, 0.12);
	// alkonyat: a fény rózsás-barackos, az árnyék lilább
	vec3 du = c * mix(vec3(0.78, 0.52, 0.78), vec3(1.05, 0.72, 0.66), smoothstep(0.35, 0.8, l));
	c = mix(c, du, dusk);
	// éjjel: halvány, sötétkék, holdfényes perem
	c = mix(c, c * vec3(0.16, 0.19, 0.34), night);
	ALBEDO = col_out(c);
	ALPHA = t.a * vis * mix(1.0, 0.55, night);
}
