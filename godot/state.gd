class_name GameState
extends RefCounted
## A játék teljes, megmaradó állapota: játékos, bolygók és fáik, csillagok (elengedett fák), magos táska, napok.
## JSON-ként mentjük a user:// alá (weben ez IndexedDB). Minden változás után azonnal mentünk (save()),
## mert weben a böngésző bármikor bezárhatja a lapot.
##
## Adatszerkezet (a mezőnevek angolul, mert a kód is így hivatkozik rájuk):
##   version      int      a mentés formátuma (migrate() hozza fel a régieket)
##   player       String   játékoskód, első indításkor véletlen (pl. "K7MQ2P")
##   created      int      az első indítás napja (napsorszám, lásd today())
##   day_offset   int      teszt-eltolás napokban (?nap=+1, debug-gomb); 0 = valódi nap
##   next_id      int      a következő egyedi azonosító (fák, magok)
##   active       int      az aktív bolygó indexe a planets tömbben
##   planets      Array    bolygók, lásd new_planet()
##   bag          Array    magos táska, lásd new_seed()
##   daily        Dict     a nap magja: napsorszám → félkész rács vagy kész jelző és a választott DNS (lásd lent)
##   flags        Dict     apró jelzők (pl. látott bemutatók), bármi, ami nem érdemel saját mezőt
##
## A napok egész számok: a helyi dátum napsorszáma 1970. 01. 01. óta. Mindenhol today()-t használj,
## ne a rendszerórát, hogy a teszt-eltolás mindenre hasson.

const VERSION := 2
const SAVE_PATH := "user://mag_mentes.json"
const BACKUP_SUFFIX := ".bak"
## Ennyi fa fér egy bolygóra (teljesítménykeret); utána új bolygó születik.
const PLANET_FULL := 30
## Ennyi kezdő fa van az első bolygón.
const START_TREES := 3
## Félreérthető betűk (0/O, 1/I/L) nélkül, hogy telefonon könnyű legyen bediktálni.
const CODE_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

## A teszt-eltolás minden today()-hívásra hat; a betöltéskor a mentésből és az URL-ből áll be.
static var day_offset := 0

var data: Dictionary = {}
## Hová mentünk; üres = sehová (pl. --shot, --bench, próba-bolygó: ott nem írunk mentést).
var path := SAVE_PATH
var persist := true
## Hány mentés történt ebben a futásban (ellenőrzéshez).
var save_count := 0


# ---------------------------------------------------------------- Napok

## A helyi dátum napsorszáma (1970. 01. 01. = 0), eltolás nélkül.
static func real_day() -> int:
	var d := Time.get_date_dict_from_system()
	var t := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 0, "minute": 0, "second": 0})
	return int(floor(float(t) / 86400.0))


## A játék „mai” napja: a valódi nap + a teszt-eltolás. Minden napfüggő funkció (kikelés, öntözés, a nap magja) ezt használja.
static func today() -> int:
	return real_day() + day_offset


## Napsorszámból olvasható dátum, pl. „2026. 11. 10.”.
static func day_label(day: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(day * 86400)
	return "%d. %02d. %02d." % [d.year, d.month, d.day]


# ---------------------------------------------------------------- Indítási kapcsolók

## Kapcsolók a parancssorból (`-- --state=fájl --player=KOD --nap=+1 --uj`) és weben az URL-ből (`?nap=+1`, `?uj`, `?jatekos=KOD`).
##   state: a mentés helye a user:// helyett (teszteléshez), player: a játékoskód új játéknál,
##   day: teszt-eltolás napokban (null = nincs megadva; a mentésbe is bekerül, `?nap=0` állítja vissza),
##   wipe: a mentés törlése indításkor (új játék), open: "tabla"/"taska" = indításkor nyitva (`?tabla`, `?taska`).
static func launch_options() -> Dictionary:
	var o := {"state": "", "player": "", "wipe": false, "day": null, "open": ""}
	var pairs: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			pairs.append(a.substr(2))
	if OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval("location.search", true))
		for part in q.trim_prefix("?").split("&", false):
			pairs.append(part)
	for kv in pairs:
		var k: String = (kv as String).get_slice("=", 0)
		var v: String = (kv as String).substr(k.length() + 1)
		match k:
			"state":
				o.state = v
			"player", "jatekos":
				o.player = v.to_upper()
			"uj":
				o.wipe = true
			"tabla", "taska":
				# indításkor nyitva: a mai DNS-tábla vagy a magos táska (teszteléshez)
				o.open = k
			"nap":
				# a „+” az URL-ben szóközként is megérkezhet
				o.day = v.replace("%2B", "").replace("+", "").strip_edges().to_int()
	return o


