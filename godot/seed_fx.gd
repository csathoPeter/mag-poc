class_name SeedFx
extends Node3D
## „A nagy pillanat” látványa (a Three.js-prototípus kettős spirálja Godotban):
##  - play_helix(): a kész DNS-tábla mezői bázispárokká válnak, kettős spirállá csavarodnak, maggá húzódnak,
##    és a mag a táskába repül (a táska gombja felé). A kamera előtt lebeg, a világ fölött (mélységteszt nélkül).
##  - play_sow(): elvetéskor a mag fénypontként, lágyan himbálózva a bolygó egy pontjára ereszkedik; földet érve
##    fénygyűrű fut szét, és egy rövid, lebegő felirat jelenik meg.
##  - burst(): fénygyűrű egy pontban (a kikeléskor is ezt használjuk).
## Olcsó: két MultiMesh (≈215 fénylő pont, 36 pálca), önvilágító pasztell színek, additív haló; valódi bloom nincs.
## Minden mozgás csillapított (smoothstep), semmi nem ugrik. Koppintás: skip() – először gyorsít, másodszor a végére ugrik.

## A spirál véget ért (a mag a táskában).
signal helix_done
## Az elvetett mag földet ért (ekkor jelenik meg a jele a bolygón).
signal sow_landed

const DOT := preload("res://shaders/glow_dot.gdshader")
const DOT_TOP := preload("res://shaders/glow_dot_top.gdshader")
const BAR := preload("res://shaders/glow_bar.gdshader")
const VEIL := preload("res://shaders/veil.gdshader")

## A mag színe (meleg arany, mint a prototípusban); a jel a bolygón is ilyen.
const C_SEED := Color(1.0, .84, .52)
const C_BEAD := Color(.96, .93, 1.0)

## A kettős spirál idővonala (másodperc): csavarodás, pörgés, összehúzódás maggá, a mag a táskába repül.
const H_MORPH := 1.05
const H_COLLAPSE := 2.05
const H_COLLAPSE_LEN := .8
const H_FLY := 3.0
const H_LEN := 3.85
## Elvetés: a kamera odafordul (0 – S_FALL), a mag leereszkedik (– S_LAND), fénygyűrű és felirat.
const S_FALL := .9
const S_LAND := 3.6
const S_BUSY := 4.6
const S_LEN := 8.0
## A spirál a kamera előtt ekkora távolságban lebeg (a képernyő-koordinátákból ide vetítjük).
const DEPTH := 4.0
## A gerincen két golyó között ennyi apró fénypont rajzolja ki a szálat.
const STRAND_SUB := 2
const N := 36
## A pontok sorrendje a MultiMesh-ben: golyók (2×36), a szálak pontjai, a mag, a mag aurája.
const I_STRAND := N * 2
const I_SEED := I_STRAND + 2 * (N - 1) * STRAND_SUB
const I_AURA := I_SEED + 1
const DOTS := I_AURA + 1
## A világban: a hulló mag, a csóvája, a fénygyűrű.
const TRAIL := 8
const W_RING := TRAIL + 1
const W_DOTS := W_RING + 1

var cam: Camera3D
## "" = nyugalom, "helix" = kettős spirál, "sow" = elvetés.
var mode := ""
var t := 0.0
var speed := 1.0
## Képernyőképhez: az idő áll (a --shot egy adott pillanatot fényképez).
var frozen := false

var _rig := Node3D.new()
var _dots := MultiMeshInstance3D.new()
var _bars := MultiMeshInstance3D.new()
var _veil := MeshInstance3D.new()
var _veil_mat := ShaderMaterial.new()
var _cells: Array = []
var _vals: Array = []
var _cell_px := 40.0
var _to_px := Vector2.ZERO

