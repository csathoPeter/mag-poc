class_name Tending
extends Node3D
## Gondozás a mentett bolygón (M4): öntözés, lekonyulás, virágzás, maggyűjtés. A szabályok a care.gd-ben vannak,
## itt a látvány és az érintés:
##  - A fák kinézete shader-paraméterekből jön (droop, thirst a fán, levélen, virágon; bloom_* és pick a virágon),
##    így olcsó, és a növény váza, determinizmusa nem változik. Napváltáskor („nap +1”, éjfél) minden lassan
##    átúszik az új állapotba; ha egy fán nincs virág, a virágok MultiMesh-e ki se rajzolódik.
##  - Szomjas fa mellett apró, lassan lüktető vízcsepp-fény (kívülről is látszik halvány pontként). Leszállva a fára
##    egy koppintás = öntözés: csillogó cseppek hullanak a lombra, vízszínű fénygyűrű, a fa rugalmasan (kicsit
##    túllendülve) felegyenesedik, a színe visszatér. watered = ma, mentés.
##  - Virágzó fán, amelyik ma még hozhat magot, egy virágon arany csillanás. Leszállva egy virágra koppintva
##    (vagy a csillanásra) a mag kis fényként felemelkedik és a Táska gombja felé repül; a virág összecsukódik és
##    elsápad. Naponta fánként egy (a természet a korlát, nincs számláló).
##
## A főjelenet (main.gd) tagjait használja, ezért a host típus nélküli: trees, planet, cam, eye, game, saved_view,
## fx, hatching, bag_btn, view, focus, _tag_text().

## A mag a táskába ért (a táska gombja ekkor villan fel).
signal seed_arrived(seed_id: int)

const DOT := preload("res://shaders/glow_dot.gdshader")
const FLOWER := preload("res://shaders/flower.gdshader")

const C_WATER := Color(.62, .86, 1.0)
const C_GLINT := Color(1.0, .9, .64)
## A repülő mag színe (mélyebb arany, mert keverve rajzoljuk, nem additívan).
const C_FLY := Color(1.0, .74, .3)
## Öntözés: a cseppek hullása (0 – ~2 mp), a felegyenesedés (WATER_SPRING-től), a szín visszatérése.
const WATER_LEN := 3.6
const WATER_SPRING := .45
## Maggyűjtés: a mag felemelkedik (– GATHER_RISE), majd a táska felé repül (– GATHER_LEN).
const GATHER_RISE := .75
const GATHER_LEN := 2.1
const DROPS := 44
const MARKS := 64
const TRAIL := 6
## A rövid megjegyzés („Megöntözted…”) ennyi ideig áll a lebegő táblán, utána az állapot.
const NOTE_LEN := 4.5

var host
## Az a nap, amelyikre a fák kinézete most be van állítva.
var day := 0
## Képernyőképhez: az öntözés / maggyűjtés idővonala ennél a pontnál áll (-1 = fut).
var freeze_at := -1.0

var _marks := MultiMeshInstance3D.new()
var _drops := MultiMeshInstance3D.new()
## A repülő mag a 2D rétegben (a gombok fölött is látszik, a világos nappali égen is).
var _fly_layer := CanvasLayer.new()
var _fly := Control.new()
var _fly_pts: Array = []
## A futó öntözés: {"tree": a fa (a host.trees eleme), "t": idő, "d0": a lekonyulás a kezdetkor, "th0": szomjúság}
var _water := {}
## A futó maggyűjtés: {"from": a virág helye, "up": a fa iránya, "t": idő, "id": a mag azonosítója}
var _gather := {}
var _note := ""
var _note_tree: Dictionary = {}
var _note_t := 0.0
var _check_t := 0.0
## A cseppek álvéletlen adatai (egyszer kiszámolva): [szög, sugár, magasság, méret, fázis]
var _drop_rnd: Array = []


