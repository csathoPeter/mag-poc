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
##   active       int      az aktív bolygó indexe a planets tömbben (M7: bolygóváltáskor mentve)
##   planets      Array    bolygók, lásd new_planet(); ha az utolsó megtelt, mellette új születik (ensure_next_planet)
##   bag          Array    magos táska, lásd new_seed()
##   daily        Dict     a nap magja: napsorszám → félkész rács vagy kész jelző és a választott DNS (lásd lent)
##   flags        Dict     apró jelzők (pl. látott bemutatók), bármi, ami nem érdemel saját mezőt
##   cross        Dict     keresztezés (M5): félkész tábla {"a", "b", "grid"}, vagy kész, választásra váró csírák
##                         {"done": true, "a", "b", "parents", "names", "solved", "sprouts": [...]}; üres = nincs
##
## A napok egész számok: a helyi dátum napsorszáma 1970. 01. 01. óta. Mindenhol today()-t használj,
## ne a rendszerórát, hogy a teszt-eltolás mindenre hasson.

## 4 (M6): bolygón "next_star", "peak"; csillagon "seq"; csillagról hozott magon "star_origin", "star_day".
## 5 (M7): bolygón "born_seen" (a születését látta-e már a játékos; a régi mentésben igaz).
## 6 (M10): magon "share" (barát magjánál a kapott mag-kód), "share_day" (ha a barát a nap magját küldte: annak napja),
##    "from" (honnan kaptad, pl. a barát bolygójának neve); flags.got: a már megkapott mag-kódok (kétszer nem jár).
const VERSION := 6
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
##   wipe: a mentés törlése indításkor (új játék), open: "tabla"/"taska" = indításkor nyitva (`?tabla`, `?taska`),
##   "kereszt" = két teszt-mag a kert fáiról és a keresztezett tábla nyitva (`?kereszt`; `?kereszt=kesz`: a tábla
##   rögtön kész, a három csíra látszik); "csillag" = a csillagkép-nézet (herbárium) nyitva, csillag nélkül teszt-csillagokkal
##   (`?csillag`).
##   mag: barát mag-kódja (`?mag=KOD`, M10: a mag a táskába kerül, „Kaptál egy magot”); bolygo: barát bolygójának linkje
##   (`?bolygo=…`, M10: vendégként nézhető, a mentés nem változik).
static func launch_options() -> Dictionary:
	var o := {"state": "", "player": "", "wipe": false, "day": null, "open": "", "mag": "", "bolygo": "", "evszak": ""}
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
			"kereszt":
				o.open = "kereszt=kesz" if v == "kesz" else "kereszt"
			"csillag":
				# a csillagkép-nézet nyitva; ha még nincs csillag, teszt-csillagokkal (M6)
				o.open = "csillag"
			"alakit", "alakitas":
				# leszállás az első fára, alakító mód bekapcsolva (M8, teszteléshez)
				o.open = "alakit"
			"mag":
				o.mag = v.uri_decode()
			"bolygo":
				o.bolygo = v
			"evszak":
				# az évszak rögzítése teszteléshez (M11): tavasz, nyar, osz, tel; auto = a dátum szerint
				o.evszak = v
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
		"cross": {},
	}
	var p := new_planet()
	# az első bolygó születését nem kell megmutatni
	p.born_seen = true
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
		"cross": _fill_cross(d.get("cross", {})),
	}
	for p in d.get("planets", []):
		out.planets.append(_fill_planet(p))
	for s in d.get("bag", []):
		out.bag.append(_fill_seed(s))
	if out.planets.is_empty():
		data = out
		new_planet().born_seen = true
	out.active = clampi(out.active, 0, out.planets.size() - 1)
	return out


# ---------------------------------------------------------------- Bolygók

func planets() -> Array:
	return data.planets


func active_planet() -> Dictionary:
	return data.planets[data.active]


