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
## Fű: a felszín kocka-gömb csempékre van osztva (laponként TILES_N × TILES_N). Egy szál helye, iránya és mérete a
## shaderben születik a csempe és a szál sorszámából (hash), a magasság a felszín rácsából, így a fű a bolygóhoz
## rögzített, determinisztikus, és sosem generálódik újra. A sűrűség a szálak sorrendjéből adódik: ritkább fűnél csak
## a sor eleje látszik, sűrűbbnél a további szálak puhán előnőnek; a meglévőket semmi nem cseréli le.
## Rajzolni csoportonként kell (GROUP × GROUP csempe egy hívás, a csempék szálai váltakozva), csoportonként két
## csomóponttal: a kamerához közeli csempék részletes (íves) szálakkal, a többi egyszerűbbel.
## Sűrűség (csomó/egység², 4 szál/csomó): a kamera és a nézett pont körül NEAR_DENS, távolabb a bolygót borító alap (COVER.count).
const TILES_N := 6
const GROUP := 3
const NEAR_DENS := 140.0
## A fű alapsűrűségének szorzója (2026. 11. 11., Péter kérésére sokkal sűrűbb fű). A grass_mult (mérés, önálló
## minőség) erre szorzódik; melegedéskor a main.gd _auto_res ezt veszi vissza puhán (a ritkább csomók elhalványulnak).
const DENSITY := 1.6
const CLUMP_BLADES := 4
## A kamera körül CAM_R-en belül teljes a sűrűség, CAM_FAR-ig ritkul.
const CAM_R := 2.5
const CAM_FAR := 10.0
## A nézett pont körüli sűrű folt eddig ritkul (a sugár szorzója).
const FOCUS_FAR := 2.2
## Ennél közelebbi csempék részletes (íves) szálakat kapnak.
const HI_DIST := 6.5
const FACES := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
## Holdak száma és gyűrű az alapító szirmaiból.
const MOONS := [0, 1, 1, 2, 0, 1, 2, 3, 1, 0, 2, 1, 0, 1]
const RINGED := [false, false, true, false, false, false, false, false, true, false, false, true, false, false]
## A csupasz, alapító nélküli bolygó (M7) színei: halvány gyöngyház gömb, fehéres-levendula pára, sima felszín,
## fű, holdak és gyűrű nélkül. Az első kikelt fa adja meg a jellegét (add_plant: lassan átúszik).
const BARE_ROCK := Color(.64, .62, .72)
const BARE_GRASS := Color(.70, .69, .79)
const BARE_ATMO := Color(.86, .85, .96)

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
## A bolygó legalább ennyi növényhez méreteződik (M6: az eddigi legtöbb kikelt fa), így egy fa elengedésekor nem
## zsugorodik össze, és a fák közti távolság sem fogy el. A próba-bolygón 0.
var min_plants := 0
## az alapításkori növények DNS-e (setup); ha minden fát elengedtek, a bolygó színei is ezekből jönnek
var founders: Array = []
## Csupasz bolygó (M7): még nincs látott fája; az első kikelt fánál (add_plant) felveszi a jellegét.
var bare := false
## A domborzat megjelenése 0–1 (csupasz: 0, sima gömb); a felszín és a fák helye is ezzel számol.
var shape_k := 1.0

