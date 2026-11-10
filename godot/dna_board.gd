class_name DnaBoard
extends RefCounted
## A DNS-tábla logikája (a felülettől függetlenül, hogy a nap magja és a keresztezés is ezt használja).
##
## 6×6 mező, mindegyik egy bázispár: 0 = A=T, 1 = G≡C, -1 = üres.
## Szabályok (Takuzu/Binairo): soronként és oszloponként 3 A=T és 3 G≡C, három egyforma nem állhat egymás mellett.
## Egy sorra 14 szabályos minta van (Genes.rows(), a prototípussal azonos sorrendben); az egész táblára 11 222 kitöltés.
## A tábla hat sora a hat gén (Genes.GENE_NAMES), és a sor mintájának sorszáma = a gén változata.
## Ezért a DNS = hat sorszám (0–13), a tábla = rows()[dna[y]] soronként.
##
## A nap feladványa a napsorszámból jön, saját véletlenszám-generátorral (xorshift32), hogy minden eszközön
## és a motor későbbi változataiban is ugyanaz legyen (szerver nélkül, mindenkinek ugyanaz).

const N := 6
const EMPTY := -1
## Ennyi mezőt próbálunk kivenni a nem szabad sorokból (a prototípussal egyezően); a szabad sorok különbségei ezen felül üresek.
const PUZZLE_EMPTY := 12
## A nap magjának „sója”: ha egyszer új feladványsort akarunk, ezt kell átírni.
const DAILY_SALT := 0x4D41_4721

static var _boards := PackedByteArray()
static var _board_ms := 0.0


# ---------------------------------------------------------------- Véletlen (determinisztikus, motorfüggetlen)

## Kis xorshift32 generátor: csak eltolás és kizáró vagy, így minden platformon bitre ugyanazt adja.
class Rng:
	var s := 1

	func _init(seed_v: int) -> void:
		s = seed_v & 0xFFFFFFFF
		if s == 0:
			s = 0x9E3779B9
		for i in 8:
			next_u32()

	func next_u32() -> int:
		s ^= (s << 13) & 0xFFFFFFFF
		s ^= s >> 17
		s ^= (s << 5) & 0xFFFFFFFF
		return s

	## Egész 0..n-1 között.
	func below(n: int) -> int:
		return next_u32() % n

	func randf() -> float:
		return float(next_u32()) / 4294967296.0


static func day_rng(day: int, salt := 0) -> Rng:
	var s := (day * 2654435761 + DAILY_SALT + salt * 40503) & 0xFFFFFFFF
	return Rng.new(s)


# ---------------------------------------------------------------- Sorok és táblák

static func rows() -> Array:
	return Genes.rows()


## A sor (6 érték) mintájának sorszáma, vagy -1, ha nem kész vagy nem szabályos.
static func row_index(row: Array) -> int:
	var rs := rows()
	for k in rs.size():
		if rs[k] == row:
			return k
	return -1


## DNS → 6×6 rács (0/1).
static func grid_from_dna(dna: Array) -> Array:
	var rs := rows()
	var g: Array = []
	for y in N:
		g.append((rs[dna[y]] as Array).duplicate())
	return g


## Kész, szabályos rács → DNS (hat sorszám), vagy üres tömb, ha nem az.
static func dna_from_grid(grid: Array) -> Array:
	var dna: Array = []
	for y in N:
		var k := row_index(grid[y])
		if k < 0:
			return []
		dna.append(k)
	return dna if is_valid(dna) else []


static func empty_grid() -> Array:
	var g: Array = []
	for y in N:
		var r: Array = []
		r.resize(N)
		r.fill(EMPTY)
		g.append(r)
	return g


static func copy_grid(g: Array) -> Array:
	var out: Array = []
	for r in g:
		out.append((r as Array).duplicate())
	return out


## Szabályos-e a hat sorból álló tábla (a sorok maguk szabályosak, így csak az oszlopokat kell nézni).
static func is_valid(dna: Array) -> bool:
	if dna.size() != N:
		return false
	var rs := rows()
	for x in N:
		var ones := 0
		for y in N:
			var v: int = rs[dna[y]][x]
			ones += v
			if y >= 2 and v == int(rs[dna[y - 1]][x]) and v == int(rs[dna[y - 2]][x]):
				return false
		if ones != 3:
			return false
	return true


