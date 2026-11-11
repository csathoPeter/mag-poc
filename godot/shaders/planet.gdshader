shader_type spatial;
// Bolygófelszín: kőzet a meredek és magas részeken, felszíntakaró a laposon; a peremen a légkör pasztell párája.
// A fű alatti talaj maga is fűszínű, szálas mintájú (mint a sűrű fű árnyékos belseje), így a szálak közti hézag nem kopasz.
uniform vec3 rock : source_color = vec3(0.6, 0.55, 0.6);
uniform vec3 grass : source_color = vec3(0.5, 0.7, 0.5);
uniform vec3 atmo : source_color = vec3(0.8, 0.7, 0.9);
uniform float night = 0.0;
// a domborzat megjelenése (M7): 0 = csupasz, sima gömb; az első fánál 1-re nő
uniform float shape = 1.0;
varying float h_v;
varying float patch_v;
varying float slope_v;
varying vec3 pos_v;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 unit = normalize(VERTEX);
	VERTEX = mix(unit, VERTEX, shape);
	NORMAL = normalize(mix(unit, NORMAL, shape));
	h_v = COLOR.r;
	patch_v = COLOR.g;
	slope_v = dot(normalize(NORMAL), normalize(VERTEX));
	pos_v = VERTEX;
}

void fragment() {
	float g = smoothstep(0.82, 0.95, slope_v) * (1.0 - smoothstep(0.78, 0.97, h_v));
	// szálas minta: apró foltok, a távolban (ahol vibrálna) elsimul
	float fine = vnoise(pos_v * 90.0) * 0.6 + vnoise(pos_v * 210.0) * 0.4;
	float fade = clamp(1.0 - length(fwidth(pos_v * 210.0)) * 0.8, 0.0, 1.0);
	fine = mix(0.5, fine, fade);
	vec3 meadow = grass * mix(0.42, 0.85, fine) * (0.85 + 0.3 * patch_v);
	vec3 c = mix(rock * (0.8 + 0.3 * h_v), meadow, g);
	c *= 0.9 + 0.18 * patch_v;
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(c, atmo, fr * 0.45);
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
	EMISSION = atmo * fr * mix(0.22, 0.16, night) + grass * night * 0.05 * g;
}
