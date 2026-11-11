class_name ShareCode
extends RefCounted
## Megosztás (M10): a mag-kód és a bolygó-link – tiszta függvények, szerver nélkül (minden a kódban / linkben utazik).
##
## MAG-KÓD: 11 jel a félreérthető betűk nélküli ábécéből (GameState.CODE_CHARS: nincs 0/O, 1/I/L), kiírva
## „XXXX-XXXX-XXX”. 10 adatjel (31^10 ≈ 8,2·10^14) + 1 ellenőrző jegy. Az adat egy szám:
##   V = (farok · 15 + rejtett szín + 1) · 14^6 + DNS (hat gén, 14-es számrendszerben)
## A farok: 0–4095 = a nap magja, a 2026. 01. 01. utáni napsorszámmal (mindenkinek, aki aznap ugyanazt a DNS-t
## választotta, ugyanaz a kód – mint a Wordle); 4096–8191 tartalék; 8192-től „alak-kulcs” (~7,2 millió féle): a
## megosztott fa vagy mag kódjából (FNV-hash), így ugyanaz a mag/fa mindig ugyanazt a kódot adja.
## A számjegyeket láncolt eltolással keverjük (a DNS kis változása is az egész kódot átírja), az ellenőrző jegy:
## Σ (i+1)·jel_i ≡ 0 (mod 31) – a 31 prím, a súlyok különbözők, így minden egyjegyű elírást és minden két jel
## felcserélését felismeri.
##
## A KÓDBÓL KELŐ FA: a növény alakja a DNS-ből és a növénykódból jön (Genes.from_dna). A mag-kódba nem fér bele a
## megosztó fájának teljes növénykódja (pl. „K7MQ2P-1-3”, ~40 bit), ezért a kódból kapott mag növénykódja maga a
## mag-kód: „MAG-XXXXXXXXXXX”. Így ugyanaz a kód mindenkinél, mindig pontosan ugyanazt a fát adja (DNS, fajnév,
## színek, termet, éjszakai fény, hang, rejtett virágszín azonos); az ágak rajzolata viszont a barátodénál más
## – ahogy a saját fádról gyűjtött mag is új egyed. A bolygó-linkben a fák teljes kódja utazik, ezért a vendég-
## bolygón a fák pontosan olyanok, mint a barátodnál, és a róluk kért mag is pontosan azt a fát adja.
##
## BOLYGÓ-LINK (?bolygo=…): base64url bájtsor. 1. változat:
##   [1] verzió · bolygókód (hossz + UTF-8) · peak · alapítók (darab + 3 bájt/DNS) · fák száma, fánként:
##   DNS (3 bájt, 4 bit/gén) · jelzők (alsó 4 bit: rejtett szín + 1; 16: saját kód; 32: alakítás; 64: kézi forgás/méret)
##   · kód (alapból „<bolygókód>-<hely>”: csak a hely sorszáma, varint; saját kódnál a szöveg) · irány (3 bájt,
##   oktaéderes 12+12 bit) · [forgás, méret 1-1 bájt, ha nem a kódból jön] · [alakítás: darab, és műveletenként
##   fajta, ág, hány napja, kötözésnél két kvaternió 4-4 előjeles bájton] · a végén 2 bájt ellenőrző összeg.
## 30 fa ~260 bájt → ~350 jel (mérés: --sharetest).

const ALPHABET := GameState.CODE_CHARS
const BASE := 31
const DATA_LEN := 10
const CODE_LEN := 11
## 14^6: a hat gén összes változata.
const DNA_N := 7529536
const HID_N := 15
## A nap magjának napjai a farokban: 2026. 01. 01. (napsorszám 20454) és utána 4096 nap.
const DAY_EPOCH := 20454
const DAY_N := 4096
const SHAPE_FROM := 8192
## A kódból kapott mag növénykódjának előtagja.
const TREE_PREFIX := "MAG-"
## A keverés kulcsa (jelenként) és szorzója.
const MIX := [7, 19, 3, 28, 11, 23, 5, 16, 26, 9]
const CHAIN := 7
const LINK_VERSION := 1


# ---------------------------------------------------------------- Mag-kód

static func _pow31(n: int) -> int:
	var x := 1
	for i in n:
		x *= BASE
	return x


## A farok értékkészlete (31^10 / (14^6 · 15)).
static func tail_n() -> int:
	return _pow31(DATA_LEN) / (DNA_N * HID_N)


static func shape_n() -> int:
	return tail_n() - SHAPE_FROM


