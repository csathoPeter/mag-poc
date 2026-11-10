class_name Planet
extends Node3D
## Kis bolygó: domborzat, légkör, holdak, gyűrű, felszíntakaró és lebegő fénypontok.
## A kinézet a bolygó kódjából és a rajta élő növények DNS-éből jön (bolygó-DNS, lásd docs/DESIGN.md):
## az alapító (első) növény adja a darabos tulajdonságokat, a színeket és méreteket minden növény átlagolja.

const SURFACE := preload("res://shaders/planet.gdshader")
const ATMO := preload("res://shaders/atmo.gdshader")
const GRASS := preload("res://shaders/planet_grass.gdshader")
const RING := preload("res://shaders/ring.gdshader")
const MOTES := preload("res://shaders/motes.gdshader")

const RES := 40

## Domborzat az alapító termetéből.
const TERRAIN := {
	"arbor": {"amp": .07, "freq": 1.6, "ridged": false, "name": "dombos"},
	"weeping": {"amp": .05, "freq": 1.1, "ridged": false, "name": "lankás"},
	"windswept": {"amp": .09, "freq": 2.3, "ridged": true, "name": "sziklás"},
	"shrub": {"amp": .045, "freq": 3.2, "ridged": false, "name": "párnás"},
	"spire": {"amp": .13, "freq": 2.0, "ridged": true, "name": "tüskés csúcsú"},
}
## Felszíntakaró az alapító levélformájából (a LEAF tábla sorrendjében).
const COVER_OF_LEAF := [0, 0, 0, 1, 1, 1, 0, 2, 3, 2, 2, 2, 2, 2]
## h: szálmagasság, w: szélesség-szorzó, count: csomók az egész bolygón, dens: sűrűség a fa körüli foltban.
const COVER := [
	{"name": "füves", "h": .4, "w": .8, "count": 5000, "dens": 1.0},
	{"name": "mohás", "h": .1, "w": 1.6, "count": 6000, "dens": 1.15},
	{"name": "páfrányos", "h": .55, "w": 1.7, "count": 1800, "dens": .35},
	{"name": "kavicsos", "h": .08, "w": 1.8, "count": 900, "dens": .18},
]
## A fa körüli sűrű fűfolt: belül részletes csomók, kifelé ritkább, egyszerűbb csomók (csomó/egység², 4 szál/csomó).
## A folt szeletekre van vágva, így a kamera mögötti szeleteket a motor kihagyja.
const PATCH_NEAR := 4.5
const PATCH_FAR := 13.0
const NEAR_DENS := 95.0
const FAR_DENS := 24.0
const SECTORS := 8
const CLUMP_BLADES := 4
## Holdak száma és gyűrű az alapító szirmaiból.
const MOONS := [0, 1, 1, 2, 0, 1, 2, 3, 1, 0, 2, 1, 0, 1]
const RINGED := [false, false, true, false, false, false, false, false, true, false, false, true, false, false]

var code := ""
var dnas: Array = []
var radius := 4.0
var radius_target := 4.0
var terrain: Dictionary = {}
var cover: Dictionary = {}
var moon_count := 0
var ringed := false
var target := {}
var cur := {}
var night := 0.0
var amp := .06

var noise := FastNoiseLite.new()
var patch := FastNoiseLite.new()
var body := Node3D.new()
var surface := MeshInstance3D.new()
var atmo := MeshInstance3D.new()
var grass := MultiMeshInstance3D.new()
var patch_nodes: Array = []
var patch_on := false
var grass_on := true
var blade_hi: Mesh
var blade_lo: Mesh
var clump_noise := FastNoiseLite.new()
var motes := MultiMeshInstance3D.new()
var ring := MeshInstance3D.new()
var moons: Array = []
var surf_mat := ShaderMaterial.new()
var atmo_mat := ShaderMaterial.new()
var grass_mat := ShaderMaterial.new()
var ring_mat := ShaderMaterial.new()
var motes_mat := ShaderMaterial.new()
var moon_mat := StandardMaterial3D.new()


