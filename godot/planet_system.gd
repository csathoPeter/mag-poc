class_name PlanetSystem
extends Node3D
## A játékos bolygói egymás mellett (M7): a többi bolygó a háttérben, új bolygó születése, bolygóváltás (átrepülés).
##  - Kis bolygók: az aktív bolygó (a teljes, main.gd + planet.gd) mellett a többi csak olcsó változatban látszik:
##    egy alacsony felbontású gömb a bolygó színeivel (Planet.look_of: ugyanaz a bolygó-DNS), légkör-perem, és a fák
##    apró pöttyökként a shaderben (legfeljebb 16; a kikelésre váró meleg fénnyel lüktet). Gyűrűs bolygónál gyűrű.
##    Egy kis bolygó ~360 háromszög (gyűrűvel ~520); mind látszik, 16 bolygónál is csak ~6k háromszög.
##    Átlátszatlan anyagok (az áttűnés pontrácsos): az átlátszókat a lencse-utófeldolgozás lefedné.
##  - Hol (2026. 11. 11.): a 3D-térben, mint a csillagok, csak közelebb. Minden bolygónak állandó helye van (a
##    játékoskódból és a sorszámából: space_point – egy lassan növő, háromdimenziós fürt, az új bolygó a régiektől
##    távol kerül, a meglévők sosem mozdulnak el). A hely a világhoz rögzített (az aktív bolygó a középpont: a többi
##    a hozzá mért különbség), így forgatáskor valódi parallaxissal mozognak. Kicsinyítéskor (csípés, orbit_zoom 0
##    alá, lásd main._orbit_pose) tűnnek elő; közelről és leszállva nem látszanak; ami a kamerához túl közel kerül,
##    elhalványul.
##  - Átfogó nézet (orbit_zoom ZOOM_MIN alatt ZOOM_ALL-ig): a kamera kihúzódik, hogy az egész fürt beférjen
##    (overview_pose: a fürt közepére néz, a bolygó-nézet forgatásával körbejárható), mindegyik bolygó alatt a neve és
##    a fák száma. Koppintás egy bolygóra: átrepülés; az aktívra: vissza közelre (main._tap). Tovább kifelé: a
##    kozmosz (sky_stars.gd), a fürt körül a csillagokkal.
##  - Születés (birth): ha az utolsó bolygó megtelt (GameState.ensure_next_planet), a következő nyugodt pillanatban
##    a kamera az átfogó nézetbe húzódik (hogy az új bolygó helye biztosan a képben legyen), a bolygó peremén fénypont gyúl, ívben kiúszik a helyére, ott szétnyílik (fénygyűrű), és
##    fehéren izzó gömbből kibomlik a csupasz, halvány új bolygó, ami lassan a pályájára áll. Felirat. ~10 mp,
##    koppintás gyorsít. Utána born_seen = igaz (mentve).
##  - Váltás (hop): egy kis bolygóra koppintva a kamera felé fordul, lágyan odarepül, a légkörébe érve egy pillanatra
##    a pára színe tölti be a képet – ekkor cserélődik a teljes bolygó (main._hop_swap: aktív index, mentés,
##    show_saved_planet; a fák a meglévő sorbaállítással épülnek), és a kamera a pára mögül az új bolygó elé ér.
##
## A főjelenet (main.gd) tagjait használja, ezért a host típus nélküli: game, saved_view, garden_mode, view, focus,
## orbit_q, orbit_zoom, eye, look, up_v, cam, planet, night, queue, retreating, board, bag, crossing, fx, hatching,
## herb, stars, share, bench_on, _fit_dist().

## A váltás közepén (a pára mögött): a hívó lecseréli a teljes bolygót erre az indexre, majd after_swap()-et hív.
signal swap(index: int)
## Megérkeztünk az új bolygóhoz.
signal arrived(index: int)
## Véget ért egy bolygó születése (born_seen már igaz és mentve).
signal born(index: int)

const MINI := preload("res://shaders/planet_mini.gdshader")
const RING := preload("res://shaders/planet_mini_ring.gdshader")

const MAX_DOTS := 16
## Kicsinyítés: orbit_zoom legfeljebb ZOOM_MIN-ig mehet 0 alá; ott a kamera (1 + PULL)-szor messzebb van a felszíntől.
const ZOOM_MIN := -1.0
const PULL := 1.0
## Átfogó nézet: ZOOM_MIN alatt ZOOM_ALL-ig úszik át (ov 0 → 1).
const ZOOM_ALL := -2.0
## Az átfogó nézetben a kis bolygók a valódi méretük ennyiszeresén látszanak (az aktív a valódi méretén).
const OV_SCALE := .8
## A bolygók a térben: a k. bolygó a fürt közepétől kb. SP_UNIT·∛k-ra (így a fürt sűrűsége állandó), a jelöltek közül
## a már meglévőktől legtávolabbi helyre (SP_TRIES próba). 16 bolygónál a fürt sugara ~47, a csillagoké 62-től kezdődik.
const SP_UNIT := 19.0
const SP_TRIES := 28
## Ennél a kicsinyítésnél áll a kamera a születés után; érkezéskor ide (ZOOM_ARRIVE); a régi képek alapja (ZOOM_REF).
const ZOOM_REF := -.9
const ZOOM_BIRTH := -2.0
const ZOOM_ARRIVE := -.3
## A kis bolygók a valódi méretük ennyiszeresén látszanak (a háttérben kisebbek, így nem zsúfolódnak); a váltáskor a
## cél az út során lassan a valódi méretére nő (a csere a pára mögött így nem ugrik).
const MINI_SCALE := .62

