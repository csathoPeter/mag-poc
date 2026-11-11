class_name SoundSynth
extends RefCounted
## Hangminták kódból (M9): nincs letöltött hangfájl, minden itt készül, előre kiszámolt AudioStreamWAV-ként.
## Weben a Godot a hangot „sample” módban játssza le (Web Audio AudioBuffer): ott csak a kész minták (WAV/OGG/MP3)
## mennek biztosan, generátor- és buszeffekt nem – ezért a zengés is bele van számolva a mintába.
##
## Egy recept = hangok listája (op), mindegyik saját burkolóval:
##   "p" részhang: szinusz, opcionális FM-modulátorral (harang/üveg jelleg) és hangmagasság-csúszással,
##   "n" zaj: két egypólusú alul- és egy felüláteresztő szűrővel (szél, víz, levélzizegés), lassú lüktetéssel,
##   "k" pengetés: Karplus–Strong (hárfaszerű).
## A számolás darabokban fut (Job.step, időkerettel), így weben sem akasztja meg a képet; a minta végén enyhe zengés,
## a csúcs normálva, az eleje és a vége puhán nullára húzva (nincs kattanás).
##
## Hangolás: D-dúr pentaton (D E Fis A H), a fák hangjai, az akkord és az effektek is ebből, így minden összeillik.

const SR := 22050
## A növényhangok alapmintái ezen a hangmagasságon készülnek (A4); a fa hangja pitch_scale-lel tolja el.
const VOICE_HZ := 440.0
## A pad (ambient) alapminta hangmagassága (A3).
const PAD_HZ := 220.0
## A skála alaphangja (D4) és a pentaton fokai félhangban.
const ROOT_HZ := 293.66
const SCALE := [0, 2, 4, 7, 9]
## A normálás célcsúcsa (a lejátszás hangereje külön, a Sound.gd táblájában).
const PEAK := .8

## A növényhang hangszíne a kéregből (14 változat → 4 család): fa (marimba), harang (FM), üveg, pengetés.
const BARK_FAMILY := ["glass", "glass", "wood", "wood", "wood", "bell", "pluck", "glass", "bell", "pluck", "pluck", "bell", "wood", "bell"]
## A levélforma a felhang-réteg (csillogás) erőssége dB-ben: a kerek levél puha, a tollas, csipkés fényes.
const LEAF_SHIMMER := [-14.0, -12.0, -10.0, -18.0, -26.0, -20.0, -9.0, -16.0, -11.0, -13.0, -8.0, -15.0, -12.0, -7.0]
## A termet a hangfekvés (0 = mély: szomorú, zömök; 3 = magas: oszlopos, magas bokros).
const HABIT_REG := [1, 2, 0, 0, 1, 0, 1, 2, 0, 2, 3, 2, 3, 3]
## A lomb a díszítés iránya: a hangok közti lépések a skálán (fokban).
const FOLIAGE_STEPS := [[1, 1, 1], [2, 1, 2], [1, 2, 1], [2, 2, 1], [-1, -1, -1], [3, -1, 2], [1, -2, 3], [2, -1, 2],
	[-2, 1, -2], [1, 1, -2], [3, 1, 1], [-1, 2, -1], [2, 1, 1], [-2, -1, 2]]
const FAMILY_DB := {"wood": 0.0, "bell": -1.5, "glass": 0.0, "pluck": 3.5}
## A szirmok a díszítés hangjainak száma és üteme (harangos virág = lassabb), telt virágnál oktáv-kettőzés.
const PETAL_NOTES := [1, 2, 2, 3, 3, 4]
const PETAL_GAP := [.12, .15, .19, .24]

## Az összes minta neve, nagyjából a szükség sorrendjében (a háttérben ebben a sorrendben készülnek).
const ALL := ["v_wood", "v_bell", "v_glass", "v_pluck", "v_shimmer", "tap_at", "tap_gc", "tap_clear", "pad_warm", "pad_glass",
	"cricket", "wind", "water", "gather", "bag", "select", "done", "helix", "fall", "land", "hatch", "snip", "tie", "undo",
	"release", "star", "rise", "recall", "hop", "arrive", "kindle", "birth"]


# ---------------------------------------------------------------- Zene: fokok, hangmagasság

## A skála d-edik foka félhangban (negatív is lehet).
static func degree_semis(d: int) -> int:
	var o := floori(d / 5.0)
	return o * 12 + int(SCALE[d - o * 5])


static func semis_hz(s: float) -> float:
	return ROOT_HZ * pow(2.0, s / 12.0)


## Egy fa hangja a DNS-ből (és a kódból egy hajszálnyi egyéni hangolás). Determinisztikus.
##   family: hangszín, deg: alaphang (skálafok 0–7), notes: a díszítés fokai, gap: ütem (mp), double: oktáv-kettőzés,
##   shimmer: a csillogó felhang-réteg hangereje (dB), cents: egyéni hangolás.
static func voice(dna: Array, code: String) -> Dictionary:
	var deg := int(dna[0]) % 5 + int(HABIT_REG[int(dna[3])])
	var pk := int(dna[1])
	var steps: Array = FOLIAGE_STEPS[int(dna[5])]
	var notes: Array = [deg]
	var d := deg
	for i in int(PETAL_NOTES[pk % 6]) - 1:
		d = clampi(d + int(steps[i % steps.size()]), -2, 10)
		notes.append(d)
	var h := absi(hash(code + "hang"))
	return {"family": BARK_FAMILY[int(dna[4])], "deg": deg, "notes": notes, "gap": float(PETAL_GAP[pk % 4]) * (.95 + .1 * float(h % 101) / 100.0),
		"double": pk >= 6 and pk < 12, "shimmer": float(LEAF_SHIMMER[int(dna[2])]), "cents": float(h % 21 - 10)}