var noise := FastNoiseLite.new()
var patch := FastNoiseLite.new()
## a festett fű sávjai (_paint_raw); a tengely ugyanaz, mint a fű szeléé (planet_grass.gdshader wind_axis)
var paint_noise := FastNoiseLite.new()
const PAINT_AXIS := Vector3(0.2822, 0.9407, 0.1881)
var body := Node3D.new()
var surface := MeshInstance3D.new()
var atmo := MeshInstance3D.new()
## Csempék: {dir, jmax, f, a, b}; csoportok: {hi, lo (csomópontok), dir, tiles, n_hi, n_lo (csempénkénti darabszám)}.
## A csomópont pufferében szálanként csak két szám van: a csempe helyi indexe és a szál sorszáma (a mátrix 1. és 2.
## oszlopának hosszában); a helyet, irányt, méretet a shader számolja.
var tiles: Array = []
var groups: Array = []
## helyi csempe-indexenként előre kitöltött puffer (0..k_cap szál), ebből szeletelünk
var segs: Array = []
var k_cap := 0
var tile_aabb := AABB()
var tile_rad := .2
var height_tex: ImageTexture
var h_min := 0.0
var h_max := 0.0
var grass_on := true
## A fű sűrűségének szorzója (a terheléses méréshez).
var grass_mult := 1.0
var view_cam := Vector3.ZERO
var focus_pt := Vector3.ZERO
var focus_r := 4.5
var focus_k := 0.0
## az utolsó csempe-frissítéskori állapot
var view_r := 0.0
var upd_cam := Vector3.ZERO
var upd_pt := Vector3.ZERO
var upd_r := 0.0
var upd_k := 0.0
var blade_hi: Mesh
var blade_lo: Mesh
var motes := MultiMeshInstance3D.new()
var ring := MeshInstance3D.new()
var moons: Array = []
var surf_mat := ShaderMaterial.new()
var atmo_mat := ShaderMaterial.new()
var grass_mat := ShaderMaterial.new()
var hi_mat := ShaderMaterial.new()
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
	hi_mat.shader = GRASS
	hi_mat.set_shader_parameter("hi_layer", true)
	_make_tiles()
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
	paint_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	paint_noise.frequency = 1.0
	paint_noise.fractal_type = FastNoiseLite.FRACTAL_NONE


## Új bolygó: a domborzat, a felszíntakaró és a holdak az alapítóból, a többi a növényekből.
## founding: az alapításkori növények DNS-e (a mentésből). Ezekből jön a darabos jelleg és a domborzat magassága,
## így újratöltéskor (több fával) is ugyanaz a bolygó áll össze. Üres = a mostani növények az alapítók.
## is_bare (M7): csupasz, alapító nélküli bolygó – sima, halvány gömb; a jelleg (founding) már kiszámolva, csak rejtve.
func setup(planet_code: String, plant_dnas: Array, founding: Array = [], is_bare := false) -> void:
	code = planet_code
	bare = is_bare
	var base: Array = founding if not founding.is_empty() else plant_dnas
	founders = base.duplicate()
	var founder: Array = base[0]
	terrain = TERRAIN[Genes.TERMET[founder[3]][0]]
	cover = COVER[COVER_OF_LEAF[founder[2]]]
	moon_count = MOONS[founder[1]]
	ringed = RINGED[founder[1]]
	noise.seed = hash(code + "domb")
	noise.frequency = terrain.freq
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED if terrain.ridged else FastNoiseLite.FRACTAL_FBM
	patch.seed = hash(code + "folt")
	paint_noise.seed = hash(code + "festett")
	# puha stílus: a részletes szál vége tompább (a felső sor magasabban és szélesebben, a hegy rövid)
	blade_hi = _clump_mesh([0.0, .4, .78], [.05, .047, .036], float(cover.w), hash(code + "szal"))
	blade_lo = _clump_mesh([0.0], [.05], float(cover.w), hash(code + "szal"))
	for g in groups:
		g.n_hi = []
		g.n_lo = []
		(g.hi as MultiMeshInstance3D).multimesh.mesh = blade_hi
		(g.lo as MultiMeshInstance3D).multimesh.mesh = blade_lo
	for m in [grass_mat, hi_mat]:
		(m as ShaderMaterial).set_shader_parameter("seed", hash(code + "fu") & 0xffffff)
	dnas = base.duplicate()
	_compute()
	amp = target.amp
	if not plant_dnas.is_empty():
		dnas = plant_dnas.duplicate()
		_compute()
	_snap()
	_build_surface()
	_build_grass()
	_build_motes()
	_build_moons()
	_build_ring()


## Új növény a bolygón: a célértékek változnak, a bolygó lassan átúszik az új kinézetbe.
## Csupasz bolygón (M7) az első növény adja meg a jellegét: a domborzat kiemelkedik, a színek, a fű, a holdak megjelennek.
func add_plant(dna: Array) -> void:
	if bare:
		bare = false
		dnas.clear()
	dnas.append(dna)
	_compute()
	_tile_bounds()


## Elengedett növény (M6): a színek a megmaradt növényekből állnak össze (lassan átúszik). A darabos jelleg és a
## domborzat az alapítóból jön (setup), így nem változik; az első megmaradt növény veszi át az alapító súlyát.
## Ha nem marad növény, a színek is az alapítóból jönnek (mint újratöltéskor).
func remove_plant(dna: Array) -> void:
	var i := dnas.find(dna)
	if i < 0:
		return
	dnas.remove_at(i)
	if dnas.is_empty():
		dnas = founders.duplicate()
	_compute()
	_tile_bounds()


