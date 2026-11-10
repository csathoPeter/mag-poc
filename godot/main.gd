extends Node3D
## Godot PoC: ugyanaz a DNS-ből épülő növény, valódi árnyékkal, ragyogással és mérőszámokkal.

const WOOD := preload("res://shaders/wood.gdshader")
const LEAF := preload("res://shaders/leaf.gdshader")
const FLOWER := preload("res://shaders/flower.gdshader")
const GRASS := preload("res://shaders/grass.gdshader")
const GROUND := preload("res://shaders/ground.gdshader")
const SKY := preload("res://shaders/sky.gdshader")
const TILT := preload("res://shaders/tiltshift.gdshader")

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
var previous: Dictionary = {}

var board := BoardUI.new()
var helix := Helix.new()
var hold_grow := false
var cross_btn: Button
var mode_btn: Button

var name_l := Label.new()
var traits_l := Label.new()
var stats_l := Label.new()
var gen_ms := 0.0
var stat_timer := 0.0
var shot_args: Array = []
var shot_frames := 0


func _ready() -> void:
	# A "≡" (G≡C) nincs benne a Godot alapfontjában, weben pedig nincs rendszerfont, ami pótolná.
	var font := ThemeDB.fallback_font
	font.fallbacks = font.fallbacks + [preload("res://fonts/symbols.ttf")]
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	add_child(plants_root)
	_build_world()
	_build_grass()
	_build_ui()
	add_child(helix)
	helix.landed.connect(func() -> void: hold_grow = false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_args = a.substr(7).split(",")
	if shot_args.size() > 0:
		var dna: Array = []
		for s in (shot_args[1] as String).split("-"):
			dna.append(int(s))
		show_single(dna, shot_args[2])
		if shot_args.has("fly"):
			start_garden()
		if shot_args.has("cross"):
			previous = Genes.from_dna([7, 2, 11, 0, 3, 9], "szulo2")
			open_board(true)
		elif shot_args.has("board"):
			open_board(false)
		if shot_args.has("solve"):
			board.solve()
	else:
		show_single([2, 5, 1, 3, 0, 5], "kert01")
		start_garden()


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
	_button(row, "Új mag", func() -> void: open_board(false)).add_theme_stylebox_override("normal", _seed_box())
	cross_btn = _button(row, "Keresztezés", func() -> void: open_board(true))
	cross_btn.disabled = true
	mode_btn = _button(row, "Kert", func() -> void:
		if garden_mode == "fly":
			retreat(func() -> void: show_single(current.dna, current.code, current.get("parents", [])))
		else:
			retreat(start_garden))
	joy.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy.draw.connect(func() -> void:
		var c := _joy_center()
		joy.draw_circle(c, JOY_R, Color(1, 1, 1, .1))
		joy.draw_arc(c, JOY_R, 0.0, TAU, 56, Color(1, 1, 1, .55), 2.0, true)
		joy.draw_circle(c + joy_knob, 27.0, Color(1, 1, 1, .62)))
	layer.add_child(joy)
	board.visible = false
	layer.add_child(board)
	board.cancelled.connect(func() -> void: board.visible = false)
	board.finished.connect(_on_board_finished)


func _seed_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BoardUI.SEED, .28)
	sb.border_color = BoardUI.SEED
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	return sb


## Új mag: DNS-tábla. Keresztezésnél az előző és a mostani növény a két szülő.
func open_board(cross: bool) -> void:
	if retreating or helix.running:
		return
	if cross and previous.is_empty():
		return
	board.open([previous.dna, current.dna] if cross else [])


## A kész táblából új növény lesz: a tábla kettős spirállá csavarodik, maggá húzódik, a földbe hull, és kinő.
## rect: a sarokmezők középpontjai közti téglalap, képernyő-koordinátában.
func _on_board_finished(dna: Array, grid: Array, rect: Rect2) -> void:
	var parents: Array = []
	if board.parents.size() == 2:
		parents = [previous.code, current.code]
	if not current.is_empty():
		previous = current
	board.visible = false
	hold_grow = true
	show_single(dna, Genes.new_code(), parents)
	cross_btn.disabled = false
	# A tábla helyét a kamera síkjába vetítjük, hogy a spirál pontosan onnan induljon.
	var depth := (target - cam.global_position).dot(-cam.global_basis.z)
	var c := cam.project_position(rect.get_center(), depth)
	var step := rect.size.x / (DnaBoard.N - 1)
	var cell := cam.project_position(rect.get_center() + Vector2(step, 0), depth).distance_to(c)
	helix.start(grid, c, cell, cam.global_basis, target, Vector3(0, .03, 0))
	if shot_args.size() > 0:
		# Képernyőképnél: "helix1.3" a spirált az adott pillanatban mutatja, különben átugorjuk.
		var at := helix.DURATION
		for a in shot_args:
			if (a as String).begins_with("helix"):
				at = float((a as String).substr(5))
		if at >= helix.DURATION:
			helix.advance(at)
		else:
			helix.running = false
			helix.pose_at(at)


