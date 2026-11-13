class_name Clouds
extends MultiMeshInstance3D
## Festett gomolyfelhők (2026. 11. 13.; Péter: a zajból vágott felhő márványos lett, „igazi gomolyfelhők” kellenek).
## A Nano Banana Pro festette 8 felhő (tools/prep_clouds.py → textures/felhok.png) kamera felé forduló négyszögeken,
## determinisztikusan a bolygókódból (leszállva a fa kódjából is), napszak szerint színezve (shaders/cloud.gdshader).
## Két elrendezés:
##  - kívülről (bolygó-nézet): ORBIT_N kisebb felhő a bolygó körüli távoli gömbhéjon (a sugár SHELL-szerese), így mindig a
##    bolygó mögött úsznak, lassan sodródva a szél tengelye körül;
##  - leszállva: LAND_N felhő egy sávban a fa helyi látóhatára fölött (5–40°), körben minden irányban – a 40°-os álló
##    képbe a gömbhéjról csak véletlenül jutott felhő.
## Váltáskor (leszállás, fa- vagy bolygócsere) a felhők elhalványulnak, átrendeződnek, és újra előtűnnek.
## Láthatóság: bolygó-módban, festett stílusban; a szomszéd-bolygók / átfogó nézet és a kozmosz felé elhalványul.

const SHADER := preload("res://shaders/cloud.gdshader")
const ATLAS := preload("res://textures/felhok.png")
const ORBIT_N := 120
const LAND_N := 26
## a gömbhéj sugara a bolygó sugarában (a lencse 80 egységen túl alig mos: lens.gdshader sky_blur)
const SHELL := 14.0
## sodródás (radián / mp) a szél tengelye körül (planet.gd PAINT_AXIS)
const DRIFT := .004
## áttűnés (mp) elrendezés-váltáskor
const FADE := .6

var host: Node
## az elrendezés kulcsa (bolygókód, sugár, leszállt fa iránya), és a következő, amire váltani kell
var _key := ""
var _want := ""
var _fade := 0.0
var _mat := ShaderMaterial.new()
var _angle := 0.0


func _ready() -> void:
	_mat.shader = SHADER
	_mat.set_shader_parameter("atlas", ATLAS)
	# a lencse (main.gd tilt_quad) után: az a képernyő átlátszó rész előtti képét rajzolja vissza, ami alá kerülnének
	# (mint a kozmosz ködei, cosmos.gd 5–6); a mélységteszt marad, a bolygó és a fák eltakarják
	_mat.render_priority = 4
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a héj nagy: ne vágja ki a kamera
	extra_cull_margin = 16384.0
	visible = false


func _new_mm(n: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = n
	return mm


## Kívülről: a bolygó körüli gömbhéj (a csomópont a bolygó közepén áll, lassan forog).
func _build_orbit(code: String, rad: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(code + "felhő")
	var mm := _new_mm(ORBIT_N)
	var shell := rad * SHELL
	for i in ORBIT_N:
		var z := r.randf_range(-1.0, 1.0)
		var a := r.randf() * TAU
		var dir := Vector3(sqrt(1.0 - z * z) * cos(a), z, sqrt(1.0 - z * z) * sin(a))
		mm.set_instance_transform(i, Transform3D(Basis(), dir * shell * r.randf_range(.9, 1.1)))
		mm.set_instance_custom_data(i, Color(float(r.randi() % 8), shell * r.randf_range(.12, .24), r.randf_range(.92, 1.04), 0))
	multimesh = mm


## Leszállva: sáv a fa helyi látóhatára fölött (a csomópont a fa tövénél áll, nem forog).
func _build_land(code: String, rad: float, up: Vector3) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(code + "felhő-lent")
	var mm := _new_mm(LAND_N)
	var e1 := up.cross(Vector3.UP if absf(up.y) < .99 else Vector3.RIGHT).normalized()
	var e2 := up.cross(e1)
	var dist := rad * SHELL * .8
	for i in LAND_N:
		var az := (float(i) + r.randf_range(-.35, .35)) / float(LAND_N) * TAU
		var el := deg_to_rad(lerpf(5.0, 40.0, pow(r.randf(), 1.4)))
		var h := e1 * cos(az) + e2 * sin(az)
		var dir := (h * cos(el) + up * sin(el)).normalized()
		mm.set_instance_transform(i, Transform3D(Basis(), dir * dist * r.randf_range(.85, 1.15)))
		mm.set_instance_custom_data(i, Color(float(r.randi() % 8), dist * r.randf_range(.16, .3), r.randf_range(.92, 1.04), 0))
	multimesh = mm


func _process(delta: float) -> void:
	if host == null or host.planet == null:
		return
	var p: Planet = host.planet
	var on: bool = host.garden_mode == "planet" and host.paint_on and host.soft_on
	var v := 1.0
	var landed: bool = host.view == "surface" and int(host.focus) >= 0 and int(host.focus) < (host.trees as Array).size()
	if host.view == "orbit":
		v = smoothstep(-.6, -.05, float(host.orbit_zoom))
	v *= 1.0 - float(host.stars.cosmos())
	visible = on and v > .001
	if not visible:
		_key = ""
		return
	var tdir := Vector3.ZERO
	if landed:
		tdir = (host.trees[host.focus].dir as Vector3).normalized()
	_want = "%s|%.1f|%s" % [p.code, p.radius, str(tdir.snapped(Vector3.ONE * .01)) if landed else "kint"]
	if _want != _key:
		# elhalványul, aztán átrendeződik (az első építéskor azonnal)
		_fade = maxf(_fade - delta / FADE, 0.0) if _key != "" else 0.0
		if _fade <= 0.0:
			_key = _want
			if landed:
				_build_land(p.code + str(host.focus), p.radius, tdir)
			else:
				_build_orbit(p.code, p.radius)
	else:
		_fade = minf(_fade + delta / FADE, 1.0)
	if landed:
		global_transform = Transform3D(Basis(), p.surface_point(tdir) + p.global_position)
	else:
		_angle += delta * DRIFT
		global_transform = Transform3D(Basis(Planet.PAINT_AXIS, _angle), p.global_position)
	_mat.set_shader_parameter("vis", v * smoothstep(0.0, 1.0, _fade))
	_mat.set_shader_parameter("night", maxf(float(host.night), 0.0))
	_mat.set_shader_parameter("dusk", maxf(float(host.dusk), 0.0))
	if not p.cur.is_empty():
		_mat.set_shader_parameter("atmo_lin", Planet._lin(p.cur.atmo))
