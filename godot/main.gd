extends Node3D
## Godot PoC: DNS-ből épülő növények egy kis bolygón (bolygó-DNS, napszak, éjszakai fény), valódi árnyékkal és mérőszámokkal.
## A korábbi módok (egy fa közelről, repülős kert) a --shot paraméterrel továbbra is elérhetők.

const WOOD := preload("res://shaders/wood.gdshader")
const LEAF := preload("res://shaders/leaf.gdshader")
const FLOWER := preload("res://shaders/flower.gdshader")
const GRASS := preload("res://shaders/grass.gdshader")
const GROUND := preload("res://shaders/ground.gdshader")
const SKY := preload("res://shaders/sky.gdshader")
const TILT := preload("res://shaders/tiltshift.gdshader")
const SPACE_SKY := preload("res://shaders/space_sky.gdshader")

var plants_root := Node3D.new()
var trees: Array = []
var tilt_quad := MeshInstance3D.new()
var joy := Control.new()
var joy_id := -1
var joy_knob := Vector2.ZERO
var stick := Vector2.ZERO
var cam_pos := Vector3.ZERO
var fly_vel := Vector3.ZERO
var roll := 0.0
var lod_timer := 0.0
const JOY_R := 62.0
var plants: Array = []
var queue: Array = []
var garden_mode := ""
var retreating := false
var build_ms_total := 0.0
var cam := Camera3D.new()
var sun := DirectionalLight3D.new()
var env := Environment.new()
var sky_mat := ShaderMaterial.new()
var ground_mat := ShaderMaterial.new()
var grass_mat := ShaderMaterial.new()
var flat_ground: Array = []

var yaw := 0.0
var pitch := 0.2
var dist := 18.0
var yaw_v := 0.0
var target := Vector3(0, 3, 0)
var min_dist := 6.0
var max_dist := 30.0
var touches := {}
var pinch_last := 0.0

var pending: Variant = null
var current: Dictionary = {}

var name_l := Label.new()
var traits_l := Label.new()
var stats_l := Label.new()
var gen_ms := 0.0
var stat_timer := 0.0
var shot_args: Array = []
var shot_frames := 0
var grow_start := 0.0

# Bolygó
var planet: Planet
var planet_dnas: Array = []
var space_mat := ShaderMaterial.new()
var view := "orbit"
var focus := -1
var orbit_q := Quaternion.IDENTITY
var orbit_dist := 20.0
var spin := Vector2.ZERO
var eye := Vector3(0, 0, 60)
var look := Vector3.ZERO
var up_v := Vector3.UP
var s_yaw := 0.0
var s_pitch := .28
var s_dist := 6.0
var trans_t := 9.0
var sun_dir := Vector3(.4, .6, .7)
var last_r := 0.0
var taps := {}
var tag := Label3D.new()
var tag_alpha := 0.0

# Napszak: a telefon órája szerint, vagy a gombbal kiválasztva
const TOD_PRESETS := [-1.0, 6.4, 12.0, 19.0, 23.0]
const TOD_NAMES := ["valódi idő", "hajnal", "nappal", "alkony", "éjjel"]
var tod_i := 0
var tod := -1.0
var shot_hour := -1.0
var night := -1.0
var dusk := -1.0
var tod_btn: Button

# Mérőkapcsolók (telefonon végigkattintva kiderül, mi viszi el az időt)
const SCALES := [1.0, .75, .6, .5]
const SKY_MODES := ["ég tex", "ég sima", "ég régi"]
var scale_i := 0
var sky_i := 0
var tilt_ok := true
## Egyszerre legfeljebb ennyi részletes fa (a mérés szerint leszállva a legtöbb úgyis kívül esik a képen).
const HI_TREES := 4
var hi_trees := HI_TREES
## Alap belső 3D-felbontás: sűrű kijelzőn (pl. iPhone, 3×) 75%, mert ott a pixelek kitöltése drága, és a tiltshiftes képen nem látszik.
var base_scale := 1.0
## A részletes fák távolsághatára (a fa közepétől a kameráig) és a visszaváltás többlete.
const LOD_DIST := 22.0
const MID_EXTRA := 5.0
const LOD_HYST := 3.0
var lod_force := false
var dbg_btn := {}

# Automatikus mérés: végigpróbálja a beállításokat kint és leszállva, a végén táblázat + küldés GitHubra
const BENCH_SETTLE := 1.2
const BENCH_MEASURE := 3.5
## Terheléses mérés: meddig bírja a telefon 60 fps-sel (fű sűrűsége, részletes fák, fák száma).
const LOAD_STEPS := [
	["lent", "alap (14 fa)", {}],
	["lent", "100% felbontás", {"scale": 1.0}],
	["lent", "fű ×1,5", {"gmul": 1.5}],
	["lent", "fű ×2", {"gmul": 2.0}],
	["lent", "fű ×3", {"gmul": 3.0}],
	["lent", "minden látható részletes", {"hi": 99, "force": true}],
	["kint", "14 fa", {}],
	["kint", "30 fa", {"trees": 30}],
	["lent", "30 fa", {"trees": 30}],
	["lent", "30 fa, 100%", {"trees": 30, "scale": 1.0}],
	["lent", "30 fa, fű ×1,5", {"trees": 30, "gmul": 1.5}],
	["lent", "30 fa, fű ×2", {"trees": 30, "gmul": 2.0}],
	["kint", "45 fa", {"trees": 45}],
	["lent", "45 fa", {"trees": 45}],
]
## Beállítás-mérés (?meres&beall): egyenként kikapcsolja a drága részeket.
const BENCH_STEPS := [
	["kint", "alap", {}],
	["kint", "75%", {"scale": .75}],
	["kint", "50%", {"scale": .5}],
	["kint", "fű ki", {"grass": false}],
	["kint", "árnyék ki", {"shadow": false}],
	["kint", "ragyogás ki", {"glow": false}],
	["kint", "ég sima", {"sky": 1}],
	["kint", "AA ki", {"aa": false}],
	["lent", "alap", {}],
	["lent", "75%", {"scale": .75}],
	["lent", "60%", {"scale": .6}],
	["lent", "50%", {"scale": .5}],
	["lent", "fű ki", {"grass": false}],
	["lent", "1 részletes fa", {"hi": 1}],
	["lent", "árnyék ki", {"shadow": false}],
	["lent", "ragyogás ki", {"glow": false}],
	["lent", "ég sima", {"sky": 1}],
	["lent", "tilt ki", {"tilt": false}],
	["lent", "AA ki", {"aa": false}],
	["lent", "minden ki, 50%", {"scale": .5, "grass": false, "hi": 1, "shadow": false, "glow": false, "sky": 1, "tilt": false, "aa": false}],
]
var bench_on := false
var bench_steps: Array = []
var bench_wait := false
var bench_i := -1
var bench_t := 0.0
var bench_last := 0
var bench_dt := PackedFloat32Array()
var bench_cpu := 0.0
var bench_tris := 0
var bench_rows: Array = []
var bench_cli := false
var bench_tod := 0


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	add_child(plants_root)
	planet = Planet.new()
	planet.visible = false
	add_child(planet)
	space_mat.shader = SPACE_SKY
	space_mat.set_shader_parameter("nebula", _nebula_texture())
	_build_world()
	_build_grass()
	_build_ui()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_args = a.substr(7).split(",")
		if a == "--bench":
			bench_cli = true
	_build_tag()
	if DisplayServer.screen_get_scale() >= 2.5:
		base_scale = .75
	get_viewport().scaling_3d_scale = base_scale
	scale_i = SCALES.find(base_scale)
	_sync_dbg()
	if shot_args.size() > 0 and shot_args[1] == "planet":
		grow_start = 1.0
		if shot_args.size() > 4:
			shot_hour = float(shot_args[4])
		start_planet(shot_args[2], int(shot_args[3]))
	elif shot_args.size() > 0:
		grow_start = float(shot_args[3])
		var dna: Array = []
		for s in (shot_args[1] as String).split("-"):
			dna.append(int(s))
		show_single(dna, shot_args[2])
		if shot_args.size() > 4:
			start_garden()
	else:
		start_planet("bolygo01", 14)
	if bench_cli or (OS.has_feature("web") and str(JavaScriptBridge.eval("location.search", true)).contains("meres")):
		start_bench.call_deferred()


