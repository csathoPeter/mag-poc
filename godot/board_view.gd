class_name BoardView
extends Control
## A DNS-tábla felülete: félig átlátszó, fénylő rács, ami a világ fölött lebeg (nem szürke menü).
## Álló telefonra méretezve; koppintásra a mező vált: üres → A=T → G≡C → üres.
## Minden sor mellett a gén neve, és ha a sor kész, a változat neve (Genes.allele_name).
## A logika a DnaBoard-ban van; ezt a felületet a keresztezés (M5) is használja: open() parents-szel a sorok mellé
## 1 / 2 / M jelet tesz (melyik szülőtől jött a gén, vagy mutáció).

## Kész, szabályos tábla: a DNS (hat sorszám). A hívó teszi a magot a táskába.
signal finished(dna: Array)
## A játékos bezárta (a félkész állapot a changed jelzéssel már mentődött).
signal closed
## Minden koppintás után: a rács (mentéshez).
signal changed(grid: Array)

const C_AT := Color(.52, .96, .82)
const C_GC := Color(1.0, .70, .56)
const C_FREE := Color(1.0, .86, .48)
const C_BAD := Color(1.0, .46, .52)
const C_TEXT := Color(.95, .93, 1.0)
const C_DIM := Color(.80, .76, .95, .62)

var puzzle: Dictionary = {}
var grid: Array = []
## M5: a két szülő DNS-e (üres = nincs jelölés).
var parents: Array = []
var cell := 40.0
var gap := 4.0
var label_w := 88.0
var finishing := false

var _t := 0.0
var _pop := {}
var _done_t := -1.0
var _reset_armed := 0
## Ehhez a képernyőmérethez készült az elrendezés (weben induláskor és forgatáskor változik).
var _laid_for := Vector2.ZERO
var _sb := StyleBoxFlat.new()
var _panel := PanelContainer.new()
var _title := Label.new()
var _sub := Label.new()
var _grid := Control.new()
var _legend := Control.new()
var _progress := Label.new()
var _choices := Label.new()
var _rules := Label.new()
var _hint_b: Button
var _reset_b: Button
var _close_b: Button
## Elhalványulás a kész tábla után: a mezők helyén már a kettős spirál golyói vannak (seed_fx.gd), a fátyol is ott folytatódik.
var _fading := false
var _fade_tw: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_panel.add_theme_stylebox_override("panel", panel_style())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	_panel.add_child(col)
	_style_label(_title, 21, C_TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_style_label(_sub, 12, C_DIM)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_sub)
	_grid.draw.connect(_draw_grid)
	_grid.gui_input.connect(_grid_input)
	_grid.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_child(_grid)
	_legend.custom_minimum_size = Vector2(0, 30)
	_legend.draw.connect(_draw_legend)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_legend)
	_style_label(_progress, 13, C_TEXT)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_progress)
	_style_label(_choices, 12, C_FREE)
	_choices.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_choices)
	_style_label(_rules, 11, C_DIM)
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules.text = "Soronként és oszloponként 3-3 legyen mindkét bázispárból, és három egyforma nem állhat egymás mellett. Koppintásra a mező vált: üres, kettős (AT), hármas (GC), majd újra üres. Nincs hiba, csak próbálkozás."
	col.add_child(_rules)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_hint_b = make_button(row, "Súgás", _on_hint)
	_reset_b = make_button(row, "Újra", _on_reset)
	_close_b = make_button(row, "Bezár", _on_close)


