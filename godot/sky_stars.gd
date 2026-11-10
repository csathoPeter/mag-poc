class_name SkyStars
extends Node3D
## Csillagok a bolygó egén (M6): az elengedett fák és a keresztezés el nem választott csírái csillagképet rajzolnak.
##  - A csillagkép alakja determinisztikus: a csillagok helye a bolygókódból és a csillag sorszámából (seq) jön, egy
##    lassan növő „ágas” mintával (minden új csillag egy korábbihoz kapcsolódik, a többitől távol). Egy csillag
##    visszahozása nem mozdítja el a többit; a vonalak a legközelebbi megmaradt őshöz kötnek.
##  - Hol látszik: a bolygó égboltja a kamera mögött lebeg, nagyon messze (mint a Hold az autóablakból): a kamera
##    forgásakor puhán lemaradva követi, így bolygó-nézetben a bolygó fölött, a háttérben, leszállva a fa mögötti égen
##    látszik. Telefonon (álló kép, keskeny látószög) egy rögzített égbolt-irány ritkán kerülne a képbe – ezért így.
##  - Nappal halványan, éjjel fényesen; a csillag színe a fa virágszínéből. Olcsó: a helyek 3D-ben (a kamerától
##    messze), a rajz 2D-ben (a 3D-kép fölött, a gombsor alatt, additív keveréssel: körök és vonalak, ≤64 csillag).
##    A bolygó és a fák eltakarják (sugár–gömb próba). Így weben is biztosan ugyanaz: a WebGL-es próbán a képkockánként
##    frissített MultiMesh-példányok nem rajzolódtak ki, a 2D rajz igen; és a lencse sem mossa el.
##  - Csillagkép-nézet (herbárium, herbarium.gd): a kamera kicsit felé fordul (tilt), a csillagkép megnő, a kiválasztott
##    csillag felé tolódik, gyűrű jelöli.
##  - Elengedés: a fa fénnyel átjárva, a csúcsaitól kezdve fénypontokká oszlik, a fények összegyűlnek a koronája fölött,
##    és egy fény lassan, csóvával felszáll az égre, ahol csillag lesz (release()). Visszahozás: a csillag felvillan és
##    elhalványul (recall()); a mag útja a táskába a 2D rétegben (herbarium.gd).
##
## A főjelenet (main.gd) tagjait használja, ezért a host típus nélküli: cam, planet, game, saved_view, garden_mode,
## night, trees, plants.

## Elengedéskor a fa eltűnt a jelenetből (a hívó kiveszi a fák közül, és felemeli a kamerát).
signal gone(tree: Dictionary)
## A felszálló fény megérkezett: a csillag kigyullad az égen.
signal arrived(star_id: int)

## A csillagok távolsága a kamerától (a bolygó és a holdak mögött).
const DIST := 150.0
const MAX_STARS := 64
## A csillagkép helye a kamera (lemaradva követett) keretében, érintősík-egységekben (tan szög; x jobbra, y fel):
## közép és fél-szélesség/-magasság, és egy elrendezés-egység legnagyobb mérete. Kint/lent és a csillagkép-nézetben.
const BOX_PASSIVE := Rect2(0.0, .255, .135, .075)
const UNIT_PASSIVE := .0105
const BOX_SKY := Rect2(0.0, .29, .155, .15)
const UNIT_SKY := .021
## A csillagkép-nézetben ennyivel fordul fel a kamera.
const TILT_SKY := .16
## Képpontban: a csillag (haló együtt) átmérője, a kiválasztott csillag gyűrűje, a vonal szélessége.
const PX_STAR := 26.0
const PX_RING := 58.0
const PX_LINE := 1.6
## A koppintás sugara (képpont): telefonon nagy érintési terület.
const TAP_R := 46.0

## Elengedés idővonala (mp): felragyogás, a fa a csúcsaitól fénnyé oszlik (UNGROW0–UNGROW1), a fények
## összegyűlnek, a fény felszáll (RISE0–RISE1), a csillag kigyullad, vége (LEN).
const R_UNGROW0 := .8
const R_UNGROW1 := 3.4
const R_RISE0 := 3.9
const R_RISE1 := 7.2
const R_LEN := 8.2
const MOTES := 42
const TRAIL := 8

