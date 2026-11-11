class_name Breeding
extends RefCounted
## Keresztezés (M5): a két szülő génjeiből tábla, a legközelebbi szabályos DNS, három csíra, rejtett virágszín.
## Tiszta függvények (a felület a crossing.gd és a sprout_pick.gd), minden a két mag azonosítójából és DNS-éből
## jön, saját véletlenszám-generátorral (DnaBoard.Rng), így determinisztikus és motorfüggetlen: ugyanaz a pár
## mindig ugyanazt a táblát és ugyanazt a három csírát adja (újratöltés után is).
##
## 1. Tábla: soronként (génenként) az egyik szülő változata – ahol eltérnek, a pár kulcsából sorsolva. Ez ritkán
##    szabályos, ezért a legközelebbi szabályos DNS lesz a cél (DnaBoard.nearest); az eltérés maga a mutáció.
##    A feladványban két szabad sor marad, lehetőleg ott, ahol a szülők génjei közül lehet választani
##    (DnaBoard.make_puzzle prefer), így a játékos dönt, melyik szülőtől jöjjön az a gén.
## 2. Három csíra: az 1. pontosan a játékos táblája; a 2. és 3. testvér: egy-egy olyan gén, ahol a szülők
##    eltérnek, a másik szülőtől jön (a tábla ehhez is a legközelebbi szabályosat keresi, ezért gyakran egy
##    másik gén is mutálódik). Azonos szülőknél (önbeporzás) egy-egy apró mutáció.
## 3. Rejtett virágszín: minden mag és fa hordoz egy lappangó virágszínt (hidden; alapból a virágszínéhez tartozó
##    pár, LATENT). Csíránként mindkét szülő vagy a látható, vagy a lappangó színét adja tovább (fele-fele).
##    Ha mindkettő a lappangót adja, és ez a kettőnél ugyanaz, a testvér-csírán előbújik (pl. két kék szülőtől
##    néha fehér utód). Az utód lappangó színe az, amit a szülők továbbadtak, de nem látszik rajta.

## A virágszínek lappangó párja (Genes.FLOWER sorrendjében): a kékek, a rózsa, az orgona és a menta fehéret rejt;
## a meleg színek barackot; a fehér és az ibolya éjkéket; a barack korallt; a cseresznye rózsát; a magenta cseresznyét.
const LATENT := [11, 2, 12, 1, 13, 12, 12, 12, 12, 11, 11, 0, 13, 12]
const SPROUTS := 3


## A mag vagy fa lappangó virágszíne (a mentett hidden, vagy ha nincs, a virágszínéhez tartozó pár).
static func latent(rec: Dictionary) -> int:
	var h := int(rec.get("hidden", -1))
	return h if h >= 0 else int(LATENT[int((rec.dna as Array)[0])])


static func dna_text(dna: Array) -> String:
	return "-".join(dna.map(func(x: Variant) -> String: return str(int(x))))


## A pár kulcsa: a két mag azonosítója és DNS-e (a sorrend számít: 1 = akiről indult, 2 = a párja).
static func cross_key(a: Dictionary, b: Dictionary) -> int:
	return Care.str_hash("kereszt:%d:%d:%s:%s" % [int(a.id), int(b.id), dna_text(a.dna), dna_text(b.dna)])


## A kívánt sorok: génenként az egyik szülőé (ahol egyformák, az; ahol eltérnek, sorsolva).
static func wanted(a_dna: Array, b_dna: Array, rng: DnaBoard.Rng) -> Array:
	var out: Array = []
	for y in DnaBoard.N:
		out.append(int(a_dna[y]) if rng.below(2) == 0 else int(b_dna[y]))
	return out


## A keresztezés feladványa (DnaBoard.make_puzzle formátumban, plusz "wanted" és "mutations" = eltérő mezők száma).
static func puzzle(a: Dictionary, b: Dictionary) -> Dictionary:
	var rng := DnaBoard.Rng.new(cross_key(a, b))
	var want := wanted(a.dna, b.dna, rng)
	var near := DnaBoard.nearest(want, rng)
	var p := DnaBoard.make_puzzle(near.dna, rng, DnaBoard.PUZZLE_EMPTY, [a.dna, b.dna])
	p.wanted = want
	p.mutations = int(near.dist)
	return p


## Soronként: "1" = az 1. szülőtől, "2" = a 2. szülőtől, "M" = mutáció (ugyanaz a szabály, mint a BoardView jelölése).
static func marks(dna: Array, a_dna: Array, b_dna: Array) -> Array:
	var out: Array = []
	for y in DnaBoard.N:
		out.append("1" if int(dna[y]) == int(a_dna[y]) else "2" if int(dna[y]) == int(b_dna[y]) else "M")
	return out


