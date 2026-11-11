class_name Shaping
extends Node3D
## Alakítás (M8): metszés és kötözés leszállva a fánál. A szabályok a generátorban vannak (plant_gen.gd: az alakítási
## lista csak a kirajzolásnál hat, a váz és a véletlenszámok nem változnak); itt a felület, a látvány és a mentés.
##  - Belépés: a fa lebegő táblája alatt „Alakítás” (az „Elengedem…” mellett). Ilyenkor a koppintás nem öntöz és nem
##    szed magot, a hosszú nyomás nem enged el, és a kamera nem forog magától. Alul kis lap: tipp, „Levágom”,
##    „Visszavonom”, „Kész”. Kilépés: „Kész”, vagy koppintás a fa mellé (az égre, a földre).
##  - Ágra koppintás: kiemeli (halvány, lüktető fényburok az ágon és mindenen, ami rajta nő). Már az ujj lenyomásakor
##    látszik, mit fogsz meg. Újabb koppintás ugyanarra az ágra (vagy „Levágom”): levágja – az ág a tövénél elválik,
##    kifelé dőlve lehull, a levelei szétszóródnak, és elhalványul (~2,4 mp).
##  - Húzás egy ágon: kötözés. Az ág tövétől nézve a fogás pontja az ujj felé fordul (legfeljebb 60°-kal); a cél a
##    mentésbe kerül, és az ág napok alatt hajlik arra (plant_gen.gd: BEND_DAYS). Amíg hajlik, kis fénylő zsinór köti a
##    célhoz (a zsinór napról napra rövidül). Ugyanazt az ágat újrakötve onnan hajlik tovább, ahol most tart.
##  - Visszavonás: a mai műveletek visszafelé visszavonhatók (kíméletes, büntetésmentes). A korábbi napokéi már a fa részei.
##  - A törzs (0. szint) nem vágható és nem köthető: rákoppintva egy halk tipp.
##  - Az alakítás nem öröklődik: az elengedett fa csillaga megőrzi a listát, de a magjából (visszahozás, gyűjtés,
##    keresztezés) kikelő fa üres listával, a nyers DNS-ből nő (state.gd: new_tree).
##
## A főjelenet (main.gd) tagjait használja, ezért a host típus nélküli: trees, focus, view, macro, cam, eye, game,
## saved_view, garden_mode, planet, fx, hatching, stars, system, herb, board, bag, crossing, touches, bench_on,
## retreating, s_dist, tag_alpha, _tag_text().

const GLOW := preload("res://shaders/branch_glow.gdshader")
## A zsinór mélységteszt nélkül: a lombon át is látszik (csak az elöl lévő, közeli fákon rajzoljuk).
const DOT := preload("res://shaders/glow_dot_top.gdshader")
const WOOD := preload("res://shaders/wood.gdshader")
const LEAF := preload("res://shaders/leaf.gdshader")
const FLOWER := preload("res://shaders/flower.gdshader")

const C_HI := Color(1.0, .86, .55)
const C_CORD := Color(1.0, .8, .5)
const C_CUT := Color(1.0, .78, .62)
const C_STAR := Color(1.0, .88, .6)
## A lehullás hossza (mp), a zsinór pontjai, egyszerre legfeljebb ennyi zsinór.
const FALL_LEN := 2.4
const CORD_DOTS := 14
const CORDS := 8
## A kötés pontja az ágon (a tövétől a hossz ekkora részénél).
const TIE_U := .72
## A legnagyobb fordulás egy húzással, és összesen (fok).
const MAX_DRAG := 60.0
const MAX_TOTAL := 85.0
## Ennyi képpont alatt a húzás még koppintás.
const DRAG_MIN := 18.0
const HINT_IDLE := "Koppints egy ágra: kiemelem. Húzd el az ágat: odakötöm, és pár nap alatt arra hajlik.\nA fa mellé koppintva kilépsz."
const HINT_SEL := "Kiemelve: ez az ág és ami rajta nő.\nKoppints rá még egyszer (vagy: Levágom). Húzd el: kötözés."
const HINT_TRUNK := "A törzset nem vágom le és nem kötöm – az ágait igen."

var host
## Be van-e kapcsolva az alakító mód.
var on := false
## A kiemelt ág (-1 = nincs).
var sel := -1
## A fa, amelyiken dolgozunk (a host.trees eleme).
var tree: Dictionary = {}
## Képernyőképhez: a lehullás ennél a pontnál áll (-1 = fut).
var freeze_at := -1.0
## A tábla alatti „Alakítás” gomb (a herbarium.gd helyezi el az „Elengedem…” mellé).
var btn: Button

## A fogás: {"index", "pos", "cur", "b", "at" (a fogás pontja a növény keretében), "u", "was_sel", "moved"}
var _grab := {}
var _hi := MeshInstance3D.new()
var _hi_mat := ShaderMaterial.new()
var _hi_b := -1
var _cords := MultiMeshInstance3D.new()
## A lehulló darabok: {"node", "mats", "t", "base", "pivot", "axis", "drop"}
var _falls: Array = []
var _layer := CanvasLayer.new()
var _panel := PanelContainer.new()
var _title := Label.new()
var _hint := Label.new()
var _cut_btn: Button
var _undo_btn: Button
var _note := ""
var _note_t := 0.0
## Még újraépítendő részletességi szintek: [fa, szint] (képkockánként egy).
var _queue: Array = []
static var _fall_shaders := {}


