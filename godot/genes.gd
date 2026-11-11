class_name Genes
extends RefCounted
## A DNS 6 génből áll, génenként 14 változattal. Ugyanazok a táblák, mint a webes prototípusban.

const GENE_NAMES := ["Virágszín", "Szirmok", "Levél", "Termet", "Kéreg", "Lomb"]

const HABITS := {
	"arbor": {"height": 4.5, "stems": 1, "b0": 9, "b1": 6, "b2": 5, "a0": 44, "a1": 38, "a2": 36, "r0": .56, "r1": .55, "r2": .62, "s0": .40, "s1": .12, "s2": .12, "t0": .10, "t1": .16, "t2": .10, "t3": .06, "wobble": .42, "wind": 0.0, "taper": .36, "flare": .55, "crown": .68, "leaf_dens": 13, "thick": 1.0, "flower_odds": .22},
	"weeping": {"height": 4.2, "stems": 1, "b0": 9, "b1": 6, "b2": 5, "a0": 56, "a1": 40, "a2": 22, "r0": .60, "r1": .78, "r2": 1.05, "s0": .52, "s1": .06, "s2": .05, "t0": .14, "t1": -.34, "t2": -1.15, "t3": -1.7, "wobble": .3, "wind": 0.0, "taper": .40, "flare": .5, "crown": .25, "leaf_dens": 19, "thick": .95, "flower_odds": .12},
	"windswept": {"height": 3.4, "stems": 1, "b0": 7, "b1": 5, "b2": 4, "a0": 48, "a1": 44, "a2": 40, "r0": .62, "r1": .52, "r2": .58, "s0": .30, "s1": .15, "s2": .10, "t0": .05, "t1": .10, "t2": .06, "t3": .05, "wobble": .95, "wind": .42, "taper": .32, "flare": .8, "crown": .5, "leaf_dens": 15, "thick": 1.25, "flower_odds": .28},
	"shrub": {"height": 2.0, "stems": 7, "b0": 5, "b1": 4, "b2": 3, "a0": 40, "a1": 42, "a2": 38, "r0": .55, "r1": .55, "r2": .6, "s0": .28, "s1": .10, "s2": .10, "t0": .16, "t1": .08, "t2": .04, "t3": .02, "wobble": .6, "wind": 0.0, "taper": .34, "flare": .1, "crown": .3, "leaf_dens": 17, "thick": .42, "flower_odds": .62},
	"spire": {"height": 6.0, "stems": 1, "b0": 22, "b1": 4, "b2": 3, "a0": 30, "a1": 34, "a2": 34, "r0": .26, "r1": .55, "r2": .62, "s0": .18, "s1": .12, "s2": .15, "t0": .02, "t1": .34, "t2": .20, "t3": .10, "wobble": .24, "wind": 0.0, "taper": .22, "flare": .5, "crown": .85, "leaf_dens": 22, "thick": .72, "flower_odds": .1},
}

const SKIES := [
	{"name": "aranyóra", "zenith": "#1a2a52", "horizon": "#f2a765", "moss": "#6c7a39", "sun": "#ffc78a", "dir": Vector3(.62, .30, -.62), "energy": 2.6},
	{"name": "hajnal", "zenith": "#25346a", "horizon": "#f3b8b2", "moss": "#74855a", "sun": "#ffd2c4", "dir": Vector3(-.55, .30, -.68), "energy": 2.3},
	{"name": "pára", "zenith": "#274b52", "horizon": "#c3d8c4", "moss": "#5a7d58", "sun": "#fff0d2", "dir": Vector3(.42, .62, -.50), "energy": 1.9},
	{"name": "alkony", "zenith": "#17123a", "horizon": "#d9648c", "moss": "#4f5d55", "sun": "#ff9f83", "dir": Vector3(.68, .24, -.55), "energy": 2.4},
]