func _compute() -> void:
	radius_target = radius_for(maxi(dnas.size(), min_plants))
	target = look_of(dnas, float(terrain.amp))
	# csupasz bolygó (M7): halvány gyöngyház, sima, fű, holdak és gyűrű nélkül; a jelleg az első fával jön elő
	target.shape = 0.0 if bare else 1.0
	target.deco = 0.0 if bare else 1.0
	if bare:
		target.atmo = BARE_ATMO
		target.grass = BARE_GRASS
		target.rock = BARE_ROCK
		target.moon = BARE_ATMO


## A bolygó-DNS színei és méretei a növényekből (az első az alapító, súlya 1/3). A háttérben látszó kis bolygók
## (planet_system.gd) is ezt használják, így ugyanolyan színűek, mint a teljes bolygó.
static func look_of(plant_dnas: Array, terrain_amp: float) -> Dictionary:
	var n := plant_dnas.size()
	var ws: Array = []
	for i in n:
		ws.append((1.0 if n == 1 else 1.0 / 3.0) if i == 0 else (2.0 / 3.0) / (n - 1))
	var fl := _avg_hsl(plant_dnas, ws, func(d: Array) -> Array: return Genes.FLOWER[d[0]])
	var fo := _avg_hsl(plant_dnas, ws, func(d: Array) -> Array: return Genes.FOLIAGE[d[5]])
	var ba := _avg_hsl(plant_dnas, ws, func(d: Array) -> Array: return Genes.BARK[d[4]])
	var tall := 0.0
	var petals := 0.0
	var leaf := 0.0
	for i in n:
		var d: Array = plant_dnas[i]
		tall += ws[i] * float(Genes.TERMET[d[3]][2])
		petals += ws[i] * float(d[1] % 6) / 5.0
		leaf += ws[i] * float(Genes.LEAF[d[2]][1])
	return {
		"atmo": Genes.hsl(fl.x, minf(fl.y, .8) * .85, .72),
		"atmo_h": fl.x,
		"grass": Genes.hsl(fo.x, fo.y * .8, lerpf(fo.z, .6, .3)),
		"rock": Genes.hsl(ba.x, ba.y * .7, lerpf(ba.z, .62, .35)),
		"moon": Genes.hsl(fl.x + .5, .35, .8),
		"amp": terrain_amp * lerpf(.8, 1.25, clampf((tall - .7) / .6, 0.0, 1.0)),
		"moon_size": lerpf(.1, .2, petals),
		"blade": lerpf(.8, 1.25, clampf((leaf - .22) / .32, 0.0, 1.0)),
	}


## Súlyozott HSL-átlag; az árnyalat körkörös (szín-kerék), hogy a piros és a lila átlaga ne zöld legyen.
static func _avg_hsl(plant_dnas: Array, ws: Array, pick: Callable) -> Vector3:
	var c := Vector2.ZERO
	var s := 0.0
	var l := 0.0
	for i in plant_dnas.size():
		var row: Array = pick.call(plant_dnas[i])
		var a := float(row[1]) * TAU
		c += Vector2(cos(a), sin(a)) * ws[i] * (.25 + float(row[2]))
		s += ws[i] * float(row[2])
		l += ws[i] * float(row[3])
	return Vector3(fposmod(c.angle() / TAU, 1.0), s, l)


func _snap() -> void:
	radius = radius_target
	cur = target.duplicate()
	shape_k = float(cur.shape)
	_apply()


## A fű páfrány-változata: ugyanaz a shader #define FROND-dal (levélkékre tagolt szál, discard-dal – csak itt).
static var _frond: Shader


static func _frond_shader() -> Shader:
	if _frond == null:
		_frond = Shader.new()
		_frond.code = GRASS.code.replace("shader_type spatial;", "shader_type spatial;\n#define FROND")
	return _frond


static func _lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)