static func dna_index(dna: Array) -> int:
	var x := 0
	for i in 6:
		x = x * 14 + clampi(int(dna[i]), 0, 13)
	return x


static func dna_of_index(x: int) -> Array:
	var out: Array = []
	out.resize(6)
	for i in range(5, -1, -1):
		out[i] = x % 14
		x /= 14
	return out


## Mag-kód a részeiből. day: a nap magjának napja (-1 = nem napi); shape: alak-kulcs (bármilyen nemnegatív egész,
## a tartományba hajtjuk). Kiírva „XXXX-XXXX-XXX”.
static func encode(dna: Array, hidden: int, day := -1, shape := 0) -> String:
	var tail := 0
	if day >= DAY_EPOCH and day < DAY_EPOCH + DAY_N:
		tail = day - DAY_EPOCH
	else:
		tail = SHAPE_FROM + posmod(shape, shape_n())
	var v := (tail * HID_N + clampi(hidden, -1, 13) + 1) * DNA_N + dna_index(dna)
	var digits: Array = []
	for i in DATA_LEN:
		digits.append(v % BASE)
		v /= BASE
	# láncolt keverés: minden jel az előzőtől is függ
	var out: Array = []
	var prev := 0
	for i in DATA_LEN:
		var c := posmod(int(digits[i]) + prev * CHAIN + int(MIX[i]), BASE)
		out.append(c)
		prev = c
	out.append(_check_digit(out))
	return pretty(_chars(out))


## Az ellenőrző jegy: Σ (i+1)·jel_i ≡ 0 (mod 31), a 11. jel súlya 11 (11·17 ≡ 1, így az inverze 17).
static func _check_digit(d: Array) -> int:
	var s := 0
	for i in DATA_LEN:
		s += (i + 1) * int(d[i])
	return posmod(-s * 17, BASE)


static func _chars(d: Array) -> String:
	var s := ""
	for v in d:
		s += ALPHABET[int(v)]
	return s


## „XXXXXXXXXXX” → „XXXX-XXXX-XXX”.
static func pretty(raw: String) -> String:
	if raw.length() != CODE_LEN:
		return raw
	return "%s-%s-%s" % [raw.substr(0, 4), raw.substr(4, 4), raw.substr(8)]


## Beírt vagy beillesztett szöveg → a kód 11 jele (nagybetűk, szóköz, kötőjel, pont nélkül). Elfogadja a teljes
## linket is (…?mag=KOD). Üres, ha nincs benne értelmes kód-jelölt.
static func normalize(text: String) -> String:
	var s := text.strip_edges()
	var at := s.find("mag=")
	if at >= 0:
		s = s.substr(at + 4)
		var amp := s.find("&")
		if amp >= 0:
			s = s.left(amp)
		var hsh := s.find("#")
		if hsh >= 0:
			s = s.left(hsh)
	s = s.to_upper()
	for ch in [" ", "-", ".", "_", "\t", "\n", "%20", "%2D"]:
		s = s.replace(ch, "")
	return s


## Mag-kód → {"ok", "err" (hibánál, magyarul), "code" (szép alak), "raw", "dna", "hidden", "day" (-1, ha nem napi),
## "shape" (-1, ha napi)}.
static func decode(text: String) -> Dictionary:
	var raw := normalize(text)
	if raw.length() != CODE_LEN:
		return {"ok": false, "err": "A kód 11 jelből áll (pl. ABCD-EFGH-JKM), ez %d." % raw.length()}
	var d: Array = []
	for i in raw.length():
		var k := ALPHABET.find(raw[i])
		if k < 0:
			var hint := ""
			if "0O".contains(raw[i]):
				hint = " (a kódban nincs 0 és O)"
			elif "1IL".contains(raw[i]):
				hint = " (a kódban nincs 1, I és L)"
			return {"ok": false, "err": "A(z) „%s” nem lehet a kódban%s." % [raw[i], hint]}
		d.append(k)
	var s := 0
	for i in CODE_LEN:
		s += (i + 1) * int(d[i])
	if s % BASE != 0:
		return {"ok": false, "err": "A kód nem stimmel: valamelyik jel elírás lehet."}
	var digits: Array = []
	var prev := 0
	for i in DATA_LEN:
		digits.append(posmod(int(d[i]) - prev * CHAIN - int(MIX[i]), BASE))
		prev = int(d[i])
	var v := 0
	for i in range(DATA_LEN - 1, -1, -1):
		v = v * BASE + int(digits[i])
	var dna := dna_of_index(v % DNA_N)
	v /= DNA_N
	var hidden := v % HID_N - 1
	var tail := v / HID_N
	if tail >= DAY_N and tail < SHAPE_FROM:
		return {"ok": false, "err": "Ezt a kódot egy újabb játékváltozat készítette."}
	var out := {"ok": true, "code": pretty(raw), "raw": raw, "dna": dna, "hidden": hidden, "day": -1, "shape": -1}
	if tail < DAY_N:
		out.day = DAY_EPOCH + tail
	else:
		out.shape = tail - SHAPE_FROM
	return out


