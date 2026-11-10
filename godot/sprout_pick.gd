class_name SproutPick
extends Control
## „Három csíra” (M5): a keresztezett tábla után a három utód-jelölt egymás mellett, lebegő, fénylő panelen.
## Felül egy közös kis 3D-előnézet (egy SubViewport, saját világ): a három csíra kinő a földkupacából és lassan forog
## (egyszerűsített részletesség, ~3×15k háromszög, csak amíg a panel nyitva van). Alattuk kártyánként: fajnév,
## a hat gén változata 1 / 2 / M jellel (melyik szülőtől jött, vagy mutáció), ha előbújt, a rejtett szín, a DNS kis
## rácsa, és „Ezt nevelem”.
## Választáskor a másik kettő összemegy, fénnyé válik, és felszáll az égre (csillag lesz – az adat a state.gd-ben,
## a csillagkép az M6 dolga); a választott kártya rácsából indul a kettős spirál (seed_fx.gd), a mag a táskába repül.

## Választott (k = 0–2); a hívó indítja a spirált (grid_cells/grid_vals), és teszi a magot a táskába.
signal chosen(k: int)
## „Később”: a csírák a mentésben várnak (a táskában „Három csíra vár”).
signal closed

const WOOD := preload("res://shaders/wood.gdshader")
const LEAF := preload("res://shaders/leaf.gdshader")
const FLOWER := preload("res://shaders/flower.gdshader")

## A kinövés hossza (mp), és csíránként ennyivel később indul.
const GROW_LEN := 2.4
const GROW_STAGGER := .3
## Választás után: a két csillag felszáll (STAR_LEN), a spirál HELIX_AT-kor indul, a panel addig elhalványul.
const STAR_LEN := 2.4
const HELIX_AT := .95
## Az előnézet magassága (alacsony képernyőn kisebb, hogy a panel elférjen).
const PREVIEW_H := 150.0
## A mini DNS-rács egy mezője és a hézag (képpont).
const MINI_CELL := 8.0
const MINI_GAP := 2.0
const C_HIDDEN := Color(1.0, .86, .48)

var cross: Dictionary = {}
var t := 0.0
## Választás óta eltelt idő (-1 = még nem választott).
var pick_t := -1.0
var choice := -1
## Képernyőképhez: a kinövés / a választás ennél az időpontnál áll (-1 = fut).
var freeze_grow := -1.0
var freeze_pick := -1.0

var _panel := PanelContainer.new()
var _title := Label.new()
var _sub := Label.new()
var _view := TextureRect.new()
var _cards_row := HBoxContainer.new()
var _hint := Label.new()
var _later: Button
var _fx := Control.new()
var _vp := SubViewport.new()
var _cam := Camera3D.new()
var _world := Node3D.new()
var _plants: Array = []
var _cards: Array = []
var _laid_for := Vector2.ZERO
var _w := 340.0
var _ph := PREVIEW_H
var _world_w := 3.5
var _helix_sent := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_panel.add_theme_stylebox_override("panel", BoardView.panel_style())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)
	BoardView._style_label(_title, 21, BoardView.C_TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text = "Három csíra"
	col.add_child(_title)
	BoardView._style_label(_sub, 12, BoardView.C_DIM)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_sub)
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_view)
	_cards_row.add_theme_constant_override("separation", 6)
	_cards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_cards_row)
	BoardView._style_label(_hint, 11, BoardView.C_DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = "Egyet nevelsz tovább: az lesz a mag. A másik kettő csillag lesz a bolygó egén. 1 / 2: melyik szülőtől jött a gén, M: mutáció."
	col.add_child(_hint)
	var row := HBoxContainer.new()
	col.add_child(row)
	_later = BoardView.make_button(row, "Később", _on_later)
	# a felszálló csillagok a panel fölött
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	# a 3D-előnézet saját világa: kamera, fény, környezet (átlátszó háttér, a panel látszik mögötte)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_vp.add_child(_world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.78, .72, 1.0)
	env.ambient_light_energy = .75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, .92, .84)
	sun.light_energy = 1.5
	sun.rotation = Vector3(deg_to_rad(-38), deg_to_rad(28), 0)
	_vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(.62, .7, 1.0)
	fill.light_energy = .45
	fill.rotation = Vector3(deg_to_rad(-15), deg_to_rad(200), 0)
	_vp.add_child(fill)
	_cam.fov = 26.0
	_vp.add_child(_cam)
	_view.texture = _vp.get_texture()