func _build_world() -> void:
	sky_mat.shader = SKY
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_white = 5.0
	env.glow_enabled = true
	env.glow_intensity = .55
	env.glow_bloom = .04
	env.glow_hdr_threshold = .9
	env.glow_strength = 1.05
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 20.0
	env.fog_depth_end = 62.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 42.0
	sun.shadow_blur = 1.6
	sun.shadow_opacity = .78
	sun.shadow_normal_bias = 1.2
	add_child(sun)

	ground_mat.shader = GROUND
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 500)
	var g := MeshInstance3D.new()
	g.mesh = plane
	g.material_override = ground_mat
	add_child(g)
	flat_ground.append(g)

	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	var tm := ShaderMaterial.new()
	tm.shader = TILT
	tilt_quad.mesh = q
	tilt_quad.material_override = tm
	tilt_quad.extra_cull_margin = 16384.0
	tilt_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tilt_quad.visible = false
	add_child(tilt_quad)

	cam.fov = 38.0
	cam.near = .1
	cam.far = 400.0
	add_child(cam)


func _build_grass() -> void:
	var seg := 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg + 1:
		var t := float(i) / seg
		var w := .05 * (1.0 - t * .85)
		var z := .3 * t * t
		st.set_uv(Vector2(t, 1)); st.add_vertex(Vector3(-w, t, z))
		st.set_uv(Vector2(t, 1)); st.add_vertex(Vector3(w, t, z))
	for i in seg:
		var a := i * 2
		st.add_index(a); st.add_index(a + 1); st.add_index(a + 2)
		st.add_index(a + 1); st.add_index(a + 3); st.add_index(a + 2)
	st.generate_normals()
	var count := 8000
	var r := RandomNumberGenerator.new()
	r.seed = 11
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = st.commit()
	mm.instance_count = count
	for i in count:
		var rad := pow(r.randf(), .62) * 22.0
		var a := r.randf() * TAU
		var h := r.randf_range(.1, .3)
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(h * 1.4, h, h))
		mm.set_instance_transform(i, Transform3D(b, Vector3(cos(a) * rad, 0, sin(a) * rad)))
		mm.set_instance_custom_data(i, Color(0, r.randf(), 0, 0))
	mm.custom_aabb = AABB(Vector3(-12, -1, -12), Vector3(24, 3, 24))
	grass_mat.shader = GRASS
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = grass_mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	flat_ground.append(inst)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 18)
	layer.add_child(root)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	stats_l.add_theme_font_size_override("font_size", 12)
	stats_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .6))
	col.add_child(stats_l)
	name_l.add_theme_font_size_override("font_size", 30)
	name_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .6))
	col.add_child(name_l)
	traits_l.add_theme_font_size_override("font_size", 13)
	traits_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .6))
	traits_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(traits_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_button(row, "Új bolygó", func() -> void:
		var c := "%06x" % (randi() & 0xffffff)
		var n := randi_range(5, 20)
		retreat(func() -> void: start_planet(c, n)))
	_button(row, "Ültess", plant_new)
	tod_btn = _button(row, "Napszak", func() -> void:
		tod_i = (tod_i + 1) % TOD_PRESETS.size()
		tod_btn.text = TOD_NAMES[tod_i])
	tod_btn.text = TOD_NAMES[tod_i]
	var dbg := HBoxContainer.new()
	dbg.add_theme_constant_override("separation", 3)
	col.add_child(dbg)
	# a gombok egy tagváltozó szótárában vannak, hogy a lambdák és a mérés is elérje őket
	var btn := dbg_btn
	btn.sc = _small_button(dbg, "100%", func() -> void:
		scale_i = (scale_i + 1) % SCALES.size()
		get_viewport().scaling_3d_scale = SCALES[scale_i]
		_sync_dbg())
	btn.gr = _small_button(dbg, "fű be", func() -> void:
		planet.set_grass(not planet.grass_on)
		_sync_dbg())
	btn.ht = _small_button(dbg, "fa %d" % HI_TREES, func() -> void:
		hi_trees = 1 if hi_trees == HI_TREES else HI_TREES
		_planet_lod()
		_sync_dbg())
	btn.sk = _small_button(dbg, SKY_MODES[0], func() -> void:
		sky_i = (sky_i + 1) % SKY_MODES.size()
		space_mat.set_shader_parameter("mode", sky_i)
		_sync_dbg())
	btn.tl = _small_button(dbg, "tilt be", func() -> void:
		tilt_ok = not tilt_ok
		tilt_quad.visible = tilt_ok and garden_mode == "planet" and view == "surface"
		_sync_dbg())
	btn.aa = _small_button(dbg, "AA 2x", func() -> void:
		var vp := get_viewport()
		vp.msaa_3d = Viewport.MSAA_DISABLED if vp.msaa_3d != Viewport.MSAA_DISABLED else Viewport.MSAA_2X
		_sync_dbg())
	btn.bm = _small_button(dbg, "mérés", start_bench)
	joy.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy.draw.connect(func() -> void:
		var c := _joy_center()
		joy.draw_circle(c, JOY_R, Color(1, 1, 1, .1))
		joy.draw_arc(c, JOY_R, 0.0, TAU, 56, Color(1, 1, 1, .55), 2.0, true)
		joy.draw_circle(c + joy_knob, 27.0, Color(1, 1, 1, .62)))
	layer.add_child(joy)


func _joy_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x * .5, vp.y - 112.0)


func _joy_move(p: Vector2) -> void:
	joy_knob = (p - _joy_center()).limit_length(JOY_R)
	stick = joy_knob / JOY_R
	joy.queue_redraw()


func _sync_dbg() -> void:
	dbg_btn.sc.text = "%d%%" % roundi(get_viewport().scaling_3d_scale * 100.0)
	dbg_btn.gr.text = "fű be" if planet.grass_on else "fű ki"
	dbg_btn.ht.text = "fa %d" % hi_trees
	dbg_btn.sk.text = SKY_MODES[sky_i]
	dbg_btn.tl.text = "tilt be" if tilt_ok else "tilt ki"
	dbg_btn.aa.text = "AA ki" if get_viewport().msaa_3d == Viewport.MSAA_DISABLED else "AA 2x"


func _small_button(parent: Container, text: String, cb: Callable) -> Button:
	var b := _button(parent, text, cb)
	b.custom_minimum_size = Vector2(0, 32)
	b.add_theme_font_size_override("font_size", 10)
	return b


## Az űr ködéhez előre kiszámolt, varrat nélküli 3D zaj: az ég shadere pixelenként két mintát vesz belőle, nem számol zajt.
func _nebula_texture() -> ImageTexture3D:
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = .06
	nz.fractal_octaves = 4
	nz.seed = 7
	var n := 48
	var imgs := nz.get_seamless_image_3d(n, n, n)
	var tex := ImageTexture3D.new()
	tex.create(imgs[0].get_format(), n, n, n, false, imgs)
	return tex


