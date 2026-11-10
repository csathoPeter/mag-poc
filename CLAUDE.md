# Mag – Claude Code útmutató

Péter telefonos játéka: DNS-ből kinövő, egyedi 3D növények egy nyugodt, repülhető kertben. A teljes játékterv és a döntések indoklása: `docs/DESIGN.md` – olvasd el, mielőtt játékmenetet módosítasz.

**Nyelv:** Péterrel magyarul beszélj. A kódban a változónevek angolul, a kommentek és a játékban látható szövegek magyarul.

**Péter többnyire csak telefonról dolgozik.** Nem tud fájlt letölteni, Godot-szerkesztőt nyitni vagy tárhelyre feltölteni. Amit látnia kell, az a webes buildben jelenjen meg; minden kérésnél az legyen a cél, hogy a végén a telefonos linken kipróbálható legyen.

## Szerkezet

```
godot/                  A játék (Godot 4.7.1, GDScript)
  project.godot         Mobil renderer natívan, gl_compatibility weben
  main.gd               Jelenet, UI, kamera (bolygó: forgatás/leszállás; régi: egy fa, repülős kert), napszak, növekedés, mérőszámok
  planet.gd             Kis bolygó: domborzat, légkör, holdak, gyűrű, fű, fénypontok; bolygó-DNS a növényekből
  plant_gen.gd          Növénygenerátor: ágak gyűrűkből, levelek és virágok MultiMesh-ben, részletességi szintek
  state.gd              Játékállapot és helyi mentés (GameState): játékos, bolygók, fák, csillagok, magos táska, today() + teszt-eltolás
  genes.gd              DNS → genom: 6 gén × 14 változat, termetek, égboltok; DNS-tábla sorai, rejtett éjszakai fény; változatnevek, fajnév a DNS-ből
  dna_board.gd          DNS-tábla logikája (DnaBoard): szabályok, 11 222 tábla (lustán), következtetés, feladvány szabad sorokkal,
                        a nap feladványa a napsorszámból (saját xorshift), legközelebbi szabályos DNS (keresztezéshez), önellenőrzés
  board_view.gd         A tábla felülete (BoardView): lebegő, fénylő rács, génnevek a sorok mellett, finom hibajelzés, súgás;
                        `parents`-szel 1 / 2 / M jelölés a sorok mellett (keresztezéshez kész); közös panel- és gombstílus
  seed_bag.gd           Magos táska (SeedBag): magok + az elmúlt 7 nap megfejtetlen napi magjai, „Elvetem”
  seed_fx.gd            A nagy pillanat (SeedFx): kettős spirál a kész táblából (a mezőkből csavarodik, maggá húzódik, a táskába
                        repül), elvetéskor a mag hullása a bolygóra, fénygyűrű, lebegő felirat; koppintás: gyorsít / átugrik
  seed_marks.gd         A kelésre váró magok jele a bolygón (SeedMarks): földkupac + lüktető fénypont, a mentésből
  hatching.gd           Másnapi kikelés (Hatching): a kamera odarepül, a csíra kinő, „Kikelt a tegnapi magod: …”, revealed = igaz
  shaders/              Fa, levél, virág (szél a fa keretében, éjszakai fény, érintéshullám), fű (régi kert), bolygó-fű (szálanként, GodotGrass-ötletek), bolygó, légkör, űr-ég, gyűrű, fénypontok, lencse (makett-sáv / DSLR-mélységélesség);
                        glow_dot (fénylő pont additív halóval, MultiMesh), glow_bar (spirál-kötések), veil (fátyol a spirál alatt)
  export_presets.cfg    "Web" preset (egyszálas)
prototype-threejs/      Korábbi Three.js-prototípus egy fájlban. A DNS-tábla, a feladvány-generátor (dna_board.gd) és a kettős spirál
                        (seed_fx.gd) már át van víve; a keresztezés még innen jön.
tools/setup_godot.sh    Godot + szoftveres Vulkan telepítése (felhős gépen). `--web` a webes export sablont is letölti (1,3 GB-os csomagból).
tools/render_shots.sh   Fej nélküli képernyőképek ellenőrzéshez
.github/workflows/      Push a main ágra → webes export → gh-pages
```

## Kipróbálás telefonon