## A fa egy fokának pitch_scale-je a hangszín alapmintájához.
static func voice_pitch(v: Dictionary, d: int) -> float:
	return semis_hz(degree_semis(d)) / VOICE_HZ * pow(2.0, float(v.cents) / 1200.0)


## Lejátszandó hangok egy fa egy alkalmához: [{"s": minta, "p": pitch_scale, "at": késleltetés (mp), "db": hangerő}].
##   kind: "tap" (koppintás), "water" (öntözés), "gather" (maggyűjtés), "hatch" (kikelés), "one" (csak az alaphang),
##   "amb" (az ambient halk megszólalása).
static func voice_events(v: Dictionary, kind: String) -> Array:
	var out: Array = []
	var fam := "v_" + str(v.family)
	var notes: Array = v.notes
	var gap := float(v.gap)
	var base_db := -9.0
	var shift := 0
	var first := 0.0
	match kind:
		"water":
			gap *= 1.6
			base_db = -12.0
			first = .45
		"gather":
			# egy oktávval feljebb, ha belefér (a minta legfeljebb ~3-szoros hangmagasságon szól szépen)
			shift = 5 if int(notes.max()) + 5 <= 11 else 2
			base_db = -13.0
			first = .25
		"hatch":
			gap *= 1.3
			base_db = -10.0
		"one":
			notes = [v.deg]
			base_db = -12.0
		"amb":
			notes = [v.deg]
			base_db = -25.0
	# a pengetés csúcsos (kisebb az átlagos hangereje), ezért kicsit hangosabb, hogy a fák egyformán szóljanak
	base_db += float(FAMILY_DB.get(str(v.family), 0.0))
	for i in notes.size():
		var d := int(notes[i]) + shift
		var p := voice_pitch(v, d)
		var at := first + gap * i
		var db := base_db - (0.0 if i == 0 else 3.0 + i)
		out.append({"s": fam, "p": p, "at": at, "db": db})
		if i == 0 and float(v.shimmer) > -30.0:
			out.append({"s": "v_shimmer", "p": p, "at": at, "db": db + float(v.shimmer) + 4.0})
		if bool(v.double) and i == notes.size() - 1 and kind != "amb":
			out.append({"s": fam, "p": p * .5, "at": at + .03, "db": db - 6.0})
	return out


## A bolygó ambient akkordja a fák hangjaiból: a leggyakoribb hangok (félhang, 0–11, D-től), 3–5 hang.
## Fa nélkül (csupasz bolygó) alaphang és kvint. Döntetlennél a bolygókód dönt (minden bolygó máshogy szól).
static func chord(dnas: Array, code: String) -> Array:
	if dnas.is_empty():
		return [0, 7]
	var counts := {}
	for dna in dnas:
		var v := voice(dna, "")
		var pc := degree_semis(int(v.deg)) % 12
		counts[pc] = int(counts.get(pc, 0)) + 1
	var pcs: Array = counts.keys()
	pcs.sort_custom(func(a: int, b: int) -> bool:
		if counts[a] != counts[b]:
			return counts[a] > counts[b]
		return hash(code + str(a)) < hash(code + str(b)))
	var out: Array = pcs.slice(0, 5)
	for extra in [0, 7, 9, 4, 2]:
		if out.size() >= 3:
			break
		if not out.has(extra):
			out.append(extra)
	return out


## A pad hangszíne: meleg (meleg virágszínű alapító) vagy üveges.
static func pad_kind(dnas: Array, code: String) -> String:
	if dnas.is_empty():
		return "pad_glass" if absi(hash(code)) % 2 == 0 else "pad_warm"
	return "pad_warm" if [0, 1, 2, 3, 9, 10, 11].has(int(dnas[0][0])) else "pad_glass"


## Egyszerű, motorfüggetlen véletlen (xorshift32) az ambient megszólalásaihoz: ugyanaz a bolygó ugyanúgy „lélegzik”.
class Rng:
	var s := 1

	func _init(seed_text: String) -> void:
		s = absi(hash(seed_text)) & 0x7fffffff
		if s == 0:
			s = 1

	func next() -> float:
		s ^= (s << 13) & 0xffffffff
		s ^= s >> 17
		s ^= (s << 5) & 0xffffffff
		s &= 0xffffffff
		return float(s) / 4294967296.0

	func between(a: float, b: float) -> float:
		return a + (b - a) * next()


## Az ambient sorozata: lassú lélegzés (pad-hangok az akkordból, néha egy fa halk hangja), éjjel tücskök, nappal szél.
## Minden megszólalás a bolygókódból számolt véletlen sorozatból jön; a hívó a megadott várakozás után kér újat.
class Ambient:
	var code := ""
	var breath: Rng
	var night_rng: Rng
	var day_rng: Rng
	var n := 0

	func _init(planet_code: String) -> void:
		code = planet_code
		breath = Rng.new(planet_code + "lelegzes")
		night_rng = Rng.new(planet_code + "tucsok")
		day_rng = Rng.new(planet_code + "szel")

	## Egy lélegzet: {"wait": mp a következőig, "ev": hangok}. dnas: a bolygó kikelt fái.
	func next_breath(dnas: Array) -> Dictionary:
		n += 1
		var ch := SoundSynth.chord(dnas, code)
		var pad := SoundSynth.pad_kind(dnas, code)
		var ev: Array = []
		var pc := int(ch[int(breath.next() * ch.size()) % ch.size()])
		var semi := pc + (12 if pc < 5 and breath.next() < .25 else 0)
		ev.append({"s": pad, "p": SoundSynth.semis_hz(semi - 12.0) / SoundSynth.PAD_HZ, "at": 0.0, "db": -17.0 if not dnas.is_empty() else -20.0})
		if breath.next() < .3:
			var pc2 := int(ch[(ch.find(pc) + 1 + int(breath.next() * 2.0)) % ch.size()])
			ev.append({"s": pad, "p": SoundSynth.semis_hz(pc2 - 12.0) / SoundSynth.PAD_HZ, "at": breath.between(1.2, 2.4), "db": -20.0})
		if not dnas.is_empty() and breath.next() < .28:
			var dna: Array = dnas[int(breath.next() * dnas.size()) % dnas.size()]
			for e in SoundSynth.voice_events(SoundSynth.voice(dna, ""), "amb"):
				e.at = float(e.at) + breath.between(1.0, 3.0)
				ev.append(e)
		return {"wait": breath.between(5.0, 8.5), "ev": ev}

	## Éjszakai háttér: tücsök-csiripelés csoportokban (1–3), ritkán.
	func next_night() -> Dictionary:
		var ev: Array = []
		var k := 1 + int(night_rng.next() * 3.0)
		var p := night_rng.between(.9, 1.1)
		var db := night_rng.between(-31.0, -26.0)
		for i in k:
			ev.append({"s": "cricket", "p": p * night_rng.between(.985, 1.015), "at": i * night_rng.between(.38, .55), "db": db - i})
		return {"wait": night_rng.between(3.0, 7.5), "ev": ev}

	## Nappali háttér: ritka, puha szellő.
	func next_day() -> Dictionary:
		return {"wait": day_rng.between(10.0, 18.0), "ev": [{"s": "wind", "p": day_rng.between(.8, 1.2), "at": 0.0, "db": day_rng.between(-25.0, -21.0)}]}