## Születés idővonala (mp): kicsinyítés, a fénypont kigyúl (B_KINDLE), kiúszik (B_FLY0–B_FLY1), szétnyílik
## (B_BLOOM), a gömb kibomlik (B_OPEN-ig), felirat (B_TEXT), vége (B_LEN).
const B_KINDLE := 1.3
const B_FLY0 := 2.3
const B_FLY1 := 5.7
const B_BLOOM := 5.8
const B_OPEN := 7.6
const B_TEXT := 7.0
const B_LEN := 10.5
## Az újszülött a helye ennyiszeresén nyílik ki, onnan úszik ki lassan a pályájára.
const B_SETTLE := .8
const CAPTION_HOLD := 6.0
## Váltás idővonala (mp): a kamera felé fordul (H_TURN), elindul (H_MOVE0), a pára (H_VEIL0–H_VEIL1), csere (H_SWAP).
const H_TURN := 1.3
const H_MOVE0 := .25
const H_SWAP := 2.95
const H_VEIL0 := 2.15
const H_VEIL1 := 4.0
const H_LEN := 4.0
const TRAIL := 10

var host
## Kis bolygók: {"i" (index), "node", "mat", "ring", "rmat", "r" (sugár), "born" (0–1 méret),
## "fade" (0–1 előtűnés), "settle", "bloom", "ringed", "atmo" (szín), "name", "world"}
var minis: Array = []
var sys_q := Quaternion.IDENTITY
var vis := 0.0
## A futó születés: {"i", "t", "m", "S" (a fény indulása), "W" (a kibomlás helye), "done": {}}
var birth := {}
## A futó váltás: {"to", "t", "e0", "l0", "u0", "T" (a cél középpontja), "e1", "shift", "swapped", "after", "col"}
var hop := {}
## Képernyőképhez: a születés / váltás ennél az időpontnál áll (-1 = fut); snap: azonnal a végállapot.
var freeze_at := -1.0
var snap := false
var speed := 1.0
## Átfogó nézet: 0 = a megszokott kicsinyítés, 1 = minden bolygó a spirálban (puhán követi az orbit_zoom-ot).
var ov := 0.0

var _sys_set := false
var _sphere := SphereMesh.new()
var _ring_mesh: ArrayMesh
var _layer := CanvasLayer.new()
var _veil := ColorRect.new()
var _canvas := Control.new()
var _caption := Label.new()
var _cap_until := -1.0
var _fx: Array = []
var _rings: Array = []
var _t := 0.0
## A bolygók helye a térben (sorszám → pont a fürt keretében; a játékoskódból, lustán bővítve) és melyik kódhoz.
var _space: Array = []
var _space_code := ""
## Átfogó nézet: a fürt közepe (az aktív bolygóhoz mérve) és a befoglaló gömb sugara (a bolygók sugarával).
var _ov_center := Vector3.ZERO
var _ov_rad := 10.0
var _names := Control.new()
var _names_a := 0.0


func _ready() -> void:
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 20
	_sphere.rings = 10
	_ring_mesh = _make_ring(40)
	# a 3D-kép fölött, a gombsor alatt (a csillagok rajza után: a pára azt is betakarja)
	_layer.layer = 0
	add_child(_layer)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = false
	_layer.add_child(_veil)
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_canvas.material = cm
	_canvas.draw.connect(_draw_fx)
	_layer.add_child(_canvas)
	# az átfogó nézet feliratai (a bolygók neve alattuk; nem additív)
	_names.set_anchors_preset(Control.PRESET_FULL_RECT)
	_names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_names.draw.connect(_draw_names)
	_layer.add_child(_names)
	_caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_color", Color(1, .97, .92))
	_caption.add_theme_color_override("font_outline_color", Color(.12, .08, .22, .55))
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .35))
	_caption.modulate.a = 0.0
	_layer.add_child(_caption)


