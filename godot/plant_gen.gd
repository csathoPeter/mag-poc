class_name PlantGen
extends RefCounted
## Kódból felépített növény: ágak gyűrűkből, levelek és virágok példányonként.
##
## Alakítás (M8): a növény = DNS + kód + alakítási lista (metszés, kötözés). A generátor minden ágat ugyanúgy
## végigszámol (a véletlenszám-sorrend nem tolódik el, a levágott ág levelei is beleszámítanak a korlátokba), és a
## listát csak a végén, a kirajzolandó adatokra alkalmazza (apply_shaping): a levágott ág és minden leszármazottja,
## levelei, virágai nem rajzolódnak ki; a kötözött ág a tövénél elfordul a cél felé, a leszármazottai vele mozognak.
## Az ág indexe a generálás sorrendje (mélységi bejárás): ugyanabból a DNS-ből és kódból mindig ugyanaz, és mindhárom
## részletességi szinten ugyanaz, mert a váz csak az `r` sorozatból jön (a részletesség az `rl`-t érinti). Egy ág
## leszármazottai közvetlenül utána következnek, így az ág a rajta nőtt ágakkal együtt összefüggő tartomány
## (b … br_end[b]), és a csúcsaik, indexeik, leveleik, virágaik, vázpontjaik is összefüggő szeletek a tömbökben.
## Üres listával a kimenet bitre ugyanaz, mint az alakítás előtt (--shapetest).

const SIDES := [9, 6, 5, 3]
const STEP := [.2, .15, .12, .1]
const SIDES_LOW := [6, 4, 3, 3]
const SIDES_FAR := [5, 3, 3, 3]
## E részletesség alatt a "távoli" szint: kevesebb, nagyobb levél, kevés virág, csak a vastagabb ágak.
const FAR := .1

var r := RandomNumberGenerator.new()
var rl := RandomNumberGenerator.new()
var g: Dictionary
var pos := PackedVector3Array()
var nor := PackedVector3Array()
var uvs := PackedVector2Array()
var col := PackedColorArray()
var c0 := PackedFloat32Array()
var c1 := PackedFloat32Array()
var idx := PackedInt32Array()
var n := 0

var leaf_p := PackedVector3Array()
var leaf_d := PackedVector3Array()
var leaf_n := PackedVector3Array()
var leaf_s := PackedFloat32Array()
var leaf_path := PackedFloat32Array()
var leaf_tint := PackedFloat32Array()
var flo_p := PackedVector3Array()
var flo_d := PackedVector3Array()
var flo_s := PackedFloat32Array()
var flo_path := PackedFloat32Array()

var twigs := 0
var max_path := 0.001
var max_level := 3
var wind_v := Vector3.ZERO
var bb_min := Vector3.ZERO
var bb_max := Vector3.ZERO
var max_twigs := 1100
var max_leaves := 2600
var max_flowers := 260
var detail := 1.0

## Alakítási műveletek a mentésben (a fa "shaping" listája): {"op", "branch", "day", ...}.
const OP_CUT := "metszes"
const OP_TIE := "kotozes"
## A kötözött ág ennyi nap alatt éri el a célt; már a kötözés napján enged egy kicsit (BEND_GIVE nap előny).
const BEND_DAYS := 6.0
const BEND_GIVE := .75

## Ágak (index = a generálás sorrendje): szülő (-1 = tő), szint (0 = törzs), az utolsó leszármazott indexe, és az első
## csúcs / index / levél / virág / vázpont sorszáma; a tő sugara.
var br_parent := PackedInt32Array()
var br_level := PackedInt32Array()
var br_end := PackedInt32Array()
var br_v0 := PackedInt32Array()
var br_i0 := PackedInt32Array()
var br_l0 := PackedInt32Array()
var br_f0 := PackedInt32Array()
var br_k0 := PackedInt32Array()
var br_rad := PackedFloat32Array()
## A váz pontjai ágaként egymás után (alakítás után a kirajzolt helyükön, a koppintás-kereséshez és a zsinórhoz).
var br_pts := PackedVector3Array()
## Alakítás után: levágott ágak / levelek / virágok (üres = nincs levágás), a kirajzolt indexek, az ágak mai elfordulása.
var cut_b := PackedByteArray()
var leaf_cut := PackedByteArray()
var flo_cut := PackedByteArray()
var idx_draw := PackedInt32Array()
var bend_q := {}
## A lomb közepe és sugara (a levelek árnyékolásához), az alakítás előtti helyekből, hogy egy kötözés ne színezze át
## a többi levelet.
var leaf_center := Vector3.ZERO
var leaf_far := .001