- Élő link: **https://csathopeter.github.io/mag-poc/**
- A `main` ágra pusholt minden `godot/` változás után a GitHub Actions lefordítja a webes buildet és kiteszi a `gh-pages` ágra (kb. 2–4 perc, majd a Pages további 1–2 perc). **A `gh-pages` ágat kézzel ne szerkeszd**, a workflow minden alkalommal felülírja.
- Péternek adj hozzá egy új lekérdezési paramétert (pl. `?v=<rövid commit>`), hogy a Safari ne a régit töltse be.
- **Mentés:** a játék induláskor a mentett kertet tölti be (első indításkor új játékoskód, 3 kezdő fa). URL-paraméterek teszteléshez: `?uj` törli a mentést és újat kezd (amíg az URL-ben van, minden betöltéskor!), `?nap=+1` napokkal előre tolja a játék napját (a mentésbe is bekerül, `?nap=0` állítja vissza), `?jatekos=KOD` új játéknál ezt a játékoskódot adja. A második apró gombsorban: „nap +N” (egy nappal előre), „próba” (véletlen bolygó, nem mentődik; „saját” = vissza), „törlés” (két koppintással), mellette az aktív bolygókód és a játék napja.
- **A nap magja:** a fő gombsorban „A nap magja” (a mai tábla; ha kész, a táska) és „Táska (N)” (N = magok + megfejtetlen napok). A tábla minden koppintás után mentődik; kész táblánál a sorok kettős spirállá csavarodnak, a mag a táskába repül (koppintás: gyorsít, másodszor átugrik); „Elvetem” = a kamera a bolygó felé fordul, a mag a helyére hull, ott földkupac + lüktető fény jelzi (mentés után is). Holnap kel ki: „nap +1” vagy `?nap=+1` újratöltés után a kamera odarepül, a csíra kinő, „Kikelt a tegnapi magod: …” (koppintás: átugrik). `?tabla` / `?taska` induláskor megnyitja. A régi, azonnali véletlen ültetés a második apró sorban: „ültess”.
- Ha a workflow nem fut vagy elhasal, mondd el Péternek, és ne próbáld megkerülni a Pages beállításait (innen a Pages API nem érhető el).

## Ellenőrzés munka közben

```bash
tools/setup_godot.sh                     # egyszer, ha nincs Godot
cd godot && ~/godot-bin/godot --headless --import 2>&1 | grep -iE "script error|parse error|shader error"
tools/render_shots.sh /tmp/a.png planet,bolygo01,14,12 planet,bolygo01,14,23,focus2 2-5-1-3-0-5,kert01,1
```

