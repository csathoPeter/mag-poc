class_name DnaBoard
extends RefCounted
## A DNS-tábla logikája: 6×6 bázispár, 0 = A=T, 1 = G≡C (Takuzu/Binairo-szabályok).
## Soronként és oszloponként 3-3 legyen mindkettőből, és három egyforma nem állhat egymás mellett.
## A tábla egy sora egy gén; a 14 szabályos sor sorszáma a gén változata (ugyanaz, mint a webes prototípusban).

const N := 6
const EMPTY := -1

static var rows: Array = []  # a 14 szabályos sor, mindegyik 6 elemű tömb
static var row_index := {}  # "010110" → sorszám
static var boards := PackedByteArray()  # minden szabályos tábla 6 sorszáma egymás után
static var board_count := 0
static var _ham := PackedByteArray()  # sorok közti eltérés, 14×14


static func _ensure() -> void:
	if rows.size() > 0:
		return
	for m in 64:
		var r: Array = []
		var ones := 0
		for i in N:
			var v := (m >> (N - 1 - i)) & 1
			r.append(v)
			ones += v
		if ones == 3 and not _has_triple(r):
			row_index[_key(r)] = rows.size()
			rows.append(r)
	_ham.resize(rows.size() * rows.size())
	for a in rows.size():
		for b in rows.size():
			var d := 0
			for i in N:
				if rows[a][i] != rows[b][i]:
					d += 1
			_ham[a * rows.size() + b] = d
	var out: Array = []
	var pick: Array = [0, 0, 0, 0, 0, 0]
	var cnt: Array = [0, 0, 0, 0, 0, 0]
	_gen(0, pick, cnt, out)
	boards = PackedByteArray(out)
	board_count = boards.size() / N


static func _gen(y: int, pick: Array, cnt: Array, out: Array) -> void:
	if y == N:
		out.append_array(pick)
		return
	for k in rows.size():
		var r: Array = rows[k]
		var ok := true
		for x in N:
			var ones: int = cnt[x] + r[x]
			if ones > 3 or y + 1 - ones > 3:
				ok = false
				break
			if y >= 2 and rows[pick[y - 1]][x] == r[x] and rows[pick[y - 2]][x] == r[x]:
				ok = false
				break
		if not ok:
			continue
		pick[y] = k
		for x in N:
			cnt[x] += r[x]
		_gen(y + 1, pick, cnt, out)
		for x in N:
			cnt[x] -= r[x]


static func _has_triple(a: Array) -> bool:
	for i in a.size() - 2:
		if a[i] != EMPTY and a[i] == a[i + 1] and a[i] == a[i + 2]:
			return true
	return false


static func _key(r: Array) -> String:
	var s := ""
	for v in r:
		s += str(v)
	return s


static func board_rows(b: int) -> Array:
	_ensure()
	var out: Array = []
	for y in N:
		out.append(int(boards[b * N + y]))
	return out


## Egy kitöltött sor sorszáma, vagy -1, ha nem szabályos vagy nincs kész.
static func row_of(r: Array) -> int:
	_ensure()
	return row_index.get(_key(r), -1)


static func random_board(rng: RandomNumberGenerator) -> Array:
	_ensure()
	return board_rows(rng.randi() % board_count)


static func dna_grid(dna: Array) -> Array:
	_ensure()
	var g: Array = []
	for k in dna:
		g.append((rows[k] as Array).duplicate())
	return g


static func _copy(cells: Array) -> Array:
	var g: Array = []
	for r in cells:
		g.append((r as Array).duplicate())
	return g


