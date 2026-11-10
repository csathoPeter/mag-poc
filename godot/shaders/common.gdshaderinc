uniform float grow = 1.0;
uniform float amp = 0.09;
uniform float plant_h = 5.0;
uniform float max_path = 1.0;

vec3 sway(vec3 p, float t) {
	float h = max(p.y, 0.0) / plant_h;
	float a = h * h * amp * plant_h / 5.0;
	return vec3(sin(t * 0.7 + p.y * 0.4 + p.z * 0.3) * a + sin(t * 1.7 + p.x * 1.3) * a * 0.22, 0.0, cos(t * 0.6 + p.x * 0.35) * a * 0.7);
}
