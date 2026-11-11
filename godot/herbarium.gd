class_name Herbarium
extends Control
## Herbárium (M6): a csillagok egyben a játékos emlékei (2026. 11. 11. óta a játékoséi, nem bolygónként). A felület
## elemei (a csillagok és a kozmosz: sky_stars.gd, cosmos.gd):
##  - Kozmosz: a kicsinyítés utolsó fokozata (a bolygók után tovább csípve kifelé). Fent „A csillagaid · N csillag”,
##    lent „Vissza a bolygókhoz”.
##  - Csillag-lap: egy csillagra koppintva (a kozmoszban, vagy a bolygó mögötti égen is) gyűrű jelöli, alul lebegő lap:
##    a csillag fája kis forgó 3D-előnézetben (mint a csíraválasztóban), fajnév, tulajdonságok, eredet (melyik
##    bolygóról), dátum. „‹ ›” (vagy húzás jobbra-balra) lapoz a csillagok között, így a kis pontokra sem kell pontosan
##    koppintani; a kozmoszban a kép a csillag felé tolódik. „Visszahozom”: a csillagból mag lesz, ami a táskába hull.
##  - Elengedés: leszállva a fa lebegő táblája alatt halvány „Elengedem…” (vagy hosszan nyomva a fát), utána
##    megerősítés – véletlenül nem lehet. A fa fénnyé oszlik és felszáll (sky_stars.gd), a végén a lapja nyílik.
##  - Az égről hozott mag fénye a 2D rétegben ívben a Táska gombjába repül.
##
## A főjelenet (main.gd) tagjait használja, ezért a host típus nélküli: game, stars, planet, cam, tag, tag_alpha, view,
## focus, trees, saved_view, garden_mode, ui_col, bag_btn, board, bag, crossing, fx, hatching, bench_on, retreating,
## _release_focused(), _recall_star(), _overlay_closed(), _on_seed_arrived().

const C_STAR := Color(1.0, .88, .6)
const C_LAVENDER := Color(.82, .76, 1.0)
const ORIGIN_TEXT := {"kezdo": "kezdő fa volt", "napi": "a nap magjából nőtt", "gyujtes": "gyűjtött magból nőtt",
	"keresztezes": "keresztezett magból nőtt", "csillag": "csillagról visszahozott magból nőtt", "ultetes": "próba-ültetés volt",
	"barat": "barát magjából nőtt"}
## Az előnézet mérete (képpont) és a kinövés hossza lapozáskor (mp).
const PREVIEW := Vector2(112, 132)
const GROW_LEN := 1.1
## A mag útja a csillagtól a táskáig (mp).
const FLY_LEN := 1.3

var host
## A lap ezt a csillagot mutatja (-1 = zárva).
var star_id := -1
## Képernyőképhez: az előnézet azonnal kinőve.
var snap := false

var _card := PanelContainer.new()
var _head := Label.new()
var _name := Label.new()
var _traits := Label.new()
var _origin := Label.new()
var _dates := Label.new()
var _msg := Label.new()
var _view := TextureRect.new()
var _prev: Button
var _next: Button
var _recall: Button
var _share: Button
var _vp := SubViewport.new()
var _cam := Camera3D.new()
var _world := Node3D.new()
var _plant: Dictionary = {}
var _grow_t := 0.0
var _t := 0.0
var _w := 340.0

var _ask := PanelContainer.new()
var _ask_body := Label.new()
var _ask_tree := -1

## A kozmoszban, lap nélkül: fent a cím és a csillagok száma, alul „Vissza a bolygókhoz”.
var _top := VBoxContainer.new()
var _top_title := Label.new()
var _top_sub := Label.new()
var _back: Button
var release_btn: Button