func _joy_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x * .5, vp.y - 112.0)


func _joy_move(p: Vector2) -> void:
	joy_knob = (p - _joy_center()).limit_length(JOY_R)
	stick = joy_knob / JOY_R
	joy.queue_redraw()


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
	var start := float(shot_args[3]) if shot_args.size() > 3 else 0.0
	for m in mats:
		m.set_shader_parameter("max_path", pg.max_path)
		m.set_shader_parameter("plant_h", 5.0)
		m.set_shader_parameter("grow", 1.0 - pow(1.0 - start, 1.7))
	plants_root.add_child(node)
	var rec := {"node": node, "mats": mats, "t": start, "top": top, "s": s, "pg": pg}
	plants.append(rec)
	return rec


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


func show_single(dna: Array, code: String, parents: Array = []) -> void:
	var t0 := Time.get_ticks_usec()
	clear_plants()
	queue.clear()
	garden_mode = ""
	tilt_quad.visible = false
	joy.visible = false
	cam.fov = 38.0
	var g := Genes.from_dna(dna, code)
	if parents.size() == 2:
		g.parents = parents
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
	_orbit_cam()
	current = g
	name_l.text = _latin(g)
	traits_l.text = Genes.describe(g)
	if mode_btn:
		mode_btn.text = "Kert"
	build_ms_total = (Time.get_ticks_usec() - t0) / 1000.0


## 30 fa szembőli repüléshez. Minden fának van egyszerűsített és teljes változata, azonos vázzal, így a váltás nem látszik.
func start_garden() -> void:
	var hero: Dictionary = current
	clear_plants()
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
	mode_btn.text = "Közelről"
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


func _orbit_cam() -> void:
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.look_at_from_position(target + offset, target, Vector3.UP)


func _latin(g: Dictionary) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = g.gen_seed + 77
	var a := ["Aur", "Sil", "Vel", "Lun", "Cor", "Ther", "Myr", "Hel", "Nym", "Ast", "Zeph", "Ori", "Cal", "Thal"]
	var b := ["and", "ith", "ol", "an", "er", "ys", "am", "ion", "ul", "en"]
	var c := ["ia", "ella", "ora", "ina", "ara", "ea", "anthe"]
	var d := ["aurea", "rosea", "pendula", "arborea", "viridis", "ventosa", "erecta", "violacea"]
	var genus := "%s%s%s" % [a[r.randi() % a.size()], b[r.randi() % b.size()], c[r.randi() % c.size()]]
	return genus + " " + ("hybrida" if g.has("parents") else d[r.randi() % d.size()])


func _unhandled_input(event: InputEvent) -> void:
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
		var low := spawn(gg, item.at, item.rot, item.size, .22)
		var high := spawn(gg, item.at, item.rot, item.size, 1.0)
		(high.node as Node3D).visible = false
		trees.append({"pos": item.at, "low": low, "high": high, "high_on": false})
		build_ms_total += (Time.get_ticks_usec() - t0) / 1000.0

	var rate := 0.0
	if shot_args.is_empty():
		rate = -1.8 if retreating else 1.0 / (4.5 if garden_mode != "" else 11.0)
	if hold_grow:
		rate = 0.0
	helix.advance(delta if shot_args.is_empty() else 0.0)
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

	if garden_mode == "fly":
		_fly(delta)
		lod_timer += delta
		if lod_timer >= .15:
			lod_timer = 0.0
			_update_lod()
	else:
		if touches.is_empty() and shot_args.is_empty() and not hold_grow and not board.visible:
			yaw += delta * .035
		_orbit_cam()

	stat_timer += delta
	if stat_timer >= .5:
		stat_timer = 0.0
		var rid := get_viewport().get_viewport_rid()
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
		var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid)
		var tris := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		stats_l.text = "%d fps · GPU %.1f · CPU %.1f ms · %dk · %d fa · gen %d ms" % [Engine.get_frames_per_second(), gpu, cpu, tris / 1000, (trees.size() if garden_mode != "" else plants.size()), build_ms_total]

	if shot_args.size() > 0 and queue.is_empty():
		shot_frames += 1
		if shot_frames == 1 and shot_args.has("go"):
			var c := _joy_center()
			var t1 := InputEventScreenTouch.new()
			t1.index = 0; t1.position = c; t1.pressed = true
			Input.parse_input_event(t1)
			var t2 := InputEventScreenDrag.new()
			t2.index = 0; t2.position = c + Vector2(0, -55); t2.relative = Vector2(0, -55)
			Input.parse_input_event(t2)
		if shot_frames == (40 if shot_args.has("go") else 8):
			var highs := 0
			for t in trees:
				if t.high_on:
					highs += 1
			print("STATS ", stats_l.text, " | ", name_l.text, " | cam ", cam_pos, " stick ", stick, " highs ", highs)
			get_viewport().get_texture().get_image().save_png(shot_args[0])
			get_tree().quit()
