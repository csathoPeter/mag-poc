class_name Share
extends Control
## Megosztás (M10): kép + kód, barát magja és bolygója kóddal. A kódolás: share_code.gd.
##  - „Megosztom” (a fa lebegő tábláján, a herbárium lapján, a táska magján; a nap magjánál a kész tábla szövege):
##    keretezett kép (a játék képe vagy a fa 3D-előnézete, rajta a fajnév és a mag-kód) + link (?mag=KOD). Alul lap:
##    a kép, a kód, „Küldés…” és „Bezár”.
##  - Weben a Web Share API (navigator.share, a képpel, ha navigator.canShare({files})), különben vágólap
##    (navigator.clipboard.writeText). Az iOS Safari csak felhasználói gesztusból enged megosztani, a Godot viszont a
##    koppintást a következő képkockában dolgozza fel (már a böngésző eseménykezelőjén kívül). Ezért a megosztást a
##    JS oldal indítja: amíg a lap nyitva van, a „Küldés…” gomb helyét (a vászon arányában) átadjuk a JS-nek, és egy
##    `touchend` (egérrel `pointerup`) figyelő – még a gesztus eseménykezelőjében – hívja a navigator.share-t. A Godot
##    gombja csak az eredményt mutatja (ha a figyelő valamiért nem futott, maga hívja; asztali böngészőben az is jó).
##  - Natívan: a kép a user://megosztas/ alá, a szöveg és a link a vágólapra (DisplayServer.clipboard_set).
##  - Barát magja: ?mag=KOD, vagy a táskában „Kód beírása” (weben JS prompt(): a Godot LineEdit-je weben nem nyit
##    virtuális billentyűzetet, mert a webes export kísérleti billentyűzete ki van kapcsolva) → „Kaptál egy magot”.
##  - Barát bolygója: ?bolygo=… → vendégként nézhető (main.gd show_guest_planet, a mentés nem változik), alul
##    „Vissza a kertembe”, a fára koppintva „Magot kérek”. A saját bolygón kívülről: „Bolygóm megosztása”.
##
## A főjelenet (main.gd) tagjait használja (típus nélküli host): game, trees, focus, view, saved_view, guest, garden_mode,
## ui_col, tag, tag_alpha, herb, shaping, stars, system, fx, hatching, bag, board, planet, bench_on, retreating,
## shot_args, macro, _sow(), open_bag(), _overlay_closed(), show_saved_planet(), retreat().

const C_FRIEND := Color(1.0, .74, .84)
## A keretezett kép mérete (4:5, a közösségi oldalak kedvelt aránya) és a benne lévő négyzetes képé.
const FRAME := Vector2i(1080, 1350)
const PHOTO := 960
## A „Kaptál egy magot” pillanat: a mag hullása, a lap feltűnése, a növény kinövése (mp).
const G_FALL := 1.1
const G_CARD := .9
const G_GROW := 1.6
const G_LEN := 2.8

const JS := """
(function(){
 if (window.magShare) return;
 var M = window.magShare = {data: null, file: null, rect: null, fired: 0, result: ''};
 M.put = function(json, b64, mime, fname) {
  M.data = JSON.parse(json); M.file = null; M.result = '';
  if (b64) {
   try {
    var bin = atob(b64), u = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
    M.file = new File([u], fname, {type: mime});
   } catch (e) { M.file = null; }
  }
 };
 M.arm = function(x0, y0, x1, y1) { M.rect = [x0, y0, x1, y1]; };
 M.disarm = function() { M.rect = null; };
 M.can = function() { return navigator.share ? 'share' : 'copy'; };
 M.full = function() { var d = M.data; return d.text + (d.url ? '\\n' + d.url : ''); };
 M.go = function() {
  if (!M.data) return 'nincs';
  M.fired = Date.now();
  var d = M.data, p = {title: d.title, text: d.text};
  if (d.url) p.url = d.url;
  try { if (M.file && navigator.canShare && navigator.canShare({files: [M.file]})) p.files = [M.file]; } catch (e) {}
  if (navigator.share) {
   M.result = 'fut';
   navigator.share(p).then(function() { M.result = 'megosztva'; }, function(e) {
    if (e && e.name === 'AbortError') { M.result = 'megszakitva'; return; }
    M.copy();
   });
   return 'share';
  }
  M.copy();
  return 'copy';
 };
 M.legacy = function(t) {
  try {
   var a = document.createElement('textarea'); a.value = t; a.setAttribute('readonly', '');
   a.style.cssText = 'position:fixed;top:0;left:0;opacity:0'; document.body.appendChild(a);
   a.select(); a.setSelectionRange(0, t.length); var ok = document.execCommand('copy'); a.remove(); return ok;
  } catch (e) { return false; }
 };
 M.copy = function() {
  var t = M.full(); M.result = 'fut';
  if (navigator.clipboard && navigator.clipboard.writeText) {
   navigator.clipboard.writeText(t).then(function() { M.result = 'vagolap'; }, function() { M.result = M.legacy(t) ? 'vagolap' : 'hiba'; });
  } else { M.result = M.legacy(t) ? 'vagolap' : 'hiba'; }
 };
 function up(e) {
  if (!M.rect || !M.data) return;
  if (e.type === 'pointerup' && e.pointerType === 'touch') return;
  var c = document.querySelector('canvas'); if (!c) return;
  var r = c.getBoundingClientRect(), p = e.changedTouches ? e.changedTouches[0] : e;
  var fx = (p.clientX - r.left) / r.width, fy = (p.clientY - r.top) / r.height;
  if (fx >= M.rect[0] && fx <= M.rect[2] && fy >= M.rect[1] && fy <= M.rect[3] && Date.now() - M.fired > 800) M.go();
 }
 document.addEventListener('touchend', up, true);
 document.addEventListener('pointerup', up, true);
})();
"""