func _ready() -> void:
	add_child(body)
	surf_mat.shader = SURFACE
	surface.material_override = surf_mat
	body.add_child(surface)
	atmo_mat.shader = ATMO
	var sm := SphereMesh.new()
	sm.radial_segments = 48
	sm.rings = 24
	atmo.mesh = sm
	atmo.material_override = atmo_mat
	atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(atmo)
	grass_mat.shader = GRASS
	grass.material_override = grass_mat
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(grass)
	for i in SECTORS * 2:
		var g := MultiMeshInstance3D.new()
		g.material_override = grass_mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visible = false
		body.add_child(g)
		patch_nodes.append(g)
	clump_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	clump_noise.frequency = 9.0
	motes_mat.shader = MOTES
	motes.material_override = motes_mat
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(motes)
	ring_mat.shader = RING
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(ring)
	moon_mat.roughness = 1.0
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 4
	patch.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	patch.frequency = 3.5


## Új bolygó: a domborzat, a felszíntakaró és a holdak az alapítóból, a többi a növényekből.
func setup(planet_code: String, plant_dnas: Array) -> void:
	code = planet_code
	dnas = plant_dnas.duplicate()
	var founder: Array = dnas[0]
	terrain = TERRAIN[Genes.TERMET[founder[3]][0]]
	cover = COVER[COVER_OF_LEAF[founder[2]]]
	moon_count = MOONS[founder[1]]
	ringed = RINGED[founder[1]]
	noise.seed = hash(code + "domb")
	noise.frequency = terrain.freq
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED if terrain.ridged else FastNoiseLite.FRACTAL_FBM
	patch.seed = hash(code + "folt")
	clump_noise.seed = hash(code + "csomo")
	blade_hi = _clump_mesh([0.0, .33, .66], [.05, .043, .029], float(cover.w), hash(code + "szal"))
	blade_lo = _clump_mesh([0.0], [.05], float(cover.w), hash(code + "szal"))
	show_patch(false)
	_compute()
	amp = target.amp
	_snap()
	_build_surface()
	_build_grass()
	_build_motes()
	_build_moons()
	_build_ring()


## Új növény a bolygón: a célértékek változnak, a bolygó lassan átúszik az új kinézetbe.
func add_plant(dna: Array) -> void:
	dnas.append(dna)
	_compute()


func _compute() -> void:
	var n := dnas.size()
	var ws: Array = []
	for i in n:
		ws.append((1.0 if n == 1 else 1.0 / 3.0) if i == 0 else (2.0 / 3.0) / (n - 1))
	var fl := _avg_hsl(ws, func(d: Array) -> Array: return Genes.FLOWER[d[0]])
	var fo := _avg_hsl(ws, func(d: Array) -> Array: return Genes.FOLIAGE[d[5]])
	var ba := _avg_hsl(ws, func(d: Array) -> Array: return Genes.BARK[d[4]])
	var tall := 0.0
	var petals := 0.0
	var leaf := 0.0
	for i in n:
		var d: Array = dnas[i]
		tall += ws[i] * float(Genes.TERMET[d[3]][2])
		petals += ws[i] * float(d[1] % 6) / 5.0
		leaf += ws[i] * float(Genes.LEAF[d[2]][1])
	radius_target = 3.6 + .85 * sqrt(float(n))
	target = {
		"atmo": Genes.hsl(fl.x, minf(fl.y, .8) * .85, .72),
		"atmo_h": fl.x,
		"grass": Genes.hsl(fo.x, fo.y * .8, lerpf(fo.z, .6, .3)),
		"rock": Genes.hsl(ba.x, ba.y * .7, lerpf(ba.z, .62, .35)),
		"moon": Genes.hsl(fl.x + .5, .35, .8),
		"amp": float(terrain.amp) * lerpf(.8, 1.25, clampf((tall - .7) / .6, 0.0, 1.0)),
		"moon_size": lerpf(.1, .2, petals),
		"blade": lerpf(.8, 1.25, clampf((leaf - .22) / .32, 0.0, 1.0)),
	}