## A három csíra a kész táblából (solved). code_prefix: a csírák kódja ebből + sorszám (a választott csíra pontosan
## az a fa lesz, amit az előnézetben látsz). Visszaad: [{"dna", "hidden", "shows_hidden", "code", "marks", "name"}] × 3.
static func sprouts(a: Dictionary, b: Dictionary, solved: Array, code_prefix: String) -> Array:
	var rng := DnaBoard.Rng.new(cross_key(a, b) ^ 0x2C5A9E11)
	var a_dna: Array = a.dna
	var b_dna: Array = b.dna
	var la := latent(a)
	var lb := latent(b)
	var diff: Array = []
	for y in DnaBoard.N:
		if int(a_dna[y]) != int(b_dna[y]):
			diff.append(y)
	var out: Array = []
	# ritka módosítás (genes.gd RARE): ha valamelyik szülő hordozza, csíránként fele eséllyel öröklődik (ha mindkettő, a
	# kettő közül sorsolva); külön véletlen-sorozatból, így a csírák DNS-e ugyanaz, mint a ritkaság bevezetése előtt
	var rare_rng := DnaBoard.Rng.new(cross_key(a, b) ^ 0x51A4E5C3)
	var rares: Array = []
	for x in [int(a.get("rare", 0)), int(b.get("rare", 0))]:
		if Genes.rare_valid(x) > 0:
			rares.append(x)
	for k in SPROUTS:
		# mit ad tovább a két szülő a virágszínből: a láthatót vagy a lappangót (fele-fele)
		var pa := la if rng.below(2) == 0 else int(a_dna[0])
		var pb := lb if rng.below(2) == 0 else int(b_dna[0])
		var shows := k > 0 and pa == la and pb == lb and la == lb and la != int(solved[0])
		var dna: Array = solved.duplicate()
		if k > 0:
			for attempt in 6:
				var want: Array = solved.duplicate()
				var fixed: Array = []
				var y: int
				if not diff.is_empty():
					# testvér: ez a gén a másik szülőtől jön
					y = int(diff[rng.below(diff.size())])
					want[y] = int(b_dna[y]) if int(solved[y]) == int(a_dna[y]) else int(a_dna[y])
				else:
					# önbeporzás: apró mutáció
					y = rng.below(DnaBoard.N)
					want[y] = (int(solved[y]) + 1 + rng.below(13)) % 14
				fixed.append(y)
				if shows:
					want[0] = la
					if not fixed.has(0):
						fixed.append(0)
				dna = DnaBoard.nearest(want, rng, fixed).dna
				var dup := dna == solved
				for o in out:
					if o.dna == dna:
						dup = true
				if not dup:
					break
		var hid: int
		if shows:
			hid = la
		elif pa != int(dna[0]):
			hid = pa
		elif pb != int(dna[0]):
			hid = pb
		else:
			hid = int(LATENT[int(dna[0])])
		var rare := 0
		if not rares.is_empty() and rare_rng.below(2) == 0:
			rare = int(rares[rare_rng.below(rares.size())])
		out.append({"dna": dna, "hidden": hid, "shows_hidden": shows, "code": "%s-%d" % [code_prefix, k],
			"marks": marks(dna, a_dna, b_dna), "name": Genes.latin_name(dna), "rare": rare})
	return out


# ---------------------------------------------------------------- Önellenőrzés (--crosstest)

