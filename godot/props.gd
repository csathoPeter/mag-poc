class_name Props
extends Node3D
## Díszek a kopár bolygókon (2026. 11. 13., Péter ötlete): kövek, kavicsok, gombák, lóhere, páfrány, kis virágok a
## Quaternius Stylized Nature MegaKitből (CC0; tools/prep_props.py → props/quaternius/). A felszíntakaró szerint:
## kavicsos bolygón kövek és kavicsok (a völgyekben, csoportosan), moháson gombák, lóhere, kis virágok, páfrányoson
## páfrány, kis növények, néhány kő. A füves bolygón nincs dísz (ott a fű a takaró).
## A hely determinisztikus a bolygókódból (mint a fű), a fák helyét elkerüli (avoid: a fák iránya; új fánál újraépül).
## Egy MultiMesh modellenként (a bolygó testének gyereke, a test egységnyi gömbjén, így a bolygó méretével együtt nő);
## a modell saját textúrája, a szín a bolygó színe felé húzva (shaders/prop.gdshader). Árnyékot csak a nagy kövek vetnek.

const DIR := "res://props/quaternius/"
const SHADER := preload("res://shaders/prop.gdshader")

## takarónként (planet.gd COVER sorrendje: 0 fű, 1 moha, 2 páfrány, 3 kavics):
## [modell, darab (egy ~7 sugarú bolygón), méret-szorzó min, max, hely („völgy”, „fű”, „bárhol”), csoportosan (0–1)]
const SETS := {
	3: [
		["Rock_Medium_1", 5, .1, .22, "bárhol", .3], ["Rock_Medium_2", 5, .1, .2, "bárhol", .3],
		["Rock_Medium_3", 4, .09, .18, "bárhol", .3],
		["Pebble_Round_1", 26, .45, 1.0, "völgy", .8], ["Pebble_Round_2", 26, .45, 1.0, "völgy", .8],
		["Pebble_Round_3", 26, .45, 1.0, "völgy", .8], ["Pebble_Round_4", 22, .45, 1.0, "völgy", .8],
		["Pebble_Round_5", 22, .45, 1.0, "völgy", .8],
	],
	1: [
		["Mushroom_Common", 36, .35, .65, "fű", .9], ["Clover_1", 30, .22, .36, "fű", .6],
		["Clover_2", 22, .22, .36, "fű", .6], ["Flower_3_Group", 10, .2, .3, "fű", .5],
		["Rock_Medium_2", 3, .08, .15, "bárhol", .2],
	],
	2: [
		["Fern_1", 22, .07, .11, "fű", .6], ["Plant_1", 20, .35, .55, "fű", .5], ["Plant_7", 26, .45, .75, "fű", .5],
		["Flower_4_Group", 8, .18, .26, "fű", .5], ["Rock_Medium_1", 3, .08, .15, "bárhol", .2],
	],
}
## a méret-szorzók közös szorzója (a fűszál ~0,25–0,4, egy fa 2–4 egység; a díszek ehhez igazodnak)
const SIZE := 2.6
## mennyire húz a bolygó színe felé (anyagonként: a modell textúrájának neve szerint)
const TINT := {"Rocks_Diffuse": .7, "PathRocks_Diffuse": .7, "Mushrooms": .15, "Leaves": .45, "Flowers": 0.0}

static var _meshes := {}
static var _cut_shader: Shader

## a bolygó (planet.gd), amelyhez a díszek tartoznak
var host: Planet
var avoid: Array = []
var built_r := 0.0
var built_code := ""
var built_cover := -1
var _mats: Array = []
var _cands: Array = []
var _dirty := false