var host
## Csillagok: [{"id", "seq", "rec", "col", "fade" (0–1), "leave" (-1 vagy a távozás ideje), "pos" (elrendezés)}]
var list: Array = []
## A csillagkép-nézet (herbárium) nyitva; a kiválasztott csillag azonosítója.
var sky_on := false
var selected := -1
## 0–1: átúszás a csillagkép-nézetbe; a kamera felfordulása (radián, a main.gd alkalmazza).
var sky_k := 0.0
var tilt := 0.0
## Képernyőképhez: azonnal a végállapot (nincs átúszás).
var snap := false
## Elengedés közben az érkező csillag rejtve (a felszálló fény ide tart).
var hidden_id := -1
## A futó elengedés: {"tree", "t", "star", "motes", "gone", "arrived", "col", "base", "n", "h", "g"}
var rel := {}
## Képernyőképhez: az elengedés ennél az időpontnál áll (-1 = fut).
var freeze_at := -1.0
var speed := 1.0

var _code := ""
var _layout: Array = []
var _sky_q := Quaternion.IDENTITY
var _sky_set := false
var _fit_c := Vector2.ZERO
var _fit_s := 0.0
var _pan := Vector2.ZERO
## a rajzréteg (a 3D fölött, a gombsor alatt) és a rajzlisták: csillagok, vonalak, gyűrű, az elengedés fényei
var _layer := CanvasLayer.new()
var _canvas := Control.new()
var _dots: Array = []
var _segs: Array = []
var _rings: Array = []
var _fx_dots: Array = []
var _t := 0.0
## a csillagok világbeli helye és képernyőhelye ebben a képkockában (id → Vector3 / Vector2)
var _world := {}
var _ring_t := -1.0
var _ring_id := -1
## Weben (Compatibility) nincs HDR-ragyogás: ott a fénnyé váló fa erősebb önfényt kap, hogy ugyanúgy kifehéredjen.
var _glow_peak := 2.6


func _ready() -> void:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_glow_peak = 5.0
	# a gombsor (1. réteg) alatt, a 3D-kép fölött
	_layer.layer = 0
	add_child(_layer)
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_canvas.material = cm
	_canvas.draw.connect(_draw_sky)
	_layer.add_child(_canvas)


# ---------------------------------------------------------------- Adat

## A csillagok a mentett, aktív bolygóról (vagy semmi, ha nem a mentés látszik). A meglévők állapota (halványodás) megmarad.
func sync() -> void:
	var old := {}
	for s in list:
		old[int(s.id)] = s
	list.clear()
	if host == null or not host.saved_view or host.game.data.is_empty():
		_code = ""
		return
	var p: Dictionary = host.game.active_planet()
	if str(p.code) != _code:
		_code = str(p.code)
		_layout.clear()
		_fit_s = 0.0
	var top := 0
	for st in p.stars:
		top = maxi(top, int(st.seq))
	_ensure_layout(top)
	for st in p.stars:
		var id := int(st.id)
		var o: Dictionary = old.get(id, {})
		list.append({"id": id, "seq": int(st.seq), "rec": st, "col": star_color(st), "pos": _layout[int(st.seq)],
			"fade": float(o.get("fade", 1.0 if old.is_empty() else 0.0)), "leave": -1.0})
		if list.size() >= MAX_STARS:
			break
	# a távozó (visszahozott) csillag még elhalványul
	for id in old:
		var o: Dictionary = old[id]
		if float(o.leave) >= 0.0 and list.size() < MAX_STARS:
			list.append(o)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.seq) < int(b.seq))
	if selected >= 0 and _find(selected).is_empty():
		selected = -1


## A csillag színe: a fa virágszíne, kicsit világosabban (fénylő pasztell).
static func star_color(st: Dictionary) -> Color:
	var c := Genes.allele_color(0, int((st.dna as Array)[0]))
	return c.lerp(Color(1, 1, 1), .22)


## A sorban (sorszám szerint) a csillagok, a távozók nélkül (a herbárium lapozásához).
func ordered() -> Array:
	return list.filter(func(s: Dictionary) -> bool: return float(s.leave) < 0.0)


func _find(id: int) -> Dictionary:
	for s in list:
		if int(s.id) == id:
			return s
	return {}