func _ready() -> void:
	_hi_mat.shader = GLOW
	_hi_mat.render_priority = 6
	_hi.material_override = _hi_mat
	_hi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hi.top_level = true
	_hi.visible = false
	add_child(_hi)
	_cords.multimesh = SeedFx._multimesh(SeedFx._quad(), CORDS * (CORD_DOTS + 2) + CORD_DOTS + 2, true)
	_cords.material_override = SeedFx._mat(DOT, 7)
	_cords.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cords.top_level = true
	_cords.visible = false
	add_child(_cords)
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	btn = BoardView.make_button(root, "Alakítás", start, C_HI)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(112, 36)
	btn.size = btn.custom_minimum_size
	btn.add_theme_font_size_override("font_size", 13)
	btn.focus_mode = Control.FOCUS_NONE
	btn.visible = false
	_panel.add_theme_stylebox_override("panel", BoardView.panel_style())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)
	BoardView._style_label(_title, 16, BoardView.C_TEXT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)
	BoardView._style_label(_hint, 12, BoardView.C_DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_cut_btn = BoardView.make_button(row, "Levágom", _on_cut_btn, C_CUT)
	_undo_btn = BoardView.make_button(row, "Visszavonom", undo, BoardView.C_DIM)
	BoardView.make_button(row, "Kész", stop, C_HI)
	for b in [_cut_btn, _undo_btn]:
		(b as Button).focus_mode = Control.FOCUS_NONE


# ---------------------------------------------------------------- Mód

func _on_cut_btn() -> void:
	if sel >= 0:
		cut(sel)


## Bekapcsolható-e most (leszállva egy fánál, nyugalomban, semmi más nincs nyitva).
func can_start() -> bool:
	return not on and _calm() and host.view == "surface" and host.focus >= 0 and not host.macro


func _calm() -> bool:
	return host.garden_mode == "planet" and not host.bench_on and not host.retreating and not host.fx.busy() \
		and not host.hatching.active() and not host.stars.busy() and not host.system.busy() and not host.herb.is_open() \
		and not host.board.visible and not host.bag.visible and not host.crossing.is_open()


func start() -> void:
	if not can_start():
		return
	on = true
	tree = host.trees[host.focus]
	sel = -1
	_grab = {}
	_note = ""
	_panel.visible = true
	_panel.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(_panel, "modulate:a", 1.0, .3)
	_sync_panel()


func stop() -> void:
	if not on:
		return
	on = false
	sel = -1
	_grab = {}
	_set_hi(-1)
	_panel.visible = false
	tree = {}
	if host.focus >= 0:
		host._tag_text()


## Bolygóváltáskor, újraépítéskor: minden leáll, a lehulló darabok eltűnnek.
func reset() -> void:
	on = false
	sel = -1
	_grab = {}
	tree = {}
	_set_hi(-1)
	_panel.visible = false
	for f in _falls:
		(f.node as Node3D).queue_free()
	_falls.clear()
	_queue.clear()
	_cords.visible = false


## A fa alakítási listája (mentett fánál a rekord "shaping" tömbje, a próba-bolygón a jelenet saját tömbje).
static func shape_of(t: Dictionary) -> Array:
	return t.get("shape", []) as Array


# ---------------------------------------------------------------- Érintés (a main.gd _planet_input hívja, ha on)

## Ujj le: ha egy ágon (a törzsön kívül), az ág kiemelődik, és a fogás az alakításé (true). Különben a világé.
func press(index: int, pos: Vector2) -> bool:
	if not _grab.is_empty():
		# második ujj: csípés lesz belőle, a fogás elengedi (az első ujj a kameráé lesz)
		host.touches[int(_grab.index)] = _grab.cur
		_grab = {}
		_set_hi(sel)
		return false
	# ha már egy másik ujj lent van (forgatás, csípés), az érintés a kameráé
	for k in host.touches:
		if int(k) != index:
			return false
	var hit := _pick(pos)
	if hit.is_empty() or not (_pg() as PlantGen).can_shape(int(hit.b)):
		return false
	var b := int(hit.b)
	_grab = {"index": index, "pos": pos, "cur": pos, "b": b, "at": hit.at, "u": hit.u, "was_sel": b == sel, "moved": false}
	_set_hi(b)
	return true


func drag(index: int, pos: Vector2) -> bool:
	if _grab.is_empty() or int(_grab.index) != index:
		return false
	_grab.cur = pos
	if pos.distance_to(_grab.pos) > DRAG_MIN:
		_grab.moved = true
	return true


func release(index: int, pos: Vector2) -> bool:
	if _grab.is_empty() or int(_grab.index) != index:
		return false
	var g := _grab
	_grab = {}
	var b := int(g.b)
	if bool(g.moved) or pos.distance_to(g.pos) > DRAG_MIN:
		tie(b, g.at, pos)
	elif bool(g.was_sel):
		cut(b)
	else:
		select(b)
	return true


## Koppintás a világra (az ágakra koppintást rendszerint a press/release kezeli): ágra kiemelés / levágás, a törzsre
## tipp, máshová (az égre, a földre) kilépés.
func tap(pos: Vector2) -> void:
	var hit := _pick(pos)
	if hit.is_empty():
		stop()
		return
	var b := int(hit.b)
	if not (_pg() as PlantGen).can_shape(b):
		select(-1)
		_set_note(HINT_TRUNK)
	elif b == sel:
		cut(b)
	else:
		select(b)


## A koppintáshoz legközelebbi ág a kiválasztott fán (nagy, ujjnyi találati sugárral).
func _pick(pos: Vector2) -> Dictionary:
	if tree.is_empty():
		return {}
	var cam: Camera3D = host.cam
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var px := vp.y * .5 / tan(deg_to_rad(cam.fov) * .5)
	return (_pg() as PlantGen).pick_branch(cam, _xf(), pos, maxf(48.0, vp.y * .06), px)


func _pg() -> PlantGen:
	return tree.high.pg


func _xf() -> Transform3D:
	return (tree.high.node as Node3D).transform


# ---------------------------------------------------------------- Műveletek

func select(b: int) -> void:
	sel = b
	_set_hi(b)
	_note = ""
	_sync_panel()


## Metszés: a lista végére, mentés, a fa újraépül (mindhárom szint), a levágott rész lehull.
func cut(b: int) -> void:
	var pg := _pg()
	if not pg.can_shape(b) or not pg.branch_live(b):
		return
	_spawn_fall(tree, b)
	var list := shape_of(tree)
	list.append({"op": PlantGen.OP_CUT, "branch": b, "day": GameState.today()})
	_save()
	rebuild(tree)
	var w := _xf() * pg.br_pts[pg.br_k0[b]]
	host.fx.burst(w, (_xf().basis * (pg.branch_point(b, .3) - pg.br_pts[pg.br_k0[b]])).normalized(), .7, C_CUT)
	sel = -1
	_set_hi(-1)
	_set_note("Levágtad. Ha meggondolod: Visszavonom (ma még lehet).")


## Kötözés: a fogás pontja (at, a növény keretében) az ujj felé fordul az ág tövétől nézve. A cél az ág eredeti
## keretében mentődik ("from" = ahol most tart, "to" = a cél), az ág napok alatt hajlik oda.
func tie(b: int, at: Vector3, finger: Vector2) -> void:
	var pg := _pg()
	if not pg.can_shape(b) or not pg.branch_live(b):
		return
	var xf := _xf()
	var cam: Camera3D = host.cam
	var gw := xf * at
	var plane := Plane(-cam.global_transform.basis.z, gw)
	var hitw: Variant = plane.intersects_ray(cam.project_ray_origin(finger), cam.project_ray_normal(finger))
	if hitw == null:
		return
	var f := xf.affine_inverse() * (hitw as Vector3)
	var o := pg.br_pts[pg.br_k0[b]]
	var v1 := (at - o).normalized()
	var v2 := (f - o).normalized()
	if v1.length() < .5 or v2.length() < .5 or v1.is_equal_approx(v2):
		return
	var q := Quaternion(v1, v2)
	var ang := q.get_angle()
	if ang > deg_to_rad(MAX_DRAG):
		q = Quaternion(q.get_axis().normalized(), deg_to_rad(MAX_DRAG))
	# a kirajzolt keretből (az ősök elfordulásával) az ág eredeti keretébe
	var anc := pg.ancestors_basis(b)
	var local := (anc.inverse() * Basis(q) * anc).get_rotation_quaternion()
	var list := shape_of(tree)
	var old := _tie_entry(list, b)
	var cur: Quaternion = PlantGen.tie_quat(old, GameState.today()) if not old.is_empty() else Quaternion.IDENTITY
	var to := (local * cur).normalized()
	if to.get_angle() > deg_to_rad(MAX_TOTAL):
		to = Quaternion(to.get_axis().normalized(), deg_to_rad(MAX_TOTAL))
	var e := {"op": PlantGen.OP_TIE, "branch": b, "day": GameState.today(), "from": PlantGen.quat_arr(cur), "to": PlantGen.quat_arr(to)}
	if not old.is_empty():
		# a régi kötés a visszavonáshoz megmarad (a mentésben is), a helyére az új kerül
		e.prev = old.duplicate(true)
		list.erase(old)
	list.append(e)
	_save()
	rebuild(tree)
	sel = b
	_set_hi(b)
	_set_note(("Újrakötötted: innen hajlik tovább az új irány felé." if not old.is_empty() else "Odakötötted.") +
		" Kb. %d nap alatt hajlik arra, addig a fénylő zsinór mutatja." % int(PlantGen.BEND_DAYS))


func _tie_entry(list: Array, b: int) -> Dictionary:
	for e in list:
		if e is Dictionary and str(e.get("op", "")) == PlantGen.OP_TIE and int(e.get("branch", -1)) == b:
			return e
	return {}


## A mai utolsó művelet visszavonása (újrakötésnél a régi kötés visszaáll).
func undo() -> void:
	if tree.is_empty():
		return
	var list := shape_of(tree)
	var today := GameState.today()
	for i in range(list.size() - 1, -1, -1):
		var e: Dictionary = list[i]
		if int(e.get("day", -1)) != today:
			continue
		list.remove_at(i)
		if e.get("prev") is Dictionary:
			list.append(e.prev)
		_save()
		rebuild(tree)
		tree.wave = 0.0
		sel = -1
		_set_hi(-1)
		_set_note("Visszavontam: %s." % ("a levágott ág visszanőtt" if str(e.op) == PlantGen.OP_CUT else "a kötés lekerült"))
		return


func _today_ops() -> int:
	var n := 0
	if tree.is_empty():
		return 0
	for e in shape_of(tree):
		if int((e as Dictionary).get("day", -1)) == GameState.today():
			n += 1
	return n


func _save() -> void:
	if host.saved_view and int(tree.get("sid", -1)) >= 0:
		host.game.save()


func _set_note(msg: String) -> void:
	_note = msg
	_note_t = 0.0
	_sync_panel()


func _sync_panel() -> void:
	if tree.is_empty():
		return
	_title.text = "Alakítás · %s" % Genes.latin_name((tree.g as Dictionary).dna)
	_hint.text = _note if _note != "" else (HINT_SEL if sel >= 0 else HINT_IDLE)
	_cut_btn.disabled = sel < 0
	_cut_btn.modulate.a = 1.0 if sel >= 0 else .4
	var n := _today_ops()
	_undo_btn.disabled = n == 0
	_undo_btn.modulate.a = 1.0 if n > 0 else .4


# ---------------------------------------------------------------- Újraépítés

## A fa mindhárom részletességi szintje újra a DNS-ből és a kódból, a mai alakítási listával (ugyanaz a váz).
## A csomópontok és az anyagok maradnak (a gondozás, a napszak, a növekedés beállításai megmaradnak). A részletes
## szint azonnal épül (azt látod, azon keres a koppintás), a másik kettő a következő képkockákban, egyenként – így weben
## sem akad meg egyszerre a kép.
func rebuild(t: Dictionary) -> void:
	_rebuild_lod(t, t.high)
	for rec in [t.low, t.far]:
		_queue = _queue.filter(func(x: Array) -> bool: return not is_same(x[1], rec))
		_queue.append([t, rec])
	t.shape_day = GameState.today()
	if t.has("care"):
		t.care.glint = Tending._glint_flower(t.high.pg, str((t.g as Dictionary).code))
		host.tending._flags(t)
	if is_same(t, tree) and _hi_b >= 0:
		var b := _hi_b
		_hi_b = -1
		_set_hi(b if (t.high.pg as PlantGen).branch_live(b) else -1)


func _rebuild_lod(t: Dictionary, rec: Dictionary) -> void:
	if not is_instance_valid(rec.node):
		return
	var pg := PlantGen.new()
	pg.build(t.g, float(rec.det))
	pg.apply_shaping(shape_of(t), GameState.today())
	for c in (rec.node as Node3D).get_children():
		if c is MultiMeshInstance3D:
			var sh: Shader = ((c as MultiMeshInstance3D).material_override as ShaderMaterial).shader
			(c as MultiMeshInstance3D).multimesh = pg.leaves_multimesh() if sh == LEAF else pg.flowers_multimesh()
		elif c is MeshInstance3D:
			(c as MeshInstance3D).mesh = pg.wood_mesh()
	rec.pg = pg


## Napváltáskor: a kötözött fák egy nappal tovább hajlanak (csak azok épülnek újra, ahol a hajlás még tart).
func on_new_day() -> void:
	var day := GameState.today()
	for t in host.trees:
		if int(t.get("shape_day", day)) == day:
			continue
		var moving := false
		for e in shape_of(t):
			if str((e as Dictionary).get("op", "")) == PlantGen.OP_TIE and not PlantGen.tie_done(e, int(t.shape_day)):
				moving = true
		if moving:
			rebuild(t)
		else:
			t.shape_day = day


## A lebegő tábla alakítás-sora (ha a fán hajlik valami): „kötözve · még kb. N napig hajlik”.
func tag_line(t: Dictionary) -> String:
	var left := 0
	var day := GameState.today()
	for e in shape_of(t):
		if str((e as Dictionary).get("op", "")) == PlantGen.OP_TIE and not PlantGen.tie_done(e, day):
			left = maxi(left, int(e.day) + int(PlantGen.BEND_DAYS) - day)
	if left > 0:
		return "kötözve · %s hajlik" % ("ma még" if left <= 1 else "még kb. %d napig" % left)
	return ""


# ---------------------------------------------------------------- Kiemelés

func _set_hi(b: int) -> void:
	if b == _hi_b:
		_hi.visible = b >= 0 and not tree.is_empty()
		return
	_hi_b = b
	if b < 0 or tree.is_empty():
		_hi.visible = false
		return
	_hi.mesh = (_pg() as PlantGen).subtree_wood_mesh(b)
	_hi.visible = true
	_sync_hi()


## A fényburok a fa részletes szintjének helyén, ugyanazokkal a shader-adatokkal (szél, növekedés, lekonyulás).
func _sync_hi() -> void:
	if not _hi.visible or tree.is_empty():
		return
	var rec: Dictionary = tree.high
	_hi.global_transform = (rec.node as Node3D).global_transform
	var wm: ShaderMaterial = rec.mats[0]
	for k in ["tree_xf", "tree_inv", "tree_scale", "max_path", "plant_h", "grow", "droop", "amp"]:
		var v: Variant = wm.get_shader_parameter(k)
		if v != null:
			_hi_mat.set_shader_parameter(k, v)
	_hi_mat.set_shader_parameter("shell", clampf(float(host.s_dist) * .0035, .012, .05))
	var pressed := not _grab.is_empty() and int(_grab.b) == _hi_b
	_hi_mat.set_shader_parameter("hi_amt", 1.35 if pressed else 1.0)


# ---------------------------------------------------------------- Lehullás

## A levágott ág (a levágás előtti növényből) külön darabként: a tövénél kifelé dől, lehull, a levelei szétszóródnak,
## és pontrácsosan elhalványul. Az anyagok a fa részletes szintjének másolatai, a FALL változatú shaderrel.
func _spawn_fall(t: Dictionary, b: int) -> void:
	var rec: Dictionary = t.high
	var pg: PlantGen = rec.pg
	var node := Node3D.new()
	node.top_level = true
	var mats: Array = []
	for c in (rec.node as Node3D).get_children():
		if not (c is GeometryInstance3D):
			continue
		var src: ShaderMaterial = (c as GeometryInstance3D).material_override
		var m := src.duplicate() as ShaderMaterial
		m.shader = fall_shader(src.shader)
		m.set_shader_parameter("amp", 0.0)
		m.set_shader_parameter("droop", 0.0)
		m.set_shader_parameter("wave", -1.0)
		var gi: GeometryInstance3D
		if c is MultiMeshInstance3D:
			var mm: MultiMesh = pg.subtree_leaves_multimesh(b) if src.shader == LEAF else pg.subtree_flowers_multimesh(b)
			if mm == null or not (c as Node3D).visible:
				continue
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			gi = mi
		else:
			var me := MeshInstance3D.new()
			me.mesh = pg.subtree_wood_mesh(b)
			gi = me
		gi.material_override = m
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(gi)
		mats.append(m)
	add_child(node)
	var o := pg.br_pts[pg.br_k0[b]]
	var tip := pg.branch_point(b, 1.0)
	var out := Vector3(tip.x - o.x, 0.0, tip.z - o.z)
	if out.length() < .01:
		out = Vector3(o.x, 0.0, o.z) if Vector2(o.x, o.z).length() > .01 else Vector3.RIGHT
	var axis := Vector3.UP.cross(out.normalized()).normalized()
	var base: Transform3D = (rec.node as Node3D).global_transform
	_falls.append({"node": node, "mats": mats, "t": freeze_at if freeze_at >= 0.0 else 0.0, "base": base, "pivot": o, "axis": axis,
		"drop": maxf(o.y - .05, 0.0)})
	_step_falls(0.0)


## A FALL változat: ugyanaz a shader, #define FALL-lal (pontrácsos áttűnés, a levelek szóródása).
static func fall_shader(src: Shader) -> Shader:
	if _fall_shaders.has(src):
		return _fall_shaders[src]
	var sh := Shader.new()
	sh.code = src.code.replace("shader_type spatial;", "shader_type spatial;\n#define FALL")
	_fall_shaders[src] = sh
	return sh


func _step_falls(delta: float) -> void:
	for i in range(_falls.size() - 1, -1, -1):
		var f: Dictionary = _falls[i]
		if freeze_at < 0.0:
			f.t = float(f.t) + delta
		var u := clampf(float(f.t) / FALL_LEN, 0.0, 1.0)
		# előbb csak elválik és megbillen, aztán gyorsulva dől és hull
		var tilt := 1.25 * Tending._smooth(u / .8) + .08 * Tending._smooth(u / .12)
		var drop := float(f.drop) * u * u
		var o: Vector3 = f.pivot
		var bs := Basis(f.axis as Vector3, tilt)
		var local := Transform3D(bs, o - bs * o + Vector3.DOWN * drop)
		(f.node as Node3D).global_transform = (f.base as Transform3D) * local
		var fade := 1.0 - Tending._smooth((u - .5) / .5)
		for m in f.mats:
			(m as ShaderMaterial).set_shader_parameter("fall_fade", fade)
			(m as ShaderMaterial).set_shader_parameter("fall_t", u)
		if u >= 1.0 and freeze_at < 0.0:
			(f.node as Node3D).queue_free()
			_falls.remove_at(i)


# ---------------------------------------------------------------- Zsinór

## Fénylő zsinór a kötözött ágaktól a céljukig (ameddig hajlanak), és húzás közben a fogástól az ujjig.
func _update_cords() -> void:
	var mm := _cords.multimesh
	var n := 0
	var day := GameState.today()
	var calm: bool = _calm() and host.garden_mode == "planet"
	if calm:
		if not _grab.is_empty() and bool(_grab.moved) and not tree.is_empty():
			var xf := _xf()
			var cam: Camera3D = host.cam
			var gw: Vector3 = xf * (_grab.at as Vector3)
			var plane := Plane(-cam.global_transform.basis.z, gw)
			var hw: Variant = plane.intersects_ray(cam.project_ray_origin(_grab.cur), cam.project_ray_normal(_grab.cur))
			if hw != null:
				n = _cord(mm, n, gw, hw as Vector3, 1.0, (tree.dir as Vector3))
		var count := 0
		for t in host.trees:
			if count >= CORDS:
				break
			if not bool(t.get("shown", true)) or not bool(t.get("front", true)) or int(t.get("lod", 2)) > 1:
				continue
			var pg: PlantGen = t.high.pg
			var xf: Transform3D = (t.high.node as Node3D).transform
			for e in shape_of(t):
				if count >= CORDS:
					break
				if str((e as Dictionary).get("op", "")) != PlantGen.OP_TIE or PlantGen.tie_done(e, day):
					continue
				var b := int(e.branch)
				if b >= pg.branch_count() or not pg.branch_live(b):
					continue
				var a := xf * pg.branch_point(b, TIE_U)
				var z := xf * pg.tie_target(b, e, TIE_U)
				if a.distance_to(z) < .03:
					continue
				n = _cord(mm, n, a, z, .8, (t.dir as Vector3))
				count += 1
	mm.visible_instance_count = n
	_cords.visible = n > 0


## Egy zsinór pontjai (kicsit belóg, a két végén fénycsomó). Visszaadja a következő szabad példány sorszámát.
func _cord(mm: MultiMesh, n: int, a: Vector3, z: Vector3, k: float, up: Vector3) -> int:
	if n + CORD_DOTS + 2 > mm.instance_count:
		return n
	var l := a.distance_to(z)
	var sag := up * (-.12 * l)
	for i in CORD_DOTS:
		var u := (float(i) + .5) / CORD_DOTS
		var p := a.lerp(z, u) + sag * (4.0 * u * (1.0 - u))
		mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * .085), p))
		mm.set_instance_color(n, Color(C_CORD, 1.1 * k))
		mm.set_instance_custom_data(n, Color(fmod(u * 2.0, 1.0), 0, .25, 0))
		n += 1
	for e in [[a, .2, C_HI], [z, .26, C_STAR]]:
		mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * float(e[1])), e[0] as Vector3))
		mm.set_instance_color(n, Color(e[2] as Color, 1.3 * k))
		mm.set_instance_custom_data(n, Color(.3, 0, .35, 0))
		n += 1
	return n


