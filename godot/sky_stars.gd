class_name SkyStars
extends Node3D
## Csillagok az égbolton (M6; 2026. 11. 11. óta a játékoséi, nem a bolygóké): az elengedett fák és a keresztezés el nem
## választott csírái. Nem csillagkép, nem gócpont: szétszórva ragyognak az égen.
##  - A csillag helye determinisztikus: a játékoskódból és a csillag sorszámából (seq) egy pont az égbolt egységnyi
##    négyzetén (R2 kis eltérésű sorozat, kis remegéssel): bármennyi csillag egyenletesen szóródik, és egy csillag
##    visszahozása vagy egy új érkezése nem mozdítja el a többit. Nincsenek vonalak.
##  - Hol látszik: az égbolt nagyon messze, a kamera mögött lebeg (mint a Hold az autóablakból): a kamera forgásakor
##    puhán lemaradva követi. Bolygó-nézetben és leszállva az egész képet beborítja (a bolygó és a fák lombja eltakarja,
##    ami mögöttük van), így mindig szétszórva látszik néhány.
##  - „Felnézek az égboltra” (herbarium.gd): a kamera felfordul az ég felé (a bolygó lecsúszik a kép aljára), az ég
##    elsötétül, és a csillagok a kép felső kétharmadába rendeződnek – mindegyik látszik, egy képernyőn. Koppintás egy
##    csillagra: a lapja (gyűrű jelöli).
##  - Nappal halványan, éjjel fényesen (felnézve mindig jól látszanak); a csillag színe a fa virágszínéből. Olcsó: a
##    helyek 3D-ben (a kamerától messze), a rajz 2D-ben (a 3D-kép fölött, a gombsor alatt, additív keveréssel, ≤128
##    csillag). Így weben is biztosan ugyanaz: a WebGL-es próbán a képkockánként frissített MultiMesh-példányok nem
##    rajzolódtak ki, a 2D rajz igen; és a lencse sem mossa el.
##  - Elengedés: a fa fénnyel átjárva, a csúcsaitól kezdve fénypontokká oszlik, a fények összegyűlnek a koronája fölött,
##    és egy fény lassan, csóvával felszáll az égre, ahol csillag lesz (release()); közben a kamera felnéz. Visszahozás:
##    a csillag felvillan és elhalványul (recall()); a mag útja a táskába a 2D rétegben (herbarium.gd).
##
## A főjelenet (main.gd) tagjait használja, ezért a host típus nélküli: cam, planet, game, saved_view, garden_mode,
## night, trees, plants.

## Elengedéskor a fa eltűnt a jelenetből (a hívó kiveszi a fák közül, és felemeli a kamerát).
signal gone(tree: Dictionary)
## A felszálló fény megérkezett: a csillag kigyullad az égen.
signal arrived(star_id: int)

## A csillagok távolsága a kamerától (a bolygó és a holdak mögött).
const DIST := 150.0
## Ennyi csillag látszik legfeljebb (a sorszám szerinti első ennyi; a többi a mentésben megvan).
const MAX_STARS := 128
## Az égbolt egységnyi négyzete a képernyőn (a kép méretének arányában: bal felső sarok és méret). Szokásos nézetben az
## egész kép (ami a bolygó vagy egy fa mögé esik, nem látszik), felnézve a kép felső része (alul a csillag lapja).
const AREA_PASSIVE := Rect2(.05, .05, .90, .86)
const AREA_SKY := Rect2(.08, .115, .84, .52)
## Felnézéskor ennyit fordul fel a kamera (radián): a bolygó a kép aljára csúszik.
const TILT_SKY := .42
## Képpontban: a csillag (haló együtt) átmérője, a kiválasztott csillag gyűrűje.
const PX_STAR := 26.0
const PX_RING := 58.0
## A koppintás sugara (képpont): telefonon nagy érintési terület.
const TAP_R := 46.0
## Az R2 sorozat lépései (a „plasztikus szám” hatványainak reciproka) és a remegés (az egységnégyzetben).
const R2_A := Vector2(.7548776662466927, .5698402909980532)
const JITTER := .035

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
## Csillagok: [{"id", "seq", "rec", "col", "fade" (0–1), "leave" (-1 vagy a távozás ideje), "pos" (helye az égbolt
## egységnégyzetén)}]
var list: Array = []
## Felnézve (az égbolt-nézet nyitva); a kiválasztott csillag azonosítója (-1 = egyik sem, csak az égbolt).
var sky_on := false
var selected := -1
## 0–1: átúszás a felnézésbe; a kamera felfordulása (radián, a main.gd alkalmazza).
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
## sorszám → hely az égbolt egységnégyzetén (a játékoskódból)
var _spots := {}
var _sky_q := Quaternion.IDENTITY
var _sky_set := false
## a rajzréteg (a 3D fölött, a gombsor alatt): az elsötétülő ég (felnézve) és a rajzlisták: csillagok, gyűrű, az
## elengedés fényei
var _layer := CanvasLayer.new()
var _veil := Control.new()
var _canvas := Control.new()
var _dots: Array = []
var _rings: Array = []
var _fx_dots: Array = []
var _t := 0.0
## a csillagok világbeli helye ebben a képkockában (id → Vector3)
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
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.draw.connect(_draw_veil)
	_layer.add_child(_veil)
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