var _fly_layer := CanvasLayer.new()
var _fly := Control.new()
## {"from", "to", "t", "col", "id"}
var _flying := {}
var _swipe := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# --- a csillag-lap
	_card.add_theme_stylebox_override("panel", BoardView.panel_style())
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.visible = false
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_card.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	BoardView._style_label(_head, 12, BoardView.C_DIM)
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_head)
	var close_b := BoardView.make_button(head, "Bezár", close, BoardView.C_DIM)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_b.custom_minimum_size = Vector2(78, 34)
	close_b.add_theme_font_size_override("font_size", 13)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.custom_minimum_size = PREVIEW
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_view)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	BoardView._style_label(_name, 18, BoardView.C_TEXT)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_name)
	for l in [_traits, _origin, _dates]:
		BoardView._style_label(l, 11, BoardView.C_DIM if l != _origin else C_LAVENDER)
		(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(l)
	BoardView._style_label(_msg, 12, BoardView.C_FREE)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_msg)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	col.add_child(nav)
	_prev = BoardView.make_button(nav, "‹", func() -> void: page(-1))
	_recall = BoardView.make_button(nav, "Visszahozom", _on_recall, C_STAR)
	# megosztás (M10): a csillag fájának képe + mag-kódja
	_share = BoardView.make_button(nav, "Megosztom", func() -> void:
		if star_id >= 0:
			host.share.share_star(star_id), BoardView.C_FREE)
	_next = BoardView.make_button(nav, "›", func() -> void: page(1))
	for b in [_prev, _next]:
		(b as Button).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		(b as Button).custom_minimum_size = Vector2(56, 46)
		(b as Button).add_theme_font_size_override("font_size", 24)
	_recall.custom_minimum_size = Vector2(0, 46)
	_share.custom_minimum_size = Vector2(0, 46)
	for b in [_recall, _share]:
		(b as Button).add_theme_font_size_override("font_size", 15)
	# --- az előnézet saját világa (mint a csíraválasztóban)
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
	_cam.position = Vector3(0, .12, .75 / tan(deg_to_rad(_cam.fov) * .5))
	_vp.add_child(_cam)
	_cam.look_at(Vector3(0, 0, 0), Vector3.UP)
	_view.texture = _vp.get_texture()
	# --- megerősítés elengedés előtt
	_ask.add_theme_stylebox_override("panel", BoardView.panel_style())
	_ask.mouse_filter = Control.MOUSE_FILTER_STOP
	_ask.visible = false
	add_child(_ask)
	var acol := VBoxContainer.new()
	acol.add_theme_constant_override("separation", 10)
	_ask.add_child(acol)
	var at := Label.new()
	BoardView._style_label(at, 20, BoardView.C_TEXT)
	at.text = "Elengeded?"
	at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	acol.add_child(at)
	BoardView._style_label(_ask_body, 13, BoardView.C_DIM)
	_ask_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ask_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	acol.add_child(_ask_body)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 8)
	acol.add_child(arow)
	BoardView.make_button(arow, "Mégse", _on_cancel, BoardView.C_DIM)
	BoardView.make_button(arow, "Elengedem", _on_confirm, C_STAR)
	# --- a kozmoszban: cím fent, „Vissza a bolygókhoz” lent
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_theme_constant_override("separation", 2)
	_top.visible = false
	add_child(_top)
	BoardView._style_label(_top_title, 22, BoardView.C_TEXT)
	BoardView._style_label(_top_sub, 13, BoardView.C_DIM)
	for l in [_top_title, _top_sub]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(l as Label).add_theme_color_override("font_shadow_color", Color(.03, .02, .1, .8))
		(l as Label).add_theme_constant_override("shadow_offset_y", 1)
		(l as Label).add_theme_constant_override("shadow_outline_size", 6)
		_top.add_child(l)
	_top_title.text = "A csillagaid"
	_back = BoardView.make_button(self, "Vissza a bolygókhoz", func() -> void: host.back_from_stars(), C_LAVENDER)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.custom_minimum_size = Vector2(190, 46)
	_back.focus_mode = Control.FOCUS_NONE
	_back.visible = false
	# --- az „Elengedem…”
	release_btn = BoardView.make_button(self, "Elengedem…", ask_release, C_LAVENDER)
	release_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	release_btn.custom_minimum_size = Vector2(128, 36)
	release_btn.size = release_btn.custom_minimum_size
	release_btn.add_theme_font_size_override("font_size", 13)
	release_btn.focus_mode = Control.FOCUS_NONE
	release_btn.visible = false
	# --- a táskába repülő mag (a gombok fölött)
	_fly_layer.layer = 3
	add_child(_fly_layer)
	_fly.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fly.draw.connect(_draw_fly)
	_fly_layer.add_child(_fly)