# ---------------------------------------------------------------- Képkockánként

func _process(delta: float) -> void:
	if host == null:
		return
	if on:
		# más nézet, másik fa, nyitott lap: a mód csendben kikapcsol
		if not _calm() or host.view != "surface" or host.focus < 0 or host.macro or not is_same(host.trees[host.focus], tree):
			stop()
	if on:
		var vp := get_viewport().get_visible_rect().size
		var w := minf(vp.x - 16.0, 420.0)
		_hint.custom_minimum_size = Vector2(w - 24.0, 0)
		_panel.reset_size()
		_panel.position = Vector2(floorf((vp.x - _panel.size.x) * .5), floorf(vp.y - _panel.size.y - 16.0))
		if _note != "":
			_note_t += delta
			if _note_t > 6.0:
				_note = ""
				_sync_panel()
		_sync_hi()
	if not _queue.is_empty():
		var q: Array = _queue.pop_front()
		_rebuild_lod(q[0], q[1])
	_step_falls(delta)
	_update_cords()


# ---------------------------------------------------------------- Önellenőrzés (--shapetest)

## Az M8 előtti generátor lenyomatai (üres alakítási listával a kimenetnek bitre ugyanennek kell lennie).
## Kulcs: kód, részletesség; a DNS a kód sorszámából (lásd _test_dna).
const BASELINE := {
	"proba-0 1.00": "23ed75e4ff3cc0c4", "proba-0 0.22": "b3671f78eb443846", "proba-0 0.09": "3a8118bf1117b58c",
	"proba-3 1.00": "0da00a620fba3bd3", "proba-3 0.22": "5667a85790b0168b", "proba-3 0.09": "6cf4b5cad5889795",
	"proba-6 1.00": "527ab21946f72491", "proba-6 0.22": "fe451f90868581c4", "proba-6 0.09": "84bd7cb014df0c98",
	"proba-9 1.00": "903814c2297ccb30", "proba-9 0.22": "6ab5e5e5f163b2e3", "proba-9 0.09": "19045b56c8fa4b9f",
	"proba-12 1.00": "a2a9e573123bbcab", "proba-12 0.22": "29978e17d13cf568", "proba-12 0.09": "fa0a6d3612d54447",
	"proba-13 1.00": "1019d3ad31caf25a", "proba-13 0.22": "78ff8accc74952f8", "proba-13 0.09": "989cddbaeb69f80b",
}