## Az összes szabályos tábla (11 222 × 6 bájt), lustán, első használatkor számolva (a keresztezés és az önellenőrzés kéri).
## A nap magjához nem kell: az visszalépéses kereséssel olcsóbb.
static func boards() -> PackedByteArray:
	if not _boards.is_empty():
		return _boards
	var t0 := Time.get_ticks_usec()
	var rs := rows()
	# soronként előre: melyik minta melyik oszlopba tesz G≡C-t
	var out := PackedByteArray()
	var pick := PackedInt32Array([0, 0, 0, 0, 0, 0])
	var cnt := PackedInt32Array([0, 0, 0, 0, 0, 0])
	_enum(0, rs, pick, cnt, out)
	_boards = out
	_board_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return _boards


static func _enum(y: int, rs: Array, pick: PackedInt32Array, cnt: PackedInt32Array, out: PackedByteArray) -> void:
	if y == N:
		for i in N:
			out.append(pick[i])
		return
	for k in rs.size():
		var r: Array = rs[k]
		var ok := true
		for x in N:
			var ones: int = cnt[x] + int(r[x])
			if ones > 3 or y + 1 - ones > 3:
				ok = false
				break
			if y >= 2 and int(rs[pick[y - 1]][x]) == int(r[x]) and int(rs[pick[y - 2]][x]) == int(r[x]):
				ok = false
				break
		if not ok:
			continue
		pick[y] = k
		for x in N:
			cnt[x] += int(r[x])
		_enum(y + 1, rs, pick, cnt, out)
		for x in N:
			cnt[x] -= int(r[x])


static func board_count() -> int:
	return boards().size() / N


static func board_dna(b: int) -> Array:
	var bs := boards()
	var dna: Array = []
	for y in N:
		dna.append(int(bs[b * N + y]))
	return dna


## Ennyi ms-ig tartott a felsorolás (önellenőrzéshez).
static func boards_ms() -> float:
	return _board_ms


## Véletlen szabályos tábla visszalépéses kereséssel, megkevert sorrendben (nem kell hozzá az összes tábla).
static func random_board(rng: Rng) -> Array:
	var order: Array = []
	for y in N:
		var o: Array = range(rows().size())
		for i in range(o.size() - 1, 0, -1):
			var j := rng.below(i + 1)
			var tmp: int = o[i]
			o[i] = o[j]
			o[j] = tmp
		order.append(o)
	var pick: Array = [0, 0, 0, 0, 0, 0]
	if _random_fill(0, order, pick):
		return pick
	return [2, 5, 1, 3, 0, 5]


static func _random_fill(y: int, order: Array, pick: Array) -> bool:
	if y == N:
		return is_valid(pick)
	var rs := rows()
	for k in order[y]:
		var r: Array = rs[k]
		var ok := true
		for x in N:
			var ones := int(r[x])
			for yy in y:
				ones += int(rs[pick[yy]][x])
			if ones > 3 or y + 1 - ones > 3:
				ok = false
				break
			if y >= 2 and int(rs[pick[y - 1]][x]) == int(r[x]) and int(rs[pick[y - 2]][x]) == int(r[x]):
				ok = false
				break
		if not ok:
			continue
		pick[y] = k
		if _random_fill(y + 1, order, pick):
			return true
	return false


## Két sor eltérése (hány mezőben különböznek).
static func hamming(a: int, b: int) -> int:
	var rs := rows()
	var d := 0
	for x in N:
		if int(rs[a][x]) != int(rs[b][x]):
			d += 1
	return d