var _wdots := MultiMeshInstance3D.new()
var _caption := Label3D.new()
var _p := Vector3.ZERO
var _n := Vector3.UP
var _side := Vector3.RIGHT
var _start := Vector3.ZERO
var _has_start := false
var _landed := false
var _ring_t := -1.0
var _ring_p := Vector3.ZERO
var _ring_n := Vector3.UP
var _ring_size := 2.4
var _ring_col := C_SEED
## A spirálból húzódó mag színe: ritka napon (a nap magja ritka módosítást kapott) gyöngyházfehér – az egyetlen
## előjel; hogy mi az, csak kikeléskor derül ki.
const C_SEED_RARE := Color(.86, .92, 1.0)
var _seed_col := C_SEED


func _ready() -> void:
	add_child(_rig)
	_rig.top_level = true
	_rig.visible = false
	# a fátyol a lencse után, a spirál előtt rajzolódik (render_priority), a teljes képet fedi
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	_veil.mesh = q
	_veil_mat.shader = VEIL
	_veil_mat.render_priority = 5
	_veil.material_override = _veil_mat
	_veil.extra_cull_margin = 16384.0
	_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rig.add_child(_veil)
	_dots.multimesh = _multimesh(_quad(), DOTS, true)
	_dots.material_override = _mat(DOT_TOP, 10)
	_rig.add_child(_dots)
	var cyl := CylinderMesh.new()
	cyl.top_radius = .5
	cyl.bottom_radius = .5
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	_bars.multimesh = _multimesh(cyl, N, false)
	_bars.material_override = _mat(BAR, 9)
	_rig.add_child(_bars)
	for mi in [_dots, _bars]:
		(mi as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a világban: a hulló mag és a fénygyűrű (mélységteszttel, a bolygó eltakarja a túloldalt)
	add_child(_wdots)
	_wdots.top_level = true
	_wdots.visible = false
	_wdots.multimesh = _multimesh(_quad(), W_DOTS, true)
	var wm := _mat(DOT, 8)
	wm.set_shader_parameter("min_ang", .012)
	_wdots.material_override = wm
	_wdots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_caption.font_size = 40
	_caption.outline_size = 12
	_caption.no_depth_test = true
	_caption.render_priority = 12
	_caption.outline_render_priority = 11
	_caption.shaded = false
	_caption.width = 640.0
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.top_level = true
	_caption.visible = false
	add_child(_caption)


static func _quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	return q


static func _multimesh(mesh: Mesh, count: int, custom: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	# a pontok a shaderben nőnek ki a négyszögből: a befoglaló doboz legyen bőven nagy
	mm.custom_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))
	for i in count:
		mm.set_instance_color(i, Color(0, 0, 0, 0))
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * .001), Vector3.ZERO))
	return mm


