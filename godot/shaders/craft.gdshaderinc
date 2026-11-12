// Kézműves levél (2026. 11. 12.): a gépies, tökéletesen ismétlődő levelek helyett minden levél kicsit más, és látszik
// rajta az anyag. Globális `craft` (main.gd _craft_globals(), ?level=…, a fejlesztői fiók „levél: …” gombja):
// 0 = gépies (a korábbi kép), 1 = vágott papír, 2 = akvarell. A tökéletlenség a levél saját véletlen számából jön
// (INSTANCE_CUSTOM.y), így determinisztikus: ugyanaz a fa mindig ugyanazzal a „kézírással” nő.
global uniform float craft;

// 1, ha a kézműves mód be van kapcsolva (papír vagy akvarell).
float craft_on() {
	return step(0.5, craft);
}

float craft_paper() {
	return 1.0 - step(0.5, abs(craft - 1.0));
}

float craft_water() {
	return 1.0 - step(0.5, abs(craft - 2.0));
}

// Hash kis számokkal (mobilon a sin()-es hash nagy argumentumnál pontatlan).
float craft_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Három független véletlen szám (-0,5…0,5) a levél saját számából.
vec3 craft_rand3(float k) {
	return vec3(craft_hash(vec2(k * 97.0, 1.7)), craft_hash(vec2(k * 61.0, 7.3)), craft_hash(vec2(k * 43.0, 3.1))) - 0.5;
}

// Simított értékzaj (0–1).
float craft_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = craft_hash(i);
	float b = craft_hash(i + vec2(1.0, 0.0));
	float c = craft_hash(i + vec2(0.0, 1.0));
	float d = craft_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
