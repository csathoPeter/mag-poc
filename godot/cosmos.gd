class_name Cosmos
extends Node3D
## A kozmosz háttere (a kicsinyítés utolsó fokozata, sky_stars.gd): csillagpor, ködök és galaxisok a 3D-térben,
## különböző mélységben, így a kamera körbejárásakor valódi parallaxis van (a közeli por jobban elmozdul, a galaxisok
## alig). Determinisztikus (a játékoskódból), egyszer épül fel, amikor először kell; utána csak a halványodás változik.
##  - Csillagpor: ~1400 apró fénypont egy egyszer feltöltött MultiMesh-ben (a képkockánként frissített MultiMesh weben
##    a SwiftShaderen megállt – ez nem az), R_DUST0–R_DUST1 közt, kifelé ritkulva.
##  - Az anyagok render_priority-je 5–6: a bolygó-nézet lencséje (main.gd tilt_quad) után rajzolódnak, különben a
##    lencse képernyő-másolata lefedné őket (ugyanígy seed_marks.gd, shaping.gd).
##  - Ködök: 10 nagy, puha, kétszínű felhő (a kamera felé fordulnak), galaxisok: 64 spirál- és elliptikus galaxis döntött
##    korongon, messze. Mind additív, átlátszó.
## Olcsó: ~1400 + 74 négyszög (≈3k háromszög), csak a kozmoszban látszik.

const DUST := preload("res://shaders/cosmos_dust.gdshader")
const GALAXY := preload("res://shaders/galaxy.gdshader")

const N_DUST := 1400
const R_DUST0 := 150.0
const R_DUST1 := 1500.0
const N_NEBULA := 10
const N_GALAXY := 64
const DUST_COLS := [Color(1, 1, 1), Color(.78, .86, 1.0), Color(1.0, .86, .9), Color(1.0, .94, .78), Color(.86, .8, 1.0)]
const NEB_COLS := [[Color(.55, .3, .85), Color(.95, .45, .7)], [Color(.25, .45, .9), Color(.5, .85, .95)],
	[Color(.85, .4, .55), Color(1.0, .75, .55)], [Color(.35, .3, .8), Color(.75, .55, 1.0)], [Color(.2, .55, .6), Color(.6, .9, .75)]]
const GAL_COLS := [[Color(1.0, .9, .72), Color(.55, .65, 1.0)], [Color(1.0, .85, .8), Color(.85, .55, .95)],
	[Color(1.0, .95, .85), Color(.5, .85, 1.0)], [Color(1.0, .8, .65), Color(1.0, .6, .7)]]

var _built := ""
var _mats: Array = []
var _fade := 0.0


## A halványodás (0 = nem látszik); code: a játékoskód (ebből a háttér), az első látszáskor épül fel.
func set_fade(k: float, code: String) -> void:
	_fade = k
	visible = k > .005
	if not visible:
		return
	if _built != code:
		_build(code)
	for m in _mats:
		(m as ShaderMaterial).set_shader_parameter("fade", k)


func _build(code: String) -> void:
	for c in get_children():
		c.queue_free()
	_mats.clear()
	_built = code
	var r := RandomNumberGenerator.new()
	r.seed = hash(code + "kozmosz")
	# --- csillagpor
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = N_DUST
	for i in N_DUST:
		var d := _rand_dir(r)
		# kifelé ritkulva, de a messzi rétegből több (ott kisebbek): a sugár a térfogat helyett a távolság szerint
		var rad := lerpf(R_DUST0, R_DUST1, pow(r.randf(), .8))
		var sz := r.randf_range(.9, 3.0) * rad / 300.0
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sz), d * rad))
		var col: Color = DUST_COLS[r.randi() % DUST_COLS.size()]
		col.a = r.randf_range(.45, 1.2) * (1.8 if r.randf() < .07 else 1.0)
		mm.set_instance_color(i, col)
	var dust := MultiMeshInstance3D.new()
	dust.multimesh = mm
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.extra_cull_margin = 16384.0
	var dm := ShaderMaterial.new()
	dm.shader = DUST
	# a lencse (makett-sáv, main.gd tilt_quad) után rajzolódjon, különben a képernyő-másolata lefedi (mint seed_marks.gd)
	dm.render_priority = 6
	dust.material_override = dm
	_mats.append(dm)
	add_child(dust)
	# --- ködök (a kamera felé fordulnak)
	for i in N_NEBULA:
		var cols: Array = NEB_COLS[i % NEB_COLS.size()]
		_quad(_rand_dir(r) * r.randf_range(650.0, 1300.0), Basis(), r.randf_range(420.0, 800.0), 2, cols[0], cols[1],
			r.randf_range(.5, .8), r)
	# --- galaxisok (döntött korongok, messze)
	for i in N_GALAXY:
		var cols: Array = GAL_COLS[r.randi() % GAL_COLS.size()]
		var b := Basis(_rand_dir(r).cross(Vector3(.3, 1, .2)).normalized(), r.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, r.randf_range(-1.2, 1.2))
		var kind := 1 if r.randf() < .25 else 0
		_quad(_rand_dir(r) * r.randf_range(1500.0, 2500.0), b, r.randf_range(110.0, 380.0), kind, cols[0], cols[1],
			r.randf_range(1.1, 1.7), r)


func _quad(pos: Vector3, basis: Basis, size: float, kind: int, core: Color, arm: Color, strength: float, r: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = size
	mi.transform = Transform3D(basis.scaled(Vector3.ONE * size), pos)
	var m := ShaderMaterial.new()
	m.shader = GALAXY
	m.render_priority = 5 if kind == 2 else 6
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("col_core", core)
	m.set_shader_parameter("col_arm", arm)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("arms", float(2 + r.randi() % 2))
	m.set_shader_parameter("twist", r.randf_range(1.8, 3.4))
	m.set_shader_parameter("seed", r.randf_range(0.0, 50.0))
	mi.material_override = m
	_mats.append(m)
	add_child(mi)


static func _rand_dir(r: RandomNumberGenerator) -> Vector3:
	var z := r.randf_range(-1.0, 1.0)
	var a := r.randf() * TAU
	var s := sqrt(1.0 - z * z)
	return Vector3(s * cos(a), z, s * sin(a))