## Az elrendezés: a 0. csillag középen; a következő egy korábbi mellé kerül (legtöbbször az előzőhöz, néha egy
## régebbihez – így ágas, csillagkép-szerű alak nő), a többitől legalább MIN_GAP távolságra. Csak a bolygókódtól és a
## sorszámtól függ (a jelenlévő csillagoktól nem), így a meglévők sosem mozdulnak el.
const MIN_GAP := 4.4


func _ensure_layout(top: int) -> void:
	while _layout.size() <= top:
		var n := _layout.size()
		if n == 0:
			_layout.append({"p": Vector2.ZERO, "parent": -1, "dir": 0.0})
			continue
		var r := RandomNumberGenerator.new()
		r.seed = hash(_code + "csillagkep" + str(n))
		var parent := n - 1 if (r.randf() < .6 or n < 3) else r.randi() % (n - 1)
		var pe: Dictionary = _layout[parent]
		var base_a := float(pe.dir) if parent > 0 else r.randf() * TAU
		var best := Vector2.ZERO
		var best_a := 0.0
		var best_d := -1.0
		for k in 18:
			var a := base_a + r.randf_range(-1.25, 1.25) * (1.0 + k * .12)
			var c: Vector2 = (pe.p as Vector2) + Vector2.from_angle(a) * r.randf_range(5.0, 7.5)
			var md := 99.0
			for e in _layout:
				md = minf(md, c.distance_to(e.p))
			if md >= MIN_GAP:
				best = c
				best_a = a
				best_d = md
				break
			if md > best_d:
				best_d = md
				best = c
				best_a = a
		_layout.append({"p": best, "parent": parent, "dir": best_a})


## A csillag vonala: a legközelebbi még égen lévő ősére, vagy ha nincs ilyen, a legközelebbi korábbi csillagra.
func _link(s: Dictionary, present: Dictionary) -> int:
	var seq := int(s.seq)
	var p := int(_layout[seq].parent)
	while p >= 0:
		if present.has(p):
			return p
		p = int(_layout[p].parent)
	var best := -1
	var bd := 1e9
	for q in present:
		if int(q) < seq:
			var d: float = (_layout[seq].p as Vector2).distance_to(_layout[int(q)].p)
			if d < bd:
				bd = d
				best = int(q)
	return best


# ---------------------------------------------------------------- Csillagkép-nézet

func open_sky(id: int) -> void:
	sky_on = true
	selected = id
	_ring_t = 0.0


func close_sky() -> void:
	sky_on = false
	selected = -1


func select(id: int) -> void:
	if id != selected:
		selected = id
		_ring_t = 0.0


## A koppintáshoz legközelebbi látható csillag (TAP_R képponton belül, a bolygó nem takarja), vagy -1.
func pick(pos: Vector2) -> int:
	var best := -1
	var bd := TAP_R * (1.25 if sky_on else 1.0)
	for s in list:
		var id := int(s.id)
		if float(s.leave) >= 0.0 or id == hidden_id or not _world.has(id) or _occluded(_world[id]):
			continue
		var sp: Vector2 = host.cam.unproject_position(_world[id])
		var d := sp.distance_to(pos)
		if d < bd:
			bd = d
			best = id
	return best


## A csillag helye a képernyőn (vagy a kép közepe fölött, ha még nincs).
func screen_pos(id: int) -> Vector2:
	if _world.has(id):
		return host.cam.unproject_position(_world[id])
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	return Vector2(vp.x * .5, vp.y * .25)


func world_pos(id: int) -> Vector3:
	return _world.get(id, host.cam.global_position + Vector3.UP * DIST)


## A bolygó vagy egy fa lombja takarja-e a csillagot (sugár–gömb próba a kamerától; a fa lombja egy gömb).
func _occluded(w: Vector3) -> bool:
	var planet: Planet = host.planet
	var o: Vector3 = host.cam.global_position
	var d := (w - o).normalized()
	if _hits(o, d, planet.global_position, planet.radius * (1.0 + planet.h_max * .5)):
		return true
	for t in host.trees:
		if bool(t.get("shown", false)) and _hits(o, d, host._tree_mid(t), maxf(float(t.w) * 1.05, float(t.h) * .32)):
			return true
	return false


static func _hits(o: Vector3, d: Vector3, center: Vector3, r: float) -> bool:
	var c := center - o
	var tca := c.dot(d)
	if tca < 0.0:
		return false
	return c.length_squared() - tca * tca < r * r