## A kívánt sorokhoz (génváltozatokhoz) legközelebbi szabályos DNS: a legkevesebb eltérő mező, döntetlennél véletlenül.
## wanted: hat sorszám (0–13), vagy -1 ott, ahol mindegy. A keresztezésnél (M5) a két szülő génjeiből összerakott kívánság
## ritkán szabályos; az eltérés maga a mutáció. Visszaad: {"dna": [...], "dist": mezők száma, "ties": döntetlenek száma}.
static func nearest(wanted: Array, rng: Rng) -> Dictionary:
	var bs := boards()
	var count := bs.size() / N
	# soronkénti távolság-táblázat a gyorsaságért
	var dist_tab: Array = []
	for y in N:
		var row := PackedInt32Array()
		row.resize(14)
		for k in 14:
			row[k] = 0 if int(wanted[y]) < 0 else hamming(int(wanted[y]), k)
		dist_tab.append(row)
	var best := 999
	var ties := PackedInt32Array()
	for b in count:
		var d := 0
		for y in N:
			d += (dist_tab[y] as PackedInt32Array)[bs[b * N + y]]
			if d > best:
				break
		if d < best:
			best = d
			ties = PackedInt32Array([b])
		elif d == best:
			ties.append(b)
	var pick := ties[rng.below(ties.size())]
	return {"dna": board_dna(pick), "dist": best, "ties": ties.size()}


# ---------------------------------------------------------------- Ellenőrzés és következtetés

## A szabálysértő mezők (Vector2i(x, y) → true): túl sok egyforma egy sorban/oszlopban, vagy három egyforma egymás mellett.
## Az üres mezők nem hibák; finom jelzéshez a felület használja.
static func bad_cells(grid: Array) -> Dictionary:
	var bad := {}
	for axis in 2:
		for i in N:
			for sym in 2:
				var idx: Array = []
				for j in N:
					if _at(grid, axis, i, j) == sym:
						idx.append(j)
				if idx.size() > 3:
					for j in idx:
						bad[_pos(axis, i, j)] = true
			for j in N - 2:
				var v := _at(grid, axis, i, j)
				if v != EMPTY and v == _at(grid, axis, i, j + 1) and v == _at(grid, axis, i, j + 2):
					for q in 3:
						bad[_pos(axis, i, j + q)] = true
	return bad


static func _at(grid: Array, axis: int, i: int, j: int) -> int:
	return int(grid[j][i]) if axis == 1 else int(grid[i][j])


static func _pos(axis: int, i: int, j: int) -> Vector2i:
	return Vector2i(i, j) if axis == 1 else Vector2i(j, i)


static func empty_count(grid: Array) -> int:
	var n := 0
	for r in grid:
		for v in r:
			if int(v) == EMPTY:
				n += 1
	return n


## Soronként és oszloponként levezethető mezők kitöltése: egy sor/oszlop üres mezője akkor dől el, ha az összes
## illeszkedő szabályos mintában ugyanaz. Ugyanaz, amit egy játékos is ki tud következtetni (találgatás nélkül).
## Visszaad: a kiegészített rács, vagy üres tömb, ha ellentmondásra jut.
static func deduce(cells: Array) -> Array:
	var g := copy_grid(cells)
	var rs := rows()
	var changed := true
	while changed:
		changed = false
		for axis in 2:
			for i in N:
				var fits: Array = []
				for r in rs:
					var ok := true
					for j in N:
						var v := _at(g, axis, i, j)
						if v != EMPTY and v != int(r[j]):
							ok = false
							break
					if ok:
						fits.append(r)
				if fits.is_empty():
					return []
				for j in N:
					if _at(g, axis, i, j) != EMPTY:
						continue
					var v0: int = fits[0][j]
					var same := true
					for r in fits:
						if int(r[j]) != v0:
							same = false
							break
					if same:
						if axis == 1:
							g[j][i] = v0
						else:
							g[i][j] = v0
						changed = true
	return g


# ---------------------------------------------------------------- Feladvány

