class_name Care
extends RefCounted
## A gondozás szabályai, tiszta függvényekként a fa-rekordon (state.gd) és a napon: szomjazás, virágzási ciklus,
## maggyűjtés. Nincs halál és büntetés: a szomjas fa csak lekonyul (és nem hoz magot), egy öntözéstől feléled.
## Minden a napsorszámból és a fa kódjából / helyéből jön, így determinisztikus és motorfüggetlen.
##
## Virágzási ciklus (CYCLE = 9 nap): bimbó (BUD_DAYS = 2) → virágzás (3 vagy 4 nap, a fa kódjából) → elnyílás
## (WILT_DAYS = 1) → pihenés (1–2 nap). A kezdő fáknál a ciklus eltolása a hely sorszámából jön (slot × 3 + slot / 3),
## így egymás után virágoznak: már a 3 kezdő fa közül is minden nap virágzik egy (de nem mind). A kikelt fák
## első bimbója a kikelés után YOUTH_DAYS + (slot mod 3) nappal jön (2–4 nap), utána 9 naponta.

const THIRST_DAYS := 3
const CYCLE := 9
const BUD_DAYS := 2
const WILT_DAYS := 1
const YOUTH_DAYS := 2

## A szakaszok (a felirat és a shader-paraméterek ebből jönnek).
const YOUNG := "fiatal"
const REST := "pihen"
const BUD := "bimbos"
const BLOOM := "virágzik"
const WILT := "elnyilt"


## Egyszerű, motorfüggetlen szöveg-hash (FNV-1a, 31 bit), hogy minden eszközön ugyanaz legyen.
static func str_hash(s: String) -> int:
	var h := 2166136261
	for c in s.to_utf8_buffer():
		h = ((h ^ c) * 16777619) & 0xffffffff
	return h & 0x7fffffff


static func bloom_len(t: Dictionary) -> int:
	return 3 + (str_hash(str(t.get("code", ""))) >> 5) % 2


## A ciklus eltolása: a kezdő fáknál a hely sorszámából (egymás után virágoznak), az elvetett magokból kikelt fáknál
## úgy, hogy az első bimbó 2–4 nappal a kikelés után jöjjön (a kikelés napja úgyis eltér fánként).
static func offset(t: Dictionary) -> int:
	var slot := int(t.get("slot", 0))
	if str(t.get("origin", "")) == "kezdo":
		return posmod(slot * 3 + slot / 3, CYCLE)
	return posmod(-(int(t.get("hatch", 0)) + YOUTH_DAYS + slot % 3), CYCLE)


## Az utolsó öntözés napja (ha még soha, a kikelésé).
static func last_water(t: Dictionary) -> int:
	var w := int(t.get("watered", -1))
	return w if w >= 0 else int(t.get("hatch", 0))


static func dry_days(t: Dictionary, day: int) -> int:
	return maxi(0, day - last_water(t))


static func thirsty(t: Dictionary, day: int) -> bool:
	return dry_days(t, day) >= THIRST_DAYS


## A lekonyulás mértéke (0 = egyenes, 1 = teljesen lekonyult): a 3. száraz naptól, lassan erősödik.
static func droop(t: Dictionary, day: int) -> float:
	var d := dry_days(t, day)
	if d < THIRST_DAYS:
		return 0.0
	return minf(1.0, .75 + .125 * float(d - THIRST_DAYS))


## Az első bimbó napja (a kezdő fáknál nincs ilyen korlát).
static func first_bud(t: Dictionary) -> int:
	if str(t.get("origin", "")) == "kezdo":
		return -(1 << 40)
	var earliest := int(t.get("hatch", 0)) + YOUTH_DAYS
	# a ciklus szerinti első bimbó-kezdés legalább ezen a napon
	var p := posmod(earliest + offset(t), CYCLE)
	return earliest if p == 0 else earliest + (CYCLE - p)


## A fa szakasza egy napon: {"kind": YOUNG/REST/BUD/BLOOM/WILT, "i": hányadik napja a szakasznak (0-tól),
## "left": hány nap van még hátra belőle (a mait is beleértve), "next": hány nap múlva bimbózik újra (REST, YOUNG, WILT)}.
static func stage(t: Dictionary, day: int) -> Dictionary:
	var fb := first_bud(t)
	if day < fb:
		return {"kind": YOUNG, "i": 0, "left": fb - day, "next": fb - day}
	var p := posmod(day + offset(t), CYCLE)
	var bl := bloom_len(t)
	if p < BUD_DAYS:
		return {"kind": BUD, "i": p, "left": BUD_DAYS - p, "next": 0}
	if p < BUD_DAYS + bl:
		return {"kind": BLOOM, "i": p - BUD_DAYS, "left": BUD_DAYS + bl - p, "next": CYCLE - p}
	if p < BUD_DAYS + bl + WILT_DAYS:
		return {"kind": WILT, "i": 0, "left": 1, "next": CYCLE - p}
	return {"kind": REST, "i": 0, "left": CYCLE - p, "next": CYCLE - p}