const FLOWER := [["korall", .02, .78, .64], ["cseresznye", .96, .72, .62], ["rózsa", .93, .75, .74], ["magenta", .87, .78, .58], ["ibolya", .77, .62, .64], ["orgona", .72, .55, .72], ["azúr", .58, .8, .64], ["türkiz", .5, .7, .58], ["menta", .43, .55, .72], ["citrom", .15, .85, .66], ["arany", .12, .9, .56], ["barack", .07, .85, .72], ["hófehér", .12, .25, .93], ["éjkék", .64, .7, .42]]
const FOLIAGE := [["smaragd", .40, .55, .32], ["fűzöld", .28, .55, .36], ["olíva", .2, .45, .32], ["almazöld", .24, .62, .44], ["kékeszöld", .47, .5, .32], ["türkiz", .5, .62, .42], ["ezüstös", .42, .18, .56], ["aranysárga", .13, .68, .46], ["borostyán", .09, .72, .42], ["rozsda", .05, .6, .34], ["bordó", .97, .52, .3], ["bíbor", .83, .4, .34], ["lila", .77, .42, .4], ["fenyő", .37, .42, .2]]
const BARK := [["hamu", .08, .08, .36], ["füst", .62, .08, .28], ["mogyoró", .07, .32, .3], ["dió", .06, .3, .2], ["ében", .05, .12, .11], ["réz", .05, .42, .3], ["vörösfenyő", .03, .36, .24], ["nyírfa", .12, .12, .62], ["ezüst", .6, .08, .54], ["homok", .1, .26, .46], ["moha", .25, .22, .24], ["palakék", .6, .2, .3], ["mahagóni", .01, .42, .2], ["szén", .6, .05, .14]]
const LEAF := [["keskeny", .34, .13, 1.1, 0], ["lándzsás", .46, .16, .85, 0], ["hosszú", .54, .2, 1.0, 0], ["ovális", .36, .26, 1.0, 0], ["kerek", .3, .38, 1.0, 0], ["szív alakú", .34, .36, .68, 0], ["csúcsos", .4, .25, 1.4, 0], ["széles", .4, .42, .9, 0], ["apró", .22, .24, 1.0, 0], ["karéjos", .38, .32, .95, 3], ["csipkés", .36, .3, 1.0, 6], ["tölgyes", .42, .3, .85, 5], ["ujjas", .4, .36, 1.0, 4], ["tollas", .5, .22, 1.0, 7]]
const TERMET := [["arbor", "terebélyes", 1.0, 1.0], ["arbor", "magas terebélyes", 1.18, .86], ["arbor", "zömök terebélyes", .8, 1.28], ["weeping", "szomorú", 1.0, 1.0], ["weeping", "magas szomorú", 1.18, .88], ["weeping", "törpe szomorú", .76, 1.18], ["windswept", "szélfútta", 1.0, 1.0], ["windswept", "magas szélfútta", 1.2, .85], ["windswept", "göcsörtös", .82, 1.35], ["shrub", "bokros", 1.0, 1.0], ["shrub", "magas bokros", 1.28, .9], ["shrub", "párnás", .7, 1.1], ["spire", "oszlopos", 1.0, 1.0], ["spire", "karcsú oszlopos", 1.15, .8]]


static func hsl(h: float, s: float, l: float) -> Color:
	h = fposmod(h, 1.0)
	s = clampf(s, 0.0, 1.0)
	l = clampf(l, 0.0, 1.0)
	var c := (1.0 - absf(2.0 * l - 1.0)) * s
	var x := c * (1.0 - absf(fmod(h * 6.0, 2.0) - 1.0))
	var m := l - c / 2.0
	var rgb := [Vector3(c, x, 0), Vector3(x, c, 0), Vector3(0, c, x), Vector3(0, x, c), Vector3(x, 0, c), Vector3(c, 0, x)][int(h * 6.0) % 6] as Vector3
	return Color(rgb.x + m, rgb.y + m, rgb.z + m)


static func random_dna() -> Array:
	var dna := []
	for i in 6:
		dna.append(randi() % 14)
	return dna


