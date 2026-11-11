class_name Playtest
extends Node
## Végigjátszás fej nélkül (M13, `--playtest`): egy friss, külön mentéssel (user://playtest_mentes.json – a valódi
## mentéshez nem nyúl) a valódi bemeneteken (egér- és érintés-események a gombokra, a fákra, a táblára) és a játék saját
## útvonalain (a fejlesztői gombok függvényei) át végigvisz egy több napos játékot:
##   nap magja (tábla kitöltése koppintásokkal) → spirál → táska → Elvetem → nap +1 → kikelés → öntözés → maggyűjtés →
##   keresztezés („Később”, újratöltés, „Választok”, „Ezt nevelem”) → elengedés (közben koppintás) → visszahozás →
##   alakítás (levágás, kötözés, visszavonás, csípés kifelé) → megtelés, új bolygó → elvetés a megtelt bolygóról
##   (átrepülés) → csupasz bolygó kikelése → az utolsó fa elengedése (0 fa) → bolygóváltás koppintással → mag-kód →
##   barát magja (kétszer) → vendég-bolygó („Magot kérek”, „Vissza a kertembe”) → éjféli napváltás nyitott appnál
##   (nyitott táblával is) → kész, de be nem fejezett tábla a mentésben → teljes újratöltés.
## Minden lépés után ellenőrzi az invariánsokat: a mentés újraolvasva (migrate) bitre ugyanaz, mint a memóriában (azaz
## minden változás mentve van, és semmi nem vész el a betöltéskor), az azonosítók egyediek, a bolygók nincsenek túltöltve,
## a jelenetben a kikelt fák látszanak, a magok / fák / csillagok száma a várt, és nem jött hibaüzenet (Logger).
## Futtatás: `godot --headless --fixed-fps 30 -- --playtest` (a --fixed-fps nélkül is fut, csak valós időben).
## A vége: `EREDMÉNY: rendben`, vagy a hibák listája.

const PATH := "user://playtest_mentes.json"
const MAX_WAIT := 4000

var host
var fails: Array = []
var notes: Array = []
var _step := 0
var _log := ErrLog.new()
var _seen_errors := 0
## Őrkutya: ha a forgatókönyv (korutin) megáll – pl. szkripthiba miatt –, ennyi ms után kilépünk a hibával.
const STALL_MS := 90000
var _beat := 0
var _done := false


## A motor hibaüzenetei (push_error, szkripthiba, shader-hiba): a figyelmeztetéseket külön számoljuk.
class ErrLog extends Logger:
	var errors: Array = []
	var warnings: Array = []
	var _m := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var msg := "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]
		_m.lock()
		if error_type == ERROR_TYPE_WARNING:
			warnings.append(msg)
		else:
			errors.append(msg)
		_m.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ready() -> void:
	_beat = Time.get_ticks_msec()
	run.call_deferred()


func _process(_delta: float) -> void:
	if not _done and Time.get_ticks_msec() - _beat > STALL_MS:
		_fail("a forgatókönyv megállt (szkripthiba?): %s" % (_log.errors.back() if not _log.errors.is_empty() else "nincs hibaüzenet"))
		_finish()


# ---------------------------------------------------------------- A forgatókönyv