const ROUND_SHADER := """
shader_type canvas_item;
uniform vec2 size = vec2(960.0);
uniform float radius = 40.0;
void fragment() {
	vec2 p = UV * size;
	vec2 q = abs(p - size * .5) - (size * .5 - vec2(radius));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= clamp(.5 - d, 0.0, 1.0);
}
"""

var host

## Lebegő gombok: a fa táblája alatt („Megosztom” / vendégként „Magot kérek”; a herbarium.gd helyezi el a többi
## mellé), vendégként alul középen „Vissza a kertembe”. A „Bolygóm megosztása” (M12 óta) a jobb felső „…” lapon
## van (hud.gd).
var tree_btn: Button
var home_btn: Button

## Képernyőképhez: a „Kaptál egy magot” pillanat ennél az időnél áll (-1 = fut).
var gift_freeze := -1.0

var _dim := Control.new()
# --- a megosztás lapja
var _sheet := PanelContainer.new()
var _s_title := Label.new()
var _s_pic := TextureRect.new()
var _s_grid := Control.new()
var _s_code := Label.new()
var _s_link := Label.new()
var _s_msg := Label.new()
var _send: Button
## Mit osztunk meg: {"title", "text", "url", "image": Image vagy null, "file", "cells" (napi rács), "code"}.
var _payload := {}
var _armed := Rect2()
var _polling := false
var _working := false
var _capturing := false
# --- a keretezett kép (külön 2D-s világ, egyszer rajzolva)
var _frame_vp := SubViewport.new()
var _f_photo := TextureRect.new()
var _f_name := Label.new()
var _f_sub := Label.new()
var _f_code := Label.new()
var _f_foot := Label.new()
# --- a fa 3D-előnézete (a mag és a csillag képéhez, és a „Kaptál egy magot” lapon élőben)
var _pv_vp := SubViewport.new()
var _pv_world := Node3D.new()
var _pv_cam := Camera3D.new()
var _pv_plant: Dictionary = {}
# --- „Kaptál egy magot”
var _gift := PanelContainer.new()
var _g_title := Label.new()
var _g_pic := TextureRect.new()
var _g_name := Label.new()
var _g_traits := Label.new()
var _g_from := Label.new()
var _g_btns := HBoxContainer.new()
var _g_t := -1.0
var _g_seed: Dictionary = {}
var _g_col := SeedFx.C_SEED
# --- kód beírása (natívan; weben prompt())
var _entry := PanelContainer.new()
var _e_line := LineEdit.new()
var _e_msg := Label.new()
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_dim.draw.connect(_draw_dim)
	_dim.gui_input.connect(_dim_input)
	add_child(_dim)
	_build_sheet()
	_build_gift()
	_build_entry()
	_build_frame()
	_build_preview_world()
	tree_btn = _float_button("Megosztom", _on_tree_btn, BoardView.C_FREE)
	tree_btn.custom_minimum_size = Vector2(112, 36)
	home_btn = _float_button("Vissza a kertembe", go_home, C_FRIEND)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(JS, true)


func _float_button(text: String, cb: Callable, accent: Color) -> Button:
	var b := BoardView.make_button(self, text, cb, accent)
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 13)
	b.focus_mode = Control.FOCUS_NONE
	b.visible = false
	b.size = b.get_combined_minimum_size()
	return b


## Nyitva van-e valamelyik lap (a megosztás, a „Kaptál egy magot” vagy a kód beírása).
func is_open() -> bool:
	return _sheet.visible or _gift.visible or _entry.visible


## Épp képet készít, vagy nyitva van: a többi lebegő gomb ilyenkor rejtve.
func busy() -> bool:
	return _working or _capturing or is_open()


# ---------------------------------------------------------------- Felépítés