## A seq. csillag helye az égbolt egységnégyzetén: R2 sorozat (egymás utáni pontjai messze esnek egymástól, és
## bármennyi pont egyenletesen tölti ki a négyzetet) a játékoskódból eltolva, kis remegéssel, körbefordítva. Csak a
## játékoskódtól és a sorszámtól függ, így a meglévők sosem mozdulnak el.
func spot(seq: int) -> Vector2:
	if _spots.has(seq):
		return _spots[seq]
	var r := RandomNumberGenerator.new()
	r.seed = hash(_code + "egbolt")
	var o := Vector2(r.randf(), r.randf())
	r.seed = hash(_code + "egbolt" + str(seq))
	var p := o + R2_A * float(seq + 1) + Vector2(r.randf_range(-JITTER, JITTER), r.randf_range(-JITTER, JITTER))
	p = Vector2(fposmod(p.x, 1.0), fposmod(p.y, 1.0))
	_spots[seq] = p
	return p


# ---------------------------------------------------------------- Felnézés

## Felnézés az égboltra (id: a kiválasztott csillag, -1 = csak az égbolt).
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
	var bd := TAP_R * (1.25 if sky_on else 1.0)
	for s in list:
		var id := int(s.id)
		if float(s.leave) >= 0.0 or id == hidden_id or not _world.has(id) or (not sky_on and _occluded(_world[id])):
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
	var o: Vector3 = host.cam.global_position
	var d := (w - o).normalized()
	for oc in _occ:
		if _hits(o, d, oc[0], oc[1]):
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


static func _hits(o: Vector3, d: Vector3, center: Vector3, r2: float) -> bool:
	var c := center - o
	var tca := c.dot(d)
	if tca < 0.0:
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
	_veil.visible = on
	if not on:
		return
	var cam: Camera3D = host.cam
	var k := 1.0 if snap else 1.0 - exp(-delta * 2.0)
	sky_k = lerpf(sky_k, 1.0 if sky_on else 0.0, k)
	if absf(sky_k - (1.0 if sky_on else 0.0)) < .002:
		sky_k = 1.0 if sky_on else 0.0
	tilt = TILT_SKY * _smooth(sky_k)
	# az égbolt kerete: a kamera kerete, puhán lemaradva (forgáskor és felnézéskor az ég „mögötte marad”, aztán utoléri)
	var q0 := cam.global_transform.basis.orthonormalized().get_rotation_quaternion()
	if not _sky_set or snap:
		_sky_q = q0
		_sky_set = true
	else:
		_sky_q = _sky_q.slerp(q0, 1.0 - exp(-delta * 2.4)).normalized()
	_gather_occluders()
	if not rel.is_empty():
		_step_release(delta)
	# a visszahozott csillag elhalványulása után ki a listából
	list = list.filter(func(s: Dictionary) -> bool: return float(s.leave) < 0.0 or _t - float(s.leave) < 1.5)
	_place(delta)
	_veil.queue_redraw()
	_canvas.queue_redraw()


