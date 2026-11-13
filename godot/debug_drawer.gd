class_name DebugDrawer
extends Control
## Fejlesztői fiók (2026. 11. 11.): fejlesztői módban (?debug, vagy hármas koppintás a bal felső sarokba) a jobb szélen
## egy fogantyú (⚙), rákoppintva oldalról kicsúszik egy panel minden teszt-kapcsolóval:
##  - élő mérőszámok: fps, képkockaidő (átlag és 95%), GPU/CPU ms, háromszög, rajzolási hívás, ablak és 3D-felbontás,
##    önálló felbontás és fűsűrűség, fps-grafikon az utolsó ~2 másodpercről;
##  - hozzáadás: fa, mag, csillag, új bolygó, bolygó feltöltése, fiatal fák növése, nap +1, próba bolygó, mentés törlése;
##  - kapcsolók: fű, árnyék, ragyogás, lencse, élsimítás, puha stílus, levél-körvonal, kerek szirom, évszak-részecskék,
##    felület, csillagok, önálló felbontás, 4 részletes fa;
##  - beállítások: felbontás, fűsűrűség, ég, napszak, évszak; mérések (terheléses, beállítások, tartós, gyors).
## A régi apró gombsorok (main.gd dbg_btn) megmaradtak a fiók mögött: a fiók gombjai azokat nyomják meg, így egy helyen
## van a logika. A panel alatt a világ nem kap érintést (main.gd _unhandled_input: covers()).

const GRAPH_N := 120

var host: Node
var open := false
var _slide := 0.0
var handle := Button.new()
var panel := PanelContainer.new()
var _list := VBoxContainer.new()
var _stats := Label.new()
var _game := Label.new()
var _graph := Control.new()
var _ft := PackedFloat32Array()
var _last := 0
var _refresh := 0.0
## [CheckButton, kulcs]
var _toggles: Array = []
## [Button, felirat-függvény]
var _labels: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.text = "⚙"
	handle.tooltip_text = "Fejlesztői fiók"
	handle.custom_minimum_size = Vector2(46, 46)
	handle.add_theme_font_size_override("font_size", 22)
	handle.focus_mode = Control.FOCUS_NONE
	handle.pressed.connect(func() -> void: set_open(not open))
	add_child(handle)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(.09, .08, .14, .9)
	sb.corner_radius_top_left = 14
	sb.corner_radius_bottom_left = 14
	sb.content_margin_left = 14
	sb.content_margin_right = 12
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var scroll := ScrollContainer.new()
	# vízszintesen nem görget, és a tartalom sem szélesítheti a panelt (a feliratok vághatók)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	panel.add_child(scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_build()
	panel.visible = false