func _build_sheet() -> void:
	# a megosztás lapja gyakran egy másik lapon (táska, herbárium) vagy a fa tábláján nyílik: majdnem átlátszatlan,
	# különben az alatta lévő szöveg átütött rajta
	var sheet_sb := BoardView.panel_style()
	sheet_sb.bg_color.a = .93
	_sheet.add_theme_stylebox_override("panel", sheet_sb)
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.visible = false
	add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_sheet.add_child(col)
	BoardView._style_label(_s_title, 19, BoardView.C_TEXT)
	_s_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_s_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_s_title)
	_s_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_s_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_s_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_s_pic)
	_s_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_s_grid.draw.connect(_draw_grid)
	col.add_child(_s_grid)
	BoardView._style_label(_s_code, 24, BoardView.C_FREE)
	_s_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_s_code)
	BoardView._style_label(_s_link, 11, BoardView.C_DIM)
	_s_link.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_s_link.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	col.add_child(_s_link)
	BoardView._style_label(_s_msg, 13, BoardView.C_AT)
	_s_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_s_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_s_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	BoardView.make_button(row, "Bezár", close_sheet, BoardView.C_DIM)
	_send = BoardView.make_button(row, "Küldés…", _on_send, BoardView.C_FREE)


func _build_gift() -> void:
	_gift.add_theme_stylebox_override("panel", BoardView.panel_style())
	_gift.mouse_filter = Control.MOUSE_FILTER_STOP
	_gift.visible = false
	add_child(_gift)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_gift.add_child(col)
	BoardView._style_label(_g_title, 21, BoardView.C_TEXT)
	_g_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_g_title)
	_g_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_g_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_g_pic.custom_minimum_size = Vector2(0, 200)
	_g_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_g_pic)
	for l in [_g_name, _g_traits, _g_from]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	BoardView._style_label(_g_name, 22, BoardView.C_TEXT)
	BoardView._style_label(_g_traits, 12, BoardView.C_DIM)
	BoardView._style_label(_g_from, 12, C_FRIEND)
	_g_btns.add_theme_constant_override("separation", 8)
	col.add_child(_g_btns)


func _build_entry() -> void:
	_entry.add_theme_stylebox_override("panel", BoardView.panel_style())
	_entry.mouse_filter = Control.MOUSE_FILTER_STOP
	_entry.visible = false
	add_child(_entry)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_entry.add_child(col)
	var t := Label.new()
	BoardView._style_label(t, 19, BoardView.C_TEXT)
	t.text = "Barátod magjának kódja"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	_e_line.placeholder_text = "ABCD-EFGH-JKM"
	_e_line.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_e_line.add_theme_font_size_override("font_size", 22)
	_e_line.custom_minimum_size = Vector2(280, 48)
	_e_line.text_submitted.connect(func(_s: String) -> void: _entry_ok())
	col.add_child(_e_line)
	BoardView._style_label(_e_msg, 12, BoardView.C_DIM)
	_e_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_e_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_e_msg.custom_minimum_size = Vector2(280, 0)
	col.add_child(_e_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	BoardView.make_button(row, "Mégse", func() -> void:
		_entry.visible = false
		_after_close(), BoardView.C_DIM)
	BoardView.make_button(row, "Kérem", _entry_ok, C_FRIEND)


## A keretezett kép: sötét lila háttér, halvány fényudvar, lekerekített kép, alatta a fajnév, a tulajdonságok, a kód
## és a játék címe. Egy külön SubViewport rajzolja, csak amikor kell (UPDATE_DISABLED).
func _build_frame() -> void:
	_frame_vp.size = FRAME
	_frame_vp.transparent_bg = false
	_frame_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_frame_vp.disable_3d = true
	add_child(_frame_vp)
	var bg := ColorRect.new()
	bg.color = Color(.07, .05, .16)
	bg.size = Vector2(FRAME)
	_frame_vp.add_child(bg)
	var glow := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(.42, .30, .72, .75))
	gr.set_color(1, Color(.42, .30, .72, 0.0))
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(.5, .5)
	gt.fill_to = Vector2(.5, 0.0)
	gt.width = 256
	gt.height = 256
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.position = Vector2(-60, -60)
	glow.size = Vector2(FRAME.x + 120, FRAME.x + 120)
	_frame_vp.add_child(glow)
	var off := (FRAME.x - PHOTO) / 2
	_f_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_f_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_f_photo.position = Vector2(off, off)
	_f_photo.size = Vector2(PHOTO, PHOTO)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = ROUND_SHADER
	sm.shader = sh
	sm.set_shader_parameter("size", Vector2(PHOTO, PHOTO))
	_f_photo.material = sm
	_frame_vp.add_child(_f_photo)
	var border := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(.85, .78, 1.0, .4)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(42)
	border.add_theme_stylebox_override("panel", sb)
	border.position = Vector2(off - 2, off - 2)
	border.size = Vector2(PHOTO + 4, PHOTO + 4)
	_frame_vp.add_child(border)
	var y := float(off + PHOTO + 34)
	for spec in [[_f_name, 62, BoardView.C_TEXT, 84.0], [_f_sub, 28, Color(.82, .78, .96, .8), 44.0], [_f_code, 44, BoardView.C_FREE, 64.0], [_f_foot, 24, Color(.8, .76, .95, .55), 40.0]]:
		var l: Label = spec[0]
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", spec[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.position = Vector2(off, y)
		l.size = Vector2(PHOTO, spec[3])
		y += float(spec[3])
		_frame_vp.add_child(l)
	_f_foot.text = "Mag · egy nyugodt kert · csathopeter.github.io/mag-poc"