func _make_ring(seg: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg + 1:
		var a := float(i) / seg * TAU
		var d := Vector3(cos(a), 0, sin(a))
		st.set_uv(Vector2(0, float(i) / seg)); st.add_vertex(d * 1.5)
		st.set_uv(Vector2(1, float(i) / seg)); st.add_vertex(d * 2.15)
	for i in seg:
		var a := i * 2
		st.add_index(a); st.add_index(a + 1); st.add_index(a + 2)
		st.add_index(a + 1); st.add_index(a + 3); st.add_index(a + 2)
	return st.commit()


# ---------------------------------------------------------------- Kis bolygók

## A kis bolygók a mentésből: az aktív kivételével mind, mindegyik a saját helyén a térben. A meglévők állapota megmarad.
func sync() -> void:
	var want := {}
	var ps: Array = []
	if host != null and host.saved_view and not host.game.data.is_empty() and host.garden_mode == "planet":
		ps = host.game.data.planets
		var act: int = host.game.active_index()
		for i in ps.size():
			if i != act:
				want[i] = i - act
	var old := {}
	for m in minis:
		old[int(m.i)] = m
	minis.clear()
	for i in want:
		var m: Dictionary = old.get(i, {})
		if m.is_empty():
			m = _make_mini(int(i))
		else:
			old.erase(i)
		m.near = true
		_paint(m, ps[i])
		minis.append(m)
	for k in old:
		(old[k].node as Node3D).queue_free()
	_layout()


## A bolygók helye a térben: a fürt keretében (a 0. bolygó a közepe). A k. pont a fürt közepétől kb. SP_UNIT·∛k-ra,
## SP_TRIES véletlen (a játékoskódból és k-ból) jelölt közül arra, amelyik a meglévőktől a legtávolabb esik. Csak a
## korábbi pontoktól függ, így egy új bolygó a régieket sosem mozdítja el.
func space_point(k: int) -> Vector3:
	var code := str(host.game.data.get("player", "")) if host != null and not host.game.data.is_empty() else ""
	if code != _space_code:
		_space_code = code
		_space.clear()
	while _space.size() <= k:
		var n := _space.size()
		if n == 0:
			_space.append(Vector3.ZERO)
			continue
		var r := RandomNumberGenerator.new()
		r.seed = hash(code + "terben" + str(n))
		var rk := SP_UNIT * pow(float(n), 1.0 / 3.0)
		var best := Vector3.ZERO
		var best_d := -1.0
		for c in SP_TRIES:
			var z := r.randf_range(-1.0, 1.0)
			var a := r.randf() * TAU
			var q := sqrt(1.0 - z * z)
			var p := Vector3(q * cos(a), z * .8, q * sin(a)) * rk * r.randf_range(.88, 1.12)
			var md := 1e9
			for e in _space:
				md = minf(md, p.distance_to(e))
			if md > best_d:
				best_d = md
				best = p
		_space.append(best)
	return _space[k]


## Az i. bolygó helye a világban (az aktív bolygó a középpont).
func space_pos(i: int) -> Vector3:
	var act: int = host.game.active_index() if not host.game.data.is_empty() else 0
	return space_point(i) - space_point(act)


## A fürt közepe (a 0. bolygó helye) a világban: a csillagok héja és a kozmosz háttere ehhez igazodik.
func space_origin() -> Vector3:
	if host == null or host.game.data.is_empty() or not host.saved_view:
		return Vector3.ZERO
	return -space_point(host.game.active_index())


## Az átfogó nézet kerete: a fürt közepe és a befoglaló gömb (a bolygók sugarával, alattuk a névnek is hellyel).
func _layout() -> void:
	if minis.is_empty() or host.game.data.is_empty():
		_ov_center = Vector3.ZERO
		_ov_rad = 10.0
		return
	var pts: Array = [[Vector3.ZERO, float(host.planet.radius_target) * 1.15]]
	for m in minis:
		pts.append([space_pos(int(m.i)), float(m.r) * OV_SCALE])
	var c := Vector3.ZERO
	for e in pts:
		c += e[0]
	c /= float(pts.size())
	var rad := 0.0
	for e in pts:
		rad = maxf(rad, c.distance_to(e[0]) + float(e[1]) + 2.5)
	_ov_center = c
	_ov_rad = rad


## Az átfogó nézet (0–1, simítva) – a kamera (main._orbit_pose) ezzel keveri az overview_pose()-t.
func overview() -> float:
	return _smooth(ov)


## Az átfogó nézet kamerája: [szem, nézett pont, fel] – szemből az egész spirál, álló és fekvő képen is befér.
func overview_pose() -> Array:
	var b := Basis(host.orbit_q)
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var tv := tan(deg_to_rad(40.0) * .5)
	var th := tv * maxf(vp.x, 1.0) / maxf(vp.y, 1.0)
	# a fürt befoglaló gömbje beférjen (álló képen a szélesség a szűkebb; fent a felirat, lent a táska: szegély)
	var d := _ov_rad * 1.12 / sin(atan(minf(tv * .85, th)))
	return [_ov_center + b.z * d, _ov_center, b.y]


## Koppintás az aktív bolygóra (az átfogó nézetben: vissza közelre).
func pick_active(pos: Vector2) -> bool:
	var cam: Camera3D = host.cam
	var planet: Planet = host.planet
	var w := planet.global_position
	if cam.is_position_behind(w):
		return false
	var c := cam.unproject_position(w)
	var rpx := c.distance_to(cam.unproject_position(w + cam.global_transform.basis.x * planet.radius))
	return c.distance_to(pos) < maxf(rpx * 1.3, 34.0)


func _make_mini(i: int) -> Dictionary:
	var node := Node3D.new()
	node.visible = false
	add_child(node)
	var mat := ShaderMaterial.new()
	mat.shader = MINI
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	var rmat := ShaderMaterial.new()
	rmat.shader = RING
	var rg := MeshInstance3D.new()
	rg.mesh = _ring_mesh
	rg.material_override = rmat
	rg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rg.visible = false
	node.add_child(rg)
	return {"i": i, "node": node, "mat": mat, "ring": rg, "rmat": rmat, "r": 4.0, "born": 1.0,
		"fade": 0.0, "settle": 1.0, "bloom": 0.0, "ringed": false, "atmo": Planet.BARE_ATMO, "name": "", "world": Vector3.ZERO,
		"near": true, "sub": "", "a": 0.0, "vr": 0.0}


## A kis bolygó kinézete a bolygó mentett adataiból: színek a látott fákból (mint a teljes bolygón), méret, fapöttyök.
func _paint(m: Dictionary, p: Dictionary) -> void:
	var game: GameState = host.game
	var today := GameState.today()
	var dnas: Array = []
	var grown: Array = []
	var waiting: Array = []
	for t in p.trees:
		var dna: Array = t.dna
		var d: Vector3 = (t.dir as Vector3).normalized()
		if int(t.hatch) > today:
			waiting.append([Vector4(d.x, d.y, d.z, .08), Color(1, .86, .6), 2.0])
		elif not bool(t.revealed):
			waiting.push_front([Vector4(d.x, d.y, d.z, .11), Color(1, .84, .55), 1.0])
		else:
			dnas.append(dna)
			var col := Genes.allele_color(5, dna[5]).lerp(Genes.allele_color(0, dna[0]), .4)
			grown.append([Vector4(d.x, d.y, d.z, .12), col * .85, 0.0])
	var founders: Array = p.founders
	var bare := game.is_bare(p)
	var base: Array = dnas if not dnas.is_empty() else founders
	var look := {}
	if bare or base.is_empty():
		bare = true
		look = {"rock": Planet.BARE_ROCK, "grass": Planet.BARE_GRASS, "atmo": Planet.BARE_ATMO, "moon": Planet.BARE_ATMO}
	else:
		look = Planet.look_of(base, 0.0)
	m.r = Planet.radius_for(maxi(dnas.size(), int(p.peak)))
	m.ringed = not bare and not founders.is_empty() and bool(Planet.RINGED[int(founders[0][1])])
	m.atmo = look.atmo
	m.name = Planet.name_for(str(p.code))
	m.sub = _sub_line(bare, grown.size())
	if birth.is_empty() or int(birth.i) != int(m.i):
		m.born = 1.0 if bool(p.born_seen) else 0.0
		m.bloom = 0.0
		m.settle = 1.0
	var mat: ShaderMaterial = m.mat
	mat.set_shader_parameter("rock", look.rock)
	mat.set_shader_parameter("grass", look.grass)
	mat.set_shader_parameter("atmo", look.atmo)
	mat.set_shader_parameter("seed", float(hash(str(p.code)) % 997) / 31.0)
	mat.set_shader_parameter("patches", 0.0 if bare else 1.0)
	var all: Array = waiting + grown
	var dv := PackedVector4Array()
	var dc := PackedVector4Array()
	for k in MAX_DOTS:
		if k < all.size():
			var e: Array = all[k]
			var c: Color = e[1]
			dv.append(e[0])
			dc.append(Vector4(c.r, c.g, c.b, float(e[2])))
		else:
			dv.append(Vector4(0, 1, 0, 0))
			dc.append(Vector4.ZERO)
	mat.set_shader_parameter("dots", dv)
	mat.set_shader_parameter("dot_cols", dc)
	mat.set_shader_parameter("dot_n", mini(all.size(), MAX_DOTS))
	var rmat: ShaderMaterial = m.rmat
	rmat.set_shader_parameter("col_a", look.atmo)
	rmat.set_shader_parameter("col_b", look.moon)
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(p.code) + "gyuru")
	(m.ring as Node3D).rotation = Vector3(r.randf_range(.25, .5), r.randf() * TAU, r.randf_range(-.2, .2))
	rmat.set_shader_parameter("seed", r.randf() * 10.0)


