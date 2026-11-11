class_name SkyStars
extends Node3D
## A játékos csillagai (M6; 2026. 11. 11. óta a játékoséi, nem a bolygóké): az elengedett fák és a keresztezés el nem
## választott csírái. Valódi 3D-pontok egy gömbhéjban a bolygórendszer körül – nem csillagkép, nem gócpont.
##  - Hely: a játékoskódból és a csillag sorszámából (seq): R3 kis eltérésű sorozat → irány (egyenletesen a gömbön) és
##    sugár (egyenletesen a héj térfogatában, R_IN–R_OUT), a bolygók fürtjének közepe körül (planet_system.gd: a
##    bolygók is a térben vannak, csak közelebb). Bármennyi csillag egyenletesen szóródik; egy új érkezése vagy
##    egy visszahozása nem mozdítja el a többit.
##  - A bolygó-nézetben és leszállva a kamera a héjon belül van: a csillagok szétszórva látszanak az égen (ami a bolygó
##    vagy egy fa lombja mögé esik, nem), forgatáskor valódi parallaxissal (a közeliek jobban elmozdulnak).
##  - Kozmosz (a kicsinyítés utolsó fokozata, a bolygók átfogó nézete után; több bolygó nélkül a szomszéd-bolygós
##    lépcső után): a kamera messze kihúzódik, középen kicsiben a bolygórendszer, körülötte az összes csillag; húzásra
##    körbejár (parallaxis), lassan magától is sodródik. A háttér (csillagpor, ködök, galaxisok): cosmos.gd. Csillagra
##    koppintva a lapja (herbarium.gd); ilyenkor a kép a csillag felé tolódik (a lap fölé).
##  - Nappal halványan, éjjel fényesen, a kozmoszban mindig fényesen; a közeli csillag nagyobb és fényesebb. A csillag
##    színe a fa virágszínéből. Olcsó: a helyek 3D-ben, a rajz 2D-ben (a 3D-kép fölött, a gombsor alatt, additív
##    körök, ≤128 csillag). Így weben is biztosan ugyanaz, és a lencse sem mossa el.
##  - Elengedés: a fa fénnyel átjárva, a csúcsaitól kezdve fénypontokká oszlik, a fények összegyűlnek a koronája fölött,
##    és egy fény lassan, csóvával felszáll; közben a kamera kihúzódik a kozmoszba, ahol a fény csillaggá gyullad
##    (release()). Visszahozás: a csillag felvillan és elhalványul (recall()); a mag útja a táskába: herbarium.gd.
##
## A főjelenet (main.gd) tagjait használja, ezért a host típus nélküli: cam, planet, game, saved_view, garden_mode,
## night, trees, plants, view, focus, orbit_zoom, orbit_q, system, shot_args.

## Elengedéskor a fa eltűnt a jelenetből (a hívó kiveszi a fák közül, és kihúzza a kamerát a kozmoszba).
signal gone(tree: Dictionary)
## A felszálló fény megérkezett: a csillag kigyullad.
signal arrived(star_id: int)