## A panel tartalma (a host felépülése után hívja a main.gd).
func _build() -> void:
	var top := HBoxContainer.new()
	var title := Label.new()
	title.text = "Fejlesztői fiók"
	title.add_theme_font_size_override("font_size", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := _btn(top, "×", func() -> void: set_open(false))
	close.custom_minimum_size = Vector2(40, 34)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_list.add_child(top)

	_section("Mérőszámok")
	_stats.add_theme_font_size_override("font_size", 12)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.custom_minimum_size = Vector2(10, 0)
	_list.add_child(_stats)
	_graph.custom_minimum_size = Vector2(0, 54)
	_graph.draw.connect(_draw_graph)
	_list.add_child(_graph)
	_game.add_theme_font_size_override("font_size", 11)
	_game.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game.custom_minimum_size = Vector2(10, 0)
	_game.modulate = Color(1, 1, 1, .75)
	_list.add_child(_game)

	_section("Hozzáadás")
	var g := _grid()
	_btn(g, "+ fa (ültetés)", func() -> void: host.plant_new())
	_btn(g, "+ 2 mag", func() -> void: host._debug_seeds())
	_btn(g, "+ 3 csillag", func() -> void: host._debug_stars())
	_btn(g, "+ új bolygó", func() -> void: host._debug_new_planet())
	_btn(g, "bolygó feltöltése", func() -> void: host._debug_fill())
	_btn(g, "fiatal fák +5 nap növés", func() -> void: host._debug_grow(5))
	_mirror(g, func() -> String: return "nap +1 (most %+d)" % GameState.day_offset, "day")
	_mirror(g, func() -> String: return "próba bolygó" if (host.dbg_btn.try as Button).text == "próba" else "vissza a sajátra", "try")
	_mirror(g, func() -> String: return "mentés törlése" if (host.dbg_btn.wipe as Button).text == "törlés" else "biztos? (még egyszer)", "wipe")

	_section("Kapcsolók")
	g = _grid()
	for t in [["fű", "grass"], ["árnyék", "shadow"], ["ragyogás", "glow"], ["lencse", "tilt"], ["élsimítás", "aa"],
			["puha stílus", "soft"], ["festett stílus (fű, ég)", "paint"], ["levélforma", "leafcut"], ["kerek szirom", "petal"], ["részecskék", "fx"],
			["felület", "hud"], ["csillagok", "stars"], ["auto felbontás", "auto"], ["4 részletes fa", "hi"]]:
		_toggle(g, t[0], t[1])

	_section("Beállítások")
	g = _grid()
	_mirror(g, func() -> String: return "felbontás: %s" % (host.dbg_btn.sc as Button).text, "sc")
	var gm := _btn(g, "", func() -> void:
		var steps := [.6, 1.0, 1.5, 2.0]
		var i := steps.find(snappedf(host.planet.grass_mult, .1))
		var v: float = steps[(i + 1) % steps.size()]
		host.grass_q = v
		host.planet.set_grass_mult(v)
		_sync())
	_labels.append([gm, func() -> String: return "fűsűrűség ×%.1f" % (host.planet.grass_mult as float)])
	_mirror(g, func() -> String: return (host.dbg_btn.sk as Button).text, "sk")
	var tod := _btn(g, "", func() -> void:
		(host.tod_btn as Button).pressed.emit()
		_sync())
	_labels.append([tod, func() -> String: return "napszak: %s" % (host.tod_btn as Button).text])
	_mirror(g, func() -> String: return "évszak váltása", "season")

	_section("Mérés (a végén táblázat + Másolás)")
	g = _grid()
	_btn(g, "terheléses", func() -> void: _bench(""))
	_btn(g, "beállítások", func() -> void: _bench("&beall"))
	_btn(g, "tartós (melegedés)", func() -> void: _bench("&tartos"))
	_btn(g, "gyors próba", func() -> void: _bench("&gyors"))


func _bench(mode: String) -> void:
	set_open(false)
	host.dbg_bench(mode)


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.modulate = Color(.8, .9, 1.0, .85)
	_list.add_child(HSeparator.new())
	_list.add_child(l)


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(g)
	return g


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 13)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.pressed.connect(func() -> void:
		cb.call()
		_sync())
	parent.add_child(b)
	return b


## A régi apró gombsor egy gombját nyomja meg (ugyanaz a logika), a felirat a label függvényből.
func _mirror(parent: Control, label: Callable, key: String) -> void:
	var b := _btn(parent, "", func() -> void: (host.dbg_btn[key] as Button).pressed.emit())
	_labels.append([b, label])