# ---------------------------------------------------------------- Betöltés, mentés

## Betölti a mentést, vagy ha nincs (vagy hibás), újat kezd. Visszaadja, hogy új játék indult-e.
func load_or_new(player_code := "") -> bool:
	var loaded := _read(path)
	if loaded.is_empty():
		loaded = _read(path + BACKUP_SUFFIX)
	if not loaded.is_empty():
		if int(loaded.get("version", 0)) > VERSION:
			# újabb játékverzió mentése (pl. a böngésző egy régi buildet töltött be): megmutatjuk, de nem írjuk felül
			push_warning("A mentés újabb verziójú (%d > %d), nem írom felül." % [int(loaded.version), VERSION])
			persist = false
		data = migrate(loaded)
		day_offset = int(data.day_offset)
		return false
	new_game(player_code)
	save()
	return true


## Új játék: új játékoskód, első bolygó a kezdő fákkal (a játékoskódból determinisztikusan).
func new_game(player_code := "") -> void:
	day_offset = 0
	data = {
		"version": VERSION,
		"player": player_code if player_code != "" else random_code(),
		"created": real_day(),
		"day_offset": 0,
		"next_id": 1,
		"active": 0,
		"planets": [],
		"bag": [],
		"daily": {},
		"flags": {},
	}
	var p := new_planet()
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(data.player) + "kezdo")
	var dnas: Array = []
	for i in START_TREES:
		var dna: Array = []
		for k in 6:
			dna.append(r.randi() % 14)
		# a kezdő fák ne legyenek bokrok, hogy az első bolygón legyen mit nézni
		while dna[3] >= 9 and dna[3] <= 11:
			dna[3] = r.randi() % 14
		dnas.append(dna)
	p.founders = dnas.duplicate(true)
	for dna in dnas:
		var t := new_tree(p, dna, "kezdo")
		# a kezdő fák már kint vannak, mintha tegnap kelt volna ki
		t.planted = today() - 1
		t.hatch = today() - 1
		t.revealed = true
		place_tree(p, t)


## Mentés a beállított helyre (ha van). Weben a fájl bezárása indítja az IndexedDB-szinkront.
func save() -> void:
	if not persist or path == "" or data.is_empty():
		return
	data.day_offset = day_offset
	var txt := JSON.stringify(_plain(data), "", false, true)
	for p in [path, path + BACKUP_SUFFIX]:
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f == null:
			push_warning("Mentés sikertelen: %s (%s)" % [p, error_string(FileAccess.get_open_error())])
			continue
		f.store_string(txt)
		f.close()
	save_count += 1


## A mentés törlése (teszteléshez). Utána new_game() vagy load_or_new() indít újat.
func wipe() -> void:
	for p in [path, path + BACKUP_SUFFIX]:
		if path != "" and FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	data = {}


func _read(p: String) -> Dictionary:
	if p == "" or not FileAccess.file_exists(p):
		return {}
	var txt := FileAccess.get_file_as_string(p)
	var v: Variant = JSON.parse_string(txt)
	if v is Dictionary and (v as Dictionary).has("planets"):
		return v
	push_warning("Hibás mentés: %s" % p)
	return {}


## Régi mentés felhozása az aktuális formátumra, és a JSON-ból jött számok visszaalakítása (a JSON-ban minden szám float).
## Új mező bevezetésekor: VERSION += 1, és itt add hozzá az alapértéket; a hiányzó mezőket a _fill_* pótolja.
func migrate(d: Dictionary) -> Dictionary:
	var out := {
		"version": VERSION,
		"player": str(d.get("player", random_code())),
		"created": int(d.get("created", real_day())),
		"day_offset": int(d.get("day_offset", 0)),
		"next_id": int(d.get("next_id", 1)),
		"active": int(d.get("active", 0)),
		"planets": [],
		"bag": [],
		"daily": d.get("daily", {}) if d.get("daily") is Dictionary else {},
		"flags": d.get("flags", {}) if d.get("flags") is Dictionary else {},
	}
	for p in d.get("planets", []):
		out.planets.append(_fill_planet(p))
	for s in d.get("bag", []):
		out.bag.append(_fill_seed(s))
	if out.planets.is_empty():
		data = out
		new_planet()
	out.active = clampi(out.active, 0, out.planets.size() - 1)
	return out


