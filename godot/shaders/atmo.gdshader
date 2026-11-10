shader_type spatial;
// Légkör: additív perem-izzás a bolygó körül, a szélén elhalványul.
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled, shadows_disabled;
uniform vec3 atmo : source_color = vec3(0.8, 0.7, 0.9);
uniform float strength = 1.0;

void fragment() {
	float d = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - d, 3.0) * smoothstep(0.0, 0.4, d);
	ALBEDO = atmo * rim * strength * 1.4;
}