## A modell hálója (gyorsítótárban), a felületenként saját anyaggal (a textúra a glTF anyagából).
static func mesh_of(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var scene: Node = (load(DIR + name + ".gltf") as PackedScene).instantiate()
	var mi := _find_mesh(scene)
	var mesh := (mi.mesh as Mesh).duplicate() as ArrayMesh
	for s in mesh.get_surface_count():
		var std := mesh.surface_get_material(s) as BaseMaterial3D
		if std == null and mi.get_surface_override_material(s) != null:
			std = mi.get_surface_override_material(s) as BaseMaterial3D
		var tex: Texture2D = std.albedo_texture if std != null else null
		var tname := tex.resource_path.get_file().get_basename() if tex != null else ""
		var leafy := tname == "Leaves" or tname == "Flowers"
		var m := ShaderMaterial.new()
		m.shader = _cut() if leafy else SHADER
		m.set_shader_parameter("tex", tex)
		m.set_shader_parameter("tint_k", TINT.get(tname, .3))
		m.set_shader_parameter("leafy", 1.0 if leafy else 0.0)
		m.set_meta("tint_src", tname)
		mesh.surface_set_material(s, m)
	scene.free()
	_meshes[name] = mesh
	return mesh


static func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r != null:
			return r
	return null


static func _cut() -> Shader:
	if _cut_shader == null:
		_cut_shader = Shader.new()
		_cut_shader.code = SHADER.code.replace("shader_type spatial;", "shader_type spatial;\n#define CUT")
	return _cut_shader


## Felépítés a bolygóhoz (a bolygó setup-ja után, és ha a fák vagy a sugár változnak). p: Planet.
## A lehetséges helyek (a domborzatból, drága) bolygónként egyszer készülnek (_cands); új fánál csak a közeliek esnek ki.
func build(p: Planet) -> void:
	for c in get_children():
		c.queue_free()
	_mats.clear()
	_dirty = false
	if p.code != built_code or p.cover_i != built_cover or absf(p.radius - built_r) > built_r * .03:
		_cands = _candidates(p)
	built_r = p.radius
	built_code = p.code
	built_cover = p.cover_i
	for e in _cands:
		var xf: Array = []
		for c in e.list:
			if xf.size() >= int(e.want):
				break
			var near := false
			for t in avoid:
				if (c[0] as Vector3).distance_to(t) * p.radius < 1.3:
					near = true
					break
			if not near:
				xf.append(c)
		if xf.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh_of(e.name)
		mm.instance_count = xf.size()
		for i in xf.size():
			mm.set_instance_transform(i, xf[i][1])
			mm.set_instance_custom_data(i, Color(float(xf[i][2]), 0, 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (e.name as String).begins_with("Rock") \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		for s in mm.mesh.get_surface_count():
			_mats.append(mm.mesh.surface_get_material(s))


## A díszek lehetséges helyei modellenként ([irány, transzformáció, tónus], a kelleténél ~40%-kal több, hogy a fák
## körül kieső helyek pótolhatók legyenek) – determinisztikusan a bolygókódból.
func _candidates(p: Planet) -> Array:
	var out: Array = []
	var set_list: Array = SETS.get(p.cover_i, [])
	var area := pow(p.radius / 7.0, 2.0)
	var clump := FastNoiseLite.new()
	clump.seed = hash(p.code + "díszcsoport")
	clump.frequency = 2.2
	for e in set_list:
		var name: String = e[0]
		var want := int(round(float(e[1]) * area))
		var pool := int(ceil(want * 1.4))
		var r := RandomNumberGenerator.new()
		r.seed = hash(p.code + "dísz" + name)
		var list: Array = []
		var tries := 0
		while list.size() < pool and tries < pool * 30:
			tries += 1
			var z := r.randf_range(-1.0, 1.0)
			var a := r.randf() * TAU
			var dir := Vector3(sqrt(1.0 - z * z) * cos(a), z, sqrt(1.0 - z * z) * sin(a))
			var yaw := r.randf() * TAU
			var sc := r.randf_range(float(e[2]), float(e[3])) * SIZE
			var bright := r.randf_range(.85, 1.1)
			var roll := r.randf()
			var keep := r.randf()
			# csoportosan: a csoport-zaj szerint (e[5]: mennyire); olcsó, ezért a domborzat előtt
			if keep > lerpf(1.0, smoothstep(-.15, .35, clump.get_noise_3dv(dir)), float(e[5])):
				continue
			var h := p._height_fixed(dir)
			var hv := clampf(h / p.amp * .5 + .5, 0.0, 1.0)
			var place: String = e[4]
			if place == "völgy" and roll > 1.0 - smoothstep(.35, .75, hv):
				continue
			var nrm := p._normal(dir).normalized()
			if place != "bárhol":
				var cov := smoothstep(.42, .66, nrm.dot(dir)) * (1.0 - smoothstep(.93, 1.0, hv))
				if cov < (.5 if place == "völgy" else .6):
					continue
			var up := (nrm + dir).normalized()
			var basis := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, yaw)
			var k := sc / p.radius
			list.append([dir, Transform3D(basis.scaled(Vector3.ONE * k), dir * (1.0 + h) - up * (k * .05)), bright])
		out.append({"name": name, "want": want, "list": list})
	return out


## A színek a bolygóból (a kőzet és a fű színe, lineárisan; a planet.gd _apply-ja hívja).
func set_colors(rock_lin: Vector3, field_lin: Vector3) -> void:
	for m in _mats:
		var src: String = (m as ShaderMaterial).get_meta("tint_src", "")
		var c := field_lin if src == "Leaves" or src == "Mushrooms" else rock_lin.lerp(field_lin, .35)
		(m as ShaderMaterial).set_shader_parameter("tint_lin", c)


## Egy fa helye (a díszek elkerülik); a következő frissítéskor újraépül.
func note_tree(dir: Vector3) -> void:
	for t in avoid:
		if (t as Vector3).distance_to(dir) < .001:
			return
	avoid.append(dir)
	_dirty = true


## Csupasz bolygón (és amíg a domborzat kiemelkedik) nincs dísz; a fák, a sugár, a bolygó változásakor újraépül
## (képkockánként legfeljebb egyszer – betöltéskor a 30 fa egy építéssel jár).
func _process(_delta: float) -> void:
	if host == null:
		return
	visible = not host.bare and host.shape_k > .99
	if visible and needs_rebuild(host):
		build(host)
		set_colors(Planet._lin(host.cur.rock), Planet._lin(host.cur.grass))


func needs_rebuild(p: Planet) -> bool:
	return _dirty or p.code != built_code or p.cover_i != built_cover or absf(p.radius - built_r) > built_r * .03