## rare: ritka módosítás (RARE sorszáma, 0 = nincs). A DNS-tábláról nem jöhet ki: a nap magjába sorsolódik (roll_rare),
## és részben öröklődik. Csak a véletlenszámok UTÁN hat, így a fa váza ugyanaz marad, mint módosítás nélkül
## (kivéve, ha maga a módosítás a váz: csavart törzs).
static func from_dna(dna: Array, code: String, rare := 0) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash(code + str(dna))
	var ter: Array = TERMET[dna[3]]
	var g: Dictionary = (HABITS[ter[0]] as Dictionary).duplicate()
	for k in g.keys():
		if k != "stems":
			g[k] = float(g[k]) * r.randf_range(.93, 1.07)
	g.height *= ter[2]
	g.thick *= ter[3]
	g.dna = dna
	g.code = code
	g.gen_seed = hash(code + "x" + str(dna))
	g.form = ter[1]
	var f: Array = FLOWER[dna[0]]
	var l: Array = FOLIAGE[dna[5]]
	var b: Array = BARK[dna[4]]
	var lf: Array = LEAF[dna[2]]
	var pk: int = dna[1]
	g.petal_h = f[1]; g.petal_tip_h = fposmod(f[1] + r.randf_range(-.04, .04), 1.0); g.petal_s = f[2]; g.petal_l = f[3]
	g.petals = 4 + pk % 6
	g.layers = 2 if pk >= 6 and pk < 12 else 1
	g.petal_cup = [15.0, 32.0, 48.0, 62.0][pk % 4]
	g.petal_len = r.randf_range(.72, 1.02); g.petal_w = r.randf_range(.38, .64)
	g.center_h = r.randf_range(.11, .16); g.flower_size = r.randf_range(.12, .22)
	g.leaf_h = l[1]; g.leaf_tip_h = fposmod(l[1] + r.randf_range(-.04, .04), 1.0); g.leaf_s = l[2]; g.leaf_l = l[3]
	g.leaf_len = lf[1]; g.leaf_w = lf[2]; g.leaf_pow = lf[3]; g.leaf_lobes = lf[4]
	g.leaf_fold = r.randf_range(.12, .42); g.leaf_curl = r.randf_range(-.5, -.1); g.leaf_up = r.randf_range(-.1, .25)
	g.bark = hsl(b[1], b[2], b[3]).srgb_to_linear()
	g.wind_dir = r.randf() * TAU
	g.sky = r.randi() % SKIES.size()
	g.rare = rare if rare > 0 and rare < RARE.size() else 0
	if g.rare > 0:
		_apply_rare(g)
	return g


# ---------------------------------------------------------------- Ritka módosítások

## A ritkaság fokozatai és esélyük a nap magjában (egymást kizáróan; összesen 14,5%). Minden nap, minden játékosnál
## külön sorsolódik (roll_rare), nem a napok sorrendje szerint.
const RARE_TIERS := [
	{"name": "ritka", "chance": .10, "col": Color(.62, .9, .78)},
	{"name": "nagyon ritka", "chance": .035, "col": Color(.72, .74, 1.0)},
	{"name": "legendás", "chance": .01, "col": Color(1.0, .84, .45)},
]

## A ritka módosítások (a 0. üres). kind: melyik részt érinti; fx: a shader-ág (leaf_fx / flower_fx / wood_fx).
const RARE := [
	{"name": "", "tier": -1, "kind": ""},
	{"name": "kétszínű lomb", "tier": 0, "kind": "lomb", "desc": "a levelek csúcsa egészen más színű"},
	{"name": "óriás virágok", "tier": 0, "kind": "virág", "desc": "a virágai kétszer akkorák"},
	{"name": "óriás termet", "tier": 0, "kind": "termet", "desc": "jóval nagyobbra nő a társainál"},
	{"name": "fénylő virágok", "tier": 0, "kind": "fény", "desc": "a virágai nappal is halványan világítanak"},
	{"name": "tarka levél", "tier": 1, "kind": "lomb", "desc": "a levelek széle krémfehér"},
	{"name": "telt virág", "tier": 1, "kind": "virág", "desc": "háromsoros, telt virágok"},
	{"name": "csavart törzs", "tier": 1, "kind": "törzs", "desc": "a törzse csigavonalban csavarodik"},
	{"name": "holdfény", "tier": 1, "kind": "fény", "desc": "minden éjjel teljes fénnyel világít, nappal is dereng"},
	{"name": "ezüstlomb", "tier": 2, "kind": "lomb", "desc": "ezüstösen csillogó levelek"},
	{"name": "szivárványvirág", "tier": 2, "kind": "virág", "desc": "minden virága más színben játszik"},
	{"name": "aranykéreg", "tier": 2, "kind": "törzs", "desc": "aranyló, csillanó kéreg"},
	{"name": "csillámlomb", "tier": 2, "kind": "fény", "desc": "a levelein apró fények csillannak"},
]
const RARE_TWO_TONE := 1
const RARE_BIG_FLOWERS := 2
const RARE_GIANT := 3
const RARE_GLOW_FLOWERS := 4
const RARE_VARIEGATED := 5
const RARE_DOUBLE := 6
const RARE_TWISTED := 7
const RARE_MOONLIGHT := 8
const RARE_SILVER := 9
const RARE_RAINBOW := 10
const RARE_GOLD := 11
const RARE_SPARKLE := 12