## Új, üres bolygó a listában (kód = játékoskód + sorszám). Az első ültetett fák lesznek az alapítók.
## A születését (M7) a játékos még nem látta: born_seen = hamis (a planet_system.gd mutatja meg, aztán igaz).
func new_planet() -> Dictionary:
	var n: int = data.planets.size() + 1
	var p := _fill_planet({"code": "%s-%d" % [data.player, n], "index": n, "founded": today(), "born_seen": false})
	data.planets.append(p)
	return p


func active_index() -> int:
	return int(data.active)


## Bolygóváltás (M7): ez lesz az aktív bolygó (mentve; újratöltéskor ez nyílik).
func set_active(i: int) -> void:
	data.active = clampi(i, 0, (data.planets as Array).size() - 1)


func planet_index(p: Dictionary) -> int:
	return (data.planets as Array).find(p)


## Ha a legutolsó bolygó megtelt, mellette új, üres bolygó születik (M7). Visszaadja az újat, vagy üreset.
## A régebbi bolygók megmaradnak; ha egy régebbin elengedéssel hely szabadul fel, oda is lehet vetni, de új bolygó
## csak a legutolsó megtelésekor születik.
func ensure_next_planet() -> Dictionary:
	var last: Dictionary = (data.planets as Array).back()
	if is_full(last):
		return new_planet()
	return {}


## Hová hull az elvetett mag (M7): az aktív bolygóra, ha nem telt meg; különben a legújabb, még nem megtelt bolygóra
## (a hívó odarepül vele). A táska, a nap magja és a keresztezés közös; a csillagok bolygónként.
func sow_target() -> int:
	if not is_full(active_planet()):
		return active_index()
	ensure_next_planet()
	var ps: Array = data.planets
	for i in range(ps.size() - 1, -1, -1):
		if not is_full(ps[i]):
			return i
	return active_index()


## A bolygó még alapító fa nélküli, csupasz gömb-e (M7): egy fája sem kelt ki és látszott még, és el sem engedtek
## róla fát. Az első kikelt fa adja meg a jellegét (domborzat, talaj, színek, holdak).
func is_bare(p: Dictionary) -> bool:
	if int(p.get("peak", 0)) > 0:
		return false
	var d := today()
	for t in p.trees:
		if int(t.hatch) <= d and bool(t.revealed):
			return false
	return true

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
		# csillagok (M6): elengedett fák és a keresztezés el nem választott csírái. Ugyanaz a fa-rekord, plusz
		# "released" (a nap) és "seq" (a csillag sorszáma a bolygón: ebből és a bolygókódból jön a helye a csillagképben,
		# így egy csillag visszahozása nem mozdítja el a többit). A bolygó egén csillagképet rajzolnak (sky_stars.gd).
		"stars": [],
		# a következő csillag sorszáma
		"next_star": int(p.get("next_star", 0)),
		# az eddigi legtöbb kikelt fa (M6): a bolygó ehhez méreteződik, így elengedéskor nem zsugorodik össze
		"peak": int(p.get("peak", 0)),
		# a születését látta-e már a játékos (M7; a régi mentésben és az első bolygónál igaz)
		"born_seen": bool(p.get("born_seen", true)),
	}
	for t in p.get("trees", []):
		out.trees.append(_fill_tree(t))
	for t in p.get("stars", []):
		var s := _fill_tree(t)
		s.released = int((t as Dictionary).get("released", today()))
		s.seq = int((t as Dictionary).get("seq", -1))
		out.stars.append(s)
	# régi (v3) mentés: a csillagok sorszáma a lista sorrendjéből
	for s in out.stars:
		if int(s.seq) < 0:
			s.seq = out.next_star
		out.next_star = maxi(int(out.next_star), int(s.seq) + 1)
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
		# alakítási lista (M8, plant_gen.gd apply_shaping, shaping.gd): [{"op": "metszes"/"kotozes", "branch": az ág
		# indexe (a generálás sorrendje), "day": a művelet napja}], kötözésnél "from" / "to" (az ág elfordulása a tövénél,
		# kvaternió [x, y, z, w], az ág eredeti keretében: a kötözéskori állás és a cél) és "prev" (újrakötésnél a régi
		# kötés, a visszavonáshoz). Nem öröklődik: a magból kikelő fa üres listával indul.
		"shaping": _shaping(t.get("shaping", [])),
		"name": str(t.get("name", "")),
		# lappangó virágszín (M5, rejtett gén; -1 = a virágszínéhez tartozó alapérték, lásd Breeding.LATENT)
		"hidden": clampi(int(t.get("hidden", -1)), -1, 13),
	}