- **Mentésből induló kert:** `--shot=kimenet.png,state[,óra[,focusN|plant|zoomZ|macro]]`. A mentés helye `--state=fájl` (ha nincs meg, új játékot kezd és elmenti; a `plant` ide ültet és ment), `--player=KOD` az új játék kódja, `--nap=+1` eltolás, `--uj` törlés. `--state` nélkül csak olvassa a valódi `user://` mentést. A kimenet `STATE` sorában a játékos, a fák helye és a mentés lenyomata (hash) – mentés → újraindítás után ugyanannak kell lennie. A render_shots.sh-nak: `MAG_ARGS="--state=/tmp/s.json --player=TESZT1" tools/render_shots.sh /tmp/a.png state,12 state,12,zoom0`.
- **DNS-tábla:** `godot --headless -- --boardtest[=napok]` (alap: 366 nap a mai naptól) minden nap feladványát legenerálja, és ellenőrzi: determinisztikus, logikával (találgatás nélkül) megoldható, a szabad sorokon kívül egyértelmű, a szabad sorokban van választás; a legközelebbi-DNS keresést is. `EREDMÉNY: rendben` a vége.
- Tábla és táska képen (a `state` lövés 6. mezője): `board` (mai tábla üresen), `boardNN` (NN%-ban kitöltve), `boardNNx` (plusz egy szabálysértő mező), `boardplay` (valódi koppintás-eseményekkel kitölti, a szabad sorokban a másik változattal → táska), `solve` (megoldva → táska), `bag`. A nagy pillanat: `helixNN` (a kettős spirál NN%-ánál, pl. `helix45` a közepe), `sow` (megoldás + elvetés, a mag már földet ért: jel + felirat), `sowNN` (az elvetés NN%-ánál, pl. `sow30`: a mag hullik), `hatchNN` (megoldás, elvetés, nap +1, a kikelés NN%-ánál, pl. `hatch50`), `revealNN` (a mentésből kikelő fák, `--state=… --nap=+1` kell; `reveal` magában lefut és elmenti a `revealed`-et). A kikelés képernyőképnél csak `hatch`/`reveal` módban fut, máskor a még nem látott fák is kinőve látszanak. Pl. `MAG_ARGS="--state=/tmp/s.json --player=T1 --nap=+2" tools/render_shots.sh /tmp/a.png state,12,board50x state,12,solve state,12,bag`.
- A `--shot=kimenet.png,dna,kód,növekedés[,fly[,go]]` argumentumot a `main.gd` kezeli: betölti az állapotot, ha `go`, előretolja a kart, kiírja a `STATS` sort, ment egy képet és kilép.
- Bolygó: `--shot=kimenet.png,planet,kód,fák száma[,óra[,focusN|plant|zoomZ|macro]]`. Az óra a napszakot rögzíti (pl. 12 nappal, 19 alkony, 23 éjjel). `zoomZ`: bolygó-nézet közelsége (0 = egész bolygó, 1 = alacsony légi nézet), `macro`: leszállás a 0. fára és rá egy virágra. Hetedik elemként `yawX`: a kamera X radiánnal arrébb (a fű rögzítettségének ellenőrzéséhez). A `STATS` sor a fű rajzolásait és csomóit is kiírja.
- A webes (Compatibility) renderert natívan is ki lehet próbálni: `xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 -- --shot=...` – így derült ki, hogy weben a 3D képernyő-textúrának nincs használható mipmapje (a szintjeit a ragyogás tölti, ezért ott a lencse csak a 0. szintet olvassa); a 2D rétegben (canvas_item) viszont van, ha a ragyogás ki van kapcsolva.
- **Automatikus mérés:** a „mérés” gomb (vagy a `?meres` URL-paraméter) terheléses mérést futtat: fű sűrűsége ×1–×6, részletes fák száma, 14/30/45 fa kint és lent. A `?meres&beall` a korábbi beállítás-mérés (felbontás, fű, árnyék, ragyogás, ég, tilt, AA ki-be), a `?meres&gyors` 2 lépéses próba. A végén HTML-rétegen táblázat + „Küldés GitHubra” (előre kitöltött issue a repóban) és „Másolás”. Natívan: `godot -- --bench [--gyors]` kiírja a `BENCH` táblázatot és kilép.
- Mérési eredmény (iPhone 15, Safari, 2026. 11. 10., build 9257794): minden beállítás 60 fps (a böngésző felső határa), kint ~210k, lent ~650k háromszög. Az „árnyék ki” egyszeri akadása a shaderek újrafordítása, nem tartós költség.
- Terheléses mérés (build 7ac52f3, 100% felbontás): lent fű ×1,5-ig 60 fps, ×2: 57, ×3: 50; lent 30 fa: 43; kint 30 fa: 60, 45 fa: 47. Ökölszabály: leszállva ~650–700k háromszög a határ; a pixelkitöltés is számít (75%-on +20%). Ezután jött a 3 szintű fa, az árnyék-helyettesítés, a 75%-os alapfelbontás és a bolygóhoz rögzített, csempés fű (a sarokban a „hívás” a rajzolási hívások száma; a háromszögszámba a fű ki nem nőtt, eldobott csomói is beleszámítanak).
- A webes buildben a második, apró gombsor mérőkapcsoló: belső 3D-felbontás (100/75/60/50%), fű be/ki, részletes fák száma (4/1), ég (textúra/sima/régi), tiltshift, élsimítás. A sarokban a valódi és a 3D renderfelbontás is látszik.
- **Webes build fej nélküli Chrome-ban:** `godot --headless --export-release Web /tmp/web/index.html`, az `index.html`-ben a `"args":[]` helyére pl. `["--","--player=T1","--shot=/tmp/x.png,state,12,helix45"]`, majd `google-chrome --headless=new --use-angle=swiftshader --enable-unsafe-swiftshader --remote-debugging-port=9222` + CDP-képernyőkép (a lövés a 40. képkockánál kilép, az utolsó változó kép a jó). A konzolban látszik, ha egy shader weben nem fordul.
- A szoftveres renderelés 1–6 fps-t ad: ez **nem** teljesítménymérés, csak a kép és a hibák ellenőrzése. A valódi teljesítményt Péter méri iPhone 15-ön (a sarokban fps, CPU/GPU ms, háromszögszám, fák száma).
- Minden változtatás után nézd meg legalább egy képernyőképen, mielőtt pusholsz. A Compatibility (webes) renderer másképp néz ki: ha a látványt hangolod, azt is nézd meg, pl. a webes exportot fej nélküli Chrome-mal.

## Teljesítménykeret (iPhone 15, webes build)

- 1 fa teljes részletességgel, árnyékkal: ~220k háromszög, 60 fps.
- 30 fás kert, csak a közeli 4 fa részletes: ~600–800k, 60 fps. Mind a 30 teljes (4,3M): 40 fps – ez már túl sok.
- Új vizuális elemnél maradj 1M háromszög alatt, és olcsó Androidra gondolva hagyj tartalékot.

## Kódolási szabályok

- GDScript típusokkal (`var x := ...`, `-> void`), tabulátoros behúzás, ahogy a meglévő fájlokban.
- A növény mindig determinisztikus a DNS-ből és a kódból: ugyanaz a bemenet ugyanazt a növényt adja (a mentés és a megosztás erre épül). A részletességi szintek ugyanabból a magból készülnek, a váz nem változhat köztük.
- Nincs halál, büntetés, időzítő, fizetős gyorsítás – lásd `docs/DESIGN.md` alapelvek.

## Következő lépések (prioritás szerint)

1. M4: öntözés, virágzás, maggyűjtés; M5: keresztezés (DnaBoard.nearest + BoardView `parents` 1/2/M jelöléssel kész alap; a spirál `SeedFx.play_helix` a keresztezett táblával is megy).
2. A nagy pillanatok hangja (M9) és napi egy értesítés („Kikelt a tegnapi magod”).
3. Közelről a levelek szögletesek: finomabb levélforma vagy textúra a részletes szinten.
4. Webes színek hangolása (a Compatibility renderer fakóbb lombot, foltos talajt ad).