## Sok véletlen páron: a csírák szabályosak, különbözők, determinisztikusak; a rejtett szín milyen gyakran bújik elő;
## és a maghozás tempója (Care.bears_seed) a fák számától függően.
static func self_test(pairs: int) -> String:
	var lines: Array = []
	var t0 := Time.get_ticks_usec()
	var rng := DnaBoard.Rng.new(4242)
	var count := DnaBoard.board_count()
	var bad := 0
	var dups := 0
	var muts := 0
	var marks_m := 0
	var blue_pairs := 0
	var blue_white := 0
	var shows_any := 0
	var free_parent := 0
	var p_ms := 0.0
	var rare_n := 0
	var rare_got := 0
	var s_ms := 0.0
	for i in pairs:
		var a := {"id": i * 2 + 1, "dna": DnaBoard.board_dna(rng.below(count)), "hidden": -1}
		var b := {"id": i * 2 + 2, "dna": DnaBoard.board_dna(rng.below(count)), "hidden": -1}
		if i % 4 == 0:
			# minden negyedik pár két kék virágú szülő (azúr, türkiz, éjkék): a rejtett fehér gyakoriságához
			for rec in [a, b]:
				for tries in 200:
					var d := DnaBoard.board_dna(rng.below(count))
					if [6, 7, 13].has(int(d[0])):
						rec.dna = d
						break
		var c0 := Time.get_ticks_usec()
		var p := puzzle(a, b)
		p_ms += (Time.get_ticks_usec() - c0) / 1000.0
		muts += int(p.mutations)
		if not DnaBoard.is_valid(p.target):
			bad += 1
		for y in p.free:
			for k in DnaBoard.row_choices(p, int(y)):
				if k != int(p.target[y]) and (k == int(a.dna[y]) or k == int(b.dna[y])):
					free_parent += 1
					break
		var c1 := Time.get_ticks_usec()
		var sp := sprouts(a, b, p.target, "T%d" % i)
		s_ms += (Time.get_ticks_usec() - c1) / 1000.0
		# ritka módosítás: ha az egyik szülő hordozza, a csírák kb. fele örökli; a DNS ugyanaz, mint nélküle
		var ar := a.duplicate()
		ar.rare = 1 + i % (Genes.RARE.size() - 1)
		var spr := sprouts(ar, b, p.target, "T%d" % i)
		for k in SPROUTS:
			rare_n += 1
			if spr[k].dna != sp[k].dna or int(sp[k].rare) != 0:
				bad += 1
			if int(spr[k].rare) == int(ar.rare):
				rare_got += 1
		if sp != sprouts(a, b, p.target, "T%d" % i) or p.clue != puzzle(a, b).clue:
			bad += 1
			lines.append("  nem determinisztikus: %d. pár" % i)
		var seen := {}
		var any := false
		for s in sp:
			if not DnaBoard.is_valid(s.dna):
				bad += 1
			seen[dna_text(s.dna)] = true
			marks_m += (s.marks as Array).count("M")
			any = any or bool(s.shows_hidden)
		if seen.size() < SPROUTS:
			dups += 1
		if any:
			shows_any += 1
		if [6, 7, 13].has(int(a.dna[0])) and [6, 7, 13].has(int(b.dna[0])):
			blue_pairs += 1
			for s in sp:
				if int(s.dna[0]) == 12:
					blue_white += 1
					break
	lines.append("párok: %d, szabálytalan/nem determinisztikus: %d, egyforma csírák: %d" % [pairs, bad, dups])
	lines.append("mutáció a táblán: átlag %.2f mező; M-jel csíránként átlag %.2f gén" % [float(muts) / pairs, float(marks_m) / (pairs * SPROUTS)])
	lines.append("szabad sor a másik szülő génjével: %.0f%% (párok átlaga, max 2 sor)" % [100.0 * free_parent / (pairs * 2.0)])
	lines.append("ritka módosítás öröklődik (egyik szülő hordozza): a csírák %.0f%%-ában" % (100.0 * rare_got / maxf(1.0, rare_n)))
	lines.append("rejtett szín előbújt: a keresztezések %.0f%%-ában; két kék szülő (%d pár): fehér csíra %.0f%%" % [100.0 * shows_any / pairs, blue_pairs, 100.0 * blue_white / maxf(1.0, blue_pairs)])
	lines.append("idő: feladvány átlag %.1f ms, három csíra átlag %.1f ms" % [p_ms / pairs, s_ms / pairs])
	# a maghozás tempója: N kikelt fa (3 kezdő fa, a többi naponta egy-egy kikelt mag), 90 nap
	var tempo: Array = []
	for n in [3, 5, 10, 20, 30]:
		var trees: Array = []
		for i in n:
			trees.append({"code": "TEMPO-%d" % i, "slot": i, "origin": "kezdo" if i < 3 else "ultetes", "hatch": -20 - i, "watered": 1 << 30})
		var total := 0
		var lo := 99
		var hi := 0
		for day in range(0, 90):
			var c := 0
			for t in trees:
				if Care.can_gather(t, day, trees):
					c += 1
			total += c
			lo = mini(lo, c)
			hi = maxi(hi, c)
		tempo.append("%d fa: %.1f (%d–%d)" % [n, total / 90.0, lo, hi])
	lines.append("mag naponta (90 nap átlaga, min–max): " + ", ".join(tempo))
	lines.append("összesen %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	lines.append("EREDMÉNY: %s" % ("rendben" if bad == 0 and dups == 0 else "HIBA"))
	return "\n".join(lines)