## A név alatti sor az átfogó nézetben.
static func _sub_line(bare: bool, n: int) -> String:
	return "még csupasz" if bare else "%d fa" % n


func _mini_of(i: int) -> Dictionary:
	for m in minis:
		if int(m.i) == i:
			return m
	return {}


## A kis bolygó helye a világban: a térbeli helye (születéskor közelebb indul, és onnan úszik ki: settle).
func _pos_world(m: Dictionary) -> Vector3:
	return space_pos(int(m.i)) * float(m.settle)


## A kamera távolsága a bolygó középpontjától a bolygó-nézetben, z közelségnél (z < 0: kicsinyítve; main._orbit_pose).
static func pull(z: float) -> float:
	return 1.0 + PULL * clampf(-z, 0.0, -ZOOM_MIN)


## Meddig lehet kicsinyíteni: 0 alá, a többi bolygón (több bolygónál az átfogó nézeten) túl a kozmoszig, a csillagok
## közé (sky_stars.gd); születés és váltás közben a megszokottig.
func min_zoom() -> float:
	if busy():
		return ZOOM_ALL
	return host.stars.stars_zoom()


func busy() -> bool:
	return not birth.is_empty() or not hop.is_empty()


func flying() -> bool:
	return not hop.is_empty()


func skip() -> void:
	if busy() and freeze_at < 0.0:
		speed = 3.0