## A csillagok helye ebben a képkockában: az égbolt egységnégyzete a képernyőn (szokásos nézetben az egész kép,
## felnézve a felső része) → irány a lemaradó égbolt-keretben → világbeli pont messze a kamera mögött.
func _place(delta: float) -> void:
	var cam: Camera3D = host.cam
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var night: float = clampf(float(host.night), 0.0, 1.0)
	var e := _smooth(sky_k)
	var area := Rect2(AREA_PASSIVE.position.lerp(AREA_SKY.position, e), AREA_PASSIVE.size.lerp(AREA_SKY.size, e))
	var th := tan(deg_to_rad(cam.fov) * .5)
	var aspect := vp.x / maxf(vp.y, 1.0)
	var sky := Basis(_sky_q)
	var eye := cam.global_position
	_world.clear()
	_dots.clear()
	_rings.clear()
	var shown := {}
	var n := 0
	for s in list:
		if float(s.leave) < 0.0:
			n += 1
	# sok csillagnál kicsit kisebbek, hogy felnézve se folyjanak össze
	var size_k := clampf(sqrt(48.0 / maxf(float(n), 1.0)), .72, 1.0)
	var passive_a := lerpf(.5, 1.75, night)
	var star_a := lerpf(passive_a, maxf(passive_a, 1.6), e)
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
		var f: Vector2 = area.position + area.size * (s.pos as Vector2)
		var dir := (sky * Vector3((f.x * 2.0 - 1.0) * th * aspect, (1.0 - f.y * 2.0) * th, -1.0)).normalized()
		var w := eye + dir * DIST
		_world[id] = w
		# felnézve mind látszik (a bolygó ilyenkor a kép alján, a csillagok fölötte)
		if fade <= .001 or cam.is_position_behind(w) or (e < .5 and _occluded(w)):
			continue
		var is_sel := id == selected and sky_on
		var r := PX_STAR * .5 * size_k * lerpf(.85, 1.3, e) * (1.25 if is_sel else 1.0) * (1.0 + 1.4 * flare)
		# lassú, halk pislákolás
		var tw := 1.0 + .12 * sin(_t * 1.7 + float(s.seq) * 2.3)
		var sp := cam.unproject_position(w)
		shown[id] = sp
		_dots.append([sp, r, s.col, star_a * fade * (1.0 + flare) * tw])
	# a kiválasztott csillag gyűrűje (felnézve), és az érkezéskor szétfutó gyűrű
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
	for dl in [_dots, _fx_dots]:
		for d in dl:
			_glow(d[0], d[1], d[2], d[3])
	for rg in _rings:
		var col: Color = rg[2]
		var al: float = rg[3]
		_canvas.draw_arc(rg[0], rg[1], 0.0, TAU, 56, Color(col, minf(al * .25, 1.0)), 7.0, true)
		_canvas.draw_arc(rg[0], rg[1], 0.0, TAU, 56, Color(col, minf(al * .9, 1.0)), 2.0, true)


## Felnézve az ég elsötétül (nappal erősebben): felül mély éjkék, lefelé halványuló – a csillagok nappal is ragyognak.
func _draw_veil() -> void:
	var e := _smooth(sky_k)
	if e <= .001:
		return
	var night: float = clampf(float(host.night), 0.0, 1.0)
	var a := e * lerpf(.72, .35, night)
	var sz := _veil.size
	var top := Color(.025, .02, .09, a)
	var mid := Color(.04, .03, .12, a * .8)
	var bot := Color(.05, .035, .14, 0.0)
	_veil.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), Vector2(sz.x, sz.y * .6), Vector2(0, sz.y * .6)]),
		PackedColorArray([top, top, mid, mid]))
	_veil.draw_polygon(PackedVector2Array([Vector2(0, sz.y * .6), Vector2(sz.x, sz.y * .6), Vector2(sz.x, sz.y), Vector2(0, sz.y)]),
		PackedColorArray([mid, mid, bot, bot]))


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
