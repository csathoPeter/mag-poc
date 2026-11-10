shader_type spatial;
// Bolygófelszín: kőzet a meredek és magas részeken, felszíntakaró a laposon; a peremen a légkör pasztell párája.
uniform vec3 rock : source_color = vec3(0.6, 0.55, 0.6);
uniform vec3 grass : source_color = vec3(0.5, 0.7, 0.5);
uniform vec3 atmo : source_color = vec3(0.8, 0.7, 0.9);
uniform float night = 0.0;
varying float h_v;
varying float patch_v;
varying float slope_v;

void vertex() {
	h_v = COLOR.r;
	patch_v = COLOR.g;
	slope_v = dot(normalize(NORMAL), normalize(VERTEX));
}

void fragment() {
	float g = smoothstep(0.82, 0.95, slope_v) * (1.0 - smoothstep(0.78, 0.97, h_v));
	vec3 c = mix(rock * (0.8 + 0.3 * h_v), grass * (0.8 + 0.35 * patch_v), g);
	c *= 0.9 + 0.18 * patch_v;
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(c, atmo, fr * 0.45);
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
	EMISSION = atmo * fr * mix(0.22, 0.16, night) + grass * night * 0.05 * g;
}
