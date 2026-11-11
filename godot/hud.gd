class_name Hud
extends Control
## Diegetikus felület (M12): szinte nincs képernyőelem, a játék a világban él.
##  - A nap magja: a bolygó fölött lebegő, lassan lélegző, fénylő mag (`orb`). Koppintva nyílik a mai tábla; ha ma
##    már kész, elhalványul és eltűnik (a kihagyott napok a táskában várnak). Reggel (guide.gd) hívogatóan lüktet.
##  - Magos táska: kis, puha, rajzolt batyu a bal alsó sarokban (`pouch`), rajta a magok fénypöttyökkel (arany: mag,
##    menta: megfejtetlen nap, zöld: választásra váró csírák). A „mag a táskába repül” animációk célpontja.
##  - Bolygónév és leírás: vékony, finoman világító felirat fent középen (`name_l`, `traits_l` a main.gd-ből), ami
##    kis idő után elhalványul; a bolygó-nézetben koppintásra / forgatáskor visszajön. Az üzenetek (pl. „Elvetve: …”)
##    is így jelennek meg: minden szövegváltozás felébreszti.
##  - Jobb felső sarok: puha „…” fény → kis lap: hang be/ki, „Bolygóm megosztása”.
##  - Fejlesztői mód (`debug`): mérőszámok, a két apró gombsor, napszak, állapotsor. Alapból rejtve; `?debug` (vagy
##    `?debug=0`), illetve hármas koppintás a bal felső sarokba váltja, a mentésbe kerül (flags.debug).
##
## A főjelenet (main.gd) tagjait használja (típus nélküli host): game, garden_mode, view, cam, planet, saved_view,
## shot_args, bench_on, macro, shaping, sound, share, system, trees, guest, open_daily(), open_bag(), _planet_texts().

const C_SEED := Color(1.0, .86, .55)
const C_DAY := Color(.56, .96, .84)
const C_SPROUT := Color(.70, 1.0, .58)
const C_TEXT := Color(.96, .94, 1.0)
const C_GLOW := Color(.66, .52, 1.0)
## A hármas koppintás helye (bal felső sarok) és ideje (ms, két koppintás között).
const TAP_ZONE := Vector2(88, 72)
const TAP_GAP := 900

var host

var debug := false
var dbg_box := VBoxContainer.new()
var dbg_rows := VBoxContainer.new()
var whisper_box := VBoxContainer.new()
var orb := Button.new()
var pouch := Button.new()
var menu_dot := Button.new()
var menu := PanelContainer.new()
var thin_font := FontVariation.new()

## A suttogás (bolygónév, leírás, üzenetek) átlátszósága és hátralévő ideje.
var whisper_a := 0.0
## Reggeli hívás (guide.gd): ennyi ideig lüktet erősebben a nap magja.
var orb_call := 0.0

var _top := VBoxContainer.new()
var _w_key := ""
var _w_hold := 0.0
var _t := 0.0
var _orb_pos := Vector2(-1, -1)
var _orb_a := 0.0
var _bump := 0.0
var _seeds := 0
var _days := 0
var _sprouts := false
var _done := false
var _taps: Array = []
var _menu_t := 0.0
var _sound_l := Label.new()
var _share_b: Button
var _cap_a := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	thin_font.base_font = get_theme_default_font()
	thin_font.variation_embolden = -.35
	thin_font.spacing_glyph = 1
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 18)
	add_child(root)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_theme_constant_override("separation", 6)
	root.add_child(_top)
	dbg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(dbg_box)
	dbg_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dbg_rows.visible = false
	whisper_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	whisper_box.add_theme_constant_override("separation", 2)
	whisper_box.modulate.a = 0.0
	_top.add_child(whisper_box)
	for b in [orb, pouch, menu_dot]:
		_flat(b)
		add_child(b)
	orb.custom_minimum_size = Vector2(92, 92)
	orb.size = orb.custom_minimum_size
	orb.tooltip_text = "A nap magja"
	orb.pressed.connect(func() -> void: host.open_daily())
	orb.draw.connect(_draw_orb)
	pouch.custom_minimum_size = Vector2(84, 92)
	pouch.size = pouch.custom_minimum_size
	pouch.tooltip_text = "Magos táska"
	pouch.pressed.connect(func() -> void: host.open_bag())
	pouch.draw.connect(_draw_pouch)
	menu_dot.custom_minimum_size = Vector2(48, 48)
	menu_dot.size = menu_dot.custom_minimum_size
	menu_dot.pressed.connect(func() -> void: open_menu(not menu.visible))
	menu_dot.draw.connect(_draw_menu_dot)
	_build_menu()