## Feladvány a cél-DNS-ből. A szabad sorok: két sor, amelyekben a többi sor változatlanul hagyásával más szabályos
## kitöltés is van (egy sorban eltérő tábla nem létezik, mert az oszlopösszegek nem engednék). Ott a játékos dönt.
## A többi sorból mezőket veszünk ki, amíg a tábla a szabad sorokon kívül logikával (deduce) végig megoldható.
## Visszaad: {"target": dna, "clue": rács (-1 = üres), "free": [sorok], "options": [szabályos DNS-ek, amelyek a feladványhoz illenek]}
static func make_puzzle(dna: Array, rng: Rng, empty_cells := PUZZLE_EMPTY) -> Dictionary:
	var target := grid_from_dna(dna)
	# pároknál: a két sor minden más változata, amellyel a tábla szabályos marad
	var keys: Array = []
	var groups := {}
	for y1 in N:
		for y2 in range(y1 + 1, N):
			for k1 in 14:
				if k1 == int(dna[y1]):
					continue
				for k2 in 14:
					if k2 == int(dna[y2]):
						continue
					var alt := dna.duplicate()
					alt[y1] = k1
					alt[y2] = k2
					if is_valid(alt):
						var key := Vector2i(y1, y2)
						if not groups.has(key):
							groups[key] = []
							keys.append(key)
						(groups[key] as Array).append(alt)
	var clue := copy_grid(target)
	var free: Array = []
	var options: Array = [dna.duplicate()]
	if not keys.is_empty():
		var key: Vector2i = keys[rng.below(keys.size())]
		free = [key.x, key.y]
		options.append_array(groups[key])
		var rs := rows()
		for y in free:
			for x in N:
				for alt in groups[key]:
					if int(rs[alt[y]][x]) != int(target[y][x]):
						clue[y][x] = EMPTY
						break
	var order: Array = []
	for y in N:
		if not free.has(y):
			for x in N:
				order.append(Vector2i(x, y))
	for i in range(order.size() - 1, 0, -1):
		var j := rng.below(i + 1)
		var tmp: Vector2i = order[i]
		order[i] = order[j]
		order[j] = tmp
	var removed := 0
	for p in order:
		if removed >= empty_cells:
			break
		var keep: int = clue[p.y][p.x]
		clue[p.y][p.x] = EMPTY
		if solves_fixed(clue, target, free):
			removed += 1
		else:
			clue[p.y][p.x] = keep
	return {"target": dna.duplicate(), "clue": clue, "free": free, "options": options}


## A szabad sorokon kívül logikával végig megoldható-e (és a célt adja-e).
static func solves_fixed(clue: Array, target: Array, free: Array) -> bool:
	var g := deduce(clue)
	if g.is_empty():
		return false
	for y in N:
		if free.has(y):
			continue
		for x in N:
			if int(g[y][x]) != int(target[y][x]):
				return false
	return true


## A nap feladványa (napsorszám → mindenkinek ugyanaz). A cél-DNS véletlen szabályos tábla a nap magjából.
static func daily(day: int) -> Dictionary:
	var rng := day_rng(day)
	var dna := random_board(rng)
	var p := make_puzzle(dna, rng)
	p.day = day
	return p


## A feladványhoz illő szabályos DNS-ek közül azok változatai egy sorban (a szabad soroknál: miből választhat a játékos).
static func row_choices(puzzle: Dictionary, y: int) -> Array:
	var out: Array = []
	for o in puzzle.options:
		if not out.has(int(o[y])):
			out.append(int(o[y]))
	return out


## Súgás: az első mező (sorfolytonosan), amely a nem szabad sorokban eltér a céltól. Vector2i(-1, -1), ha nincs ilyen.
static func hint(puzzle: Dictionary, grid: Array) -> Vector2i:
	var target := grid_from_dna(puzzle.target)
	for y in N:
		if (puzzle.free as Array).has(y):
			continue
		for x in N:
			if int(grid[y][x]) != int(target[y][x]):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


# ---------------------------------------------------------------- Önellenőrzés