## Nyitva van-e a lap vagy a megerősítés (a világ ilyenkor nem forog magától, a gombsor rejtve).
func is_open() -> bool:
	return _card.visible or _ask.visible


func card_open() -> bool:
	return _card.visible


func asking() -> bool:
	return _ask.visible


# ---------------------------------------------------------------- Csillag-lap

## A lap a csillaggal (gyűrű jelöli; a kozmoszban a kép felé tolódik). msg: felső üzenet (pl. „… csillag lett”).
func open(id: int, msg := "") -> void:
	var stars: SkyStars = host.stars
	if stars._find(id).is_empty():
		return
	host.board.close()
	host.bag.visible = false
	host.ui_col.visible = false
	stars.open_sky(id)
	var was := _card.visible
	_card.visible = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_show(id, msg)
	if not was:
		_card.modulate = Color(1, 1, 1, 0)
		create_tween().tween_property(_card, "modulate:a", 1.0, .45)


## A lap bezárása (a kamera ott marad, ahol van – a kozmoszban a csillagok közt), a gombsor visszajön.
func close() -> void:
	close_now()
	host._overlay_closed()


## Bezárás jelzés nélkül (bolygóváltáskor, méréskor).
func close_now() -> void:
	_ask.visible = false
	_card.visible = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	star_id = -1
	_drop_plant()
	if host != null:
		host.stars.close_sky()


## Lapozás a csillagok között (sorszám szerint, körbe).
func page(dir: int) -> void:
	var ord: Array = host.stars.ordered()
	if ord.is_empty():
		return
	var i := 0
	for k in ord.size():
		if int(ord[k].id) == star_id:
			i = k
	var nid := int(ord[posmod(i + dir, ord.size())].id)
	host.stars.select(nid)
	_show(nid, "")


func _show(id: int, msg: String) -> void:
	var stars: SkyStars = host.stars
	var s := stars._find(id)
	if s.is_empty():
		return
	var st: Dictionary = s.rec
	var ord := stars.ordered()
	var idx := 0
	for k in ord.size():
		if int(ord[k].id) == id:
			idx = k + 1
	_head.text = "A csillagaid · %d / %d" % [idx, ord.size()]
	_name.text = Genes.latin_name(st.dna)
	_traits.text = Genes.traits_text(st.dna, int(st.get("rare", 0)))
	_origin.text = origin_text(st)
	_dates.text = dates_text(st)
	_msg.text = msg
	_msg.visible = msg != ""
	_prev.disabled = ord.size() < 2
	_next.disabled = ord.size() < 2
	_recall.disabled = false
	_layout()
	if id != star_id:
		star_id = id
		_build_plant(st)


## Honnan jött a csillag (a lapon, levendula színnel).
static func origin_text(st: Dictionary) -> String:
	var o := str(st.origin)
	if o == "csira":
		var ps: Array = st.get("parents", [])
		if ps.size() == 2:
			return "A keresztezés el nem választott csírája (%s × %s)%s" % [Genes.latin_name(ps[0]), Genes.latin_name(ps[1]), _from(st)]
		return "A keresztezés el nem választott csírája%s" % _from(st)
	if o == "teszt":
		return "Teszt-csillag (a „+csillag” gombtól)"
	return "Elengedett fa · %s%s" % [ORIGIN_TEXT.get(o, "a kertedben nőtt"), _from(st)]


## Melyik bolygón lett csillag (a csillagok a játékoséi, de emlékeznek a bolygójukra).
static func _from(st: Dictionary) -> String:
	var pc := str(st.get("planet", ""))
	return " · %s bolygóról" % Planet.name_for(pc) if pc != "" else ""