## Megnyitás egy feladvánnyal (DnaBoard.make_puzzle / daily). saved: félkész rács a mentésből (üres = a kiinduló állapot).
func open(p: Dictionary, title: String, subtitle: String, saved: Array = [], parent_dnas: Array = []) -> void:
	puzzle = p
	parents = parent_dnas
	grid = DnaBoard.copy_grid(saved) if saved.size() == DnaBoard.N else DnaBoard.copy_grid(p.clue)
	# a feladvány mezői mindig a helyükön (ha a mentés régebbi lenne)
	for y in DnaBoard.N:
		for x in DnaBoard.N:
			if int(p.clue[y][x]) != DnaBoard.EMPTY:
				grid[y][x] = p.clue[y][x]
	_title.text = title
	_sub.text = subtitle
	finishing = false
	_done_t = -1.0
	_pop.clear()
	_stop_fade()
	_layout()
	_update_texts()
	visible = true
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate:a", 1.0, .35)


func close() -> void:
	_stop_fade()
	visible = false


## A kész tábla elhalványul: a mezők azonnal eltűnnek (a spirál golyói veszik át a helyüket), a feliratok lassan.
func fade_out(dur := .6) -> void:
	_stop_fade()
	_fading = true
	_fade_tw = create_tween()
	_fade_tw.tween_property(self, "modulate:a", 0.0, dur)
	_fade_tw.tween_callback(func() -> void:
		_fading = false
		visible = false)


func _stop_fade() -> void:
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = null
	_fading = false


## Hány mező volt üres a kiindulásnál (a játékos ennyit tölt ki).
func total_empty() -> int:
	return DnaBoard.empty_count(puzzle.clue)


## Egy mező közepe képernyő-koordinátában (teszteléshez: szimulált koppintás).
func cell_center(x: int, y: int) -> Vector2:
	return _grid.get_global_rect().position + Vector2(x * (cell + gap) + cell * .5, y * (cell + gap) + cell * .5)


## Tesztelés (--shot): a nem szabad sorok üres mezőinek egy részét a céllal tölti ki; bad: egy szabálysértő mezőt is tesz.
func fill_for_shot(frac: float, bad: bool) -> void:
	var target := DnaBoard.grid_from_dna(puzzle.target)
	var empties: Array = []
	for y in DnaBoard.N:
		for x in DnaBoard.N:
			if int(grid[y][x]) == DnaBoard.EMPTY and not (puzzle.free as Array).has(y):
				empties.append(Vector2i(x, y))
	var n := roundi(empties.size() * frac)
	for i in n:
		var p: Vector2i = empties[i]
		grid[p.y][p.x] = target[p.y][p.x]
	if bad:
		for i in range(n, empties.size()):
			var p: Vector2i = empties[i]
			grid[p.y][p.x] = 1 - int(target[p.y][p.x])
			if not DnaBoard.bad_cells(grid).is_empty():
				break
			grid[p.y][p.x] = DnaBoard.EMPTY
	_update_texts()
	changed.emit(grid)


func _layout() -> void:
	var vp := get_viewport_rect().size
	_laid_for = vp
	var avail := minf(vp.x, 480.0) - 8.0 - 20.0
	label_w = clampf(avail * .245, 80.0, 130.0)
	gap = 4.0
	cell = clampf(floorf((avail - label_w - 10.0 - 5.0 * gap) / 6.0), 34.0, 60.0)
	var gw := 6.0 * cell + 5.0 * gap
	_grid.custom_minimum_size = Vector2(gw + 10.0 + label_w, gw)
	_choices.custom_minimum_size = Vector2(gw + 10.0 + label_w, 0)
	_rules.custom_minimum_size = Vector2(gw + 10.0 + label_w, 0)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if get_viewport_rect().size != _laid_for:
		_layout()
	# lebegés: a tábla lassan, alig észrevehetően emelkedik és süllyed
	_panel.reset_size()
	_panel.position = ((get_viewport_rect().size - _panel.size) * .5).floor() + Vector2(0, sin(_t * .9) * 3.0)
	_grid.queue_redraw()
	queue_redraw()
	if _done_t >= 0.0:
		_done_t += delta
		if _done_t > 1.1 and finishing:
			finishing = false
			finished.emit(DnaBoard.dna_from_grid(grid))


