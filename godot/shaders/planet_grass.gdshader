shader_type spatial;
// Szálankénti fű a bolygón. Az ötletek a 2Retr0/GodotGrass projektből (MIT) és a Ghost of Tsushima GDC-előadásból jönnek:
// magassággal arányos hajlás (íves szál), egységes szél, nézetből oldalra eső szálak kiszélesítése,
// lekerekített normál, tő felé sötétedő szín, puha szórt fény és hátulról átsütő fény.
// Egy példány egy csomó (több szál), így ugyanannyi példányból sűrűbb a fű.
// Csak spatial shader + MultiMesh, így a webes (Compatibility) rendererrel is működik.
render_mode cull_disabled, shadows_disabled;

uniform vec3 base_col : source_color = vec3(0.12, 0.22, 0.1);
uniform vec3 tip_col : source_color = vec3(0.6, 0.75, 0.45);
uniform vec3 sss_col : source_color = vec3(1.0, 0.86, 0.6);
uniform vec3 glow_col : source_color = vec3(0.5, 1.0, 0.8);
uniform float night = 0.0;
uniform float wind = 1.0;
// A szél a bolygó körül kering e tengely körül.
uniform vec3 wind_axis = vec3(0.3, 1.0, 0.2);

varying float hf_v;
varying float rnd_v;
varying float clump_v;
varying float gust_v;
varying vec3 side_v;

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

void vertex() {
	// INSTANCE_CUSTOM: y = véletlen, z = csomó (0..1), w = második véletlen
	// CUSTOM0 (csúcspontonként): xy = a szál töve a csomóban, z = félszélesség, w = oldal (-1, 0, 1)
	// UV.y = magasság a szálon belül (0 tő, 1 csúcs)
	float rnd = INSTANCE_CUSTOM.y;
	float rnd2 = INSTANCE_CUSTOM.w;
	float hf = UV.y;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 up_w = normalize(MODEL_MATRIX[1].xyz);

	// szél: a tengely körül keringő irány; a széllökések hullámként futnak körbe a bolygón (varrat nélkül)
	vec3 ax = normalize(wind_axis);
	vec3 bx = normalize(cross(ax, vec3(1.0, 0.0, 0.0)));
	vec3 cx = cross(ax, bx);
	float phi = atan(dot(root, cx), dot(root, bx));
	float along = dot(root, ax);
	float gust = 0.5 + 0.5 * sin(phi * 9.0 + along * 0.8 - TIME * 1.6);
	gust *= 0.55 + 0.45 * sin(phi * 4.0 + along * 2.1 - TIME * 0.9);
	vec3 wdir = cross(ax, up_w);
	wdir = length(wdir) > 0.001 ? normalize(wdir) : vec3(1.0, 0.0, 0.0);
	float strength = wind * gust;

	// a csomó a véletlen irány és a szél iránya között áll
	vec3 wl = transpose(mat3(MODEL_MATRIX)) * wdir;
	vec2 rd = vec2(sin(rnd * 6.2831), cos(rnd * 6.2831));
	vec2 wd = normalize(wl.xz + vec2(1e-5));
	vec2 d = normalize(mix(rd, wd, clamp(0.35 + strength * 0.6, 0.0, 0.95)));
	mat3 ry = rot_y(atan(d.x, d.y));
	// hajlás: minél magasabban van a pont, annál jobban (íves szál); minden szál a saját töve körül hajlik
	float bend = (mix(0.12, 0.42, rnd2) + strength * 0.55 + 0.08 * sin(TIME * 3.1 + rnd * 20.0) * strength) * hf;
	mat3 r = ry * rot_x(bend);
	vec3 base = vec3(CUSTOM0.x, 0.0, CUSTOM0.y);
	vec3 side_l = normalize(cross(vec3(0.0, 1.0, 0.0), NORMAL));
	VERTEX = ry * base + r * (VERTEX - base);
	NORMAL = r * NORMAL;

	// nézetből oldalra eső szálak kiszélesítése, a távoliak eleve szélesebbek (így ritkább fű is dúsnak hat)
	vec3 vv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float edge = 1.0 - abs(dot(nv, normalize(-vv)));
	float scale = length(MODEL_MATRIX[0].xyz);
	float far = clamp(length(vv) * 0.05 - 0.5, 0.0, 1.2);
	vv.x += (edge * edge * edge * edge * 1.5 + far) * CUSTOM0.z * scale * CUSTOM0.w;
	POSITION = PROJECTION_MATRIX * vec4(vv, 1.0);

	side_v = normalize((MODELVIEW_MATRIX * vec4(r * side_l, 0.0)).xyz);
	hf_v = hf;
	rnd_v = rnd;
	clump_v = INSTANCE_CUSTOM.z;
	gust_v = gust;
}

void fragment() {
	// lekerekített normál: a szál két széle kicsit kifelé néz
	NORMAL = normalize(NORMAL + side_v * (UV.x * 2.0 - 1.0) * 0.45);
	float h = hf_v;
	vec3 tip = tip_col * (0.85 + 0.3 * clump_v);
	vec3 c = mix(base_col, tip, h * h);
	c *= mix(0.45, 1.0, h);
	c *= 0.9 + 0.2 * rnd_v;
	// széllökés: a meghajló szálak csúcsa világosabb, így a hullámok végigfutnak a mezőn
	c *= 1.0 + 0.32 * gust_v * h;
	// távolban egyszínűbb, hogy ne vibráljon
	float far = exp(-length(VERTEX) * 0.035);
	c = mix(mix(base_col, tip_col, 0.55) * 0.75, c, far);
	ALBEDO = c;
	ROUGHNESS = mix(1.0, 0.45, h);
	SPECULAR = 0.25;
	EMISSION = glow_col * night * step(0.93, rnd_v) * h * h * 1.2;
}

void light() {
	// puha szórt fény (sosem teljesen sötét) + hátulról átsütő fény
	float diff = pow(4.0, dot(NORMAL, LIGHT)) / 4.0;
	float sss = max(-dot(VIEW, LIGHT), 0.0) * 0.55 * hf_v;
	DIFFUSE_LIGHT += (diff + sss * sss_col) * ATTENUATION * LIGHT_COLOR / PI;
	vec3 hv = normalize(LIGHT + VIEW);
	SPECULAR_LIGHT += pow(max(dot(NORMAL, hv), 0.0), 24.0) * diff * hf_v * 0.35 * ATTENUATION * LIGHT_COLOR / PI;
}
