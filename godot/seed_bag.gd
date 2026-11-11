class_name SeedBag
extends Control
## A magos táska: a táskában lévő magok (név, főbb tulajdonságok, eredet, nap) és a még megfejtetlen napi magok
## (a mai és az elmúlt 7 nap kihagyottjai; koppintásra a táblájuk nyílik). Lebegő, fénylő panel, mint a DNS-tábla.
## „Elvetem”: a táska bezárul, a mag fénypontként a bolygóra hull (seed_fx.gd), másnap kikel (hatching.gd).
## „Keresztezem” (M5, gyűjtött és keresztezett magon): a táska párválasztó módba vált – a többi magon „Ezzel”,
## a választotton „Mégse”; két koppintással indul a keresztezés (crossing.gd). Ha a keresztezett tábla kész, de
## a három csíra közül még nem választottál, legfelül „Három csíra vár” kártya.

signal sow(seed_id: int)
signal solve(day: int)
signal closed
## Keresztezés: a (1. szülő) és b (2. szülő) magja.
signal cross(a_id: int, b_id: int)
## A választásra váró csírák megnyitása.
signal sprouts
## Megosztás (M10): egy mag (kép + mag-kód), a kész napi tábla (szöveg + rács), és a barát kódjának beírása.
signal share(seed_id: int)
signal share_daily(day: int)
signal enter_code

const ORIGIN_NAMES := {"napi": "A nap magja", "gyujtes": "Gyűjtött mag", "keresztezes": "Keresztezett mag", "csillag": "Csillagról hozott mag", "barat": "Barát magja"}
## A táska szakaszai ebben a sorrendben (ha egynél több fajta mag van, fejléccel elválasztva).
const SECTIONS := [["napi", "A nap magjai"], ["gyujtes", "Gyűjtött magok – a virágzó fáidról"], ["keresztezes", "Keresztezett magok"], ["csillag", "Csillagról hozott magok"], ["barat", "Barátoktól kapott magok"]]
## A gyűjtött mag színe a táskában (kerti zöld), hogy jól elváljon a nap magjától (menta) és a megfejtetlentől (arany).
const C_GATHERED := Color(.80, .95, .52)
## A keresztezett mag színe (levendula, mint a mutáció jele a táblán).
const C_CROSSED := Color(.86, .66, 1.0)

var _panel := PanelContainer.new()
var _title := Label.new()
var _msg := Label.new()
var _scroll := ScrollContainer.new()
var _list := VBoxContainer.new()
var _t := 0.0
var _laid_for := Vector2.ZERO
var _args: Array = []
## Párválasztó mód: ennek a magnak keresünk párt (-1 = nincs).
var pick_a := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_panel.add_theme_stylebox_override("panel", BoardView.panel_style())
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	BoardView._style_label(_title, 21, BoardView.C_TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text = "Magos táska"
	col.add_child(_title)
	BoardView._style_label(_msg, 13, BoardView.C_FREE)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_msg)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# húzással görgethető, de görgetősáv nélkül: a megjelenő-eltűnő sáv minden képkockában átrendezte (rángatta) a panelt
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.scroll_deadzone = 8
	col.add_child(_scroll)
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	# barát magja kóddal (M10): weben a böngésző kérdezi meg (prompt), natívan saját mező
	BoardView.make_button(row, "Kód beírása", func() -> void: enter_code.emit(), Share.C_FRIEND)
	BoardView.make_button(row, "Bezár", func() -> void:
		visible = false
		pick_a = -1
		closed.emit())


