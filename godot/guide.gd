class_name Guide
extends Control
## Első indítás és napi visszatérés (M12) – csendesen, a világban.
##
## Tippek: egyszer megjelenő, vékony, világító feliratok a világban, ott, ahol szükség van rájuk, sorrendben, ahogy
## kellenek. Nincs ablak, nincs kényszer: a tipp a hozzá tartozó mozdulatra (vagy kis idő után magától) elhalványul,
## és nem jön vissza (flags.tips). Ha a játékos előbb megteszi, amit a tipp mondana, a tipp meg sem jelenik.
##   drag     „Húzd: forgatás · csípd: közelítés”, alatta egy lassan húzódó fénypont
##   daily    „Koppints a fénylő magra: a nap magja” a nap magja alatt, vékony fényvonallal felé
##   tree     „Koppints egy fára” – a legközelebbi fa körül puha gyűrű
##   bag      „A magjaid a táskában” a batyu fölött
##   tomorrow „Holnap visszajöhetsz: kikel, amit ma elvetsz” – az első elvetés után
##   planets  „Csípd kifelé: a többi bolygód” – ha már több bolygó van
##
## Reggel (új nap megnyitáskor, vagy „nap +1”): a kép puha fátyolból nyílik (ha valódi idő szerint reggel van, a fény
## hajnalból kel fel), a kikelés (hatching.gd) lefut, aztán ha van szomjas vagy magot érlelő virágzó fa, a kamera
## lassan felé fordul, és egy suttogás szól róla; végül a nap magja hívogatóan lüktet. Nincs lista, nincs feladat.
##
## A főjelenet (main.gd) tagjait használja (típus nélküli host): game, hud, trees, view, garden_mode, saved_view,
## ui_col, fx, hatching, stars, system, herb, share, crossing, shaping, board, bag, bench_on, retreating, cam, planet,
## shot_args, traits_l, tod_i, tod, _tod_target(), _tree_mid(), turn_to().

const ORDER := ["drag", "daily", "tree", "bag", "tomorrow", "planets"]
const TEXT := {
	"drag": "Húzd: forgatás · csípd: közelítés",
	"daily": "Koppints a fénylő magra:\na nap magja",
	"tree": "Koppints egy fára",
	"bag": "A magjaid a táskában",
	"tomorrow": "Holnap visszajöhetsz:\nkikel, amit ma elvetsz",
	"planets": "Csípd kifelé: a többi bolygód",
}
## Mozdulat → az a tipp, amit kivált (vagy fölöslegessé tesz).
const ACTION := {"drag": "drag", "daily": "daily", "tree": "tree", "bag": "bag", "zoomout": "planets"}
## Egy tipp legalább ennyi ideig látszik (ha közben megtette is), és legfeljebb ennyi ideig vár.
const MIN_SHOW := 2.6
const MAX_SHOW := 16.0
## Ennyi nyugodt idő kell két tipp között.
const GAP := 2.2
## A reggel: a fátyol ideje, a jelzés és a hívás közti szünet.
const VEIL_LEN := 3.2
const SIGNAL_LEN := 4.5
const C_TIP := Color(.97, .95, 1.0)
const C_LINE := Color(1.0, .88, .62)

var host
## false: semmi nem jelenik meg és semmi nem íródik (képernyőkép, mérés).
var tips_on := false
## Képernyőképhez: ez a tipp teljes fényerővel (a feltételeitől függetlenül).
var force := ""
## Képernyőképhez: a reggel ideje képkockánként rögzített lépésben halad, és itt megáll (-1 = valós idő).
var morning_freeze := -1.0

var _cur := ""
var _cur_t := 0.0
var _a := 0.0
var _ending := false
var _gap := 0.0
var _pending := {}
var _t := 0.0
var _tree_i := -1
var _tree_check := 0.0
## A reggel állapota: {"t", "phase", "early", "said"}; üres = nincs reggel.
var _m := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# ---------------------------------------------------------------- Kívülről