# ---------------------------------------------------------------- Receptek

static func _p(f: float, a: float, t: float, length: float, att: float, dec: float, rel := .05, extra := {}) -> Dictionary:
	var o := {"k": "p", "f": f, "a": a, "t": t, "len": length, "att": att, "dec": dec, "rel": rel}
	o.merge(extra)
	return o


static func _n(a: float, t: float, length: float, att: float, dec: float, rel: float, lp: float, hp: float, extra := {}) -> Dictionary:
	var o := {"k": "n", "a": a, "t": t, "len": length, "att": att, "dec": dec, "rel": rel, "lp": lp, "hp": hp}
	o.merge(extra)
	return o


## FM-harang egy hangja (csengő, puha ütés).
static func _bell(f: float, a: float, t: float, dec := 1.0, ratio := 3.5, idx := 1.2) -> Dictionary:
	return _p(f, a, t, minf(dec * 4.5, 4.0), .006, dec, .1, {"mr": ratio, "mi": idx, "md": dec * .35})


## Csillanás: rövid, magas, üveges hang.
static func _glint(f: float, a: float, t: float, dec := .35) -> Array:
	return [_p(f, a, t, dec * 4.0, .005, dec, .05), _p(f * 2.76, a * .25, t, dec * 2.0, .004, dec * .4, .03)]