static func _mat(shader: Shader, prio: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.render_priority = prio
	return m


## Fut-e valami, ami alatt a világ ne reagáljon (a koppintás ilyenkor gyorsít / átugrik).
func busy() -> bool:
	return mode == "helix" or (mode == "sow" and t < S_BUSY)


## Koppintás: először felgyorsít, másodszor a végére ugrik (a spirálnál a táskába, elvetésnél a földet érésig).
func skip() -> void:
	if frozen or not busy():
		return
	if speed < 2.0:
		speed = 3.5
		return
	if mode == "helix":
		t = H_LEN
	elif t < S_LAND:
		t = S_LAND


## Minden leáll és eltűnik (pl. bolygóváltáskor).
func cancel() -> void:
	mode = ""
	frozen = false
	_rig.visible = false
	_wdots.visible = false
	_caption.visible = false
	_ring_t = -1.0


## A spirál indítása. cells: a 36 mező közepe képernyő-koordinátában (sorfolytonosan), vals: a bázispárok
## (0 = A=T, 1 = G≡C), cell_px: egy mező mérete, to_px: ahová a mag repül (a táska gombja).
func play_helix(cells: Array, vals: Array, cell_px: float, to_px: Vector2, rare := false) -> void:
	_seed_col = C_SEED_RARE if rare else C_SEED
	_cells = cells
	_vals = vals
	_cell_px = cell_px
	_to_px = to_px
	var mm := _bars.multimesh
	for k in N:
		mm.set_instance_color(k, BoardView.C_AT if int(vals[k]) == 0 else BoardView.C_GC)
	mode = "helix"
	t = 0.0
	speed = 1.0
	frozen = false
	_rig.visible = true
	Sound.fx("helix")
	_update(0.0)


## Elvetés: a mag a kamera elől lágyan a bolygó p pontjára (n: a felszín iránya) ereszkedik.
func play_sow(p: Vector3, n: Vector3, caption: String) -> void:
	_p = p
	_n = n.normalized()
	_side = cam.global_transform.basis.x
	_has_start = false
	_landed = false
	_caption.text = caption
	mode = "sow"
	# a mag a kamera fordulása után kezd ereszkedni
	Sound.fx("fall", 1.0, 0.0, S_FALL - .1)
	t = 0.0
	speed = 1.0
	frozen = false
	_wdots.visible = true
	_update(0.0)


## Fénygyűrű egy pontban, kissé a felszín (n) fölött; a kikeléskor és öntözéskor (vízszínnel) is.
func burst(p: Vector3, n: Vector3, size := 2.4, col := C_SEED) -> void:
	_ring_t = 0.0
	_ring_col = col
	_ring_p = p
	_ring_n = n.normalized()
	_ring_size = size
	_wdots.visible = true


## Képernyőképhez: az idővonal egy pontja (másodpercben), utána áll.
func freeze(at: float) -> void:
	t = at
	frozen = true
	_update(0.0)


func _process(delta: float) -> void:
	_update(0.0 if frozen else delta)
	# a fénygyűrű a valódi idővel fut (képernyőképnél is lefut, nem marad a földet érés pillanatában)
	if _ring_t >= 0.0:
		_ring_t += delta
		_ring()


func _update(delta: float) -> void:
	if cam == null:
		return
	if mode == "helix":
		t += delta * speed
		_helix()
		if t >= H_LEN:
			mode = ""
			_rig.visible = false
			Sound.fx("bag")
			helix_done.emit()
	elif mode == "sow":
		t += delta * speed
		if t >= S_LAND and not _landed:
			_landed = true
			speed = 1.0
			burst(_p + _n * .08, _n)
			Sound.fx("land")
			sow_landed.emit()
		_sow()
		if t >= S_LEN:
			mode = ""
			_caption.visible = false


static func _smooth(x: float) -> float:
	var v := clampf(x, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


# ---------------------------------------------------------------- Kettős spirál (kamera-térben)

func _helix() -> void:
	_rig.global_transform = cam.global_transform
	var vp := get_viewport().get_visible_rect().size
	var view_h := 2.0 * DEPTH * tan(deg_to_rad(cam.fov) * .5)
	var per_px := view_h / vp.y
	var cell := _cell_px * per_px
	var morph := _smooth(t / H_MORPH)
	var collapse := _smooth((t - H_COLLAPSE) / H_COLLAPSE_LEN)
	var fly := _smooth((t - H_FLY) / (H_LEN - H_FLY))
	# a pörgés lassan indul és összehúzódáskor felgyorsul, mint egy felcsavarodó rugó
	var spin := t * 2.1 + collapse * 2.5
	var hs := view_h * .56 / 35.0
	var rr := minf(view_h * .075, view_h * vp.x / vp.y * .2)
	var center := Vector3(0, view_h * .04, -DEPTH)
	var mm := _dots.multimesh
	var bm := _bars.multimesh
	var a_pts: Array = []
	var b_pts: Array = []
	for k in N:
		var gp := _to_local(_cells[k], per_px, vp)
		var ga := gp - Vector3(cell * .3, 0, 0)
		var gb := gp + Vector3(cell * .3, 0, 0)
		var hc := _helix_point(float(k), center, hs, rr, spin)
		var off := hc[1] as Vector3
		var a := ga.lerp(hc[0] + off, morph).lerp(center, collapse)
		var b := gb.lerp(hc[0] - off, morph).lerp(center, collapse)
		a_pts.append(a)
		b_pts.append(b)
		var fade := 1.0 - collapse * collapse
		var br := cell * (.42 - .14 * morph) * (1.0 - collapse * .5)
		mm.set_instance_transform(k * 2, Transform3D(Basis.from_scale(Vector3.ONE * br), a))
		mm.set_instance_transform(k * 2 + 1, Transform3D(Basis.from_scale(Vector3.ONE * br), b))
		var bead := Color(C_BEAD, .95 * fade)
		mm.set_instance_color(k * 2, bead)
		mm.set_instance_color(k * 2 + 1, bead)
		# a bázispár kötése: pálca A-tól B-ig, a mező színével
		var d := b - a
		var len := maxf(d.length(), .0001)
		var y := d / len
		var x := y.cross(Vector3.FORWARD if absf(y.z) < .9 else Vector3.UP).normalized()
		var z := x.cross(y)
		var w := cell * .085 * (1.0 - collapse * .6)
		bm.set_instance_transform(k, Transform3D(Basis(x * w, y * len, z * w), (a + b) * .5))
		var c: Color = BoardView.C_AT if int(_vals[k]) == 0 else BoardView.C_GC
		bm.set_instance_color(k, Color(c, (.75 + .25 * morph) * fade))
	# a két gerinc: a golyók között apró pontok; a rácson még nem látszanak, a spirálban rajzolják ki a szálat
	var i := I_STRAND
	for k in N - 1:
		var ga0 := _to_local(_cells[k], per_px, vp)
		var ga1 := _to_local(_cells[k + 1], per_px, vp)
		for j in STRAND_SUB:
			var f := float(j + 1) / float(STRAND_SUB + 1)
			var hc := _helix_point(float(k) + f, center, hs, rr, spin)
			var g := ga0.lerp(ga1, f)
			for side in 2:
				var sgn := 1.0 if side == 0 else -1.0
				var gx := g + Vector3(cell * .3 * -sgn, 0, 0)
				var p := gx.lerp(hc[0] + (hc[1] as Vector3) * sgn, morph).lerp(center, collapse)
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * cell * .17), p))
				mm.set_instance_color(i, Color(C_BEAD, .75 * morph * (1.0 - collapse)))
				i += 1
	# a mag: az összehúzódással megjelenik, lüktet, aztán ívben a táskába repül és összemegy
	var to := _to_local(_to_px, per_px, vp)
	var seed := center.lerp(to, fly) + Vector3(0, sin(fly * PI) * view_h * .07, 0)
	var ss := cell * (.15 + 1.1 * collapse) * (1.0 - fly * .7)
	mm.set_instance_transform(I_SEED, Transform3D(Basis.from_scale(Vector3.ONE * ss), seed))
	mm.set_instance_color(I_SEED, Color(_seed_col, 1.6 * collapse))
	mm.set_instance_custom_data(I_SEED, Color(0, 0, .08 * collapse * (1.0 - fly), 0))
	mm.set_instance_transform(I_AURA, Transform3D(Basis.from_scale(Vector3.ONE * cell * 4.5 * collapse * (1.0 - fly * .8)), seed))
	mm.set_instance_color(I_AURA, Color(_seed_col, .38 * collapse * (1.0 - fly)))
	# a fátyol a tábla mögötti ködből folytatódik, és a mag elrepülésével feloszlik
	_veil_mat.set_shader_parameter("amount", lerpf(.86, .93, morph) * (1.0 - fly))


