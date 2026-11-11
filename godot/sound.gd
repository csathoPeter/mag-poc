class_name Sound
extends Node
## Hang (M9): minden hang kódból készül (sound_synth.gd), a DNS-ből és a bolygóból, determinisztikusan.
##  - Növényhang: minden fának saját hangja van (hangszín a kéregből, alaphang a virágszínből és a termetből, díszítés
##    a szirmokból és a lombból, a csillogás a levélformából). Koppintásra, öntözéskor, maggyűjtéskor, kikeléskor szól.
##  - Bolygó-ambient: a fák hangjaiból válogatott 3–5 hangú akkord, lassú pad-hangokkal „lélegzik” (5–8,5 mp-enként egy),
##    néha egy fa halk hangja; éjjel puha tücsök-csiripelés, nappal ritka szellő. A sorozat a bolygókódból jön.
##  - Effektek: tábla (A=T két, G≡C három csengő hang, soronként más magasságban), kész tábla, spirál, hullás, földet
##    érés, kikelés, öntözés, maggyűjtés, csírák, elengedés, csillag, visszahozás, születés, átrepülés, metszés, kötözés.
##
## Weben a Godot „sample” módban játszik le (Web Audio): ezért minden hang előre kiszámolt AudioStreamWAV, a hangmagasság
## pitch_scale, a zengés a mintában van (buszeffekt ott nem menne). Két busz: „Ambient” és „Effekt” (a hangerő külön).
## iOS Safari csak érintés után enged hangot: az első érintésig semmi nem szól, az ambient sem indul.
## A minták a háttérben, képkockánként kis időkerettel (2,5 ms) készülnek; ha egy kért hang még nincs kész, előre kerül.
##
## Bárhonnan hívható: Sound.fx("water"), Sound.tree_of(fa, "tap"), Sound.board(érték, x, y) – ha nincs hangmotor
## (pl. --shot, önellenőrzés), nem csinálnak semmit.

static var inst: Sound

const BUS_FX := "Effekt"
const BUS_AMB := "Ambient"
## A buszok hangereje (dB): az ambient halk háttér.
const FX_BUS_DB := 0.0
const AMB_BUS_DB := -6.0
## A háttérszámolás képkockánkénti időkerete (µs); ha egy hang a mintájára vár, nagyobb.
const BUDGET := 2500
const BUDGET_URGENT := 6000
## Az indulás utáni csend (mp), amíg a bolygó és a fák felépülnek – addig nem számolunk.
const WARMUP := 1.5
const FX_PLAYERS := 10
const AMB_PLAYERS := 6
## Ennyit vár egy hang a mintájára (mp), utána elmarad (inkább csend, mint késve szóló hang).
const LATE := .7
## Az ambient türelmesebb (az első lélegzetek a pad mintájára várnak).
const AMB_LATE := 4.0

## Az effektek alap-hangereje (dB) – a minták csúcsra normáltak, a keverés itt van.
const FX_DB := {"tap_at": -15.0, "tap_gc": -15.0, "tap_clear": -19.0, "done": -11.0, "helix": -12.0, "fall": -15.0,
	"land": -12.0, "hatch": -11.0, "water": -12.0, "gather": -12.0, "bag": -15.0, "select": -19.0, "snip": -12.0,
	"tie": -13.0, "undo": -16.0, "release": -11.0, "star": -12.0, "rise": -16.0, "recall": -13.0, "hop": -14.0,
	"arrive": -13.0, "kindle": -12.0, "birth": -11.0}

var host
## Hamis: nincs hang (képernyőkép, parancssori mérés) – semmi nem számolódik és nem szól.
var enabled := true
## Volt-e már érintés (iOS: addig a böngésző úgysem enged hangot).
var unlocked := false
var muted := false
## Kész minták: név → AudioStreamWAV.
var streams := {}

var _queue: Array = SoundSynth.ALL.duplicate()
var _job: SoundSynth.Job
var _urgent := false
## Ütemezett hangok: {"at": mp, "s", "p", "db", "bus"}.
var _events: Array = []
var _fx_pool: Array = []
var _amb_pool: Array = []
var _now := 0.0
var _amb: SoundSynth.Ambient
var _amb_code := ""
var _t_breath := 0.0
var _t_night := 0.0
var _t_day := 0.0
var _flags_read := false
var _button: Button
var _demo := -1.0
var _gen_max_ms := 0.0
var _gen_frames := 0


func _enter_tree() -> void:
	inst = self


func _exit_tree() -> void:
	if inst == self:
		inst = null