## A táska megnyitása (újraépíti a listát). highlight: az épp most bekerült mag azonosítója; msg: felső üzenet.
func open(game: GameState, highlight := -1, msg := "", fade := true) -> void:
	_args = [game, highlight, msg]
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var vp := get_viewport_rect().size
	_laid_for = vp
	var w := minf(vp.x - 16.0, 440.0) - 24.0
	var count := 0
	if not game.data.is_empty():
		if pick_a >= 0 and game.find_seed(pick_a).is_empty():
			pick_a = -1
		var picking := pick_a >= 0
		var today := GameState.today()
		var pend := game.pending_sprouts()
		var seeds: Array = (game.data.bag as Array).duplicate()
		seeds.reverse()
		if picking:
			var a := game.find_seed(pick_a)
			msg = ("Kivel keresztezed? A párja mellett koppints: „Ezzel”. (%s)" % GameState.seed_name(a)) if seeds.size() > 1 \
				else "A keresztezéshez kell még egy mag: gyűjts egy virágzó fáról, vagy fejtsd meg a nap magját."
		if not pend.is_empty() and not picking:
			var names: Array = pend.names
			_card(w, {"sprouts": pend.sprouts}, "Három csíra vár", "%s × %s\nVálassz közülük: egy mag lesz, kettő csillag." % [names[0], names[1]],
				[["Választok", func() -> void: sprouts.emit(), BoardView.C_FREE]], highlight == -2, BoardView.C_FREE)
			count += 1
		if not picking and game.daily_done(today):
			# a mai tábla kész: Wordle-szerűen megosztható (dátum, fajnév, spoiler nélküli rács, a választásod)
			var dd := game.daily_dna(today)
			if not dd.is_empty():
				_card(w, {"dna": dd, "origin": "napi"}, "A mai tábla kész", "%s · %s\nOszd meg a rácsodat (a megoldás nem látszik)." % [GameState.day_label(today), Genes.latin_name(dd)],
					[["Megosztom", func() -> void: share_daily.emit(today), BoardView.C_FREE]], false, BoardView.C_FREE)
				count += 1
		if not picking:
			for day in game.daily_open_days():
				var when := "ma" if day == today else "tegnap" if day == today - 1 else "%d napja" % (today - day)
				_card(w, {}, "A mai mag vár" if day == today else "Megfejtetlen napi mag",
					"%s · %s\nA DNS-táblája még kitöltésre vár." % [GameState.day_label(day), when],
					[["Megfejtem", func() -> void: solve.emit(day), BoardView.C_FREE]], false, BoardView.C_FREE)
				count += 1
		# szakaszonként (a nap magjai, gyűjtött magok, …), mindegyikben a legújabb elöl
		var groups: Array = []
		for sec in SECTIONS:
			groups.append([sec[1], seeds.filter(func(x: Dictionary) -> bool: return str(x.origin) == sec[0])])
		var known: Array = SECTIONS.map(func(sec: Array) -> String: return sec[0])
		groups.append(["Más magok", seeds.filter(func(x: Dictionary) -> bool: return not known.has(str(x.origin)))])
		var filled := groups.filter(func(gr: Array) -> bool: return not (gr[1] as Array).is_empty()).size()
		for gr in groups:
			if (gr[1] as Array).is_empty():
				continue
			if filled > 1 or count > 0:
				_header(w, gr[0])
			for sd in gr[1]:
				_seed_card(w, sd, highlight, picking, pend.is_empty())
				count += 1
	_msg.text = msg
	_msg.visible = msg != ""
	_msg.custom_minimum_size = Vector2(w, 0)
	if count == 0:
		var l := Label.new()
		BoardView._style_label(l, 13, BoardView.C_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w, 0)
		l.text = "A táska üres. Holnap új napi mag vár, és virágzó fákról is gyűjthetsz: szállj le egy fához, és koppints egy virágára."
		_list.add_child(l)
	_scroll.custom_minimum_size = Vector2(w, 90.0)
	visible = true
	if fade:
		modulate = Color(1, 1, 1, 0)
		create_tween().tween_property(self, "modulate:a", 1.0, .3)