static func perpendicular(d: Vector3) -> Vector3:
	var a := Vector3.UP if absf(d.y) < .9 else Vector3.RIGHT
	return d.cross(a).normalized()


func build(genome: Dictionary, det := 1.0) -> void:
	g = genome
	detail = det
	max_leaves = int(2600 * det)
	max_flowers = 260 if det >= 1.0 else (35 if det >= FAR else 14)
	r.seed = g.gen_seed
	rl.seed = g.gen_seed + 9
	max_level = 2 if g.b2 < .6 else 3
	wind_v = Vector3(cos(g.wind_dir), 0, sin(g.wind_dir))
	var stems: int = maxi(1, roundi(g.stems))
	for s in stems:
		var a := float(s) / stems * TAU + r.randf()
		var splay := (r.randf_range(.22, .52) if stems > 1 else .04 + g.wind * .5) as float
		var dir := Vector3(cos(a) * splay, 1, sin(a) * splay)
		var off := Vector3(cos(a) * .12, -.06, sin(a) * .12) if stems > 1 else Vector3(0, -.06, 0)
		_branch(off, dir, g.height * (r.randf_range(.75, 1.1) if stems > 1 else 1.0), g.height * .055 * g.thick, 0, 0.0, -1)
	var count := leaf_p.size()
	for p in leaf_p:
		leaf_center += p
	leaf_center /= maxi(count, 1)
	for p in leaf_p:
		leaf_far = maxf(leaf_far, p.distance_to(leaf_center))


func _expand(p: Vector3) -> void:
	bb_min = bb_min.min(p)
	bb_max = bb_max.max(p)


