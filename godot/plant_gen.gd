class_name PlantGen
extends RefCounted
## Kódból felépített növény: ágak gyűrűkből, levelek és virágok példányonként.

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
		_branch(off, dir, g.height * (r.randf_range(.75, 1.1) if stems > 1 else 1.0), g.height * .055 * g.thick, 0, 0.0)


func _expand(p: Vector3) -> void:
	bb_min = bb_min.min(p)
	bb_max = bb_max.max(p)


func _branch(p0: Vector3, d0: Vector3, length: float, rad: float, lvl: int, path: float) -> void:
	twigs += 1
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
			_branch(pts[i], cd, length * g["r%d" % lvl] * profile * r.randf_range(.8, 1.2), rs[i] * (.62 if lvl == 0 else .68), lvl + 1, ps[i] + .02)
			az += 2.39996 + (r.randf() - .5) * .4


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
	arr[Mesh.ARRAY_INDEX] = idx
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
	var count := leaf_p.size()
	var buf := PackedFloat32Array()
	buf.resize(count * 16)
	var center := Vector3.ZERO
	for p in leaf_p:
		center += p
	center /= maxi(count, 1)
	var far := .001
	for p in leaf_p:
		far = maxf(far, p.distance_to(center))
	for i in count:
		var birth := leaf_path[i] / max_path * .64 + .05
		var ao := .42 + .58 * pow(leaf_p[i].distance_to(center) / far, 1.25)
		_basis_buffer(buf, i, leaf_p[i], leaf_d[i], leaf_n[i], leaf_s[i], Color(birth, leaf_tint[i], ao, 0))
	return _new_multimesh(leaf_mesh(), count, buf)


func flowers_multimesh() -> MultiMesh:
	var count := flo_p.size()
	var buf := PackedFloat32Array()
	buf.resize(count * 16)
	for i in count:
		var birth := .74 + flo_path[i] / max_path * .14
		var hint := Vector3.UP if absf(flo_d[i].y) < .9 else Vector3.RIGHT
		_basis_buffer(buf, i, flo_p[i], flo_d[i], hint, flo_s[i], Color(birth, .9 + fmod(i * .618, 1.0) * .22, 1, 0))
	return _new_multimesh(flower_mesh(), count, buf)