## A spirál k-adik lépcsője: a tengely pontja és a szál kitérése (a két szál ±).
func _helix_point(k: float, center: Vector3, hs: float, rr: float, spin: float) -> Array:
	var th := k * .62 + spin
	return [center + Vector3(0, (17.5 - k) * hs, 0), Vector3(cos(th), 0, sin(th)) * rr]


## Képernyő-pont a kamera előtt DEPTH távolságban (kamera-térben).
static func _to_local(px: Vector2, per_px: float, vp: Vector2) -> Vector3:
	return Vector3((px.x - vp.x * .5) * per_px, (vp.y * .5 - px.y) * per_px, -DEPTH)


# ---------------------------------------------------------------- Elvetés (a világban)

func _sow() -> void:
	var mm := _wdots.multimesh
	if frozen:
		# képernyőképnél a kamera csak a fagyasztás után áll be: a kiindulópontot mindig az aktuálishoz számoljuk
		_has_start = false
	if t >= S_FALL and not _has_start:
		# a kiindulópont a kép felső része, a cél fölött: onnan ereszkedik le a mag
		var xf := cam.global_transform
		# (a gombsor ilyenkor rejtve van, a kép teteje szabad); közelebb a kamerához, így messziről érkezik
		var d := xf.origin.distance_to(_p)
		var half := tan(deg_to_rad(cam.fov) * .5) * d * .5
		_start = xf.origin - xf.basis.z * d * .5 + xf.basis.y * half * .72 + xf.basis.x * half * .12
		_has_start = true
	var u := clampf((t - S_FALL) / (S_LAND - S_FALL), 0.0, 1.0)
	var vis := 1.0 if _has_start else 0.0
	for i in TRAIL:
		var ui := u - float(i) * .028
		var a := vis * (smoothstep(0.0, .12, ui) if i == 0 else .5 * (1.0 - float(i) / TRAIL) * smoothstep(0.0, .1, ui))
		if _landed:
			# földet érve a mag beleolvad a jelébe
			a *= 1.0 - _smooth((t - S_LAND) / .6)
		var p := _fall_point(clampf(ui, 0.0, 1.0))
		var s := (.5 if i == 0 else .3 * (1.0 - float(i) / TRAIL * .6))
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), p))
		mm.set_instance_color(i, Color(C_SEED, (2.6 if i == 0 else 1.6) * a))
		mm.set_instance_custom_data(i, Color(0, 0, .1 if i == 0 else 0.0, 0))
	# felirat a földet érés helye fölött: lassan előtűnik, kis ideig áll, elhalványul
	var ca := _smooth((t - S_LAND - .2) / .7) * (1.0 - _smooth((t - (S_LEN - 1.2)) / 1.2))
	_caption.visible = ca > .001
	if _caption.visible:
		var d := cam.global_position.distance_to(_p)
		_caption.pixel_size = .00042 * d
		# a jel alatt (a kép lefelé eső irányában), hogy ne takarja se a jelet, se a felső gombsort
		_caption.global_position = _p + _n * .3 - cam.global_transform.basis.y * d * .1
		_caption.modulate = Color(1, .96, .88, ca)
		_caption.outline_modulate = Color(.14, .08, .24, ca * .6)