func _ready() -> void:
	for i in DROPS:
		_drop_rnd.append([_rnd(i, 1) * TAU, sqrt(_rnd(i, 2)), _rnd(i, 3), _rnd(i, 4), _rnd(i, 5)])
	_marks.multimesh = SeedFx._multimesh(SeedFx._quad(), MARKS, true)
	var mm := SeedFx._mat(DOT, 7)
	# kívülről (a bolygó-nézetből) is látsszon egy-két képpontnyi fény
	mm.set_shader_parameter("min_ang", .009)
	_marks.material_override = mm
	_drops.multimesh = SeedFx._multimesh(SeedFx._quad(), DROPS, true)
	_drops.material_override = SeedFx._mat(DOT, 7)
	_drops.visible = false
	for mi in [_marks, _drops]:
		(mi as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MultiMeshInstance3D).top_level = true
		add_child(mi)
	_fly_layer.layer = 3
	add_child(_fly_layer)
	_fly.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fly.draw.connect(_draw_fly)
	_fly_layer.add_child(_fly)


## Minden futó effekt leáll (bolygóváltáskor, újraépítéskor).
func reset() -> void:
	_water = {}
	_gather = {}
	_note = ""
	_note_tree = {}
	_drops.visible = false
	_fly_pts.clear()
	_fly.queue_redraw()


# ---------------------------------------------------------------- A fák kinézete

## Új fa a jelenetben (main._spawn_on_planet): a mentett rekordja, a virág-MultiMesh-ek, a kinézet azonnal beállítva.
## A próba-bolygón (nincs mentett rekord) a fák mindig virágoznak, és nem szomjaznak.
func attach(t: Dictionary) -> void:
	var rec: Dictionary = {}
	if host.saved_view and int(t.sid) >= 0:
		rec = host.game.find_tree(int(t.sid))
	var fmis: Array = []
	for lod in t.lods:
		for c in (lod.node as Node3D).get_children():
			if c is MultiMeshInstance3D and (c as MultiMeshInstance3D).material_override.shader == FLOWER:
				fmis.append(c)
	var pg: PlantGen = t.high.pg
	t.care = {"rec": rec, "fmis": fmis, "glint": _glint_flower(pg, str((t.g as Dictionary).code)), "cur": {}, "want": {}}
	day = GameState.today()
	_retarget(t, true)


## A mai nap szerinti kinézet minden fára (napváltáskor lassan átúszik; snap: azonnal).
func refresh(snap := false) -> void:
	day = GameState.today()
	# a kötözött ágak egy nappal tovább hajlanak (M8)
	host.shaping.on_new_day()
	for t in host.trees:
		if t.has("care"):
			_retarget(t, snap)


func _retarget(t: Dictionary, snap: bool) -> void:
	var c: Dictionary = t.care
	var rec: Dictionary = c.rec
	var w := {"droop": 0.0, "thirst": 0.0, "size": 1.0, "open": 1.0, "fade": 0.0, "drop": 0.0, "pick": 0.0}
	if not rec.is_empty():
		var look := Care.flower_look(rec, day)
		w.droop = Care.droop(rec, day)
		w.thirst = clampf(w.droop * 1.1, 0.0, 1.0)
		w.size = look.size
		w.open = look.open
		w.fade = look.fade
		w.drop = look.drop
		w.pick = 1.0 if Care.gathered_today(rec, day) else 0.0
	c.want = w
	_flags(t)
	if snap or (c.cur as Dictionary).is_empty():
		c.cur = w.duplicate()
		_push(t)


## A jelekhez: szomjas-e, és hozhat-e ma magot (napváltáskor, öntözés és gyűjtés után frissül, nem minden képkockán).
func _flags(t: Dictionary) -> void:
	var rec: Dictionary = t.care.rec
	var today := GameState.today()
	t.care.thirsty = not rec.is_empty() and Care.thirsty(rec, today)
	t.care.seed = not rec.is_empty() and t.care.glint != null and Care.can_gather(rec, today, _garden(rec))