## Ennyi csillag látszik legfeljebb (a sorszám szerinti első ennyi; a többi a mentésben megvan).
const MAX_STARS := 128
## A csillagok gömbhéja a bolygók fürtje körül (világegység; a bolygó sugara ~3–6, a fürt sugara 16 bolygónál ~47).
const R_IN := 62.0
const R_OUT := 150.0
## Az R3 sorozat lépései (1/g, 1/g², 1/g³, g a „plasztikus szám” 3D-s rokona).
const R3_A := Vector3(.8191725133961645, .6710436067037893, .5497004779019703)
## A kozmosz: látószög (szélesebb, hogy álló képen is beférjen a héj), és mennyivel a bolygók utolsó lépcsője alatt
## (orbit_zoom-egységben) ér a teljes kihúzódásig.
const COSMOS_FOV := 56.0
const COSMOS_SPAN := 1.0
## Képpontban: a csillag (haló együtt) átmérője, a kiválasztott csillag gyűrűje.
const PX_STAR := 26.0
const PX_RING := 58.0
## A koppintás sugara (képpont): telefonon nagy érintési terület.
const TAP_R := 46.0
const TAP_R_NEAR := 24.0

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
## Csillagok: [{"id", "seq", "rec", "col", "fade" (0–1), "leave" (-1 vagy a távozás ideje), "pos" (világbeli hely)}]
var list: Array = []
## Nyitva a csillag lapja (herbarium.gd); a kiválasztott csillag azonosítója.
var sky_on := false
var selected := -1
## Kozmosz: 0 = a bolygók, 1 = kihúzódva a csillagok közé (puhán követi az orbit_zoom-ot).
var cosmos_k := 0.0
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
## sorszám → világbeli hely (a játékoskódból)
var _spots := {}
## a kozmoszban a kép a kiválasztott csillag felé tolódik (világegységben, a kamera síkjában)
var _pan := Vector3.ZERO
## a csillagok héjának közepe a világban: a bolygók fürtjének közepe (a 0. bolygó helye; planet_system.space_origin),
## így bolygóváltáskor sem ugrik el az ég
var _origin := Vector3.ZERO
## a rajzréteg (a 3D fölött, a gombsor alatt) és a rajzlisták: csillagok, gyűrű, az elengedés fényei
var _layer := CanvasLayer.new()
var _canvas := Control.new()
var _dots: Array = []
var _rings: Array = []
var _fx_dots: Array = []
## a kozmoszban a bolygórendszer jele: [képernyőhely, alfa, név] (üres = nincs)
var _home: Array = []
var _t := 0.0
## a csillagok világbeli helye (id → Vector3; a takarás és a koppintás ehhez mér)
var _world := {}
## ebben a képkockában a takaró gömbök (a bolygó és a látszó fák lombja): [[közép, sugár²]]
var _occ: Array = []
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

## A játékos csillagai (vagy semmi, ha nem a mentés látszik, pl. barát bolygója, próba). A meglévők állapota
## (halványodás) megmarad.
func sync() -> void:
	var old := {}
	for s in list:
		old[int(s.id)] = s
	list.clear()
	if host == null or not host.saved_view or host.game.data.is_empty():
		_code = ""
		return
	var code := str(host.game.data.player)
	if code != _code:
		_code = code
		_spots.clear()
	var all: Array = (host.game.data.stars as Array).duplicate()
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.seq) < int(b.seq))
	for st in all:
		var id := int(st.id)
		var o: Dictionary = old.get(id, {})
		list.append({"id": id, "seq": int(st.seq), "rec": st, "col": star_color(st), "pos": spot(int(st.seq)),
			"fade": float(o.get("fade", 1.0 if old.is_empty() else 0.0)), "leave": -1.0})
		if list.size() >= MAX_STARS:
			break
	# a távozó (visszahozott) csillag még elhalványul
	for id in old:
		var o: Dictionary = old[id]
		if float(o.leave) >= 0.0 and list.size() < MAX_STARS:
			list.append(o)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.seq) < int(b.seq))
	for s in list:
		_world[int(s.id)] = (s.pos as Vector3) + _origin
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


## A seq. csillag világbeli helye: R3 sorozat a játékoskódból eltolva → irány (z = 1 − 2u, φ = 2πv: egyenletes a
## gömbön) és sugár (w-ből a héj térfogatában egyenletesen). Csak a játékoskódtól és a sorszámtól függ.
func spot(seq: int) -> Vector3:
	if _spots.has(seq):
		return _spots[seq]
	var r := RandomNumberGenerator.new()
	r.seed = hash(_code + "egbolt")
	var o := Vector3(r.randf(), r.randf(), r.randf())
	var q := o + R3_A * float(seq + 1)
	q = Vector3(fposmod(q.x, 1.0), fposmod(q.y, 1.0), fposmod(q.z, 1.0))
	var z := 1.0 - 2.0 * q.x
	var phi := TAU * q.y
	var rr := sqrt(maxf(0.0, 1.0 - z * z))
	var rad := pow(pow(R_IN, 3.0) + q.z * (pow(R_OUT, 3.0) - pow(R_IN, 3.0)), 1.0 / 3.0)
	var p := Vector3(rr * cos(phi), z, rr * sin(phi)) * rad
	_spots[seq] = p
	return p