## Egy minta receptje: {"len": mp, "rev": zengés (0–1), "ops": [...], "sr": mintavétel}.
static func recipe(name: String) -> Dictionary:
	var f := VOICE_HZ
	var ops: Array = []
	var length := 1.0
	var rev := .25
	var sr := SR
	match name:
		# --- növényhangok (A4-en; a fa hangja pitch_scale-lel tolja el)
		"v_wood":
			# marimba: alaphang, a 4. és a 10. részhang gyorsan lecseng; puha fa-ütés
			ops = [_p(f, 1.0, 0, 1.4, .004, .5), _p(f * 4.0, .22, 0, .5, .003, .1), _p(f * 9.9, .05, 0, .2, .003, .03),
				_n(.08, 0, .05, .002, .012, .01, 2500.0, 300.0)]
			length = 1.6
		"v_bell":
			ops = [_bell(f, 1.0, 0, 1.1), _p(f * 2.0, .12, 0, 2.0, .01, .7), _p(f * 2.76, .08, 0, .9, .003, .25)]
			length = 2.6
		"v_glass":
			# üvegharmonika-szerű: lassabb indulás, kevés, nem harmonikus felhang
			ops = [_p(f, 1.0, 0, 2.6, .018, 1.4), _p(f * 2.32, .26, 0, 1.6, .012, .6), _p(f * 4.25, .1, 0, .8, .008, .25),
				_p(f * 1.003, .35, 0, 2.6, .03, 1.2)]
			length = 2.8
			rev = .3
		"v_pluck":
			ops = [{"k": "k", "f": f, "a": .9, "t": 0.0, "len": 2.0, "damp": .45, "fb": .996}, _p(f, .25, 0, 1.8, .004, .7)]
			length = 2.1
		"v_shimmer":
			# a fényes felhang-réteg: oktáv és duodecima, enyhe lebegéssel
			ops = [_p(f * 2.0, .6, 0, 1.6, .03, .55, .1, {"mr": 1.0, "mi": .3, "md": .3}), _p(f * 3.006, .4, 0, 1.3, .04, .4),
				_p(f * 4.01, .2, 0, .9, .05, .25)]
			length = 1.7
			rev = .35
		# --- DNS-tábla: A=T két kötés (két hang), G≡C három kötés (három hang), törlés halk koppanás
		"tap_at":
			ops = _glint(880.0, .8, 0, .22) + _glint(1318.5, .55, .045, .2)
			length = .9
		"tap_gc":
			ops = _glint(880.0, .7, 0, .2) + _glint(1174.7, .55, .035, .2) + _glint(1480.0, .45, .07, .2)
			length = .9
		"tap_clear":
			ops = [_p(520.0, .7, 0, .3, .004, .06, .05, {"f1": 380.0, "g": .08})]
			length = .4
			rev = .15
		"done":
			# kész a tábla: felfelé futó harang-arpeggio
			var ns := [587.3, 740.0, 880.0, 1174.7, 1480.0]
			for i in ns.size():
				ops.append(_bell(ns[i], .7 - i * .06, i * .09, .55, 3.5, 1.0))
			length = 2.4
			rev = .35
		# --- spirál, elvetés, kikelés
		"helix":
			# felfelé csavarodó csillanások egy puha akkord fölött, a végén a mag „összehúzódik”
			ops = [_p(293.7, .35, 0, 3.6, 1.2, 0.0, 1.4), _p(440.0, .25, .2, 3.4, 1.2, 0.0, 1.4), _p(587.3, .12, .4, 3.0, 1.0, 0.0, 1.2, {"mr": 2.0, "mi": .4, "md": 1.0})]
			for i in 14:
				var d := 3 + i
				ops.append_array(_glint(semis_hz(degree_semis(d)), .32 + .02 * (i % 3), .15 + i * .19, .3))
			ops.append(_p(1760.0, .3, 2.9, .9, .02, .2, .1, {"f1": 880.0, "g": .25}))
			length = 4.0
			rev = .4
		"fall":
			# a mag lágyan ereszkedik: lefelé csúszó, halk szinusz és légies zaj
			ops = [_p(1400.0, .35, 0, 2.4, .5, 0.0, .9, {"f1": 660.0, "g": 2.4}), _n(.25, 0, 2.4, .9, 0.0, 1.0, 1800.0, 700.0)]
			length = 2.6
			rev = .35
		"land":
			# földet ér: mély, puha koppanás, felette fénygyűrű-csengés
			ops = [_p(120.0, .9, 0, .5, .004, .18, .1, {"f1": 70.0, "g": .2}), _n(.3, 0, .3, .002, .08, .1, 500.0, 60.0),
				_bell(587.3, .35, .05, .9, 2.0, .8), _bell(880.0, .25, .12, .8, 2.0, .6)]
			length = 2.2
			rev = .4
		"hatch":
			# kikelés: kinyíló akkord (D, A, E, Fis), egymás után belépő hangokkal, a tetején csillanás
			var ch := [293.7, 440.0, 659.3, 740.0]
			for i in ch.size():
				ops.append(_p(ch[i], .45, i * .16, 3.2 - i * .16, .45, 1.6, .6))
			ops.append_array(_glint(1480.0, .3, .7, .4))
			ops.append_array(_glint(1760.0, .25, .85, .4))
			length = 3.6
			rev = .45
		# --- gondozás
		"water":
			# csobbanás és cseppek: rövid, felfelé csúszó „plip”-ek, alatta puha zaj
			ops = [_n(.22, 0, .6, .015, .18, .2, 1700.0, 400.0)]
			var r := Rng.new("viz")
			for i in 9:
				var ff := r.between(900.0, 1500.0)
				ops.append(_p(ff, r.between(.25, .45), .05 + i * r.between(.09, .15), .25, .002, .05, .05, {"f1": ff * 1.6, "g": .04}))
			length = 1.8
			rev = .3
		"gather":
			# a mag kibújik: kis „pop”, utána két csillanás
			ops = [_p(600.0, .5, 0, .2, .002, .05, .05, {"f1": 950.0, "g": .06})]
			ops.append(_bell(1318.5, .5, .08, .5, 3.0, 1.0))
			ops.append(_bell(1760.0, .45, .18, .55, 3.0, 1.0))
			length = 1.6
			rev = .3
		"bag":
			# a mag a táskába ér
			ops = [{"k": "k", "f": 587.3, "a": .7, "t": 0.0, "len": .7, "damp": .5, "fb": .99}, _p(500.0, .4, 0, .15, .002, .04, .04, {"f1": 1000.0, "g": .05})]
			length = .9
		# --- alakítás
		"select":
			ops = _glint(1760.0, .45, 0, .05)
			length = .3
			rev = .1
		"snip":
			# metszés: két halk olló-kattanás, fa-koppanás, utána levélzizegés
			ops = [_n(.3, 0, .03, .001, .006, .005, 5000.0, 2000.0), _n(.25, .07, .03, .001, .006, .005, 5000.0, 2000.0),
				_p(330.0, .4, .07, .2, .002, .05), _n(.18, .2, .9, .08, .3, .4, 3500.0, 1200.0, {"gust": .6, "gf": 9.0})]
			length = 1.3
			rev = .2
		"tie":
			# kötözés: lágy, lefelé hajló pengetés
			ops = [{"k": "k", "f": 293.7, "a": .7, "t": 0.0, "len": 1.4, "damp": .4, "fb": .995}, _p(587.3, .3, 0, 1.2, .01, .4, .1, {"f1": 554.4, "g": .6})]
			length = 1.5
		"undo":
			ops = _glint(880.0, .5, 0, .25) + _glint(587.3, .45, .12, .3)
			length = 1.1
		# --- csillagok
		"release":
			# a fa fénnyé válik: lassan duzzadó, felfelé hajló akkord, levegős zaj, emelkedő csillanások
			ops = [_p(587.3, .4, 0, 4.4, 1.6, 0.0, 1.6, {"f1": 659.3, "g": 4.0}), _p(880.0, .3, .3, 4.1, 1.5, 0.0, 1.6, {"f1": 987.8, "g": 3.8}),
				_p(1318.5, .15, .6, 3.8, 1.4, 0.0, 1.4, {"mr": 2.0, "mi": .5, "md": 2.0}), _n(.18, 0, 4.4, 2.0, 0.0, 2.0, 3000.0, 900.0)]
			for i in 8:
				ops.append_array(_glint(semis_hz(degree_semis(5 + i)), .22, 1.4 + i * .32, .35))
			length = 4.8
			rev = .5
		"star":
			# a csillag kigyullad
			var ns := [1480.0, 1760.0, 2349.3, 1975.5, 2960.0]
			for i in ns.size():
				ops.append_array(_glint(ns[i], .45 - i * .05, i * .07, .4))
			ops.append(_p(880.0, .25, 0, 1.6, .02, .7))
			length = 2.2
			rev = .5
		"rise":
			# egy csíra fénnyé válik és felszáll (rövid)
			ops = [_p(700.0, .4, 0, 1.6, .3, 0.0, .6, {"f1": 1760.0, "g": 1.5})]
			ops.append_array(_glint(1760.0, .3, 1.2, .35))
			length = 2.0
			rev = .45
		"recall":
			# visszahozás: lefelé futó csillanások, a végén kis pengetés (a mag)
			var ns := [2349.3, 1975.5, 1760.0, 1480.0, 1174.7]
			for i in ns.size():
				ops.append_array(_glint(ns[i], .35, i * .08, .3))
			ops.append({"k": "k", "f": 587.3, "a": .5, "t": .5, "len": .9, "damp": .5, "fb": .993})
			length = 1.8
			rev = .4
		# --- bolygók
		"hop":
			# átrepülés: puha, emelkedő légsuhogás
			ops = [_n(.6, 0, 2.8, 1.4, 0.0, 1.2, 500.0, 120.0, {"lp1": 2200.0}), _p(220.0, .2, 0, 2.8, 1.2, 0.0, 1.2, {"f1": 330.0, "g": 2.6})]
			length = 3.0
			rev = .3
		"arrive":
			ops = [_bell(587.3, .5, 0, 1.2, 2.0, .7), _bell(880.0, .4, .04, 1.1, 2.0, .6), _bell(1108.7, .2, .08, .9, 2.0, .5)]
			length = 2.6
			rev = .45
		"kindle":
			# a születő bolygó fénypontja kigyúl: egy mély, puha harang
			ops = [_bell(293.7, .8, 0, 2.0, 1.0, 1.2), _p(587.3, .2, 0, 2.5, .3, 1.0)]
			length = 3.0
			rev = .45
		"birth":
			# kibomlik az új bolygó: lassú, mély akkord, felette csillanások
			var ch := [146.8, 220.0, 293.7, 370.0, 440.0]
			for i in ch.size():
				ops.append(_p(ch[i], .4 - i * .03, i * .12, 4.8 - i * .12, 1.0, 2.5, 1.5))
			for i in 6:
				ops.append_array(_glint(semis_hz(degree_semis(6 + i)), .2, .8 + i * .25, .4))
			length = 5.2
			rev = .5
		# --- ambient
		"pad_warm":
			# meleg pad: lassan duzzadó alaphang + 2. és 3. részhang, enyhén elhangolt párral (lassú lebegés)
			sr = 16000
			f = PAD_HZ
			ops = [_p(f, 1.0, 0, 7.0, 2.4, 0.0, 3.2), _p(f * 1.004, .55, 0, 7.0, 2.6, 0.0, 3.2), _p(f * 2.0, .3, 0, 6.6, 2.4, 0.0, 3.0),
				_p(f * 3.0, .1, .2, 6.0, 2.2, 0.0, 2.6)]
			length = 7.2
			rev = .3
		"pad_glass":
			sr = 16000
			f = PAD_HZ
			ops = [_p(f, .9, 0, 7.0, 2.2, 0.0, 3.2, {"mr": 2.0, "mi": .25, "md": 3.0}), _p(f * 2.003, .45, 0, 7.0, 2.6, 0.0, 3.2),
				_p(f * 4.0, .12, .3, 6.0, 2.4, 0.0, 2.6), _p(f * 0.998, .4, 0, 7.0, 2.8, 0.0, 3.2)]
			length = 7.2
			rev = .35
		"cricket":
			# tücsök: 4 puha impulzus egy magas hangon, enyhe lebegéssel
			for i in 4:
				ops.append(_p(3600.0, .7, i * .055, .035, .008, 0.0, .02))
				ops.append(_p(3640.0, .4, i * .055, .035, .008, 0.0, .02))
			length = .45
			rev = .35
		"wind":
			sr = 16000
			ops = [_n(.9, 0, 5.0, 2.0, 0.0, 2.6, 700.0, 140.0, {"gust": .5, "gf": .7, "lp1": 1100.0}), _n(.4, .8, 3.8, 1.6, 0.0, 1.8, 1600.0, 600.0, {"gust": .6, "gf": 1.3})]
			length = 5.2
			rev = .15
		_:
			push_warning("Ismeretlen hang: " + name)
	return {"len": length, "rev": rev, "ops": ops, "sr": sr}