## Súlyozott HSL-átlag; az árnyalat körkörös (szín-kerék), hogy a piros és a lila átlaga ne zöld legyen.
func _avg_hsl(ws: Array, pick: Callable) -> Vector3:
	var c := Vector2.ZERO
	var s := 0.0
	var l := 0.0
	for i in dnas.size():
		var row: Array = pick.call(dnas[i])
		var a := float(row[1]) * TAU
		c += Vector2(cos(a), sin(a)) * ws[i] * (.25 + float(row[2]))
		s += ws[i] * float(row[2])
		l += ws[i] * float(row[3])
	return Vector3(fposmod(c.angle() / TAU, 1.0), s, l)


func _snap() -> void:
	radius = radius_target
	cur = target.duplicate()
	_apply()


func _apply() -> void:
	body.scale = Vector3.ONE * radius
	surf_mat.set_shader_parameter("rock", cur.rock)
	surf_mat.set_shader_parameter("grass", cur.grass)
	surf_mat.set_shader_parameter("atmo", cur.atmo)
	surf_mat.set_shader_parameter("night", night)
	atmo_mat.set_shader_parameter("atmo", cur.atmo)
	atmo_mat.set_shader_parameter("strength", lerpf(1.0, .8, night))
	var gc: Color = cur.grass
	grass_mat.set_shader_parameter("base_col", Color(gc.r * .45, gc.g * .5, gc.b * .45))
	grass_mat.set_shader_parameter("tip_col", gc.lerp(Color(1, .98, .9), .22))
	grass_mat.set_shader_parameter("sss_col", gc.lerp(Color(1, .9, .7), .6))
	grass_mat.set_shader_parameter("glow_col", Genes.hsl(cur.atmo_h + .45, .8, .62))
	grass_mat.set_shader_parameter("night", night)
	ring_mat.set_shader_parameter("col_a", cur.atmo)
	ring_mat.set_shader_parameter("col_b", cur.moon)
	ring_mat.set_shader_parameter("night", night)
	motes_mat.set_shader_parameter("night", night)
	motes_mat.set_shader_parameter("glow_col", Genes.hsl(cur.atmo_h + .45, .7, .7))
	moon_mat.albedo_color = cur.moon
	for m in moons:
		(m.mesh as Node3D).scale = Vector3.ONE * radius * float(cur.moon_size) * float(m.k)


func set_night(v: float) -> void:
	night = v
	_apply()


func _process(delta: float) -> void:
	if cur.is_empty():
		return
	var k := 1.0 - exp(-delta * 1.2)
	var moving := absf(radius - radius_target) > .0005
	if moving:
		radius = lerpf(radius, radius_target, k)
	for key in ["atmo", "grass", "rock", "moon"]:
		cur[key] = (cur[key] as Color).lerp(target[key], k)
	for key in ["moon_size"]:
		cur[key] = lerpf(cur[key], target[key], k)
	cur.atmo_h = target.atmo_h
	_apply()
	for m in moons:
		var p: Node3D = m.pivot
		p.rotate_object_local(Vector3.UP, delta * float(m.speed))
		(m.mesh as Node3D).position = Vector3(radius * float(m.dist), 0, 0)


## Magasság egységnyi bolygón (a sugár arányában). A domborzat magassága az alapításkor dől el.
func _height_fixed(dir: Vector3) -> float:
	return noise.get_noise_3dv(dir) * amp


func surface_point(dir: Vector3) -> Vector3:
	return dir * radius * (1.0 + _height_fixed(dir))


func _unit_point(dir: Vector3) -> Vector3:
	return dir * (1.0 + _height_fixed(dir))


func _normal(dir: Vector3) -> Vector3:
	var t1 := dir.cross(Vector3.UP if absf(dir.y) < .99 else Vector3.RIGHT).normalized()
	var t2 := dir.cross(t1)
	var e := .01
	var p0 := _unit_point(dir)
	var n := (_unit_point((dir + t1 * e).normalized()) - p0).cross(_unit_point((dir + t2 * e).normalized()) - p0).normalized()
	return n if n.dot(dir) > 0.0 else -n