## A kódból kapott mag növénykódja (ebből és a DNS-ből nő a fa: mindenkinél ugyanaz).
static func tree_code(code: String) -> String:
	return TREE_PREFIX + normalize(code)


## Ha a növénykód kódból kapott magé („MAG-…”), az eredeti mag-kód szép alakja; különben üres.
static func code_of_tree_code(tree_code_s: String) -> String:
	if not tree_code_s.begins_with(TREE_PREFIX):
		return ""
	var raw := tree_code_s.substr(TREE_PREFIX.length())
	var d := decode(raw)
	return str(d.code) if bool(d.ok) else ""


## Stabil (motortól független) 31 bites hash szövegre (FNV-1a), az alak-kulcshoz.
static func str_hash(s: String) -> int:
	return Care.str_hash(s)


## Egy fa mag-kódja (a lebegő tábláról, a herbáriumból, a vendég-bolygóról kért maghoz): DNS + rejtett szín + a
## növénykódból alak-kulcs. A kódból kelt fa a saját kódját adja vissza (körbejárás).
static func for_tree(t: Dictionary) -> String:
	var own := code_of_tree_code(str(t.get("code", "")))
	if own != "":
		return own
	return encode(t.dna, int(t.get("hidden", -1)), -1, str_hash(str(t.get("code", ""))))


## Egy mag mag-kódja (a táskából). A barát magja a kapott kódját adja; a nap magja napi kódot (mindenkinél, aki
## aznap ugyanazt választotta, ugyanazt); a többi a mag kódjából, vagy ha nincs (gyűjtött mag), a játékosból és a mag
## azonosítójából kap alak-kulcsot – így ugyanaz a mag mindig ugyanazt a kódot adja.
static func for_seed(s: Dictionary, player: String) -> String:
	if str(s.get("share", "")) != "":
		return str(s.share)
	var own := code_of_tree_code(str(s.get("code", "")))
	if own != "":
		return own
	if str(s.get("origin", "")) == "napi":
		return encode(s.dna, int(s.get("hidden", -1)), int(s.get("day", -1)), 0)
	var key := str(s.get("code", ""))
	if key == "":
		key = "%s#%d#%s" % [player, int(s.get("id", 0)), str(s.dna)]
	return encode(s.dna, int(s.get("hidden", -1)), -1, str_hash(key))


## A megosztás linkje a játék címével (weben a valódi cím, így a fejlesztői build /fejlesztes/ útvonala is marad).
static func base_url() -> String:
	if OS.has_feature("web"):
		var s := str(JavaScriptBridge.eval("location.origin + location.pathname", true))
		if s.ends_with("index.html"):
			s = s.trim_suffix("index.html")
		if s.begins_with("http"):
			return s
	return "https://csathopeter.github.io/mag-poc/"


static func seed_url(code: String) -> String:
	return "%s?mag=%s" % [base_url(), pretty(normalize(code))]


static func planet_url(link: String) -> String:
	return "%s?bolygo=%s" % [base_url(), link]


# ---------------------------------------------------------------- A nap magja, Wordle-szerűen

## Rövid szöveg a kész napi táblához: dátum, fajnév, 6×6-os emoji-rács spoiler nélkül (⬜ a feladvány adta mező,
## 🟩 amit kikövetkeztettél – az értéke nem látszik –, 🟨/🟪 a szabad sorokban a választásod: A=T / G≡C), a szabad
## sorokban választott változatok neve, és a link (a tábla nyílik vele).
static func daily_text(day: int, dna: Array) -> String:
	var lines: Array = ["Mag · %s · %s" % [GameState.day_label(day), Genes.latin_name(dna)]]
	for row in daily_cells(day, dna):
		var s := ""
		for c in row:
			s += ["⬜", "🟩", "🟨", "🟪"][int(c)]
		lines.append(s)
	var puz := DnaBoard.daily(day)
	var picks: Array = []
	for y in puz.free:
		picks.append("%s: %s" % [(Genes.GENE_NAMES[int(y)] as String).to_lower(), Genes.allele_name(int(y), int(dna[int(y)]))])
	if not picks.is_empty():
		lines.append("Választásom: " + ", ".join(picks))
	return "\n".join(lines)