# ---------------------------------------------------------------- Kozmosz

## A kicsinyítés melyik foka után jön a kozmosz (több bolygónál az átfogó nézet után, egynél a szomszéd-lépcső után).
func start_zoom() -> float:
	return PlanetSystem.ZOOM_ALL if not (host.system.minis as Array).is_empty() else PlanetSystem.ZOOM_MIN


## A teljes kihúzódás (ennél a kicsinyítésnél vagyunk a csillagok között).
func stars_zoom() -> float:
	return start_zoom() - COSMOS_SPAN


## A kozmosz (0–1, simítva) – a kamera (main._orbit_pose) ezzel keveri a cosmos_pose()-t.
func cosmos() -> float:
	return _smooth(cosmos_k)


## A kamera a kozmoszban: a bolygórendszer közepe körül, a bolygó-nézet forgatásával (orbit_q), olyan messze, hogy a
## csillagok héja beférjen. Nyitott lapnál a kép a kiválasztott csillag felé tolódik (a csillag a lap fölé kerül).
## base: a bolygók kamerája [szem, nézett pont, fel]; k szerint keveri (a távolság logaritmikusan nő).
func cosmos_pose(base: Array) -> Array:
	var k := cosmos()
	if k <= 0.0:
		return base
	var b := Basis(host.orbit_q)
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var tv := tan(deg_to_rad(COSMOS_FOV) * .5)
	var th := tv * maxf(vp.x, 1.0) / maxf(vp.y, 1.0)
	var d := R_OUT * 1.08 / sin(atan(minf(tv, th)))
	var center: Vector3 = host.planet.global_position
	var ov: float = host.system.overview()
	if ov > 0.0:
		center = center.lerp(host.system.overview_pose()[1], ov)
	var look := center + _pan
	var eye := look + b.z * d
	var d0 := maxf(((base[0] as Vector3) - (base[1] as Vector3)).length(), .01)
	var dir0 := ((base[0] as Vector3) - (base[1] as Vector3)) / d0
	var lk := (base[1] as Vector3).lerp(look, k)
	var dir := dir0.slerp(b.z, k).normalized()
	var dist := exp(lerpf(log(d0), log(d), k))
	return [lk + dir * dist, lk, (base[2] as Vector3).slerp(b.y, k).normalized()]


func _cosmos_step(delta: float) -> void:
	var want := 0.0
	if (host.view == "orbit" or int(host.focus) < 0) and not host.system.busy() and host.garden_mode == "planet" and host.saved_view:
		want = clampf((start_zoom() - float(host.orbit_zoom)) / COSMOS_SPAN, 0.0, 1.0)
	cosmos_k = want if snap else lerpf(cosmos_k, want, 1.0 - exp(-delta * 3.0))
	if absf(cosmos_k - want) < .001:
		cosmos_k = want
	# nyitott lapnál a kiválasztott csillag a kép felső közepe felé
	var want_pan := Vector3.ZERO
	var sel := _find(selected)
	if sky_on and not sel.is_empty() and cosmos_k > .5:
		var b := Basis(host.orbit_q)
		var center: Vector3 = host.planet.global_position.lerp(host.system.overview_pose()[1], host.system.overview())
		var off: Vector3 = (sel.pos as Vector3) + _origin - center
		var vp: Vector2 = host.get_viewport().get_visible_rect().size
		var tv := tan(deg_to_rad(COSMOS_FOV) * .5)
		var th := tv * maxf(vp.x, 1.0) / maxf(vp.y, 1.0)
		var d := R_OUT * 1.08 / sin(atan(minf(tv, th)))
		# a csillag mélységénél ennyi a fél képmagasság: a lap fölötti sáv közepére
		var depth := d - off.dot(b.z)
		want_pan = b.x * off.dot(b.x) + b.y * (off.dot(b.y) - depth * tv * .3)
	_pan = want_pan if snap else _pan.lerp(want_pan, 1.0 - exp(-delta * 2.5))


# ---------------------------------------------------------------- A csillag lapja