## A hulló mag pályája: másodfokú görbe a kiindulópontból a célba (a cél fölött függőlegesen érkezik),
## és lágy, csillapodó himbálózás oldalra, mint egy hulló pihe.
func _fall_point(u: float) -> Vector3:
	if not _has_start:
		return _p
	var e := .5 - .5 * cos(u * PI)
	var top := _p + _n * _start.distance_to(_p) * .55
	var q := _start.lerp(top, e).lerp(top.lerp(_p + _n * .6, e), e)
	return q + _side * sin(u * TAU * 1.3) * .45 * (1.0 - e)


func _ring() -> void:
	var mm := _wdots.multimesh
	var k := _ring_t / 1.4
	if k >= 1.0:
		_ring_t = -1.0
		mm.set_instance_color(W_RING, Color(0, 0, 0, 0))
		if mode != "sow":
			_wdots.visible = false
		return
	var e := 1.0 - pow(1.0 - k, 3.0)
	# a gyűrű a kamera felé néz (nem a felszínre fektetve): kicsi és gyorsan elhalványul, így ez nem zavar
	mm.set_instance_transform(W_RING, Transform3D(Basis.from_scale(Vector3.ONE * lerpf(.3, _ring_size, e)), _ring_p + _ring_n * .15))
	mm.set_instance_color(W_RING, Color(_ring_col.lerp(Color.WHITE, .3), 1.3 * (1.0 - k) * (1.0 - k)))
	mm.set_instance_custom_data(W_RING, Color(0, 1, 0, 0))