func _build_preview_world() -> void:
	_pv_vp.size = Vector2i(720, 720)
	_pv_vp.own_world_3d = true
	_pv_vp.transparent_bg = true
	_pv_vp.msaa_3d = Viewport.MSAA_4X
	_pv_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_pv_vp)
	_pv_vp.add_child(_pv_world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.78, .72, 1.0)
	env.ambient_light_energy = .75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	_pv_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, .92, .84)
	sun.light_energy = 1.5
	sun.rotation = Vector3(deg_to_rad(-38), deg_to_rad(28), 0)
	_pv_vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(.62, .7, 1.0)
	fill.light_energy = .45
	fill.rotation = Vector3(deg_to_rad(-15), deg_to_rad(200), 0)
	_pv_vp.add_child(fill)
	_pv_cam.fov = 28.0
	_pv_cam.position = Vector3(0, .02, .8 / tan(deg_to_rad(_pv_cam.fov) * .5))
	_pv_vp.add_child(_pv_cam)
	_pv_cam.look_at(Vector3(0, 0, 0), Vector3.UP)


func _preview_plant(dna: Array, code: String, det: float) -> void:
	if not _pv_plant.is_empty():
		(_pv_plant.node as Node3D).queue_free()
	_pv_plant = SproutPick.build_preview(Genes.from_dna(dna, code), det)
	_pv_world.add_child(_pv_plant.node)
	_pose_preview(1.0)


func _pose_preview(grow: float) -> void:
	if _pv_plant.is_empty():
		return
	SproutPick.pose_preview(_pv_plant, Vector3(0, -.6, 0), float(_pv_plant.rot) + _t * .25, 1.0, grow)


# ---------------------------------------------------------------- Megosztás

## A kiválasztott (leszállt) fa a saját bolygón: a játék képe (a felület nélkül) + a fa mag-kódja.
func share_focused() -> void:
	if _working or host.focus < 0:
		return
	var t: Dictionary = host.trees[host.focus]
	var rec: Dictionary = host.game.find_tree(int(t.sid)) if int(t.sid) >= 0 else {}
	if rec.is_empty():
		rec = {"dna": t.g.dna, "code": t.g.code, "hidden": -1}
	var code := ShareCode.for_tree(rec)
	_working = true
	var img: Image = await _capture_screen()
	_open_seed_sheet(rec.dna, code, img, "Egy fa a kertemből: %s." % Genes.latin_name(rec.dna))


## Egy mag a táskából: a kódból kelő fa 3D-előnézete + a mag-kód.
func share_seed(id: int) -> void:
	if _working:
		return
	var s: Dictionary = host.game.find_seed(id)
	if s.is_empty():
		return
	var code := ShareCode.for_seed(s, str(host.game.data.player))
	_working = true
	var img: Image = await _render_preview(s.dna, ShareCode.tree_code(code))
	var what := "Mag a táskámból"
	if str(s.origin) == "napi":
		what = "A nap magja (%s)" % GameState.day_label(int(s.day))
	elif str(s.origin) == "barat":
		what = "Egy mag, amit kaptam"
	_open_seed_sheet(s.dna, code, img, "%s: %s." % [what, Genes.latin_name(s.dna)])


## Egy csillag a herbárium lapjáról: a csillag fájának előnézete + a mag-kódja.
func share_star(id: int) -> void:
	if _working:
		return
	var st: Dictionary = host.game.find_star(id)
	if st.is_empty():
		return
	var code := ShareCode.for_tree(st)
	_working = true
	var img: Image = await _render_preview(st.dna, str(st.code))
	_open_seed_sheet(st.dna, code, img, "Csillag az égboltomon: %s." % Genes.latin_name(st.dna))


func _open_seed_sheet(dna: Array, code: String, photo: Image, text: String) -> void:
	var name := Genes.latin_name(dna)
	var framed: Image = await _compose(photo, name, Genes.traits_text(dna), "Mag-kód: %s" % code)
	var url := ShareCode.seed_url(code)
	_payload = {"title": "Mag · %s" % name, "text": "%s Vesd el te is: a kód %s" % [text, code], "url": url, "image": framed,
		"file": "mag-%s.jpg" % ShareCode.normalize(code).to_lower(), "code": code}
	_show_sheet("Megosztom: %s" % name, framed, code, url)


## A nap magja, Wordle-szerűen: dátum, fajnév, spoiler nélküli 6×6 rács, a szabad sorokban választott változatok, link
## (a tábla nyílik vele). Kép nélkül, csak szöveg (mint a Wordle).
func share_daily(day: int) -> void:
	if _working:
		return
	var dna: Array = host.game.daily_dna(day)
	if dna.is_empty():
		return
	var text := ShareCode.daily_text(day, dna)
	var url := ShareCode.base_url() + "?tabla"
	_payload = {"title": "Mag · a nap magja", "text": text, "url": url, "image": null, "file": "", "cells": ShareCode.daily_cells(day, dna), "code": ""}
	var picks := text.get_slice("\n", 7) if text.count("\n") >= 7 else ""
	_show_sheet("A nap magja · %s\n%s" % [GameState.day_label(day), Genes.latin_name(dna)], null, "", picks)