## Fut-e az elengedés (alatta a világ nem reagál; a koppintás gyorsít).
func busy() -> bool:
	return not rel.is_empty()


func skip() -> void:
	if busy() and freeze_at < 0.0:
		speed = 3.0


# ---------------------------------------------------------------- Elengedés, visszahozás

## Elengedés: a fa (a host.trees eleme) fénnyé oszlik, a fény felszáll, és a star_id csillag lesz belőle.
## A csillag már a mentésben van; addig rejtve marad, amíg a fény meg nem érkezik.
func release(t: Dictionary, star_id: int) -> void:
	var planet: Planet = host.planet
	var n: Vector3 = (t.dir as Vector3).normalized()
	var base := planet.surface_point(n)
	var h := float(t.h)
	var g: Dictionary = t.g
	var col := Genes.hsl(float(g.petal_h), .7, .78)
	var pg: PlantGen = t.high.pg
	var xf: Transform3D = (t.high.node as Node3D).transform
	var pts: Array = []
	var src: Array = pg.leaf_p if pg.leaf_p.size() > 0 else pg.flo_p
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(g.code) + "csillag")
	for i in MOTES:
		var w: Vector3 = base + n * h * r.randf_range(.3, .9)
		if src.size() > 0:
			w = xf * (src[r.randi() % src.size()] as Vector3)
		if i % 5 == 0 and pg.flo_p.size() > 0:
			w = xf * (pg.flo_p[r.randi() % pg.flo_p.size()] as Vector3)
		var hn := clampf((w - base).dot(n) / maxf(h, .1), 0.0, 1.0)
		# a csúcsok (a magasabb, külső részek) oszlanak el előbb, ahogy a fa a csúcsaitól visszahúzódik
		var tb := R_UNGROW0 + .1 + (1.0 - hn) * (R_UNGROW1 - R_UNGROW0 - .7) + r.randf() * .35
		pts.append({"p": w, "tb": tb, "ph": r.randf() * TAU, "k": r.randf_range(.7, 1.2)})
	t.wave = -1.0
	for rec in t.lods:
		rec.hold = true
	rel = {"tree": t, "t": freeze_at if freeze_at >= 0.0 else 0.0, "star": star_id, "motes": pts, "gone": false, "arrived": false,
		"col": col, "base": base, "n": n, "h": h, "g": base + n * h * 1.15}
	hidden_id = star_id
	speed = 1.0


## Visszahozás: a csillag felvillan és elhalványul (az adatot a hívó már kivette a mentésből).
func recall(id: int) -> void:
	var s := _find(id)
	if s.is_empty():
		return
	s.leave = _t
	if selected == id:
		selected = -1


# ---------------------------------------------------------------- Képkockánként

func _process(delta: float) -> void:
	_t += delta
	var on: bool = host != null and host.garden_mode == "planet" and host.saved_view
	_canvas.visible = on
	if not on:
		return
	var cam: Camera3D = host.cam
	var applied_tilt := tilt
	var k := 1.0 if snap else 1.0 - exp(-delta * 2.0)
	sky_k = lerpf(sky_k, 1.0 if sky_on else 0.0, k)
	if absf(sky_k - (1.0 if sky_on else 0.0)) < .002:
		sky_k = 1.0 if sky_on else 0.0
	tilt = TILT_SKY * _smooth(sky_k)
	# az égbolt kerete: a kamera kerete a felfordulás nélkül, puhán lemaradva (forgáskor az ég „mögötte marad”)
	var b0 := cam.global_transform.basis.orthonormalized() * Basis(Vector3.RIGHT, -applied_tilt)
	var q0 := b0.get_rotation_quaternion()
	if not _sky_set or snap:
		_sky_q = q0
		_sky_set = true
	else:
		_sky_q = _sky_q.slerp(q0, 1.0 - exp(-delta * 2.4)).normalized()
	if not rel.is_empty():
		_step_release(delta)
	# a visszahozott csillag elhalványulása után ki a listából
	list = list.filter(func(s: Dictionary) -> bool: return float(s.leave) < 0.0 or _t - float(s.leave) < 1.5)
	_place(delta, k)
	_canvas.queue_redraw()