func run() -> void:
	OS.add_logger(_log)
	var game: GameState = host.game
	var opts := GameState.launch_options()
	opts.state = PATH
	opts.wipe = true
	opts.player = "PROBA1"
	opts.day = 0
	opts.open = ""
	opts.mag = ""
	opts.bolygo = ""
	opts.debug = null
	host._load_game(opts)
	game = host.game
	await _settle("indulás")
	_check("új játék: 1 bolygó, 3 kezdő fa, üres táska", {"planets": 1, "trees0": 3, "bag": 0, "stars0": 0})
	# üres táska (csak a mai mag vár benne), 0 csillag: a csillagjel rejtve
	await _press(host.hud.pouch)
	_expect(host.bag.visible, "a batyura koppintva nyílik a táska")
	await _close_bag()
	_expect(not host.herb.chip.visible, "csillag nélkül nincs csillagjel")

	# --- 1. nap: a nap magja a fénylő magra koppintva, kitöltés koppintásokkal, spirál, táska
	await _solve_daily()
	_check("a nap magja megfejtve: mag a táskában", {"bag": 1, "trees0": 3})
	var napi := _bag_of("napi")
	if not napi.is_empty():
		await _bag_click(int(napi.id), "Elvetem")
		await _settle("elvetés")
	_check("elvetve: 4 fa (egy a földben), üres táska", {"bag": 0, "trees0": 4})

	# --- 2. nap: kikelés
	await _next_day()
	var sown: Dictionary = game.active_planet().trees.back()
	_expect(bool(sown.revealed) and int(sown.hatch) <= GameState.today(), "a tegnapi mag kikelt és látszott (revealed)")
	_check("nap +1: kikelés", {"trees0": 4})

	# --- öntözés: két nap múlva a kezdő fák szomjasak
	await _next_day()
	await _next_day()
	var thirsty := _find_tree(func(t: Dictionary) -> bool: return Care.thirsty(t, GameState.today()))
	_expect(not thirsty.is_empty(), "a 3. napon van szomjas fa")
	if not thirsty.is_empty():
		await _water(thirsty)
		_expect(int(thirsty.watered) == GameState.today(), "öntözés: watered = ma")
	await _water_all()
	_check("öntözés", {"trees0": 4})

	# --- maggyűjtés: amíg nincs magot érlelő fa, napokat léptetünk (és öntözünk)
	var bearer := {}
	for k in 12:
		await _water_all()
		bearer = _find_tree(func(t: Dictionary) -> bool: return Care.can_gather(t, GameState.today(), game.garden_of(t)))
		if not bearer.is_empty():
			break
		await _next_day()
	_expect(not bearer.is_empty(), "12 napon belül van magot érlelő fa")
	if not bearer.is_empty():
		var before := (game.data.bag as Array).size()
		await _gather(bearer)
		_check("maggyűjtés", {"bag": before + 1})
		# naponta fánként egy: még egy koppintás nem hoz újat
		await _gather(bearer)
		_check("maggyűjtés másodszor ugyanaznap: nincs új mag", {"bag": before + 1})

	# --- keresztezés: a mai nap magja + a gyűjtött mag
	await _solve_daily()
	var g1 := _bag_of("gyujtes")
	var n1 := _bag_of("napi")
	var stars_before: int = (game.active_planet().stars as Array).size()
	var bag_before: int = (game.data.bag as Array).size()
	if not g1.is_empty() and not n1.is_empty():
		host.open_bag()
		await _frames(3)
		await _bag_click(int(g1.id), "Keresztezem")
		await _bag_click(int(n1.id), "Ezzel")
		await _frames(3)
		_expect(host.crossing.board_open and host.board.visible, "a keresztezett tábla nyitva")
		await _play_board()
		await _until(func() -> bool: return host.crossing.is_open(), "a három csíra")
		await _frames(10)
		await _click(host.crossing.pick, "Később")
		await _settle("Később")
		_check("keresztezés: a két mag elfogyott, a csírák a mentésben várnak", {"bag": bag_before - 2})
		_expect(not game.pending_sprouts().is_empty(), "választásra váró csírák")
		host.open_bag()
		await _frames(3)
		await _click(host.bag, "Választok")
		await _until(func() -> bool: return host.crossing.is_open(), "a három csíra újra")
		await _frames(10)
		var want_code: String = str(game.pending_sprouts().sprouts[1].code) if not game.pending_sprouts().is_empty() else "?"
		await _click(host.crossing.pick, "Ezt nevelem", 1)
		await _until(func() -> bool: return host.bag.visible, "a táska a spirál után")
		await _close_bag()
		await _settle("csíraválasztás")
		_check("csíraválasztás: mag a táskába, két csillag", {"bag": bag_before - 1, "stars0": stars_before + 2})
		var kx := _bag_of("keresztezes")
		_expect(str(kx.get("code", "")) == want_code, "a keresztezett mag a választott csíra kódjával")
		_expect(game.pending_sprouts().is_empty(), "nincs több várakozó csíra")
		if not kx.is_empty():
			host.open_bag()
			await _frames(3)
			await _bag_click(int(kx.id), "Elvetem")
			await _settle("keresztezett mag elvetése")
		_check("keresztezett mag elvetve", {"trees0": 5})

	# --- elengedés (közben koppintás: gyorsít) és visszahozás
	var rel: Dictionary = _find_tree(func(t: Dictionary) -> bool: return int(t.hatch) <= GameState.today() and str(t.origin) == "kezdo")
	var trees_before: int = (game.active_planet().trees as Array).size()
	stars_before = (game.active_planet().stars as Array).size()
	if not rel.is_empty():
		await _land(rel)
		await _until(func() -> bool: return float(host.tag_alpha) > .6, "a lebegő tábla")
		await _click(host.herb, "Elengedem…")
		await _click(host.herb, "Elengedem")
		await _frames(20)
		_touch(Vector2(200, 300))
		await _until(func() -> bool: return not host.stars.busy(), "az elengedés vége")
		await _until(func() -> bool: return host.herb.card_open(), "a csillag lapja")
		_check("elengedés: a fa csillag lett", {"trees0": trees_before - 1, "stars0": stars_before + 1})
		var st: Dictionary = game.find_star(game.active_planet(), host.herb.star_id)
		_expect(str(st.get("code", "")) == str(rel.code), "a csillag a fa kódjával")
		bag_before = (game.data.bag as Array).size()
		await _click(host.herb, "Visszahozom")
		await _until(func() -> bool: return host.herb._flying.is_empty(), "a mag útja a táskába")
		await _settle("visszahozás")
		_check("visszahozás: mag a táskában, a csillag eltűnt", {"bag": bag_before + 1, "stars0": stars_before})
		var cs := _bag_of("csillag")
		_expect(str(cs.get("code", "")) == str(rel.code), "a csillagról hozott mag a fa kódjával")

	# --- alakítás: levágás, kötözés, visszavonás, kilépés; csípés kifelé alakító módban
	var sh: Dictionary = _find_tree(func(t: Dictionary) -> bool: return int(t.hatch) <= GameState.today())
	if not sh.is_empty():
		await _land(sh)
		await _until(func() -> bool: return float(host.tag_alpha) > .6, "a lebegő tábla")
		await _click(host.shaping, "Alakítás")
		_expect(host.shaping.on, "alakító mód")
		_expect(not host.hud.orb.visible, "alakító módban a nap magja rejtve")
		var t: Dictionary = host.trees[host.focus]
		var b: int = host._shot_branch(t)
		if b >= 0:
			var pg: PlantGen = t.high.pg
			var xf: Transform3D = (t.high.node as Node3D).transform
			var c: Vector2 = host.cam.unproject_position(xf * pg.branch_point(b, .6))
			_touch_drag(c, Vector2.ZERO)
			await _frames(3)
			_touch_drag(c, Vector2.ZERO)
			await _frames(3)
			_expect(_has_op(sh, PlantGen.OP_CUT), "levágás a mentett fán")
			var b2: int = host._shot_branch(t, b)
			if b2 >= 0:
				pg = t.high.pg
				var c2: Vector2 = host.cam.unproject_position(xf * pg.branch_point(b2, Shaping.TIE_U))
				_touch_drag(c2, Vector2(-30, 140))
				await _frames(3)
				_expect(_has_op(sh, PlantGen.OP_TIE), "kötözés a mentett fán")
				await _click(host.shaping, "Visszavonom")
				_expect(not _has_op(sh, PlantGen.OP_TIE) and _has_op(sh, PlantGen.OP_CUT), "visszavonás: a kötés lekerült, a vágás marad")
				_touch_drag(c2, Vector2(-30, 140))
				await _frames(3)
		await _click(host.shaping, "Kész")
		_expect(not host.shaping.on, "kilépés az alakításból")
		_check("alakítás", {})
		# a mentett listából újraépítve ugyanaz a fa (determinizmus)
		var g := Genes.from_dna(sh.dna, str(sh.code))
		var pa := PlantGen.new()
		pa.build(g, 1.0)
		pa.apply_shaping(sh.shaping, GameState.today())
		_expect(pa.digest() == (host.trees[host.focus].high.pg as PlantGen).digest(), "az alakított fa a mentésből bitre ugyanaz")
		# alakító módban csípés kifelé: a fáról felemelkedve az alakítás is véget ér
		await _until(func() -> bool: return float(host.tag_alpha) > .6, "a lebegő tábla az alakítás után")
		await _click(host.shaping, "Alakítás")
		_expect(host.shaping.on, "alakító mód újra")
		host._zoom(4.0)
		await _frames(3)
		_expect(not host.shaping.on and host.view == "orbit", "csípés kifelé alakító módban: kilép az alakításból is")
		_expect(not host.shaping._panel.visible, "az alakítás lapja eltűnt")
		_touch_drag(Vector2(20, 400), Vector2.ZERO)
		await _settle("alakítás vége")

	# --- a kötözés napról napra hajlik
	await _next_day()
	_check("nap +1 kötözéssel", {})

	# --- megtelés: új bolygó születik; a megtelt bolygóról elvetett mag átrepül
	host._debug_fill()
	await _settle("megtelés, születés")
	_check("megtelt bolygó, mellette új", {"planets": 2, "trees0": GameState.PLANET_FULL})
	_expect(bool(game.data.planets[1].born_seen), "a születés lejátszódott (born_seen)")
	_expect(game.is_bare(game.data.planets[1]), "az új bolygó csupasz")
	# átrepülés a csupasz (fa nélküli, alapító nélküli) bolygóra és vissza
	host.system.go(1)
	await _settle("átrepülés a csupasz bolygóra")
	_expect(host.planet.bare and (host.trees as Array).is_empty(), "a csupasz bolygó látszik")
	_check("csupasz bolygó", {"active": 1, "trees1": 0})
	host.system.go(0)
	await _settle("vissza a teli bolygóra")
	_check("vissza a teli bolygóra", {"active": 0})
	await _next_day()
	await _solve_daily()
	var nd := _bag_of("napi")
	if not nd.is_empty():
		host.open_bag()
		await _frames(3)
		await _bag_click(int(nd.id), "Elvetem")
		await _settle("átrepülés és elvetés")
	_check("elvetés a megtelt bolygóról: az újra hullott", {"active": 1, "trees1": 1, "trees0": GameState.PLANET_FULL})
	await _next_day()
	_expect(not game.is_bare(game.data.planets[1]), "az első kikelt fa megalapította a bolygót")
	_expect((host.trees as Array).size() == 1, "a jelenetben 1 fa")
	_check("csupasz bolygó kikelése", {"trees1": 1})

	# --- az utolsó fa elengedése: fa nélküli bolygó, egy csillag
	var last: Dictionary = game.data.planets[1].trees[0]
	await _land(last)
	await _until(func() -> bool: return float(host.tag_alpha) > .6, "a lebegő tábla")
	await _click(host.herb, "Elengedem…")
	await _click(host.herb, "Elengedem")
	await _until(func() -> bool: return not host.stars.busy(), "az elengedés vége")
	await _frames(5)
	host.herb.close()
	await _settle("elengedés vége")
	_check("fa nélküli bolygó", {"trees1": 0, "stars1": 1})
	_expect((host.trees as Array).is_empty(), "a jelenetben nincs fa")
	host.retreat(host.show_saved_planet)
	await _settle("fa nélküli bolygó újra")
	_check("fa nélküli bolygó újraépítve", {"trees1": 0})

	# --- bolygóváltás koppintással a kis bolygóra
	host.orbit_zoom = host.system.min_zoom()
	await _frames(40)
	var mp: Vector2 = host.system.screen_pos(0)
	_touch(mp)
	await _frames(3)
	await _settle("bolygóváltás")
	if game.active_index() != 0:
		notes.append("a kis bolygóra koppintás nem talált (%s), a váltás a system.go úton" % mp)
		host.system.go(0)
		await _settle("bolygóváltás (go)")
	_check("bolygóváltás", {"active": 0})

	# --- megosztás: a saját fa mag-kódja barát magjaként (kétszer: másodszor nem jár)
	var src: Dictionary = game.active_planet().trees[1]
	var code := ShareCode.for_tree(src)
	bag_before = (game.data.bag as Array).size()
	host.share.receive_code(code, false)
	await _until(func() -> bool: return host.share._gift.mouse_filter == Control.MOUSE_FILTER_STOP, "„Kaptál egy magot”")
	await _click(host.share, "A táskába")
	await _frames(3)
	await _close_bag()
	_check("barát magja", {"bag": bag_before + 1})
	var gift := _bag_of("barat")
	_expect(str(gift.get("share", "")) == code, "a barát magja a kóddal")
	host.share.receive_code(code, false)
	await _frames(5)
	await _click(host.share, "Bezár")
	_check("ugyanaz a kód másodszor: nincs új mag", {"bag": bag_before + 1})

	# --- vendég-bolygó: a saját bolygó linkje; a mentett bolygók nem változnak, „Magot kérek”, vissza
	var link := ShareCode.encode_planet(game.active_planet(), game.hatched(game.active_planet()), GameState.today())
	var gp := ShareCode.decode_planet(link, GameState.today())
	_expect(bool(gp.get("ok", false)), "a bolygó-link kinyílik")
	var planets_json := JSON.stringify(GameState._plain(game.data.planets), "", true, true)
	host.show_guest_planet(gp)
	await _settle("vendég-bolygó")
	_expect(not host.guest.is_empty() and not host.saved_view, "vendég-nézet")
	await _land_i(0)
	await _until(func() -> bool: return float(host.tag_alpha) > .6, "a lebegő tábla (vendég)")
	bag_before = (game.data.bag as Array).size()
	await _click(host.share, "Magot kérek")
	await _until(func() -> bool: return host.share._gift.mouse_filter == Control.MOUSE_FILTER_STOP, "„Kaptál egy magot” (vendég)")
	await _click(host.share, "Tovább nézem")
	_check("vendégként kért mag", {"bag": bag_before + 1})
	_expect(JSON.stringify(GameState._plain(game.data.planets), "", true, true) == planets_json, "vendégként a bolygók nem változtak")
	_touch_drag(Vector2(20, 400), Vector2.ZERO)
	await _frames(5)
	await _click(host.share, "Vissza a kertembe")
	await _settle("vissza a kertbe")
	_expect(host.saved_view and host.guest.is_empty(), "vissza a saját kertben")
	_check("vissza a kertbe", {})

	# --- éjféli napváltás nyitott appnál: a kikelés és a nap magja magától jön
	var cs2 := _bag_of("csillag")
	if not cs2.is_empty():
		host.open_bag()
		await _frames(3)
		await _bag_click(int(cs2.id), "Elvetem")
		await _settle("elvetés éjfél előtt")
	var pending: Dictionary = game.active_planet().trees.back()
	_expect(not bool(pending.revealed), "a mag a földben vár")
	# a tábla nyitva marad éjfélkor: alatta nem kel ki semmi
	host.open_daily()
	await _frames(3)
	GameState.day_offset += 1
	await _frames(150)
	_expect(host.board.visible and not host.hatching.active(), "nyitott tábla alatt nem indul a kikelés")
	await _click(host.board, "Bezár")
	await _settle("éjféli napváltás")
	_expect(bool(pending.revealed), "éjfél után a nyitott appban is kikelt a mag")
	_expect(not host.hud._done, "éjfél után a nap magja újra hív")
	_check("éjféli napváltás", {})

	# --- a mentésben kész, de be nem fejezett tábla (a lap a kész pillanatban zárult be): megnyitva befejeződik
	var today := GameState.today()
	bag_before = (game.data.bag as Array).size()
	game.set_daily_progress(today, DnaBoard.grid_from_dna(DnaBoard.daily(today).target))
	game.save()
	host.open_daily()
	await _until(func() -> bool: return host.bag.visible, "a kész tábla befejeződik")
	await _close_bag()
	await _settle("kész tábla")
	_check("a félbehagyott kész tábla befejeződött", {"bag": bag_before + 1})
	_expect(game.daily_done(today), "a mai nap kész")

	# --- indításkor egyszerre új nap és barát magja (?mag=…): a „Kaptál egy magot” lap alatt nem indul a kikelés
	var bs := _bag_of("barat")
	if not bs.is_empty():
		host.open_bag()
		await _frames(3)
		await _bag_click(int(bs.id), "Elvetem")
		await _settle("elvetés a lap előtt")
	var waiting: Dictionary = game.active_planet().trees.back()
	GameState.day_offset += 1
	game.save()
	var other := ShareCode.for_tree(game.data.planets[0].trees[2])
	bag_before = (game.data.bag as Array).size()
	host.share.receive_code(other, true)
	host.retreat(host.show_saved_planet)
	await _frames(200)
	_expect(host.share.is_open() and not host.hatching.active() and not bool(waiting.revealed), "a lap alatt nem kel ki semmi")
	await _until(func() -> bool: return host.share._gift.mouse_filter == Control.MOUSE_FILTER_STOP, "„Kaptál egy magot” (indításkor)")
	await _click(host.share, "A táskába")
	await _frames(3)
	await _close_bag()
	await _settle("kikelés a lap után")
	_expect(bool(waiting.revealed), "a lap bezárása után kikelt")
	_check("új nap + barát magja indításkor", {"bag": bag_before + 1})

	# --- teljes újratöltés: a mentésből ugyanaz a kert
	var digest_before: String = host._state_digest()
	var g2 := GameState.new()
	g2.path = PATH
	g2.load_or_new()
	host.game = g2
	game = g2
	host.retreat(host.show_saved_planet)
	await _settle("újratöltés")
	# (a lenyomat hash-e teljes pontosságú: a JSON-olvasó az utolsó jegyben kerekíthet, ezért a szöveges részt vetjük össze;
	# a teljes adatot 15 jegyre a _check)
	_expect(_no_hash(host._state_digest()) == _no_hash(digest_before), "újratöltés után ugyanaz a lenyomat")
	_check("teljes újratöltés", {})
	await _next_day()
	_check("újratöltés után nap +1", {})

	# --- régi mentések felhozása (migrate): a mostani kertből visszafelé lebutítva v3 és v1 formátumra
	for ver in [3, 1]:
		var old := _downgrade(GameState._plain(game.data), ver)
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(old))
		f.close()
		DirAccess.remove_absolute(PATH + GameState.BACKUP_SUFFIX)
		var g3 := GameState.new()
		g3.path = PATH
		_expect(not g3.load_or_new(), "a v%d mentés betöltődik" % ver)
		var ok := true
		for p in g3.data.planets:
			ok = ok and bool(p.born_seen) and not (p.founders as Array).is_empty()
			for k in (p.stars as Array).size():
				ok = ok and int(p.stars[k].seq) == k
			ok = ok and int(p.next_star) == (p.stars as Array).size()
			for t in p.trees:
				ok = ok and (t.shaping as Array).is_empty() and (t.dir as Vector3).length() > .5
		_expect(ok, "v%d: a hiányzó mezők pótolva (born_seen, alapító, csillag-sorszám, alakítás)" % ver)
		g3.save()
		host.game = g3
		game = g3
		host.retreat(host.show_saved_planet)
		await _settle("v%d mentésből" % ver)
		_check("v%d mentés felhozva" % ver, {"planets": (old.planets as Array).size(), "bag": (old.bag as Array).size()})

	_finish()