func _branch(p0: Vector3, d0: Vector3, length: float, rad: float, lvl: int, path: float, parent: int) -> void:
	var bi := twigs
	twigs += 1
	br_parent.append(parent)
	br_level.append(lvl)
	br_end.append(bi)
	br_v0.append(n)
	br_i0.append(idx.size())
	br_l0.append(leaf_p.size())
	br_f0.append(flo_p.size())
	br_k0.append(br_pts.size())
	br_rad.append(rad)
	if twigs > max_twigs:
		return
	var segs: int = clampi(roundi(length / STEP[lvl]), 3, 28)
	var step := length / segs
	var phase := r.randf() * TAU
	var freq := r.randf_range(.8, 2.3)
	var d := d0.normalized()
	var nn := perpendicular(d)
	var p := p0
	var pts := PackedVector3Array()
	var ds := PackedVector3Array()
	var ns := PackedVector3Array()
	var rs := PackedFloat32Array()
	var ps := PackedFloat32Array()
	var trop: float = g["t%d" % lvl]
	for i in segs + 1:
		var t := float(i) / segs
		var rr := maxf(rad * lerpf(1.0, g.taper, t), .007)
		if lvl == 0:
			rr *= 1.0 + g.flare * pow(1.0 - t, 7.0)
		pts.append(p); ds.append(d); ns.append(nn); rs.append(rr); ps.append(path + step * i)
		_expand(p)
		if i == segs:
			break
		var bn := d.cross(nn)
		d += nn * sin(phase + t * freq * TAU) * g.wobble * step
		d += bn * cos(phase * 1.7 + t * freq * 5.1) * g.wobble * step
		d.y += trop * step
		d += wind_v * g.wind * step * (.4 + .6 * lvl)
		d = d.normalized()
		nn = (nn - d * nn.dot(d)).normalized()
		p += d * step
	max_path = maxf(max_path, ps[segs])
	br_pts.append_array(pts)

	var sides: int = SIDES[lvl] if detail >= 1.0 else (SIDES_LOW[lvl] if detail >= FAR else SIDES_FAR[lvl])
	var base := n
	var draw_rings := detail >= 1.0 or lvl < (max_level if detail >= FAR else max_level - 1)
	var ring_every := 1 if detail >= 1.0 else (2 if detail >= FAR else 3)
	var ring_ids: Array[int] = []
	if draw_rings:
		for i in segs + 1:
			if i % ring_every == 0 or i == segs:
				ring_ids.append(i)
	for k in ring_ids.size():
		var i := ring_ids[k]
		var c := pts[i]
		var prev := pts[ring_ids[maxi(0, k - 1)]]
		var bn := ds[i].cross(ns[i])
		var shade := rl.randf_range(.86, 1.1)
		for s in sides:
			var a := float(s) / sides * TAU
			var ca := cos(a)
			var sa := sin(a)
			var v := ns[i] * ca + bn * sa
			var rr := rs[i]
			if lvl == 0:
				rr *= 1.0 + .22 * g.flare * sin(a * 3.0 + phase) * pow(1.0 - float(i) / segs, 3.0)
			pos.append(c + v * rr)
			nor.append(v)
			uvs.append(Vector2(ca, sa))
			var sh := shade * (.9 if s % 2 == 1 else 1.1)
			var bc: Color = g.bark
			col.append(Color(bc.r * sh, bc.g * sh, bc.b * sh))
			c0.append(c.x); c0.append(c.y); c0.append(c.z); c0.append(ps[i])
			c1.append(prev.x); c1.append(prev.y); c1.append(prev.z); c1.append(0.0)
	for i in maxi(ring_ids.size() - 1, 0):
		for s in sides:
			var a := base + i * sides + s
			var b := base + i * sides + (s + 1) % sides
			var cc := a + sides
			var e := b + sides
			idx.append(a); idx.append(b); idx.append(cc)
			idx.append(b); idx.append(e); idx.append(cc)
	n += ring_ids.size() * sides

	if lvl >= max_level - 1 and leaf_p.size() < max_leaves:
		var count := maxi(1, roundi(length * g.leaf_dens * 1.4 * (1.0 if lvl == max_level else .4) * detail))
		var az := rl.randf() * TAU
		for k in count:
			var t := lerpf(.1, 1.0, (k + rl.randf()) / count)
			var i := mini(segs, int(t * segs))
			var bn := ds[i].cross(ns[i])
			var out := ns[i] * cos(az) + bn * sin(az)
			var dir := ds[i] * .45 + out * .85
			dir.y += g.leaf_up
			dir = dir.normalized()
			var nv := (Vector3.UP - dir * dir.y) + Vector3(rl.randf() - .5, rl.randf() - .5, rl.randf() - .5) * .5
			leaf_p.append(pts[i]); leaf_d.append(dir); leaf_n.append(nv)
			leaf_s.append(g.leaf_len * rl.randf_range(.65, 1.25) * (1.0 - .25 * t) * sqrt(1.0 / detail))
			leaf_path.append(ps[i]); leaf_tint.append(rl.randf())
			_expand(pts[i])
			az += 2.39996
	if lvl == max_level:
		if flo_p.size() < max_flowers and rl.randf() < g.flower_odds * maxf(detail, .7):
			var dir := (ds[segs] * .55 + Vector3(rl.randf() - .5, .7, rl.randf() - .5) * .8).normalized()
			flo_p.append(pts[segs]); flo_d.append(dir); flo_s.append(g.flower_size * rl.randf_range(.8, 1.2) * (1.0 if detail >= 1.0 else 1.5)); flo_path.append(ps[segs])
		if flo_p.size() < max_flowers and rl.randf() < g.flower_odds * .5 * maxf(detail, .7):
			var i := int(segs * rl.randf_range(.3, .8))
			flo_p.append(pts[i]); flo_d.append(Vector3(rl.randf() - .5, .9, rl.randf() - .5).normalized()); flo_s.append(g.flower_size * rl.randf_range(.7, 1.05) * (1.0 if detail >= 1.0 else 1.5)); flo_path.append(ps[i])

	if lvl < max_level:
		var cnt: int = roundi(g["b%d" % lvl])
		var start: float = g["s%d" % lvl]
		var az := r.randf() * TAU
		for c in cnt:
			var u := (c + r.randf_range(.2, .8)) / cnt
			var t := lerpf(start, .97, u)
			var i := clampi(int(t * segs), 0, segs)
			var bn := ds[i].cross(ns[i])
			var out := ns[i] * cos(az) + bn * sin(az)
			var a: float = deg_to_rad(g["a%d" % lvl]) * r.randf_range(.8, 1.2)
			var cd := ds[i] * cos(a) + out * sin(a)
			var profile := lerpf(1.0, 1.0 - u * .8, g.crown)
			_branch(pts[i], cd, length * g["r%d" % lvl] * profile * r.randf_range(.8, 1.2), rs[i] * (.62 if lvl == 0 else .68), lvl + 1, ps[i] + .02, bi)
			az += 2.39996 + (r.randf() - .5) * .4
	br_end[bi] = twigs - 1