func _flat(b: Button) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())


func _build_menu() -> void:
	var sb := BoardView.panel_style()
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(10)
	sb.shadow_size = 18
	menu.add_theme_stylebox_override("panel", sb)
	menu.visible = false
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(menu)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	menu.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	# a hangszóró-ikon (sound.gd rajzolja; a webes betűkészletben nincs hangjegy), mellette a felirata
	var tb: Button = host.sound.make_toggle(row)
	var acc := Color(.85, .8, 1.0)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(acc, .10 if st != "pressed" else .26)
		s.border_color = Color(acc, .45 if st != "focus" else 0.0)
		s.set_border_width_all(1)
		s.set_corner_radius_all(16)
		tb.add_theme_stylebox_override(st, s)
	tb.pressed.connect(func() -> void: _menu_t = 0.0)
	BoardView._style_label(_sound_l, 13, Color(.92, .9, 1.0, .85))
	_sound_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_sound_l)
	_share_b = BoardView.make_button(col, "Bolygóm megosztása", func() -> void:
		open_menu(false)
		host.share.share_planet(), BoardView.C_FREE)
	_share_b.custom_minimum_size = Vector2(0, 40)
	_share_b.add_theme_font_size_override("font_size", 13)
	_share_b.focus_mode = Control.FOCUS_NONE


## A bolygónév és a leírás stílusa: vékony, kerek betű, puha fénylő szegély (a main.gd címkéi).
func style_whisper(title: Label, sub: Label) -> void:
	var sub_font := FontVariation.new()
	sub_font.base_font = get_theme_default_font()
	sub_font.variation_embolden = -.12
	for l in [title, sub]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(l as Label).add_theme_color_override("font_color", C_TEXT)
		# puha fény (árnyék eltolás nélkül, vastagítva) + vékony sötét szegély, hogy a világos égen is olvasható legyen
		(l as Label).add_theme_color_override("font_shadow_color", Color(C_GLOW, .24))
		(l as Label).add_theme_constant_override("shadow_offset_x", 0)
		(l as Label).add_theme_constant_override("shadow_offset_y", 0)
		(l as Label).add_theme_constant_override("shadow_outline_size", 12)
		(l as Label).add_theme_color_override("font_outline_color", Color(.13, .08, .26, .5))
		(l as Label).add_theme_constant_override("outline_size", 4)
	title.add_theme_font_override("font", thin_font)
	title.add_theme_font_size_override("font_size", 27)
	sub.add_theme_font_override("font", sub_font)
	sub.add_theme_font_size_override("font_size", 13)
	whisper_box.add_child(title)
	whisper_box.add_child(sub)


# ---------------------------------------------------------------- Állapot kívülről

## A táska tartalma (a main.gd _sync_daily hívja): magok, megfejtetlen napok, várakozó csírák; kész-e a mai tábla.
func sync_counts(seeds: int, days: int, sprouts: bool, done: bool) -> void:
	_seeds = seeds
	_days = days
	_sprouts = sprouts
	_done = done
	pouch.queue_redraw()


## A táskába ért egy mag: a batyu megemelkedik, felragyog.
func bump() -> void:
	_bump = 1.0


## Koppintás / forgatás a bolygó-nézetben: ha a felirat már elhalványult, a bolygó neve és leírása visszajön.
func wake() -> void:
	if menu.visible:
		open_menu(false)
	if whisper_a > .05 or _w_hold > -1.0 or host == null or host.garden_mode != "planet" or host.view != "orbit":
		return
	host._planet_texts()
	_w_key = _key()
	_w_hold = 5.0


func open_menu(on: bool) -> void:
	menu.visible = on
	_menu_t = 0.0
	menu_dot.queue_redraw()


## Fejlesztői mód be/ki (mérőszámok, apró gombsorok); save: a mentésbe is (flags.debug).
func set_debug(on: bool, save := true) -> void:
	debug = on
	# a kapcsolók a fejlesztői fiókban vannak (debug_drawer.gd, ⚙ a jobb szélen); fent csak a mérőszám-sor látszik,
	# a régi apró gombsorok rejtve maradnak (a fiók ezeket nyomja meg)
	dbg_rows.visible = false
	if save and host != null and not (host.game.data as Dictionary).is_empty() and host.game.persist:
		host.game.data.flags.debug = on
		host.game.save()