## A rács mezőnként: 0 = a feladvány adta, 1 = kikövetkeztetett, 2 / 3 = szabad sor, A=T / G≡C.
static func daily_cells(day: int, dna: Array) -> Array:
	var puz := DnaBoard.daily(day)
	var grid := DnaBoard.grid_from_dna(dna)
	var out: Array = []
	for y in DnaBoard.N:
		var row: Array = []
		for x in DnaBoard.N:
			if int(puz.clue[y][x]) != DnaBoard.EMPTY:
				row.append(0)
			elif (puz.free as Array).has(y):
				row.append(2 + int(grid[y][x]))
			else:
				row.append(1)
		out.append(row)
	return out


# ---------------------------------------------------------------- Bolygó-link

## A bolygó linkje (base64url): a kódja, alapítói, a legtöbb fája és a kikelt fák (DNS, rejtett szín, kód, irány,
## alakítás). trees: a kikelt fák a mentés sorrendjében (ebből áll össze a bolygó-DNS).
static func encode_planet(p: Dictionary, trees: Array, today: int) -> String:
	var b := PackedByteArray()
	b.append(LINK_VERSION)
	var pcode := str(p.code)
	_put_str(b, pcode)
	b.append(clampi(int(p.get("peak", 0)), 0, 255))
	var founders: Array = p.get("founders", [])
	_put_var(b, founders.size())
	for f in founders:
		_put_dna(b, f)
	_put_var(b, trees.size())
	for t in trees:
		var code := str(t.code)
		var slot := int(t.get("slot", 0))
		var flags := clampi(int(t.get("hidden", -1)) + 1, 0, 14)
		var own := code != "%s-%d" % [pcode, slot]
		if own:
			flags |= 16
		var shaping: Array = t.get("shaping", [])
		if not shaping.is_empty():
			flags |= 32
		var derived := _rot_size(code)
		var manual := absf(float(t.rot) - derived.x) > 1e-4 or absf(float(t.size) - derived.y) > 1e-4
		if manual:
			flags |= 64
		_put_dna(b, t.dna)
		b.append(flags)
		if own:
			_put_str(b, code)
		else:
			_put_var(b, slot)
		_put_dir(b, t.dir)
		if manual:
			b.append(posmod(roundi(float(t.rot) / TAU * 256.0), 256))
			b.append(clampi(roundi(float(t.size) * 160.0), 0, 255))
		if not shaping.is_empty():
			_put_var(b, shaping.size())
			for e in shaping:
				var tie := str(e.op) == PlantGen.OP_TIE
				b.append(1 if tie else 0)
				_put_var(b, maxi(int(e.branch), 0))
				_put_var(b, clampi(today - int(e.day), 0, 100000))
				if tie:
					_put_quat(b, PlantGen.quat_of(e.from))
					_put_quat(b, PlantGen.quat_of(e.to))
	var h := _bytes_hash(b)
	b.append(h & 255)
	b.append((h >> 8) & 255)
	return Marshalls.raw_to_base64(b).replace("+", "-").replace("/", "_").replace("=", "")