## Egy mostani mentés lebutítva a régi formátumra (a régi mezőkkel; teszteléshez).
static func _downgrade(d: Dictionary, ver: int) -> Dictionary:
	var o: Dictionary = d.duplicate(true)
	o.version = ver
	for p in o.planets:
		for k in ["born_seen", "next_star", "peak"]:
			p.erase(k)
		for t in p.trees:
			t.erase("shaping")
			if ver < 2:
				for k in ["watered", "gathered", "gathered_at", "hidden", "parents", "name"]:
					t.erase(k)
		for st in p.stars:
			st.erase("seq")
		if ver < 3:
			p.erase("stars")
			p.erase("founders")
	for sd in o.bag:
		for k in ["star_origin", "star_day", "share", "share_day", "from"]:
			sd.erase(k)
		if ver < 2:
			for k in ["parents", "tree", "name", "hidden", "code"]:
				sd.erase(k)
	if ver < 3:
		o.erase("cross")
		o.erase("active")
	return o


# ---------------------------------------------------------------- Lépések

func _solve_daily() -> void:
	await _settle("a nap magja előtt")
	var game: GameState = host.game
	var before: int = (game.data.bag as Array).size()
	_expect(host.hud.orb.visible, "a nap magja látszik")
	await _until(func() -> bool: return host.hud.orb.modulate.a > .95, "a nap magja kigyúl")
	await _press(host.hud.orb)
	await _frames(3)
	_expect(host.board.visible and host.board_day == GameState.today(), "a mai tábla nyitva")
	if not host.board.visible:
		host.open_daily()
		await _frames(3)
	_play_board()
	await _until(func() -> bool: return host.bag.visible, "a spirál után a táska")
	await _close_bag()
	_expect((game.data.bag as Array).size() == before + 1 and game.daily_done(GameState.today()), "a mai mag a táskában")