func _key() -> String:
	return "%s|%s" % [host.name_l.text, host.traits_l.text]


## A hármas koppintás a bal felső sarokba (fejlesztői mód). Csak érintést számolunk (az egér-utánzatot nem).
func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or not event.pressed:
		return
	var p: Vector2 = event.position
	# fejlesztői módban csak a mérőszám-sor fölött (alatta már a „100%” gomb van)
	if p.x > TAP_ZONE.x or p.y > (TAP_ZONE.y if not debug else 50.0):
		_taps.clear()
		return
	var now := Time.get_ticks_msec()
	if not _taps.is_empty() and now - int(_taps[_taps.size() - 1]) > TAP_GAP:
		_taps.clear()
	_taps.append(now)
	if _taps.size() >= 3:
		_taps.clear()
		# a 3. koppintást elnyeljük, és a sávok csak a képkocka végén jelennek meg: különben a még el nem rendezett
		# gombsor (minden gomb a sarokban) kapná meg ezt az érintést
		get_viewport().set_input_as_handled()
		_toggle_debug.call_deferred()


func _toggle_debug() -> void:
	set_debug(not debug)
	host.traits_l.text = "Fejlesztői mód: %s (hármas koppintás a bal felső sarokba)" % ("be" if debug else "ki")


# ---------------------------------------------------------------- Képkockánként

func _process(delta: float) -> void:
	_t += delta
	if host == null:
		return
	var vp := get_viewport_rect().size
	var shot: bool = not (host.shot_args as Array).is_empty()
	var stats: Label = host.stats_l
	stats.visible = debug or host.bench_on
	# --- suttogás: minden szövegváltozás felébreszti, aztán elhalványul (mérés alatt és képernyőképnél marad)
	var key := _key()
	if key != _w_key:
		_w_key = key
		_w_hold = clampf(4.5 + (host.traits_l.text as String).length() * .035, 5.0, 11.0)
	_w_hold -= delta
	var hold: bool = host.bench_on or (shot and not (host.shot_args as Array).has("faded"))
	var want := 1.0 if (_w_hold > 0.0 or hold) and key != "|" else 0.0
	if shot and (host.shot_args as Array).has("faded"):
		want = 0.0
	whisper_a = want if shot else move_toward(whisper_a, want, delta / (.6 if want > whisper_a else 1.6))
	whisper_box.modulate.a = whisper_a
	# a sarokban lévő tárgyak felirata a suttogással együtt ébred (így felfedezhetők, de nem zsúfolnak)
	_cap_a = whisper_a
	# --- a nap magja
	var top_y := 18.0 + (dbg_box.size.y + 6.0 if dbg_box.size.y > 2.0 and (debug or stats.visible) else 0.0)
	var planet_ok: bool = host.garden_mode == "planet" and not host.macro and not host.shaping.on
	# felnézve (az égbolt-nézetben) a nap magja nem takarja a csillagokat
	var show_orb: bool = planet_ok and not _done and not host.bench_on and not host.herb.looking
	_orb_a = (1.0 if show_orb else 0.0) if shot else move_toward(_orb_a, 1.0 if show_orb else 0.0, delta / .8)
	orb.visible = _orb_a > .01
	orb.mouse_filter = Control.MOUSE_FILTER_STOP if _orb_a > .5 else Control.MOUSE_FILTER_IGNORE
	var target := _orb_target(vp, top_y)
	if _orb_pos.x < 0.0 or shot:
		_orb_pos = target
	else:
		_orb_pos = _orb_pos.lerp(target, 1.0 - exp(-delta * 2.2))
	var bob := Vector2(sin(_t * .7) * 3.0, sin(_t * 1.1) * 5.0)
	orb.position = (_orb_pos + bob - orb.size * .5).floor()
	orb.modulate.a = _orb_a
	orb_call = maxf(orb_call - delta, 0.0)
	orb.queue_redraw()
	# --- táska: bal lent (a „Felnézek az égboltra” jobb lent, herbarium.gd)
	_bump = maxf(_bump - delta * 1.1, 0.0)
	pouch.visible = host.garden_mode == "planet" and not host.bench_on
	pouch.position = Vector2(10.0, vp.y - pouch.size.y - 14.0).floor()
	pouch.queue_redraw()
	# --- „…” jobb fent, alatta a kis lap
	menu_dot.visible = host.garden_mode == "planet" and not host.bench_on
	menu_dot.position = Vector2(vp.x - menu_dot.size.x - 8.0, top_y - 10.0).floor()
	if menu.visible:
		_menu_t += delta
		_sound_l.text = "hang: néma" if host.sound.muted else "hang: szól"
		var can_share: bool = host.saved_view and host.guest.is_empty() and host.view == "orbit" and not (host.trees as Array).is_empty()
		_share_b.visible = can_share
		menu.reset_size()
		menu.position = Vector2(vp.x - menu.size.x - 12.0, menu_dot.position.y + menu_dot.size.y + 2.0).floor()
		if (_menu_t > 7.0 and not shot) or not menu_dot.visible:
			open_menu(false)
	menu_dot.queue_redraw()