## Az alakítási lista a mentésből (a JSON a számokat lebegőpontosnak adja vissza: itt egészre / tömbre igazítjuk, és a
## hibás bejegyzéseket kihagyjuk).
static func _shaping(v: Variant) -> Array:
	var out: Array = []
	if not (v is Array):
		return out
	for e in v:
		var x := _shape_entry(e)
		if not x.is_empty():
			out.append(x)
	return out


static func _shape_entry(e: Variant) -> Dictionary:
	if not (e is Dictionary):
		return {}
	var d: Dictionary = e
	var op := str(d.get("op", ""))
	if op != PlantGen.OP_CUT and op != PlantGen.OP_TIE:
		return {}
	var x := {"op": op, "branch": int(d.get("branch", -1)), "day": int(d.get("day", 0))}
	if op == PlantGen.OP_TIE:
		x.from = PlantGen.quat_arr(PlantGen.quat_of(d.get("from")))
		x.to = PlantGen.quat_arr(PlantGen.quat_of(d.get("to")))
		var prev := _shape_entry(d.get("prev"))
		if not prev.is_empty():
			x.prev = prev
	return x


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


## Elengedés (M6): a fa csillag lesz a bolygó egén (nincs halál, bármikor visszahozható). A csillag a fa teljes
## rekordja (DNS, kód, név, rejtett szín, eredet, ültetés és kikelés napja), plusz az elengedés napja és a sorszáma.
## A helye a bolygón felszabadul. A bolygó-DNS ezután a megmaradt fákból áll össze; a darabos jelleg (domborzat,
## felszíntakaró, holdak) és a domborzat magassága a mentett alapítókból jön, így az alapító elengedése után is
## ugyanaz marad, és a bolygó sem zsugorodik (peak). Visszaadja a csillagot.
func release_tree(p: Dictionary, t: Dictionary) -> Dictionary:
	p.peak = maxi(int(p.peak), hatched(p).size())
	p.trees.erase(t)
	var s := t.duplicate(true)
	s.released = today()
	s.seq = _take_star(p)
	if str(s.name) == "":
		s.name = Genes.latin_name(s.dna)
	p.stars.append(s)
	return s


func find_star(p: Dictionary, id: int) -> Dictionary:
	for s in p.stars:
		if int(s.id) == id:
			return s
	return {}


## Visszahozás az égről (M6): a csillagból mag lesz a táskában (eredet „csillag”, a csillag DNS-ével, kódjával – így
## elvetve pontosan ugyanaz a fa nő ki –, szüleivel és rejtett színével); a csillag eltűnik az égről. Ha újra
## elengeded, új csillag lesz belőle (új sorszámmal, új helyen a csillagképben). Visszaadja a magot.
func recall_star(p: Dictionary, id: int) -> Dictionary:
	var st := find_star(p, id)
	if st.is_empty():
		return {}
	p.stars.erase(st)
	return new_seed((st.dna as Array).duplicate(), "csillag", {"parents": (st.parents as Array).duplicate(true), "code": str(st.code),
		"hidden": int(st.hidden), "star_origin": str(st.origin), "star_day": int(st.released)})


func _take_star(p: Dictionary) -> int:
	var i := int(p.get("next_star", 0))
	p.next_star = i + 1
	return i