func local_aabb() -> AABB:
	return AABB(bb_min - Vector3.ONE * 2.5, bb_max - bb_min + Vector3.ONE * 5.0)


func wood_mesh() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nor
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_CUSTOM0] = c0
	arr[Mesh.ARRAY_CUSTOM1] = c1
	arr[Mesh.ARRAY_INDEX] = idx_draw if not cut_b.is_empty() else idx
	var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	m.custom_aabb = local_aabb()
	return m


func leaf_mesh() -> ArrayMesh:
	var rows := 6 if detail >= 1.0 else (3 if detail >= FAR else 2)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows + 1:
		var t := float(i) / rows
		var w: float = pow(maxf(sin(PI * pow(t, g.leaf_pow)), 0.0), .8) * g.leaf_w
		if g.leaf_lobes > 0:
			w *= .76 + .24 * absf(sin(t * PI * g.leaf_lobes))
		var z: float = g.leaf_curl * t * t
		st.set_uv(Vector2(t, 1)); st.add_vertex(Vector3(-w, t, z + g.leaf_fold * w))
		st.set_uv(Vector2(t, 0)); st.add_vertex(Vector3(0, t, z))
		st.set_uv(Vector2(t, 1)); st.add_vertex(Vector3(w, t, z + g.leaf_fold * w))
	for i in rows:
		var a := i * 3
		for s in 2:
			st.add_index(a + s); st.add_index(a + s + 1); st.add_index(a + s + 3)
			st.add_index(a + s + 1); st.add_index(a + s + 4); st.add_index(a + s + 3)
	st.generate_normals()
	var m := st.commit()
	m.custom_aabb = local_aabb()
	return m


func flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := [0]
	var rows := 4 if detail >= 1.0 else 2
	var add_petal := func(angle: float, plen: float, wid: float, cup: float) -> void:
		var base: int = count[0]
		var ca := cos(angle)
		var sa := sin(angle)
		var cc := cos(cup)
		var sc := sin(cup)
		for i in rows + 1:
			var t := float(i) / rows
			var w := pow(maxf(sin(PI * pow(t, .75)), 0.0), .7) * wid
			var rad := t * plen * cc
			var y := t * plen * sc + t * t * plen * .28 * sc - t * t * plen * .18
			for s in [-1, 0, 1]:
				var z: float = s * w
				st.set_color(Color(0, 0, 0))
				st.set_uv(Vector2(t, absf(float(s))))
				st.add_vertex(Vector3(rad * ca - z * sa, y + absf(float(s)) * w * .22, rad * sa + z * ca))
		count[0] += (rows + 1) * 3
		for i in rows:
			for s in 2:
				var a := base + i * 3 + s
				st.add_index(a); st.add_index(a + 1); st.add_index(a + 3)
				st.add_index(a + 1); st.add_index(a + 4); st.add_index(a + 3)
	var np: int = g.petals
	for i in np:
		add_petal.call(float(i) / np * TAU, g.petal_len, g.petal_w * g.petal_len * .62, deg_to_rad(g.petal_cup))
	if g.layers == 2 and detail >= FAR:
		for i in np:
			add_petal.call((i + .5) / np * TAU, g.petal_len * .68, g.petal_w * g.petal_len * .46, deg_to_rad(g.petal_cup + 18.0))
	if detail < FAR:
		# távolról a porzó nem látszik
		st.generate_normals()
		var mf := st.commit()
		mf.custom_aabb = local_aabb()
		return mf
	var ball := SphereMesh.new()
	ball.radius = .16 * g.petal_len
	ball.height = .32 * g.petal_len
	ball.radial_segments = 6
	ball.rings = 3
	var ba := ball.get_mesh_arrays()
	var bv: PackedVector3Array = ba[Mesh.ARRAY_VERTEX]
	var bi: PackedInt32Array = ba[Mesh.ARRAY_INDEX]
	var base: int = count[0]
	for v in bv:
		st.set_color(Color(1, 0, 0)); st.set_uv(Vector2.ZERO); st.add_vertex(v + Vector3(0, .06, 0))
	for k in bi.size():
		st.add_index(base + bi[k])
	st.generate_normals()
	var m := st.commit()
	m.custom_aabb = local_aabb()
	return m