func _draw() -> void:
	if _fading:
		return
	# a világ elsötétül és ködbe borul a tábla mögött, de átlátszik
	draw_rect(get_viewport_rect(), Color(.04, .02, .10, .42))
	var c := _panel.position + _panel.size * .5
	for i in 5:
		var r := maxf(_panel.size.x, _panel.size.y) * (.42 + i * .1)
		draw_circle(c, r, Color(.55, .45, 1.0, .028))


func _draw_grid() -> void:
	var font := get_theme_default_font()
	var bad := DnaBoard.bad_cells(grid)
	var free: Array = puzzle.free
	var gw := 6.0 * cell + 5.0 * gap
	for y in DnaBoard.N:
		var y0 := y * (cell + gap)
		if _fading:
			_draw_label(font, Vector2(gw + 10.0, y0), y)
			continue
		if free.has(y):
			# szabad gén: meleg, arany sáv a sor mögött
			_sb.bg_color = Color(C_FREE, .10 + .03 * sin(_t * 1.6))
			_sb.border_color = Color(C_FREE, .0)
			_sb.set_border_width_all(0)
			_sb.set_corner_radius_all(int(cell * .3))
			_sb.shadow_size = 0
			_grid.draw_style_box(_sb, Rect2(-3, y0 - 2, gw + 6, cell + 4))
		for x in DnaBoard.N:
			_draw_cell(Vector2(x * (cell + gap), y0), x, y, bad.has(Vector2i(x, y)), free.has(y))
		_draw_label(font, Vector2(gw + 10.0, y0), y)


func _draw_cell(pos: Vector2, x: int, y: int, is_bad: bool, is_free: bool) -> void:
	var v: int = grid[y][x]
	var fixed := int(puzzle.clue[y][x]) != DnaBoard.EMPTY
	var r := Rect2(pos, Vector2(cell, cell))
	# koppintáskor rugalmasan megugrik
	var k := Vector2i(x, y)
	var s := 1.0
	if _pop.has(k):
		var dt: float = _t - float(_pop[k])
		s = 1.0 + .16 * exp(-dt * 9.0) * cos(dt * 18.0)
	# kész táblán fényhullám fut végig átlósan
	var wave := 0.0
	if _done_t >= 0.0:
		wave = clampf(1.0 - absf(_done_t * 9.0 - float(x + y)) / 2.5, 0.0, 1.0)
		s += wave * .08
	r = r.grow((s - 1.0) * cell * .5)
	var col: Color = C_AT if v == 0 else C_GC if v == 1 else Color(1, 1, 1)
	_sb.set_corner_radius_all(int(cell * .28))
	_sb.shadow_offset = Vector2.ZERO
	if v == DnaBoard.EMPTY:
		_sb.bg_color = Color(1, 1, 1, .05)
		_sb.border_color = Color(C_FREE, .5) if is_free else Color(1, 1, 1, .2)
		_sb.set_border_width_all(1)
		_sb.shadow_size = 0
	elif fixed:
		_sb.bg_color = Color(col, .17)
		_sb.border_color = Color(col, .22)
		_sb.set_border_width_all(1)
		_sb.shadow_size = 0
	else:
		_sb.bg_color = Color(col, .30 + wave * .4)
		_sb.border_color = Color(col, .9)
		_sb.set_border_width_all(2)
		_sb.shadow_color = Color(col, .30 + wave * .4)
		_sb.shadow_size = int(5 + wave * 8)
	if is_bad:
		# finom jelzés: lassan lüktető korall keret, semmi villogás vagy büntetés
		var pulse := .55 + .3 * sin(_t * 3.0)
		_sb.border_color = Color(C_BAD, pulse)
		_sb.set_border_width_all(2)
		_sb.shadow_color = Color(C_BAD, .25)
		_sb.shadow_size = 5
	_grid.draw_style_box(_sb, r)
	if v != DnaBoard.EMPTY:
		draw_pair(_grid, get_theme_default_font(), r.get_center(), r.size.x, v, Color(col.lerp(Color.WHITE, .55), .62 if fixed else 1.0))