## Egy mag kártyája. Párválasztáskor: a választott magon „Mégse”, a többin „Ezzel”; máskor „Elvetem”, és a gyűjtött
## és keresztezett magon „Keresztezem” is (ha nem vár választásra korábbi keresztezés csírája).
func _seed_card(w: float, sd: Dictionary, highlight: int, picking: bool, can_cross: bool) -> void:
	var dna: Array = sd.dna
	var sid := int(sd.id)
	var origin := str(sd.origin)
	var accent: Color = C_GATHERED if origin == "gyujtes" else C_CROSSED if origin == "keresztezes" else Herbarium.C_STAR if origin == "csillag" \
		else Share.C_FRIEND if origin == "barat" else BoardView.C_AT
	var title := GameState.seed_name(sd)
	var body := ""
	if origin == "gyujtes":
		body = "%s\nSaját fádról szedted · %s" % [Genes.traits_text(dna), GameState.day_label(int(sd.day))]
	elif origin == "keresztezes" and (sd.parents as Array).size() == 2:
		body = "%s\nKeresztezés: %s × %s · %s" % [Genes.traits_text(dna), Genes.latin_name(sd.parents[0]), Genes.latin_name(sd.parents[1]), GameState.day_label(int(sd.day))]
	elif origin == "csillag":
		var so := str(sd.get("star_origin", ""))
		var was := "el nem választott csíra volt" if so == "csira" else ("teszt-csillag volt" if so == "teszt" or so == "" else "elengedett fa volt")
		body = "%s\nCsillagról hozott mag (%s) · %s" % [Genes.traits_text(dna), was, GameState.day_label(int(sd.day))]
	elif origin == "barat":
		var from := str(sd.get("from", ""))
		var sday := int(sd.get("share_day", -1))
		var src := ("%s napi magja" % GameState.day_label(sday)) if sday >= 0 else (from if from != "" else "Barát magja")
		body = "%s\n%s · kód %s · %s" % [Genes.traits_text(dna), src, str(sd.get("share", "")), GameState.day_label(int(sd.day))]
	else:
		body = "%s\n%s · %s" % [Genes.traits_text(dna), ORIGIN_NAMES.get(origin, "Mag"), GameState.day_label(int(sd.day))]
	var actions: Array = []
	var hl := sid == highlight
	if picking:
		if sid == pick_a:
			actions.append(["Mégse", func() -> void: _pick(-1), BoardView.C_DIM])
			hl = true
		else:
			actions.append(["Ezzel", func() -> void: _partner(sid), BoardView.C_FREE])
	else:
		actions.append(["Elvetem", func() -> void: sow.emit(sid), accent])
		if can_cross and (origin == "gyujtes" or origin == "keresztezes"):
			actions.append(["Keresztezem", func() -> void: _pick(sid), BoardView.C_FREE])
		actions.append(["Megosztom", func() -> void: share.emit(sid), BoardView.C_DIM])
	_card(w, sd, title, body, actions, hl, accent)
	# a kártyán a mag azonosítója (a végigjátszás, playtest.gd így találja meg a gombjait)
	_list.get_child(_list.get_child_count() - 1).set_meta("seed_id", sid)


func _partner(sid: int) -> void:
	var a := pick_a
	pick_a = -1
	cross.emit(a, sid)


## Párválasztó mód be (a mag azonosítója) vagy ki (-1); a lista helyben újraépül.
func _pick(id: int) -> void:
	pick_a = id
	if not _args.is_empty():
		open(_args[0], -1, "", false)