## Hol lebegjen a nap magja: kívülről a bolygó pereme fölött jobbra (a képernyőn tartva), leszállva fent az égen.
func _orb_target(vp: Vector2, top_y: float) -> Vector2:
	var p := Vector2(vp.x * .72, top_y + 150.0)
	if host.garden_mode == "planet" and host.view == "orbit":
		var cam: Camera3D = host.cam
		var pc: Vector3 = host.planet.global_position
		if not cam.is_position_behind(pc):
			var c := cam.unproject_position(pc)
			var d := maxf(cam.global_position.distance_to(pc), .1)
			var px := vp.y * .5 / tan(deg_to_rad(cam.fov) * .5)
			var r := float(host.planet.radius) / d * px
			p = c + Vector2(.45, -.89) * (r + 58.0)
	p.x = clampf(p.x, 64.0, vp.x - 92.0)
	p.y = clampf(p.y, top_y + 132.0, vp.y * .42)
	return p


# ---------------------------------------------------------------- Rajz

func _halo(ci: CanvasItem, c: Vector2, r: float, col: Color, a: float) -> void:
	ci.draw_circle(c, r, Color(col, .06 * a))
	ci.draw_circle(c, r * .66, Color(col, .10 * a))
	ci.draw_circle(c, r * .40, Color(col, .18 * a))


## A nap magja: fénylő, lassan lélegző mag (mandula alak), körülötte haló; reggel kifutó fénygyűrűk.
func _draw_orb() -> void:
	var c := orb.size * .5
	var breath := .5 + .5 * sin(_t * 1.6)
	var call := clampf(orb_call / 1.5, 0.0, 1.0)
	# halvány sötét korong a mag mögött: a világos nappali égen is kiemelkedik
	orb.draw_circle(c, 25.0, Color(.12, .07, .26, .20))
	_halo(orb, c, 44.0 + breath * 6.0 + call * 8.0, C_SEED, 1.5 + breath * .4 + call * .8)
	if call > 0.0:
		for k in 2:
			var u := fmod(_t * .55 + k * .5, 1.0)
			orb.draw_arc(c, 14.0 + u * 34.0, 0.0, TAU, 48, Color(C_SEED, .45 * (1.0 - u) * call), 1.6, true)
	# a mag: mandula alak, kissé megdöntve, belül világosabb
	var pts := PackedVector2Array()
	var tilt := -.45 + sin(_t * .5) * .08
	for i in 24:
		var a := TAU * i / 24.0
		var y := cos(a)
		var x := sin(a) * (.62 - .22 * y)
		pts.append(c + Vector2(x * 13.0, -y * 18.0).rotated(tilt))
	orb.draw_colored_polygon(pts, Color(1.0, .78, .40, .95))
	orb.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, .95, .82, .95), 1.4, true)
	# belső fény: világosabb mag a mag közepén
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * .55 + Vector2(-1.5, -3.0).rotated(tilt))
	orb.draw_colored_polygon(inner, Color(1.0, .93, .74, .9))
	orb.draw_circle(c + Vector2(-2.5, -5.0).rotated(tilt), 3.4, Color(1, 1, 1, .9))
	# a felirat a suttogással együtt ébred
	if _cap_a > .02:
		_caption(orb, Vector2(c.x, orb.size.y - 4.0), "a nap magja", _cap_a)


