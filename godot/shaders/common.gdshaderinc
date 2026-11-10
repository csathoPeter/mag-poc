uniform float grow = 1.0;
uniform float amp = 0.09;
uniform float plant_h = 5.0;
uniform float max_path = 1.0;
// A fa saját kerete (a bolygón a fák ferdén állnak, a szél a fa "felfelé" irányához igazodik).
uniform mat4 tree_xf = mat4(1.0);
uniform mat4 tree_inv = mat4(1.0);
uniform float tree_scale = 1.0;
// Éjszakai fény: szín, erősség (rejtett tulajdonság × éjszaka), melyik rész világít (0 virág, 1 levél, 2 kéreg).
uniform vec3 glow_col : source_color = vec3(0.5, 0.9, 1.0);
uniform float glow_amt = 0.0;
uniform float glow_part = 0.0;
// Érintés óta eltelt idő másodpercben (-1: nincs), a tövétől a csúcsa felé futó fényhullámhoz.
uniform float wave = -1.0;

vec3 sway(vec3 wp, float t) {
	vec3 p = (tree_inv * vec4(wp, 1.0)).xyz * tree_scale;
	float h = max(p.y, 0.0) / plant_h;
	float a = h * h * amp * plant_h / 5.0;
	vec3 off = vec3(sin(t * 0.7 + p.y * 0.4 + p.z * 0.3) * a + sin(t * 1.7 + p.x * 1.3) * a * 0.22, 0.0, cos(t * 0.6 + p.x * 0.35) * a * 0.7);
	return mat3(tree_xf) * off / tree_scale;
}

float part_on(float k) {
	return 1.0 - step(0.5, abs(glow_part - k));
}

float touch_wave(float u) {
	if (wave < 0.0) {
		return 0.0;
	}
	float front = wave * 0.6 - 0.1;
	return exp(-pow((u - front) * 6.0, 2.0)) * (1.0 - smoothstep(1.8, 3.0, wave));
}
