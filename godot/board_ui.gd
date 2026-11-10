class_name BoardUI
extends Control
## A DNS kirakása: 6×6-os tábla, soronként egy gén. Koppintásra üres → A=T → G≡C → üres.
## Ha a tábla kész és szabályos, jelez (finished), a jelenet ebből csavarja a kettős spirált.

signal finished(dna: Array, grid: Array, board_rect: Rect2)
signal cancelled

const INK := Color("#f6efe0")
const INK_SOFT := Color(0.965, 0.937, 0.878, .74)
const LINE := Color(0.965, 0.937, 0.878, .34)
const NIGHT := Color("#141a26")
const SEED := Color("#f3d48a")
const AT := Color("#f0b35a")
const GC := Color("#55c6c0")
const WARN := Color("#ff8a75")
const LABEL := ["A=T", "G≡C"]
const GENE_W := 96.0

var clue: Array = []
var grid: Array = []
var target: Array = []
var free: Array = []
var parents: Array = []  # keresztezésnél a két szülő DNS-e
var total := 0
var finishing := false

var cells: Array = []  # [y][x] Button
var gene_name: Array = []
var gene_value: Array = []
var progress_l := Label.new()
var rules_l := Label.new()
var board_box := GridContainer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(.047, .059, .086, .88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "A mag DNS-e"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	progress_l.add_theme_font_size_override("font_size", 12)
	progress_l.add_theme_color_override("font_color", INK_SOFT)
	progress_l.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(progress_l)

	rules_l.add_theme_font_size_override("font_size", 12)
	rules_l.add_theme_color_override("font_color", INK_SOFT)
	rules_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(rules_l)

	board_box.columns = DnaBoard.N + 1
	board_box.add_theme_constant_override("h_separation", 4)
	board_box.add_theme_constant_override("v_separation", 4)
	col.add_child(board_box)
	for y in DnaBoard.N:
		var row: Array = []
		for x in DnaBoard.N:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 11)
			b.pressed.connect(_tap.bind(y, x))
			board_box.add_child(b)
			row.append(b)
		cells.append(row)
		var g := VBoxContainer.new()
		g.custom_minimum_size = Vector2(GENE_W, 0)
		g.add_theme_constant_override("separation", 0)
		var n := Label.new()
		n.add_theme_font_size_override("font_size", 11)
		var v := Label.new()
		v.add_theme_font_size_override("font_size", 11)
		v.add_theme_color_override("font_color", INK)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.custom_minimum_size = Vector2(GENE_W - 6, 0)
		g.add_child(n)
		g.add_child(v)
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 6)
		pad.add_child(g)
		board_box.add_child(pad)
		gene_name.append(n)
		gene_value.append(v)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	col.add_child(actions)
	_action(actions, "Mégse", func() -> void: cancelled.emit())
	_action(actions, "Törlés", func() -> void:
		if finishing:
			return
		grid = _copy(clue)
		_refresh())
	_action(actions, "Tipp", _hint)
	_layout()
	get_viewport().size_changed.connect(_layout)


func _action(parent: Container, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 13)
	parent.add_child(b)
	b.pressed.connect(cb)


## A tábla mérete a képernyő szélességéhez igazodik (telefonon ~40 px-es mezők).
func _layout() -> void:
	var w := minf(get_viewport().get_visible_rect().size.x, 470.0) - 36.0
	var s := floorf(clampf((w - GENE_W - 4.0 * DnaBoard.N) / DnaBoard.N, 30.0, 58.0))
	for row in cells:
		for b in row:
			(b as Button).custom_minimum_size = Vector2(s, s)
	rules_l.custom_minimum_size = Vector2(s * DnaBoard.N + 4.0 * DnaBoard.N + GENE_W, 0)


func _copy(a: Array) -> Array:
	var out: Array = []
	for r in a:
		out.append((r as Array).duplicate())
	return out