func _ready() -> void:
	_bus(BUS_FX, FX_BUS_DB)
	_bus(BUS_AMB, AMB_BUS_DB)
	for i in FX_PLAYERS:
		_fx_pool.append(_player(BUS_FX))
	for i in AMB_PLAYERS:
		_amb_pool.append(_player(BUS_AMB))
	# --soundplay: próba a futó játékban (érintés nélkül „feloldva”): sorban minden effekt és pár fa megszólal,
	# a lejátszások és a háttérszámolás ideje a kimenetre kerül, a végén kilép
	if OS.get_cmdline_user_args().has("--soundplay"):
		_demo = 0.0
		unlocked = true


func _bus(bus_name: String, db: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(i, db)


func _player(bus_name: String) -> Dictionary:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	add_child(p)
	return {"pl": p, "busy": 0.0}


# ---------------------------------------------------------------- Hívható bárhonnan

## Effekt lejátszása (név a SoundSynth.ALL-ból); pitch: hangmagasság-szorzó, db: a táblázathoz képest, delay: mp.
static func fx(snd: String, pitch := 1.0, db := 0.0, delay := 0.0) -> void:
	if inst != null:
		inst._add(snd, pitch, float(FX_DB.get(snd, -14.0)) + db, delay, BUS_FX)


## Egy fa hangja a DNS-éből (és a kódjából). kind: lásd SoundSynth.voice_events.
static func tree(dna: Array, code: String, kind := "tap", delay := 0.0, db := 0.0) -> void:
	if inst == null or dna.size() < 6:
		return
	for e in SoundSynth.voice_events(SoundSynth.voice(dna, code), kind):
		inst._add(str(e.s), float(e.p), float(e.db) + db, float(e.at) + delay, BUS_FX)


## A jelenet egy fája (main.gd trees eleme).
static func tree_of(t: Dictionary, kind := "tap", delay := 0.0) -> void:
	if t.has("g"):
		tree((t.g as Dictionary).dna, str((t.g as Dictionary).code), kind, delay)


## A DNS-tábla egy mezője: v = 0 (A=T, két hang), 1 (G≡C, három hang), más = üres (halk koppanás).
## A sor (gén) a hangmagasság: lentebb a táblán magasabb hang a pentaton skálán.
static func board(v: int, _x: int, y: int) -> void:
	var p := pow(2.0, SoundSynth.degree_semis(y - 2) / 12.0)
	if v == 0:
		fx("tap_at", p)
	elif v == 1:
		fx("tap_gc", p)
	else:
		fx("tap_clear", p)


func _add(snd: String, pitch: float, db: float, delay: float, bus: String) -> void:
	if not enabled or not unlocked or muted:
		return
	_events.append({"at": _now + delay, "s": snd, "p": pitch, "db": db, "bus": bus})
	_want(snd, delay < LATE)


## A minta előre kerül a számolási sorban (ha még nincs kész).
func _want(snd: String, urgent: bool) -> void:
	if streams.has(snd) or (_job != null and _job.name == snd):
		if urgent and _job != null and _job.name == snd:
			_urgent = true
		return
	_queue.erase(snd)
	_queue.push_front(snd)
	if urgent:
		_urgent = true


# ---------------------------------------------------------------- Némítás

## Az apró hang be/ki gomb a fő gombsorba (rajzolt hangszóró-ikon; a betűkészletben nincs hangjegy).
func make_toggle(parent: Container) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(44, 40)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Hang be/ki"
	b.pressed.connect(func() -> void: set_muted(not muted))
	b.draw.connect(_draw_icon)
	parent.add_child(b)
	_button = b
	return b


func _draw_icon() -> void:
	var b := _button
	var c := b.size * .5 + Vector2(-5, 0)
	var col := Color(1, 1, 1, .9 if not muted else .5)
	var s := 1.0
	b.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -4) * s, c + Vector2(-3, -4) * s, c + Vector2(3, -9) * s,
		c + Vector2(3, 9) * s, c + Vector2(-3, 4) * s, c + Vector2(-8, 4) * s]), col)
	if muted:
		b.draw_line(c + Vector2(7, -4), c + Vector2(14, 4), col, 2.0, true)
		b.draw_line(c + Vector2(14, -4), c + Vector2(7, 4), col, 2.0, true)
	else:
		b.draw_arc(c + Vector2(3, 0), 6.0, -.9, .9, 10, col, 1.8, true)
		b.draw_arc(c + Vector2(3, 0), 11.0, -.9, .9, 14, Color(col, .6), 1.8, true)


func set_muted(m: bool, save := true) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)
	if m:
		_events.clear()
	if _button != null:
		_button.queue_redraw()
	if save and host != null and not (host.game.data as Dictionary).is_empty():
		host.game.data.flags.mute = m
		host.game.save()


# ---------------------------------------------------------------- Képkockánként