## A tábla kitöltése koppintásokkal (a szabad sorokban az utolsó választható változattal; mint a boardplay lövés).
func _play_board() -> void:
	var board: BoardView = host.board
	var opts: Array = board.puzzle.options
	var want := DnaBoard.grid_from_dna(opts[opts.size() - 1])
	for y in DnaBoard.N:
		for x in DnaBoard.N:
			if int(board.grid[y][x]) != DnaBoard.EMPTY:
				continue
			for i in (1 if int(want[y][x]) == 0 else 2):
				_mouse(board.cell_center(x, y))
	await _frames(2)


func _next_day() -> void:
	await _settle("nap +1 előtt")
	host._next_day()
	await _frames(3)
	await _settle("nap +1")


func _water(t: Dictionary) -> void:
	await _land(t)
	await _frames(20)
	var i := _scene_index(t)
	if i < 0:
		return
	_touch(host.cam.unproject_position(host._tree_mid(host.trees[i])))
	await _frames(3)
	if int(t.watered) != GameState.today():
		notes.append("öntözés: a koppintás nem talált, újra")
		host.tending.tap_focused(i, host.cam.unproject_position(host._tree_mid(host.trees[i])))
	await _until(func() -> bool: return host.tending._water.is_empty(), "az öntözés vége")


