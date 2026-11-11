class_name Crossing
extends Node
## Keresztezés (M5) – a folyamat: táska („Keresztezem” → „Ezzel”) → keresztezett DNS-tábla (a két szülő génjei,
## a legközelebbi szabályos DNS, két szabad sor, 1 / 2 / M jelölés) → „Három csíra” (sprout_pick.gd) → a választott
## csíra kettős spirállal maggá lesz a táskában, a másik kettő csillag lesz az égbolton. A szabályok: breeding.gd,
## az adat: state.gd (data.cross, a csírák választásig a mentésben várnak).
##
## A főjelenet (main.gd) tagjait használja, ezért a host típus nélküli: game, board, bag, fx, ui_col, bag_btn,
## helix_seed, helix_msg, bench_on, retreating, saved_view, planet, _overlay_closed(), _sync_daily().

var host
var pick := SproutPick.new()
## A keresztezett tábla van nyitva (a tábla jelzései ide jönnek, nem a nap magjához).
var board_open := false
var a_id := -1
var b_id := -1


func _ready() -> void:
	pick.chosen.connect(_on_chosen)
	pick.closed.connect(func() -> void: host._overlay_closed())


## A felület a host UI-rétegébe kerül (a tábla és a táska fölé).
func attach_ui(layer: CanvasLayer) -> void:
	layer.add_child(pick)


## Nyitva van-e valami a keresztezésből (a világ ilyenkor nem reagál az érintésre).
func is_open() -> bool:
	return pick.visible


## Keresztezés indítása a táskából: a tábla a két mag génjeivel (a félkész állapot a mentésből jön).
func start(a: int, b: int) -> void:
	var game: GameState = host.game
	if game.data.is_empty() or host.bench_on:
		return
	var sa := game.find_seed(a)
	var sb := game.find_seed(b)
	if sa.is_empty() or sb.is_empty() or a == b:
		return
	if not game.pending_sprouts().is_empty():
		open_pick()
		return
	a_id = a
	b_id = b
	host.bag.visible = false
	var p := Breeding.puzzle(sa, sb)
	var title := "Keresztezés"
	var sub := "1: %s  ×  2: %s" % [GameState.seed_name(sa), GameState.seed_name(sb)]
	host.board.open(p, title, sub, game.cross_progress(a, b), [sa.dna, sb.dna])
	host.board_day = -1
	board_open = true
	host.ui_col.visible = false


## Minden koppintás után mentjük a félkész keresztezett táblát.
func board_changed(grid: Array) -> void:
	host.game.set_cross_progress(a_id, b_id, grid)
	host.game.save()


## Kész a keresztezett tábla: a két mag elfogy, a három csíra a mentésbe kerül, és nyílik a választás.
func board_done(dna: Array, animate := true) -> void:
	board_open = false
	var game: GameState = host.game
	var c := game.finish_cross(a_id, b_id, dna)
	game.save()
	if animate:
		host.board.fade_out(.5)
	else:
		host.board.close()
	host._sync_daily()
	if c.is_empty():
		host._overlay_closed()
		return
	open_pick()


## A választásra váró csírák (a táskából „Választok”, vagy a tábla után).
func open_pick() -> void:
	var c: Dictionary = host.game.pending_sprouts()
	if c.is_empty():
		return
	host.bag.visible = false
	host.board.close()
	host.ui_col.visible = false
	pick.open(c)


## Választott: mag a táskába (spirállal), a másik két csíra csillag lesz. A spirál a kártya kis rácsából indul.
func _on_chosen(k: int) -> void:
	var game: GameState = host.game
	var cells := pick.grid_cells(k)
	var vals := pick.grid_vals(k)
	var s := game.choose_sprout(k)
	game.save()
	host._sync_daily()
	# a két csillag a felszállásuk végén kigyullad az égbolton (sky_stars.gd)
	host.get_tree().create_timer(SproutPick.STAR_LEN - .3).timeout.connect(host.stars.sync)
	if s.is_empty():
		return
	host.helix_seed = int(s.id)
	host.helix_msg = "Kész! %s a táskádba került. A másik két csíra csillag lett az égbolton." % Genes.latin_name(s.dna)
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var r: Rect2 = (host.bag_btn as Control).get_global_rect()
	var to := r.get_center() if r.size.x > 1.0 else Vector2(vp.x * .62, 130.0)
	host.fx.play_helix(cells, vals, 22.0, to)
	if pick.freeze_pick >= 0.0:
		# képernyőképhez: a spirál is a választás utáni időpontban áll
		host.fx.freeze(pick.freeze_pick - SproutPick.HELIX_AT)