func _input(event: InputEvent) -> void:
	if unlocked or not enabled:
		return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		# az első érintés (lenyomás vagy felengedés): a böngésző ezzel engedi el a hangot; az ambient lassan indul
		unlocked = true
		_t_breath = _now + 1.2
		_t_night = _now + 2.5
		_t_day = _now + 5.0


func _process(delta: float) -> void:
	if not enabled:
		return
	_now += delta
	if not _flags_read and host != null and not (host.game.data as Dictionary).is_empty():
		_flags_read = true
		set_muted(bool((host.game.data.flags as Dictionary).get("mute", false)), false)
	var bench: bool = host != null and bool(host.bench_on)
	if not bench and _now > WARMUP:
		var t0 := Time.get_ticks_usec()
		_generate()
		_gen_max_ms = maxf(_gen_max_ms, (Time.get_ticks_usec() - t0) / 1000.0)
	if _demo >= 0.0:
		_demo_step(delta)
	if bench or not unlocked or muted:
		return
	_ambient()
	_play_due()


## A minták számolása a háttérben, időkerettel (a fák építése közben fél kerettel).
func _generate() -> void:
	if _job == null:
		if _queue.is_empty():
			return
		var nm: String = _queue.pop_front()
		if streams.has(nm):
			return
		_job = SoundSynth.Job.new(nm)
	var budget := BUDGET_URGENT if _urgent else BUDGET
	if host != null and not (host.queue as Array).is_empty():
		budget /= 2
	if _job.step(budget):
		streams[_job.name] = _job.stream
		_job = null
		_urgent = false
		for e in _events:
			if not streams.has(str(e.s)):
				_urgent = true


func _play_due() -> void:
	if _events.is_empty():
		return
	var keep: Array = []
	for e in _events:
		if float(e.at) > _now:
			keep.append(e)
			continue
		var st: AudioStreamWAV = streams.get(str(e.s))
		if st != null:
			_start(st, float(e.p), float(e.db), str(e.bus))
		elif _now - float(e.at) < (LATE if str(e.bus) == BUS_FX else AMB_LATE):
			keep.append(e)
	_events = keep


func _start(st: AudioStreamWAV, pitch: float, db: float, bus: String) -> void:
	if _demo >= 0.0:
		print("HANG %6.2f s  %-9s ×%.2f  %5.1f dB  %s" % [_now, streams.find_key(st), pitch, db, bus])
	var pool := _fx_pool if bus == BUS_FX else _amb_pool
	var best: Dictionary = pool[0]
	for p in pool:
		if float(p.busy) < float(best.busy):
			best = p
	var pl: AudioStreamPlayer = best.pl
	pl.stream = st
	pl.pitch_scale = clampf(pitch, .25, 4.0)
	pl.volume_db = db
	pl.play()
	best.busy = _now + st.get_length() / pl.pitch_scale


## A bolygó lélegzése: pad-hangok az akkordból, éjjel tücskök, nappal szellő (csak a bolygón, nem a próba-kertben).
func _ambient() -> void:
	if host == null or str(host.garden_mode) != "planet" or host.planet == null:
		return
	var code: String = host.planet.code
	if code != _amb_code:
		_amb_code = code
		_amb = SoundSynth.Ambient.new(code)
		_t_breath = maxf(_t_breath, _now + 1.5)
	var dnas: Array = host.planet_dnas
	if _now >= _t_breath:
		var b := _amb.next_breath(dnas)
		_queue_amb(b.ev)
		_t_breath = _now + float(b.wait)
	var night := float(host.night)
	if _now >= _t_night:
		var b := _amb.next_night()
		if night > .55:
			_queue_amb(b.ev)
		_t_night = _now + float(b.wait)
	if _now >= _t_day:
		var b := _amb.next_day()
		if night >= 0.0 and night < .35:
			_queue_amb(b.ev)
		_t_day = _now + float(b.wait)


func _queue_amb(ev: Array) -> void:
	for e in ev:
		_events.append({"at": _now + float(e.at), "s": str(e.s), "p": float(e.p), "db": float(e.db), "bus": BUS_AMB})
		_want(str(e.s), false)


func _demo_step(delta: float) -> void:
	var prev := _demo
	_demo += delta
	var names: Array = FX_DB.keys()
	for i in names.size():
		var at := 3.0 + i * .8
		if prev < at and _demo >= at:
			fx(names[i])
	var t_tree := 3.0 + names.size() * .8 + 1.0
	if prev < t_tree and _demo >= t_tree:
		for k in mini(3, (host.trees as Array).size()):
			tree_of(host.trees[k], "tap", k * 1.5)
	if _demo >= t_tree + 14.0:
		print("HANGPRÓBA kész: %d minta kész, %d a sorban, a háttérszámolás leghosszabb képkockája %.1f ms" % [streams.size(), _queue.size(), _gen_max_ms])
		get_tree().quit()