func _basis_buffer(buf: PackedFloat32Array, i: int, p: Vector3, y: Vector3, z_hint: Vector3, s: float, cust: Color) -> void:
	var z := (z_hint - y * z_hint.dot(y)).normalized()
	var x := y.cross(z)
	var o := i * 16
	buf[o] = x.x * s; buf[o + 1] = y.x * s; buf[o + 2] = z.x * s; buf[o + 3] = p.x
	buf[o + 4] = x.y * s; buf[o + 5] = y.y * s; buf[o + 6] = z.y * s; buf[o + 7] = p.y
	buf[o + 8] = x.z * s; buf[o + 9] = y.z * s; buf[o + 10] = z.z * s; buf[o + 11] = p.z
	buf[o + 12] = cust.r; buf[o + 13] = cust.g; buf[o + 14] = cust.b; buf[o + 15] = cust.a


func _new_multimesh(mesh: Mesh, count: int, buf: PackedFloat32Array) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.buffer = buf
	mm.custom_aabb = local_aabb()
	return mm


func leaves_multimesh() -> MultiMesh:
	return _new_multimesh(leaf_mesh(), leaf_p.size(), _leaf_buffer(0, leaf_p.size()))


func flowers_multimesh() -> MultiMesh:
	return _new_multimesh(flower_mesh(), flo_p.size(), _flower_buffer(0, flo_p.size()))


