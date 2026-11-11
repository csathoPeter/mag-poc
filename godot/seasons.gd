class_name Seasons
extends Node3D
## Évszakok (M11): a valódi dátum (+ a teszt-eltolás, GameState.today()) szerint, északi féltekén, finom hangulat.
## Nem büntet és nem változtat a játékon: csak a színek, a lomb sűrűsége és néhány részecske.
##  - A súlyok (tavasz, nyár, ősz, tél; összegük 1) globális shader-uniformban: `season` (shaders/season.gdshaderinc).
##    A határok körül (±15 nap) napról napra úsznak át; napváltáskor a képen is lassan.
##    tavasz: világosabb, üdébb lomb, nagyobb virágok, szálló szirmok, sok pollen; nyár: a semleges, telt kép;
##    ősz: a lomb meleg árnyalat felé húz (levelenként arany, narancs, rozsdás), néhány levél lehullott, hulló levelek;
##    tél: ritkább, deres lomb, hó az ágak tetején, deres-csillogó talaj, lassan szállingózó hó, kevesebb virág.
##  - A leszállt nézetben a kiválasztott fa körül: évszakos részecskék (season_fx.gdshader) és lebegő porszemek
##    (motes.gdshader: nappal pollen, éjjel szentjánosbogár-szerű fények). Mindkettő egyetlen, egyszer feltöltött
##    MultiMesh: a mozgás a shaderben, időből születik, képkockánként csak a csomópont helye frissül (ha kell).
##  - Teszt: `?evszak=tavasz|nyar|osz|tel` (vagy `--evszak=…`; `auto` = a dátum), az apró gombsor „…” sorában
##    „évszak” (körbe: dátum szerint → tavasz → nyár → ősz → tél). A --shot=…,planet,… és a --bench alapból nyár
##    (semleges, összehasonlítható képek), a mentésből induló (state) lövés a dátumot követi.

const FX := preload("res://shaders/season_fx.gdshader")
const MOTES := preload("res://shaders/motes.gdshader")
const NAMES := ["tavasz", "nyár", "ősz", "tél"]
const KEYS := ["tavasz", "nyar", "osz", "tel"]
## Az évszakok kezdete (az év napja, 0 = jan. 1.): tavasz márc. 5., nyár jún. 1., ősz szept. 10., tél dec. 5.
const STARTS := [63, 151, 252, 338]
const BLEND := 15.0
const FX_N := 72
const MOTE_N := 30

## -1: a dátum szerint; 0–3: rögzített évszak (URL-paraméter, debug-gomb)
static var forced := -1

var host: Node
## semleges (nyár), ha nincs rögzítve: a --shot=…,planet és a --bench képei így nem függnek a dátumtól
var neutral := false
var weights := Vector4(0, 1, 0, 0)
var _target := Vector4(0, 1, 0, 0)
var _day := -99999
var _forced_seen := -2
var _fx := MultiMeshInstance3D.new()
var _motes := MultiMeshInstance3D.new()
var _fx_mat := ShaderMaterial.new()
var _mote_mat := ShaderMaterial.new()
var _anchor_key := ""


## A súlyok egy adott napra (GameState napszám: a Unix-epoch óta eltelt napok).
static func weights_for(day: int) -> Vector4:
	if forced >= 0:
		var w := Vector4.ZERO
		w[forced] = 1.0
		return w
	var d := Time.get_datetime_dict_from_unix_time(day * 86400)
	var cum := [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	var doy := float(cum[int(d.month) - 1] + int(d.day) - 1)
	var w := Vector4.ZERO
	var sum := 0.0
	for i in 4:
		var start := float(STARTS[i])
		var length := fposmod(float(STARTS[(i + 1) % 4]) - start, 365.0)
		# az évszak kezdetétől mért nap, körbeérve (a tél átnyúlik az év végén)
		var x := fposmod(doy - start + BLEND, 365.0) - BLEND
		var v := smoothstep(-BLEND, BLEND, x) * (1.0 - smoothstep(length - BLEND, length + BLEND, x))
		w[i] = v
		sum += v
	return w / maxf(sum, .001)


## A domináns évszak neve (a kis állapotsorhoz).
static func name_of(w: Vector4) -> String:
	var best := 0
	for i in 4:
		if w[i] > w[best]:
			best = i
	return NAMES[best]


## Az URL-ből / parancssorból: tavasz, nyar (nyár), osz (ősz), tel (tél), auto.
static func parse(v: String) -> int:
	var s := v.uri_decode().to_lower().replace("á", "a").replace("ő", "o").replace("é", "e").replace("ö", "o")
	for i in 4:
		if s.begins_with(KEYS[i]):
			return i
	return -1


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 4417
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = FX_N
	# a fajta-választó szám egyenletesen, keverve: így a látható részecskék száma az évszak súlyával arányos
	for i in FX_N:
		mm.set_instance_transform(i, Transform3D())
		mm.set_instance_custom_data(i, Color(r.randf(), r.randf(), fposmod(i * .618034, 1.0), 0))
	mm.custom_aabb = AABB(Vector3(-12, -6, -12), Vector3(24, 24, 24))
	_fx.multimesh = mm
	_fx_mat.shader = FX
	_fx.material_override = _fx_mat
	_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fx)
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	var m2 := MultiMesh.new()
	m2.transform_format = MultiMesh.TRANSFORM_3D
	m2.use_custom_data = true
	m2.mesh = qm
	m2.instance_count = MOTE_N
	for i in MOTE_N:
		# a lomb körül, a fa magasságához mérten (anchor() méretezi a csomópontot)
		var a := r.randf() * TAU
		var rr := sqrt(r.randf()) * 1.1
		m2.set_instance_transform(i, Transform3D(Basis(), Vector3(cos(a) * rr, r.randf_range(.08, 1.05), sin(a) * rr)))
		m2.set_instance_custom_data(i, Color(r.randf(), r.randf(), 0, 0))
	m2.custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	_motes.multimesh = m2
	_mote_mat.shader = MOTES
	_mote_mat.set_shader_parameter("near", 1.0)
	_motes.material_override = _mote_mat
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_motes)
	visible = false
	_update(true)