## Ritka módosítás két egyenletes véletlen számból (0–1): u a fokozatot, v a fokozaton belüli fajtát választja.
## 0 = nincs (az esetek ~85,5%-ában).
static func roll_rare(u: float, v: float) -> int:
	var acc := 0.0
	for tier in range(RARE_TIERS.size() - 1, -1, -1):
		acc += float(RARE_TIERS[tier].chance)
		if u < acc:
			var list := rare_of_tier(tier)
			return int(list[mini(int(v * list.size()), list.size() - 1)])
	return 0


static func rare_of_tier(tier: int) -> Array:
	var out: Array = []
	for i in range(1, RARE.size()):
		if int(RARE[i].tier) == tier:
			out.append(i)
	return out


static func rare_valid(k: int) -> int:
	return k if k > 0 and k < RARE.size() else 0


## „aranykéreg (legendás)” (üres, ha nincs).
static func rare_label(k: int) -> String:
	if rare_valid(k) == 0:
		return ""
	return "%s (%s)" % [RARE[k].name, RARE_TIERS[int(RARE[k].tier)].name]


static func rare_color(k: int) -> Color:
	if rare_valid(k) == 0:
		return Color.WHITE
	return RARE_TIERS[int(RARE[k].tier)].col


## A módosítás a genomon (a véletlenszámok után, így a többi tulajdonság ugyanaz marad).
static func _apply_rare(g: Dictionary) -> void:
	match int(g.rare):
		RARE_TWO_TONE:
			g.leaf_tip_h = fposmod(float(g.leaf_h) + .42, 1.0)
			g.leaf_s = maxf(float(g.leaf_s), .55)
		RARE_BIG_FLOWERS:
			g.flower_size = float(g.flower_size) * 1.8
		RARE_GIANT:
			g.scale = 1.38
		RARE_DOUBLE:
			g.layers = 3
			g.petals = maxi(int(g.petals), 6)
		RARE_TWISTED:
			g.twist = 1.0
		RARE_SILVER:
			g.leaf_h = .55; g.leaf_tip_h = .5; g.leaf_s = .12; g.leaf_l = .56
		RARE_GOLD:
			g.bark = hsl(.115, .78, .5).srgb_to_linear()


## A ritka módosítás shader-paraméterei a fa anyagain (bármelyik lehet null). A kert, a csíraválasztó, a herbárium
## és a megosztás képe is ezt hívja, így mindenhol ugyanúgy látszik.
static func rare_params(g: Dictionary, wm: ShaderMaterial, lm: ShaderMaterial, fm: ShaderMaterial) -> void:
	var k := int(g.get("rare", 0))
	if wm != null:
		wm.set_shader_parameter("wood_fx", 1 if k == RARE_GOLD else 0)
	if lm != null:
		lm.set_shader_parameter("leaf_fx", 1 if k == RARE_VARIEGATED else 2 if k == RARE_SILVER else 3 if k == RARE_SPARKLE else 0)
	if fm != null:
		fm.set_shader_parameter("flower_fx", 1 if k == RARE_RAINBOW else 2 if k == RARE_GLOW_FLOWERS else 0)


static func describe(g: Dictionary) -> String:
	var dna: Array = g.dna
	return "%s termet · %s levél · %s virág · %s lomb · %s" % [g.form, LEAF[dna[2]][0], FLOWER[dna[0]][0], FOLIAGE[dna[5]][0], SKIES[g.sky].name]


static var _rows: Array = []


## A 14 szabályos sor (0 = A=T, 1 = G≡C), ugyanabban a sorrendben, mint a prototípusban: a génváltozat sorszáma = a sor sorszáma.
static func rows() -> Array:
	if _rows.is_empty():
		for m in 64:
			var r: Array = []
			var sum := 0
			for i in 6:
				var v := (m >> (5 - i)) & 1
				r.append(v)
				sum += v
			var triple := false
			for i in 4:
				if r[i] == r[i + 1] and r[i] == r[i + 2]:
					triple = true
			if sum == 3 and not triple:
				_rows.append(r)
	return _rows