## Új feladvány. Keresztezésnél a két szülő génjeiből indul, a legközelebbi szabályos táblából.
func open(parent_dnas: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var dna: Array
	parents = parent_dnas
	if parents.size() == 2:
		var wanted: Array = []
		for y in DnaBoard.N:
			wanted.append(parents[rng.randi() % 2][y])
		dna = DnaBoard.nearest_board(wanted, rng)
	else:
		dna = DnaBoard.random_board(rng)
	var p := DnaBoard.make_puzzle(dna, rng)
	clue = p.clue
	target = p.target
	free = p.free
	grid = _copy(clue)
	total = 0
	for r in clue:
		total += (r as Array).count(DnaBoard.EMPTY)
	finishing = false
	if parents.size() == 2:
		rules_l.text = "Soronként és oszloponként 3 A=T és 3 G≡C legyen, három egyforma nem állhat egymás mellett. A sárga sorokban te döntesz. 1 és 2: melyik szülőtől jött, M: mutáció."
	else:
		rules_l.text = "Soronként és oszloponként 3 A=T és 3 G≡C legyen, három egyforma nem állhat egymás mellett. A sárga sorokban több jó megoldás van, ott te döntesz."
	visible = true
	_refresh()


## Ellenőrzéshez: a tábla kirakása a célmegoldással.
func solve() -> void:
	grid = _copy(target)
	_refresh()


func _tap(y: int, x: int) -> void:
	if finishing or clue[y][x] != DnaBoard.EMPTY:
		return
	var v: int = grid[y][x]
	grid[y][x] = 0 if v == DnaBoard.EMPTY else (1 if v == 0 else DnaBoard.EMPTY)
	_refresh()


func _hint() -> void:
	if finishing:
		return
	for y in DnaBoard.N:
		if free.has(y):
			continue
		for x in DnaBoard.N:
			if grid[y][x] != target[y][x]:
				grid[y][x] = target[y][x]
				_refresh()
				return
	rules_l.text = "A lezárt génekkel kész vagy, már csak a sárga sorokban kell döntened."


func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(3)
	return s


func _style_cell(b: Button, v: int, locked: bool, open_gene: bool, bad: bool) -> void:
	var c: Color = AT if v == 0 else GC
	var box: StyleBoxFlat
	var font := c
	if v == DnaBoard.EMPTY:
		box = _box(Color(0, 0, 0, 0), SEED if open_gene else LINE, 1)
		font = INK
	elif locked:
		box = _box(c, c, 1)
		font = NIGHT
	else:
		box = _box(Color(c, .2), c, 1)
	if bad:
		box.border_color = WARN
		box.set_border_width_all(2)
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, box)
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(fc, font)


func _refresh() -> void:
	var bad := DnaBoard.bad_cells(grid)
	var empty := 0
	for y in DnaBoard.N:
		for x in DnaBoard.N:
			var v: int = grid[y][x]
			var b: Button = cells[y][x]
			b.text = "" if v == DnaBoard.EMPTY else LABEL[v]
			_style_cell(b, v, clue[y][x] != DnaBoard.EMPTY, free.has(y), bad.has(Vector2i(x, y)))
			if v == DnaBoard.EMPTY:
				empty += 1
		var k := DnaBoard.row_of(grid[y])
		var tag := ""
		if k >= 0 and parents.size() == 2:
			tag = "  1" if k == parents[0][y] else ("  2" if k == parents[1][y] else "  M")
		var n: Label = gene_name[y]
		n.text = Genes.GENE_NAMES[y] + tag
		n.add_theme_color_override("font_color", SEED if free.has(y) or tag != "" else INK_SOFT)
		var val: Label = gene_value[y]
		val.text = Genes.allele_name(y, k) if k >= 0 else ("te döntesz" if free.has(y) else "…")
	progress_l.text = "%d / %d bázispár" % [total - empty, total]
	if empty == 0 and bad.is_empty() and not finishing:
		finishing = true
		get_tree().create_timer(.45).timeout.connect(_finish)


func _finish() -> void:
	if not visible:
		return
	var dna: Array = []
	for y in DnaBoard.N:
		dna.append(DnaBoard.row_of(grid[y]))
	var a: Rect2 = (cells[0][0] as Button).get_global_rect()
	var b: Rect2 = (cells[DnaBoard.N - 1][DnaBoard.N - 1] as Button).get_global_rect()
	# A bal felső és a jobb alsó mező középpontja között: ebből jön a spirál helye és a mezők távolsága.
	finished.emit(dna, _copy(grid), Rect2(a.get_center(), b.get_center() - a.get_center()))
