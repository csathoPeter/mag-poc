shader_type sky;
#include "res://shaders/color_space.gdshaderinc"
uniform vec3 zenith : source_color = vec3(0.1, 0.16, 0.32);
uniform vec3 horizon : source_color = vec3(0.95, 0.65, 0.4);

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 c = d.y > 0.0 ? mix(col_in(horizon), col_in(zenith), pow(smoothstep(0.0, 0.2, d.y), 0.75)) : col_in(horizon);
	float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
	c += LIGHT0_COLOR * (pow(s, 240.0) * 5.0 + pow(s, 24.0) * 0.5 + pow(s, 5.0) * 0.16) * smoothstep(-0.1, 0.03, d.y);
	COLOR = col_out(c);
}