## Megnyitás a választásra váró csírákkal (GameState.pending_sprouts()).
func open(c: Dictionary) -> void:
	cross = c
	t = 0.0
	pick_t = -1.0
	choice = -1
	_helix_sent = false
	_panel.modulate = Color.WHITE
	_sub.text = "%s × %s" % [c.names[0], c.names[1]]
	_layout()
	_build_cards()
	_build_plants()
	_later.disabled = false
	visible = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate:a", 1.0, .35)


func close() -> void:
	visible = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for p in _plants:
		(p.node as Node3D).queue_free()
	_plants.clear()


## A választott kártya mini rácsának mezői (képernyő-koordinátában, sorfolytonosan) és értékei a spirálhoz.
func grid_cells(k: int) -> Array:
	var gc: Control = _cards[k].grid
	var o := gc.get_global_rect().position
	var out: Array = []
	for y in DnaBoard.N:
		for x in DnaBoard.N:
			out.append(o + Vector2(x * (MINI_CELL + MINI_GAP) + MINI_CELL * .5, y * (MINI_CELL + MINI_GAP) + MINI_CELL * .5))
	return out


func grid_vals(k: int) -> Array:
	var out: Array = []
	for row in DnaBoard.grid_from_dna(cross.sprouts[k].dna):
		out.append_array(row)
	return out


## Teszteléshez (--shot): a k-adik csíra választása, mintha a gombjára koppintottak volna.
func choose(k: int) -> void:
	if choice >= 0 or k < 0 or k >= _cards.size():
		return
	choice = k
	pick_t = 0.0
	_later.disabled = true
	for i in _cards.size():
		var cd: Dictionary = _cards[i]
		(cd.button as Button).disabled = true
		if i == k:
			var sb: StyleBoxFlat = (cd.panel as PanelContainer).get_theme_stylebox("panel")
			sb.border_color = Color(C_HIDDEN, .9)
			sb.set_border_width_all(2)
			sb.shadow_color = Color(C_HIDDEN, .35)
			sb.shadow_size = 12
		else:
			create_tween().tween_property(cd.panel, "modulate:a", .3, .6)


func _on_later() -> void:
	if choice >= 0:
		return
	close()
	closed.emit()


func _layout() -> void:
	var vp := get_viewport_rect().size
	_laid_for = vp
	_w = minf(vp.x - 16.0, 440.0) - 24.0
	_ph = clampf(vp.y - 480.0, 96.0, PREVIEW_H)
	_view.custom_minimum_size = Vector2(_w, _ph)
	_hint.custom_minimum_size = Vector2(_w, 0)
	_sub.custom_minimum_size = Vector2(_w, 0)
	# a belső felbontás a valódi képpontokhoz igazodik (telefonon 2–3×), hogy a kis fák élesek legyenek
	var k := clampf(get_viewport().get_final_transform().get_scale().x, 1.0, 2.5)
	_vp.size = Vector2i(roundi(_w * k), roundi(_ph * k))
	# a kamera: a világ 1,5 egység magas (a fák ~1,1 magasak), a szélessége a képarányból; a fák az oszlopok közepén
	_world_w = 1.5 * _w / _ph
	var half_h := .75
	_cam.position = Vector3(0, .12, half_h / tan(deg_to_rad(_cam.fov) * .5))
	_cam.look_at(Vector3(0, 0, 0), Vector3.UP)


func _col_x(k: int) -> float:
	var cw := (_w - 12.0) / 3.0
	var px := (cw + 6.0) * k + cw * .5
	return (px / _w - .5) * _world_w