func _button(parent: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = 1.0
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func retreat(after: Callable) -> void:
	if retreating:
		return
	queue.clear()
	retreating = true
	pending = after


func clear_plants() -> void:
	for p in plants:
		(p.node as Node3D).queue_free()
	plants.clear()
	trees.clear()


## Egy növény a jelenetbe, saját anyagokkal: a kertben minden fának más a színe és a növekedése.
func spawn(g: Dictionary, at: Vector3, rot: float, size_mul: float, det: float) -> Dictionary:
	var pg := PlantGen.new()
	pg.build(g, det)
	var node := Node3D.new()
	var mats: Array = []
	var wm := ShaderMaterial.new()
	wm.shader = WOOD
	var wood := MeshInstance3D.new()
	wood.mesh = pg.wood_mesh()
	wood.material_override = wm
	if det < 1.0:
		wood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(wood)
	mats.append(wm)
	if pg.leaf_p.size() > 0:
		var lm := ShaderMaterial.new()
		lm.shader = LEAF
		lm.set_shader_parameter("base", Genes.hsl(g.leaf_h, g.leaf_s, g.leaf_l))
		lm.set_shader_parameter("tip", Genes.hsl(g.leaf_tip_h, g.leaf_s * .9, g.leaf_l + .12))
		var li := MultiMeshInstance3D.new()
		li.multimesh = pg.leaves_multimesh()
		li.material_override = lm
		node.add_child(li)
		mats.append(lm)
	if pg.flo_p.size() > 0:
		var fm := ShaderMaterial.new()
		fm.shader = FLOWER
		fm.set_shader_parameter("petal", Genes.hsl(g.petal_h, g.petal_s, g.petal_l))
		fm.set_shader_parameter("petal_tip", Genes.hsl(g.petal_tip_h, g.petal_s * .9, minf(.92, g.petal_l + .12)))
		fm.set_shader_parameter("throat", Genes.hsl(g.center_h, .7, .55))
		fm.set_shader_parameter("stamen", Genes.hsl(g.center_h, .85, .5))
		var fi := MultiMeshInstance3D.new()
		fi.multimesh = pg.flowers_multimesh()
		fi.material_override = fm
		fi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(fi)
		mats.append(fm)
	var top := maxf(pg.bb_max.y, 1.6)
	var s := 5.0 / top * size_mul
	node.scale = Vector3.ONE * s
	node.position = at
	node.rotation.y = rot
	var start := grow_start
	for m in mats:
		m.set_shader_parameter("max_path", pg.max_path)
		m.set_shader_parameter("plant_h", 5.0)
		m.set_shader_parameter("grow", 1.0 - pow(1.0 - start, 1.7))
	plants_root.add_child(node)
	var rec := {"node": node, "mats": mats, "t": start, "top": top, "s": s, "pg": pg}
	_set_tree_xf(rec)
	plants.append(rec)
	return rec


## A fa saját kerete a shadereknek: a szél és a növekedés a fa "felfelé" irányához igazodik (a bolygón ferdén állnak).
func _set_tree_xf(rec: Dictionary) -> void:
	var xf: Transform3D = (rec.node as Node3D).transform
	for m in rec.mats:
		m.set_shader_parameter("tree_xf", xf)
		m.set_shader_parameter("tree_inv", xf.affine_inverse())
		m.set_shader_parameter("tree_scale", rec.s)


func apply_sky(g: Dictionary) -> Vector3:
	var sky: Dictionary = Genes.SKIES[g.sky]
	var horizon := Color(sky.horizon as String)
	sky_mat.set_shader_parameter("zenith", Color(sky.zenith as String))
	sky_mat.set_shader_parameter("horizon", horizon)
	ground_mat.set_shader_parameter("moss", Color(sky.moss as String))
	grass_mat.set_shader_parameter("moss", Color(sky.moss as String))
	env.fog_light_color = horizon
	sun.light_color = Color(sky.sun as String)
	sun.light_energy = sky.energy
	var dir: Vector3 = (sky.dir as Vector3).normalized()
	sun.look_at_from_position(dir * 60.0, Vector3.ZERO, Vector3.UP)
	return dir


func show_single(dna: Array, code: String) -> void:
	var t0 := Time.get_ticks_usec()
	clear_plants()
	_leave_planet()
	garden_mode = ""
	tilt_quad.visible = false
	joy.visible = false
	cam.fov = 38.0
	var g := Genes.from_dna(dna, code)
	var rec := spawn(g, Vector3.ZERO, 0.0, 1.0, 1.0)
	var dir := apply_sky(g)
	env.fog_depth_begin = 20.0
	env.fog_depth_end = 62.0
	sun.directional_shadow_max_distance = 42.0
	var pg: PlantGen = rec.pg
	var s: float = rec.s
	var h: float = rec.top * s
	var w := maxf(pg.bb_max.x - pg.bb_min.x, pg.bb_max.z - pg.bb_min.z) * s
	target = Vector3((pg.bb_max.x + pg.bb_min.x) * .5 * s, h * .58, (pg.bb_max.z + pg.bb_min.z) * .5 * s)
	var t := tan(deg_to_rad(cam.fov) * .5)
	var vp := get_viewport().get_visible_rect().size
	dist = maxf((h * .5 + .4) / t * 1.5, (w * .5 + .6) / (t * vp.x / vp.y) * 1.16)
	min_dist = dist * .3
	max_dist = dist * 1.5
	yaw = atan2(dir.x, dir.z) + PI + .75
	pitch = .21
	current = g
	name_l.text = _latin(g)
	traits_l.text = Genes.describe(g)
	build_ms_total = (Time.get_ticks_usec() - t0) / 1000.0


## 30 fa szembőli repüléshez. Minden fának van egyszerűsített és teljes változata, azonos vázzal, így a váltás nem látszik.
func start_garden() -> void:
	var hero: Dictionary = current
	clear_plants()
	_leave_planet()
	garden_mode = "fly"
	build_ms_total = 0.0
	var r := RandomNumberGenerator.new()
	r.seed = 5 if shot_args.size() > 0 else randi()
	var spots: Array = [Vector3.ZERO]
	var guard := 0
	while spots.size() < 30 and guard < 6000:
		guard += 1
		var a := r.randf() * TAU
		var rad := sqrt(r.randf()) * 19.0
		var p := Vector3(cos(a) * rad, 0, sin(a) * rad)
		var ok := true
		for q in spots:
			if p.distance_to(q) < 4.6:
				ok = false
				break
		if ok:
			spots.append(p)
	queue.clear()
	for i in spots.size():
		var dna: Array = hero.dna
		var code: String = hero.code
		if i > 0:
			dna = []
			for k in 6:
				dna.append(r.randi() % 14)
			while dna[3] >= 9 and dna[3] <= 11:
				dna[3] = r.randi() % 14
			code = "g%02d" % i
		queue.append({"dna": dna, "code": code, "at": spots[i], "rot": r.randf() * TAU, "size": 1.0 if i == 0 else r.randf_range(.62, 1.0)})
	apply_sky(hero)
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 125.0
	sun.directional_shadow_max_distance = 62.0
	tilt_quad.visible = true
	joy.visible = true
	joy_id = -1
	joy_knob = Vector2.ZERO
	stick = Vector2.ZERO
	joy.queue_redraw()
	cam.fov = 48.0
	cam_pos = Vector3(0, 2.3, 27)
	fly_vel = Vector3.ZERO
	yaw = PI
	pitch = -.02
	roll = 0.0
	name_l.text = "Kert"
	traits_l.text = "Húzd a kart a repüléshez, máshol húzva körülnézel."


func _update_lod() -> void:
	var order := trees.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.pos as Vector3).distance_squared_to(cam_pos) < (b.pos as Vector3).distance_squared_to(cam_pos))
	for i in order.size():
		var t: Dictionary = order[i]
		var d: float = (t.pos as Vector3).distance_to(cam_pos)
		var want: bool = i < 4 and d < (17.0 if t.high_on else 14.0)
		if want != t.high_on:
			t.high_on = want
			(t.high.node as Node3D).visible = want
			(t.low.node as Node3D).visible = not want