static func _test_dna(k: int) -> Array:
	return [k, (k * 5 + 3) % 14, (k * 3 + 1) % 14, k, (k * 7 + 2) % 14, (k * 11 + 4) % 14]


static func _built(g: Dictionary, det: float, list: Array, day: int) -> PlantGen:
	var pg := PlantGen.new()
	pg.build(g, det)
	pg.apply_shaping(list, day)
	return pg


## Egy alkalmas próba-ág: 1. szintű, legalább 3 ágnyi leszármazottal és levelekkel.
static func test_branch(pg: PlantGen) -> int:
	var best := -1
	var best_n := 0
	for b in pg.branch_count():
		if pg.br_level[b] != 1:
			continue
		var nsub := pg.br_end[b] - b + 1
		if nsub >= 3 and nsub > best_n and pg._sub_end(pg.br_l0, pg.leaf_p.size(), b) > pg.br_l0[b]:
			best = b
			best_n = nsub
	return best


## Önellenőrzés: üres lista = régi kimenet; levágás és kötözés csak az ágat (és leszármazottait) érinti; a három
## részletességi szint váza azonos; determinizmus; a kötözés napról napra hajlik; az alakítás nem öröklődik.
static func self_test() -> String:
	var out: Array = []
	var fails := 0
	# 1. üres lista: bitre ugyanaz, mint az M8 előtt
	var same := 0
	for key in BASELINE:
		var code := str(key).get_slice(" ", 0)
		var det := float(str(key).get_slice(" ", 1))
		var g := Genes.from_dna(_test_dna(int(code.trim_prefix("proba-"))), code)
		var pg := _built(g, det, [], 0)
		var d := pg.digest()
		if d == BASELINE[key]:
			same += 1
		else:
			fails += 1
			out.append("HIBA: %s lenyomata %s (várt %s)" % [key, d, BASELINE[key]])
	out.append("üres lista = M8 előtti kimenet: %d/%d" % [same, BASELINE.size()])
	var day := 1000
	for k in [0, 3, 6, 9, 12]:
		var code := "proba-%d" % k
		var g := Genes.from_dna(_test_dna(k), code)
		var raw := _built(g, 1.0, [], day)
		var b := test_branch(raw)
		if b < 0:
			out.append("%s: nincs alkalmas ág" % code)
			continue
		var e1 := raw.br_end[b]
		# 2. levágás: a többi ág váza, csúcsai, levelei, virágai változatlanok; a levágott rész nem rajzolódik
		var t0 := Time.get_ticks_usec()
		var cutl := [{"op": PlantGen.OP_CUT, "branch": b, "day": day}]
		var cut := _built(g, 1.0, cutl, day)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var moved := _moved_outside(raw, cut, b, e1)
		var tris_raw := raw.idx.size() / 3
		var tris_cut := cut.idx_draw.size() / 3
		var leaves_cut := 0
		for i in cut.leaf_cut.size():
			leaves_cut += cut.leaf_cut[i]
		var lbuf_ok := _buf_same_outside(raw.leaves_multimesh().buffer, cut.leaves_multimesh().buffer, raw.br_l0[b], raw._sub_end(raw.br_l0, raw.leaf_p.size(), b))
		var fbuf_ok := _buf_same_outside(raw.flowers_multimesh().buffer, cut.flowers_multimesh().buffer, raw.br_f0[b], raw._sub_end(raw.br_f0, raw.flo_p.size(), b))
		var ok_cut := moved == 0 and lbuf_ok and fbuf_ok and tris_cut < tris_raw and leaves_cut > 0
		if not ok_cut:
			fails += 1
		out.append("%s levágás: %d. ág (%d ág, %d levél le), háromszög %d → %d, máshol elmozdult %d, levél/virág-puffer máshol azonos: %s/%s, %.1f ms %s" % [
			code, b, e1 - b + 1, leaves_cut, tris_raw, tris_cut, moved, lbuf_ok, fbuf_ok, ms, "OK" if ok_cut else "HIBA"])
		# 3. kötözés: 0/3/7 nap; a tő helyben marad, a csúcs fokozatosan fordul, a többi ág nem mozdul
		var q := Quaternion(Vector3(0, 0, 1), deg_to_rad(40.0))
		var tiel := [{"op": PlantGen.OP_TIE, "branch": b, "day": day, "from": PlantGen.quat_arr(Quaternion.IDENTITY), "to": PlantGen.quat_arr(q)}]
		var angs: Array = []
		var ok_tie := true
		for dd in [0, 3, 7]:
			var tp := _built(g, 1.0, tiel, day + dd)
			var o0 := raw.br_pts[raw.br_k0[b]]
			var tip0 := raw.branch_point(b, 1.0) - o0
			var tip1 := tp.branch_point(b, 1.0) - tp.br_pts[tp.br_k0[b]]
			angs.append(rad_to_deg(tip0.angle_to(tip1)))
			if not tp.br_pts[tp.br_k0[b]].is_equal_approx(o0) or _moved_outside(raw, tp, b, e1) > 0:
				ok_tie = false
		# 7 nap után pontosan a cél: a csúcs a tövénél 40°-kal elfordítva
		var tip_goal := Basis(q) * (raw.branch_point(b, 1.0) - raw.br_pts[raw.br_k0[b]])
		var full := rad_to_deg((raw.branch_point(b, 1.0) - raw.br_pts[raw.br_k0[b]]).angle_to(tip_goal))
		ok_tie = ok_tie and float(angs[0]) > .5 and float(angs[1]) > float(angs[0]) and float(angs[2]) > float(angs[1]) and absf(float(angs[2]) - full) < .05
		if not ok_tie:
			fails += 1
		out.append("%s kötözés (40° a z körül): 0/3/7 nap → %.1f° / %.1f° / %.1f° (cél %.1f°), a tő és a többi ág helyben: %s" % [code, angs[0], angs[1], angs[2], full, "OK" if ok_tie else "HIBA"])
		# 4. a három részletességi szint: ugyanaz a váz (levágással és kötözéssel együtt); 5. determinizmus
		var both: Array = []
		var sub := -1
		for c in range(b + 1, e1 + 1):
			if raw.br_level[c] == 2:
				sub = c
				break
		both = tiel.duplicate(true)
		if sub >= 0:
			both.append({"op": PlantGen.OP_CUT, "branch": sub, "day": day})
		var other := -1
		for c in raw.branch_count():
			if raw.br_level[c] == 1 and c != b:
				other = c
		if other >= 0:
			both.append({"op": PlantGen.OP_CUT, "branch": other, "day": day})
		var hi := _built(g, 1.0, both, day + 2)
		var ok_lod := true
		for det in [.22, .09]:
			var lp := _built(g, det, both, day + 2)
			if lp.br_pts != hi.br_pts or lp.cut_b != hi.cut_b:
				ok_lod = false
		var again := _built(g, 1.0, both, day + 2)
		var ok_det := again.digest() == hi.digest()
		if not ok_lod or not ok_det:
			fails += 1
		out.append("%s három szint azonos váza (kötés + 2 levágás): %s, determinisztikus: %s" % [code, "OK" if ok_lod else "HIBA", "OK" if ok_det else "HIBA"])
	# 6. az alakítás nem öröklődik (elengedés → csillag megőrzi; visszahozás / gyűjtés → elvetés: üres lista)
	var gs := GameState.new()
	gs.persist = false
	gs.path = ""
	gs.new_game("TESZT8")
	var p := gs.active_planet()
	var t: Dictionary = p.trees[0]
	t.shaping.append({"op": PlantGen.OP_CUT, "branch": 3, "day": GameState.today()})
	var t2: Dictionary = p.trees[1]
	t2.shaping.append({"op": PlantGen.OP_CUT, "branch": 4, "day": GameState.today()})
	var gseed := gs._seed_of(t2)
	var st := gs.release_tree(p, t)
	var rseed := gs.recall_star(p, int(st.id))
	var n1 := gs.sow_seed(rseed)
	var n2 := gs.sow_seed(gseed)
	var ok_inh := (st.shaping as Array).size() == 1 and (n1.shaping as Array).is_empty() and (n2.shaping as Array).is_empty() and str(n1.code) == str(t.code)
	if not ok_inh:
		fails += 1
	out.append("öröklés: a csillag megőrzi (%d), a visszahozott és a gyűjtött magból kikelő fa üres listával: %s" % [(st.shaping as Array).size(), "OK" if ok_inh else "HIBA"])
	out.append("ÖSSZESEN: %s" % ("minden rendben" if fails == 0 else "%d hiba" % fails))
	return "\n".join(out)


## Hány vázpont / csúcs mozdult el az ág (b … e1) tartományán kívül.
static func _moved_outside(a: PlantGen, b2: PlantGen, b: int, e1: int) -> int:
	var moved := 0
	var k0 := a.br_k0[b]
	var k1 := a._sub_end(a.br_k0, a.br_pts.size(), b)
	for i in a.br_pts.size():
		if (i < k0 or i >= k1) and a.br_pts[i] != b2.br_pts[i]:
			moved += 1
	var v0 := a.br_v0[b]
	var v1 := a._sub_end(a.br_v0, a.n, b)
	for i in a.pos.size():
		if (i < v0 or i >= v1) and a.pos[i] != b2.pos[i]:
			moved += 1
	return moved


static func _buf_same_outside(x: PackedFloat32Array, y: PackedFloat32Array, i0: int, i1: int) -> bool:
	if x.size() != y.size():
		return false
	return x.slice(0, i0 * 16) == y.slice(0, i0 * 16) and x.slice(i1 * 16) == y.slice(i1 * 16)