func _place(delta: float, k: float) -> void:
	var cam: Camera3D = host.cam
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var night: float = clampf(float(host.night), 0.0, 1.0)
	var e := _smooth(sky_k)
	# a jelenlévő (nem rejtett, nem távozó) csillagok befoglaló doboza → méretezés a kerethez
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var present := {}
	for s in list:
		if float(s.leave) < 0.0:
			present[int(s.seq)] = s
			lo = lo.min(s.pos.p)
			hi = hi.max(s.pos.p)
	var box := Rect2(BOX_PASSIVE.position.lerp(BOX_SKY.position, e), BOX_PASSIVE.size.lerp(BOX_SKY.size, e))
	var unit := lerpf(UNIT_PASSIVE, UNIT_SKY, e)
	var want_s := unit
	var want_c := Vector2.ZERO
	if not present.is_empty():
		var half := (hi - lo) * .5
		want_c = (hi + lo) * .5
		if half.x > .01:
			want_s = minf(want_s, box.size.x / half.x)
		if half.y > .01:
			want_s = minf(want_s, box.size.y / half.y)
	var kk := 1.0 if snap or _fit_s <= 0.0 else 1.0 - exp(-delta * 1.6)
	_fit_s = lerpf(_fit_s, want_s, kk)
	_fit_c = _fit_c.lerp(want_c, kk)
	# a csillagkép-nézetben a kiválasztott csillag a kép közepe felé tolódik (a kamera „felé fordul”)
	var want_pan := Vector2.ZERO
	var sel := _find(selected)
	if sky_on and not sel.is_empty():
		want_pan = ((sel.pos.p as Vector2) - _fit_c) * _fit_s * .25
	_pan = _pan.lerp(want_pan, k)
	var sky := Basis(_sky_q)
	var eye := cam.global_position
	_world.clear()
	_dots.clear()
	_segs.clear()
	_rings.clear()
	var shown := {}
	var star_a := lerpf(.5, 1.75, night)
	for s in list:
		var id := int(s.id)
		var fade := float(s.fade)
		var flare := 0.0
		if float(s.leave) >= 0.0:
			# visszahozva: felvillan, aztán elhalványul
			var a := _t - float(s.leave)
			flare = sin(clampf(a / 1.1, 0.0, 1.0) * PI)
			fade = 1.0 - _smooth((a - .35) / .8)
			if a > 1.3:
				fade = 0.0
		elif id == hidden_id:
			fade = 0.0
		else:
			fade = minf(1.0, fade + delta * 1.4)
		s.fade = fade
		var lp: Vector2 = box.position + ((s.pos.p as Vector2) - _fit_c) * _fit_s - _pan
		var dir := (sky * Vector3(lp.x, lp.y, -1.0)).normalized()
		var w := eye + dir * DIST
		_world[id] = w
		if fade <= .001 or cam.is_position_behind(w) or _occluded(w):
			continue
		var is_sel := id == selected and sky_on
		var r := PX_STAR * .5 * (1.0 + .35 * e) * (1.25 if is_sel else 1.0) * (1.0 + 1.4 * flare)
		# lassú, halk pislákolás
		var tw := 1.0 + .12 * sin(_t * 1.7 + float(s.seq) * 2.3)
		var sp := cam.unproject_position(w)
		shown[id] = sp
		_dots.append([sp, r, s.col, star_a * fade * (1.0 + flare) * tw])
	# vonalak: minden csillagtól a legközelebbi megmaradt őséig
	var line_a := lerpf(.07, .42, night) * (1.0 + .3 * e)
	for s in list:
		if float(s.leave) >= 0.0 or float(s.fade) <= .001:
			continue
		var to := _link(s, present)
		if to < 0:
			continue
		var o: Dictionary = present[to]
		if float(o.fade) <= .001:
			continue
		# ha valamelyik vége takarva van (a bolygó vagy egy fa mögött), a vonal sem látszik
		if not shown.has(int(s.id)) or not shown.has(int(o.id)):
			continue
		var c: Color = (s.col as Color).lerp(o.col, .5).lerp(Color(.92, .9, 1.0), .5)
		_segs.append([shown[int(s.id)], shown[int(o.id)], c, line_a * minf(float(s.fade), float(o.fade)), PX_STAR * .5 * (1.0 + .35 * e) * .45])
	# a kiválasztott csillag gyűrűje (a csillagkép-nézetben), és az érkezéskor szétfutó gyűrű
	var ring_id := selected if sky_on else -1
	if _ring_id >= 0 and _ring_t >= 0.0:
		ring_id = _ring_id
	if ring_id >= 0 and shown.has(ring_id) and ring_id != hidden_id:
		_ring_t = _ring_t + delta if _ring_t >= 0.0 else 0.0
		var grow := _smooth(_ring_t / .7)
		var rs := PX_RING * .5 * (lerpf(.4, 1.0, grow) if _ring_id < 0 else lerpf(.5, 2.4, grow))
		var ra := (.9 + .25 * sin(_t * 2.4)) if _ring_id < 0 else 1.6 * (1.0 - _smooth((_ring_t - .3) / .9))
		var sc := _find(ring_id)
		var rc: Color = BoardView.C_FREE if _ring_id < 0 else (sc.col if not sc.is_empty() else BoardView.C_FREE)
		_rings.append([shown[ring_id], rs, rc, ra * lerpf(.75, 1.2, night) * (e if _ring_id < 0 else 1.0)])
		if _ring_id >= 0 and _ring_t > 1.4:
			_ring_id = -1
			_ring_t = 0.0