## Teszt („+csillag” gomb, --shot ...,sky…): n csillag az aktív bolygó egén véletlen (a játékoskódból és a sorszámból
## determinisztikus) DNS-sel, eredet „teszt”. A fák nem változnak.
func debug_stars(n: int) -> Array:
	var p := active_planet()
	var out: Array = []
	for i in n:
		var r := RandomNumberGenerator.new()
		r.seed = hash("%s-csillag-%d" % [data.player, int(p.get("next_star", 0))])
		var dna: Array = []
		for k in 6:
			dna.append(r.randi() % 14)
		out.append(add_star(p, {"dna": dna, "code": "%s-C%d" % [p.code, int(p.get("next_star", 0))], "origin": "teszt", "planted": today() - 1 - r.randi() % 9}))
	return out


## Teszt („tele” gomb, --shot ...,birth/system/hop…): a bolygót feltölti kikelt, már látott fákkal (véletlen, a
## játékoskódból és a hely sorszámából determinisztikus DNS), amíg upto fája nem lesz; ha ezzel az utolsó bolygó megtelt,
## mellette új bolygó születik. Visszaadja az új fák számát.
func debug_fill(p: Dictionary, upto: int) -> int:
	var n := 0
	while (p.trees as Array).size() < upto:
		var r := RandomNumberGenerator.new()
		r.seed = hash("%s-%s-tele-%d" % [data.player, p.code, int(p.next_tree)])
		var dna: Array = []
		for k in 6:
			dna.append(r.randi() % 14)
		var t := new_tree(p, dna, "teszt")
		t.planted = today() - 1 - r.randi() % 6
		t.hatch = t.planted + 1
		t.revealed = true
		place_tree(p, t)
		if (p.founders as Array).is_empty():
			p.founders = [dna.duplicate()]
		n += 1
	ensure_next_planet()
	return n


func find_tree(id: int) -> Dictionary:
	for p in data.planets:
		for t in p.trees:
			if int(t.id) == id:
				return t
	return {}


# ---------------------------------------------------------------- Magos táska

## Új mag a táskába. origin: "napi" (a nap magja), "gyujtes" (virágzó fáról), "keresztezes", "csillag", "barat" (M10).
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
		# lappangó virágszín (M5, rejtett gén; -1 = a virágszínéhez tartozó alapérték, lásd Breeding.LATENT)
		"hidden": clampi(int(s.get("hidden", -1)), -1, 13),
		# csillagról hozott magnál (M6): a csillag eredete (pl. „csira”, „napi”) és az elengedés napja; máskor üres / -1
		"star_origin": str(s.get("star_origin", "")),
		"star_day": int(s.get("star_day", -1)),
		# barát magja (M10): a kapott mag-kód (szép alakban), a nap magjánál annak napja, és honnan jött (pl. bolygónév)
		"share": str(s.get("share", "")),
		"share_day": int(s.get("share_day", -1)),
		"from": str(s.get("from", "")),
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
## Visszaadja a fa-rekordot, vagy üreset, ha a bolygó megtelt. Ha ezzel az utolsó bolygó megtelt, mellette új
## bolygó születik (ensure_next_planet; a születés látványa: planet_system.gd).
func sow_seed(seed: Dictionary) -> Dictionary:
	var p := active_planet()
	if is_full(p):
		return {}
	# a keresztezett magnak saját kódja van (a csíráé): pontosan az a fa nő ki, amit a választáskor láttál
	var t := new_tree(p, (seed.dna as Array).duplicate(), str(seed.origin), str(seed.code))
	t.parents = (seed.parents as Array).duplicate(true)
	t.hidden = int(seed.hidden)
	place_tree(p, t)
	if (p.founders as Array).is_empty():
		p.founders = [(seed.dna as Array).duplicate()]
	remove_seed(int(seed.id))
	ensure_next_planet()
	return t


# ---------------------------------------------------------------- Barát magja (M10; a kód: share_code.gd)

## Megkaptad-e már ezt a mag-kódot (a táskában van, vagy már elvetetted). Ugyanaz a kód kétszer nem jár.
func has_gift(code: String) -> bool:
	return (data.flags.get("got", []) as Array).has(code)