func _header(w: float, text: String) -> void:
	var l := Label.new()
	BoardView._style_label(l, 12, BoardView.C_DIM)
	l.text = text
	l.custom_minimum_size = Vector2(w, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(l)


## actions: [[felirat, Callable, szín], …] – egymás alatt a kártya jobb oldalán.
func _card(w: float, seed: Dictionary, title: String, body: String, actions: Array, hl: bool, accent: Color) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, .07 if not hl else .14)
	sb.border_color = Color(accent, .55 if hl else .22)
	sb.set_border_width_all(2 if hl else 1)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(10)
	if hl:
		sb.shadow_color = Color(accent, .3)
		sb.shadow_size = 10
	card.add_theme_stylebox_override("panel", sb)
	# a kártyán húzva görgethető a lista (csak a gomb fogja meg az érintést)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.custom_minimum_size = Vector2(w - 4.0, 0)
	_list.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(row)
	var sw := Control.new()
	sw.custom_minimum_size = Vector2(38, 38)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.draw.connect(func() -> void: _draw_swatch(sw, seed, accent))
	row.add_child(sw)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var tl := Label.new()
	BoardView._style_label(tl, 15, BoardView.C_TEXT)
	tl.text = title
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tl)
	var bl := Label.new()
	BoardView._style_label(bl, 11, BoardView.C_DIM)
	bl.text = body
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(bl)
	var bc := VBoxContainer.new()
	bc.add_theme_constant_override("separation", 6)
	bc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bc.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(bc)
	for ac in actions:
		var b := BoardView.make_button(bc, ac[0], ac[1], ac[2])
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.custom_minimum_size = Vector2(104, 44 if actions.size() == 1 else 40)
		if actions.size() > 1:
			b.add_theme_font_size_override("font_size", 14)


## A mag kis képe: a virág színe középen, körülötte a lomb és a kéreg színe; a megfejtetlen magnál egy halvány rács.
func _draw_swatch(c: Control, seed: Dictionary, accent: Color) -> void:
	var m := c.size * .5
	if seed.is_empty():
		var w := 5.0
		for y in 3:
			for x in 3:
				c.draw_rect(Rect2(m + Vector2((x - 1.5) * (w + 3), (y - 1.5) * (w + 3)), Vector2(w, w)), Color(accent, .3 + .2 * float((x + y) % 2)))
		return
	if seed.has("sprouts"):
		# választásra váró csírák: három kis virágszín-korong
		var sp: Array = seed.sprouts
		for i in sp.size():
			var p := m + Vector2((i - 1) * 11.0, 5.0 - (6.0 if i == 1 else 0.0))
			c.draw_circle(p, 7.5, Color(Genes.allele_color(5, sp[i].dna[5]), .9))
			c.draw_circle(p, 4.5, Genes.allele_color(0, sp[i].dna[0]))
		return
	var dna: Array = seed.dna
	c.draw_circle(m, 18.0, Color(Genes.allele_color(4, dna[4]), .9))
	c.draw_circle(m, 14.0, Genes.allele_color(5, dna[5]))
	c.draw_circle(m, 8.0, Genes.allele_color(0, dna[0]))
	c.draw_arc(m, 18.5, 0, TAU, 32, Color(1, 1, 1, .45), 1.0, true)
	if str(seed.get("origin", "")) == "gyujtes":
		# gyűjtött mag: kis arany magszem a sarokban
		var sp := m + Vector2(12.5, 12.5)
		c.draw_circle(sp, 6.0, Color(.1, .06, .2, .55))
		c.draw_circle(sp, 4.2, SeedFx.C_SEED)
		c.draw_circle(sp + Vector2(-1.2, -1.4), 1.5, Color(1, 1, 1, .7))


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# más képernyőméret (weben induláskor, forgatáskor): újraépítjük a szélességhez
	if get_viewport_rect().size != _laid_for and not _args.is_empty():
		open(_args[0], _args[1], _args[2], false)
	# a lista magasságához igazítva, legfeljebb a képernyő 58%-a (utána görgethető)
	var want := minf(get_viewport_rect().size.y * .58, maxf(60.0, _list.get_combined_minimum_size().y))
	if absf(_scroll.custom_minimum_size.y - want) > .5:
		_scroll.custom_minimum_size.y = want
	_panel.reset_size()
	_panel.position = ((get_viewport_rect().size - _panel.size) * .5).floor() + Vector2(0, sin(_t * .9) * 3.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(get_viewport_rect(), Color(.04, .02, .10, .42))