func _water_all() -> void:
	var game: GameState = host.game
	for t in game.hatched(game.active_planet()):
		if Care.thirsty(t, GameState.today()):
			await _water(t)
	if host.view == "surface":
		host._unfocus()
	await _settle("öntözés vége")


func _gather(t: Dictionary) -> void:
	await _land(t)
	await _frames(20)
	var i := _scene_index(t)
	if i < 0:
		return
	var tr: Dictionary = host.trees[i]
	var gl: Variant = tr.care.glint
	if gl == null:
		_fail("a magot érlelő fán nincs csillanás")
		return
	var w: Vector3 = (tr.high.node as Node3D).transform * (gl as Vector3)
	_touch(host.cam.unproject_position(w))
	await _frames(3)
	await _until(func() -> bool: return host.tending._gather.is_empty(), "a maggyűjtés vége")
	host._unfocus()
	await _settle("maggyűjtés vége")


## Leszállás egy mentett fához: koppintás a fára (ha nem talál, a _focus úton, megjegyzéssel).
func _land(t: Dictionary) -> void:
	await _settle("leszállás előtt")
	var i := _scene_index(t)
	if i < 0:
		_fail("a fa nincs a jelenetben: %s" % t.get("code", "?"))
		return
	await _land_i(i)


func _land_i(i: int) -> void:
	if host.view == "surface" and host.focus == i:
		return
	if host.view == "surface":
		host._unfocus()
		await _frames(30)
	var tr: Dictionary = host.trees[i]
	host.turn_to(tr.dir)
	host.orbit_q = host.look_q
	host.look_q = null
	await _frames(60)
	var c: Vector3 = host._tree_mid(tr)
	if not host.cam.is_position_behind(c):
		_touch(host.cam.unproject_position(c))
		await _frames(3)
	if host.focus != i:
		notes.append("leszállás: a koppintás %s fát talált (%d helyett), _focus úton" % [host.focus, i])
		host._focus(i)
	await _frames(60)