# ---------------------------------------------------------------- Számolás (darabokban)

## Egy minta kiszámolása. step(usec) addig dolgozik, amíg a keret engedi; done = kész, stream = az eredmény.
class Job:
	var name := ""
	var sr := SR
	var rec: Dictionary
	var buf := PackedFloat32Array()
	var n := 0
	var stage := 0
	var op_i := 0
	var st := {}
	var pos := 0
	var peak := 0.0
	var done := false
	var stream: AudioStreamWAV
	var bytes := PackedByteArray()
	var ms := 0.0
	# zengés: 4 fésűszűrő és 2 mindentáteresztő (Schroeder–Freeverb-szerű, kicsiben)
	var cb: Array = []
	var ci := PackedInt32Array()
	var cl := PackedFloat32Array()
	var ab: Array = []
	var ai := PackedInt32Array()

	func _init(sound_name: String) -> void:
		name = sound_name
		rec = SoundSynth.recipe(sound_name)
		sr = int(rec.sr)
		n = int(float(rec.len) * sr)
		buf.resize(n)
		buf.fill(0.0)

	## Dolgozik legfeljebb usec mikroszekundumig (0 = a végéig). Igaz, ha kész.
	func step(usec: int) -> bool:
		var t0 := Time.get_ticks_usec()
		while not done:
			if stage == 0:
				var ops: Array = rec.ops
				if op_i >= ops.size():
					stage = 1
					pos = 0
					continue
				var o: Dictionary = ops[op_i]
				if st.is_empty():
					st = {"j": 0}
				if _op(o, st, 4096):
					op_i += 1
					st = {}
			elif stage == 1:
				if float(rec.rev) <= 0.0:
					stage = 2
					pos = 0
					continue
				if _reverb(4096):
					stage = 2
					pos = 0
			elif stage == 2:
				_measure(8192)
			elif stage == 3:
				_encode(8192)
			if usec > 0 and Time.get_ticks_usec() - t0 >= usec:
				break
		ms += (Time.get_ticks_usec() - t0) / 1000.0
		return done

	func _op(o: Dictionary, s: Dictionary, chunk: int) -> bool:
		var start := int(float(o.t) * sr)
		var total := mini(int(float(o.len) * sr), n - start)
		if total <= 0:
			return true
		var j0 := int(s.j)
		var j1 := mini(j0 + chunk, total)
		match str(o.k):
			"p":
				_partial(o, s, start, j0, j1, total)
			"n":
				_noise(o, s, start, j0, j1, total)
			"k":
				_pluck(o, s, start, j0, j1, total)
		s.j = j1
		return j1 >= total

	## Burkoló: emelkedő koszinusz-felfutás (att), exponenciális lecsengés (dec, időállandó), koszinusz-lecsengés a végén (rel).
	func _partial(o: Dictionary, s: Dictionary, start: int, j0: int, j1: int, total: int) -> void:
		var na := maxi(1, int(float(o.att) * sr))
		var nr := maxi(1, int(float(o.rel) * sr))
		var r0 := total - nr
		var dec := float(o.dec)
		var dk := exp(-1.0 / (dec * sr)) if dec > 0.0 else 1.0
		var f0 := float(o.f)
		var w := float(s.get("w", TAU * f0 / sr))
		var ng := int(float(o.get("g", 0.0)) * sr)
		var wk := pow(float(o.get("f1", f0)) / f0, 1.0 / maxf(1.0, float(ng))) if ng > 0 else 1.0
		var ph := float(s.get("ph", 0.0))
		var e := float(s.get("e", 1.0))
		var a := float(o.a)
		var mr := float(o.get("mr", 0.0))
		var b := buf
		if mr > 0.0:
			var pm := float(s.get("pm", 0.0))
			var mi := float(s.get("mi", o.mi))
			var mk := exp(-1.0 / (float(o.md) * sr))
			for j in range(j0, j1):
				var shape := 1.0
				if j < na:
					shape = .5 - .5 * cos(PI * j / na)
				elif j > r0:
					shape = .5 + .5 * cos(PI * (j - r0) / nr)
				b[start + j] += a * e * shape * sin(ph + mi * sin(pm))
				ph += w
				pm += w * mr
				e *= dk
				mi *= mk
				if j < ng:
					w *= wk
			s.pm = fmod(pm, TAU)
			s.mi = mi
		else:
			for j in range(j0, j1):
				var shape := 1.0
				if j < na:
					shape = .5 - .5 * cos(PI * j / na)
				elif j > r0:
					shape = .5 + .5 * cos(PI * (j - r0) / nr)
				b[start + j] += a * e * shape * sin(ph)
				ph += w
				e *= dk
				if j < ng:
					w *= wk
		s.ph = fmod(ph, TAU)
		s.e = e
		s.w = w

	func _noise(o: Dictionary, s: Dictionary, start: int, j0: int, j1: int, total: int) -> void:
		var na := maxi(1, int(float(o.att) * sr))
		var nr := maxi(1, int(float(o.rel) * sr))
		var r0 := total - nr
		var dec := float(o.dec)
		var dk := exp(-1.0 / (dec * sr)) if dec > 0.0 else 1.0
		var e := float(s.get("e", 1.0))
		var x := int(s.get("x", absi(hash(name + str(op_i))) | 1))
		var l1 := float(s.get("l1", 0.0))
		var l2 := float(s.get("l2", 0.0))
		var hpv := float(s.get("hp", 0.0))
		var lp0 := float(o.lp)
		var lp1 := float(o.get("lp1", lp0))
		var hk := exp(-TAU * float(o.hp) / sr)
		var gust := float(o.get("gust", 0.0))
		var gw := TAU * float(o.get("gf", 1.0)) / sr
		var a := float(o.a)
		var b := buf
		var lk := 0.0
		for j in range(j0, j1):
			if j == j0 or j % 64 == 0:
				var fc := lerpf(lp0, lp1, float(j) / total)
				lk = 1.0 - exp(-TAU * fc / sr)
			x = (x * 1664525 + 1013904223) & 0xffffffff
			var v := float(x) / 2147483648.0 - 1.0
			l1 += lk * (v - l1)
			l2 += lk * (l1 - l2)
			# egypólusú felüláteresztő: a jel mínusz a lassú része
			hpv = hk * hpv + (1.0 - hk) * l2
			var y := l2 - hpv
			var shape := 1.0
			if j < na:
				shape = .5 - .5 * cos(PI * j / na)
			elif j > r0:
				shape = .5 + .5 * cos(PI * (j - r0) / nr)
			if gust > 0.0:
				# lassú, szabálytalan lüktetés (két szinusz összege), mint a széllökés
				shape *= 1.0 - gust * (.5 + .25 * sin(gw * j) + .25 * sin(gw * j * 2.37 + 1.3))
			b[start + j] += a * e * shape * y * 3.0
			e *= dk
		s.e = e
		s.x = x
		s.l1 = l1
		s.l2 = l2
		s.hp = hpv

	func _pluck(o: Dictionary, s: Dictionary, start: int, j0: int, j1: int, total: int) -> void:
		var period := maxi(2, roundi(sr / float(o.f)))
		if not s.has("d"):
			# a húr kezdőállapota: szűrt zaj (a csillapítás puhítja)
			var d := PackedFloat32Array()
			d.resize(period)
			var x := absi(hash(name + "pengetes")) | 1
			var lp := 0.0
			for i in period:
				x = (x * 1664525 + 1013904223) & 0xffffffff
				lp += .5 * ((float(x) / 2147483648.0 - 1.0) - lp)
				d[i] = lp
			# egyenáram nélkül (különben a húr lassan „eltolódik”, és a minta vége nem nulla)
			var mean := 0.0
			for i in period:
				mean += d[i]
			mean /= period
			for i in period:
				d[i] -= mean
			s.d = d
			s.i = 0
			s.prev = 0.0
		var dl: PackedFloat32Array = s.d
		var i := int(s.i)
		var prev := float(s.prev)
		var damp := float(o.damp)
		var fb := float(o.fb)
		var a := float(o.a)
		var nr := maxi(1, int(.08 * sr))
		var r0 := total - nr
		var na := maxi(1, int(.004 * sr))
		var b := buf
		for j in range(j0, j1):
			var y := dl[i]
			var nv := fb * (y * (1.0 - damp * .5) + prev * damp * .5)
			prev = y
			dl[i] = nv
			i = (i + 1) % period
			var shape := 1.0
			if j < na:
				shape = .5 - .5 * cos(PI * j / na)
			elif j > r0:
				shape = .5 + .5 * cos(PI * (j - r0) / nr)
			b[start + j] += a * shape * y * 2.0
		s.i = i
		s.prev = prev

	func _reverb(chunk: int) -> bool:
		var k := float(sr) / 44100.0
		if cb.is_empty():
			for d in [1116, 1188, 1277, 1356]:
				var arr := PackedFloat32Array()
				arr.resize(maxi(8, int(d * k)))
				arr.fill(0.0)
				cb.append(arr)
			ci.resize(4)
			ci.fill(0)
			cl.resize(4)
			cl.fill(0.0)
			for d in [556, 441]:
				var arr := PackedFloat32Array()
				arr.resize(maxi(4, int(d * k)))
				arr.fill(0.0)
				ab.append(arr)
			ai.resize(2)
			ai.fill(0)
		var wet := float(rec.rev)
		var fbk := .8
		var damp := .3
		var b := buf
		var c0: PackedFloat32Array = cb[0]
		var c1: PackedFloat32Array = cb[1]
		var c2: PackedFloat32Array = cb[2]
		var c3: PackedFloat32Array = cb[3]
		var a0: PackedFloat32Array = ab[0]
		var a1: PackedFloat32Array = ab[1]
		var i0 := ci[0]; var i1 := ci[1]; var i2 := ci[2]; var i3 := ci[3]
		var l0 := cl[0]; var l1 := cl[1]; var l2 := cl[2]; var l3 := cl[3]
		var j0 := ai[0]; var j1 := ai[1]
		var end := mini(pos + chunk, n)
		for p in range(pos, end):
			var x := b[p] * .25
			var y0 := c0[i0]; l0 = y0 * (1.0 - damp) + l0 * damp; c0[i0] = x + l0 * fbk; i0 = (i0 + 1) % c0.size()
			var y1 := c1[i1]; l1 = y1 * (1.0 - damp) + l1 * damp; c1[i1] = x + l1 * fbk; i1 = (i1 + 1) % c1.size()
			var y2 := c2[i2]; l2 = y2 * (1.0 - damp) + l2 * damp; c2[i2] = x + l2 * fbk; i2 = (i2 + 1) % c2.size()
			var y3 := c3[i3]; l3 = y3 * (1.0 - damp) + l3 * damp; c3[i3] = x + l3 * fbk; i3 = (i3 + 1) % c3.size()
			var y := y0 + y1 + y2 + y3
			var z := a0[j0]
			a0[j0] = y + z * .5
			y = z - y * .5
			j0 = (j0 + 1) % a0.size()
			z = a1[j1]
			a1[j1] = y + z * .5
			y = z - y * .5
			j1 = (j1 + 1) % a1.size()
			b[p] = b[p] + y * wet
		ci[0] = i0; ci[1] = i1; ci[2] = i2; ci[3] = i3
		cl[0] = l0; cl[1] = l1; cl[2] = l2; cl[3] = l3
		ai[0] = j0; ai[1] = j1
		pos = end
		return pos >= n

	func _measure(chunk: int) -> void:
		var end := mini(pos + chunk, n)
		var b := buf
		for p in range(pos, end):
			peak = maxf(peak, absf(b[p]))
		pos = end
		if pos >= n:
			stage = 3
			pos = 0
			bytes.resize(n * 2)

	## Normálás, puha eleje (3 ms) és vége (40 ms), 16 bites egész.
	func _encode(chunk: int) -> void:
		var g := SoundSynth.PEAK / maxf(peak, 1e-6) * 32767.0
		var nin := maxi(1, int(.003 * sr))
		var nout := maxi(1, int(.04 * sr))
		var o0 := n - nout
		var end := mini(pos + chunk, n)
		var b := buf
		for p in range(pos, end):
			var v := b[p] * g
			if p < nin:
				v *= .5 - .5 * cos(PI * p / nin)
			elif p >= o0:
				v *= .5 + .5 * cos(PI * (p - o0 + 1) / nout)
			bytes.encode_s16(p * 2, clampi(roundi(v), -32767, 32767))
		pos = end
		if pos >= n:
			stream = AudioStreamWAV.new()
			stream.format = AudioStreamWAV.FORMAT_16_BITS
			stream.mix_rate = sr
			stream.stereo = false
			stream.data = bytes
			bytes = PackedByteArray()
			buf = PackedFloat32Array()
			done = true