## A saját (aktív) bolygó kívülről: a játék képe + link a bolygó kódjával és a kikelt fákkal (?bolygo=…).
func share_planet() -> void:
	if _working or not host.saved_view:
		return
	var p: Dictionary = host.game.active_planet()
	var ts: Array = host.game.hatched(p)
	var link := ShareCode.encode_planet(p, ts, GameState.today())
	var url := ShareCode.planet_url(link)
	var pname: String = host.planet.planet_name()
	_working = true
	var img: Image = await _capture_screen()
	var framed: Image = await _compose(img, pname, "%d fa · %s" % [ts.size(), host.planet.describe().get_slice(" · ", 0)], "Látogass el hozzám")
	_payload = {"title": "Mag · %s" % pname, "text": "%s – a bolygóm a Mag-ban, %d fával. Gyere, nézd meg (és kérj magot):" % [pname, ts.size()],
		"url": url, "image": framed, "file": "bolygo-%s.jpg" % pname.to_lower(), "code": ""}
	_show_sheet("Bolygóm megosztása: %s" % pname, framed, "", "A link (%d jel) a bolygót és %d fáját hordozza." % [url.length(), ts.size()])


## A játék képe a felület nélkül (a gombsor, a lebegő tábla és a gombok egy képkockára eltűnnek).
func _capture_screen() -> Image:
	_capturing = true
	host.stop_waves()
	var hide: Array = [host.ui_col, host.herb.release_btn, host.shaping.btn, tree_btn, home_btn, host.herb.chip, host.tag]
	var was: Array = hide.map(func(n) -> bool: return bool(n.visible))
	for n in hide:
		n.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	# a gombsor rejtve marad (a lap jön); a többi visszakapja a láthatóságát
	for i in hide.size():
		if hide[i] != host.ui_col:
			hide[i].visible = was[i]
	_capturing = false
	return img


## A fa 3D-előnézete (részletes szinten, kinőve) egy négyzetes képbe, átlátszó háttérrel.
func _render_preview(dna: Array, code: String) -> Image:
	_preview_plant(dna, code, 1.0)
	_pv_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _pv_vp.get_texture().get_image()
	if not _gift.visible:
		_pv_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return img


## A keretezett kép: a négyzetre vágott kép (a közepéből), alatta a felirat. Visszaadja a kész képet (FRAME méret).
func _compose(photo: Image, title: String, sub: String, code_line: String) -> Image:
	var sq := _square(photo)
	_f_photo.texture = ImageTexture.create_from_image(sq)
	_f_name.text = title
	_f_sub.text = sub
	_f_code.text = code_line
	_frame_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _frame_vp.get_texture().get_image()
	_frame_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	img.convert(Image.FORMAT_RGB8)
	return img