## Bolygó-link → {"ok", "err", "code", "peak", "founders", "trees": [{"dna", "hidden", "code", "slot", "dir", "rot", "size",
## "shaping"}]}. A forgás és a méret, ha nem a linkben jött, a kódból (mint GameState.new_tree).
static func decode_planet(text: String, today: int) -> Dictionary:
	var s := text.strip_edges()
	var at := s.find("bolygo=")
	if at >= 0:
		s = s.substr(at + 7)
		var amp := s.find("&")
		if amp >= 0:
			s = s.left(amp)
	s = s.replace("-", "+").replace("_", "/").replace("%2B", "+").replace("%2F", "/").replace("%3D", "")
	while s.length() % 4 != 0:
		s += "="
	var b := Marshalls.base64_to_raw(s)
	if b.size() < 6:
		return {"ok": false, "err": "A bolygó linkje csonka."}
	var body := b.slice(0, b.size() - 2)
	var h := _bytes_hash(body)
	if b[b.size() - 2] != (h & 255) or b[b.size() - 1] != ((h >> 8) & 255):
		return {"ok": false, "err": "A bolygó linkje sérült (talán nem másolódott ki egészen)."}
	var r := {"b": body, "i": 0, "bad": false}
	if _get_byte(r) != LINK_VERSION:
		return {"ok": false, "err": "Ezt a linket egy újabb játékváltozat készítette."}
	var pcode := _get_str(r)
	var peak := _get_byte(r)
	var founders: Array = []
	for i in mini(_get_var(r), 64):
		founders.append(_get_dna(r))
	var trees: Array = []
	var n := mini(_get_var(r), 64)
	for i in n:
		var dna := _get_dna(r)
		var flags := _get_byte(r)
		var code := ""
		var slot := -1
		if flags & 16:
			code = _get_str(r)
		else:
			slot = _get_var(r)
			code = "%s-%d" % [pcode, slot]
		var dir := _get_dir(r)
		var rs := _rot_size(code)
		if flags & 64:
			rs = Vector2(float(_get_byte(r)) / 256.0 * TAU, float(_get_byte(r)) / 160.0)
		var shaping: Array = []
		if flags & 32:
			for k in mini(_get_var(r), 256):
				var tie := _get_byte(r) == 1
				var e := {"op": PlantGen.OP_TIE if tie else PlantGen.OP_CUT, "branch": _get_var(r)}
				e.day = today - _get_var(r)
				if tie:
					e.from = PlantGen.quat_arr(_get_quat(r))
					e.to = PlantGen.quat_arr(_get_quat(r))
				shaping.append(e)
		trees.append({"dna": dna, "hidden": (flags & 15) - 1, "code": code, "slot": slot, "dir": dir, "rot": rs.x, "size": rs.y, "shaping": shaping})
	if bool(r.bad) or int(r.i) != body.size():
		return {"ok": false, "err": "A bolygó linkje hibás."}
	return {"ok": true, "code": pcode, "peak": peak, "founders": founders, "trees": trees}


## A fa forgása és mérete a kódjából, ugyanúgy, mint GameState.new_tree (a mentett fáknál mindig ez).
static func _rot_size(code: String) -> Vector2:
	var r := RandomNumberGenerator.new()
	r.seed = hash(code + "hely")
	var rot := r.randf() * TAU
	return Vector2(rot, r.randf_range(.5, .72))


static func _bytes_hash(b: PackedByteArray) -> int:
	var h := 2166136261
	for c in b:
		h = ((h ^ c) * 16777619) & 0xffffffff
	return h


static func _put_var(b: PackedByteArray, v: int) -> void:
	v = maxi(v, 0)
	while v >= 128:
		b.append((v & 127) | 128)
		v >>= 7
	b.append(v)


static func _put_str(b: PackedByteArray, s: String) -> void:
	var u := s.to_utf8_buffer()
	_put_var(b, u.size())
	b.append_array(u)


static func _put_dna(b: PackedByteArray, dna: Variant) -> void:
	var d: Array = GameState._dna(dna)
	for i in 3:
		b.append((int(d[i * 2]) << 4) | int(d[i * 2 + 1]))


## Egységvektor oktaéderes vetülete, 12+12 biten (3 bájt; a hiba ~0,05°).
static func _put_dir(b: PackedByteArray, v: Variant) -> void:
	var d: Vector3 = GameState._vec(v)
	if d.length() < 1e-6:
		d = Vector3.UP
	d = d / (absf(d.x) + absf(d.y) + absf(d.z))
	var x := d.x
	var y := d.y
	if d.z < 0.0:
		x = (1.0 - absf(d.y)) * (1.0 if d.x >= 0.0 else -1.0)
		y = (1.0 - absf(d.x)) * (1.0 if d.y >= 0.0 else -1.0)
	var u := clampi(roundi((x * .5 + .5) * 4095.0), 0, 4095)
	var w := clampi(roundi((y * .5 + .5) * 4095.0), 0, 4095)
	b.append(u >> 4)
	b.append(((u & 15) << 4) | (w >> 8))
	b.append(w & 255)


static func _put_quat(b: PackedByteArray, q: Quaternion) -> void:
	q = q.normalized()
	for c in [q.x, q.y, q.z, q.w]:
		b.append(posmod(clampi(roundi(float(c) * 127.0), -127, 127), 256))