func _process(delta: float) -> void:
	_update(false)
	var k := 1.0 - exp(-delta * .8)
	if not weights.is_equal_approx(_target):
		weights = weights.lerp(_target, k) if (weights - _target).length() > .002 else _target
		RenderingServer.global_shader_parameter_set("season", weights)
	_follow()


## A cél-súlyok a mai napból (napváltáskor, a rögzítés változásakor); snap: azonnal (induláskor, képernyőképnél).
func _update(snap: bool) -> void:
	var day := GameState.today()
	if day == _day and forced == _forced_seen:
		return
	_day = day
	_forced_seen = forced
	_target = Vector4(0, 1, 0, 0) if neutral and forced < 0 else weights_for(day)
	if snap or not is_inside_tree() or (host != null and not (host.shot_args as Array).is_empty()):
		weights = _target
		RenderingServer.global_shader_parameter_set("season", weights)
	print_verbose("SEASON ", name_of(_target), " ", _target)


## Képernyőképnél / induláskor: a súlyok azonnal a helyükre.
func snap() -> void:
	_day = -99999
	_update(true)


## Debug-gomb: dátum szerint → tavasz → nyár → ősz → tél → dátum szerint.
func cycle() -> void:
	forced = forced + 1 if forced < 3 else -1
	_update(false)


## Rövid felirat az állapotsorba (pl. „ősz” vagy „tél (rögzítve)”).
func label() -> String:
	_update(false)
	return name_of(_target) + (" (rögzítve)" if forced >= 0 else "")


## A leszállt nézetben a kiválasztott fához igazodik (a fa töve, a „felfelé” iránya, a mérete).
func _follow() -> void:
	if host == null:
		return
	var on: bool = host.garden_mode == "planet" and host.view == "surface" and int(host.focus) >= 0 and int(host.focus) < (host.trees as Array).size()
	visible = on
	if not on:
		_anchor_key = ""
		return
	var t: Dictionary = host.trees[int(host.focus)]
	var planet: Planet = host.planet
	var key := "%s|%.3f|%s" % [str(t.dir), planet.radius, str(t.get("sid", ""))]
	if key != _anchor_key:
		_anchor_key = key
		var d: Vector3 = t.dir
		var h := maxf(float(t.h), .5)
		var rec: Dictionary = t.high
		var g: Dictionary = (rec.pg as PlantGen).g
		transform = Transform3D(Basis(Quaternion(Vector3.UP, d)), planet.surface_point(d))
		_fx_mat.set_shader_parameter("tree_h", h)
		_fx_mat.set_shader_parameter("crown_r", h * .5)
		_fx_mat.set_shader_parameter("planet_r", planet.radius)
		_fx_mat.set_shader_parameter("leaf_col", Genes.hsl(g.leaf_h, g.leaf_s, g.leaf_l))
		_fx_mat.set_shader_parameter("petal_col", Genes.hsl(g.petal_h, g.petal_s, g.petal_l))
		_motes.scale = Vector3.ONE * h
		_mote_mat.set_shader_parameter("glow_col", Genes.hsl(g.petal_h, .75, .7))
		# a pollen az évszakkal: tavasszal és nyáron sok, ősszel kevesebb, télen alig (éjjel a fények maradnak)
	var w := weights
	_mote_mat.set_shader_parameter("amount", clampf(w.x * 1.0 + w.y * .85 + w.z * .5 + w.w * .2, 0.0, 1.0))


func set_night(n: float) -> void:
	_fx_mat.set_shader_parameter("night", n)
	_mote_mat.set_shader_parameter("night", n)