static func _square(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var s := mini(w, h)
	var sq := img.get_region(Rect2i((w - s) / 2, clampi(h / 2 - s / 2, 0, h - s), s, s))
	if sq.get_format() != Image.FORMAT_RGBA8:
		sq.convert(Image.FORMAT_RGBA8)
	if s != PHOTO:
		sq.resize(PHOTO, PHOTO, Image.INTERPOLATE_CUBIC)
	return sq


func _show_sheet(title: String, img: Image, code: String, link: String) -> void:
	_working = false
	if img != null and not host.shot_args.is_empty():
		# képernyőképnél a keretezett kép is kimegy (ellenőrzéshez): kimenet_kep.jpg
		img.save_jpg(str(host.shot_args[0]).get_basename() + "_kep.jpg", .9)
	host.ui_col.visible = false
	_s_title.text = title
	_s_pic.visible = img != null
	if img != null:
		_s_pic.texture = ImageTexture.create_from_image(img)
	_s_grid.visible = _payload.has("cells")
	_s_code.text = code
	_s_code.visible = code != ""
	_s_link.text = link if link != "" else str(_payload.url)
	_s_msg.text = ""
	_s_msg.visible = false
	_send.text = "Küldés…"
	if OS.has_feature("web"):
		_send.text = "Küldés…" if str(JavaScriptBridge.eval("window.magShare ? window.magShare.can() : 'copy'", true)) == "share" else "Link másolása"
		var b64 := ""
		if img != null:
			b64 = Marshalls.raw_to_base64(img.save_jpg_to_buffer(.88))
		var ms = JavaScriptBridge.get_interface("magShare")
		if ms != null:
			ms.put(JSON.stringify({"title": _payload.title, "text": _payload.text, "url": _payload.url}), b64, "image/jpeg", str(_payload.file))
	else:
		_send.text = "Mentés + vágólap"
	_layout_sheet()
	_sheet.visible = true
	_dim.visible = true
	_sheet.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(_sheet, "modulate:a", 1.0, .3)
	_armed = Rect2()
	Sound.fx("select")


func close_sheet() -> void:
	_sheet.visible = false
	_polling = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.magShare && window.magShare.disarm()", true)
	_armed = Rect2()
	_after_close()


func _after_close() -> void:
	_dim.visible = is_open()
	if not is_open():
		host._overlay_closed()


## „Küldés…”: weben a JS figyelő már elindította a koppintás eseménykezelőjében (lásd fent); ha mégsem, innen.
## Natívan: kép a user://megosztas/ alá, a szöveg a vágólapra.
func _on_send() -> void:
	if OS.has_feature("web"):
		var since := float(JavaScriptBridge.eval("window.magShare ? Date.now() - window.magShare.fired : 1e9", true))
		if since > 1500.0:
			JavaScriptBridge.eval("window.magShare && window.magShare.go()", true)
		_polling = true
		return
	var full := "%s\n%s" % [_payload.text, _payload.url]
	DisplayServer.clipboard_set(full)
	var where := ""
	var img: Image = _payload.get("image")
	if img != null and host.shot_args.is_empty():
		DirAccess.make_dir_recursive_absolute("user://megosztas")
		var path := "user://megosztas/%s" % str(_payload.file)
		if img.save_jpg(path, .9) == OK:
			where = "A kép: %s\n" % ProjectSettings.globalize_path(path)
	_say("%sA link a vágólapon." % where)


func _say(msg: String) -> void:
	_s_msg.text = msg
	_s_msg.visible = msg != ""
	_layout_sheet()


func _layout_sheet() -> void:
	var vp := get_viewport_rect().size
	var w := minf(vp.x - 16.0, 420.0) - 24.0
	for l in [_s_title, _s_code, _s_link, _s_msg]:
		(l as Label).custom_minimum_size = Vector2(w, 0)
	var ph := minf(vp.y * .44, w * 1.25)
	_s_pic.custom_minimum_size = Vector2(w, ph)
	_s_grid.custom_minimum_size = Vector2(w, 6 * 24.0 + 10.0)
	_sheet.reset_size()


## A napi rács a lapon (a megosztott szöveg emojijai helyett rajzolva: a webes betűkészletben nincsenek emojik).
func _draw_grid() -> void:
	var cells: Array = _payload.get("cells", [])
	if cells.is_empty():
		return
	var s := 22.0
	var gap := 3.0
	var w := 6 * s + 5 * gap
	var o := Vector2((_s_grid.size.x - w) * .5, 4.0)
	var cols := [Color(.92, .9, 1.0, .85), Color(.42, .82, .5), Color(1.0, .84, .36), Color(.72, .52, 1.0)]
	for y in cells.size():
		for x in (cells[y] as Array).size():
			var r := Rect2(o + Vector2(x * (s + gap), y * (s + gap)), Vector2(s, s))
			_s_grid.draw_rect(r, cols[int(cells[y][x])])


# ---------------------------------------------------------------- Barát magja

## A táska „Kód beírása” gombja: weben prompt() (megbízhatóan nyit billentyűzetet), natívan saját mező.
func ask_code() -> void:
	if OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("prompt('Barátod magjának kódja (pl. ABCD-EFGH-JKM):', '')", true)
		if v == null or str(v).strip_edges() == "":
			return
		receive_code(str(v), false)
		return
	_e_line.text = ""
	_e_msg.text = "11 jel, a kötőjel nem számít. Nincs benne 0, O, 1, I és L."
	_entry.visible = true
	_dim.visible = true
	host.ui_col.visible = false
	_e_line.grab_focus()


func _entry_ok() -> void:
	var d := ShareCode.decode(_e_line.text)
	if not bool(d.ok):
		_e_msg.text = str(d.err)
		return
	_entry.visible = false
	receive_code(_e_line.text, false)


## Mag-kód → a mag a táskába (eredet „barat”), „Kaptál egy magot”. Hibás kódnál a táskában (vagy URL-ből jövet
## a lapon) üzenet; ugyanaz a kód kétszer nem jár.
func receive_code(text: String, from_url: bool) -> void:
	var game: GameState = host.game
	if game.data.is_empty():
		return
	var d := ShareCode.decode(text)
	if not bool(d.ok):
		if from_url:
			_gift_open({}, "Ez a kód nem nyílik ki", "", str(d.err), "")
		else:
			host.open_bag(-1, "%s (%s)" % [str(d.err), text.strip_edges()])
		return
	var code := str(d.code)
	if game.has_gift(code):
		_gift_open({}, "Ez a mag már nálad van", Genes.latin_name(d.dna), "Ezt a kódot (%s) már megkaptad. Nézd meg a táskában, vagy keresd a bolygódon." % code, "")
		return
	var day := int(d.day)
	var seed := game.receive_seed(code, d.dna, int(d.hidden), ShareCode.tree_code(code), day)
	game.save()
	var from := "Egy barátodtól · %s" % code
	if day >= 0:
		from = "A %s napi magja, egy barátodtól · %s" % [GameState.day_label(day), code]
	_gift_open(seed, "Kaptál egy magot", Genes.latin_name(d.dna), Genes.traits_text(d.dna), from)


## Vendégként a barát bolygóján: „Magot kérek” a kiválasztott fáról (pontosan az a fa nő ki belőle, a kódjával).
func ask_seed() -> void:
	if host.focus < 0 or host.guest.is_empty():
		return
	var t: Dictionary = host.trees[host.focus]
	var gt: Dictionary = {}
	for x in host.guest.trees:
		if str(x.code) == str(t.g.code):
			gt = x
	if gt.is_empty():
		return
	var game: GameState = host.game
	var code := ShareCode.for_tree(gt)
	var pname := Planet.name_for(str(host.guest.code))
	if game.has_gift(code):
		_gift_open({}, "Erről a fáról már kaptál magot", Genes.latin_name(gt.dna), "Nézd meg a táskádban.", "")
		return
	var seed := game.receive_seed(code, gt.dna, int(gt.hidden), str(gt.code), -1, pname)
	game.save()
	_gift_open(seed, "Kaptál egy magot", Genes.latin_name(gt.dna), Genes.traits_text(gt.dna), "%s bolygójáról, egy barátodtól" % pname)


## „Kaptál egy magot” (vagy egy rövid üzenet, ha seed üres): a mag fényként lehull, a lapon kinő a fája.
func _gift_open(seed: Dictionary, title: String, name: String, body: String, from: String) -> void:
	host.bag.visible = false
	host.board.close()
	host.ui_col.visible = false
	_g_seed = seed
	_g_title.text = title
	_g_name.text = name
	_g_name.visible = name != ""
	_g_traits.text = body
	_g_from.text = from
	_g_from.visible = from != ""
	for c in _g_btns.get_children():
		c.queue_free()
	_g_pic.visible = not seed.is_empty()
	if seed.is_empty():
		BoardView.make_button(_g_btns, "Táska", func() -> void: _gift_close(func() -> void: host.open_bag()), BoardView.C_DIM)
		BoardView.make_button(_g_btns, "Bezár", func() -> void: _gift_close(Callable()), BoardView.C_DIM)
		_g_t = G_LEN
	else:
		_preview_plant(seed.dna, str(seed.code), .22)
		_g_pic.texture = _pv_vp.get_texture()
		_pv_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_g_col = Genes.allele_color(0, int(seed.dna[0])).lerp(Color.WHITE, .25)
		var sid := int(seed.id)
		if host.guest.is_empty():
			BoardView.make_button(_g_btns, "Elvetem", func() -> void: _gift_close(func() -> void: host._sow(sid)), C_FRIEND)
		else:
			BoardView.make_button(_g_btns, "Tovább nézem", func() -> void: _gift_close(Callable()), BoardView.C_DIM)
		BoardView.make_button(_g_btns, "A táskába", func() -> void: _gift_close(func() -> void: host.open_bag(sid)), BoardView.C_FREE)
		_g_t = 0.0
		Sound.fx("recall")
		Sound.tree(seed.dna, str(seed.code), "one", G_FALL + .2)
	var vp := get_viewport_rect().size
	var w := minf(vp.x - 16.0, 400.0) - 24.0
	for l in [_g_title, _g_name, _g_traits, _g_from]:
		(l as Label).custom_minimum_size = Vector2(w, 0)
	_g_pic.custom_minimum_size = Vector2(w, minf(220.0, vp.y * .3))
	_gift.reset_size()
	_gift.visible = true
	_dim.visible = true


func _gift_close(then: Callable) -> void:
	_gift.visible = false
	_g_t = -1.0
	_pv_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if then.is_valid():
		_dim.visible = false
		then.call()
	else:
		_after_close()


# ---------------------------------------------------------------- Lebegő gombok

func _on_tree_btn() -> void:
	if not host.guest.is_empty():
		ask_seed()
	else:
		share_focused()


## Vissza a saját kertbe a barát bolygójáról (a link paramétere is lekerül, így újratöltve már a saját nyílik).
func go_home() -> void:
	if host.retreating:
		return
	forget_link()
	host.retreat(host.show_saved_planet)


## A barát bolygójának linkje lekerül az URL-ből (hazatérve újratöltéskor már a saját kert nyíljon).
static func forget_link() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{var u=new URL(location.href);u.searchParams.delete('bolygo');history.replaceState(null,'',u.toString());}catch(e){}})()", true)


