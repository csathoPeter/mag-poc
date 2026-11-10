class_name SeedBag
extends Control
## A magos táska: a táskában lévő magok (név, főbb tulajdonságok, eredet, nap) és a még megfejtetlen napi magok
## (a mai és az elmúlt 7 nap kihagyottjai; koppintásra a táblájuk nyílik). Lebegő, fénylő panel, mint a DNS-tábla.
## Az elvetés itt egyelőre egy gomb (M3-ban jön a spirál és a másnapi kikelés látványa).

signal sow(seed_id: int)
signal solve(day: int)
signal closed

const ORIGIN_NAMES := {"napi": "A nap magja", "gyujtes": "Gyűjtött mag", "keresztezes": "Keresztezett mag", "csillag": "Csillagról hozott mag"}

var _panel := PanelContainer.new()
var _title := Label.new()
var _msg := Label.new()
var _scroll := ScrollContainer.new()
var _list := VBoxContainer.new()
var _t := 0.0
var _laid_for := Vector2.ZERO
var _args: Array = []


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
	_scroll.scroll_deadzone = 8
	col.add_child(_scroll)
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list)
	var row := HBoxContainer.new()
	col.add_child(row)
	BoardView.make_button(row, "Bezár", func() -> void:
		visible = false
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
	_msg.text = msg
	_msg.visible = msg != ""
	_msg.custom_minimum_size = Vector2(w, 0)
	var count := 0
	if not game.data.is_empty():
		var today := GameState.today()
		for day in game.daily_open_days():
			var when := "ma" if day == today else "tegnap" if day == today - 1 else "%d napja" % (today - day)
			_card(w, {}, "A mai mag vár" if day == today else "Megfejtetlen napi mag",
				"%s · %s\nA DNS-táblája még kitöltésre vár." % [GameState.day_label(day), when],
				"Megfejtem", func() -> void: solve.emit(day), false, BoardView.C_FREE)
			count += 1
		var seeds: Array = (game.data.bag as Array).duplicate()
		seeds.reverse()
		for s in seeds:
			var dna: Array = s.dna
			var origin: String = ORIGIN_NAMES.get(str(s.origin), "Mag")
			var sid := int(s.id)
			_card(w, s, Genes.latin_name(dna), "%s\n%s · %s" % [Genes.traits_text(dna), origin, GameState.day_label(int(s.day))],
				"Elvetem", func() -> void: sow.emit(sid), sid == highlight, BoardView.C_AT)
			count += 1
	if count == 0:
		var l := Label.new()
		BoardView._style_label(l, 13, BoardView.C_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w, 0)
		l.text = "A táska üres. Holnap új napi mag vár, és virágzó fákról is gyűjthetsz majd."
		_list.add_child(l)
	_scroll.custom_minimum_size = Vector2(w, 90.0)
	visible = true
	if fade:
		modulate = Color(1, 1, 1, 0)
		create_tween().tween_property(self, "modulate:a", 1.0, .3)


func _card(w: float, seed: Dictionary, title: String, body: String, action: String, cb: Callable, hl: bool, accent: Color) -> void:
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
	var b := BoardView.make_button(row, action, cb, accent)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(96, 44)


## A mag kis képe: a virág színe középen, körülötte a lomb és a kéreg színe; a megfejtetlen magnál egy halvány rács.
func _draw_swatch(c: Control, seed: Dictionary, accent: Color) -> void:
	var m := c.size * .5
	if seed.is_empty():
		var w := 5.0
		for y in 3:
			for x in 3:
				c.draw_rect(Rect2(m + Vector2((x - 1.5) * (w + 3), (y - 1.5) * (w + 3)), Vector2(w, w)), Color(accent, .3 + .2 * float((x + y) % 2)))
		return
	var dna: Array = seed.dna
	c.draw_circle(m, 18.0, Color(Genes.allele_color(4, dna[4]), .9))
	c.draw_circle(m, 14.0, Genes.allele_color(5, dna[5]))
	c.draw_circle(m, 8.0, Genes.allele_color(0, dna[0]))
	c.draw_arc(m, 18.5, 0, TAU, 32, Color(1, 1, 1, .45), 1.0, true)


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