func _fly(delta: float) -> void:
	yaw -= stick.x * delta * 1.0
	var f := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var right := f.cross(Vector3.UP).normalized()
	var want := (f * -stick.y + right * stick.x * .35) * 6.0
	fly_vel = fly_vel.lerp(want, 1.0 - exp(-delta * 2.8))
	cam_pos += fly_vel * delta
	cam_pos.y = clampf(cam_pos.y, .9, 15.0)
	for t in trees:
		var flat := Vector3(cam_pos.x - t.pos.x, 0, cam_pos.z - t.pos.z)
		if flat.length() < 1.1 and cam_pos.y < 3.2:
			cam_pos += flat.normalized() * (1.1 - flat.length())
	var flat_out := Vector2(cam_pos.x, cam_pos.z)
	if flat_out.length() > 36.0:
		flat_out = flat_out.normalized() * 36.0
		cam_pos.x = flat_out.x
		cam_pos.z = flat_out.y
	roll = lerpf(roll, -stick.x * .13, 1.0 - exp(-delta * 3.0))
	cam.look_at_from_position(cam_pos, cam_pos + f, Vector3.UP)
	cam.rotate_object_local(Vector3.FORWARD, roll)


func _latin(g: Dictionary) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = g.gen_seed + 77
	var a := ["Aur", "Sil", "Vel", "Lun", "Cor", "Ther", "Myr", "Hel", "Nym", "Ast", "Zeph", "Ori", "Cal", "Thal"]
	var b := ["and", "ith", "ol", "an", "er", "ys", "am", "ion", "ul", "en"]
	var c := ["ia", "ella", "ora", "ina", "ara", "ea", "anthe"]
	var d := ["aurea", "rosea", "pendula", "arborea", "viridis", "ventosa", "erecta", "violacea"]
	return "%s%s%s %s" % [a[r.randi() % a.size()], b[r.randi() % b.size()], c[r.randi() % c.size()], d[r.randi() % d.size()]]


func _unhandled_input(event: InputEvent) -> void:
	if garden_mode == "planet":
		_planet_input(event)
		return
	if garden_mode == "fly":
		if event is InputEventScreenTouch:
			if event.pressed:
				if joy_id == -1 and event.position.distance_to(_joy_center()) < JOY_R * 1.7:
					joy_id = event.index
					_joy_move(event.position)
			elif event.index == joy_id:
				joy_id = -1
				joy_knob = Vector2.ZERO
				stick = Vector2.ZERO
				joy.queue_redraw()
		elif event is InputEventScreenDrag:
			if event.index == joy_id:
				_joy_move(event.position)
			else:
				yaw -= event.relative.x * .005
				pitch = clampf(pitch - event.relative.y * .004, -.75, .6)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		pinch_last = 0.0
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() == 1:
			yaw -= event.relative.x * .008
			pitch = clampf(pitch + event.relative.y * .006, -.02, .95)
			yaw_v = 0.0
		elif touches.size() == 2:
			var pts: Array = touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if pinch_last > 0.0:
				dist = clampf(dist * pinch_last / d, min_dist, max_dist)
			pinch_last = d
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = clampf(dist * .92, min_dist, max_dist)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = clampf(dist * 1.08, min_dist, max_dist)


func _process(delta: float) -> void:
	if queue.size() > 0 and not retreating:
		var t0 := Time.get_ticks_usec()
		var item: Dictionary = queue.pop_front()
		var gg := Genes.from_dna(item.dna, item.code)
		if item.has("dir"):
			_spawn_on_planet(item, gg)
		else:
			var low := spawn(gg, item.at, item.rot, item.size, .22)
			var high := spawn(gg, item.at, item.rot, item.size, 1.0)
			(high.node as Node3D).visible = false
			trees.append({"pos": item.at, "low": low, "high": high, "high_on": false})
		build_ms_total += (Time.get_ticks_usec() - t0) / 1000.0

	var rate := 0.0
	if shot_args.is_empty():
		rate = -1.8 if retreating else 1.0 / (4.5 if garden_mode != "" else 11.0)
	var all_zero := true
	for p in plants:
		var before: float = p.t
		p.t = clampf(before + delta * rate, 0.0, 1.0)
		if p.t > 0.0:
			all_zero = false
		if p.t != before:
			var u := 1.0 - pow(1.0 - float(p.t), 1.7)
			for m in p.mats:
				m.set_shader_parameter("grow", u)
	if retreating and (all_zero or plants.is_empty()):
		retreating = false
		if pending != null:
			var f: Callable = pending
			pending = null
			f.call()

	if garden_mode == "planet":
		_planet_process(delta)
	elif garden_mode == "fly":
		_fly(delta)
		lod_timer += delta
		if lod_timer >= .15:
			lod_timer = 0.0
			_update_lod()
	else:
		if touches.is_empty() and shot_args.is_empty():
			yaw += delta * .035
		var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
		cam.look_at_from_position(target + offset, target, Vector3.UP)

	stat_timer += delta
	if stat_timer >= .5:
		stat_timer = 0.0
		var rid := get_viewport().get_viewport_rid()
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
		var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid)
		var tris := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var ws := get_window().size
		var k: float = get_viewport().scaling_3d_scale
		stats_l.text = "%d fps · GPU %.1f · CPU %.1f ms · %dk · %d fa · %d×%d 3D %d×%d" % [Engine.get_frames_per_second(), gpu, cpu, tris / 1000, (trees.size() if garden_mode != "" else plants.size()), ws.x, ws.y, roundi(ws.x * k), roundi(ws.y * k)]

	if bench_on:
		_bench_process(delta)

	if shot_args.size() > 0 and queue.is_empty():
		shot_frames += 1
		if shot_frames == 1 and garden_mode == "planet" and shot_args.size() > 5:
			if shot_args[5] == "plant":
				plant_new()
			else:
				_focus(int((shot_args[5] as String).trim_prefix("focus")) if (shot_args[5] as String).length() > 5 else 0)
		if shot_frames == 1 and shot_args.size() > 5:
			var c := _joy_center()
			var t1 := InputEventScreenTouch.new()
			t1.index = 0; t1.position = c; t1.pressed = true
			Input.parse_input_event(t1)
			var t2 := InputEventScreenDrag.new()
			t2.index = 0; t2.position = c + Vector2(0, -55); t2.relative = Vector2(0, -55)
			Input.parse_input_event(t2)
		if shot_frames == (40 if shot_args.size() > 5 else 8):
			var highs := 0
			for t in trees:
				if t.high_on:
					highs += 1
			print("STATS ", stats_l.text, " | ", name_l.text, " | cam ", cam_pos, " stick ", stick, " highs ", highs)
			get_viewport().get_texture().get_image().save_png(shot_args[0])
			get_tree().quit()


# ---------------------------------------------------------------- Bolygó