static func _get_byte(r: Dictionary) -> int:
	var b: PackedByteArray = r.b
	var i := int(r.i)
	if i >= b.size():
		r.bad = true
		return 0
	r.i = i + 1
	return b[i]


static func _get_var(r: Dictionary) -> int:
	var v := 0
	var sh := 0
	while sh < 35:
		var c := _get_byte(r)
		v |= (c & 127) << sh
		if c < 128 or bool(r.bad):
			return v
		sh += 7
	r.bad = true
	return v


static func _get_str(r: Dictionary) -> String:
	var n := _get_var(r)
	var b: PackedByteArray = r.b
	var i := int(r.i)
	if n > 200 or i + n > b.size():
		r.bad = true
		return ""
	r.i = i + n
	return b.slice(i, i + n).get_string_from_utf8()


static func _get_dna(r: Dictionary) -> Array:
	var out: Array = []
	for i in 3:
		var c := _get_byte(r)
		out.append(mini(c >> 4, 13))
		out.append(mini(c & 15, 13))
	return out


static func _get_dir(r: Dictionary) -> Vector3:
	var b0 := _get_byte(r)
	var b1 := _get_byte(r)
	var b2 := _get_byte(r)
	var u := (b0 << 4) | (b1 >> 4)
	var w := ((b1 & 15) << 8) | b2
	var x := float(u) / 4095.0 * 2.0 - 1.0
	var y := float(w) / 4095.0 * 2.0 - 1.0
	var z := 1.0 - absf(x) - absf(y)
	if z < 0.0:
		var ox := x
		x = (1.0 - absf(y)) * (1.0 if ox >= 0.0 else -1.0)
		y = (1.0 - absf(ox)) * (1.0 if y >= 0.0 else -1.0)
	return Vector3(x, y, z).normalized()


static func _get_quat(r: Dictionary) -> Quaternion:
	var c: Array = []
	for i in 4:
		var v := _get_byte(r)
		c.append(float(v - 256 if v > 127 else v) / 127.0)
	var q := Quaternion(c[0], c[1], c[2], c[3])
	return q.normalized() if q.length() > 1e-4 else Quaternion.IDENTITY


# ---------------------------------------------------------------- Önellenőrzés (--sharetest)