## A koppintáshoz tartozó kis bolygó indexe, vagy -1 (csak ha látszanak, és nem takarja az aktív bolygó).
func pick(pos: Vector2) -> int:
	if vis < .5 or busy():
		return -1
	var cam: Camera3D = host.cam
	var best := -1
	var best_s := 1.0
	for m in minis:
		if float(m.born) < .5 or not (m.node as Node3D).visible:
			continue
		var w: Vector3 = m.world
		if cam.is_position_behind(w):
			continue
		var o := cam.global_position
		var dir := (w - o).normalized()
		var planet: Planet = host.planet
		if SkyStars._hits(o, dir, 1e9, planet.global_position, planet.radius * planet.radius) and o.distance_to(planet.global_position) < o.distance_to(w):
			continue
		var c := cam.unproject_position(w)
		var rpx := c.distance_to(cam.unproject_position(w + cam.global_transform.basis.x * float(m.r) * MINI_SCALE))
		var s := c.distance_to(pos) / maxf(rpx * 1.45, 34.0)
		if s < best_s:
			best_s = s
			best = int(m.i)
	return best


## Mérőszám (--shot STATS): a látszó kis bolygók, helyük a képen és a háromszögszámuk.
func info() -> String:
	var parts: Array = []
	var tris := 0
	for m in minis:
		var node: Node3D = m.node
		if not node.visible:
			continue
		var t := _sphere.get_faces().size() / 3 + ((_ring_mesh.get_faces().size() / 3) if (m.ring as Node3D).visible else 0)
		tris += t
		parts.append("#%d %s @%s r%.1f" % [int(m.i) + 1, m.name, host.cam.unproject_position(m.world).round(), float(m.r) * MINI_SCALE])
	return "kis bolygók: %d (%d háromszög) %s" % [parts.size(), tris, " ".join(parts)]


## Az i. kis bolygó helye a képen (teszthez), vagy (-1, -1).
func screen_pos(i: int) -> Vector2:
	var m := _mini_of(i)
	if m.is_empty():
		return Vector2(-1, -1)
	return host.cam.unproject_position(m.world)


# ---------------------------------------------------------------- Képkockánként

func _process(delta: float) -> void:
	_t += delta
	var on: bool = host != null and host.garden_mode == "planet" and host.saved_view
	_canvas.visible = on
	if not on:
		_names.visible = false
		for m in minis:
			(m.node as Node3D).visible = false
		_veil.visible = false
		_caption.modulate.a = 0.0
		return
	var dt := delta * speed
	_fx.clear()
	_rings.clear()
	if not hop.is_empty():
		_step_hop(dt)
	if not birth.is_empty():
		_step_birth(dt)
	elif hop.is_empty() and _can_start():
		_check_births()
	if not busy():
		speed = 1.0
	# a rendszer kerete a bolygó-nézet forgatását puhán követi (a születés és a váltás alatt áll)
	if not _sys_set or snap:
		sys_q = host.orbit_q
		_sys_set = true
	elif not busy():
		sys_q = sys_q.slerp(host.orbit_q, 1.0 - exp(-delta * lerpf(1.4, 8.0, _smooth(ov)))).normalized()
	var want := 1.0
	if not busy():
		want = (1.0 - smoothstep(0.0, .35, float(host.orbit_zoom))) if host.view == "orbit" or int(host.focus) < 0 else 0.0
	vis = want if snap else lerpf(vis, want, 1.0 - exp(-delta * (3.0 if want > vis else 5.0)))
	# átfogó nézet: a váltás alatt áll (a csere után after_swap nullázza); születéskor is ide húzódik a kamera
	if hop.is_empty():
		var ov_want := 0.0
		if minis.size() > 0 and (host.view == "orbit" or int(host.focus) < 0):
			ov_want = clampf((ZOOM_MIN - float(host.orbit_zoom)) / (ZOOM_MIN - ZOOM_ALL), 0.0, 1.0)
		ov = ov_want if snap else lerpf(ov, ov_want, 1.0 - exp(-delta * 4.0))
		if absf(ov - ov_want) < .001:
			ov = ov_want
	_place(delta)
	# a nevek a kozmoszban elhalványulnak (ott a bolygók kicsik, a csillagoké a kép)
	var na: float = _smooth((ov - .55) / .4) * (1.0 - float(host.stars.cosmos())) if not busy() else 0.0
	_names_a = na if snap else lerpf(_names_a, na, 1.0 - exp(-delta * (3.0 if na > _names_a else 8.0)))
	_names.visible = _names_a > .01
	if _names.visible:
		_names.queue_redraw()
	# a felirat a születés után még egy ideig marad, aztán elhalványul
	var cap_a := 1.0 if _t < _cap_until else 0.0
	_caption.modulate.a = cap_a if snap else lerpf(_caption.modulate.a, cap_a, 1.0 - exp(-delta * (2.0 if cap_a > 0.0 else 1.2)))
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	_caption.offset_bottom = -vp.y * .05
	_caption.offset_left = 28.0
	_caption.offset_right = -28.0
	_canvas.queue_redraw()