## Az elengedés egy képkockája: a fa felragyog és a csúcsaitól fénnyé oszlik, a fények a korona fölé gyűlnek, a fény
## felszáll a csillag helyére (ami a kamerával együtt mozog, így a fény odatalál).
func _step_release(delta: float) -> void:
	var t: Dictionary = rel.tree
	if freeze_at < 0.0:
		rel.t = float(rel.t) + delta * speed
	var tt := float(rel.t)
	var col: Color = rel.col
	if not bool(rel.gone):
		var glow := _smooth(tt / 1.0)
		var g := 1.0 - _smooth((tt - R_UNGROW0) / (R_UNGROW1 - R_UNGROW0))
		for rec in t.lods:
			for m in rec.mats:
				var sm := m as ShaderMaterial
				sm.set_shader_parameter("grow", 1.0 - pow(1.0 - g, 1.7))
				sm.set_shader_parameter("glow_col", col)
				sm.set_shader_parameter("glow_amt", lerpf(float(t.glow.strength) * maxf(float(host.night), 0.0), _glow_peak, glow))
				# fényhullámok futnak fel a fán, újra és újra
				sm.set_shader_parameter("wave", fmod(tt, 1.7))
		if tt >= R_UNGROW1 + .1:
			rel.gone = true
			gone.emit(t)
	_fx_dots.clear()
	var up: Vector3 = rel.n
	var gp: Vector3 = rel.g
	var cam: Camera3D = host.cam
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	# egy egységnyi méret egységnyi távolságban hány képpont
	var px_unit: float = maxf(vp.y, 1.0) / (2.0 * tan(deg_to_rad(cam.fov) * .5))
	# fénypontok: kiválnak a fából, spirálban felemelkednek, és a korona fölötti fénybe olvadnak
	var gathered := 0.0
	for m in rel.motes:
		var a := (tt - float(m.tb)) / 1.5
		if a <= 0.0:
			continue
		var u := _smooth(a)
		gathered += u
		var from: Vector3 = m.p
		var off := from - gp
		var swirl := off.rotated(up, u * 2.2 * float(m.k)) * (1.0 - u)
		var p := gp + swirl + up * sin(u * PI) * .6 * float(m.k)
		var alpha := _smooth(a * 4.0) * (1.0 - _smooth((a - .8) / .3)) * 1.6
		var size := (.14 + .1 * sin(_t * 5.0 + float(m.ph))) * float(m.k) * (1.0 - .5 * u)
		_fx_dot(cam, p, size, px_unit, 2.5, col.lerp(Color.WHITE, .3), alpha)
	gathered /= float(MOTES)
	# a fény: a korona fölött gyűlik, aztán felszáll a csillag helyére, csóvával
	var target := world_pos(int(rel.star))
	var rise := _smooth((tt - R_RISE0) / (R_RISE1 - R_RISE0))
	for i in TRAIL + 1:
		var ui := clampf(rise - i * .035, 0.0, 1.0)
		var p := _rise_point(gp, up, target, ui)
		# a fény messze is látsszon: legalább néhány képpontnyi (a fej nagyobb, a csóva kisebb)
		var base_w := lerpf(.2, .62, gathered) * (1.0 + .12 * sin(_t * 3.0)) if i == 0 else .34 - i * .03
		var a := (minf(1.0, gathered * 1.6) * 1.6 if i == 0 else (1.4 * (1.0 - float(i) / (TRAIL + 1)) if rise > .02 and ui > 0.0 else 0.0))
		if tt >= R_RISE1:
			a *= 1.0 - _smooth((tt - R_RISE1) / .35)
		if a > .001:
			_fx_dot(cam, p, base_w, px_unit, 11.0 if i == 0 else 5.5 - i * .4, col.lerp(Color.WHITE, .45 if i == 0 else .2), a)
	if tt >= R_RISE1 and not bool(rel.arrived):
		rel.arrived = true
		hidden_id = -1
		var s := _find(int(rel.star))
		if not s.is_empty():
			s.fade = 0.0
		_ring_id = int(rel.star)
		_ring_t = 0.0
		arrived.emit(int(rel.star))
	if tt >= R_LEN and freeze_at < 0.0:
		rel = {}
		_fx_dots.clear()
		speed = 1.0