static func dates_text(st: Dictionary) -> String:
	var rel := GameState.day_label(int(st.get("released", GameState.today())))
	if str(st.origin) == "csira" or str(st.origin) == "teszt":
		return "Csillag lett: %s" % rel
	return "Kikelt: %s · csillag lett: %s" % [GameState.day_label(int(st.hatch)), rel]


func _on_recall() -> void:
	if star_id < 0 or host.stars.busy():
		return
	host._recall_star(star_id)


func _layout() -> void:
	var vp := get_viewport_rect().size
	_w = minf(vp.x - 16.0, 440.0) - 24.0
	var info_w := _w - PREVIEW.x - 10.0
	for l in [_name, _traits, _origin, _dates]:
		(l as Label).custom_minimum_size = Vector2(info_w, 0)
	_msg.custom_minimum_size = Vector2(_w, 0)
	var k := clampf(get_viewport().get_final_transform().get_scale().x, 1.0, 2.5)
	_vp.size = Vector2i(roundi(PREVIEW.x * k), roundi(PREVIEW.y * k))


func _build_plant(st: Dictionary) -> void:
	_drop_plant()
	var g := Genes.from_dna(st.dna, str(st.code), int(st.get("rare", 0)))
	_plant = SproutPick.build_preview(g)
	_world.add_child(_plant.node)
	_grow_t = GROW_LEN if snap else 0.0
	_pose_plant()


func _drop_plant() -> void:
	if not _plant.is_empty():
		(_plant.node as Node3D).queue_free()
	_plant = {}