## A fa összes részletességi szintjének anyagába beírja a jelenlegi értékeket.
func _push(t: Dictionary) -> void:
	var c: Dictionary = t.care
	var cur: Dictionary = c.cur
	var rec: Dictionary = c.rec
	var pick_at: Vector3 = rec.get("gathered_at", Vector3.ZERO) if not rec.is_empty() else Vector3.ZERO
	for lod in t.lods:
		for m in lod.mats:
			var sm := m as ShaderMaterial
			sm.set_shader_parameter("droop", cur.droop)
			sm.set_shader_parameter("thirst", cur.thirst)
			if sm.shader == FLOWER:
				sm.set_shader_parameter("bloom_size", cur.size)
				sm.set_shader_parameter("bloom_open", cur.open)
				sm.set_shader_parameter("bloom_fade", cur.fade)
				sm.set_shader_parameter("bloom_drop", cur.drop)
				sm.set_shader_parameter("pick", Vector4(pick_at.x, pick_at.y, pick_at.z, cur.pick))
	for fmi in c.fmis:
		(fmi as Node3D).visible = float(cur.size) > .005


## A csillanó virág (ezen „vár” a mag): a lomb egyik külső, magasabb virága a részletes szinten, a fa kódjából
## választott irányban. A virág helye a növény saját koordinátáiban (vagy null, ha nincs virága).
static func _glint_flower(pg: PlantGen, code: String) -> Variant:
	if pg.flo_p.is_empty():
		return null
	var az := float(Care.str_hash(code + "mag") % 6283) / 1000.0
	var dir := Vector3(cos(az), 0, sin(az))
	var center := Vector3.ZERO
	for p in pg.flo_p:
		center += p
	center /= pg.flo_p.size()
	var best := -1
	var best_s := -1e9
	for i in pg.flo_p.size():
		# a levágott ág virágain nem vár mag (M8)
		if not pg.flower_live(i):
			continue
		var p: Vector3 = pg.flo_p[i]
		var s := (p - center).dot(dir) + (p.y - center.y) * .6
		if s > best_s:
			best_s = s
			best = i
	return pg.flo_p[best] if best >= 0 else null


# ---------------------------------------------------------------- Érintés

## Koppintás a kiválasztott (leszállt) fára. Szomjas fa: öntözés. Virágzó fa, ha ma még hozhat magot, és virágra
## (vagy a csillanásra) koppintottál: maggyűjtés. Visszaadja, hogy kezelte-e (különben a makró-nézet jön).
func tap_focused(i: int, pos: Vector2) -> bool:
	var t: Dictionary = host.trees[i]
	if not t.has("care") or (t.care.rec as Dictionary).is_empty() or not _water.is_empty() or not _gather.is_empty():
		return false
	var rec: Dictionary = t.care.rec
	if Care.thirsty(rec, GameState.today()):
		water(t)
		return true
	if Care.can_gather(rec, GameState.today(), _garden(rec)):
		var local: Variant = _flower_at(t, pos)
		if local != null:
			gather(t, local)
			return true
	return false


## A koppintáshoz legközelebbi virág (a részletes szinten) a növény saját koordinátáiban, vagy null.
func _flower_at(t: Dictionary, pos: Vector2) -> Variant:
	var cam: Camera3D = host.cam
	var pg: PlantGen = t.high.pg
	var xf: Transform3D = (t.high.node as Node3D).transform
	var best: Variant = null
	var bd := 90.0
	for k in pg.flo_p.size():
		if not pg.flower_live(k):
			continue
		var p: Vector3 = pg.flo_p[k]
		var w: Vector3 = xf * p
		if cam.is_position_behind(w):
			continue
		var d := cam.unproject_position(w).distance_to(pos)
		if d < bd:
			bd = d
			best = p
	var g: Variant = t.care.glint
	if g != null:
		var w: Vector3 = xf * (g as Vector3)
		if not cam.is_position_behind(w) and cam.unproject_position(w).distance_to(pos) < maxf(bd, 120.0):
			best = g
	return best