## Indításkor (a mentett kert betöltése után): új nap esetén reggel. fresh: első indítás (nincs reggel, jönnek a tippek).
func begin(fresh: bool) -> void:
	tips_on = true
	var f: Dictionary = host.game.data.flags
	var today := GameState.today()
	var seen := int(f.get("seen_day", -1))
	if not fresh and seen >= 0 and seen < today:
		start_morning()
	_mark_seen()


## „nap +1” (teszt): a következő nap reggele.
func new_day() -> void:
	if not tips_on:
		return
	start_morning()
	_mark_seen()


func start_morning() -> void:
	var h := Time.get_time_dict_from_system()
	var hour := float(h.hour) + float(h.minute) / 60.0
	if float(host.shot_hour) >= 0.0:
		hour = float(host.shot_hour)
	_m = {"t": 0.0, "phase": 0, "early": hour >= 5.0 and hour < 11.0 and int(host.tod_i) == 0, "said": false, "dawn": false}


## Egy mozdulat megtörtént: a hozzá tartozó tipp elhalványul (vagy meg sem jelenik).
func did(action: String) -> void:
	if not tips_on or not ACTION.has(action):
		return
	var id: String = ACTION[action]
	if _cur == id:
		_ending = true
	elif not _is_done(id):
		_mark(id)


## Esemény, ami egy tippet előhív (pl. az első elvetés után a „holnap” tipp).
func event(name: String) -> void:
	if tips_on and name == "sowed" and not _is_done("tomorrow"):
		_pending.tomorrow = true


func busy() -> bool:
	return not _m.is_empty()


func _is_done(id: String) -> bool:
	return (host.game.data.flags.get("tips", []) as Array).has(id)


func _mark(id: String) -> void:
	var f: Dictionary = host.game.data.flags
	var l: Array = f.get("tips", [])
	if not l.has(id):
		l.append(id)
	f.tips = l
	if host.game.persist:
		host.game.save()


func _mark_seen() -> void:
	host.game.data.flags.seen_day = GameState.today()
	if host.game.persist:
		host.game.save()


# ---------------------------------------------------------------- Képkockánként

## Nyugodt-e a kép: a saját kert látszik, semmi nincs nyitva, nincs nagy pillanat.
func _calm() -> bool:
	return host.garden_mode == "planet" and host.saved_view and host.ui_col.visible and not host.fx.busy() and not host.hatching.active() \
		and (host.hatching.waiting as Array).is_empty() and not host.stars.busy() and not host.system.busy() and not host.bench_on \
		and not host.retreating and not host.herb.is_open() and not host.share.is_open() and not host.crossing.is_open() \
		and not host.shaping.on and not host.board.visible and not host.bag.visible and (host.queue as Array).is_empty()


func _want(id: String) -> bool:
	match id:
		"drag":
			return host.view == "orbit"
		"daily":
			return host.view == "orbit" and host.hud.orb.visible and host.hud.orb.modulate.a > .5
		"tree":
			return host.view == "orbit" and _tree_i >= 0
		"bag":
			return not (host.game.data.bag as Array).is_empty() and host.hud.pouch.visible
		"tomorrow":
			return _pending.has("tomorrow")
		"planets":
			return host.view == "orbit" and (host.game.data.planets as Array).size() > 1
	return false


func _process(delta: float) -> void:
	_t += delta
	if host == null:
		return
	var shot: bool = not (host.shot_args as Array).is_empty()
	_tree_check -= delta
	if _tree_check <= 0.0:
		_tree_check = .5
		_tree_i = _pick_tree()
	if not _m.is_empty():
		_morning(1.0 / 5.0 if shot else delta)
	queue_redraw()
	if force != "":
		_a = 1.0
		return
	if not tips_on:
		return
	var calm := _calm() and _m.is_empty()
	if _cur == "":
		_gap = _gap + delta if calm else 0.0
		if _gap > GAP:
			for id in ORDER:
				if not _is_done(id) and _want(id):
					_cur = id
					_cur_t = 0.0
					_ending = false
					_a = 0.0
					break
		return
	_cur_t += delta if calm else 0.0
	if _cur_t > MAX_SHOW or not _want(_cur):
		_ending = true
	var fading := _ending and _cur_t > MIN_SHOW
	var want := 1.0 if calm and not fading else 0.0
	_a = move_toward(_a, want, delta / (.9 if want > _a else 1.2))
	if fading and _a <= 0.0:
		_mark(_cur)
		_pending.erase(_cur)
		_cur = ""
		_gap = 0.0