func _leave_planet() -> void:
	planet.visible = false
	for n in flat_ground:
		(n as Node3D).visible = true
	env.sky.sky_material = sky_mat
	env.fog_enabled = true
	env.ambient_light_energy = 1.35
	tag.visible = false


func _build_tag() -> void:
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 40
	tag.outline_size = 12
	tag.pixel_size = .0024
	tag.width = 760.0
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.shaded = false
	tag.modulate = Color(1, 1, 1, 0)
	tag.outline_modulate = Color(.12, .08, .22, 0)
	tag.visible = false
	add_child(tag)


## Új bolygó a kódból: a növények DNS-e determinisztikus, az első az alapító.
func start_planet(code: String, count: int) -> void:
	clear_plants()
	queue.clear()
	garden_mode = "planet"
	view = "orbit"
	focus = -1
	build_ms_total = 0.0
	var r := RandomNumberGenerator.new()
	r.seed = hash(code)
	planet_dnas = []
	for i in count:
		var dna: Array = []
		for k in 6:
			dna.append(r.randi() % 14)
		planet_dnas.append(dna)
	planet.visible = true
	for n in flat_ground:
		(n as Node3D).visible = false
	planet.setup(code, planet_dnas)
	last_r = planet.radius
	var dirs: Array = []
	for i in count:
		var dir := planet.pick_spot(i, dirs)
		dirs.append(dir)
		queue.append({"dna": planet_dnas[i], "code": "%s-%d" % [code, i], "dir": dir, "rot": r.randf() * TAU, "size": r.randf_range(.5, .72)})
	env.sky.sky_material = space_mat
	env.fog_enabled = false
	sun.directional_shadow_max_distance = 60.0
	tilt_quad.visible = false
	joy.visible = false
	tag.visible = true
	cam.fov = 40.0
	orbit_dist = _fit_dist(planet.radius_target)
	if shot_args.is_empty():
		eye = Basis(orbit_q) * Vector3(0, 0, orbit_dist * 1.8)
	trans_t = 0.0
	night = -1.0
	_planet_texts()


## Távolság, ahonnan az egész bolygó a fákkal együtt kifér (álló telefonon a szélesség a szűkebb).
func _fit_dist(r: float) -> float:
	var vp := get_viewport().get_visible_rect().size
	var t := tan(deg_to_rad(cam.fov) * .5) * minf(1.0, vp.x / vp.y)
	return (r + 3.0) / t * 1.05


func _planet_texts() -> void:
	name_l.text = planet.planet_name()
	traits_l.text = planet.describe() + "\nHúzd: forgatás · csípd: közelítés · koppints egy fára"


## Új fa a bolygón: a bolygó-DNS változik, a bolygó lassan nő, a kamera odarepül a csírához.
func plant_new() -> void:
	if garden_mode != "planet" or queue.size() > 0 or retreating:
		return
	if trees.size() >= 30:
		traits_l.text = "A bolygó megtelt. Később itt születik mellette egy új kis bolygó."
		return
	var dna := Genes.random_dna()
	planet_dnas.append(dna)
	planet.add_plant(dna)
	var dirs: Array = []
	for t in trees:
		dirs.append(t.dir)
	var i := trees.size()
	queue.append({"dna": dna, "code": "%s-%d" % [planet.code, i], "dir": planet.pick_spot(i, dirs), "rot": randf() * TAU, "size": randf_range(.5, .72), "focus": true})
	_planet_texts()


