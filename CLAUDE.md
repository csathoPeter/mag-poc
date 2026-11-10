# Mag – Claude Code útmutató

Péter telefonos játéka: DNS-ből kinövő, egyedi 3D növények egy nyugodt, repülhető kertben. A teljes játékterv és a döntések indoklása: `docs/DESIGN.md` – olvasd el, mielőtt játékmenetet módosítasz.

**Nyelv:** Péterrel magyarul beszélj. A kódban a változónevek angolul, a kommentek és a játékban látható szövegek magyarul.

**Péter többnyire csak telefonról dolgozik.** Nem tud fájlt letölteni, Godot-szerkesztőt nyitni vagy tárhelyre feltölteni. Amit látnia kell, az a webes buildben jelenjen meg; minden kérésnél az legyen a cél, hogy a végén a telefonos linken kipróbálható legyen.

## Szerkezet

```
godot/                  A játék (Godot 4.7.1, GDScript)
  project.godot         Mobil renderer natívan, gl_compatibility weben
  main.gd               Jelenet, UI, kamera (egy fa / repülős kert), analóg kar, növekedés, mérőszámok
  dna_board.gd          DNS-tábla logikája: 14 szabályos sor, 11 222 tábla, feladvány-generátor, levezetés, legközelebbi tábla
  board_ui.gd           A tábla kirakása (koppintás: üres → A=T → G≡C), szabad sorok, 1/2/M jelölés keresztezésnél, tipp
  helix.gd              Kettős spirál: a kész tábla spirállá csavarodik, maggá húzódik, a földbe hull
  plant_gen.gd          Növénygenerátor: ágak gyűrűkből, levelek és virágok MultiMesh-ben, részletességi szintek
  genes.gd              DNS → genom: 6 gén × 14 változat, termetek, égboltok
  shaders/              Fa, levél, virág, fű, talaj, ég, tiltshift
  fonts/symbols.ttf     Csak a „≡” jel (DejaVu), mert weben nincs rendszerfont, ami pótolná
  export_presets.cfg    "Web" preset (egyszálas)
prototype-threejs/      Korábbi Three.js-prototípus egy fájlban (DNS-tábla, keresztezés, spirál – ezek már át vannak víve Godotba).
tools/setup_godot.sh    Godot + szoftveres Vulkan telepítése (felhős gépen). `--web` a webes export sablont is letölti (1,3 GB-os csomagból).
tools/render_shots.sh   Fej nélküli képernyőképek ellenőrzéshez
.github/workflows/      Push a main ágra → webes export → gh-pages
```

## Kipróbálás telefonon

- Élő link: **https://csathopeter.github.io/mag-poc/**
- A `main` ágra pusholt minden `godot/` változás után a GitHub Actions lefordítja a webes buildet és kiteszi a `gh-pages` ágra (kb. 2–4 perc, majd a Pages további 1–2 perc). **A `gh-pages` ágat kézzel ne szerkeszd**, a workflow minden alkalommal felülírja.
- Péternek adj hozzá egy új lekérdezési paramétert (pl. `?v=<rövid commit>`), hogy a Safari ne a régit töltse be.
- Ha a workflow nem fut vagy elhasal, mondd el Péternek, és ne próbáld megkerülni a Pages beállításait (innen a Pages API nem érhető el).

## Ellenőrzés munka közben

```bash
tools/setup_godot.sh                     # egyszer, ha nincs Godot
cd godot && ~/godot-bin/godot --headless --import 2>&1 | grep -iE "script error|parse error|shader error"
tools/render_shots.sh /tmp/a.png 2-5-1-3-0-5,kert01,1 2-5-1-3-0-5,kert01,1,fly,go
```

- A `--shot=kimenet.png,dna,kód,növekedés[,kapcsolók…]` argumentumot a `main.gd` kezeli: betölti az állapotot, kiírja a `STATS` sort, ment egy képet és kilép. Kapcsolók: `fly` repülős kert, `go` előretolja a kart, `board` megnyitja a DNS-táblát, `cross` keresztezéses tábla (egy beépített második szülővel), `solve` kirakja a táblát (ebből nő az új növény), `helix1.3` a spirált az adott másodpercben mutatja (különben átugorja).
- Példa: `tools/render_shots.sh /tmp/b.png 2-5-1-3-0-5,kert01,1,board 2-5-1-3-0-5,kert01,0,cross,solve,helix1.3`
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

1. ~~DNS-tábla, feladvány-generátor, keresztezés és kettős spirál átvitele Godotba~~ (kész). Hátra van belőle: rejtett gének, egy keresztezésből három csíra.
2. Helyi mentés: a kert fái és DNS-ük megmaradjanak újratöltés után.
3. Saját növények a kertben, a mag másnap kel ki, öntözés.
4. Közelről a levelek szögletesek: finomabb levélforma vagy textúra a részletes szinten.
5. Webes színek hangolása (a Compatibility renderer fakóbb lombot, foltos talajt ad).