## A reggeli pillanat lépései: fátyol (és hajnal), a kikelés kivárása, gondozási jelzés, a nap magjának hívása.
func _morning(dt: float) -> void:
	if morning_freeze >= 0.0 and float(_m.t) >= morning_freeze:
		return
	_m.t = float(_m.t) + dt
	var t: float = _m.t
	if bool(_m.early) and not bool(_m.dawn):
		# valódi reggel: a fény hajnalból kel fel (a napszak lassan úszik a valódi órához)
		_m.dawn = true
		host.tod = fposmod(float(host._tod_target()) - 1.5, 24.0)
	match int(_m.phase):
		0:
			if t >= VEIL_LEN * .6:
				_m.phase = 1
		1:
			# a kikelés és minden nagy pillanat után
			if _calm():
				_m.phase = 2
				_m.t2 = t
				_signal()
		2:
			if t - float(_m.t2) >= (SIGNAL_LEN if bool(_m.said) else .6):
				_m.phase = 3
				if not host.game.daily_done(GameState.today()):
					host.hud.orb_call = 7.0
		3:
			if t - float(_m.t2) >= 9.0:
				_m = {}


## Ha van szomjas vagy ma magot érlelő, virágzó fa a bolygón, a kamera lassan felé fordul, és egy suttogás szól róla.
func _signal() -> void:
	var p: Dictionary = host.game.active_planet()
	var today := GameState.today()
	var pick := {}
	var kind := ""
	for st in host.game.hatched(p):
		if Care.thirsty(st, today):
			pick = st
			kind = "thirsty"
			break
	if pick.is_empty():
		for st in host.game.hatched(p):
			if Care.can_gather(st, today, host.game.garden_of(st)):
				pick = st
				kind = "bloom"
				break
	if pick.is_empty():
		return
	var nm := Genes.latin_name(pick.dna)
	if kind == "thirsty":
		host.traits_l.text = "%s lekonyult. Egy kis víz jólesne neki." % nm
	else:
		host.traits_l.text = "%s virágzik: egy virágjáról magot szedhetsz." % nm
	var hour := float(host._tod_target())
	host.name_l.text = "Jó reggelt!" if bool(_m.early) else ("Csendes éjszaka" if hour >= 22.0 or hour < 5.0 else ("Jó estét" if hour >= 18.0 else "Szép napot"))
	_m.said = true
	if host.view == "orbit":
		host.turn_to(pick.dir)


## A tipphez a legközelebbi, látszó fa (a kép közepéhez).
func _pick_tree() -> int:
	if host.garden_mode != "planet" or host.view != "orbit":
		return -1
	var vp := get_viewport_rect().size
	var best := -1
	var bd := 1e9
	for i in (host.trees as Array).size():
		var t: Dictionary = host.trees[i]
		if not bool(t.get("front", false)):
			continue
		var c: Vector3 = host._tree_mid(t)
		if host.cam.is_position_behind(c):
			continue
		var s: Vector2 = host.cam.unproject_position(c)
		if s.x < 30.0 or s.x > vp.x - 30.0 or s.y < vp.y * .2 or s.y > vp.y * .85:
			continue
		var d := s.distance_to(vp * Vector2(.5, .55))
		if d < bd:
			bd = d
			best = i
	return best


# ---------------------------------------------------------------- Rajz