func _place(delta: float) -> void:
	var night: float = clampf(float(host.night), 0.0, 1.0)
	var eye: Vector3 = host.cam.global_position
	for m in minis:
		m.fade = minf(1.0, float(m.fade) + delta * 1.3) if not snap else 1.0
		var w := _pos_world(m)
		m.world = w
		var node: Node3D = m.node
		var born := float(m.born)
		var a := vis * float(m.fade)
		# ami a kamerához túl közel kerül (a kamera a fürtön belül jár), elhalványul
		var rr := float(m.r) * OV_SCALE
		a *= clampf((eye.distance_to(w) - rr * 1.6) / (rr * 2.5), 0.0, 1.0)
		m.a = a
		node.visible = a > .005 and born > .002
		if not node.visible:
			continue
		node.position = w
		var k0 := lerpf(MINI_SCALE, OV_SCALE, _smooth(ov))
		var k := k0
		if not hop.is_empty() and int(hop.to) == int(m.i):
			k = lerpf(k0, 1.0, _smooth(float(hop.t) / H_SWAP))
		m.vr = float(m.r) * born * k
		node.scale = Vector3.ONE * float(m.vr)
		var mat: ShaderMaterial = m.mat
		mat.set_shader_parameter("fade", a)
		mat.set_shader_parameter("night", night)
		mat.set_shader_parameter("bloom", float(m.bloom))
		var rmat: ShaderMaterial = m.rmat
		rmat.set_shader_parameter("night", night)
		rmat.set_shader_parameter("fade", a * _smooth((born - .6) / .4))
		(m.ring as Node3D).visible = bool(m.ringed) and born > .6


func _can_start() -> bool:
	return host.garden_mode == "planet" and host.saved_view and (host.queue as Array).is_empty() and not host.retreating \
		and not host.board.visible and not host.bag.visible and not host.crossing.is_open() and not host.fx.busy() and not host.bench_on \
		and not host.herb.is_open() and not host.stars.busy() and not host.hatching.active() and (host.hatching.waiting as Array).is_empty() \
		and not host.share.is_open()


## A még nem látott születés: ha az aktív bolygó mellett (index + 1) született, megmutatjuk; ha máshol (ritka), csak jelöljük.
func _check_births() -> void:
	var ps: Array = host.game.data.planets
	var act: int = host.game.active_index()
	for i in ps.size():
		if bool(ps[i].born_seen):
			continue
		if i == act + 1:
			start_birth(i)
			return
		ps[i].born_seen = true
		host.game.save()


# ---------------------------------------------------------------- Születés

func start_birth(i: int) -> void:
	sync()
	var m := _mini_of(i)
	if m.is_empty():
		host.game.data.planets[i].born_seen = true
		host.game.save()
		return
	host.begin_birth()
	sys_q = host.orbit_q
	m.born = 0.0
	m.bloom = 1.0
	m.settle = B_SETTLE
	m.fade = 1.0
	_layout()
	# a fény a bolygó peremén gyúl, az újszülött felőli oldalon, a kép síkjában (hogy látsszon), onnan ívben úszik ki
	var b := Basis(sys_q)
	var w: Vector3 = space_pos(i) * B_SETTLE
	var f := -b.z
	var wp := w - f * w.dot(f)
	var side := b.x * signf(wp.dot(b.x) + .001)
	var s := (wp.normalized() * .35 + side).normalized() * float(host.planet.radius_target) * 1.08
	birth = {"i": i, "t": freeze_at if freeze_at >= 0.0 else 0.0, "m": m, "S": s, "W": w, "done": {}}
	_step_birth(0.0)