func _spawn_on_planet(item: Dictionary, gg: Dictionary) -> void:
	# három részletességi szint ugyanabból a vázból: részletes (közel), egyszerűsített, távoli
	var far := spawn(gg, Vector3.ZERO, 0.0, item.size, .09)
	var low := spawn(gg, Vector3.ZERO, 0.0, item.size, .22)
	var high := spawn(gg, Vector3.ZERO, 0.0, item.size, 1.0)
	(high.node as Node3D).visible = false
	(low.node as Node3D).visible = false
	# árnyékot csak az egyszerűsített szint vet (a részletes fa helyett is, csak árnyékként): a puha árnyékon
	# nem látszik a különbség, de a részletes fát így nem kell kétszer kirajzolni; a távoli fa nem vet árnyékot
	_cast_shadow(high, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_cast_shadow(far, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_cast_shadow(low, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	var pg: PlantGen = high.pg
	var w := maxf(pg.bb_max.x - pg.bb_min.x, pg.bb_max.z - pg.bb_min.z) * float(high.s) * .5
	var t := {"dir": item.dir, "rot": item.rot, "low": low, "high": high, "far": far, "lods": [high, low, far], "lod": 2, "shown": true, "high_on": false, "front": true,
		"g": gg, "glow": Genes.glow(item.dna), "wave": -1.0, "h": 5.0 * float(item.size), "w": w}
	trees.append(t)
	_place_tree(t)
	var col := Genes.hsl(gg.petal_h, .85, .62)
	for rec in t.lods:
		for m in rec.mats:
			m.set_shader_parameter("glow_col", col)
			m.set_shader_parameter("glow_part", float(t.glow.part))
			m.set_shader_parameter("glow_amt", float(t.glow.strength) * maxf(night, 0.0))
	if item.get("focus", false):
		_focus(trees.size() - 1)


func _cast_shadow(rec: Dictionary, mode: GeometryInstance3D.ShadowCastingSetting) -> void:
	for c in (rec.node as Node3D).get_children():
		if c is GeometryInstance3D and not (c is MultiMeshInstance3D and (c as MultiMeshInstance3D).material_override.shader == FLOWER):
			(c as GeometryInstance3D).cast_shadow = mode


func _tree_frame(i: int) -> Basis:
	return Basis(Quaternion(Vector3.UP, trees[i].dir as Vector3))


func _place_tree(t: Dictionary) -> void:
	var d: Vector3 = t.dir
	var b := Basis(Quaternion(Vector3.UP, d)) * Basis(Vector3.UP, t.rot)
	var pos := planet.surface_point(d) - d * .06
	for rec in t.lods:
		(rec.node as Node3D).transform = Transform3D(b.scaled(Vector3.ONE * float(rec.s)), pos)
		_set_tree_xf(rec)


func _tree_mid(t: Dictionary) -> Vector3:
	return planet.surface_point(t.dir) + (t.dir as Vector3) * float(t.h) * .45


func _focus(i: int) -> void:
	focus = i
	view = "surface"
	trans_t = 0.0
	var t: Dictionary = trees[i]
	var vp := get_viewport().get_visible_rect().size
	var tv := tan(deg_to_rad(cam.fov) * .5)
	# a lomb a levelek miatt szélesebb, mint az ágak befoglaló doboza
	s_dist = maxf(float(t.h) * .8 / tv, float(t.w) * 1.2 / (tv * minf(1.0, vp.x / vp.y))) + 1.5
	tag.pixel_size = .0024 * s_dist / 7.0
	s_pitch = .26
	var rel := _tree_frame(i).inverse() * (eye - planet.surface_point(t.dir))
	s_yaw = atan2(rel.x, rel.z)
	t.wave = 0.0
	var up_hint := Basis(orbit_q).y
	if absf(up_hint.dot(t.dir)) > .98:
		up_hint = Basis(orbit_q).x
	orbit_q = Basis.looking_at(-(t.dir as Vector3), up_hint).get_rotation_quaternion()
	tilt_quad.visible = tilt_ok
	planet.build_patch(_patch_center(i), not shot_args.is_empty())
	planet.show_patch(true)
	_tag_text()


## A sűrű fűfolt középpontja: a fa és a kamera között, hogy a sűrű fű a képen legyen, ne a fa mögött.
func _patch_center(i: int) -> Vector3:
	var t: Dictionary = trees[i]
	var off := _tree_frame(i) * Vector3(sin(s_yaw), 0, cos(s_yaw)) * minf(s_dist * .45, 4.0)
	return (planet.surface_point(t.dir) + off).normalized()


func _unfocus() -> void:
	view = "orbit"
	focus = -1
	trans_t = 0.0
	tilt_quad.visible = false
	planet.show_patch(false)
	orbit_dist = clampf(orbit_dist, _fit_dist(planet.radius) * .45, _fit_dist(planet.radius) * 1.4)


func _tag_text() -> void:
	if focus < 0:
		return
	var t: Dictionary = trees[focus]
	var g: Dictionary = t.g
	var dna: Array = g.dna
	var gl: Dictionary = t.glow
	var light := "éjszakai fénye: titok, nézd meg este"
	if night > .5:
		if float(gl.strength) < .05:
			light = "éjjel sötét marad"
		else:
			light = "éjjel a %s %s" % [gl.part_name, "világít" if gl.part == 2 else "világítanak"]
	tag.text = "%s\n%s termet · %s levél · %s virág\n%s" % [_latin(g), g.form, Genes.LEAF[dna[2]][0], Genes.FLOWER[dna[0]][0], light]


func _zoom(f: float) -> void:
	if view == "orbit":
		orbit_dist = clampf(orbit_dist * f, _fit_dist(planet.radius) * .45, _fit_dist(planet.radius) * 1.4)
	else:
		s_dist *= f
		if s_dist > 14.0:
			_unfocus()
		s_dist = clampf(s_dist, 2.0, 14.0)


func _tap(pos: Vector2) -> void:
	var vp := get_viewport().get_visible_rect().size
	var px := vp.y * .5 / tan(deg_to_rad(cam.fov) * .5)
	var best := -1
	var best_score := 1.3
	for i in trees.size():
		var t: Dictionary = trees[i]
		if not t.front:
			continue
		var c := _tree_mid(t)
		if cam.is_position_behind(c):
			continue
		var reach := clampf(float(t.h) * .5 / maxf(cam.global_position.distance_to(c), .1) * px, 28.0, 200.0)
		var score := cam.unproject_position(c).distance_to(pos) / reach
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		if view == "surface" and best == focus:
			trees[best].wave = 0.0
		else:
			_focus(best)
	elif view == "surface":
		_unfocus()


func _planet_input(event: InputEvent) -> void:
	if bench_on:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			taps[event.index] = {"pos": event.position, "t": Time.get_ticks_msec(), "moved": false}
			spin = Vector2.ZERO
		else:
			touches.erase(event.index)
			var tp: Variant = taps.get(event.index)
			taps.erase(event.index)
			if tp != null and not tp.moved and Time.get_ticks_msec() - int(tp.t) < 400 and touches.is_empty():
				_tap(event.position)
		pinch_last = 0.0
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if taps.has(event.index) and (event.position - (taps[event.index].pos as Vector2)).length() > 12.0:
			taps[event.index].moved = true
		if touches.size() == 1:
			var rel: Vector2 = event.relative
			if view == "orbit":
				var a := rel * -.0055
				orbit_q = (orbit_q * Quaternion(Vector3.UP, a.x) * Quaternion(Vector3.RIGHT, a.y)).normalized()
				spin = spin.lerp(a * 60.0, .5)
			else:
				s_yaw -= rel.x * .008
				s_pitch = clampf(s_pitch + rel.y * .006, .04, 1.2)
		elif touches.size() == 2:
			for k in taps:
				taps[k].moved = true
			var pts: Array = touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if pinch_last > 0.0:
				_zoom(pinch_last / d)
			pinch_last = d
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(.92)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.08)


func _planet_process(delta: float) -> void:
	var snap := not shot_args.is_empty()
	trans_t += delta
	# a bolygó növekedésekor a fák a felszínen maradnak
	if absf(planet.radius - last_r) > .0001:
		last_r = planet.radius
		for t in trees:
			_place_tree(t)
	_update_tod(delta, snap)
	_planet_cam(delta, snap)
	if view == "surface" and focus >= 0 and planet.patch_job.is_empty() and not snap:
		var want := _patch_center(focus)
		if want.angle_to(planet.patch_center) * planet.radius > 2.5:
			planet.build_patch(want)
	for t in trees:
		if float(t.wave) >= 0.0:
			t.wave = float(t.wave) + delta
			if t.wave > 3.2:
				t.wave = -1.0
			for rec in t.lods:
				for m in rec.mats:
					m.set_shader_parameter("wave", t.wave)
	lod_timer += delta
	if lod_timer >= .15 or snap:
		lod_timer = 0.0
		_planet_lod()
	# lebegő névtábla a kiválasztott fa fölött
	var want := 1.0 if view == "surface" and focus >= 0 and trans_t > .5 else 0.0
	tag_alpha = want if snap else lerpf(tag_alpha, want, 1.0 - exp(-delta * (3.0 if want > 0.0 else 8.0)))
	if focus >= 0:
		var t: Dictionary = trees[focus]
		var base := planet.surface_point(t.dir)
		tag.position = base + (t.dir as Vector3) * .3 + (eye - base).normalized() * (float(t.w) * .9 + .5)
	var tc := Color(1, .97, .92).lerp(Color(.8, .95, 1.0), maxf(night, 0.0))
	tag.modulate = Color(tc.r, tc.g, tc.b, tag_alpha)
	tag.outline_modulate = Color(.12, .08, .22, tag_alpha * .55)


func _planet_cam(delta: float, snap: bool) -> void:
	var want_eye: Vector3
	var want_look: Vector3
	var want_up: Vector3
	if view == "orbit" or focus < 0:
		if touches.is_empty():
			if spin.length() < .02 and not bench_on:
				spin = spin.lerp(Vector2(.03, 0), 1.0 - exp(-delta * .5))
			orbit_q = (orbit_q * Quaternion(Vector3.UP, spin.x * delta) * Quaternion(Vector3.RIGHT, spin.y * delta)).normalized()
			spin *= exp(-delta * 2.2)
		var b := Basis(orbit_q)
		want_eye = b * Vector3(0, 0, orbit_dist)
		want_look = Vector3.ZERO
		want_up = b.y
	else:
		var t: Dictionary = trees[focus]
		var n: Vector3 = t.dir
		var target := planet.surface_point(n) + n * float(t.h) * .52
		var off := _tree_frame(focus) * (Vector3(sin(s_yaw) * cos(s_pitch), sin(s_pitch), cos(s_yaw) * cos(s_pitch)) * s_dist)
		want_eye = target + off
		var ground := planet.surface_point(want_eye.normalized()).length() + .5
		if want_eye.length() < ground:
			want_eye = want_eye.normalized() * ground
		want_look = target
		want_up = n
		if touches.is_empty() and shot_args.is_empty() and not bench_on:
			s_yaw += delta * .03
	# átmenetkor lassú, puha mozgás; utána gyorsan követi az ujjat
	var rate := 2.2 if trans_t < 2.5 else 12.0
	var k := 1.0 if snap else 1.0 - exp(-delta * rate)
	var ed := eye.normalized().slerp(want_eye.normalized(), k)
	eye = ed * lerpf(eye.length(), want_eye.length(), k)
	look = look.lerp(want_look, k)
	up_v = up_v.slerp(want_up.normalized(), k).normalized()
	cam.look_at_from_position(eye, look, up_v)
	sun.directional_shadow_max_distance = 26.0 if view == "surface" else eye.length() + planet.radius + 4.0
	(tilt_quad.material_override as ShaderMaterial).set_shader_parameter("focus", eye.distance_to(look))
	# a nap a kamerához (kint) vagy a fához (lent) igazodik, így a látható oldal mindig meg van világítva
	var el := lerpf(lerpf(.75, .32, dusk), .6, night)
	var z := lerpf(lerpf(.55, -.45, dusk), .3, night)
	var local := Vector3(-.55, el, z).normalized()
	var frame: Basis = cam.global_transform.basis if view == "orbit" or focus < 0 else _tree_frame(focus).rotated(trees[focus].dir, s_yaw)
	var wsun := (frame * local).normalized()
	sun_dir = wsun if snap else sun_dir.slerp(wsun, 1.0 - exp(-delta * 3.0)).normalized()
	sun.look_at_from_position(sun_dir * 60.0, Vector3.ZERO, Vector3.UP if absf(sun_dir.y) < .98 else Vector3.RIGHT)


## Részletességi szint: a kiválasztott fa mindig részletes; a többi közül a legközelebbiek (legfeljebb hi_trees),
## ha elég közel vannak; a közepesen távoliak egyszerűsítettek, a többiek távoli szintűek.
## A visszaváltás távolabb történik, mint a felváltás, így a határon nem villog.
func _planet_lod() -> void:
	var en := eye.normalized()
	var thr := planet.radius / maxf(eye.length(), .001) - .35
	var order: Array = []
	for i in trees.size():
		var t: Dictionary = trees[i]
		t.front = (t.dir as Vector3).dot(en) > thr
		t.d = _tree_mid(t).distance_to(eye)
		t.focused = view == "surface" and i == focus
		order.append(t)
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.focused != b.focused:
			return a.focused
		return float(a.d) < float(b.d))
	var used := 0
	for t in order:
		var limit := LOD_DIST + (LOD_HYST if int(t.lod) == 0 else 0.0)
		var hi: bool = t.focused or (t.front and used < hi_trees and (float(t.d) < limit or lod_force))
		if hi:
			used += 1
		# kívülről egyszerűsített (a bolygó peremén a fák jól látszanak); leszállva a háttér távoli szintű,
		# mert ott a tiltshift úgyis elmossa
		var mid_limit := (1e9 if view == "orbit" else s_dist + MID_EXTRA) + (LOD_HYST if int(t.lod) <= 1 else 0.0)
		var lod := 0 if hi else (1 if float(t.d) < mid_limit else 2)
		var shown: bool = t.front or t.focused
		if lod != int(t.lod) or shown != bool(t.get("shown", false)):
			t.lod = lod
			t.shown = shown
			for k in 3:
				((t.lods[k] as Dictionary).node as Node3D).visible = shown and (k == lod or (lod == 0 and k == 1))
			# részletes fánál az egyszerűsített szint csak árnyékként van jelen
			_cast_shadow(t.low, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if lod == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		t.high_on = hi


func _tod_target() -> float:
	var p: float = TOD_PRESETS[tod_i]
	if p >= 0.0:
		return p
	if shot_hour >= 0.0:
		return shot_hour
	var t := Time.get_time_dict_from_system()
	return float(t.hour) + float(t.minute) / 60.0


## Napszak: éjszaka és alkony erőssége az órából; ebből jön az ég, a fény és a növények éjszakai világítása.
func _update_tod(delta: float, snap: bool) -> void:
	var want := _tod_target()
	if tod < 0.0 or snap:
		tod = want
	else:
		tod = fposmod(tod + wrapf(want - tod, -12.0, 12.0) * (1.0 - exp(-delta * 1.2)), 24.0)
	var n := clampf(1.0 - smoothstep(4.8, 6.6, tod) + smoothstep(19.4, 21.0, tod), 0.0, 1.0)
	var du := maxf(1.0 - smoothstep(0.0, 1.6, absf(tod - 6.3)), 1.0 - smoothstep(0.0, 1.7, absf(tod - 19.2)))
	if absf(n - night) < .002 and absf(du - dusk) < .002:
		return
	var crossed := (n > .5) != (night > .5)
	night = n
	dusk = du
	space_mat.set_shader_parameter("night", night)
	space_mat.set_shader_parameter("dusk", dusk)
	planet.set_night(night)
	for t in trees:
		for rec in t.lods:
			for m in rec.mats:
				m.set_shader_parameter("glow_amt", float(t.glow.strength) * night)
	var c := Color(1.0, .95, .88).lerp(Color(1.0, .72, .64), dusk).lerp(Color(.55, .66, 1.0), night)
	sun.light_color = c
	sun.light_energy = lerpf(lerpf(1.7, 1.3, dusk), 1.0, night)
	env.ambient_light_energy = lerpf(1.2, 1.6, night)
	if crossed:
		_tag_text()


# ---------------------------------------------------------------- Mérés

## Egységes alapállapot (azonos bolygó, nappal), aztán lépésenként egy-egy beállítás, kint és leszállva.
func start_bench() -> void:
	if bench_on:
		return
	bench_on = true
	bench_rows.clear()
	bench_steps = LOAD_STEPS
	var q := str(JavaScriptBridge.eval("location.search", true)) if OS.has_feature("web") else ""
	if q.contains("beall"):
		bench_steps = BENCH_STEPS
	# rövid próba a fejlesztéshez (?meres&gyors): fű ×2 lent, aztán 30 fa kint (bolygó-újraépítéssel)
	if q.contains("gyors") or (bench_cli and OS.get_cmdline_user_args().has("--gyors")):
		bench_steps = [LOAD_STEPS[3], LOAD_STEPS[7]]
	bench_tod = tod_i
	tod_i = 2
	tod_btn.text = TOD_NAMES[tod_i]
	planet.grass_mult = 1.0
	grow_start = 1.0
	start_planet("bolygo01", 14)
	grow_start = 0.0
	bench_i = -1
	bench_t = 0.0
	bench_last = 0
	bench_wait = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("var o=document.getElementById('mag-bench'); if(o) o.remove();", true)


func _bench_cfg(cfg: Dictionary) -> void:
	get_viewport().scaling_3d_scale = cfg.get("scale", base_scale)
	planet.set_grass(cfg.get("grass", true))
	hi_trees = cfg.get("hi", HI_TREES)
	lod_force = cfg.get("force", false)
	planet.set_grass_mult(cfg.get("gmul", 1.0))
	sun.shadow_enabled = cfg.get("shadow", true)
	env.glow_enabled = cfg.get("glow", true)
	sky_i = cfg.get("sky", 0)
	space_mat.set_shader_parameter("mode", sky_i)
	tilt_ok = cfg.get("tilt", true)
	tilt_quad.visible = tilt_ok and view == "surface"
	get_viewport().msaa_3d = Viewport.MSAA_2X if cfg.get("aa", true) else Viewport.MSAA_DISABLED
	_planet_lod()
	_sync_dbg()


func _bench_next() -> void:
	bench_i += 1
	bench_t = 0.0
	bench_dt.clear()
	bench_cpu = 0.0
	if bench_i >= bench_steps.size():
		_bench_done()
		return
	var step: Array = bench_steps[bench_i]
	var cfg: Dictionary = step[2]
	var want_trees: int = cfg.get("trees", 14)
	if want_trees != trees.size() or planet.code != "bolygo01":
		# más faszám: a bolygó újraépül (a fű sűrűsége előre beállítva, hogy ne épüljön kétszer)
		planet.grass_mult = cfg.get("gmul", 1.0)
		grow_start = 1.0
		start_planet("bolygo01", want_trees)
		grow_start = 0.0
		bench_wait = true
		return
	_bench_enter(step)


func _bench_enter(step: Array) -> void:
	var want_view: String = "surface" if step[0] == "lent" else "orbit"
	var gm_before := planet.grass_mult
	if want_view != view or (want_view == "surface" and focus != 0):
		if want_view == "surface":
			_focus(0)
		else:
			_unfocus()
		# nézetváltáskor tovább várunk: a kamera odarepül, a fűfolt felépül
		bench_t = -2.5
	_bench_cfg(step[2])
	if not is_equal_approx(gm_before, planet.grass_mult):
		bench_t = minf(bench_t, -1.5)


## A képkockaidőt valódi órával mérjük: a motor a delta-t 133 ms-nál levágja, lassú gépen az torzítana.
func _bench_process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var delta := (now - bench_last) / 1000000.0 if bench_last > 0 else 0.0
	bench_last = now
	if bench_i < 0:
		# a bolygó összes fája elkészült, a kamera beért
		if queue.is_empty():
			bench_t += delta
			if bench_t > 2.0:
				_bench_next()
		return
	var step: Array = bench_steps[bench_i]
	if bench_wait:
		name_l.text = "Mérés %d/%d" % [bench_i + 1, bench_steps.size()]
		traits_l.text = "a bolygó újraépül (%d fa)…" % (step[2] as Dictionary).get("trees", 14)
		if queue.is_empty():
			bench_wait = false
			_bench_enter(step)
			bench_t = -2.5
		return
	bench_t += delta
	name_l.text = "Mérés %d/%d" % [bench_i + 1, bench_steps.size()]
	traits_l.text = "%s · %s – kérlek, ne nyúlj a képernyőhöz (kb. %d mp)" % [step[0], step[1], roundi((bench_steps.size() - bench_i) * (BENCH_SETTLE + BENCH_MEASURE))]
	if bench_t < BENCH_SETTLE:
		return
	bench_dt.append(delta)
	bench_cpu += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
	bench_tris = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	if bench_t >= BENCH_SETTLE + BENCH_MEASURE:
		var n := bench_dt.size()
		var total := 0.0
		for d in bench_dt:
			total += d
		var sorted := bench_dt.duplicate()
		sorted.sort()
		bench_rows.append({"view": step[0], "name": step[1], "fps": n / maxf(total, .001), "avg": total / maxi(n, 1) * 1000.0,
			"p95": sorted[mini(n - 1, int(n * .95))] * 1000.0, "cpu": bench_cpu / maxi(n, 1), "tris": bench_tris})
		_bench_next()


func _bench_info() -> String:
	var ws := get_window().size
	var info := "%s · %s · %s · ablak %d×%d · skála %.1f" % [OS.get_name(), RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), ws.x, ws.y, DisplayServer.screen_get_scale()]
	if OS.has_feature("web"):
		var build := str(JavaScriptBridge.eval("(function(){try{return GODOT_CONFIG.executable}catch(e){return ''}})()", true))
		var ua := str(JavaScriptBridge.eval("navigator.userAgent", true))
		info = "build %s · %s\n%s" % [build, info, ua]
	return info


func _bench_done() -> void:
	bench_on = false
	if trees.size() != 14:
		planet.grass_mult = 1.0
		start_planet("bolygo01", 14)
	_bench_cfg({})
	tod_i = bench_tod
	tod_btn.text = TOD_NAMES[tod_i]
	_unfocus()
	_planet_texts()
	var info := _bench_info()
	var txt := "Mag mérés · alap: %d%% felbontás, %d részletes fa\n%s\n\n" % [roundi(base_scale * 100.0), HI_TREES, info]
	var md := "Automatikus mérés a játékból. Alap: %d%% belső felbontás, %d részletes fa, fű ×1 = a mostani alapsűrűség.\n\n%s\n\n| nézet | beállítás | fps | átlag ms | 95%% ms | CPU ms | háromszög |\n|---|---|---|---|---|---|---|\n" % [roundi(base_scale * 100.0), HI_TREES, info.replace("\n", "  \n")]
	for r in bench_rows:
		txt += "%-4s %-24s %5.1f fps  %5.1f ms  95%%: %5.1f  CPU %4.1f  %dk\n" % [r.view, r.name, r.fps, r.avg, r.p95, r.cpu, r.tris / 1000]
		md += "| %s | %s | %.1f | %.1f | %.1f | %.1f | %dk |\n" % [r.view, r.name, r.fps, r.avg, r.p95, r.cpu, r.tris / 1000]
	print("BENCH\n", txt)
	traits_l.text = "Mérés kész."
	if bench_cli:
		get_tree().quit()
		return
	if OS.has_feature("web"):
		_bench_overlay(txt, md)
	else:
		DisplayServer.clipboard_set(txt)
		traits_l.text = "Mérés kész, az eredmény a vágólapon."


## Weben valódi HTML-réteg: a link és a másolás gomb így a böngésző saját érintésére fut (iOS-en ez kell hozzá).
func _bench_overlay(txt: String, md: String) -> void:
	var title := "Mérés %s" % Time.get_datetime_string_from_system(false, true)
	var js := """(function(txt, md, title){
var old=document.getElementById('mag-bench'); if(old) old.remove();
var d=document.createElement('div'); d.id='mag-bench';
d.style.cssText='position:fixed;left:10px;right:10px;top:10px;bottom:10px;z-index:9999;background:rgba(24,18,44,.94);color:#fff;font:14px/1.4 -apple-system,system-ui,sans-serif;padding:14px;border-radius:16px;display:flex;flex-direction:column;gap:10px;box-sizing:border-box';
var h=document.createElement('div'); h.textContent='Mérés kész – küldd el, és megnézem!'; h.style.cssText='font-weight:600;font-size:16px';
var pre=document.createElement('pre'); pre.textContent=txt; pre.style.cssText='white-space:pre-wrap;margin:0;font:10.5px/1.35 ui-monospace,Menlo,monospace;flex:1;overflow:auto;background:rgba(255,255,255,.06);padding:8px;border-radius:10px';
function btn(t){var b=document.createElement('a'); b.textContent=t; b.style.cssText='display:block;text-align:center;padding:12px;border-radius:12px;background:#7a6cf0;color:#fff;text-decoration:none;font-weight:600'; return b;}
var a=btn('Küldés GitHubra (új issue)'); a.href='https://github.com/csathoPeter/mag-poc/issues/new?title='+encodeURIComponent(title)+'&body='+encodeURIComponent(md); a.target='_blank'; a.rel='noopener';
var c=btn('Másolás'); c.href='#'; c.style.background='#4b4570'; c.onclick=function(e){e.preventDefault(); navigator.clipboard.writeText(txt).then(function(){c.textContent='Kimásolva ✓';},function(){c.textContent='Nem sikerült, jelöld ki a szöveget';});};
var x=btn('Bezár'); x.href='#'; x.style.background='transparent'; x.style.border='1px solid rgba(255,255,255,.3)'; x.onclick=function(e){e.preventDefault(); d.remove();};
d.appendChild(h); d.appendChild(pre); d.appendChild(a); d.appendChild(c); d.appendChild(x); document.body.appendChild(d);
})(%s, %s, %s);""" % [JSON.stringify(txt), JSON.stringify(md), JSON.stringify(title)]
	JavaScriptBridge.eval(js, true)