## Barát magja a táskába (eredet „barat”): DNS, rejtett szín, növénykód (a kódból kapottnál „MAG-…”, a barát
## bolygójáról kértnél a fa saját kódja), a mag-kód. Üres, ha ezt a kódot már megkaptad.
func receive_seed(code: String, dna: Array, hidden: int, tree_code: String, share_day := -1, from := "") -> Dictionary:
	if code == "" or has_gift(code):
		return {}
	var got: Array = data.flags.get("got", [])
	got.append(code)
	data.flags.got = got
	return new_seed(dna.duplicate(), "barat", {"code": tree_code, "hidden": hidden, "share": code, "share_day": share_day, "from": from})


# ---------------------------------------------------------------- Gondozás (a szabályok: care.gd)

## Öntözés: a fa ma kapott vizet (felegyenesedik). Nincs vízszámláló, bármikor, bármennyiszer.
func water_tree(t: Dictionary) -> void:
	t.watered = today()


## Maggyűjtés virágzó fáról: a mag a táskába kerül (a fa DNS-ével, eredet: „gyujtes”, szülő: a fa), a fa ma már nem
## hoz többet. at: a virág helye a növény saját koordinátáiban (az a virág aznap elhalványul). Üres, ha ma nem hozhat.
func gather_seed(t: Dictionary, at: Vector3) -> Dictionary:
	if not Care.can_gather(t, today(), garden_of(t)):
		return {}
	t.gathered = today()
	t.gathered_at = at
	return _seed_of(t)


func _seed_of(t: Dictionary) -> Dictionary:
	var dna: Array = (t.dna as Array).duplicate()
	return new_seed(dna, "gyujtes", {"parents": [dna.duplicate()], "tree": int(t.id), "name": "%s magja" % Genes.latin_name(dna),
		"hidden": Breeding.latent(t)})


## A kert a maghozás tempójához (Care.can_gather): a játékos összes bolygójának kikelt fái (M8: közös, így több
## bolygóval sem jön több mag – napi kb. 1–3 összesen). Üres, ha a fa nincs a mentésben.
func garden_of(t: Dictionary) -> Array:
	var found := false
	var out: Array = []
	for p in data.planets:
		if not found and (p.trees as Array).has(t):
			found = true
		out.append_array(hatched(p))
	return out if found else []


## Teszt („+2 mag” gomb, --shot ...,cross…): n gyűjtött mag a táskába a bolygó kikelt fáiról, egymás után más-más
## fáról (a virágzástól függetlenül; a fák állapota nem változik).
func debug_seeds(n: int) -> Array:
	var ts := hatched(active_planet())
	var out: Array = []
	if ts.is_empty():
		return out
	var start := (data.bag as Array).size()
	for i in n:
		out.append(_seed_of(ts[(start + i) % ts.size()]))
	return out


# ---------------------------------------------------------------- Keresztezés (M5; a szabályok: breeding.gd)

func _fill_cross(c: Variant) -> Dictionary:
	if not (c is Dictionary) or (c as Dictionary).is_empty():
		return {}
	var d: Dictionary = c
	if not bool(d.get("done", false)):
		var g: Array = []
		if d.get("grid") is Array and (d.grid as Array).size() == 36:
			for v in d.grid:
				g.append(clampi(int(v), -1, 1))
		return {"a": int(d.get("a", -1)), "b": int(d.get("b", -1)), "grid": g}
	var sp: Array = []
	for x in d.get("sprouts", []):
		var o: Dictionary = x
		sp.append({"dna": _dna(o.get("dna")), "hidden": clampi(int(o.get("hidden", -1)), -1, 13), "shows_hidden": bool(o.get("shows_hidden", false)),
			"code": str(o.get("code", "")), "marks": (o.get("marks", []) as Array).map(func(m: Variant) -> String: return str(m)), "name": str(o.get("name", ""))})
	if sp.size() != Breeding.SPROUTS:
		return {}
	return {"done": true, "day": int(d.get("day", today())), "a": int(d.get("a", -1)), "b": int(d.get("b", -1)), "parents": _dna_list(d.get("parents", [])),
		"names": (d.get("names", ["", ""]) as Array).map(func(m: Variant) -> String: return str(m)), "solved": _dna(d.get("solved")), "sprouts": sp}