## Látszhat-e a fa tábla alatti gomb: a saját, mentett fán „Megosztom”, vendégként „Magot kérek” (a herbarium.gd hívja).
func tree_btn_wanted(calm_own: bool) -> bool:
	if busy():
		return false
	if not host.guest.is_empty():
		tree_btn.text = "Magot kérek"
		return host.garden_mode == "planet" and host.view == "surface" and host.focus >= 0 and not host.macro and host.ui_col.visible \
			and float(host.tag_alpha) > .5 and not host.retreating and not host.bench_on
	tree_btn.text = "Megosztom"
	return calm_own


func _process(delta: float) -> void:
	_t += delta
	if host == null:
		return
	var vp := get_viewport_rect().size
	# vendégként alul középen „Vissza a kertembe” (bal lent a táska batyuja, jobb lent a csillagjel)
	var show_home: bool = not host.guest.is_empty() and host.ui_col.visible and not busy() and not host.retreating
	home_btn.visible = show_home
	if show_home:
		home_btn.size = home_btn.get_combined_minimum_size()
		home_btn.position = Vector2(floorf((vp.x - home_btn.size.x) * .5), vp.y - home_btn.size.y - 30.0)
	if _sheet.visible:
		_sheet.reset_size()
		_sheet.position = Vector2(floorf((vp.x - _sheet.size.x) * .5), floorf(maxf(8.0, (vp.y - _sheet.size.y) * .5)))
		if OS.has_feature("web"):
			# a „Küldés…” gomb helye a vászon arányában: a JS figyelő ezen belüli érintésre indítja a megosztást
			var r := _send.get_global_rect()
			var fr := Rect2(r.position / vp, r.size / vp)
			if not fr.is_equal_approx(_armed):
				_armed = fr
				JavaScriptBridge.eval("window.magShare && window.magShare.arm(%f,%f,%f,%f)" % [fr.position.x, fr.position.y, fr.end.x, fr.end.y], true)
			if _polling:
				var res := str(JavaScriptBridge.eval("window.magShare ? window.magShare.result : ''", true))
				match res:
					"megosztva":
						_say("Elküldve.")
						_polling = false
					"vagolap":
						_say("A link a vágólapon.")
						_polling = false
					"hiba":
						_say("Nem sikerült másolni. A kód: %s" % (str(_payload.code) if str(_payload.code) != "" else str(_payload.url)))
						_polling = false
					"megszakitva":
						_polling = false
	if _entry.visible:
		_entry.reset_size()
		_entry.position = Vector2(floorf((vp.x - _entry.size.x) * .5), floorf(vp.y * .3))
	if _gift.visible:
		if _g_t >= 0.0 and gift_freeze < 0.0:
			_g_t += delta
		elif gift_freeze >= 0.0:
			_g_t = gift_freeze
		var a := clampf((_g_t - G_CARD) / .5, 0.0, 1.0)
		_gift.modulate.a = a
		_gift.mouse_filter = Control.MOUSE_FILTER_STOP if a > .5 else Control.MOUSE_FILTER_IGNORE
		var u := clampf((_g_t - G_FALL) / G_GROW, 0.0, 1.0)
		_pose_preview(1.0 - pow(1.0 - u * u * (3.0 - 2.0 * u), 1.7))
		_gift.reset_size()
		_gift.position = Vector2(floorf((vp.x - _gift.size.x) * .5), floorf((vp.y - _gift.size.y) * .5 + sin(_t * .9) * 3.0))
	if _dim.visible:
		_dim.queue_redraw()