func _pose_plant() -> void:
	if _plant.is_empty():
		return
	var u := clampf(_grow_t / GROW_LEN, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	SproutPick.pose_preview(_plant, Vector3(0, -.66, 0), float(_plant.rot) + _t * .3, 1.0, 1.0 - pow(1.0 - u, 1.7))


# ---------------------------------------------------------------- Elengedés

## „Elengedem…” (vagy hosszú nyomás a fán): megerősítés a kiválasztott (leszállt) fára.
func ask_release() -> void:
	if not _can_release():
		return
	var t: Dictionary = host.trees[host.focus]
	var game: GameState = host.game
	var rec := game.find_tree(int(t.sid))
	if rec.is_empty():
		return
	_ask_tree = int(t.sid)
	var p := game.active_planet()
	var body := "%s fénnyé válik, és csillag lesz a csillagaid között. A helye felszabadul.\nBármikor visszahozhatod: csípd kifelé a képet a bolygóidon túl, és koppints a csillagára." % Genes.latin_name(rec.dna)
	if not (p.founders as Array).is_empty() and (p.founders[0] as Array) == (rec.dna as Array):
		body += "\n\nŐ alapította a bolygót: a bolygó formája, talaja és holdjai megmaradnak, a színei a többi fából állnak össze."
	_ask_body.text = body
	var vp := get_viewport_rect().size
	_ask_body.custom_minimum_size = Vector2(minf(vp.x - 16.0, 400.0) - 24.0, 0)
	_ask.visible = true
	_ask.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(_ask, "modulate:a", 1.0, .3)
	host.ui_col.visible = false


func _on_cancel() -> void:
	_ask.visible = false
	host._overlay_closed()


func _on_confirm() -> void:
	_ask.visible = false
	if host.focus >= 0 and int(host.trees[host.focus].sid) == _ask_tree:
		host._release_focused()
	else:
		host._overlay_closed()


## Elengedhető-e most a kiválasztott fa (leszállva, a mentett bolygón, nyugalomban).
func _can_release() -> bool:
	return host.garden_mode == "planet" and host.saved_view and host.view == "surface" and host.focus >= 0 \
		and int(host.trees[host.focus].sid) >= 0 and not host.bench_on and not host.retreating and not host.fx.busy() \
		and not host.hatching.active() and not host.stars.busy() and not is_open() and not host.board.visible \
		and not host.bag.visible and not host.crossing.is_open() and not host.macro


# ---------------------------------------------------------------- A mag útja a táskába

## A visszahozott csillag magja fényként ívben a Táska gombjába repül (a gomb felvillan).
func fly_seed(from: Vector2, to: Vector2, col: Color, id: int) -> void:
	_flying = {"from": from, "to": to, "t": 0.0, "col": col, "id": id}


func _draw_fly() -> void:
	if _flying.is_empty():
		return
	var u := clampf(float(_flying.t) / FLY_LEN, 0.0, 1.0)
	var from: Vector2 = _flying.from
	var to: Vector2 = _flying.to
	var col: Color = _flying.col
	for i in 7:
		var ui := clampf(u - i * .03, 0.0, 1.0)
		var e := ui * ui * (3.0 - 2.0 * ui)
		# lefelé hulló ív: előbb kicsit lejjebb süllyed, aztán a gombhoz kanyarodik
		var mid := from.lerp(to, .5) + Vector2(60.0 * signf(from.x - to.x + .01), 120.0)
		var q := from.lerp(mid, e).lerp(mid.lerp(to, e), e)
		var a := (1.0 if i == 0 else .5 * (1.0 - i / 7.0)) * (1.0 - smoothstep(.92, 1.0, u))
		var r := 6.0 if i == 0 else 3.6 - i * .3
		_fly.draw_circle(q, r * 3.0, Color(col, .1 * a))
		_fly.draw_circle(q, r * 1.7, Color(col, .3 * a))
		_fly.draw_circle(q, r, Color(SeedFx.C_SEED.lerp(Color.WHITE, .3), .95 * a))


# ---------------------------------------------------------------- Képkockánként

func _process(delta: float) -> void:
	_t += delta
	if host == null:
		return
	var vp := get_viewport_rect().size
	if _card.visible:
		_grow_t += delta
		_pose_plant()
		_card.reset_size()
		_card.position = Vector2(floorf((vp.x - _card.size.x) * .5), floorf(vp.y - _card.size.y - 16.0 + sin(_t * .9) * 3.0))
	if _ask.visible:
		_ask.reset_size()
		_ask.position = ((vp - _ask.size) * .5).floor()
	# a kozmoszban, lap nélkül: a cím fent, a „Vissza a bolygókhoz” lent
	var calm: bool = host.garden_mode == "planet" and host.saved_view and not is_open() and host.ui_col.visible and not host.fx.busy() \
		and not host.hatching.active() and not host.stars.busy() and not host.bench_on
	var in_space: bool = calm and host.view == "orbit" and host.stars.cosmos() > .75 and not host.system.busy()
	_top.visible = in_space
	_back.visible = in_space
	if in_space:
		var n: int = host.stars.ordered().size()
		var top_y := 22.0 + (float(host.hud.dbg_box.size.y) + 6.0 if host.hud.debug and float(host.hud.dbg_box.size.y) > 2.0 else 0.0)
		_top_sub.text = ("%d csillag · húzd: körbenézel · koppints egyre: a fája" % n) if n > 0 else \
			"Még nincs csillagod. Ha egy fát elengedsz, fénnyé válik, és itt ragyog tovább."
		_top_title.custom_minimum_size = Vector2(minf(vp.x - 40.0, 420.0), 0)
		_top_sub.custom_minimum_size = Vector2(minf(vp.x - 40.0, 420.0), 0)
		_top.reset_size()
		_top.position = Vector2(floorf((vp.x - _top.size.x) * .5), top_y)
		var a := clampf((host.stars.cosmos() - .75) * 6.0, 0.0, 1.0)
		_top.modulate.a = a
		_back.modulate.a = a
		_back.size = _back.get_combined_minimum_size()
		_back.position = Vector2(floorf((vp.x - _back.size.x) * .5), vp.y - _back.size.y - 26.0)
	queue_redraw()
	# „Elengedem…” a lebegő tábla alatt (leszállva, amikor a tábla látszik), mellette balra az „Alakítás” (M8), jobbra
	# a „Megosztom” (M10; vendégként a barát bolygóján „Magot kérek”)
	var show_rel: bool = calm and _can_release() and float(host.tag_alpha) > .5 and not host.share.busy()
	var shape_btn: Button = host.shaping.btn
	var show_shape: bool = host.garden_mode == "planet" and not is_open() and host.ui_col.visible and float(host.tag_alpha) > .5 \
		and host.shaping.can_start() and not host.share.busy()
	var share_btn: Button = host.share.tree_btn
	var show_share: bool = host.share.tree_btn_wanted(show_rel)
	release_btn.visible = show_rel
	shape_btn.visible = show_shape
	share_btn.visible = show_share
	var row: Array = []
	for pair in [[shape_btn, show_shape], [release_btn, show_rel], [share_btn, show_share]]:
		if pair[1]:
			row.append(pair[0])
	if not row.is_empty():
		var tag: Label3D = host.tag
		var cam: Camera3D = host.cam
		# a tábla sorai a tördeléssel együtt (a hosszú sorok több sorba törnek, a gombok különben a szövegre kerültek)
		var font: Font = tag.font if tag.font != null else ThemeDB.fallback_font
		var lines := 0
		for par in tag.text.split("\n"):
			var tw := font.get_string_size(par, HORIZONTAL_ALIGNMENT_LEFT, -1, tag.font_size).x
			lines += maxi(1, ceili(tw / (tag.width * .9)))
		var half := tag.pixel_size * tag.font_size * 1.3 * lines * .5
		var bottom := tag.global_position - cam.global_transform.basis.y * half
		var sp := cam.unproject_position(bottom) if not cam.is_position_behind(bottom) else Vector2(vp.x * .5, vp.y - 120.0)
		var w := 8.0 * (row.size() - 1)
		for b in row:
			(b as Button).size = (b as Button).get_combined_minimum_size()
			w += (b as Button).size.x
		var x := floorf(clampf(sp.x - w * .5, 6.0, maxf(6.0, vp.x - w - 6.0)))
		var y_max := vp.y - release_btn.size.y - 100.0
		# ha a tábla alja a gombsor alá lógna, a tábla feljebb csúszik (a gombsor a táska fölött marad)
		var over := sp.y + 10.0 - y_max
		if over > 0.0 and not cam.is_position_behind(bottom):
			var dist := (tag.global_position - cam.global_position).length()
			var per_px := 2.0 * dist * tan(deg_to_rad(cam.fov) * .5) / vp.y
			tag.global_position += cam.global_transform.basis.y * (over * per_px)
			sp.y -= over
		var y := floorf(clampf(sp.y + 10.0, vp.y * .35, y_max))
		var a := clampf((float(host.tag_alpha) - .5) * 2.0, 0.0, 1.0)
		for b in row:
			(b as Button).position = Vector2(x, y)
			(b as Button).modulate.a = a
			x += (b as Button).size.x + 8.0
	if not _flying.is_empty():
		_flying.t = float(_flying.t) + delta
		if float(_flying.t) >= FLY_LEN:
			var id := int(_flying.id)
			_flying = {}
			host._on_seed_arrived(id)
		_fly.queue_redraw()


## A megerősítés mögött halvány sötétítés (mint a táska mögött).
func _draw() -> void:
	if _ask.visible:
		draw_rect(get_viewport_rect(), Color(.04, .02, .10, .42 * _ask.modulate.a))


# ---------------------------------------------------------------- Érintés nyitott lapnál

## Nyitott lapnál: egy másik csillagra koppintva azt mutatja; jobbra-balra húzva lapoz. (A lap gombjai maguk kezelik a
## koppintást.)
func sky_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe = {"pos": event.position, "t": Time.get_ticks_msec(), "done": false}
		elif not _swipe.is_empty():
			var d: Vector2 = event.position - (_swipe.pos as Vector2)
			if not bool(_swipe.done) and d.length() < 14.0 and Time.get_ticks_msec() - int(_swipe.t) < 450:
				var id: int = host.stars.pick(event.position)
				if id >= 0 and id != star_id:
					open(id)
			_swipe = {}
	elif event is InputEventScreenDrag and not _swipe.is_empty() and not bool(_swipe.done) and _card.visible:
		var d: Vector2 = event.position - (_swipe.pos as Vector2)
		if absf(d.x) > 60.0 and absf(d.x) > absf(d.y) * 1.4:
			_swipe.done = true
			page(-1 if d.x > 0.0 else 1)