## Hely a következő fának: determinisztikus a bolygó kódjából és a sorszámból, a többi fától távol.
func pick_spot(index: int, taken: Array) -> Vector3:
	var r := RandomNumberGenerator.new()
	r.seed = hash(code + "hely" + str(index))
	var best := Vector3.UP
	var best_d := -1.0
	for i in 160:
		var z := r.randf_range(-1.0, 1.0)
		var a := r.randf() * TAU
		var dir := Vector3(sqrt(1.0 - z * z) * cos(a), z, sqrt(1.0 - z * z) * sin(a))
		var md := 9.0
		for q in taken:
			md = minf(md, dir.distance_to(q))
		if md * radius_target > 3.4:
			return dir
		if md > best_d:
			best_d = md
			best = dir
	return best


func _build_surface() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	var idx := 0
	for f in faces:
		var n: Vector3 = f
		var u := Vector3(n.y, n.z, n.x)
		var v := n.cross(u)
		for j in RES + 1:
			for i in RES + 1:
				var a := tan((float(i) / RES * 2.0 - 1.0) * PI / 4.0)
				var b := tan((float(j) / RES * 2.0 - 1.0) * PI / 4.0)
				var dir := (n + u * a + v * b).normalized()
				var h := _height_fixed(dir)
				st.set_color(Color(clampf(h / amp * .5 + .5, 0.0, 1.0), patch.get_noise_3dv(dir) * .5 + .5, 0, 1))
				st.set_normal(_normal(dir))
				st.add_vertex(dir * (1.0 + h))
		for j in RES:
			for i in RES:
				var p := idx + j * (RES + 1) + i
				st.add_index(p); st.add_index(p + RES + 1); st.add_index(p + 1)
				st.add_index(p + 1); st.add_index(p + RES + 1); st.add_index(p + RES + 2)
		idx += (RES + 1) * (RES + 1)
	surface.mesh = st.commit()
	atmo.scale = Vector3.ONE * 1.2


## Fűcsomó: néhány elkeskenyedő szál egy kis körben, eltérő magassággal és iránnyal.
## Csúcspontonként: UV.y = magasság a szálon belül, CUSTOM0 = (a szál töve x, z, félszélesség, oldal), hogy a shader
## minden szálat a saját töve körül hajlítson és a nézetben kiszélesíthessen.
func _clump_mesh(ys: Array, ws: Array, width: float, seed: int) -> Mesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var base := 0
	for b in CLUMP_BLADES:
		var turn := Basis(Vector3.UP, r.randf() * TAU)
		var off := Vector2.from_angle(r.randf() * TAU) * (0.0 if b == 0 else r.randf_range(.05, .16))
		var hh := 1.0 if b == 0 else r.randf_range(.62, 1.05)
		var ww := width * r.randf_range(.8, 1.15)
		var nrm := turn * Vector3(0, 0, 1)
		var o3 := Vector3(off.x, 0, off.y)
		for i in ys.size():
			for sd in [-1.0, 1.0]:
				var hw := float(ws[i]) * ww
				st.set_normal(nrm)
				st.set_uv(Vector2((sd + 1.0) * .5, ys[i]))
				st.set_custom(0, Color(off.x, off.y, hw, sd))
				st.add_vertex(o3 + turn * Vector3(sd * hw, float(ys[i]) * hh, 0))
		st.set_normal(nrm)
		st.set_uv(Vector2(.5, 1))
		st.set_custom(0, Color(off.x, off.y, 0, 0))
		st.add_vertex(o3 + Vector3(0, hh, 0))
		for i in ys.size() - 1:
			var a := base + i * 2
			st.add_index(a); st.add_index(a + 1); st.add_index(a + 2)
			st.add_index(a + 1); st.add_index(a + 3); st.add_index(a + 2)
		var l := base + (ys.size() - 1) * 2
		st.add_index(l); st.add_index(l + 1); st.add_index(base + ys.size() * 2)
		base += ys.size() * 2 + 1
	return st.commit()