# ---------------------------------------------------------------- Bolygók

func planets() -> Array:
	return data.planets


func active_planet() -> Dictionary:
	return data.planets[data.active]


## Új, üres bolygó a listában (kód = játékoskód + sorszám). Az első ültetett fák lesznek az alapítók.
func new_planet() -> Dictionary:
	var n: int = data.planets.size() + 1
	var p := _fill_planet({"code": "%s-%d" % [data.player, n], "index": n, "founded": today()})
	data.planets.append(p)
	return p


func _fill_planet(p: Dictionary) -> Dictionary:
	var out := {
		"code": str(p.get("code", "")),
		"index": int(p.get("index", 1)),
		"founded": int(p.get("founded", today())),
		# az alapításkori növények DNS-e: a darabos tulajdonságok (domborzat, holdak, felszíntakaró) és a domborzat magassága
		# ezekből jön, és nem változik, akkor sem, ha az alapító fát később elengedik
		"founders": _dna_list(p.get("founders", [])),
		"next_tree": int(p.get("next_tree", 0)),
		"trees": [],
		# elengedett fák: ugyanaz a fa-rekord, plusz "released" (a nap); a bolygó egén csillagképet rajzolnak
		"stars": [],
	}
	for t in p.get("trees", []):
		out.trees.append(_fill_tree(t))
	for t in p.get("stars", []):
		var s := _fill_tree(t)
		s.released = int((t as Dictionary).get("released", today()))
		out.stars.append(s)
	if out.founders.is_empty() and not out.trees.is_empty():
		out.founders = [(out.trees[0].dna as Array).duplicate()]
	return out


## A bolygó megtelt-e (a kelésre váró magokkal együtt).
func is_full(p: Dictionary) -> bool:
	return (p.trees as Array).size() >= PLANET_FULL


# ---------------------------------------------------------------- Fák

## Új fa-rekord (még nincs helye: place_tree() adja, és hozzá is adja a bolygóhoz).
## origin: honnan jött ("kezdo", "ultetes", később "napi", "keresztezes", "csillag").
func new_tree(p: Dictionary, dna: Array, origin: String, code := "") -> Dictionary:
	var i: int = p.next_tree
	p.next_tree = i + 1
	var tree_code := code if code != "" else "%s-%d" % [p.code, i]
	var r := RandomNumberGenerator.new()
	r.seed = hash(tree_code + "hely")
	return _fill_tree({
		"id": _take_id(),
		"dna": dna,
		"code": tree_code,
		"slot": i,
		"rot": r.randf() * TAU,
		"size": r.randf_range(.5, .72),
		"origin": origin,
		"planted": today(),
		# másnap kel ki (a DESIGN szerint minden elvetett mag); a hívó felülírhatja
		"hatch": today() + 1,
	})


func _fill_tree(t: Dictionary) -> Dictionary:
	var planted := int(t.get("planted", today()))
	var dir: Variant = t.get("dir")
	return {
		"id": int(t.get("id", 0)),
		"dna": _dna(t.get("dna", [0, 0, 0, 0, 0, 0])),
		# növénykód: a DNS-sel együtt ez határozza meg a fa alakját (determinisztikus)
		"code": str(t.get("code", "")),
		# a hely sorszáma a bolygón (ebből és a bolygókódból jön az irány); "dir" a végleges, mentett irány
		"slot": int(t.get("slot", 0)),
		"dir": _vec(dir) if dir != null else Vector3.ZERO,
		"rot": float(t.get("rot", 0.0)),
		"size": float(t.get("size", .6)),
		"origin": str(t.get("origin", "")),
		"parents": _dna_list(t.get("parents", [])),
		"planted": planted,
		# a kikelés napja: addig a mag a földben van, a fa nem látszik, és nem számít a bolygó-DNS-be
		"hatch": int(t.get("hatch", planted + 1)),
		# a kikelés-animációt látta-e már a játékos
		"revealed": bool(t.get("revealed", false)),
		# utolsó öntözés napja (-1 = még soha; ilyenkor az ültetés napja számít)
		"watered": int(t.get("watered", -1)),
		# maggyűjtés: melyik napon szedtél róla utoljára (-1 = még soha), és melyik virágáról (a növény saját
		# koordinátáiban; az a virág elhalványul aznap) – naponta fánként legfeljebb egy mag
		"gathered": int(t.get("gathered", -1)),
		"gathered_at": _vec(t.get("gathered_at")) if t.get("gathered_at") != null else Vector3.ZERO,
		# alakítási lista (metszés, kötözés): [{"op": "metszes"/"kotozes", "branch": int, "day": int, ...}]
		"shaping": (t.get("shaping", []) as Array).duplicate(true) if t.get("shaping") is Array else [],
		"name": str(t.get("name", "")),
	}