## Egy bázispár rajza: két betű, köztük 2 (A=T) vagy 3 (G≡C) kötés. Saját rajz, mert a webes betűkészletben nincs ≡.
static func draw_pair(ci: CanvasItem, font: Font, c: Vector2, w: float, v: int, col: Color) -> void:
	var fs := int(w * .34)
	var a := "A" if v == 0 else "G"
	var b := "T" if v == 0 else "C"
	var off := w * .24
	var asc := font.get_ascent(fs) * .72
	ci.draw_string(font, Vector2(c.x - off - w * .2, c.y + asc * .5), a, HORIZONTAL_ALIGNMENT_CENTER, w * .4, fs, col)
	ci.draw_string(font, Vector2(c.x + off - w * .2, c.y + asc * .5), b, HORIZONTAL_ALIGNMENT_CENTER, w * .4, fs, col)
	var n := 2 if v == 0 else 3
	var bl := w * .14
	var sp := maxf(2.5, w * .07)
	for i in n:
		var yy := c.y + (i - (n - 1) * .5) * sp
		ci.draw_line(Vector2(c.x - bl * .5, yy), Vector2(c.x + bl * .5, yy), col, maxf(1.0, w * .035), true)


func _draw_label(font: Font, pos: Vector2, y: int) -> void:
	var row: Array = grid[y]
	var complete := not row.has(DnaBoard.EMPTY)
	var k := DnaBoard.row_index(row) if complete else -1
	var is_free := (puzzle.free as Array).has(y)
	var head: String = Genes.GENE_NAMES[y]
	if k >= 0 and not parents.is_empty():
		head += "  " + ("1" if k == int(parents[0][y]) else "2" if k == int(parents[1][y]) else "M")
	_grid.draw_string(font, pos + Vector2(0, 12), head, HORIZONTAL_ALIGNMENT_LEFT, label_w, 10, C_FREE if is_free else C_DIM)
	var text := ""
	var col := C_TEXT
	var x := pos.x
	if k >= 0:
		text = Genes.allele_name(y, k)
		var sw := Genes.allele_color(y, k)
		if sw.a > 0.0:
			_grid.draw_circle(Vector2(x + 5, pos.y + 25), 5.0, sw)
			_grid.draw_arc(Vector2(x + 5, pos.y + 25), 6.0, 0, TAU, 20, Color(1, 1, 1, .5), 1.0, true)
			x += 14
	elif is_free:
		text = "te döntesz"
		col = C_FREE
	else:
		text = "…"
		col = C_DIM
	_grid.draw_multiline_string(font, Vector2(x, pos.y + 29), text, HORIZONTAL_ALIGNMENT_LEFT, label_w - (x - pos.x), 12, 2, col)


func _draw_legend() -> void:
	var font := get_theme_default_font()
	var w := 26.0
	var x := (_legend.size.x - 300.0) * .5
	for v in 2:
		var col: Color = C_AT if v == 0 else C_GC
		var r := Rect2(Vector2(x, 2), Vector2(w, w))
		_sb.bg_color = Color(col, .3)
		_sb.border_color = Color(col, .9)
		_sb.set_border_width_all(1)
		_sb.set_corner_radius_all(7)
		_sb.shadow_size = 0
		_legend.draw_style_box(_sb, r)
		draw_pair(_legend, font, r.get_center(), w, v, col.lerp(Color.WHITE, .55))
		_legend.draw_string(font, Vector2(x + w + 6, 20), "AT: kettős kötés" if v == 0 else "GC: hármas kötés", HORIZONTAL_ALIGNMENT_LEFT, 120, 11, C_DIM)
		x += 156