## Rejtett éjszakai fény a tábla két átlójából: az erősség a G≡C-k számából, hogy melyik rész világít, az átlók eltéréseiből.
## Csak éjjel derül ki, és öröklődik, mert a sorokból (génekből) jön.
## rare: a „holdfény” módosítás teljes erővel világít, és nappal is dereng (day: a nappali alsó határ).
static func glow(dna: Array, rare := 0) -> Dictionary:
	var rs := rows()
	var gc := 0
	var key := 0
	for i in 6:
		var row: Array = rs[dna[i]]
		gc += int(row[i]) + int(row[5 - i])
		key += i * (int(row[i]) ^ int(row[5 - i]))
	var parts := ["virágai", "levélerei", "kérge"]
	var part := key % 3
	if rare == RARE_MOONLIGHT:
		return {"strength": 1.0, "part": part, "part_name": parts[part], "day": .3}
	return {"strength": clampf((gc - 3) / 6.0, 0.0, 1.0), "part": part, "part_name": parts[part], "day": 0.0}


## Egy gén egy változatának neve (a táblás felület és a magos táska mutatja), pl. allele_name(0, 2) = „rózsa”.
static func allele_name(gene: int, k: int) -> String:
	match gene:
		0:
			return FLOWER[k][0]
		1:
			var petals := 4 + k % 6
			var cup: float = [15.0, 32.0, 48.0, 62.0][k % 4]
			return "%d szirom%s%s" % [petals, ", telt" if k >= 6 and k < 12 else "", ", harangos" if cup >= 48.0 else ""]
		2:
			return LEAF[k][0]
		3:
			return TERMET[k][1]
		4:
			return BARK[k][0]
		_:
			return FOLIAGE[k][0]


## A színes gének (virágszín, kéreg, lomb) változatának színe a felülethez (sRGB); a többinél átlátszó.
static func allele_color(gene: int, k: int) -> Color:
	var t: Array = FLOWER[k] if gene == 0 else BARK[k] if gene == 4 else FOLIAGE[k] if gene == 5 else []
	if t.is_empty():
		return Color(0, 0, 0, 0)
	return hsl(t[1], t[2], t[3])


## Fajnév a DNS-ből: ugyanaz a DNS mindig ugyanazt a nevet kapja (a nap magja így megosztható: „nekem is Calitheora rosea lett”).
## A második tag a virágszínből jön (rokon növények osztoznak rajta), a nemzetségnév a többi génből.
const EPITHET := ["corallina", "cerasina", "rosea", "purpurea", "violacea", "lilacina", "azurea", "caerulea", "viridula", "citrina", "aurea", "persica", "nivea", "nocturna"]


static func latin_name(dna: Array) -> String:
	var x := 0
	for i in range(1, 6):
		x = x * 14 + int(dna[i])
	var a := ["Aur", "Sil", "Vel", "Lun", "Cor", "Ther", "Myr", "Hel", "Nym", "Ast", "Zeph", "Ori", "Cal", "Thal"]
	var b := ["and", "ith", "ol", "an", "er", "ys", "am", "ion", "ul", "en"]
	var c := ["ia", "ella", "ora", "ina", "ara", "ea", "anthe"]
	var parts: Array = []
	for list in [a, b, c]:
		# egyszerű, motorfüggetlen keverés (LCG), hogy a név minden eszközön ugyanaz legyen
		x = (x * 1103515245 + 12345) & 0x7fffffff
		parts.append(list[(x >> 8) % list.size()])
	var genus := "%s%s%s" % [parts[0], parts[1], parts[2]]
	# kettőzött magánhangzó a tagok határán (pl. Ori+ion) helyett egy
	for v in ["aa", "ee", "ii", "oo", "uu", "yy"]:
		genus = genus.replace(v, v.substr(1))
	return "%s %s" % [genus, EPITHET[int(dna[0])]]


## Rövid leírás a fő tulajdonságokból (magos táska, tábla vége).
## rare: a ritka módosítás is (a végén, pl. „· legendás · aranykéreg”); a még ki nem kelt nap magjánál ne add át.
static func traits_text(dna: Array, rare := 0) -> String:
	var s := "%s · %s levél · %s virág · %s lomb" % [TERMET[dna[3]][1], LEAF[dna[2]][0], FLOWER[dna[0]][0], FOLIAGE[dna[5]][0]]
	if rare_valid(rare) > 0:
		s += " · " + rare_label(rare)
	return s