func _draw() -> void:
	var vp := get_viewport_rect().size
	# reggeli fátyol: valódi reggel meleg barack, máskor mély lila, puhán szétoszlik
	if not _m.is_empty():
		var u := clampf(float(_m.t) / VEIL_LEN, 0.0, 1.0)
		var a := pow(1.0 - u, 2.0)
		if a > .003:
			var col := Color(1.0, .87, .76) if bool(_m.early) else Color(.12, .07, .24)
			draw_rect(Rect2(Vector2.ZERO, vp), Color(col, (.62 if bool(_m.early) else .7) * a))
	var id := force if force != "" else _cur
	if id == "" or _a < .01 or not host.ui_col.visible:
		return
	var a := _a
	var hud: Hud = host.hud
	match id:
		"drag":
			var c := vp * Vector2(.5, .74)
			# egy ujjnyi fénypont lassan jobbra-balra húz, csóvával
			var ph := _t * 1.1
			for k in 7:
				var q := sin(ph - k * .09)
				var p := c + Vector2(q * 46.0, -cos(ph - k * .09) * 6.0)
				draw_circle(p, (9.0 - k) * .9, Color(C_TIP, (.42 if k == 0 else .12 * (1.0 - k / 7.0)) * a))
			_text(c + Vector2(0, 44), TEXT.drag, a)
		"daily":
			var o: Vector2 = hud.orb.position + hud.orb.size * .5
			var at := o + Vector2(0, 66)
			at.x = clampf(at.x, 120.0, vp.x - 120.0)
			_dotted(at + Vector2(0, -16), o + Vector2(0, 26), a)
			_text(at + Vector2(0, 4), TEXT.daily, a)
		"tree":
			var c := vp * Vector2(.5, .74)
			if _tree_i >= 0:
				var s: Vector2 = host.cam.unproject_position(host._tree_mid(host.trees[_tree_i]))
				var r := 34.0 + sin(_t * 2.0) * 4.0
				draw_arc(s, r, 0.0, TAU, 56, Color(C_LINE, .55 * a), 1.6, true)
				draw_arc(s, r + 9.0, 0.0, TAU, 56, Color(C_LINE, .18 * a), 1.0, true)
				c = Vector2(clampf(s.x, 110.0, vp.x - 110.0), clampf(s.y + r + 34.0, vp.y * .3, vp.y * .86))
			_text(c, TEXT.tree, a)
		"bag":
			var b: Vector2 = hud.pouch.position + hud.pouch.size * Vector2(.5, .3)
			var at := Vector2(maxf(b.x + 70.0, 120.0), b.y - 70.0)
			_dotted(at + Vector2(-40, 8), b + Vector2(16, -22), a)
			_text(at, TEXT.bag, a)
		"tomorrow":
			_text(vp * Vector2(.5, .72), TEXT.tomorrow, a)
		"planets":
			var c := vp * Vector2(.5, .72)
			var u := fmod(_t * .5, 1.0)
			for s in [-1.0, 1.0]:
				draw_circle(c + Vector2(s * (10.0 + u * 34.0), -34.0 + s * -(4.0 + u * 10.0)), 6.0, Color(C_TIP, .38 * a * (1.0 - u * .6)))
			_text(c + Vector2(0, 10), TEXT.planets, a)


## Vékony, világító felirat középre igazítva (több sor is).
func _text(at: Vector2, text: String, a: float) -> void:
	var font: Font = host.hud.thin_font
	var fs := 16
	var lines := text.split("\n")
	var lh := font.get_height(fs) + 2.0
	for i in lines.size():
		var line: String = lines[i]
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := (at + Vector2(-w * .5, i * lh)).floor()
		draw_string_outline(font, p, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(.62, .48, 1.0, .16 * a))
		draw_string_outline(font, p, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(.14, .08, .28, .42 * a))
		draw_string(font, p, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(C_TIP, .95 * a))


## Pontozott fényvonal (a tipp és a tárgya között).
func _dotted(from: Vector2, to: Vector2, a: float) -> void:
	var n := maxi(int(from.distance_to(to) / 9.0), 2)
	for i in n + 1:
		var u := float(i) / n
		var tw := .6 + .4 * sin(_t * 3.0 - u * 6.0)
		draw_circle(from.lerp(to, u), 1.6, Color(C_LINE, .7 * a * tw))