## Hely a fának a bolygón (a bolygókódból és a hely sorszámából, a többi fától távol), és hozzáadás a bolygóhoz.
## A kelésre váró magok helye is foglalt.
func place_tree(p: Dictionary, t: Dictionary) -> void:
	var taken: Array = []
	for o in p.trees:
		taken.append(o.dir)
	t.dir = Planet.spot_for(p.code, int(t.slot), taken, Planet.radius_for(hatched(p).size() + 1))
	p.trees.append(t)


## A már kikelt (látható) fák a bolygón; ezek adják a bolygó-DNS-t.
func hatched(p: Dictionary) -> Array:
	var out: Array = []
	var d := today()
	for t in p.trees:
		if int(t.hatch) <= d:
			out.append(t)
	return out


## Elengedés: a fa csillag lesz a bolygó egén (nincs halál, bármikor visszahozható).
func release_tree(p: Dictionary, t: Dictionary) -> void:
	p.trees.erase(t)
	var s := t.duplicate(true)
	s.released = today()
	p.stars.append(s)


func find_tree(id: int) -> Dictionary:
	for p in data.planets:
		for t in p.trees:
			if int(t.id) == id:
				return t
	return {}


# ---------------------------------------------------------------- Magos táska

## Új mag a táskába. origin: "napi" (a nap magja), "gyujtes" (virágzó fáról), "keresztezes", "csillag".
func new_seed(dna: Array, origin: String, extra := {}) -> Dictionary:
	var s := _fill_seed({"id": _take_id(), "dna": dna, "origin": origin, "day": today()})
	s.merge(extra, true)
	data.bag.append(s)
	return s


func _fill_seed(s: Dictionary) -> Dictionary:
	return {
		"id": int(s.get("id", 0)),
		"dna": _dna(s.get("dna", [0, 0, 0, 0, 0, 0])),
		"origin": str(s.get("origin", "")),
		# a mag napja (a nap magjánál: melyik nap feladványa; gyűjtésnél: mikor szedted)
		"day": int(s.get("day", today())),
		# a szülők DNS-e (gyűjtött magnál: az anyafa DNS-e; keresztezésnél a két szülőé)
		"parents": _dna_list(s.get("parents", [])),
		"code": str(s.get("code", "")),
		# gyűjtött magnál: az anyafa azonosítója és a mag neve („<fajnév> magja”); máskor -1 és üres
		"tree": int(s.get("tree", -1)),
		"name": str(s.get("name", "")),
	}


func find_seed(id: int) -> Dictionary:
	for s in data.bag:
		if int(s.id) == id:
			return s
	return {}


func remove_seed(id: int) -> void:
	for s in data.bag:
		if int(s.id) == id:
			data.bag.erase(s)
			return


## Elvetés: a mag DNS-ével új fa az aktív bolygón, holnap kel ki (a DESIGN szerint minden elvetett mag másnap).
## Visszaadja a fa-rekordot, vagy üreset, ha a bolygó megtelt.
func sow_seed(seed: Dictionary) -> Dictionary:
	var p := active_planet()
	if is_full(p):
		return {}
	var t := new_tree(p, (seed.dna as Array).duplicate(), str(seed.origin))
	t.parents = (seed.parents as Array).duplicate(true)
	place_tree(p, t)
	if (p.founders as Array).is_empty():
		p.founders = [(seed.dna as Array).duplicate()]
	remove_seed(int(seed.id))
	return t


# ---------------------------------------------------------------- Gondozás (a szabályok: care.gd)

## Öntözés: a fa ma kapott vizet (felegyenesedik). Nincs vízszámláló, bármikor, bármennyiszer.
func water_tree(t: Dictionary) -> void:
	t.watered = today()