func _step_birth(dt: float) -> void:
	var m: Dictionary = birth.m
	if freeze_at < 0.0:
		birth.t = float(birth.t) + dt
	var tt := float(birth.t)
	var s: Vector3 = birth.S
	var w: Vector3 = birth.W
	var cam: Camera3D = host.cam
	var col := Color(1, .84, .58)
	# 1. a fénypont kigyúl a perem fölött, pislákol
	var kindle := _smooth((tt - B_KINDLE) / .9)
	if tt >= B_KINDLE and not birth.done.has("snd_kindle"):
		birth.done.snd_kindle = true
		Sound.fx("kindle")
	if tt >= B_BLOOM - .2 and not birth.done.has("snd_bloom"):
		birth.done.snd_bloom = true
		Sound.fx("birth")
	var u := _smooth((tt - B_FLY0) / (B_FLY1 - B_FLY0))
	var b := Basis(sys_q)
	var out := b.x * signf(s.dot(b.x) + .001)
	var bulge := (cam.global_position - w).normalized() * s.distance_to(w) * .15 + out * s.distance_to(w) * .45
	var c := s.lerp(w, .5) + bulge
	var head_a := kindle * (1.0 - _smooth((tt - B_BLOOM - .1) / .6))
	if head_a > .001:
		var flick := 1.0 + .18 * sin(_t * 9.0) * (1.0 - u)
		_fx_dot(_bez(s, c, w, u), 1.0 + .5 * u, 9.0, col, head_a * 1.5 * flick)
		# csóva: a megtett út mentén
		if u > .01 and u < .999:
			for k in range(1, TRAIL + 1):
				var uk := clampf(u - k * .028, 0.0, 1.0)
				_fx_dot(_bez(s, c, w, uk), .7 - k * .05, 5.0 - k * .3, col, head_a * 1.1 * (1.0 - float(k) / (TRAIL + 1)))
	# 2. szétnyílik: fénygyűrű, a gömb fehéren izzó fényből kibomlik, és lassan a pályájára áll
	var rb := tt - (B_BLOOM - .1)
	if rb > 0.0 and rb < 1.6:
		var sp := cam.unproject_position(w)
		var rpx := sp.distance_to(cam.unproject_position(w + cam.global_transform.basis.x * float(m.r) * MINI_SCALE))
		_rings.append([sp, lerpf(rpx * .3, rpx * 2.6, _smooth(rb / 1.4)), col, 1.4 * (1.0 - _smooth((rb - .3) / 1.2))])
	m.born = _back_out(clampf((tt - B_BLOOM) / (B_OPEN - B_BLOOM), 0.0, 1.0))
	m.bloom = 1.0 - _smooth((tt - B_BLOOM - .4) / 2.6)
	m.settle = lerpf(B_SETTLE, 1.0, _smooth((tt - B_BLOOM) / (B_LEN - B_BLOOM + .5)))
	if tt >= B_TEXT and not birth.done.has("text"):
		birth.done.text = true
		var ps: Array = host.game.data.planets
		var old_name := Planet.name_for(str(ps[int(birth.i) - 1].code)) if int(birth.i) > 0 else ""
		_caption.text = "%s megtelt. Mellette megszületett %s.\nA következő elvetett magod már oda hull.\nKoppints rá, és odarepülsz." % [old_name, m.name]
		_cap_until = _t + 1e6
	if tt >= B_LEN and freeze_at < 0.0:
		var i := int(birth.i)
		m.born = 1.0
		m.bloom = 0.0
		m.settle = 1.0
		birth = {}
		_cap_until = _t + CAPTION_HOLD
		var p: Dictionary = host.game.data.planets[i]
		p.born_seen = true
		host.game.save()
		born.emit(i)


# ---------------------------------------------------------------- Váltás

## Átrepülés az i. bolygóhoz; utána (ha van) after hívódik (pl. az elvetés folytatása). Hamis, ha nem indulhat.
func go(i: int, after := Callable()) -> bool:
	if busy() or host.game.data.is_empty() or i == host.game.active_index() or i < 0 or i >= (host.game.data.planets as Array).size():
		return false
	var m := _mini_of(i)
	var t: Vector3
	var r: float
	var col: Color
	if m.is_empty():
		# messzi bolygó (nincs kis változata): a helye a sorszám-különbségből
		sync()
		m = _mini_of(i)
	# a rendszer kerete a kamerához áll (a cél helye már ebben a keretben)
	sys_q = host.orbit_q
	if m.is_empty():
		var p: Dictionary = host.game.data.planets[i]
		t = space_pos(i)
		r = Planet.radius_for(maxi(host.game.hatched(p).size(), int(p.peak)))
		col = Planet.BARE_ATMO
	else:
		t = _pos_world(m)
		m.world = t
		r = float(m.r)
		col = m.atmo
	var e0: Vector3 = host.eye
	var fit: float = host._fit_dist(r)
	var dir := (e0 - t).normalized()
	var e1 := t + dir * (r + (fit - r) * pull(ZOOM_ARRIVE))
	hop = {"to": i, "t": freeze_at if freeze_at >= 0.0 else 0.0, "e0": e0, "l0": host.look, "u0": (host.up_v as Vector3).normalized(), "T": t,
		"e1": e1, "dir": dir, "shift": Vector3.ZERO, "swapped": false, "after": after, "col": col.lerp(Color(1, .98, .95), .35)}
	_cap_until = -1.0
	Sound.fx("hop")
	host.begin_hop()
	_step_hop(0.0)
	return true


## A kamera a váltás alatt: [szem, nézett pont, fel] (a csere után az új bolygó a középpont).
func hop_pose() -> Array:
	var tt := float(hop.t)
	var e0: Vector3 = hop.e0
	var e1: Vector3 = hop.e1
	var u0: Vector3 = hop.u0
	var turn := _smooth(tt / H_TURN)
	var mv := _smooth((tt - H_MOVE0) / (H_LEN - .3 - H_MOVE0))
	var c := e0.lerp(e1, .5) + u0 * e0.distance_to(e1) * .12
	var eye := _bez(e0, c, e1, mv)
	var look := (hop.l0 as Vector3).lerp(hop.T, turn)
	var sh: Vector3 = hop.shift
	return [eye - sh, look - sh, u0]


## Az érkezés iránya és a fel-irány (a hívó ebből állítja be a bolygó-nézetet a csere után).
func hop_arrival() -> Array:
	return [hop.dir, hop.u0]