func _close_bag() -> void:
	if host.bag.visible:
		await _click(host.bag, "Bezár")
	await _frames(2)


# ---------------------------------------------------------------- Bemenet

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		_beat = Time.get_ticks_msec()


func _until(cond: Callable, what: String) -> bool:
	var i := 0
	while not cond.call():
		await get_tree().process_frame
		_beat = Time.get_ticks_msec()
		i += 1
		if i > MAX_WAIT:
			_fail("időtúllépés: %s" % what)
			return false
	return true


## Nyugalom: nincs nagy pillanat, nyitott lap, épülő fa; a saját kert (vagy a vendég-bolygó) áll.
func _calm() -> bool:
	return (host.queue as Array).is_empty() and not host.retreating and not host.fx.busy() and not host.hatching.active() \
		and (host.hatching.waiting as Array).is_empty() and not host.stars.busy() and not host.system.busy() \
		and not host.board.visible and not host.bag.visible and not host.crossing.is_open() and not host.herb.is_open() \
		and not host.share.is_open() and (host.herb._flying as Dictionary).is_empty() and (host.tending._gather as Dictionary).is_empty()


func _settle(what: String) -> void:
	await _until(_calm, what)
	await _frames(3)


## Az események a nézetablak bemenetére mennek (push_input: a felület, aztán _input / _unhandled_input – ugyanaz az út,
## mint a valódi érintésé). Fej nélkül az Input.parse_input_event nem jut el a nézetablakig.
func _mouse(c: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = c
		e.global_position = c
		get_viewport().push_input(e, true)


func _touch(at: Vector2) -> void:
	_touch_drag(at, Vector2.ZERO)


## Egy ujjas érintés: le, (ha drag nem nulla) húzás hat lépésben, fel.
func _touch_drag(at: Vector2, drag: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = at
	e.pressed = true
	get_viewport().push_input(e, true)
	var p := at
	if drag != Vector2.ZERO:
		for k in 6:
			var d := InputEventScreenDrag.new()
			d.index = 0
			d.relative = drag / 6.0
			p += drag / 6.0
			d.position = p
			get_viewport().push_input(d, true)
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.position = p
	u.pressed = false
	get_viewport().push_input(u, true)


func _press(b: Control) -> void:
	_mouse(b.get_global_rect().get_center())
	await _frames(2)


func _click(root: Node, text: String, n := 0) -> bool:
	var found: Array = root.find_children("*", "Button", true, false).filter(func(b: Button) -> bool:
		return b.text == text and b.is_visible_in_tree() and not b.disabled)
	if found.size() <= n:
		_fail("nincs ilyen (látható) gomb: „%s” (%d)" % [text, n])
		return false
	# görgethető listában (táska) előbb odagörgetünk, mint az ujj
	var p: Node = (found[n] as Node).get_parent()
	while p != null:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(found[n])
			await _frames(2)
			break
		p = p.get_parent()
	await _press(found[n])
	return true


## A táska egy magjának gombja (a kártyán a mag azonosítója: seed_bag.gd).
func _bag_click(seed_id: int, text: String) -> bool:
	if not host.bag.visible:
		host.open_bag()
		await _frames(3)
	for card in host.bag._list.get_children():
		if card.has_meta("seed_id") and int(card.get_meta("seed_id")) == seed_id:
			return await _click(card, text)
	_fail("nincs kártya a magnak: %d" % seed_id)
	return false


# ---------------------------------------------------------------- Ellenőrzés

func _bag_of(origin: String) -> Dictionary:
	var bag: Array = host.game.data.bag
	for i in range(bag.size() - 1, -1, -1):
		if str(bag[i].origin) == origin:
			return bag[i]
	return {}


func _find_tree(cond: Callable) -> Dictionary:
	var game: GameState = host.game
	for t in game.hatched(game.active_planet()):
		if cond.call(t):
			return t
	return {}


func _scene_index(t: Dictionary) -> int:
	for i in (host.trees as Array).size():
		if int(host.trees[i].sid) == int(t.id):
			return i
	return -1


func _has_op(t: Dictionary, op: String) -> bool:
	for e in t.shaping:
		if str(e.op) == op:
			return true
	return false


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fail(what)


func _fail(what: String) -> void:
	fails.append("[%d. lépés] %s" % [_step + 1, what])
	print("  HIBA: ", what)


## Az invariánsok egy lépés után. want: "bag", "planets", "active", "treesN", "starsN" (N: a bolygó indexe).
func _check(what: String, want: Dictionary) -> void:
	_step += 1
	var n0 := fails.size()
	var game: GameState = host.game
	var d: Dictionary = game.data
	# a mentés újraolvasva (a betöltés útján: migrate) ugyanaz, mint a memóriában: minden változás mentve, semmi nem vész el
	# (a lebegőpontos számok az utolsó jegyben eltérhetnek – a JSON-olvasó kerekítése –, ezért 15 jegyre vetjük össze)
	var mem := JSON.stringify(GameState._plain(d), "", true, false)
	var g2 := GameState.new()
	var raw := g2._read(PATH)
	if raw.is_empty():
		_fail("a mentés nem olvasható")
	else:
		var loaded := JSON.stringify(GameState._plain(g2.migrate(raw)), "", true, false)
		if loaded != mem:
			_fail("a mentés újraolvasva eltér a memóriától: %s" % _diff(mem, loaded))
	# azonosítók: egyediek, a next_id mindegyiknél nagyobb
	var ids := {}
	var dup := 0
	var top := 0
	for p in d.planets:
		for t in p.trees:
			dup += 1 if ids.has(int(t.id)) else 0
			ids[int(t.id)] = true
			top = maxi(top, int(t.id))
		for s in p.stars:
			dup += 1 if ids.has(int(s.id)) else 0
			ids[int(s.id)] = true
			top = maxi(top, int(s.id))
		if (p.trees as Array).size() > GameState.PLANET_FULL:
			_fail("túltöltött bolygó: %s (%d fa)" % [p.code, (p.trees as Array).size()])
		for t in p.trees:
			if (t.dir as Vector3).length() < .5:
				_fail("fa irány nélkül: %s" % t.code)
	for s in d.bag:
		dup += 1 if ids.has(int(s.id)) else 0
		ids[int(s.id)] = true
		top = maxi(top, int(s.id))
	if dup > 0:
		_fail("%d ismétlődő azonosító" % dup)
	if int(d.next_id) <= top:
		_fail("next_id (%d) nem nagyobb a legnagyobb azonosítónál (%d)" % [int(d.next_id), top])
	if int(d.active) < 0 or int(d.active) >= (d.planets as Array).size():
		_fail("hibás aktív bolygó: %d" % int(d.active))
	# a jelenetben pontosan a kikelt fák látszanak (nyugalomban, a saját kertben)
	if host.saved_view and _calm():
		var want_ids: Array = game.hatched(game.active_planet()).map(func(t: Dictionary) -> int: return int(t.id))
		var have_ids: Array = (host.trees as Array).map(func(t: Dictionary) -> int: return int(t.sid))
		want_ids.sort()
		have_ids.sort()
		if want_ids != have_ids:
			_fail("a jelenet fái (%s) ≠ a kikelt fák (%s)" % [have_ids, want_ids])
	# a várt számok
	for k in want:
		var v := -1
		if k == "bag":
			v = (d.bag as Array).size()
		elif k == "planets":
			v = (d.planets as Array).size()
		elif k == "active":
			v = int(d.active)
		elif (k as String).begins_with("trees"):
			var pi := int((k as String).trim_prefix("trees"))
			v = (d.planets[pi].trees as Array).size() if pi < (d.planets as Array).size() else -1
		elif (k as String).begins_with("stars"):
			var pi := int((k as String).trim_prefix("stars"))
			v = (d.planets[pi].stars as Array).size() if pi < (d.planets as Array).size() else -1
		if v != int(want[k]):
			_fail("%s: %d, várt: %d" % [k, v, int(want[k])])
	# hibaüzenetek a motorból
	var errs: Array = _log.errors.slice(_seen_errors)
	_seen_errors = _log.errors.size()
	for e in errs:
		_fail("hibaüzenet: %s" % e)
	print("LÉPÉS %d: %s – %s (nap %+d, %d bolygó, aktív %d, táska %d, fák %s, csillagok %s)" % [_step, what,
		"rendben" if fails.size() == n0 else "HIBA", GameState.day_offset, (d.planets as Array).size(), int(d.active),
		(d.bag as Array).size(), (d.planets as Array).map(func(p: Dictionary) -> int: return (p.trees as Array).size()),
		(d.planets as Array).map(func(p: Dictionary) -> int: return (p.stars as Array).size())])


static func _no_hash(d: String) -> String:
	var re := RegEx.create_from_string("hash [0-9a-f]+")
	return re.sub(d, "", true)


static func _diff(a: String, b: String) -> String:
	var i := 0
	while i < mini(a.length(), b.length()) and a[i] == b[i]:
		i += 1
	return "a %d. jeltől: memória …%s… / mentés …%s…" % [i, a.substr(maxi(i - 60, 0), 140), b.substr(maxi(i - 60, 0), 140)]


func _finish() -> void:
	if _done:
		return
	_done = true
	print("PLAYTEST (%.0f mp valós idő, %d képkocka)" % [Time.get_ticks_msec() / 1000.0, Engine.get_process_frames()])
	for n in notes:
		print("  megjegyzés: ", n)
	for w in _log.warnings:
		print("  figyelmeztetés: ", w)
	if fails.is_empty():
		print("EREDMÉNY: rendben (%d lépés)" % _step)
	else:
		print("EREDMÉNY: %d hiba" % fails.size())
		for f in fails:
			print("  ", f)
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(PATH + GameState.BACKUP_SUFFIX)
	get_tree().quit(0 if fails.is_empty() else 1)