static func gathered_today(t: Dictionary, day: int) -> bool:
	return int(t.get("gathered", -1)) == day


## Tempó (M5): a kert egészében naponta kb. 1–3 mag legyen, akárhány fa van. Sok fánál nem minden virágzó fa hoz
## magot: a nap „magot érlelő” fái a virágzó fák közül az első K a fa kódjából és a napból számolt sorrendben
## (determinisztikus, minden nap más fák). K ≈ 0,4 + 0,6·√n (n = a bolygó kikelt fái), legfeljebb 3; a tört részt
## a nap dönti el (pl. 1,44 → hol 1, hol 2). 3 fánál így minden virágzó fa hoz, 10 fánál ~2,3, 30 fánál 3.
## A szomjas fa is lehet a kiválasztott, de csak öntözés után ad magot (újabb ok a gondozásra).
const SEEDS_MAX := 3.0


## Ennyi mag a cél naponta n kikelt fánál.
static func seeds_per_day(n: int) -> float:
	return minf(SEEDS_MAX, .4 + .6 * sqrt(float(maxi(n, 1))))


## A nap magot érlelő fáinak kódjai a kert (a bolygó kikelt fái) közül.
static func bearers(garden: Array, day: int) -> Array:
	var bloom: Array = []
	for t in garden:
		if stage(t, day).kind == BLOOM:
			bloom.append([str_hash("%s:mag:%d" % [str(t.get("code", "")), day]), str(t.get("code", ""))])
	bloom.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	var target := seeds_per_day(garden.size())
	var k := floori(target + float(str_hash("nap:%d" % day) % 1000) / 1000.0)
	var out: Array = []
	for i in mini(k, bloom.size()):
		out.append(bloom[i][1])
	return out


## Érlel-e ma magot a fa (virágzik, és a kertben épp ő a nap magot érlelő fái között). garden: a bolygó kikelt fái
## (üres = nincs korlát, pl. önellenőrzésben).
static func bears_seed(t: Dictionary, day: int, garden: Array = []) -> bool:
	if stage(t, day).kind != BLOOM:
		return false
	if garden.is_empty():
		return true
	return bearers(garden, day).has(str(t.get("code", "")))


## Hozhat-e ma magot: virágzik, nem szomjas, ma még nem szedtél róla (naponta fánként egy – a természet a korlát),
## és a kertben épp ő érlel ma magot (bears_seed).
static func can_gather(t: Dictionary, day: int, garden: Array = []) -> bool:
	return not thirsty(t, day) and not gathered_today(t, day) and bears_seed(t, day, garden)


## A virágok kinézete a shadernek: size (0 = nincs virág), open (0 = zárt bimbó, 1 = nyílt, >1 = szétterül),
## fade (hervadás: fakóbb, barnás), drop (a virágok ekkora része már lehullott).
static func flower_look(t: Dictionary, day: int) -> Dictionary:
	var st := stage(t, day)
	var out := {"size": 0.0, "open": 1.0, "fade": 0.0, "drop": 0.0}
	match st.kind:
		BUD:
			out.size = .46 if int(st.i) == 0 else .62
			out.open = 0.0 if int(st.i) == 0 else .14
		BLOOM:
			out.size = 1.0
			out.open = .88 if int(st.i) == 0 else 1.0
		WILT:
			out.size = .9
			out.open = 1.15
			out.fade = .8
			out.drop = .55
	if thirsty(t, day) and float(out.size) > 0.0:
		# a szomjas fa virágai félig becsukódnak és fakóbbak
		out.open = float(out.open) * .55
		out.fade = maxf(float(out.fade), .35)
	return out


## Rövid állapot a lebegő táblára (a fa neve alatt). garden: a bolygó kikelt fái (a maghozáshoz).
static func status_text(t: Dictionary, day: int, garden: Array = []) -> String:
	if thirsty(t, day):
		return "szomjas\nkoppints rá, és megöntözöd"
	var st := stage(t, day)
	var s := ""
	match st.kind:
		YOUNG:
			s = "fiatal · %s bimbózik" % _when(int(st.next))
		REST:
			s = "pihen · %s bimbózik" % _when(int(st.next))
		BUD:
			s = "bimbós · %s kinyílik" % _when(int(st.left))
		BLOOM:
			s = "virágzik (ma még)" if int(st.left) <= 1 else "virágzik (még %d napig)" % int(st.left)
			if gathered_today(t, day):
				s += " · magot hozott ma"
			elif bears_seed(t, day, garden):
				s += "\nkoppints egy virágra: mag"
			else:
				s += "\nma nem érlelt magot"
		WILT:
			s = "elnyílt · %s újra bimbózik" % _when(int(st.next))
	return s


static func _when(days: int) -> String:
	return "holnap" if days <= 1 else "%d nap múlva" % days