## Egy fénypont az elengedésből a rajzlistára: a világbeli méretből képpont (legalább min_px), a kamera mögött nem.
func _fx_dot(cam: Camera3D, p: Vector3, size: float, px_unit: float, min_px: float, col: Color, a: float) -> void:
	if cam.is_position_behind(p):
		return
	var d := maxf(cam.global_position.distance_to(p), .01)
	# a világbeli méret a haló átmérője volt (mint a 3D-s fénypontoknál): itt a sugár, kicsit kisebbre véve
	var r := clampf(size * px_unit / d * .42, min_px, 40.0)
	_fx_dots.append([cam.unproject_position(p), r, col, a])


## A rajz (additív): halvány haló, közép, fehéres mag; vonalak; gyűrűk. A mag a csillag színéből fehérbe hajlik.
func _draw_sky() -> void:
	for sg in _segs:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var gap: float = sg[4]
		var d := b - a
		if d.length() < gap * 2.2:
			continue
		var u := d.normalized()
		var col: Color = sg[2]
		var al: float = sg[3]
		_canvas.draw_line(a + u * gap, b - u * gap, Color(col, minf(al * .35, 1.0)), PX_LINE * 3.0, true)
		_canvas.draw_line(a + u * gap, b - u * gap, Color(col, minf(al, 1.0)), PX_LINE, true)
	for dl in [_dots, _fx_dots]:
		for d in dl:
			_glow(d[0], d[1], d[2], d[3])
	for rg in _rings:
		var col: Color = rg[2]
		var al: float = rg[3]
		_canvas.draw_arc(rg[0], rg[1], 0.0, TAU, 56, Color(col, minf(al * .25, 1.0)), 7.0, true)
		_canvas.draw_arc(rg[0], rg[1], 0.0, TAU, 56, Color(col, minf(al * .9, 1.0)), 2.0, true)


func _glow(p: Vector2, r: float, col: Color, a: float) -> void:
	if a <= .002:
		return
	_canvas.draw_circle(p, r, Color(col, minf(.09 * a, 1.0)))
	_canvas.draw_circle(p, r * .55, Color(col, minf(.22 * a, 1.0)))
	_canvas.draw_circle(p, r * .26, Color(col.lerp(Color.WHITE, .55), minf(.75 * a, 1.0)))
	_canvas.draw_circle(p, r * .12, Color(1, 1, 1, minf(.6 * a, 1.0)))


## A felszálló fény útja: a korona fölül előbb egyenesen fel, aztán ívben a csillag felé.
static func _rise_point(from: Vector3, up: Vector3, to: Vector3, u: float) -> Vector3:
	var e := u * u * (3.0 - 2.0 * u)
	var c1 := from + up * 5.0
	var c2 := to.lerp(from + up * 12.0, .35)
	var a := from.lerp(c1, e)
	var b := c1.lerp(c2, e)
	var c := c2.lerp(to, e)
	return a.lerp(b, e).lerp(b.lerp(c, e), e)


static func _smooth(x: float) -> float:
	var v := clampf(x, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)
