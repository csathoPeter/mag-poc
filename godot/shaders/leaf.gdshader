shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
#include "res://shaders/common.gdshaderinc"
uniform vec3 base : source_color = vec3(0.2, 0.5, 0.2);
uniform vec3 tip : source_color = vec3(0.4, 0.7, 0.3);
varying float tint_v;
varying float ao_v;
varying float u_v;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float g = smoothstep(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.x + 0.07, grow);
	vec3 p = (VERTEX - o) * g;
	p.z += sin(TIME * 2.3 + o.x * 6.0 + o.z * 4.0) * 0.012 * UV.x * step(0.001, amp);
	// szomjasan a levél lehajlik (a hossza marad)
	float pl = length(p);
	if (droop > 0.0 && pl > 0.0) {
		p = normalize(p - tree_up() * pl * droop * 0.9) * pl;
	}
	VERTEX = o + p + sway(o, TIME) + droop_off(o);
	tint_v = INSTANCE_CUSTOM.y;
	ao_v = INSTANCE_CUSTOM.z;
	u_v = (INSTANCE_CUSTOM.x - 0.05) / 0.64;
}

void fragment() {
	vec3 a = mix(base, tip, UV.x * UV.x) * (0.8 + tint_v * 0.42);
	float rib = smoothstep(0.13, 0.0, UV.y);
	float vein = smoothstep(0.72, 1.0, sin(UV.x * 44.0 + UV.y * 16.0)) * (1.0 - rib);
	ALBEDO = thirsty_col(mix(a, a * 1.5 + 0.012, rib * 0.6 + vein * 0.16), thirst * 0.55);
	ROUGHNESS = 0.55;
	SPECULAR = 0.32;
	BACKLIGHT = ALBEDO * vec3(1.0, 1.0, 0.75) * 0.9;
	AO = ao_v;
	AO_LIGHT_AFFECT = 0.45;
	EMISSION = glow_col * (glow_amt * (part_on(1.0) * (rib * 2.2 + vein * 3.5 + 0.25) + 0.06) + touch_wave(u_v) * 0.9);
}