func _toggle(parent: Control, text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_font_size_override("font_size", 13)
	c.focus_mode = Control.FOCUS_NONE
	c.clip_text = true
	c.custom_minimum_size = Vector2(0, 34)
	c.toggled.connect(func(on: bool) -> void:
		if on != host.dbg_get(key):
			host.dbg_set(key, on)
			_sync())
	parent.add_child(c)
	_toggles.append([c, key])


func set_open(on: bool) -> void:
	open = on
	if on:
		panel.visible = true
		_sync()


## Fiók nyitva és az érintés a panelre esik: a világ ne forogjon alatta.
func covers(event: InputEvent) -> bool:
	if not panel.visible or not ("position" in event):
		return false
	return panel.get_global_rect().has_point(event.position)


func _sync() -> void:
	for t in _toggles:
		(t[0] as CheckButton).set_pressed_no_signal(host.dbg_get(t[1]))
	for l in _labels:
		(l[0] as Button).text = (l[1] as Callable).call()


func _process(delta: float) -> void:
	if host == null:
		return
	var now := Time.get_ticks_usec()
	if _last > 0:
		_ft.append((now - _last) / 1000.0)
		if _ft.size() > GRAPH_N:
			_ft = _ft.slice(_ft.size() - GRAPH_N)
	_last = now
	var shot: Array = host.shot_args
	var dbg: bool = host.hud.debug and not host.bench_on and (shot.is_empty() or shot.has("drawer"))
	handle.visible = dbg
	if not dbg and open:
		set_open(false)
	var vp := get_viewport_rect().size
	var w := minf(380.0, vp.x * .88)
	_slide = (1.0 if open else 0.0) if not shot.is_empty() else move_toward(_slide, 1.0 if open else 0.0, delta / .22)
	var e := _slide * _slide * (3.0 - 2.0 * _slide)
	panel.custom_minimum_size = Vector2.ZERO
	panel.size = Vector2(w, vp.y)
	panel.position = Vector2(vp.x - w * e, 0.0)
	_list.custom_minimum_size.x = w - 30.0
	panel.visible = _slide > .001
	handle.position = Vector2(panel.position.x - handle.size.x - 4.0, vp.y * .3)
	if not panel.visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = .25
		_stats.text = _stats_text()
		_game.text = (host.game_l as Label).text
		_sync()
	_graph.queue_redraw()


func _stats_text() -> String:
	var rid: RID = get_viewport().get_viewport_rid()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var tris := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var avg := 0.0
	var sorted := _ft.duplicate()
	sorted.sort()
	for f in _ft:
		avg += f
	avg /= maxi(_ft.size(), 1)
	var p95: float = sorted[mini(sorted.size() - 1, int(sorted.size() * .95))] if not sorted.is_empty() else 0.0
	var ws := get_window().size
	var k: float = get_viewport().scaling_3d_scale
	return "%d fps · képkocka %.1f ms (95%%: %.1f)\nGPU %.1f · CPU %.1f ms · %dk háromszög · %d hívás\nablak %d×%d · 3D %d×%d (%d%%%s) · fű ×%.1f · %d fa" % [
		Engine.get_frames_per_second(), avg, p95, gpu, cpu, tris / 1000, calls, ws.x, ws.y, roundi(ws.x * k), roundi(ws.y * k),
		roundi(k * 100.0), ", auto" if host.auto_res else ", kézi", host.planet.grass_mult, (host.trees as Array).size()]


## Képkockaidő-grafikon: 0–50 ms, a 16,7 ms-os (60 fps) vonallal; a lassú képkockák pirosabbak.
func _draw_graph() -> void:
	var sz := _graph.size
	_graph.draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, .06))
	var y60 := sz.y * (1.0 - 16.7 / 50.0)
	_graph.draw_line(Vector2(0, y60), Vector2(sz.x, y60), Color(.6, 1, .7, .5), 1.0)
	var n := _ft.size()
	if n < 2:
		return
	var dx := sz.x / float(GRAPH_N - 1)
	var x0 := sz.x - dx * float(n - 1)
	for i in n - 1:
		var a := Vector2(x0 + dx * i, sz.y * (1.0 - clampf(_ft[i] / 50.0, 0.0, 1.0)))
		var b := Vector2(x0 + dx * (i + 1), sz.y * (1.0 - clampf(_ft[i + 1] / 50.0, 0.0, 1.0)))
		var slow := clampf((_ft[i + 1] - 17.5) / 15.0, 0.0, 1.0)
		_graph.draw_line(a, b, Color(.6, 1, .7).lerp(Color(1, .45, .4), slow), 1.5)
