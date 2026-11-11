class_name Hatching
extends Node
## Másnapi kikelés: ha a mentett bolygón van olyan fa, amelyik már kikelt (hatch <= ma), de a játékos még nem látta
## (revealed = hamis), a kamera lágyan odarepül (leszállás a fához), a mag jele fénygyűrűvel szétnyílik, a csíra
## kinő (a meglévő növekedés-animáció), a bolygó lassan átúszik az új bolygó-DNS-be, és a fa melletti lebegő tábla
## kiírja: „Kikelt a tegnapi magod: <fajnév>”. Végül revealed = igaz, mentés. Több fa egymás után kel ki.
## Koppintás: az aktuális kikelés a végére ugrik.
##
## A főjelenet (main.gd) tagjait használja, ezért a host típus nélküli: trees, queue, retreating, saved_view, bench_on,
## garden_mode, board, bag, crossing, share, fx, marks, planet, planet_dnas, tag, game, _focus(), _planet_texts(), _tree_title().

## Egy kikelés hossza (mp): repülés, szétnyílás (T_OPEN), növekedés (T_GROW–T_GROWN), felirat (T_TEXT).
const DUR := 7.0
const T_OPEN := 1.4
const T_GROW := 1.5
const T_GROWN := 6.0
const T_TEXT := 2.1

var host
## A kikelésre váró fák azonosítói, sorban.
var waiting: Array = []
var cur := -1
var t := 0.0
## Képernyőképhez: a kikelés ennél az időpontnál áll (-1 = fut).
var freeze_at := -1.0
var _done_steps := {}
var _founding := false


func reset(ids: Array = []) -> void:
	waiting = ids.duplicate()
	cur = -1
	t = 0.0
	_done_steps.clear()


## Fut-e épp egy kikelés (ilyenkor a koppintás átugorja).
func active() -> bool:
	return cur >= 0


func skip() -> void:
	if cur >= 0 and freeze_at < 0.0:
		t = DUR


func _process(delta: float) -> void:
	if host == null:
		return
	if cur < 0:
		if waiting.is_empty() or not _can_start():
			return
		_start(int(waiting.pop_front()))
		return
	var i := _index(cur)
	if i < 0 or host.retreating or host.garden_mode != "planet":
		# a bolygó közben lecserélődött: a következő megnyitáskor újra próbáljuk
		cur = -1
		return
	if freeze_at < 0.0:
		t += delta
	_step(i)


func _can_start() -> bool:
	return host.garden_mode == "planet" and host.saved_view and (host.queue as Array).is_empty() and not host.retreating \
		and not host.board.visible and not host.bag.visible and not host.crossing.is_open() and not host.fx.busy() and not host.bench_on \
		and not host.herb.is_open() and not host.stars.busy() and not host.system.busy() and not host.share.is_open()


func _index(id: int) -> int:
	var trees: Array = host.trees
	for i in trees.size():
		if int(trees[i].sid) == id:
			return i
	return -1


func _start(id: int) -> void:
	var i := _index(id)
	if i < 0:
		return
	cur = id
	t = freeze_at if freeze_at >= 0.0 else 0.0
	_done_steps.clear()
	_founding = false
	host._focus(i)
	# a felirat csak a szétnyílás után jön (addig a tábla üres, hogy ne lője le a meglepetést)
	host.tag.text = ""
	_step(i)


func _once(key: String) -> bool:
	if _done_steps.has(key):
		return false
	_done_steps[key] = true
	return true


func _step(i: int) -> void:
	var tr: Dictionary = host.trees[i]
	var planet: Planet = host.planet
	if t >= T_OPEN and _once("open"):
		var d: Vector3 = tr.dir
		host.fx.burst(planet.surface_point(d) + d * .05, d, 3.2)
		Sound.fx("hatch")
		host.marks.remove(cur)
		# a fa most kerül a bolygó-DNS-be: a bolygó lassan átúszik (szín, méret)
		var dna: Array = (tr.g as Dictionary).dna
		# csupasz bolygón (M7) ez az első fa: most kapja meg a bolygó a jellegét (a domborzat kiemelkedik)
		_founding = planet.bare
		if (host.planet_dnas as Array).is_empty():
			# az első kikelt fa: a bolygó addig az alapítóból állt össze, azt ne számoljuk kétszer
			planet.dnas.clear()
		host.planet_dnas.append(dna)
		planet.add_plant(dna)
		host._planet_texts()
	# a csíra kinő: ugyanaz a növekedés, mint ültetéskor, csak a kikelés ütemére
	var u := clampf((t - T_GROW) / (T_GROWN - T_GROW), 0.0, 1.0)
	for rec in tr.lods:
		rec.t = u
		var g := 1.0 - pow(1.0 - u, 1.7)
		for m in rec.mats:
			(m as ShaderMaterial).set_shader_parameter("grow", g)
	if t >= T_TEXT and _once("text"):
		host.tag.text = _caption(tr)
		# az új fa először szólal meg a saját hangján
		Sound.tree_of(tr, "hatch", .4)
		var rk := int((tr.g as Dictionary).get("rare", 0))
		if rk > 0:
			# ritka mag volt: most derül ki (a fa felragyog, csillag-csengés)
			Sound.fx("kindle", 1.0, 0.0, .5)
			var d2: Vector3 = tr.dir
			host.fx.burst(planet.surface_point(d2) + d2 * .3, d2, 4.5)
	if t >= DUR and freeze_at < 0.0:
		for rec in tr.lods:
			rec.erase("hold")
		var st: Dictionary = host.game.find_tree(cur)
		if not st.is_empty():
			st.revealed = true
			host.game.save()
		cur = -1


func _caption(tr: Dictionary) -> String:
	var st: Dictionary = host.game.find_tree(cur)
	var days := 1
	if not st.is_empty():
		days = maxi(1, GameState.today() - int(st.planted))
	var head := "Kikelt a tegnapi magod:" if days == 1 else "Kikelt a %d napja elvetett magod:" % days
	var found := ("\nŐ %s alapítója: a bolygó felveszi a jellegét." % host.planet.planet_name()) if _founding else ""
	var rk := int((tr.g as Dictionary).get("rare", 0))
	if rk > 0:
		head = "Ritka mag volt! %s: %s.\n%s" % [Genes.rare_label(rk), Genes.RARE[rk].desc, head]
	return "%s\n%s%s" % [head, host._tree_title(tr), found]
