shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float focus = 12.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d);
#endif
	vec4 v = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float z = -v.z / v.w;
	float far_c = smoothstep(focus + 4.0, focus + 34.0, z);
	float tilt = smoothstep(0.22, 0.52, abs(SCREEN_UV.y - 0.58));
	float coc = clamp(max(far_c, tilt * 0.6), 0.0, 1.0);
	float lod = coc * 5.2;
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	if (coc > 0.02) {
		vec2 px = pow(2.0, lod) * 0.9 / VIEWPORT_SIZE;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 2.39996;
			float r = sqrt((float(i) + 0.5) / 8.0);
			c += textureLod(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * r * px, lod).rgb;
		}
		c /= 9.0;
	}
	ALBEDO = c;
}