func _build_cards() -> void:
	for c in _cards_row.get_children():
		_cards_row.remove_child(c)
		c.queue_free()
	_cards.clear()
	var cw := floorf((_w - 12.0) / 3.0)
	for k in (cross.sprouts as Array).size():
		var sp: Dictionary = cross.sprouts[k]
		var dna: Array = sp.dna
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, .06)
		sb.border_color = Color(1, 1, 1, .16)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(14)
		sb.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel", sb)
		panel.custom_minimum_size = Vector2(cw, 0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cards_row.add_child(panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(col)
		var name_l := Label.new()
		BoardView._style_label(name_l, 12, BoardView.C_TEXT)
		name_l.text = str(sp.name).replace(" ", "\n")
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_l)
		for y in DnaBoard.N:
			col.add_child(_gene_line(y, int(dna[y]), str(sp.marks[y]), cw - 12.0))
		var hid := Label.new()
		BoardView._style_label(hid, 10, C_HIDDEN)
		hid.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hid.custom_minimum_size = Vector2(cw - 12.0, 0)
		hid.text = ("Előbújt a rejtett szín: %s!" % Genes.FLOWER[int(dna[0])][0]) if bool(sp.shows_hidden) else ""
		hid.visible = hid.text != ""
		col.add_child(hid)
		var grid := Control.new()
		var gw := 6.0 * MINI_CELL + 5.0 * MINI_GAP
		grid.custom_minimum_size = Vector2(gw, gw)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vals := DnaBoard.grid_from_dna(dna)
		var marks: Array = sp.marks
		grid.draw.connect(func() -> void: _draw_mini(grid, vals, marks))
		col.add_child(grid)
		var b := BoardView.make_button(col, "Ezt nevelem", func() -> void: _tap_choose(k), C_HIDDEN)
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(0, 44)
		_cards.append({"panel": panel, "grid": grid, "button": b})


func _tap_choose(k: int) -> void:
	choose(k)


## Egy gén sora a kártyán: 1 / 2 / M jel, színes génnél színfolt, és a változat neve (röviden, a gén nevével).
func _gene_line(y: int, k: int, mark: String, w: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := Control.new()
	var sw := Genes.allele_color(y, k)
	chip.custom_minimum_size = Vector2(26 if sw.a > 0.0 else 16, 14)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.draw.connect(func() -> void:
		BoardView.draw_mark(chip, get_theme_default_font(), Vector2(7, 7), mark, 6.0)
		if sw.a > 0.0:
			chip.draw_circle(Vector2(20, 7), 4.5, sw)
			chip.draw_arc(Vector2(20, 7), 5.0, 0, TAU, 16, Color(1, 1, 1, .45), 1.0, true))
	row.add_child(chip)
	var l := Label.new()
	BoardView._style_label(l, 10, BoardView.C_TEXT if mark != "M" else BoardView.C_MUT)
	l.text = short_allele(y, k)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(w - chip.custom_minimum_size.x - 2.0, 0)
	row.add_child(l)
	return row


## Rövid génleírás a kártyára (a gén nevével, hogy magában is érthető legyen).
static func short_allele(y: int, k: int) -> String:
	var n := Genes.allele_name(y, k)
	match y:
		0:
			return n + " virág"
		2:
			return n + " levél"
		4:
			return n + " kéreg"
		5:
			return n + " lomb"
	return n


func _draw_mini(c: Control, vals: Array, marks: Array) -> void:
	for y in DnaBoard.N:
		for x in DnaBoard.N:
			var v: int = vals[y][x]
			var col: Color = BoardView.C_AT if v == 0 else BoardView.C_GC
			var r := Rect2(Vector2(x * (MINI_CELL + MINI_GAP), y * (MINI_CELL + MINI_GAP)), Vector2(MINI_CELL, MINI_CELL))
			c.draw_rect(r, Color(col, .75 if str(marks[y]) != "M" else .95))
		if str(marks[y]) == "M":
			# a mutált sor: halvány levendula keret
			var rr := Rect2(Vector2(-2, y * (MINI_CELL + MINI_GAP) - 1.5), Vector2(6.0 * MINI_CELL + 5.0 * MINI_GAP + 4, MINI_CELL + 3))
			c.draw_rect(rr, Color(BoardView.C_MUT, .8), false, 1.0)


# ---------------------------------------------------------------- 3D-előnézet

func _build_plants() -> void:
	for p in _plants:
		(p.node as Node3D).queue_free()
	_plants.clear()
	for k in (cross.sprouts as Array).size():
		var sp: Dictionary = cross.sprouts[k]
		var g := Genes.from_dna(sp.dna, str(sp.code))
		_plants.append(_make_plant(g, k))


## Egy csíra az előnézetben: egyszerűsített részletesség (ugyanaz a váz, mint a kertben), a saját oszlopában,
## a magasságához és szélességéhez méretezve, egy kis földkupacon.
func _make_plant(g: Dictionary, k: int) -> Dictionary:
	var pg := PlantGen.new()
	pg.build(g, .22)
	var node := Node3D.new()
	var mats: Array = []
	var wm := ShaderMaterial.new()
	wm.shader = WOOD
	var wood := MeshInstance3D.new()
	wood.mesh = pg.wood_mesh()
	wood.material_override = wm
	node.add_child(wood)
	mats.append(wm)
	if pg.leaf_p.size() > 0:
		var lm := ShaderMaterial.new()
		lm.shader = LEAF
		lm.set_shader_parameter("base", Genes.hsl(g.leaf_h, g.leaf_s, g.leaf_l))
		lm.set_shader_parameter("tip", Genes.hsl(g.leaf_tip_h, g.leaf_s * .9, g.leaf_l + .12))
		var li := MultiMeshInstance3D.new()
		li.multimesh = pg.leaves_multimesh()
		li.material_override = lm
		node.add_child(li)
		mats.append(lm)
	if pg.flo_p.size() > 0:
		var fm := ShaderMaterial.new()
		fm.shader = FLOWER
		fm.set_shader_parameter("petal", Genes.hsl(g.petal_h, g.petal_s, g.petal_l))
		fm.set_shader_parameter("petal_tip", Genes.hsl(g.petal_tip_h, g.petal_s * .9, minf(.92, g.petal_l + .12)))
		fm.set_shader_parameter("throat", Genes.hsl(g.center_h, .7, .55))
		fm.set_shader_parameter("stamen", Genes.hsl(g.center_h, .85, .5))
		var fi := MultiMeshInstance3D.new()
		fi.multimesh = pg.flowers_multimesh()
		fi.material_override = fm
		node.add_child(fi)
		mats.append(fm)
	var top := maxf(pg.bb_max.y, 1.6)
	var wid := maxf(pg.bb_max.x - pg.bb_min.x, pg.bb_max.z - pg.bb_min.z)
	var s := minf(1.12 / top, 1.0 / maxf(wid, .1))
	for m in mats:
		m.set_shader_parameter("max_path", pg.max_path)
		m.set_shader_parameter("plant_h", 5.0)
		m.set_shader_parameter("grow", 0.0)
	_world.add_child(node)
	var mound := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = .2
	sm.height = .1
	sm.radial_segments = 16
	sm.rings = 6
	mound.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(.36, .26, .3)
	mm.roughness = 1.0
	mm.emission_enabled = true
	mm.emission = Color(.42, .3, .62)
	mm.emission_energy_multiplier = .25
	mound.material_override = mm
	_world.add_child(mound)
	var base := Vector3(_col_x(k), -.66, 0)
	mound.position = base + Vector3(0, -.02, 0)
	var rot := float(Care.str_hash(str(g.code)) % 628) / 100.0
	return {"node": node, "mats": mats, "s": s, "top": top, "base": base, "rot": rot, "mound": mound,
		"cx": (pg.bb_max.x + pg.bb_min.x) * .5, "cz": (pg.bb_max.z + pg.bb_min.z) * .5, "col": Genes.hsl(g.petal_h, .8, .7)}


func _process(delta: float) -> void:
	if not visible:
		return
	if get_viewport_rect().size != _laid_for and choice < 0:
		_layout()
		_build_cards()
		for k in _plants.size():
			_plants[k].base = Vector3(_col_x(k), -.66, 0)
			(_plants[k].mound as Node3D).position = _plants[k].base + Vector3(0, -.02, 0)
	t += delta
	var tg := t if freeze_grow < 0.0 else freeze_grow
	if pick_t >= 0.0:
		pick_t = pick_t + delta if freeze_pick < 0.0 else freeze_pick
	for k in _plants.size():
		var p: Dictionary = _plants[k]
		var u := _smooth((tg - .15 - k * GROW_STAGGER) / GROW_LEN)
		var grow := 1.0 - pow(1.0 - u, 1.7)
		var shrink := 1.0
		if choice >= 0 and k != choice:
			# a nem választott csíra összemegy és fénnyé válik
			shrink = 1.0 - _smooth(pick_t / .7)
		var node: Node3D = p.node
		var s: float = p.s * maxf(shrink, .001)
		var b := Basis(Vector3.UP, float(p.rot) + tg * .22).scaled(Vector3.ONE * s)
		node.transform = Transform3D(b, p.base - b * Vector3(p.cx, 0, p.cz))
		(p.mound as Node3D).scale = Vector3.ONE * (.6 + .4 * shrink)
		for m in p.mats:
			var sm := m as ShaderMaterial
			sm.set_shader_parameter("grow", grow)
			sm.set_shader_parameter("tree_xf", node.transform)
			sm.set_shader_parameter("tree_inv", node.transform.affine_inverse())
			sm.set_shader_parameter("tree_scale", 5.0 / float(p.top))
	_panel.reset_size()
	_panel.position = ((get_viewport_rect().size - _panel.size) * .5).floor() + Vector2(0, sin(t * .9) * 3.0 if choice < 0 else 0.0)
	if pick_t >= 0.0:
		_panel.modulate.a = 1.0 - _smooth((pick_t - HELIX_AT + .1) / .5)
		if pick_t >= HELIX_AT and not _helix_sent:
			_helix_sent = true
			chosen.emit(choice)
		if pick_t >= STAR_LEN + .6 and freeze_pick < 0.0:
			close()
	queue_redraw()
	_fx.queue_redraw()


func _draw() -> void:
	var a := 1.0 if pick_t < 0.0 else 1.0 - _smooth((pick_t - HELIX_AT) / .4)
	draw_rect(get_viewport_rect(), Color(.04, .02, .10, .42 * a))


## Felszálló fények: a nem választott csírák helyéről (a 3D-előnézetben a fa közepe) lágyan, himbálózva fel a kép
## tetejéig, csóvával; fent apró, csillogó csillag lesz belőlük, ami elhalványul.
func _draw_fx() -> void:
	if pick_t < 0.0:
		return
	var r := _view.get_global_rect()
	for k in _plants.size():
		if k == choice:
			continue
		var p: Dictionary = _plants[k]
		var from := Vector2(r.position.x + r.size.x * (float(p.base.x) / _world_w + .5), r.position.y + r.size.y * .52)
		var to := Vector2(from.x + (k - 1) * 30.0 + 12.0, 46.0 + k * 9.0)
		var col: Color = (p.col as Color).lerp(Color.WHITE, .55)
		var appear := _smooth((pick_t - .25) / .4)
		var u := _smooth((pick_t - .4) / (STAR_LEN - .9))
		for i in 7:
			var ui := clampf(u - i * .035, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - ui, 2.0)
			var q := from.lerp(to, e) + Vector2(sin(ui * TAU * 1.2 + k) * 14.0 * (1.0 - e), 0)
			var a := appear * (1.0 if i == 0 else .5 * (1.0 - i / 7.0)) * (1.0 if ui > 0.0 or i == 0 else 0.0)
			var rad := (6.0 if i == 0 else 3.5 - i * .3)
			_fx.draw_circle(q, rad * 3.2, Color(col, .08 * a))
			_fx.draw_circle(q, rad * 1.8, Color(col, .22 * a))
			_fx.draw_circle(q, rad, Color(col.lerp(Color.WHITE, .5), .95 * a))
		# fent: csillogó csillag (négyágú fény), lassan elhalványul
		var tw := _smooth((pick_t - (STAR_LEN - .5)) / .35) * (1.0 - _smooth((pick_t - STAR_LEN - .1) / .5))
		if tw > .001:
			var L := 13.0 + 3.0 * sin(pick_t * 9.0 + k)
			for d in [Vector2(1, 0), Vector2(0, 1)]:
				_fx.draw_line(to - d * L, to + d * L, Color(col.lerp(Color.WHITE, .6), .8 * tw), 1.5, true)
			_fx.draw_circle(to, 9.0, Color(col, .2 * tw))
			_fx.draw_circle(to, 3.0, Color(1, 1, 1, .95 * tw))


static func _smooth(x: float) -> float:
	var v := clampf(x, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)