# ---------------------------------------------------------------- Önellenőrzés (--soundtest)

## Minden minta legenerálása; hossz, csúcs, RMS, az eleje és a vége (kattanás-próba), a számolás ideje.
## dir: ha nem üres, a minták WAV-ként ide, és néhány fa és két bolygó ambientje is (offline keverve).
static func self_test(dir: String) -> String:
	var lines: Array = []
	var streams := {}
	var total_ms := 0.0
	var total_s := 0.0
	var bad := 0
	for nm in ALL:
		var j := Job.new(nm)
		j.step(0)
		var st := j.stream
		streams[nm] = st
		var a := analyze(st)
		total_ms += j.ms
		total_s += float(a.len)
		var ok: bool = float(a.peak) <= .82 and float(a.edge) < .02 and float(a.dc) < .01
		if not ok:
			bad += 1
		lines.append("%-10s %5.2f s  %5d Hz  csúcs %.2f  RMS %.3f  szél %.4f  DC %.4f  %6.1f ms%s" % [nm, a.len, st.mix_rate, a.peak, a.rms, a.edge, a.dc, j.ms, "" if ok else "  HIBA"])
		if dir != "":
			st.save_to_wav(dir.path_join(nm + ".wav"))
	lines.append("összesen %d minta, %.1f s hang, %.0f ms számolás (natívan), %.2f MB, hibás: %d" % [ALL.size(), total_s, total_ms, _bytes(streams) / 1048576.0, bad])
	# különböző DNS-ű fák: a hang (hangszín, alaphang, díszítés) eltér
	var dnas := [[0, 0, 0, 0, 0, 0], [5, 7, 13, 12, 5, 3], [12, 3, 4, 3, 2, 8], [9, 10, 10, 9, 8, 1], [2, 2, 2, 6, 9, 4], [13, 13, 7, 2, 13, 11]]
	for dna in dnas:
		var v := voice(dna, "proba")
		var ev := voice_events(v, "tap")
		var desc: Array = []
		for e in ev:
			desc.append("%s×%.2f@%.2f" % [str(e.s).trim_prefix("v_"), e.p, e.at])
		lines.append("fa %s: %s, fok %d, díszítés %s → %s" % [str(dna), v.family, v.deg, str(v.notes), " ".join(desc)])
		if dir != "":
			var w := mix(ev, streams, 3.0)
			w.save_to_wav(dir.path_join("fa_%s.wav" % "-".join(dna.map(func(x: int) -> String: return str(x)))))
	# két bolygó 40 mp-es ambientje (nappal, illetve éjjel), ugyanazzal a sorozattal, amit a játék használ
	for pl in [["proba-1", [[0, 0, 0, 0, 0, 0], [5, 7, 13, 12, 5, 3], [12, 3, 4, 3, 2, 8]], 0.0], ["proba-2", [[9, 10, 10, 9, 8, 1], [2, 2, 2, 6, 9, 4], [13, 13, 7, 2, 13, 11], [4, 1, 6, 1, 7, 5]], 1.0]]:
		var amb := Ambient.new(pl[0])
		var ev: Array = []
		var t := 1.0
		var count := 0
		while t < 40.0:
			var b := amb.next_breath(pl[1])
			for e in b.ev:
				e.at = float(e.at) + t
				ev.append(e)
				count += 1
			t += float(b.wait)
		var tn := 2.0
		while tn < 40.0:
			var b := amb.next_night() if float(pl[2]) > .5 else amb.next_day()
			for e in b.ev:
				e.at = float(e.at) + tn
				ev.append(e)
			tn += float(b.wait)
		lines.append("ambient %s (%s): akkord %s, %s, %d hang 40 mp alatt" % [pl[0], "éjjel" if float(pl[2]) > .5 else "nappal", str(chord(pl[1], pl[0])), pad_kind(pl[1], pl[0]), count])
		if dir != "":
			mix(ev, streams, 46.0).save_to_wav(dir.path_join("ambient_%s.wav" % pl[0]))
	return "\n".join(lines)