## Sok napra legenerálja a feladványt, és ellenőrzi: logikával megoldható, a szabad sorokon kívül egyértelmű
## (minden illeszkedő szabályos tábla a nem szabad sorokban a célt adja), a szabad sorokban tényleg van választás.
static func self_test(first_day: int, days: int) -> String:
	var lines: Array = []
	var t0 := Time.get_ticks_usec()
	var count := board_count()
	lines.append("táblák: %d (felsorolás %.1f ms), sorminták: %d" % [count, boards_ms(), rows().size()])
	var bs := boards()
	var broken := 0
	var not_logical := 0
	var no_choice := 0
	var with_free := 0
	var empties := 0
	var min_e := 99
	var max_e := 0
	var gen_ms := 0.0
	var max_gen := 0.0
	var seen := {}
	for d in range(first_day, first_day + days):
		var g0 := Time.get_ticks_usec()
		var p := daily(d)
		var gms := (Time.get_ticks_usec() - g0) / 1000.0
		gen_ms += gms
		max_gen = maxf(max_gen, gms)
		var again := daily(d)
		if again.clue != p.clue or again.target != p.target:
			broken += 1
			lines.append("  nem determinisztikus: nap %d" % d)
		seen[str(p.target)] = true
		var clue: Array = p.clue
		var free: Array = p.free
		var e := empty_count(clue)
		empties += e
		min_e = mini(min_e, e)
		max_e = maxi(max_e, e)
		if not free.is_empty():
			with_free += 1
		if not is_valid(p.target):
			broken += 1
			lines.append("  szabálytalan cél: nap %d" % d)
		if not solves_fixed(clue, grid_from_dna(p.target), free):
			not_logical += 1
			lines.append("  logikával nem megoldható: nap %d" % d)
		# minden szabályos tábla, amely illik a feladványhoz (soronként előre: mely minták illenek a sor ismert mezőihez)
		var allowed: Array = []
		for y in N:
			var fl := PackedByteArray()
			fl.resize(14)
			for k in 14:
				var row: Array = rows()[k]
				var ok := 1
				for x in N:
					var c: int = clue[y][x]
					if c != EMPTY and c != int(row[x]):
						ok = 0
						break
				fl[k] = ok
			allowed.append(fl)
		var matches := 0
		for b in count:
			var ok := true
			for y in N:
				if (allowed[y] as PackedByteArray)[bs[b * N + y]] == 0:
					ok = false
					break
			if not ok:
				continue
			matches += 1
			for y in N:
				if not free.has(y) and int(bs[b * N + y]) != int(p.target[y]):
					broken += 1
					lines.append("  nem egyértelmű a nem szabad sorokban: nap %d" % d)
					break
		if matches != (p.options as Array).size():
			broken += 1
			lines.append("  a választható DNS-ek száma eltér: nap %d (%d ≠ %d)" % [d, matches, (p.options as Array).size()])
		if not free.is_empty() and matches < 2:
			no_choice += 1
	lines.append("napok: %d, szabad sorral: %d, üres mezők átlag %.1f (%d–%d), különböző célok: %d" % [days, with_free, float(empties) / days, min_e, max_e, seen.size()])
	lines.append("generálás: átlag %.1f ms, max %.1f ms" % [gen_ms / days, max_gen])
	lines.append("hibák: nem egyértelmű/hibás %d, logikával nem megoldható %d, szabad sor választás nélkül %d" % [broken, not_logical, no_choice])
	# a legközelebbi szabályos DNS (keresztezéshez): egy szabályos kívánság önmagát adja
	var rng := Rng.new(99)
	var near_bad := 0
	var near_ms := 0.0
	for i in 50:
		var want := board_dna(rng.below(count))
		var n0 := Time.get_ticks_usec()
		var r := nearest(want, rng)
		near_ms += (Time.get_ticks_usec() - n0) / 1000.0
		if r.dna != want or int(r.dist) != 0:
			near_bad += 1
		var mixed: Array = []
		for y in N:
			mixed.append(rng.below(14))
		var m := nearest(mixed, rng)
		if not is_valid(m.dna):
			near_bad += 1
	lines.append("legközelebbi DNS: %d hiba, átlag %.1f ms" % [near_bad, near_ms / 50.0])
	lines.append("összesen %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var ok_all := broken == 0 and not_logical == 0 and no_choice == 0 and near_bad == 0 and count == 11222
	lines.append("EREDMÉNY: %s" % ("rendben" if ok_all else "HIBA"))
	return "\n".join(lines)