## Öntözés: watered = ma, mentés; cseppek, fénygyűrű, fényhullám, rugalmas felegyenesedés.
func water(t: Dictionary) -> void:
	var rec: Dictionary = t.care.rec
	host.game.water_tree(rec)
	host.game.save()
	_water = {"tree": t, "t": freeze_at if freeze_at >= 0.0 else 0.0, "d0": float(t.care.cur.droop), "th0": float(t.care.cur.thirst)}
	t.care.want = (t.care.want as Dictionary).duplicate()
	t.care.want.droop = 0.0
	t.care.want.thirst = 0.0
	_retarget_flowers(t)
	_flags(t)
	t.wave = 0.0
	_drops.visible = true
	var d: Vector3 = t.dir
	host.fx.burst(host.planet.surface_point(d) + d * .05, d, 2.2, C_WATER)
	Sound.fx("water")
	Sound.tree_of(t, "water")
	_set_note(t, "Megöntözted. Lassan felegyenesedik.")
	_step_water(0.0)


## A virágok új célértéke (öntözés / gyűjtés után), a lekonyulás nélkül (azt az öntözés rugója viszi).
func _retarget_flowers(t: Dictionary) -> void:
	var rec: Dictionary = t.care.rec
	var look := Care.flower_look(rec, GameState.today())
	for k in ["size", "open", "fade", "drop"]:
		t.care.want[k] = look[k]
	t.care.want.pick = 1.0 if Care.gathered_today(rec, GameState.today()) else 0.0


## Maggyűjtés a növény saját koordinátáiban adott virágról: a mag a táskába (mentés), a fény a táska felé repül.
func gather(t: Dictionary, local: Vector3) -> void:
	var rec: Dictionary = t.care.rec
	var s: Dictionary = host.game.gather_seed(rec, local)
	if s.is_empty():
		return
	host.game.save()
	_retarget_flowers(t)
	_flags(t)
	var xf: Transform3D = (t.high.node as Node3D).transform
	_gather = {"from": xf * local, "up": (t.dir as Vector3), "t": freeze_at if freeze_at >= 0.0 else 0.0, "id": int(s.id)}
	Sound.fx("gather")
	Sound.tree_of(t, "gather")
	_set_note(t, "Magot hozott: %s\na táskádba került." % str(s.name))
	_step_gather()


func _set_note(t: Dictionary, msg: String) -> void:
	_note = msg
	_note_tree = t
	_note_t = 0.0
	host._tag_text()


## A lebegő tábla gondozás-sora a kiválasztott fához: rövid megjegyzés (öntözés, mag után), vagy az állapota.
func care_line(t: Dictionary) -> String:
	if _note != "" and is_same(_note_tree, t):
		return _note
	if not t.has("care") or (t.care.rec as Dictionary).is_empty():
		return ""
	return Care.status_text(t.care.rec, GameState.today(), _garden(t.care.rec))


## A kert: az összes bolygó kikelt fái (a maghozás közös tempójához, M8).
func _garden(rec: Dictionary) -> Array:
	return (host.game as GameState).garden_of(rec)


# ---------------------------------------------------------------- Idő

func _process(delta: float) -> void:
	if host == null:
		return
	_check_t += delta
	if _check_t > 2.0:
		_check_t = 0.0
		# éjfélkor (vagy ha más módon változott a nap) a fák lassan átúsznak az új napba
		if GameState.today() != day and host.saved_view:
			refresh()
			if not host.hatching.active():
				host._tag_text()
	if _note != "":
		_note_t += delta
		if _note_t > NOTE_LEN and _water.is_empty() and _gather.is_empty():
			_note = ""
			if not host.hatching.active():
				host._tag_text()
	var k := 1.0 - exp(-delta * 1.4)
	for t in host.trees:
		if not t.has("care"):
			continue
		if not _water.is_empty() and is_same(_water.tree, t):
			continue
		var cur: Dictionary = t.care.cur
		var want: Dictionary = t.care.want
		var moved := false
		for key in want:
			var a: float = cur[key]
			var b: float = want[key]
			if absf(a - b) > .0005:
				cur[key] = b if absf(a - b) < .002 else lerpf(a, b, k)
				moved = true
		if moved:
			_push(t)
	if not _water.is_empty():
		if freeze_at < 0.0:
			_water.t = float(_water.t) + delta
		_step_water(delta)
	if not _gather.is_empty():
		if freeze_at < 0.0:
			_gather.t = float(_gather.t) + delta
		_step_gather()
	_update_marks()