func _apply() -> void:
	body.scale = Vector3.ONE * radius
	var deco := float(cur.deco)
	surf_mat.set_shader_parameter("shape", shape_k)
	surf_mat.set_shader_parameter("rock", cur.rock)
	surf_mat.set_shader_parameter("grass", cur.grass)
	surf_mat.set_shader_parameter("atmo", cur.atmo)
	surf_mat.set_shader_parameter("night", night)
	atmo_mat.set_shader_parameter("atmo", cur.atmo)
	atmo_mat.set_shader_parameter("strength", lerpf(1.0, .8, night))
	var gc: Color = cur.grass
	# páfrányos bolygón a fű levélkés változata (#define FROND); a paraméterek az anyagon maradnak
	var want: Shader = _frond_shader() if cover.get("name", "") == "páfrányos" else GRASS
	if grass_mat.shader != want:
		grass_mat.shader = want
		hi_mat.shader = want
		hi_mat.set_shader_parameter("hi_layer", true)
	for m in [grass_mat, hi_mat]:
		var gm := m as ShaderMaterial
		# a fű színei lineárisan (sima vec3 uniform; a shader így képpontonként nem alakít át)
		gm.set_shader_parameter("base_lin", _lin(Color(gc.r * .45, gc.g * .5, gc.b * .45)))
		gm.set_shader_parameter("tip_lin", _lin(gc.lerp(Color(1, .98, .9), .22)))
		gm.set_shader_parameter("field_lin", _lin(gc))
		gm.set_shader_parameter("sss_lin", _lin(gc.lerp(Color(1, .9, .7), .6)))
		gm.set_shader_parameter("glow_lin", _lin(Genes.hsl(cur.atmo_h + .45, .8, .62)))
		gm.set_shader_parameter("night", night)
		gm.set_shader_parameter("planet_pos", global_position)
		gm.set_shader_parameter("planet_r", radius)
		# csupasz bolygón (M7) nincs fű: a szálak a jelleg megjelenésekor nőnek ki
		gm.set_shader_parameter("blade_h", float(cover.h) * float(cur.blade) * deco * deco * deco)
		gm.set_shader_parameter("near_w", NEAR_DENS * float(cover.dens) * grass_mult * DENSITY)
		gm.set_shader_parameter("base_w", _base_u() / (radius * radius))
		gm.set_shader_parameter("cam_r", CAM_R)
		gm.set_shader_parameter("cam_far", CAM_FAR)
	ring_mat.set_shader_parameter("col_a", cur.atmo)
	ring_mat.set_shader_parameter("col_b", cur.moon)
	ring_mat.set_shader_parameter("night", night)
	motes_mat.set_shader_parameter("night", night)
	motes_mat.set_shader_parameter("glow_col", Genes.hsl(cur.atmo_h + .45, .7, .7))
	moon_mat.albedo_color = cur.moon
	for m in moons:
		(m.mesh as Node3D).scale = Vector3.ONE * maxf(radius * float(cur.moon_size) * float(m.k) * deco, .001)
		(m.mesh as Node3D).visible = deco > .01
	ring.scale = Vector3.ONE * maxf(deco, .001)
	ring.visible = ringed and deco > .01


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
	for key in ["moon_size", "blade"]:
		cur[key] = lerpf(cur[key], target[key], k)
	# a jelleg megjelenése (M7): előbb a domborzat emelkedik ki, aztán a fű, a holdak és a gyűrű
	for key in ["shape", "deco"]:
		var to := float(target[key])
		var sp := .45 if key == "shape" else .32
		cur[key] = move_toward(float(cur[key]), to, delta * sp) if absf(float(cur[key]) - to) > .0005 else to
	shape_k = _ease(float(cur.shape))
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
	return dir * radius * (1.0 + _height_fixed(dir) * shape_k)