## Sorról sorra, oszlopról oszlopra levezethető mezők: ugyanaz, amit egy játékos is ki tud következtetni.
## Ellentmondásnál üres tömböt ad.
static func deduce(cells: Array) -> Array:
	_ensure()
	var g := _copy(cells)
	var changed := true
	while changed:
		changed = false
		for axis in 2:
			for i in N:
				var line: Array = []
				for j in N:
					line.append(g[j][i] if axis == 1 else g[i][j])
				var fits: Array = []
				for r in rows:
					var ok := true
					for j in N:
						if line[j] != EMPTY and line[j] != r[j]:
							ok = false
							break
					if ok:
						fits.append(r)
				if fits.is_empty():
					return []
				for j in N:
					if line[j] != EMPTY:
						continue
					var v: int = fits[0][j]
					var same := true
					for f in fits:
						if f[j] != v:
							same = false
							break
					if same:
						if axis == 1:
							g[j][i] = v
						else:
							g[i][j] = v
						changed = true
	return g


## Feladvány egy szabályos táblához. A "free" sorokban több jó megoldás van, ott a játékos dönt;
## a többi mező logikával, találgatás nélkül kirakható.
static func make_puzzle(dna: Array, rng: RandomNumberGenerator, empty_cells := 12) -> Dictionary:
	_ensure()
	var target := dna_grid(dna)
	var groups := {}
	for b in board_count:
		var diff: Array = []
		for y in N:
			if boards[b * N + y] != dna[y]:
				diff.append(y)
				if diff.size() >= 3:
					break
		if diff.size() == 2:
			var key := "%d,%d" % [diff[0], diff[1]]
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append(b)
	var clue := _copy(target)
	var free: Array = []
	var keys: Array = groups.keys()
	if keys.size() > 0:
		var key: String = keys[rng.randi() % keys.size()]
		for s in key.split(","):
			free.append(int(s))
		for y in free:
			for x in N:
				for b in groups[key]:
					if rows[boards[b * N + y]][x] != target[y][x]:
						clue[y][x] = EMPTY
						break
	var order: Array = []
	for y in N:
		if not free.has(y):
			for x in N:
				order.append(Vector2i(x, y))
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Vector2i = order[i]
		order[i] = order[j]
		order[j] = t
	var removed := 0
	for c in order:
		if removed >= empty_cells:
			break
		var keep: int = clue[c.y][c.x]
		clue[c.y][c.x] = EMPTY
		var g := deduce(clue)
		var solved := g.size() > 0
		if solved:
			for y in N:
				if free.has(y):
					continue
				for x in N:
					if g[y][x] == EMPTY:
						solved = false
						break
				if not solved:
					break
		if solved:
			removed += 1
		else:
			clue[c.y][c.x] = keep
	return {"clue": clue, "free": free, "target": target}


## A kívánt génekhez (pl. két szülő keveréke) legközelebbi szabályos tábla. Az eltérés maga a mutáció.
static func nearest_board(wanted: Array, rng: RandomNumberGenerator) -> Array:
	_ensure()
	var nr := rows.size()
	var best := 1 << 30
	var ties: Array = []
	for b in board_count:
		var d := 0
		for y in N:
			d += _ham[boards[b * N + y] * nr + int(wanted[y])]
		if d < best:
			best = d
			ties = [b]
		elif d == best:
			ties.append(b)
	return board_rows(ties[rng.randi() % ties.size()])


## Szabályt sértő mezők (egy sorban/oszlopban 3-nál több egyforma, vagy három egyforma egymás mellett).
static func bad_cells(grid: Array) -> Dictionary:
	var bad := {}
	for axis in 2:
		for i in N:
			var line: Array = []
			var at: Array = []
			for j in N:
				line.append(grid[j][i] if axis == 1 else grid[i][j])
				at.append(Vector2i(i, j) if axis == 1 else Vector2i(j, i))
			for sym in 2:
				if line.count(sym) > 3:
					for j in N:
						if line[j] == sym:
							bad[at[j]] = true
			for j in N - 2:
				if line[j] != EMPTY and line[j] == line[j + 1] and line[j] == line[j + 2]:
					bad[at[j]] = true
					bad[at[j + 1]] = true
					bad[at[j + 2]] = true
	return bad