## A hívó lecserélte a teljes bolygót: a további út az új bolygó középpontjához mérve.
func after_swap() -> void:
	hop.shift = hop.T
	sys_q = host.orbit_q
	_sys_set = true
	# a pára mögött: az új bolygó mellett a megszokott kicsinyítés (a fürt az új középponthoz mérve: ugyanaz a tér)
	ov = 0.0
	sync()


func _step_hop(dt: float) -> void:
	if freeze_at < 0.0:
		hop.t = float(hop.t) + dt
	var tt := float(hop.t)
	if tt >= H_SWAP and not bool(hop.swapped):
		hop.swapped = true
		Sound.fx("arrive")
		swap.emit(int(hop.to))
	var a := _smooth((tt - H_VEIL0) / (H_SWAP - H_VEIL0)) if tt < H_SWAP + .15 else 1.0 - _smooth((tt - H_SWAP - .15) / (H_VEIL1 - H_SWAP - .15))
	var col: Color = hop.col
	_veil.visible = a > .002
	_veil.color = Color(col.r, col.g, col.b, a * .93)
	if tt >= H_LEN and freeze_at < 0.0:
		var i := int(hop.to)
		var cb: Callable = hop.after
		hop = {}
		_veil.visible = false
		arrived.emit(i)
		if cb.is_valid():
			cb.call()


# ---------------------------------------------------------------- Rajz (2D, additív)

func _fx_dot(p: Vector3, size: float, min_px: float, col: Color, a: float) -> void:
	var cam: Camera3D = host.cam
	if cam.is_position_behind(p):
		return
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var px_unit: float = maxf(vp.y, 1.0) / (2.0 * tan(deg_to_rad(cam.fov) * .5))
	var d := maxf(cam.global_position.distance_to(p), .01)
	var r := clampf(size * px_unit / d * 1.6, min_px, 46.0)
	_fx.append([cam.unproject_position(p), r, col, a])


func _draw_fx() -> void:
	for d in _fx:
		var p: Vector2 = d[0]
		var r: float = d[1]
		var col: Color = d[2]
		var a: float = d[3]
		_canvas.draw_circle(p, r * 2.2, Color(col, minf(.05 * a, 1.0)))
		_canvas.draw_circle(p, r, Color(col, minf(.12 * a, 1.0)))
		_canvas.draw_circle(p, r * .5, Color(col, minf(.3 * a, 1.0)))
		_canvas.draw_circle(p, r * .24, Color(col.lerp(Color.WHITE, .6), minf(.8 * a, 1.0)))
		_canvas.draw_circle(p, r * .11, Color(1, 1, 1, minf(.7 * a, 1.0)))
	for rg in _rings:
		var col: Color = rg[2]
		var al: float = rg[3]
		_canvas.draw_arc(rg[0], rg[1], 0.0, TAU, 64, Color(col, minf(al * .22, 1.0)), 9.0, true)
		_canvas.draw_arc(rg[0], rg[1], 0.0, TAU, 64, Color(col, minf(al * .8, 1.0)), 2.2, true)


## Az átfogó nézet feliratai: minden látszó bolygó alatt a neve és a fák száma (az aktívé fényesebb).
func _draw_names() -> void:
	var cam: Camera3D = host.cam
	var font: Font = host.hud.thin_font
	var planet: Planet = host.planet
	var p: Dictionary = host.game.active_planet()
	var list: Array = [[planet.global_position, planet.radius, Planet.name_for(str(p.code)),
		_sub_line(host.game.is_bare(p), host.game.hatched(p).size()), 1.0]]
	for m in minis:
		if (m.node as Node3D).visible:
			list.append([m.world, float(m.vr), m.name, m.sub, float(m.a) * .82])
	var right := cam.global_transform.basis.x
	for e in list:
		var w: Vector3 = e[0]
		var a: float = float(e[4]) * _names_a
		if a < .01 or cam.is_position_behind(w):
			continue
		var c := cam.unproject_position(w)
		var rpx := c.distance_to(cam.unproject_position(w + right * float(e[1])))
		var y := c.y + rpx + 18.0
		_label(font, str(e[2]), Vector2(c.x, y), 15, a)
		_label(font, str(e[3]), Vector2(c.x, y + 15.0), 11, a * .75)


func _label(font: Font, text: String, at: Vector2, fs: int, a: float) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(at.x - w * .5, at.y)
	_names.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(.13, .08, .26, .45 * a))
	_names.draw_string(font, pos + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Hud.C_GLOW, .3 * a))
	_names.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Hud.C_TEXT, a))


static func _bez(a: Vector3, c: Vector3, b: Vector3, u: float) -> Vector3:
	return a.lerp(c, u).lerp(c.lerp(b, u), u)


static func _smooth(x: float) -> float:
	var v := clampf(x, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


## Rugalmas kinyílás, egy kis túllendüléssel.
static func _back_out(x: float) -> float:
	if x <= 0.0:
		return 0.0
	var k := 1.4
	var v := x - 1.0
	return 1.0 + v * v * ((k + 1.0) * v + k)