static func _ease(x: float) -> float:
	var v := clampf(x, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


func _unit_point(dir: Vector3) -> Vector3:
	return dir * (1.0 + _height_fixed(dir))


func _normal(dir: Vector3) -> Vector3:
	var t1 := dir.cross(Vector3.UP if absf(dir.y) < .99 else Vector3.RIGHT).normalized()
	var t2 := dir.cross(t1)
	var e := .01
	var p0 := _unit_point(dir)
	var n := (_unit_point((dir + t1 * e).normalized()) - p0).cross(_unit_point((dir + t2 * e).normalized()) - p0).normalized()
	return n if n.dot(dir) > 0.0 else -n


## A bolygó sugara n növénnyel (minden új fával kicsit nő).
static func radius_for(n: int) -> float:
	return 3.6 + .85 * sqrt(float(maxi(n, 1)))


## Hely a következő fának: determinisztikus a bolygó kódjából és a sorszámból, a többi fától távol.
func pick_spot(index: int, taken: Array) -> Vector3:
	return spot_for(code, index, taken, radius_target)


## Ugyanez bolygó nélkül (a mentés is ezzel ad helyet a fáknak).
static func spot_for(planet_code: String, index: int, taken: Array, rad: float) -> Vector3:
	var r := RandomNumberGenerator.new()
	r.seed = hash(planet_code + "hely" + str(index))
	var best := Vector3.UP
	var best_d := -1.0
	for i in 160:
		var z := r.randf_range(-1.0, 1.0)
		var a := r.randf() * TAU
		var dir := Vector3(sqrt(1.0 - z * z) * cos(a), z, sqrt(1.0 - z * z) * sin(a))
		var md := 9.0
		for q in taken:
			md = minf(md, dir.distance_to(q))
		if md * rad > 3.4:
			return dir
		if md > best_d:
			best_d = md
			best = dir
	return best


## Festett fű (paint_field.gdshaderinc): a tónus-sávok nyers értéke (0–1) egy irányban. Két lépték (kívülről a nagy sávok,
## leszállva a domb kisebb sávjai), a szél tengelye mentén összenyomva, így a sávok körbefutnak a bolygón.
func _paint_raw(dir: Vector3) -> float:
	var al := dir.dot(PAINT_AXIS)
	var big := paint_noise.get_noise_3dv(dir * 1.3 + PAINT_AXIS * (al * 1.3 * 2.5))
	var mid := paint_noise.get_noise_3dv(dir * 3.6 + PAINT_AXIS * (al * 3.6 * 3.0) + Vector3(31.7, 5.3, -12.1))
	return clampf((big * .6 + mid * .4) * .5 + .5, 0.0, 1.0)


## Festett fű: hol fű a talaj (1) és hol kőzet (0). A planet.gdshader paint ágával azonos képlet (a lejtő és a magasság);
## a korábbi fűnél szűkebb a kőzet (csak a meredek sziklák és a legmagasabb csúcsok), mert a rövid szálak nem takarják el.
func _paint_cover(dir: Vector3, h: float) -> float:
	var slope := _normal(dir).normalized().dot(dir)
	var hv := clampf(h / amp * .5 + .5, 0.0, 1.0)
	return smoothstep(.42, .66, slope) * (1.0 - smoothstep(.93, 1.0, hv))


func _build_surface() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# a magasságok képként is (laponként (RES+1)², egymás alatt): a fű shadere ebből ülteti a szálakat pont a felszínre
	# G csatorna: a festett fű sávjainak nyers értéke (_paint_raw); a talaj csúcspont-színként (B) kapja ugyanezt.
	# B csatorna: festett fűnél a fűtakaró (_paint_cover): a kőzeten nem nő szál (a talaj ugyanígy számolja képpontonként)
	var img := Image.create_empty(RES + 1, 6 * (RES + 1), false, Image.FORMAT_RGBF)
	h_min = 9.0
	h_max = -9.0
	var idx := 0
	for f in 6:
		var n: Vector3 = FACES[f]
		var u := Vector3(n.y, n.z, n.x)
		var v := n.cross(u)
		for j in RES + 1:
			for i in RES + 1:
				var a := tan((float(i) / RES * 2.0 - 1.0) * PI / 4.0)
				var b := tan((float(j) / RES * 2.0 - 1.0) * PI / 4.0)
				var dir := (n + u * a + v * b).normalized()
				var h := _height_fixed(dir)
				var pb := _paint_raw(dir)
				img.set_pixel(i, f * (RES + 1) + j, Color(h, pb, _paint_cover(dir, h)))
				h_min = minf(h_min, h)
				h_max = maxf(h_max, h)
				st.set_color(Color(clampf(h / amp * .5 + .5, 0.0, 1.0), patch.get_noise_3dv(dir) * .5 + .5, pb, 1))
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
	height_tex = ImageTexture.create_from_image(img)
	for m in [grass_mat, hi_mat]:
		var sm := m as ShaderMaterial
		sm.set_shader_parameter("height_tex", height_tex)
		sm.set_shader_parameter("res", RES)
		sm.set_shader_parameter("tiles_n", TILES_N)
		sm.set_shader_parameter("tile_rad", tile_rad)


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


## Csempék és csoportok a kocka-gömbön. A csoport csomópontja a csoport közepén áll, a felszínre merőleges kerettel:
## a shader ebből tudja, melyik csoportot rajzolja, a motor pedig a közös befoglaló dobozzal kihagyja a képen kívülieket.
func _make_tiles() -> void:
	var nn := TILES_N
	for f in 6:
		for ti in nn:
			for tj in nn:
				var ac := -1.0 + (ti + .5) * 2.0 / nn
				var bc := -1.0 + (tj + .5) * 2.0 / nn
				var c := _face_dir(f, ac, bc)
				var jmax := 0.0
				var rad := 0.0
				for p in [[-1, -1], [-1, 1], [1, -1], [1, 1], [0, 0], [-1, 0], [1, 0], [0, -1], [0, 1]]:
					var a: float = ac + float(p[0]) / nn
					var b: float = bc + float(p[1]) / nn
					jmax = maxf(jmax, _jac(a, b))
					rad = maxf(rad, _face_dir(f, a, b).distance_to(c))
				tile_rad = maxf(tile_rad, rad)
				tiles.append({"dir": c, "f": f, "a": ac, "b": bc, "jmax": jmax})
	var gn := TILES_N / GROUP
	for f in 6:
		for gi in gn:
			for gj in gn:
				var c := _face_dir(f, -1.0 + (gi + .5) * 2.0 / gn, -1.0 + (gj + .5) * 2.0 / gn)
				var t1 := c.cross(Vector3.UP if absf(c.y) < .99 else Vector3.RIGHT).normalized()
				var g := {"dir": c, "f": f, "gi": gi, "gj": gj, "tiles": [], "n_hi": [], "n_lo": []}
				# a csempék sorrendje ugyanaz, mint a shaderben: helyi index = (ti % GROUP) * GROUP + tj % GROUP
				for li in GROUP:
					for lj in GROUP:
						(g.tiles as Array).append(f * nn * nn + (gi * GROUP + li) * nn + gj * GROUP + lj)
				for key in ["hi", "lo"]:
					var node := MultiMeshInstance3D.new()
					node.transform = Transform3D(Basis(t1, c, t1.cross(c)), c)
					node.material_override = hi_mat if key == "hi" else grass_mat
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					node.visible = false
					var mm := MultiMesh.new()
					mm.transform_format = MultiMesh.TRANSFORM_3D
					node.multimesh = mm
					body.add_child(node)
					g[key] = node
				groups.append(g)


func _face_dir(f: int, a: float, b: float) -> Vector3:
	var n: Vector3 = FACES[f]
	var u := Vector3(n.y, n.z, n.x)
	return (n + u * tan(a * PI / 4.0) + n.cross(u) * tan(b * PI / 4.0)).normalized()


## A kocka-lap paraméterterének (a, b ∈ [-1, 1]) területtorzítása az egységgömbön.
func _jac(a: float, b: float) -> float:
	var x := tan(a * PI / 4.0)
	var y := tan(b * PI / 4.0)
	return PI * PI / 16.0 * (1.0 + x * x) * (1.0 + y * y) / pow(1.0 + x * x + y * y, 1.5)


## A csoportok közös befoglaló doboza a saját keretükben (domborzat + szálmagasság); a bolygó növekedésekor frissül.
func _tile_bounds() -> void:
	var hb := float(cover.h) * float(target.blade) * 2.2 / radius_target
	var lo := Vector3.ONE * 9.0
	var hi := Vector3.ONE * -9.0
	var gn := TILES_N / GROUP
	for g in groups:
		var inv: Transform3D = (g.hi as Node3D).transform.affine_inverse()
		for i in 5:
			for j in 5:
				var d := _face_dir(g.f, -1.0 + (g.gi + i / 4.0) * 2.0 / gn, -1.0 + (g.gj + j / 4.0) * 2.0 / gn)
				for rr in [1.0 + h_min - .01, 1.0 + h_max + hb]:
					var p: Vector3 = inv * (d * rr)
					lo = lo.min(p)
					hi = hi.max(p)
	tile_aabb = AABB(lo - Vector3.ONE * hb, hi - lo + Vector3.ONE * hb * 2.0)
	for g in groups:
		for key in ["hi", "lo"]:
			(g[key] as MultiMeshInstance3D).multimesh.custom_aabb = tile_aabb


## Darabszám √2-es lépcsőkre kerekítve: így a puffer csak ritkán épül újra, amikor a kamera mozog.
static func _level(count: int) -> int:
	if count <= 0:
		return 0
	var lv := maxi(0, ceili(log(float(count) / 4.0) / log(sqrt(2.0)) - .001))
	return ceili(4.0 * pow(sqrt(2.0), lv) - .001)


## Helyi csempe-indexenként (0..GROUP²-1) egy puffer a szálak sorszámával; ha kevés, nagyobbat építünk.
func _ensure_segs(k: int) -> void:
	if k <= k_cap:
		return
	k_cap = maxi(k, int(k_cap * 1.5))
	segs.clear()
	for lt in GROUP * GROUP:
		var buf := PackedFloat32Array()
		buf.resize(k_cap * 12)
		for i in k_cap:
			buf[i * 12] = float(lt)
			buf[i * 12 + 5] = float(i)
			buf[i * 12 + 10] = 1.0
		segs.append(buf)


## A csomópont puffere: csempénként az első n szál.
func _fill_node(node: MultiMeshInstance3D, counts: Array) -> void:
	var total := 0
	for c in counts:
		total += int(c)
	var show := grass_on and total > 0
	if show:
		var buf := PackedFloat32Array()
		for lt in counts.size():
			if int(counts[lt]) > 0:
				buf.append_array((segs[lt] as PackedFloat32Array).slice(0, int(counts[lt]) * 12))
		var mm := node.multimesh
		mm.instance_count = total
		mm.buffer = buf
	if node.visible != show:
		node.visible = show


## Alapsűrűség az egységgömbön (a bolygó méretétől független, így a növekedéskor sem változik, mely szálak látszanak).
func _base_u() -> float:
	return float(cover.count) * grass_mult * DENSITY / (4.0 * PI)


func _build_grass() -> void:
	for m in [grass_mat, hi_mat]:
		var sm := m as ShaderMaterial
		sm.set_shader_parameter("hi_dist", HI_DIST)
		sm.set_shader_parameter("group", GROUP)
	_tile_bounds()
	_update_tiles()


## A kamera és a nézett pont: a fű sűrűsége ezek körül nő. A csempék ebből tudják, hány szálat rajzoljanak.
## focus_strength 0 esetén csak a kamera körül sűrű a fű.
func grass_view(cam_pos: Vector3, point: Vector3, point_r: float, point_k: float) -> void:
	# ha alig mozdult valami, a csempék darabszáma sem változik (a shader a pontos értékekkel számol)
	var same := cam_pos.distance_to(upd_cam) < .02 and point.distance_to(upd_pt) < .02 and absf(point_r - upd_r) < .01 \
		and absf(point_k - upd_k) < .005 and absf(radius - view_r) < .0005
	view_cam = cam_pos
	focus_pt = point
	focus_r = point_r
	focus_k = point_k
	for m in [grass_mat, hi_mat]:
		var sm := m as ShaderMaterial
		sm.set_shader_parameter("cam_pos", cam_pos)
		sm.set_shader_parameter("focus_pt", point)
		sm.set_shader_parameter("focus_r", point_r)
		sm.set_shader_parameter("focus_k", point_k)
		sm.set_shader_parameter("focus_far", point_r * FOCUS_FAR)
	if not same:
		view_r = radius
		upd_cam = cam_pos
		upd_pt = point
		upd_r = point_r
		upd_k = point_k
		_update_tiles()


static func _fall(d: float, r0: float, r1: float) -> float:
	var f := 1.0 if d < r0 else r0 * r0 / (d * d)
	return f * (1.0 - smoothstep(r1 * .55, r1, d))


func _update_tiles() -> void:
	if tiles.is_empty() or cover.is_empty() or blade_hi == null:
		return
	var r := radius
	var near_w := NEAR_DENS * float(cover.dens) * grass_mult * DENSITY
	var base_w := _base_u() / (r * r)
	var pa := 4.0 / float(TILES_N * TILES_N)
	var ctr := global_position
	var tr := tile_rad * r
	# a látóhatáron túli csempék nem látszanak (a bolygó takarja őket): a kamera irányától mért szög alapján
	var rel := view_cam - ctr
	var cam_dir := rel.normalized()
	var horizon := acos(clampf(r * (1.0 + h_min) / maxf(rel.length(), r * 1.001), -1.0, 1.0))
	var reach := horizon + acos(clampf(1.0 / (1.0 + h_max + .05), -1.0, 1.0)) + asin(clampf(tile_rad, 0.0, 1.0)) * 1.1
	for g in groups:
		# csempénként ugyanaz, mint a shaderben (ott dönti el szálanként, melyik csomópont rajzol és mennyi szál nő ki);
		# itt kis ráhagyással, hogy minden kellő szál biztosan sorra kerüljön
		var n_hi: Array = []
		var n_lo: Array = []
		for ti in g.tiles:
			var t: Dictionary = tiles[ti]
			var need := 0
			var dct := 99.0
			if (t.dir as Vector3).angle_to(cam_dir) < reach:
				var c: Vector3 = ctr + (t.dir as Vector3) * r
				dct = c.distance_to(view_cam) - tr
				var f := maxf(_fall(maxf(dct, 0.0), CAM_R, CAM_FAR), focus_k * _fall(maxf(c.distance_to(focus_pt) - tr, 0.0), focus_r, focus_r * FOCUS_FAR))
				need = _level(ceili(lerpf(base_w, near_w, f) * pa * float(t.jmax) * r * r))
			# a csempe a részletes csomópontba kerül, ha a legközelebbi pontja, az egyszerűbe, ha a legtávolabbi pontja lehet a
			# határon túl (a shader szálanként dönt)
			n_hi.append(need if dct < HI_DIST + .3 else 0)
			n_lo.append(need if dct + 2.0 * tr > HI_DIST - .3 else 0)
		var top := 0
		for c in n_hi + n_lo:
			top = maxi(top, int(c))
		_ensure_segs(top)
		if n_hi != g.n_hi:
			g.n_hi = n_hi
			_fill_node(g.hi, n_hi)
		if n_lo != g.n_lo:
			g.n_lo = n_lo
			_fill_node(g.lo, n_lo)


## Mérőszám: látható csempék, részletes/egyszerű csomók, alapréteg.
func grass_info(cam: Camera3D = null) -> String:
	var nt := 0
	var hi := 0
	var lo := 0
	var planes: Array = cam.get_frustum() if cam else []
	for g in groups:
		for key in ["hi", "lo"]:
			var node: MultiMeshInstance3D = g[key]
			if not node.visible or node.multimesh == null:
				continue
			var box: AABB = node.global_transform * node.multimesh.custom_aabb
			var inside := true
			for pl in planes:
				var p := pl as Plane
				var far := box.position + Vector3(box.size.x if p.normal.x < 0 else 0.0, box.size.y if p.normal.y < 0 else 0.0, box.size.z if p.normal.z < 0 else 0.0)
				if p.distance_to(far) > 0.0:
					inside = false
					break
			if not inside:
				continue
			nt += 1
			if key == "hi":
				hi += node.multimesh.instance_count
			else:
				lo += node.multimesh.instance_count
	return "fű: %d rajzolás, %d részletes + %d egyszerű csomó-hely" % [nt, hi, lo]


func set_grass_mult(m: float) -> void:
	if is_equal_approx(m, grass_mult):
		return
	grass_mult = m
	_update_tiles()


## Méréshez: a fű teljesen ki-be kapcsolható.
func set_grass(on: bool) -> void:
	grass_on = on
	for g in groups:
		g.n_hi = []
		g.n_lo = []
	_update_tiles()


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
	return name_for(code)


## A bolygó neve a kódjából (a háttérben látszó kis bolygókhoz is, lásd planet_system.gd).
static func name_for(planet_code: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(planet_code + "nev")
	var a := ["Ael", "Bri", "Cel", "Dor", "Eli", "Fae", "Ila", "Lio", "Mir", "Nai", "Ori", "Sel", "Tal", "Ves"]
	var b := ["ra", "nde", "sa", "ra", "lune", "thea", "mira", "nis", "vel", "dora"]
	return "%s%s" % [a[r.randi() % a.size()], b[r.randi() % b.size()]]


func describe() -> String:
	if bare:
		return "csupasz, fiatal bolygó · még nincs alapító fája · az első kikelő fa adja meg a jellegét"
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