## Maggyűjtés virágzó fáról: a mag a táskába kerül (a fa DNS-ével, eredet: „gyujtes”, szülő: a fa), a fa ma már nem
## hoz többet. at: a virág helye a növény saját koordinátáiban (az a virág aznap elhalványul). Üres, ha ma nem hozhat.
func gather_seed(t: Dictionary, at: Vector3) -> Dictionary:
	if not Care.can_gather(t, today()):
		return {}
	t.gathered = today()
	t.gathered_at = at
	var dna: Array = (t.dna as Array).duplicate()
	return new_seed(dna, "gyujtes", {"parents": [dna.duplicate()], "tree": int(t.id), "name": "%s magja" % Genes.latin_name(dna)})


# ---------------------------------------------------------------- A nap magja
#
# data.daily: napsorszám (szövegként) → {"grid": [36 érték, -1 = üres]} amíg folyamatban van,
#   kész nap: {"done": true, "dna": [...], "solved": nap}. A régi, folyamatban lévő rácsokat a prune_daily() törli.

## Ennyi nappal korábbi megfejtetlen feladványok várnak még a táskában (a mai mellett).
const DAILY_BACK := 7


func _daily(day: int) -> Dictionary:
	var v: Variant = data.daily.get(str(day))
	return v if v is Dictionary else {}


func daily_done(day: int) -> bool:
	return bool(_daily(day).get("done", false))


## A félig kitöltött rács (6×6, -1 = üres), vagy üres tömb, ha még nem kezdte el.
func daily_progress(day: int) -> Array:
	var flat: Variant = _daily(day).get("grid")
	if not (flat is Array) or (flat as Array).size() != 36:
		return []
	var g: Array = []
	for y in 6:
		var r: Array = []
		for x in 6:
			r.append(clampi(int(flat[y * 6 + x]), -1, 1))
		g.append(r)
	return g


func set_daily_progress(day: int, grid: Array) -> void:
	if daily_done(day):
		return
	var flat: Array = []
	for r in grid:
		for v in r:
			flat.append(int(v))
	data.daily[str(day)] = {"grid": flat}


## Kész a nap feladványa: a mag a táskába kerül (eredet: „napi”, a feladvány napjával), és a nap késznek számít.
func finish_daily(day: int, dna: Array) -> Dictionary:
	data.daily[str(day)] = {"done": true, "dna": dna.duplicate(), "solved": today()}
	prune_daily()
	return new_seed(dna, "napi", {"day": day})


## A még megfejtetlen napok, a maival kezdve, legfeljebb DAILY_BACK nappal visszamenőleg (de nem a játék kezdete elé).
func daily_open_days() -> Array:
	var out: Array = []
	var d := today()
	var first := maxi(d - DAILY_BACK, int(data.created))
	for day in range(d, first - 1, -1):
		if not daily_done(day):
			out.append(day)
	return out


## A régi, már nem elérhető napok félkész rácsai törlődnek (a kész napok jelzője megmarad, kicsi).
func prune_daily() -> void:
	var limit := today() - DAILY_BACK
	for k in data.daily.keys():
		var e: Variant = data.daily[k]
		if int(k) < limit and not (e is Dictionary and bool((e as Dictionary).get("done", false))):
			data.daily.erase(k)


# ---------------------------------------------------------------- Segédek

static func random_code() -> String:
	var s := ""
	for i in 6:
		s += CODE_CHARS[randi() % CODE_CHARS.length()]
	return s


func _take_id() -> int:
	var i: int = data.next_id
	data.next_id = i + 1
	return i


static func _dna(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			out.append(clampi(int(x), 0, 13))
	while out.size() < 6:
		out.append(0)
	return out


static func _dna_list(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for d in v:
			out.append(_dna(d))
	return out


## Mentéshez: a Vector3-ak [x, y, z] tömbbé alakítva (a JSON nem ismeri őket).
static func _plain(v: Variant) -> Variant:
	if v is Vector3:
		return [v.x, v.y, v.z]
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _plain(v[k])
		return out
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(_plain(x))
		return out
	return v


## A JSON-ban a vektor [x, y, z] tömb; a memóriában Vector3.
static func _vec(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is Array and (v as Array).size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	if v is String:
		# a JSON.stringify a Vector3-at "(x, y, z)" szöveggé alakítaná: ezt is elfogadjuk
		var parts := (v as String).trim_prefix("(").trim_suffix(")").split(",")
		if parts.size() == 3:
			return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	return Vector3.UP