## Választásra váró csírák (a tábla kész, a két mag már elfogyott), vagy üres.
func pending_sprouts() -> Dictionary:
	return data.cross if bool((data.cross as Dictionary).get("done", false)) else {}


## A félkész keresztezett tábla (6×6), ha épp ezt a párt kezdte el; különben üres.
func cross_progress(a_id: int, b_id: int) -> Array:
	var c: Dictionary = data.cross
	if bool(c.get("done", false)) or int(c.get("a", -1)) != a_id or int(c.get("b", -1)) != b_id or (c.get("grid", []) as Array).size() != 36:
		return []
	var g: Array = []
	for y in 6:
		g.append((c.grid as Array).slice(y * 6, y * 6 + 6))
	return g


func set_cross_progress(a_id: int, b_id: int, grid: Array) -> void:
	if not pending_sprouts().is_empty():
		return
	var flat: Array = []
	for r in grid:
		for v in r:
			flat.append(int(v))
	data.cross = {"a": a_id, "b": b_id, "grid": flat}


## Kész a keresztezett tábla: a két mag elfogy, a három csíra a mentésbe kerül (választásig ott vár, újratöltés után is).
func finish_cross(a_id: int, b_id: int, solved: Array) -> Dictionary:
	var a := find_seed(a_id)
	var b := find_seed(b_id)
	if a.is_empty() or b.is_empty():
		return {}
	var sp := Breeding.sprouts(a, b, solved, "%s-K%d-%d" % [data.player, a_id, b_id])
	data.cross = {"done": true, "day": today(), "a": a_id, "b": b_id, "parents": [(a.dna as Array).duplicate(), (b.dna as Array).duplicate()],
		"names": [seed_name(a), seed_name(b)], "solved": solved.duplicate(), "sprouts": sp}
	remove_seed(a_id)
	remove_seed(b_id)
	return data.cross


## A k-adik csíra lesz a mag (a táskába: eredet „keresztezes”, a két szülő DNS-e, a csíra kódja és lappangó színe);
## a másik kettő csillag lesz az aktív bolygó egén (eredet „csira” = a keresztezés el nem választott csírája).
func choose_sprout(k: int) -> Dictionary:
	var c := pending_sprouts()
	if c.is_empty():
		return {}
	var sp: Array = c.sprouts
	var ch: Dictionary = sp[k]
	var s := new_seed((ch.dna as Array).duplicate(), "keresztezes", {"parents": (c.parents as Array).duplicate(true), "code": ch.code, "hidden": int(ch.hidden)})
	for i in sp.size():
		if i == k:
			continue
		var o: Dictionary = sp[i]
		add_star(active_planet(), {"dna": (o.dna as Array).duplicate(), "code": o.code, "origin": "csira", "parents": (c.parents as Array).duplicate(true),
			"hidden": int(o.hidden), "name": str(o.name)})
	data.cross = {}
	return s


## Új csillag a bolygó egén (fa-rekord hely nélkül, plusz "released" = ma és a sorszáma); a csillagkép: sky_stars.gd.
func add_star(p: Dictionary, rec: Dictionary) -> Dictionary:
	var base := {"id": _take_id(), "planted": today(), "hatch": today()}
	base.merge(rec, true)
	var st := _fill_tree(base)
	st.released = today()
	st.seq = _take_star(p)
	if str(st.name) == "":
		st.name = Genes.latin_name(st.dna)
	p.stars.append(st)
	return st


## A mag neve a felülethez (gyűjtöttnél „<fajnév> magja”, máskor a fajnév).
static func seed_name(s: Dictionary) -> String:
	return str(s.name) if str(s.get("name", "")) != "" else Genes.latin_name(s.dna)


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


## A kész nap választott DNS-e (a megosztáshoz, M10), vagy üres tömb.
func daily_dna(day: int) -> Array:
	var d := _daily(day)
	return _dna(d.dna) if bool(d.get("done", false)) and d.get("dna") is Array else []


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