## A lap nyílik (herbarium.gd): a csillag kiválasztva, gyűrű jelöli.
func open_sky(id := -1) -> void:
	sky_on = true
	select(id)


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
	# a kozmoszban nagy érintési terület; a bolygók közt kisebb (ott körös-körül csillagok vannak, a fák és az üres ég
	# koppintása ne nyissa a lapot)
	var bd := TAP_R * 1.25 if cosmos() > .5 else TAP_R_NEAR
	var cam: Camera3D = host.cam
	for s in list:
		var id := int(s.id)
		if float(s.leave) >= 0.0 or id == hidden_id or float(s.fade) < .3:
			continue
		var w: Vector3 = (s.pos as Vector3) + _origin
		if cam.is_position_behind(w) or _occluded(w):
			continue
		var d := cam.unproject_position(w).distance_to(pos)
		if d < bd:
			bd = d
			best = id
	return best


## A csillag helye a képernyőn (vagy a kép közepe fölött, ha a kamera mögött van).
func screen_pos(id: int) -> Vector2:
	var cam: Camera3D = host.cam
	if _world.has(id) and not cam.is_position_behind(_world[id]):
		return cam.unproject_position(_world[id])
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	return Vector2(vp.x * .5, vp.y * .25)


func world_pos(id: int) -> Vector3:
	if _world.has(id):
		return _world[id]
	var s := _find(id)
	return (s.pos as Vector3) + _origin if not s.is_empty() else host.cam.global_position + Vector3.UP * R_OUT


## A bolygó vagy egy fa lombja takarja-e a csillagot (sugár–gömb próba a kamerától; a fa lombja egy gömb).
func _occluded(w: Vector3) -> bool:
	var o: Vector3 = host.cam.global_position
	var v := w - o
	var vl := v.length()
	var d := v / maxf(vl, .0001)
	for oc in _occ:
		if _hits(o, d, vl, oc[0], oc[1]):
			return true
	return false


## A takaró gömbök ebben a képkockában (a bolygó, és a látszó fák lombja).
func _gather_occluders() -> void:
	_occ.clear()
	var planet: Planet = host.planet
	var pr := planet.radius * (1.0 + planet.h_max * .5)
	_occ.append([planet.global_position, pr * pr])
	for t in host.trees:
		if bool(t.get("shown", false)):
			var r := maxf(float(t.w) * 1.05, float(t.h) * .32)
			_occ.append([host._tree_mid(t), r * r])


## A sugár (o-ból d irányban, len hosszan) eltalálja-e a gömböt – csak ha a gömb a csillag előtt van.
static func _hits(o: Vector3, d: Vector3, reach: float, center: Vector3, r2: float) -> bool:
	var c := center - o
	var tca := c.dot(d)
	if tca < 0.0 or tca > reach:
		return false
	return c.length_squared() - tca * tca < r2


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
	var from_leaves := pg.leaf_p.size() > 0
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(g.code) + "csillag")
	for i in MOTES:
		var w: Vector3 = base + n * h * r.randf_range(.3, .9)
		if src.size() > 0:
			var k := r.randi() % src.size()
			# a levágott ág (M8) helyén nincs mit fényként szétszórni
			if (pg.leaf_live(k) if from_leaves else pg.flower_live(k)):
				w = xf * (src[k] as Vector3)
		if i % 5 == 0 and pg.flo_p.size() > 0:
			var k := r.randi() % pg.flo_p.size()
			if pg.flower_live(k):
				w = xf * (pg.flo_p[k] as Vector3)
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
	Sound.fx("release")


## Visszahozás: a csillag felvillan és elhalványul (az adatot a hívó már kivette a mentésből).
func recall(id: int) -> void:
	var s := _find(id)
	if s.is_empty():
		return
	s.leave = _t
	Sound.fx("recall")
	if selected == id:
		selected = -1


# ---------------------------------------------------------------- Képkockánként

func _process(delta: float) -> void:
	_t += delta
	var on: bool = host != null and host.garden_mode == "planet" and host.saved_view
	_canvas.visible = on
	if host != null and host.garden_mode == "planet":
		_cosmos_step(delta)
	if not on:
		return
	_origin = host.system.space_origin()
	_gather_occluders()
	if not rel.is_empty():
		_step_release(delta)
	# a visszahozott csillag elhalványulása után ki a listából
	list = list.filter(func(s: Dictionary) -> bool: return float(s.leave) < 0.0 or _t - float(s.leave) < 1.5)
	_place(delta)
	_canvas.queue_redraw()