## Mag-kód: körbejárás sok véletlen magra, egyediség, minden egyjegyű elírás és szomszédos csere felismerése, a
## kiírás/beírás változatai; rögzített kódok (ha a formátum véletlenül megváltozna); bolygó-link körbejárás 1–30 fával
## (a hossz mérése), sérült link felismerése; a napi szöveg.
static func self_test(n := 4000) -> String:
	var lines: Array = []
	var ok := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261111
	# --- körbejárás
	var seen := {}
	var bad_rt := 0
	var dup := 0
	for i in n:
		var dna: Array = []
		for k in 6:
			dna.append(rng.randi() % 14)
		var hid := rng.randi_range(-1, 13)
		var daily := rng.randf() < .3
		var day := DAY_EPOCH + rng.randi_range(0, DAY_N - 1) if daily else -1
		var shape := rng.randi_range(0, shape_n() - 1)
		var c := encode(dna, hid, day, shape)
		var d := decode(c)
		if not bool(d.ok) or d.dna != dna or int(d.hidden) != hid or int(d.day) != day or (not daily and int(d.shape) != shape) or str(d.code) != c:
			bad_rt += 1
		var key := "%s|%d|%d|%d" % [str(dna), hid, day, shape if not daily else -1]
		if seen.has(c) and seen[c] != key:
			dup += 1
		seen[c] = key
	lines.append("körbejárás: %d kód, hibás %d, ütköző %d" % [n, bad_rt, dup])
	ok = ok and bad_rt == 0 and dup == 0
	# --- elírások
	var miss_sub := 0
	var miss_swap := 0
	var tries_sub := 0
	var tries_swap := 0
	var codes: Array = seen.keys().slice(0, 400)
	for c in codes:
		var raw := normalize(c)
		for i in CODE_LEN:
			for k in BASE:
				if ALPHABET[k] == raw[i]:
					continue
				var bad := raw.substr(0, i) + ALPHABET[k] + raw.substr(i + 1)
				tries_sub += 1
				if bool(decode(bad).ok):
					miss_sub += 1
			if i < CODE_LEN - 1 and raw[i] != raw[i + 1]:
				var sw := raw.substr(0, i) + raw[i + 1] + raw[i] + raw.substr(i + 2)
				tries_swap += 1
				if bool(decode(sw).ok):
					miss_swap += 1
	lines.append("elírás: %d egyjegyű csere, ebből elfogadva %d; %d szomszédos felcserélés, elfogadva %d" % [tries_sub, miss_sub, tries_swap, miss_swap])
	ok = ok and miss_sub == 0 and miss_swap == 0
	# --- beírási változatok
	var c0 := encode([2, 5, 1, 3, 0, 5], 12, -1, 777)
	var variants := [c0, c0.to_lower(), c0.replace("-", " "), " " + c0.replace("-", "") + " ", "https://csathopeter.github.io/mag-poc/?mag=" + c0 + "&x=1"]
	var var_ok := true
	for v in variants:
		var_ok = var_ok and bool(decode(v).ok) and str(decode(v).code) == c0
	var errs := [decode("ABCD-EFGH"), decode(c0.replace(c0[0], "0")), decode("")]
	for e in errs:
		var_ok = var_ok and not bool(e.ok) and str(e.err) != ""
	lines.append("beírás: kisbetű, szóköz, link → %s; hibaüzenetek: %s" % ["rendben" if var_ok else "HIBA", " / ".join(errs.map(func(e: Dictionary) -> String: return str(e.err)))])
	ok = ok and var_ok
	# --- rögzített kódok (ha ezek megváltoznak, a régi megosztott kódok mást adnának)
	var pinned := {
		encode([2, 5, 1, 3, 0, 5], -1, -1, 0): "2-5-1-3-0-5 alak 0",
		encode([13, 13, 13, 13, 13, 13], 13, -1, shape_n() - 1): "13×6 rejtett 13, utolsó alak",
		encode([0, 0, 0, 0, 0, 0], -1, DAY_EPOCH + 314, 0): "0×6 napi (2026. 11. 11.)",
	}
	lines.append("rögzített: " + ", ".join(pinned.keys().map(func(k: String) -> String: return "%s = %s" % [pinned[k], k])))
	var want := ["K5J8-Y9UQ-483", "RURN-AXXA-47A", "ZVXP-3DDH-QHT"]
	var got: Array = pinned.keys()
	var pin_ok := got == want
	lines.append("rögzített egyezik: %s" % ("igen" if pin_ok else "NEM (várt: %s)" % ", ".join(want)))
	ok = ok and pin_ok
	# --- determinisztikus a magra/fára, és a kódból kelt fa kódja visszaadja ugyanazt
	var sd := {"id": 17, "dna": [4, 2, 9, 0, 7, 3], "origin": "gyujtes", "hidden": 6, "code": ""}
	var sc1 := for_seed(sd, "K7MQ2P")
	var sc2 := for_seed(sd.duplicate(true), "K7MQ2P")
	var tr := {"dna": [4, 2, 9, 0, 7, 3], "hidden": 6, "code": tree_code(sc1)}
	var napi := {"id": 3, "dna": [1, 2, 3, 4, 5, 6], "origin": "napi", "hidden": -1, "day": DAY_EPOCH + 314}
	var det_ok := sc1 == sc2 and for_tree(tr) == sc1 and str(decode(for_seed(napi, "X")).day) == str(DAY_EPOCH + 314) \
		and for_seed(napi, "A") == for_seed(napi, "B") and for_tree({"dna": [4, 2, 9, 0, 7, 3], "hidden": 6, "code": "K7MQ2P-1-3"}) != sc1
	lines.append("determinisztikus, körbejár (mag → kód → fa → kód): %s" % ("igen" if det_ok else "NEM"))
	ok = ok and det_ok
	# --- bolygó-link
	var link_bad := 0
	var lens := {}
	var today := DAY_EPOCH + 314
	for rep in 60:
		var cnt: int = [1, 3, 10, 30][rep % 4]
		var pcode := "%s-%d" % [GameState.random_code(), rng.randi_range(1, 9)]
		var p := {"code": pcode, "peak": rng.randi_range(0, 30), "founders": [[rng.randi() % 14, 1, 2, 3, 4, 5]]}
		var ts: Array = []
		for i in cnt:
			var dna: Array = []
			for k in 6:
				dna.append(rng.randi() % 14)
			var own := rng.randf() < .2
			var slot: int = i * 2 + rng.randi() % 300
			var code := ("%s-K%d-%d" % [pcode, i, rng.randi() % 99]) if own else "%s-%d" % [pcode, slot]
			var rs := _rot_size(code)
			var manual := rng.randf() < .1
			var t := {"dna": dna, "hidden": rng.randi_range(-1, 13), "code": code, "slot": slot,
				"dir": Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized(), "rot": rng.randf() * TAU if manual else rs.x,
				"size": rng.randf_range(.5, .72) if manual else rs.y, "shaping": []}
			if rng.randf() < .15:
				t.shaping.append({"op": PlantGen.OP_CUT, "branch": rng.randi_range(1, 300), "day": today - 2})
				var q := Quaternion(Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized(), rng.randf_range(.1, .8))
				t.shaping.append({"op": PlantGen.OP_TIE, "branch": rng.randi_range(1, 300), "day": today - 1, "from": PlantGen.quat_arr(Quaternion.IDENTITY), "to": PlantGen.quat_arr(q)})
			ts.append(t)
		var link := encode_planet(p, ts, today)
		lens[cnt] = maxi(int(lens.get(cnt, 0)), link.length())
		var g := decode_planet(link, today)
		var same: bool = bool(g.ok) and str(g.code) == pcode and int(g.peak) == int(p.peak) and g.founders == p.founders and (g.trees as Array).size() == cnt
		if same:
			for i in cnt:
				var a: Dictionary = ts[i]
				var bt: Dictionary = g.trees[i]
				var rot_d := absf(wrapf(float(a.rot) - float(bt.rot), -PI, PI))
				same = same and bt.dna == a.dna and int(bt.hidden) == int(a.hidden) and str(bt.code) == str(a.code) \
					and (bt.dir as Vector3).distance_to(a.dir) < .002 and rot_d < .013 and absf(float(bt.size) - float(a.size)) < .004 \
					and (bt.shaping as Array).size() == (a.shaping as Array).size()
				for k in (a.shaping as Array).size():
					var ea: Dictionary = a.shaping[k]
					var eb: Dictionary = bt.shaping[k]
					same = same and str(ea.op) == str(eb.op) and int(ea.branch) == int(eb.branch) and int(ea.day) == int(eb.day)
					if str(ea.op) == PlantGen.OP_TIE:
						same = same and PlantGen.quat_of(ea.to).angle_to(PlantGen.quat_of(eb.to)) < .03
		if not same:
			link_bad += 1
		# sérült link: egy jel átírva
		var k2 := rng.randi_range(0, link.length() - 1)
		var other := "A" if link[k2] != "A" else "B"
		var broken := link.substr(0, k2) + other + link.substr(k2 + 1)
		if bool(decode_planet(broken, today).ok) and broken != link:
			link_bad += 1
	lines.append("bolygó-link: 60 bolygó, hibás %d; a link hossza (jel): %s; a teljes URL 30 fával ~%d jel" % [link_bad,
		", ".join(lens.keys().map(func(k: int) -> String: return "%d fa: %d" % [k, int(lens[k])])), int(lens.get(30, 0)) + planet_url("").length()])
	ok = ok and link_bad == 0
	# a szokásos bolygó: minden fa a saját helyének kódjával, alakítás nélkül (a fenti próba szándékosan nehezebb)
	var plain := {"code": "K7MQ2P-1", "peak": 30, "founders": [[3, 1, 4, 1, 5, 9]]}
	var pts: Array = []
	for i in 30:
		var code := "K7MQ2P-1-%d" % i
		var rs := _rot_size(code)
		pts.append({"dna": [i % 14, (i * 3) % 14, (i * 5) % 14, (i * 7) % 14, (i * 11) % 14, (i * 13) % 14], "hidden": -1, "code": code, "slot": i,
			"dir": Vector3(sin(i), cos(i * 1.7), sin(i * .3)).normalized(), "rot": rs.x, "size": rs.y, "shaping": []})
	var plain_link := encode_planet(plain, pts, today)
	lines.append("szokásos 30 fás bolygó: link %d jel, a teljes URL %d jel" % [plain_link.length(), planet_url(plain_link).length()])
	# --- a nap magja szövegként
	var dtxt := daily_text(today, (DnaBoard.daily(today).target as Array))
	var rows := dtxt.split("\n").slice(1, 7)
	var grid_ok := rows.size() == 6
	for rw in rows:
		grid_ok = grid_ok and (rw as String).length() == 6
	lines.append("napi szöveg (%s):\n    %s" % ["rendben" if grid_ok else "HIBA", dtxt.replace("\n", "\n    ")])
	ok = ok and grid_ok
	lines.append("EREDMÉNY: %s" % ("rendben" if ok else "HIBA"))
	return "\n".join(lines)