func _grid_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if finishing:
		return
	var p: Vector2 = event.position
	# a hézag is a legközelebbi mezőhöz tartozik, így a koppintási felület nagyobb a rajzolt mezőnél
	var x := floori((p.x + gap * .5) / (cell + gap))
	var y := floori((p.y + gap * .5) / (cell + gap))
	if x < 0 or x >= DnaBoard.N or y < 0 or y >= DnaBoard.N:
		return
	_grid.accept_event()
	if int(puzzle.clue[y][x]) != DnaBoard.EMPTY:
		return
	var v: int = grid[y][x]
	grid[y][x] = 0 if v == DnaBoard.EMPTY else 1 if v == 0 else DnaBoard.EMPTY
	_pop[Vector2i(x, y)] = _t
	_after_change()


func _after_change() -> void:
	_update_texts()
	changed.emit(grid)
	if DnaBoard.empty_count(grid) == 0 and DnaBoard.bad_cells(grid).is_empty() and not DnaBoard.dna_from_grid(grid).is_empty():
		finishing = true
		_done_t = 0.0
		var dna := DnaBoard.dna_from_grid(grid)
		_progress.text = "Kész! %s" % Genes.latin_name(dna)


func _update_texts() -> void:
	var total := total_empty()
	var filled := total - DnaBoard.empty_count(grid)
	_progress.text = "%d / %d bázispár" % [filled, total]
	var parts: Array = []
	for y in puzzle.free:
		var ch := DnaBoard.row_choices(puzzle, y)
		var names: Array = []
		for k in ch:
			names.append(Genes.allele_name(y, k))
		var shown := names.slice(0, 4)
		var txt := ", ".join(shown.slice(0, shown.size() - 1)) + " vagy " + str(shown[shown.size() - 1]) if shown.size() > 1 else str(shown[0])
		if names.size() > 4:
			txt = ", ".join(shown) + " (és még %d)" % (names.size() - 4)
		parts.append("%s: %s" % [Genes.GENE_NAMES[y], txt])
	_choices.text = ("Az arany sorokban te döntesz. " + " · ".join(parts)) if not parts.is_empty() else ""
	_reset_b.text = "Újra"


func _on_hint() -> void:
	if finishing:
		return
	var p := DnaBoard.hint(puzzle, grid)
	if p.x < 0:
		_progress.text = "A lezárt génekkel kész vagy: az arany sorokban te döntesz."
		return
	grid[p.y][p.x] = DnaBoard.grid_from_dna(puzzle.target)[p.y][p.x]
	_pop[p] = _t
	_after_change()


## Újrakezdés két koppintással (az első csak élesít), hogy véletlenül ne vesszen el a munka.
func _on_reset() -> void:
	if finishing:
		return
	var now := Time.get_ticks_msec()
	if _reset_armed == 0 or now - _reset_armed > 3000:
		_reset_armed = now
		_reset_b.text = "Biztos?"
		return
	_reset_armed = 0
	grid = DnaBoard.copy_grid(puzzle.clue)
	_after_change()


func _on_close() -> void:
	if finishing:
		return
	close()
	closed.emit()


# ---------------------------------------------------------------- Közös stílus (a magos táska is ezt használja)

static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(.10, .07, .22, .62)
	sb.border_color = Color(.80, .74, 1.0, .38)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(24)
	sb.shadow_color = Color(.62, .50, 1.0, .22)
	sb.shadow_size = 26
	sb.set_content_margin_all(12)
	sb.content_margin_top = 14
	return sb


static func make_button(parent: Control, text: String, cb: Callable, accent := Color(.85, .8, 1.0)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 15)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(accent, .10 if st != "pressed" else .26)
		sb.border_color = Color(accent, .45 if st != "focus" else .0)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(16)
		sb.set_content_margin_all(8)
		if st == "focus":
			sb.bg_color = Color(0, 0, 0, 0)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(accent.lerp(Color.WHITE, .5)))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


static func _style_label(l: Label, fs: int, col: Color) -> void:
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(.3, .2, .6, .5))