## A csillagok rajzlistája ebben a képkockában: valódi 3D-helyükről vetítve (a kamera mozgásával parallaxis), a
## közeliek nagyobbak és fényesebbek; a bolygó és a fák lombja eltakarja, ami mögéjük esik.
func _place(delta: float) -> void:
	var cam: Camera3D = host.cam
	var night: float = clampf(float(host.night), 0.0, 1.0)
	var e := cosmos()
	var eye := cam.global_position
	# a nézett pont távolsága: ehhez képest közeli / távoli egy csillag
	var dref := maxf(eye.distance_to(host.look), 1.0)
	_dots.clear()
	_rings.clear()
	var shown := {}
	var n := 0
	for s in list:
		if float(s.leave) < 0.0:
			n += 1
	# sok csillagnál kicsit kisebbek, hogy ne folyjanak össze
	var size_k := clampf(sqrt(48.0 / maxf(float(n), 1.0)), .72, 1.0)
	var star_a := lerpf(lerpf(.5, 1.75, night), 1.7, e)
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
		var w: Vector3 = (s.pos as Vector3) + _origin
		_world[id] = w
		if fade <= .001 or cam.is_position_behind(w) or _occluded(w):
			continue
		# mélység: a kozmoszban a közeli csillag nagyobb és fényesebb (a bolygók közt alig)
		var depth := clampf(dref / maxf(eye.distance_to(w), .1), .55, 1.8)
		var dk := lerpf(1.0, pow(depth, .8), e)
		var is_sel := id == selected and sky_on
		var r := PX_STAR * .5 * size_k * lerpf(.85, 1.05, e) * dk * (1.25 if is_sel else 1.0) * (1.0 + 1.4 * flare)
		# lassú, halk pislákolás
		var tw := 1.0 + .12 * sin(_t * 1.7 + float(s.seq) * 2.3)
		var sp := cam.unproject_position(w)
		shown[id] = sp
		_dots.append([sp, r, s.col, star_a * clampf(dk, .6, 1.25) * fade * (1.0 + flare) * tw])
	# a kozmoszban az otthon: halvány meleg fény a bolygórendszer körül, alatta a neve
	_home = []
	if e > .3:
		var hc: Vector3 = host.planet.global_position.lerp(host.system.overview_pose()[1], host.system.overview())
		if not cam.is_position_behind(hc):
			var many: bool = not (host.system.minis as Array).is_empty()
			_home = [cam.unproject_position(hc), _smooth((e - .3) / .5), "a bolygóid" if many else str(host.planet.planet_name())]
	# a kiválasztott csillag gyűrűje (nyitott lapnál), és az érkezéskor szétfutó gyűrű
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
		_rings.append([shown[ring_id], rs, rc, ra * lerpf(.75, 1.2, maxf(night, e))])
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
				sm.set_shader_parameter("glow_amt", lerpf(host.glow_amt_of(t.glow, float(host.night)), _glow_peak, glow))
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
		Sound.fx("star")
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


## A rajz (additív): halvány haló, közép, fehéres mag; gyűrűk. A mag a csillag színéből fehérbe hajlik.
func _draw_sky() -> void:
	if not _home.is_empty():
		var hp: Vector2 = _home[0]
		var ha: float = _home[1]
		var warm := Color(1.0, .86, .62)
		_canvas.draw_circle(hp, 46.0, Color(warm, .035 * ha))
		_canvas.draw_circle(hp, 26.0, Color(warm, .06 * ha))
		_canvas.draw_arc(hp, 30.0 + 2.0 * sin(_t * 1.3), 0.0, TAU, 48, Color(warm, .28 * ha), 1.2, true)
		var font := _canvas.get_theme_default_font()
		var txt: String = _home[2]
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_canvas.draw_string(font, (hp + Vector2(-w * .5, 50.0)).floor(), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(warm, .7 * ha))
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