func _caption(ci: CanvasItem, at: Vector2, text: String, a: float) -> void:
	var fs := 11
	var w := thin_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string_outline(thin_font, at - Vector2(w * .5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(.14, .08, .28, .45 * a))
	ci.draw_string(thin_font, at - Vector2(w * .5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(C_TEXT, .85 * a))


## A magos táska: puha, rajzolt batyu, a nyakán kötő, rajta a tartalma fénypöttyökkel.
func _draw_pouch() -> void:
	var s := pouch.size
	var lift := sin(_bump * PI) * 7.0
	var c := Vector2(s.x * .5, s.y * .5 + 2.0 - lift)
	var glow := .6 + .4 * sin(_t * 1.2) + _bump * 1.5
	_halo(pouch, c + Vector2(0, 6), 40.0, Color(.82, .72, 1.0), glow * .7)
	# test: lefelé öblösödő zsák
	var body := PackedVector2Array()
	for i in 29:
		var a := lerpf(-.28, PI + .28, i / 28.0)
		body.append(c + Vector2(cos(a) * 25.0, 8.0 + sin(a) * 19.0))
	body.append(c + Vector2(-9.0, -10.0))
	body.append(c + Vector2(9.0, -10.0))
	# (a pontok sorrendje: a jobb oldalról az alján át a balig, aztán a nyak)
	var fill := Color(.30, .20, .52, .46).lerp(Color(.62, .48, .92, .6), _bump)
	pouch.draw_colored_polygon(body, fill)
	pouch.draw_polyline(body + PackedVector2Array([body[0]]), Color(.94, .88, 1.0, .75), 1.4, true)
	# fodor a nyak fölött
	var top := PackedVector2Array([c + Vector2(-9, -10), c + Vector2(-15, -20), c + Vector2(-6, -17), c + Vector2(0, -23),
		c + Vector2(6, -17), c + Vector2(15, -20), c + Vector2(9, -10)])
	pouch.draw_colored_polygon(top, Color(.36, .25, .60, .50))
	pouch.draw_polyline(top, Color(.94, .88, 1.0, .7), 1.2, true)
	# kötő: zsinór és kis masni
	pouch.draw_line(c + Vector2(-11, -10), c + Vector2(11, -10), Color(1, .86, .62, .9), 2.0, true)
	pouch.draw_arc(c + Vector2(-5, -6), 4.0, -PI * .1, PI * 1.1, 10, Color(1, .86, .62, .8), 1.4, true)
	pouch.draw_arc(c + Vector2(5, -6), 4.0, -PI * .1, PI * 1.1, 10, Color(1, .86, .62, .8), 1.4, true)
	# tartalom: arany = mag, menta = megfejtetlen nap, zöld = várakozó csírák
	var dots: Array = []
	for i in mini(_seeds, 9):
		dots.append(C_SEED)
	for i in mini(_days, 3):
		dots.append(C_DAY)
	if _sprouts:
		dots.append(C_SPROUT)
	var total := _seeds + _days + (1 if _sprouts else 0)
	var spots := [Vector2(0, 10), Vector2(-9, 7), Vector2(9, 7), Vector2(-5, 17), Vector2(5, 17), Vector2(-14, 15), Vector2(14, 15),
		Vector2(0, 1), Vector2(-17, 7), Vector2(17, 7), Vector2(-10, 22), Vector2(10, 22), Vector2(0, 23)]
	for i in mini(dots.size(), spots.size()):
		var p: Vector2 = c + spots[i]
		var tw := .75 + .25 * sin(_t * 2.0 + i * 1.7)
		pouch.draw_circle(p, 5.5, Color(dots[i], .16 * tw))
		pouch.draw_circle(p, 2.6, Color((dots[i] as Color).lerp(Color.WHITE, .3), .95 * tw))
	if total > 9:
		var fs := 12
		var txt := str(total)
		var w := thin_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		pouch.draw_string(thin_font, c + Vector2(22.0 - w * .5, -12.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, .95, .85, .9))
	if _cap_a > .02:
		_caption(pouch, Vector2(s.x * .5, s.y - 2.0), "táska", _cap_a)


## A „…” fény: halvány kör három ponttal (nyitva: fényesebb).
func _draw_menu_dot() -> void:
	var c := menu_dot.size * .5
	var on := menu.visible
	menu_dot.draw_circle(c, 16.0, Color(.12, .08, .26, .22 if not on else .4))
	menu_dot.draw_arc(c, 16.0, 0.0, TAU, 40, Color(1, 1, 1, .22 if not on else .5), 1.0, true)
	for k in 3:
		menu_dot.draw_circle(c + Vector2((k - 1) * 6.5, 0), 1.9, Color(1, 1, 1, .62 if not on else .95))