static func _bytes(streams: Dictionary) -> int:
	var s := 0
	for k in streams:
		s += (streams[k] as AudioStreamWAV).data.size()
	return s


## Csúcs, RMS, a minta széle (az első és utolsó minták legnagyobb értéke) és az egyenáramú eltolás, -1–1 skálán.
static func analyze(st: AudioStreamWAV) -> Dictionary:
	var d := st.data
	var n := d.size() / 2
	var peak := 0.0
	var sum := 0.0
	var sum2 := 0.0
	for i in n:
		var v := d.decode_s16(i * 2) / 32768.0
		peak = maxf(peak, absf(v))
		sum += v
		sum2 += v * v
	var edge := 0.0
	for i in mini(4, n):
		edge = maxf(edge, absf(d.decode_s16(i * 2) / 32768.0))
		edge = maxf(edge, absf(d.decode_s16((n - 1 - i) * 2) / 32768.0))
	return {"len": float(n) / st.mix_rate, "peak": peak, "rms": sqrt(sum2 / maxf(1.0, n)), "edge": edge, "dc": absf(sum / maxf(1.0, n))}


## Offline keverés ellenőrzéshez: a hangok (minta, pitch_scale, késleltetés, dB) egy 22 050 Hz-es mono WAV-ba,
## lineáris interpolációval – ugyanúgy, ahogy a lejátszó a pitch_scale-t alkalmazza.
static func mix(events: Array, streams: Dictionary, seconds: float) -> AudioStreamWAV:
	var n := int(seconds * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	for e in events:
		var st: AudioStreamWAV = streams.get(str(e.s))
		if st == null:
			continue
		var d := st.data
		var m := d.size() / 2
		var step := float(e.p) * st.mix_rate / SR
		var g := db_to_linear(float(e.db)) / 32768.0
		var o := int(float(e.at) * SR)
		var x := 0.0
		var i := o
		while i < n and x < m - 1:
			var k := int(x)
			var fr := x - k
			out[i] += g * lerpf(d.decode_s16(k * 2), d.decode_s16(k * 2 + 2), fr)
			x += step
			i += 1
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, clampi(roundi(out[i] * 32767.0), -32767, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.data = bytes
	return w