## A levelek példány-adatai [i0, i1) között; a levágott levél nulla méretű (a sorszámok és a többi levél nem változik).
func _leaf_buffer(i0: int, i1: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize((i1 - i0) * 16)
	for i in range(i0, i1):
		var birth := leaf_path[i] / max_path * .64 + .05
		var ao := .42 + .58 * pow(leaf_p[i].distance_to(leaf_center) / leaf_far, 1.25)
		var s := leaf_s[i]
		if not leaf_cut.is_empty() and leaf_cut[i] != 0:
			s = 0.0
		_basis_buffer(buf, i - i0, leaf_p[i], leaf_d[i], leaf_n[i], s, Color(birth, leaf_tint[i], ao, 0))
	return buf


func _flower_buffer(i0: int, i1: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize((i1 - i0) * 16)
	for i in range(i0, i1):
		var birth := .74 + flo_path[i] / max_path * .14
		var hint := Vector3.UP if absf(flo_d[i].y) < .9 else Vector3.RIGHT
		var s := flo_s[i]
		if not flo_cut.is_empty() and flo_cut[i] != 0:
			s = 0.0
		_basis_buffer(buf, i - i0, flo_p[i], flo_d[i], hint, s, Color(birth, .9 + fmod(i * .618, 1.0) * .22, 1, 0))
	return buf


# ---------------------------------------------------------------- Alakítás (M8): metszés, kötözés

## Hány ág van (a levágottakkal együtt).
func branch_count() -> int:
	return br_level.size()


## Egy tömb-tartomány vége az ág és leszármazottai után (starts: br_v0 / br_i0 / br_l0 / br_f0 / br_k0).
func _sub_end(starts: PackedInt32Array, total: int, b: int) -> int:
	var e := br_end[b] + 1
	return starts[e] if e < br_level.size() else total


## Csak az ág saját része (a leszármazottai nélkül) – a gyerekei közvetlenül utána jönnek.
func _own_end(starts: PackedInt32Array, total: int, b: int) -> int:
	return starts[b + 1] if b + 1 < br_level.size() else total


func branch_live(b: int) -> bool:
	return cut_b.is_empty() or cut_b[b] == 0


func leaf_live(i: int) -> bool:
	return leaf_cut.is_empty() or leaf_cut[i] == 0


func flower_live(i: int) -> bool:
	return flo_cut.is_empty() or flo_cut[i] == 0


## A kötözés előrehaladása (0–1) a kezdőnap óta eltelt napokból: a kötözés napján ~11%, a 3. napon ~56%, a 6. naptól 100%.
static func bend_progress(days: int) -> float:
	return clampf((float(days) + BEND_GIVE) / (BEND_DAYS + BEND_GIVE), 0.0, 1.0)


## Egy kötözés mai elfordulása (az ág eredeti keretében, a tövénél): a kötözéskori állásból ("from") a cél felé ("to").
static func tie_quat(e: Dictionary, day: int) -> Quaternion:
	var a := quat_of(e.get("from"))
	var b := quat_of(e.get("to"))
	return a.slerp(b, bend_progress(day - int(e.get("day", day))))


## Kész-e már a kötözés (eléri a célt) ezen a napon.
static func tie_done(e: Dictionary, day: int) -> bool:
	return bend_progress(day - int(e.get("day", day))) >= 1.0


## A mentésben a kvaternió [x, y, z, w] tömb (a JSON nem ismeri a Quaternion-t).
static func quat_of(v: Variant) -> Quaternion:
	if v is Quaternion:
		return v
	if v is Array and (v as Array).size() == 4:
		var q := Quaternion(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
		if q.length() > .0001:
			return q.normalized()
	return Quaternion.IDENTITY


static func quat_arr(q: Quaternion) -> Array:
	return [snappedf(q.x, .00001), snappedf(q.y, .00001), snappedf(q.z, .00001), snappedf(q.w, .00001)]


## Érvényes-e a művelet ezen a növényen (a törzs – 0. szint – nem vágható és nem köthető).
func can_shape(b: int) -> bool:
	return b >= 0 and b < br_level.size() and br_level[b] > 0


## Az alakítási lista alkalmazása a kirajzolandó adatokra (a build() után, a mesh-ek előtt). day: a mai nap (a kötözés
## előrehaladásához). A váz (a véletlenszámok) nem változik; a három részletességi szint ugyanazt kapja.
func apply_shaping(list: Array, day: int) -> void:
	if list.is_empty():
		return
	var nb := br_level.size()
	var cuts: Array = []
	bend_q = {}
	for e in list:
		if not (e is Dictionary):
			continue
		var b := int((e as Dictionary).get("branch", -1))
		if not can_shape(b):
			continue
		var op := str((e as Dictionary).get("op", ""))
		if op == OP_CUT:
			cuts.append(b)
		elif op == OP_TIE:
			bend_q[b] = tie_quat(e, day)
	# kötözés: a mélyebb ágak előbb (a leszármazott indexe mindig nagyobb), így az ős elfordulása viszi a már elfordult
	# leszármazottat is; mindegyik az eredeti tövénél fordul
	var keys: Array = bend_q.keys()
	keys.sort()
	keys.reverse()
	for b in keys:
		var q: Quaternion = bend_q[b]
		if q.is_equal_approx(Quaternion.IDENTITY):
			continue
		var o := br_pts[br_k0[b]]
		var bs := Basis(q)
		_xf_range(b, Transform3D(bs, o - bs * o))
	if cuts.is_empty():
		return
	# metszés: az ág és minden leszármazottja (az indexek kimaradnak, a levelek és virágok nulla méretűek)
	cut_b.resize(nb)
	cut_b.fill(0)
	leaf_cut.resize(leaf_p.size())
	leaf_cut.fill(0)
	flo_cut.resize(flo_p.size())
	flo_cut.fill(0)
	cuts.sort()
	var ranges: Array = []
	for b in cuts:
		if cut_b[b] != 0:
			continue
		for c in range(b, br_end[b] + 1):
			cut_b[c] = 1
		ranges.append([br_i0[b], _sub_end(br_i0, idx.size(), b)])
		for i in range(br_l0[b], _sub_end(br_l0, leaf_p.size(), b)):
			leaf_cut[i] = 1
		for i in range(br_f0[b], _sub_end(br_f0, flo_p.size(), b)):
			flo_cut[i] = 1
	idx_draw = PackedInt32Array()
	var at := 0
	for rg in ranges:
		if int(rg[0]) > at:
			idx_draw.append_array(idx.slice(at, int(rg[0])))
		at = maxi(at, int(rg[1]))
	if at < idx.size():
		idx_draw.append_array(idx.slice(at))


## Az ág és leszármazottai minden kirajzolandó adatának elforgatása (csúcsok, normálok, gyűrűközéppontok, levelek,
## virágok, vázpontok).
func _xf_range(b: int, xf: Transform3D) -> void:
	var bs := xf.basis
	for i in range(br_v0[b], _sub_end(br_v0, n, b)):
		pos[i] = xf * pos[i]
		nor[i] = bs * nor[i]
		var k := i * 4
		var c := xf * Vector3(c0[k], c0[k + 1], c0[k + 2])
		c0[k] = c.x; c0[k + 1] = c.y; c0[k + 2] = c.z
		var pv := xf * Vector3(c1[k], c1[k + 1], c1[k + 2])
		c1[k] = pv.x; c1[k + 1] = pv.y; c1[k + 2] = pv.z
	for i in range(br_l0[b], _sub_end(br_l0, leaf_p.size(), b)):
		leaf_p[i] = xf * leaf_p[i]
		leaf_d[i] = bs * leaf_d[i]
		leaf_n[i] = bs * leaf_n[i]
	for i in range(br_f0[b], _sub_end(br_f0, flo_p.size(), b)):
		flo_p[i] = xf * flo_p[i]
		flo_d[i] = bs * flo_d[i]
	for i in range(br_k0[b], _sub_end(br_k0, br_pts.size(), b)):
		br_pts[i] = xf * br_pts[i]


## Az ág őseinek együttes mai elfordulása (az ág eredeti keretéből a kirajzolt keretbe; csak forgatás).
func ancestors_basis(b: int) -> Basis:
	var bs := Basis.IDENTITY
	var p := br_parent[b]
	while p >= 0:
		if bend_q.has(p):
			bs = Basis(bend_q[p] as Quaternion) * bs
		p = br_parent[p]
	return bs


## Az ág egy pontja (a tövétől a hossza u-adik részénél), a kirajzolt helyén.
func branch_point(b: int, u: float) -> Vector3:
	var k0 := br_k0[b]
	var k1 := _own_end(br_k0, br_pts.size(), b)
	if k1 <= k0:
		return Vector3.ZERO
	var f := clampf(u, 0.0, 1.0) * float(k1 - k0 - 1)
	var i := mini(int(f), k1 - k0 - 2) if k1 - k0 > 1 else 0
	if k1 - k0 == 1:
		return br_pts[k0]
	return br_pts[k0 + i].lerp(br_pts[k0 + i + 1], f - float(i))


## Ahová a kötés pontja (az ág u-adik része) a kötözés céljánál kerül (a kirajzolt keretben): a zsinór vége.
func tie_target(b: int, e: Dictionary, u: float) -> Vector3:
	var cur := tie_quat(e, 99999999)
	var now: Quaternion = bend_q.get(b, Quaternion.IDENTITY)
	var o := br_pts[br_k0[b]]
	var p := branch_point(b, u)
	var anc := ancestors_basis(b)
	# a mostani állásból vissza az eredetibe (az ős-keretben), majd a cél felé
	var local := anc.inverse() * (p - o)
	local = Basis(now).inverse() * local
	return o + anc * (Basis(cur) * local)


## A koppintáshoz legközelebbi élő ág a képen (a váz szakaszaiból). xf: a növény csomópontjának transzformációja.
## Visszaad: {"b": index, "d": távolság képpontban, "at": a legközelebbi vázpont a növény keretében, "u": hol az ágon}
## vagy üreset, ha radius-on belül nincs ág. A vékony ágvégeknél a vastagabb ág kicsit előnyt kap.
func pick_branch(cam: Camera3D, xf: Transform3D, pos: Vector2, radius: float, px_per_unit: float) -> Dictionary:
	var best := {}
	var best_s := radius
	var nb := br_level.size()
	var scale := xf.basis.get_scale().x
	for b in nb:
		if not branch_live(b):
			continue
		var k0 := br_k0[b]
		var k1 := _own_end(br_k0, br_pts.size(), b)
		if k1 - k0 < 2:
			continue
		var prev := Vector2.ZERO
		var prev_ok := false
		var prev_w := Vector3.ZERO
		for k in range(k0, k1):
			var w := xf * br_pts[k]
			if cam.is_position_behind(w):
				prev_ok = false
				continue
			var sp := cam.unproject_position(w)
			if prev_ok:
				var seg := sp - prev
				var l2 := seg.length_squared()
				var t := 0.0 if l2 < .0001 else clampf((pos - prev).dot(seg) / l2, 0.0, 1.0)
				var d := pos.distance_to(prev + seg * t)
				# a látszó vastagság: a sugár képpontban (a kamerától való távolsággal)
				var rpx := br_rad[b] * scale * px_per_unit / maxf(cam.global_position.distance_to(prev_w.lerp(w, t)), .1)
				var s := maxf(d - minf(rpx, 12.0), 0.0) + float(br_level[b]) * 5.0
				if s < best_s:
					best_s = s
					var local := br_pts[k - 1].lerp(br_pts[k], t)
					best = {"b": b, "d": d, "at": local, "u": (float(k - 1 - k0) + t) / float(k1 - k0 - 1)}
			prev = sp
			prev_w = w
			prev_ok = true
	return best


## Az ág (a leszármazottaival, a már levágottak nélkül) faanyaga külön mesh-ként: kiemeléshez, és – a levágás előtti
## növényből – a lehulló darabhoz.
func subtree_wood_mesh(b: int) -> ArrayMesh:
	var v0 := br_v0[b]
	var v1 := _sub_end(br_v0, n, b)
	var ids := PackedInt32Array()
	for c in range(b, br_end[b] + 1):
		if not branch_live(c):
			continue
		for k in range(br_i0[c], _own_end(br_i0, idx.size(), c)):
			ids.append(idx[k] - v0)
	var m := ArrayMesh.new()
	m.custom_aabb = local_aabb()
	if ids.size() < 3 or v1 <= v0:
		return m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos.slice(v0, v1)
	arr[Mesh.ARRAY_NORMAL] = nor.slice(v0, v1)
	arr[Mesh.ARRAY_TEX_UV] = uvs.slice(v0, v1)
	arr[Mesh.ARRAY_COLOR] = col.slice(v0, v1)
	arr[Mesh.ARRAY_CUSTOM0] = c0.slice(v0 * 4, v1 * 4)
	arr[Mesh.ARRAY_CUSTOM1] = c1.slice(v0 * 4, v1 * 4)
	arr[Mesh.ARRAY_INDEX] = ids
	var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	return m


## Az ág (és leszármazottai) élő levelei / virágai külön MultiMesh-ként (a lehulló darabhoz). Null, ha nincs.
func subtree_leaves_multimesh(b: int) -> MultiMesh:
	var i0 := br_l0[b]
	var i1 := _sub_end(br_l0, leaf_p.size(), b)
	if i1 <= i0:
		return null
	return _new_multimesh(leaf_mesh(), i1 - i0, _leaf_buffer(i0, i1))


func subtree_flowers_multimesh(b: int) -> MultiMesh:
	var i0 := br_f0[b]
	var i1 := _sub_end(br_f0, flo_p.size(), b)
	if i1 <= i0:
		return null
	return _new_multimesh(flower_mesh(), i1 - i0, _flower_buffer(i0, i1))


## Lenyomat a kirajzolandó adatokról (önellenőrzéshez): SHA-256 a mesh-ek és a példány-pufferek bájtjaiból.
func digest() -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	var arr := wood_mesh().surface_get_arrays(0)
	for i in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_INDEX]:
		if arr[i] != null:
			h.update(arr[i].to_byte_array())
	h.update(leaves_multimesh().buffer.to_byte_array())
	h.update(flowers_multimesh().buffer.to_byte_array())
	return h.finish().hex_encode().substr(0, 16)
