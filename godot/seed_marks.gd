class_name SeedMarks
extends Node3D
## A még ki nem kelt magok helye a bolygón: apró földkupac, fölötte halványan, lassan lüktető meleg fénypont
## („itt holnap kikel valami”). A jelek a mentett fákból jönnek (hatch > ma, vagy kikelt, de a játékos még nem látta),
## így újratöltés után is ott vannak. A bolygó növekedésekor a felszínen maradnak.
## Olcsó: két MultiMesh (kupac + fénypont), kevés példány.

const DOT := preload("res://shaders/glow_dot.gdshader")
const MAX_MARKS := 32

var planet: Planet
## [{"id": fa-azonosító, "dir": irány a bolygón, "born": mikor jelent meg (mp, a felbukkanó mozgáshoz)}]
var marks: Array = []
var _glow := MultiMeshInstance3D.new()
var _mound := MultiMeshInstance3D.new()
var _soil := StandardMaterial3D.new()
var _glow_mat := ShaderMaterial.new()
var _r := -1.0
var _t := 0.0


func _ready() -> void:
	var gm := MultiMesh.new()
	gm.transform_format = MultiMesh.TRANSFORM_3D
	gm.use_colors = true
	gm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	gm.mesh = q
	gm.custom_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	_glow.multimesh = gm
	_glow_mat.shader = DOT
	_glow_mat.render_priority = 6
	# messziről (a bolygó-nézetből) is legyen néhány képpontnyi fény
	_glow_mat.set_shader_parameter("min_ang", .022)
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = .5
	sm.height = 1.0
	sm.radial_segments = 12
	sm.rings = 6
	sm.is_hemisphere = true
	mm.mesh = sm
	mm.custom_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	_mound.multimesh = mm
	_soil.roughness = 1.0
	# halvány saját fény, hogy árnyékban (alkonyatkor) se tűnjön lyuknak
	_soil.emission_enabled = true
	_soil.emission_energy_multiplier = .25
	_mound.material_override = _soil
	_mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mound)


## A jelek újra (pl. bolygóváltáskor, elvetéskor). fresh: az épp most földet ért mag, ez puhán felbukkan.
func set_marks(list: Array, fresh := -1) -> void:
	var old := {}
	for m in marks:
		old[int(m.id)] = float(m.born)
	marks.clear()
	for e in list:
		var id := int(e.id)
		marks.append({"id": id, "dir": (e.dir as Vector3).normalized(), "born": _t if id == fresh else float(old.get(id, -10.0))})
		if marks.size() >= MAX_MARKS:
			break
	_r = -1.0
	_rebuild()


func remove(id: int) -> void:
	for m in marks:
		if int(m.id) == id:
			marks.erase(m)
			break
	_r = -1.0
	_rebuild()


func clear() -> void:
	marks.clear()
	_rebuild()


func _rebuild() -> void:
	_glow.multimesh.instance_count = marks.size()
	_mound.multimesh.instance_count = marks.size()
	for i in marks.size():
		_glow.multimesh.set_instance_custom_data(i, Color(fposmod(float(hash(int(marks[i].id))) * .618, 1.0), 0, .16, 0))
	_place()


func _process(delta: float) -> void:
	_t += delta
	if marks.is_empty() or planet == null:
		return
	var anim := false
	for m in marks:
		if _t - float(m.born) < 1.2:
			anim = true
	if anim or absf(planet.radius - _r) > .0005:
		_place()


func _place() -> void:
	if planet == null or marks.is_empty():
		return
	_r = planet.radius
	var rock: Variant = planet.cur.get("rock")
	if rock is Color:
		# frissen forgatott föld: a bolygó kőzetszíne, kicsit barnábban
		_soil.albedo_color = (rock as Color).lerp(Color(.42, .30, .22), .35)
		_soil.emission = _soil.albedo_color
	for i in marks.size():
		var m: Dictionary = marks[i]
		var d: Vector3 = m.dir
		var age := _t - float(m.born)
		# felbukkanás: rugalmasan kinő (enyhe túllövéssel), utána nyugalom
		var k := 1.0
		if age < 1.2:
			var x := clampf(age / 1.2, 0.0, 1.0)
			k = 1.0 + 2.2 * pow(x - 1.0, 3.0) + 1.2 * pow(x - 1.0, 2.0)
		var p := planet.surface_point(d)
		var b := Basis(Quaternion(Vector3.UP, d))
		_mound.multimesh.set_instance_transform(i, Transform3D(b * Basis.from_scale(Vector3(.42, .16, .42) * maxf(k, .001)), p - d * .03))
		# a fény a fű fölött lebeg, hogy a sűrű fűben/páfrányban is látsszon
		_glow.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * .9 * maxf(k, .001)), p + d * .6))
		_glow.multimesh.set_instance_color(i, Color(SeedFx.C_SEED, 1.9 * clampf(k, 0.0, 1.2)))