func _dim_input(event: InputEvent) -> void:
	# a sötétítésre koppintva bezárul (a „Kaptál egy magot” csak a lehullás után)
	# (az érintésből a Godot egéreseményt is küld a felületnek: csak azt nézzük, hogy ne záródjon kétszer)
	if not (event is InputEventMouseButton and not event.pressed):
		return
	if _sheet.visible:
		close_sheet()
	elif _entry.visible:
		_entry.visible = false
		_after_close()
	elif _gift.visible and _g_t > G_FALL + .4:
		_gift_close(Callable())


func _draw_dim() -> void:
	var vp := get_viewport_rect().size
	var k := 1.0
	if _gift.visible and not _g_seed.is_empty():
		k = clampf(_g_t / .4, 0.0, 1.0)
	_dim.draw_rect(Rect2(Vector2.ZERO, vp), Color(.04, .02, .10, .62 * k))
	if not _gift.visible or _g_seed.is_empty() or _g_t > G_FALL + 1.0:
		return
	# a mag fényként hull a lap közepére (ahol a fa kinő), a végén fénygyűrű
	var to := _g_pic.get_global_rect().get_center() + Vector2(0, _g_pic.size.y * .3)
	if _g_pic.size.y < 2.0:
		to = vp * Vector2(.5, .45)
	var from := Vector2(vp.x * .5 + 40.0, -30.0)
	var u := clampf(_g_t / G_FALL, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 2.2)
	if u < 1.0:
		for i in 8:
			var ui := clampf(e - i * .035, 0.0, 1.0)
			var q := from.lerp(to, ui) + Vector2(sin(ui * 7.0) * 24.0 * (1.0 - ui), 0)
			var al := (1.0 if i == 0 else .45 * (1.0 - i / 8.0))
			var r := 7.0 if i == 0 else 4.0 - i * .35
			_dim.draw_circle(q, r * 3.2, Color(_g_col, .1 * al))
			_dim.draw_circle(q, r * 1.7, Color(_g_col, .3 * al))
			_dim.draw_circle(q, r, Color(SeedFx.C_SEED.lerp(Color.WHITE, .35), .95 * al))
	else:
		var v := clampf((_g_t - G_FALL) / 1.0, 0.0, 1.0)
		_dim.draw_arc(to, 14.0 + v * 120.0, 0, TAU, 64, Color(_g_col, .7 * (1.0 - v)), 3.0 * (1.0 - v) + 1.0, true)
		_dim.draw_circle(to, 10.0 * (1.0 - v), Color(SeedFx.C_SEED, .9 * (1.0 - v)))