## Egy fűcsomó a pufferbe: egységes méretezés (a szél a csomó terében számol), a tő kicsit a felszín alatt.
func _put_blade(buf: PackedFloat32Array, i: int, dir: Vector3, r: RandomNumberGenerator) -> Vector3:
	var clump := clump_noise.get_noise_3dv(dir) * .5 + .5
	var h := float(cover.h) * float(target.blade) * lerpf(.55, 1.35, clump) * r.randf_range(.75, 1.2) / radius_target
	var b := Basis(Quaternion(Vector3.UP, dir)) * Basis(Vector3.UP, r.randf() * TAU)
	b = b.scaled(Vector3.ONE * h)
	var p := _unit_point(dir) - dir * .003
	var o := i * 16
	buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = p.x
	buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = p.y
	buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = p.z
	buf[o + 12] = 1.0; buf[o + 13] = r.randf(); buf[o + 14] = clump; buf[o + 15] = r.randf()
	return p


func _grass_mm(mesh: Mesh, buf: PackedFloat32Array, count: int, aabb: AABB) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.buffer = buf
	mm.custom_aabb = aabb
	return mm


func _build_grass() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(code + "fu")
	var count: int = cover.count
	var buf := PackedFloat32Array()
	buf.resize(count * 16)
	for i in count:
		var z := r.randf_range(-1.0, 1.0)
		var a := r.randf() * TAU
		_put_blade(buf, i, Vector3(sqrt(1.0 - z * z) * cos(a), z, sqrt(1.0 - z * z) * sin(a)), r)
	grass.multimesh = _grass_mm(blade_lo, buf, count, AABB(Vector3.ONE * -1.5, Vector3.ONE * 3.0))


## Sűrű fűfolt egy pont (pl. a kiválasztott fa) körül: belül részletes csomók, kifelé ritkább, egyszerűbb csomók.
## Szeletenként külön csomópont saját befoglaló dobozzal, így a kamera mögötti szeletek nem rajzolódnak ki.
## Determinisztikus a bolygó kódjából és a középpontból.
func build_patch(center: Vector3) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(code + "folt" + str(center.snapped(Vector3.ONE * .001)))
	var t1 := center.cross(Vector3.UP if absf(center.y) < .99 else Vector3.RIGHT).normalized()
	var t2 := center.cross(t1)
	var k := float(cover.dens)
	var rr := radius_target
	var margin := float(cover.h) * 1.6 / rr
	var rings := [[0.0, PATCH_NEAR, NEAR_DENS, blade_hi], [PATCH_NEAR, PATCH_FAR, FAR_DENS, blade_lo]]
	for ri in rings.size():
		var ring: Array = rings[ri]
		var r0: float = ring[0]
		var r1: float = ring[1]
		var per := int(PI * (r1 * r1 - r0 * r0) * float(ring[2]) * k / SECTORS)
		for sec in SECTORS:
			var buf := PackedFloat32Array()
			buf.resize(per * 16)
			var lo := Vector3.ONE * 9.0
			var hi := Vector3.ONE * -9.0
			for i in per:
				var rad := sqrt(r.randf_range(r0 * r0, r1 * r1))
				var a := (sec + r.randf()) * TAU / SECTORS
				var dir := (center + (t1 * cos(a) + t2 * sin(a)) * rad / rr).normalized()
				var p := _put_blade(buf, i, dir, r)
				lo = lo.min(p)
				hi = hi.max(p)
			var node: MultiMeshInstance3D = patch_nodes[ri * SECTORS + sec]
			node.multimesh = _grass_mm(ring[3], buf, per, AABB(lo - Vector3.ONE * margin, hi - lo + Vector3.ONE * margin * 2.0))


## Leszálláskor a folt látszik, a bolygót borító ritka réteg nem (így nem duplázódik a fű).
func show_patch(on: bool) -> void:
	patch_on = on
	_grass_visibility()