static func _smooth(x: float) -> float:
	var v := clampf(x, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


## Kis, motorfüggetlen álvéletlen 0–1 között (a cseppek helyéhez).
static func _rnd(i: int, k: int) -> float:
	return float(Care.str_hash("%d:%d" % [i, k]) % 10007) / 10007.0


func _step_water(_delta: float) -> void:
	var t: Dictionary = _water.tree
	var wt: float = _water.t
	var cur: Dictionary = t.care.cur
	# rugalmas felegyenesedés: csillapított rezgés (nulla kezdősebességgel), egyszer kicsit túllendül
	var s := maxf(wt - WATER_SPRING, 0.0)
	var kd := 1.5
	var w := 2.3
	cur.droop = float(_water.d0) * exp(-kd * s) * (cos(w * s) + kd / w * sin(w * s))
	cur.thirst = float(_water.th0) * (1.0 - _smooth((wt - .5) / 2.2))
	var want: Dictionary = t.care.want
	var k := _smooth(wt / 2.4)
	for key in ["size", "open", "fade", "drop", "pick"]:
		cur[key] = lerpf(float(cur[key]), float(want[key]), k)
	_push(t)
	# a cseppek: a korona fölül, egymás után, gyorsulva hullanak a lombra és a földre
	var planet: Planet = host.planet
	var d: Vector3 = t.dir
	var base := planet.surface_point(d)
	var fr := Basis(Quaternion(Vector3.UP, d))
	var mm := _drops.multimesh
	var h: float = t.h
	var r: float = maxf(float(t.w) * .75, .5)
	for i in DROPS:
		var start := float(i) / DROPS * 1.25
		var u := clampf((wt - start) / .95, 0.0, 1.0)
		var a := 0.0
		if wt >= start and u < 1.0:
			a = _smooth(u / .12) * (1.0 - _smooth((u - .8) / .2))
		var rn: Array = _drop_rnd[i]
		var ang: float = rn[0]
		var rad: float = rn[1] * r
		var y0 := h * (1.05 + float(rn[2]) * .25)
		var y := lerpf(y0, .1, u * u)
		var p := base + fr * Vector3(cos(ang) * rad, y, sin(ang) * rad)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * (.11 + float(rn[3]) * .06)), p))
		mm.set_instance_color(i, Color(C_WATER, 2.0 * a))
		mm.set_instance_custom_data(i, Color(rn[4], 0, .15, 0))
	if wt >= WATER_LEN and freeze_at < 0.0:
		cur.droop = 0.0
		cur.thirst = 0.0
		_push(t)
		_water = {}
		_drops.visible = false


func _step_gather() -> void:
	var gt: float = _gather.t
	var cam: Camera3D = host.cam
	var vp := get_viewport().get_visible_rect().size
	var to := Vector2(vp.x * .5, 40.0)
	var bb: Control = host.bag_btn
	if bb != null and bb.is_visible_in_tree():
		to = bb.get_global_rect().get_center()
	var from: Vector3 = _gather.from
	var top: Vector3 = from + (_gather.up as Vector3) * .38
	# a mag mérete képpontban: a virág látszó méretéhez igazítva, de mindig jól látható
	var r0 := clampf(vp.y * .012, 6.0, 14.0)
	_fly_pts.clear()
	for i in TRAIL:
		var u := gt - float(i) * .05
		if u < 0.0:
			continue
		var px: Vector2
		var r := r0
		var a := 1.0
		if u < GATHER_RISE:
			# a mag kibújik a virágból és lassan felemelkedik
			var e := _smooth(u / GATHER_RISE)
			var w := from.lerp(top, e)
			if cam.is_position_behind(w):
				continue
			px = cam.unproject_position(w)
			r = r0 * lerpf(.3, 1.0, e)
			a = _smooth(u / .25)
		else:
			# ívben a táska gombja felé, a végén összemegy és beleolvad
			var e := _smooth((u - GATHER_RISE) / (GATHER_LEN - GATHER_RISE))
			var s0 := cam.unproject_position(top)
			px = s0.lerp(to, e) - Vector2(0, sin(e * PI) * vp.y * .05)
			r = r0 * (1.0 - e * .45)
			a = 1.0 - _smooth((e - .88) / .12)
		if i > 0:
			r *= .75 * (1.0 - float(i) / TRAIL * .5)
			a *= .5 * (1.0 - float(i) / TRAIL)
		_fly_pts.append([px, r, a])
	_fly.queue_redraw()
	if gt >= GATHER_LEN and freeze_at < 0.0:
		var id := int(_gather.id)
		_gather = {}
		_fly_pts.clear()
		_fly.queue_redraw()
		Sound.fx("bag")
		seed_arrived.emit(id)


## A repülő mag: puha arany korong, fehér maggal, halvány sötét szegéllyel (hogy a világos égen is látsszon).
func _draw_fly() -> void:
	for k in range(_fly_pts.size() - 1, -1, -1):
		var e: Array = _fly_pts[k]
		var p: Vector2 = e[0]
		var r: float = e[1]
		var a: float = e[2]
		_fly.draw_circle(p, r * 2.6, Color(C_FLY, .12 * a))
		_fly.draw_circle(p, r * 1.7, Color(C_FLY, .22 * a))
		_fly.draw_circle(p, r * 1.12, Color(.22, .1, .28, .28 * a), true, -1.0, true)
		_fly.draw_circle(p, r, Color(C_FLY.lerp(Color.WHITE, .25), .95 * a), true, -1.0, true)
		_fly.draw_circle(p - Vector2(r, r) * .18, r * .5, Color(1, 1, 1, .85 * a))


# ---------------------------------------------------------------- Jelek

## Vízcsepp-fény a szomjas fák mellett, arany csillanás a magot hozó virágon (csak a látható oldalon).
func _update_marks() -> void:
	var mm := _marks.multimesh
	var n := 0
	var busy: bool = host.hatching.active() or host.fx.busy()
	if host.saved_view and not busy:
		var planet: Planet = host.planet
		var eye: Vector3 = host.eye
		for t in host.trees:
			if n >= MARKS - 1:
				break
			if not t.has("care") or (t.care.rec as Dictionary).is_empty() or not bool(t.get("shown", true)) or not bool(t.get("front", true)):
				continue
			var d: Vector3 = t.dir
			var ph := float(int(t.sid) % 7) / 7.0
			if bool(t.care.thirsty) and (_water.is_empty() or not is_same(_water.tree, t)):
				# a fa mellett oldalt (a kamerából nézve balra), félmagasságban lebeg (a lebegő tábla alul van)
				var base := planet.surface_point(d)
				var view := eye - base
				view = (view - d * view.dot(d)).normalized()
				var side := d.cross(view).normalized()
				var p := base + d * maxf(.6, float(t.h) * .5) - side * (float(t.w) * .6 + .45) + view * .3
				mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * .42), p))
				mm.set_instance_color(n, Color(C_WATER, 1.15))
				mm.set_instance_custom_data(n, Color(ph, 0, .35, 0))
				n += 1
			elif bool(t.care.seed):
				var w: Vector3 = (t.high.node as Node3D).transform * (t.care.glint as Vector3) + d * .06
				mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * .22), w))
				mm.set_instance_color(n, Color(C_GLINT, 1.5))
				mm.set_instance_custom_data(n, Color(ph, 0, .5, 0))
				n += 1
	mm.visible_instance_count = n
	_marks.visible = n > 0