## Méréshez: a fű teljesen ki-be kapcsolható.
func set_grass(on: bool) -> void:
	grass_on = on
	_grass_visibility()


func _grass_visibility() -> void:
	for n in patch_nodes:
		(n as Node3D).visible = patch_on and grass_on
	grass.visible = grass_on and not patch_on


func _build_motes() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(code + "por")
	var count := 240
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = count
	for i in count:
		var z := r.randf_range(-1.0, 1.0)
		var a := r.randf() * TAU
		var dir := Vector3(sqrt(1.0 - z * z) * cos(a), z, sqrt(1.0 - z * z) * sin(a))
		mm.set_instance_transform(i, Transform3D(Basis(), dir * r.randf_range(1.04, 1.5)))
		mm.set_instance_custom_data(i, Color(r.randf(), r.randf(), 0, 0))
	mm.custom_aabb = AABB(Vector3.ONE * -2.0, Vector3.ONE * 4.0)
	motes.multimesh = mm


func _build_moons() -> void:
	for m in moons:
		(m.pivot as Node3D).queue_free()
	moons.clear()
	var r := RandomNumberGenerator.new()
	r.seed = hash(code + "hold")
	for i in moon_count:
		var pivot := Node3D.new()
		pivot.rotation = Vector3(r.randf_range(-.5, .5), r.randf() * TAU, r.randf_range(-.4, .4))
		add_child(pivot)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 32
		sm.rings = 16
		sm.radius = 1.0
		sm.height = 2.0
		mi.mesh = sm
		mi.material_override = moon_mat
		pivot.add_child(mi)
		moons.append({"pivot": pivot, "mesh": mi, "dist": 2.3 + i * .75 + r.randf() * .3, "speed": r.randf_range(.04, .09) * (1.0 if r.randf() < .8 else -1.0), "k": r.randf_range(.7, 1.3)})


func _build_ring() -> void:
	ring.visible = ringed
	if not ringed:
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash(code + "gyuru")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 128
	var inner := 1.5
	var outer := 2.15
	for i in seg + 1:
		var a := float(i) / seg * TAU
		var d := Vector3(cos(a), 0, sin(a))
		st.set_uv(Vector2(0, float(i) / seg)); st.add_vertex(d * inner)
		st.set_uv(Vector2(1, float(i) / seg)); st.add_vertex(d * outer)
	for i in seg:
		var a := i * 2
		st.add_index(a); st.add_index(a + 1); st.add_index(a + 2)
		st.add_index(a + 1); st.add_index(a + 3); st.add_index(a + 2)
	ring.mesh = st.commit()
	ring.rotation = Vector3(r.randf_range(.25, .5), r.randf() * TAU, r.randf_range(-.2, .2))
	ring_mat.set_shader_parameter("seed", r.randf() * 10.0)


func planet_name() -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(code + "nev")
	var a := ["Ael", "Bri", "Cel", "Dor", "Eli", "Fae", "Ila", "Lio", "Mir", "Nai", "Ori", "Sel", "Tal", "Ves"]
	var b := ["ra", "nde", "sa", "ra", "lune", "thea", "mira", "nis", "vel", "dora"]
	return "%s%s" % [a[r.randi() % a.size()], b[r.randi() % b.size()]]


func describe() -> String:
	var parts: Array = []
	parts.append("%s légkör" % _nearest_flower(float(target.atmo_h)))
	parts.append(str(terrain.name))
	parts.append(str(cover.name))
	parts.append(["nincs holdja", "1 hold", "2 hold", "3 hold"][moon_count])
	if ringed:
		parts.append("gyűrű")
	parts.append("%d növény" % dnas.size())
	return " · ".join(parts)


func _nearest_flower(h: float) -> String:
	var best := ""
	var bd := 9.0
	for f in Genes.FLOWER:
		if float(f[2]) < .5:
			continue
		var d := absf(wrapf(h - float(f[1]), -.5, .5))
		if d < bd:
			bd = d
			best = f[0]
	return best
