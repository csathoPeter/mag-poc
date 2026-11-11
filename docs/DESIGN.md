# Mag – játékterv

Nyugodt, ingyenes telefonos játék (iOS, Android, web), amelyben DNS-ből kinövő, egyedi 3D növényeket nevelsz és tenyésztesz egy kertben. Hangulat: relax, a [Tree Appreciator](https://tools.simonwillison.net/tree-appreciator) nyugalma, Tamagotchi-szerű visszatérés, de büntetés nélkül.

## Alapelvek

- **Nincs bukás, halál, időzítő vagy bűntudat.** Az elhanyagolt növény csak lekonyul, egy öntözéstől feléled.
- **Az idő nem eladó.** Vizet, gyorsítást, játékelőnyt nem árulunk.
- **Napi 3–5 perc** is teljes élmény, de bármennyit lehet játszani.
- **Minden növény egyedi és szép**, kódból generálva, nem kézzel rajzolva.

## A DNS-tábla (fő mechanika)

- 6×6-os tábla, minden mező egy bázispár: **A=T** vagy **G≡C** (Takuzu/Binairo-szabályok).
- Szabályok: soronként és oszloponként 3 A=T és 3 G≡C; három egyforma nem állhat egymás mellett.
- Egy sorra 14 szabályos minta van, az egész táblára 11 222 szabályos kitöltés.
- **A hat sor hat gén**, génenként 14 változat: virágszín, szirmok, levélforma, termet, kéreg, lombszín (táblák: `godot/genes.gd`).
- A feladványok logikával, találgatás nélkül megoldhatók (300 generált táblán ellenőrizve), átlag ~19 üres mező.
- **Szabad gének:** 2 sorban több jó megoldás van, ott a játékos dönt, így irányítja a tenyésztést. (Egy sorban eltérő szabályos tábla nem létezik: az oszlopösszegek miatt legalább két sornak kell eltérnie.) A tábla mellett látszik, miből választhat (pl. „Virágszín: magenta vagy éjkék”).
- **Godotban (`godot/dna_board.gd`):** ugyanaz a sorrend és logika, mint a prototípusban (a sor mintájának sorszáma = a gén változata, `Genes.rows()`). Önellenőrzés: `--boardtest`, 366 napon 0 hiba, átlag 18,8 üres mező (16–24), feladvány-generálás ~10 ms. A 11 222 tábla felsorolása ~170 ms, ezért csak a keresztezés (legközelebbi szabályos DNS) kéri, lustán; a nap feladványa visszalépéses kereséssel, felsorolás nélkül készül.
- **Felület (`godot/board_view.gd`):** a világ fölött lebegő, félig átlátszó, fénylő rács (2D réteg, a bolygó elmosva átlátszik). Koppintás: üres → A=T → G≡C → üres; a bázispárt saját rajz mutatja (két betű, 2 vagy 3 kötés), mert a webes betűkészletben nincs ≡. Szabályt sértő mező lassan lüktető korall kerettel, büntetés nélkül; „Súgás” egy mezőt kitölt, „Újra” két koppintással. A sorok mellett a gén és a kész sor változata (színes génnél színfolttal). Minden koppintás mentődik.

## Keresztezés

- Két szülő génjeit a táblára tesszük; mivel ritkán férnek össze szabályosan, a játék a legközelebbi szabályos DNS-t keresi. **Az eltérés maga a mutáció** (a szabályokból következik, nem külön véletlen).
- A sorok mellett jelölés: 1 / 2 = melyik szülőtől jött, M = mutáció.
- Rejtett gének (két kék szülőtől néha fehér utód), egy keresztezésből három csíra, ebből egyet nevel tovább a játékos (szelekció).

**Godotban (M5, `godot/breeding.gd` szabályok, `crossing.gd` folyamat, `sprout_pick.gd` csíraválasztás):**
- **Belépés (két koppintás):** a táskában a gyűjtött (vagy keresztezett) magon „Keresztezem” → a táska párválasztó módba vált (fent: „Kivel keresztezed?”), a többi magon „Ezzel”, a választotton „Mégse”. A pár bármelyik másik mag lehet, a nap magja is. **Egy keresztezés két magot használ fel** (a tábla elkészültekor), így a korlátot a gyűjtött magok száma adja, nem számláló. Ha a tábla félbemarad, a táblája mentődik (ugyanaz a pár újra megnyitva ott folytatódik), a magok megmaradnak.
- **Tábla:** soronként (génenként) az egyik szülő változata – ahol eltérnek, a pár kulcsából sorsolva (a két mag azonosítója és DNS-e, saját xorshift, így újratöltve is ugyanaz). Ez ritkán szabályos, ezért a legközelebbi szabályos DNS a cél (`DnaBoard.nearest`); az eltérés a mutáció (300 véletlen páron átlag ~4 mező). **Játékosi döntés:** mint a nap magjánál, két szabad (arany) sor marad, de itt azok a sorpárok előnyben, ahol a választékban a szülők génjei is ott vannak (a párok 95%-ában van ilyen): „Termet: zömök terebélyes (1), törpe szomorú (2), terebélyes (M) …” – a játékos dönti el, melyik szülőtől jöjjön az a gén, vagy a mutációt választja. A kész sor mellett színes jelvény: 1 (menta), 2 (barack), M (levendula).
- **Három csíra:** az 1. pontosan a játékos táblája; a 2. és a 3. testvér: egy-egy olyan gén, ahol a szülők eltérnek, a másik szülőtől jön (a legközelebbi szabályos DNS ehhez, ezért gyakran egy másik gén is mutálódik); azonos szülőknél (két mag ugyanarról a fáról) egy-egy apró mutáció. Mindhárom látszik: közös kis 3D-előnézetben kinőnek a földkupacukból és lassan forognak (egyszerűsített részletesség, ~3×15k háromszög, egy SubViewport, csak amíg a panel nyitva van), alattuk kártyánként a fajnév, a hat gén 1 / 2 / M jellel, ha előbújt, „Előbújt a rejtett szín: hófehér!”, és a DNS kis rácsa (a mutált sor levendula kerettel). A csíra kódja (`<játékos>-K<a>-<b>-<k>`) a mag `code`-ja lesz, és elvetéskor a fáé: **pontosan az a fa nő ki, amit választottál.**
- **Választás („Ezt nevelem”):** a másik két csíra összemegy, fénnyé válik, és csóvával, himbálózva felszáll a kép tetejére, ahol csillogó csillag lesz belőle; közben a választott kártya kis rácsából indul a kettős spirál (`SeedFx.play_helix`), a mag a táskába repül (`origin` = `keresztezes`, `parents` = [a két szülő DNS-e], `code`, `hidden`). A nem választottak a bolygó `stars` listájába kerülnek (`origin` = `csira`, azaz a keresztezés el nem választott csírája, saját kóddal és rejtett színnel; a csillagkép az M6 dolga). „Később”: a csírák a mentésben várnak, a táskában legfelül „Három csíra vár” → „Választok” (addig új keresztezés nem indul).
- **Rejtett virágszín (egyszerű, determinisztikus):** minden mag és fa hordoz egy lappangó virágszínt (`hidden`; ha nincs megadva, a virágszínéhez tartozó pár: a kékek – azúr, türkiz, éjkék –, a rózsa, az orgona és a menta fehéret rejt; a meleg színek barackot; a fehér és az ibolya éjkéket; a barack korallt; a cseresznye rózsát; a magenta cseresznyét). Csíránként mindkét szülő fele-fele eséllyel a látható vagy a lappangó színét adja tovább. **Ha mindkettő a lappangót adja, és ez a kettőnél ugyanaz, a testvér-csírán előbújik** (a virágszín-sor kötelezően az lesz, a tábla ehhez keresi a legközelebbi szabályosat). Az 1. csíra (a játékos táblája) sosem változik. Mérés: a keresztezések ~16%-ában bújik elő valami; két kék szülőtől a keresztezések ~37%-ában van fehér csíra. Az utód lappangó színe az, amit a szülők továbbadtak, de nem látszik rajta – így a fehér tovább öröklődhet. A gyűjtött mag a fa lappangó színét viszi.

## A nagy pillanat

A kész tábla sorai kettős spirállá csavarodnak, maggá húzódnak, a földbe hullanak, és kinő a növény.

**Godotban (M3, `godot/seed_fx.gd`, `seed_marks.gd`, `hatching.gd`):**
- **Spirál (~3,9 mp):** a tábla mezői helyén bázispárok (két golyó + a mező színű kötés) jelennek meg, a feliratok elhalványulnak. A sorok kettős spirállá csavarodnak (a két gerincet apró fénypontok rajzolják ki), a spirál lassan pörög, felgyorsulva maggá húzódik, a mag ívben a táska felé repül, és a táska nyílik az új maggal. A tábla mögötti sötét lila fátyol folytatódik a spirál alatt, a végén feloszlik. A mag már a tábla elkészültekor mentődik (a lap bármikor bezárulhat).
- **Elvetés (~4,6 mp + felirat):** „Elvetem” után a gombsor elrejtőzik, a kamera a bolygó felé fordul (a hely a kép közepére), a mag fénypontként, csóvával, lágyan himbálózva leereszkedik, földet érve fénygyűrű fut szét, és ott marad a jele: kis földkupac, fölötte halványan lüktető meleg fény. Lebegő felirat: „<fajnév> holnap itt kel ki”.
- **Másnapi kikelés (~7 mp fánként):** megnyitáskor (vagy „nap +1” után) a kikelt, de még nem látott fákhoz a kamera odarepül (leszállás), a jel fénygyűrűvel szétnyílik, a csíra kinő, a bolygó lassan átúszik az új bolygó-DNS-be (a fa csak ekkor számít bele), a fa melletti lebegő táblán: „Kikelt a tegnapi magod: <fajnév> …”. Utána `revealed` = igaz, mentés. Több fa egymás után.
- **Koppintás:** a spirál és az elvetés alatt az első koppintás gyorsít, a második a végére ugrik; a kikelést egy koppintás befejezi. Nincs büntetés, semmi nem vész el.
- **Olcsó:** két MultiMesh (≈215 fénylő pont, 36 pálca), önvilágító pasztell, additív haló, valódi bloom nélkül; a fátyol egy teljes képernyős négyszög (csak a spirál alatt). Weben (Compatibility) a fátyol erőssége külön hangolt, mert ott a keverés sRGB-ben történik.

## A kert

- Szembőli nézet, **tiltshift** (mélységalapú háttérblur + a kép teteje/alja enyhén elmosva), makettszerű hatás.
- **Analóg karral repülsz** a kertben, máshol húzva körülnézel.
- A közeli 4 fa teljes részletes, a többi egyszerűsített, azonos vázzal (a váltás ne látsszon).

## Napi kör (game loop)

Döntés: 2026. 11. 10. Három pillér, ebben a sorrendben:

1. **Kíváncsiság** – a gerinc. Amit ma elvetsz, az holnap kel ki: „milyen lett?”
2. **A nap magja** – a szokás. Wordle-szerű közös napi feladvány.
3. **Gondozás** – a kötődés. Öntözés, maggyűjtés, metszés, kötözés.

A herbárium és a tenyésztési célok csak halk háttérelemek, nem kényszerítenek semmire.

### Egy nap (3–5 perc, de bármeddig lehet maradni)

1. **Kikelés (~30 mp).** A kert reggeli fényben nyílik. Ami tegnap a földbe került, kibújt: a kamera odarepül, kis felfedő animáció.
2. **Gondozás (~30 mp).** Lekonyult növény megérintése = öntözés, felél. Virágzó fáról érintéssel magot szedsz. Metszel, kötözöl, ha kedved van.
3. **A nap magja (1–2 perc).** Közös DNS-tábla, a szabad géneknél te döntesz → spirál → elvetés. A végén megosztható.
4. **Ha van kedved: keresztezés** a gyűjtött magokkal (két mag → tábla → három csíra, egyet választasz, a másik kettő csillag lesz). Ezek is másnap kelnek ki.
5. **Nézelődés:** repülés a kertben.

### A nap magja

- **Mindenkinek ugyanaz a tábla**, de 1–2 szabad génnél a játékos választ → rokon, mégis saját növény.
- A tábla a dátumból determinisztikusan generálható, **szerver nélkül, offline is** működik.
- Megosztás az első verzióban: kép + kód. „Mások mit választottak” statisztikához később szerver kell.
- **Kihagyás:** az elmúlt 7 nap magjai a magos táskában várnak, bármikor elvethetők. Régebbiek nem.
- **Megvalósítás (M2):** a feladvány a helyi dátum napsorszámából jön, saját, motorfüggetlen véletlenszám-generátorral (xorshift32), így minden eszközön ugyanaz. A táskában a mai és legfeljebb 7 korábbi nap megfejtetlen magja „Megfejtem” gombbal áll (a játék kezdete előtti napok nem), a kész napi mag „Elvetem” gombbal: az aktív bolygóra kerül, holnap kel ki. A félkész tábla naponként mentődik. A spirál, az elvetés és a kikelés látványa: lásd „A nagy pillanat”.
- **Fajnév a DNS-ből:** ugyanaz a DNS mindig ugyanazt a latin nevet kapja (a második tag a virágszínből, pl. *rosea*, *violacea*), így a nap magja összevethető („nekem Calulina lilacina lett”), és a táskában és a kikelt fán ugyanaz a név.

### Tempó

- A nap magja: naponta 1.
- Keresztezés: a **gyűjtött magok** adják a korlátot (napi kb. 1–3 mag a virágzó fákról; egy keresztezés két magot használ fel, a nap magja is lehet a pár). A virágzás napokig tart, a korlátot a természet adja, nem számláló vagy pénz.
- **Maghozás (M5, `care.gd`; M8: közös):** a virágzó fák aránya ~39%, így sok fánál túl sok mag jönne. Ezért naponta a kert virágzó fái közül csak az első K hoz magot (a „magot érlelő” fák, a fa kódjából és a napból számolt sorrendben, minden nap mások). K ≈ 0,4 + 0,6·√n (n = a játékos összes bolygójának kikelt fái – M8 óta közös, így több bolygóval sem jön naponta több mag), legfeljebb 3, a tört részt a nap dönti el. Mérve (90 nap): 3 fa: 1,1/nap; 5 fa: 1,3; 10 fa: 2,2; 20 és 30 fa: 3. A szomjas fa is lehet „érlelő”, de csak öntözés után ad magot. A többi virágzó fán a táblán: „ma nem érlelt magot”.
- **Minden elvetett mag másnap kel ki.** Ez az egyetlen várakozás a játékban, és jutalom, nem büntetés.

### Gondozás

- **Öntözés:** ingyenes, korlátlan, nincs vízszámláló. Az elhanyagolt növény csak lekonyul (és nem fejlődik tovább), egy öntözéstől feléled. Nincs halál.
- **Maggyűjtés:** virágzáskor a fáról érintéssel. Ez köti össze a gondozást a keresztezéssel.
- **Metszés:** egy ág levágása egy érintéssel, azonnal.
- **Kötözés:** egy ágat irányba húzol, az napok alatt lassan arra hajlik (bonsai-érzés, újabb ok a visszatérésre).
- **Godotban (M4, `godot/care.gd` szabályok, `godot/tending.gd` látvány és érintés):**
  - **Szomjazás:** ha egy fát 3 napja nem öntöztek (az utolsó öntözés, vagy ha még soha, a kikelés óta), lekonyul: a korona lehajlik, az ágvégek és a levelek lógnak, a csúcs kissé biccent, a lomb fakóbb, sárgás-olajos (a 4. naptól még kicsit jobban). A szomjas fa virágai félig becsukódnak, és nem hoz magot (nem fejlődik tovább). Nincs halál. Mellette félmagasságban apró, lassan lüktető vízcsepp-fény (kívülről halvány pont).
  - **Öntözés:** leszállva a szomjas fára egy koppintás. Csillogó cseppek hullanak a lombra (~2 mp), vízszínű fénygyűrű a tövénél, fényhullám fut fel a fán, a fa rugalmasan, egyszer kicsit túllendülve felegyenesedik (~2 mp), a színe visszatér. `watered` = ma, mentés. A lebegő táblán: „Megöntözted. Lassan felegyenesedik.” Nincs vízszámláló.
  - **Virágzási ciklus (9 nap):** bimbó 2 nap (kisebb, zárt, zöldes tövű virágok) → virágzás 3 vagy 4 nap (a fa kódjából) → elnyílás 1 nap (szétterülő, fakó, barnás szirmok, a virágok fele már lehullott) → pihenés (nincs virág, a virág-MultiMesh ki se rajzolódik). A kezdő fáknál a ciklus eltolása a hely sorszámából jön (hely × 3 + hely / 3, mod 9), így egymás után virágoznak: már a 3 kezdő fa közül is minden nap virágzik egy, de nem mind. Frissen kikelt fa első bimbója 2–4 nappal a kikelés után jön (2 + hely mod 3), utána 9 naponta; mivel a magok különböző napokon kelnek ki, ezek is elszórtan virágoznak. Napváltáskor minden lassan átúszik.
  - **Maggyűjtés:** virágzó, nem szomjas fán, ha ma még nem szedtél róla, egy virágon arany csillanás. Leszállva egy virágra (vagy a csillanásra) koppintva a mag kis fényként kibújik, felemelkedik és ívben a Táska gombja felé repül (a 2D rétegben, hogy a gombok fölött és a világos égen is látsszon); a gomb felvillan. A leszedett virág összecsukódik és elsápad (a helye a fa rekordjában, újratöltés után is). Naponta fánként egy mag: a csillanás eltűnik, a táblán „magot hozott ma”. A mag: a fa DNS-e, eredet `gyujtes`, név „<fajnév> magja”, szülő = a fa DNS-e, `tree` = a fa azonosítója, `hidden` = a fa lappangó virágszíne. A kertben összesen naponta kb. 1–3 mag (lásd Tempó, M5).
  - **A lebegő tábla (a fára koppintva):** a név alatt az állapot: „szomjas”, „fiatal / pihen · N nap múlva bimbózik”, „bimbós · holnap kinyílik”, „virágzik (még N napig) · koppints egy virágra: mag” / „magot hozott ma”, „elnyílt”. Éjjel a „virágai világítanak” fák csak virágzáskor világítanak.
  - **Olcsó:** shader-uniformok (`droop`, `thirst` a fán/levélen/virágon; `bloom_size/open/fade/drop`, `pick` a virágon), csak változáskor írva; a jelek egy MultiMesh (≤64 fénypont), a cseppek egy másik (44, csak öntözéskor). A váz és a determinizmus nem változik.
  - A próba-bolygón (nem mentett) a fák mindig virágoznak és nem szomjaznak, a mérés így változatlan.
- **Az alakítás nem öröklődik**, és a DNS-t sem változtatja. Az utód a nyers DNS-ből nő.
- **Technikai feltétel:** a növény = DNS + kód + *alakítási lista* (ág-index, művelet, kezdőnap). A generátor (`plant_gen.gd`) minden ágat ugyanúgy végigszámol (a véletlenszám-sorrend nem tolódhat el), és a listát csak a kirajzolásnál alkalmazza. Így determinisztikus marad, és minden részletességi szinten ugyanaz a váz.
- **Godotban (M8, `godot/plant_gen.gd` generátor, `godot/shaping.gd` felület és látvány):**
  - **Ág-index:** a generálás sorrendje (mélységi bejárás). A váz csak a vázat adó véletlenszám-sorozatból jön, a részletesség nem hat rá, így az index mindhárom szinten ugyanaz, és ugyanabból a DNS-ből és kódból mindig ugyanaz. Egy ág leszármazottai közvetlenül utána jönnek: az ág a rajta nőtt ágakkal egy összefüggő tartomány, a csúcsai, levelei, virágai is összefüggő szeletek – így a levágás és a hajlítás egyszerű szeletművelet.
  - **Alkalmazás:** a generátor mindent végigszámol (a levágott ág levelei is beleszámítanak a korlátokba), és csak a végén: a levágott ág és leszármazottai háromszögei kimaradnak, a leveleik, virágaik nulla méretűek (a sorszámok, így a többi levél és virág nem változik); a kötözött ág a tövénél elfordul, a leszármazottai vele (a mélyebb ágak előbb, így az ős hajlása viszi a már hajlott gyereket). **Üres listával a kimenet bitre ugyanaz, mint előtte** (`--shapetest`, 18 rögzített lenyomat), egy levágás egyetlen más vázpontot, csúcsot, levelet sem mozdít.
  - **Kötözés napok alatt:** a bejegyzés a kötözéskori állást és a célt tárolja (az ág eredeti keretében, kvaternió). Az előrehaladás a kötözés napjától: aznap ~11% (az ág már enged egy kicsit), a 3. napon ~56%, a 6. naptól 100%. A fa napváltáskor (vagy „nap +1” után) épül újra, csak ha a hajlás még tart. Újrakötve onnan hajlik tovább, ahol most tart.
  - **Felület (leszállva):** a lebegő tábla alatt „Alakítás” (az „Elengedem…” mellett) – így nem keveredik az öntözéssel, a maggyűjtéssel és az elengedéssel (alakító módban ezek nem futnak, és a kamera sem forog magától). Alul kis lap: tipp, „Levágom”, „Visszavonom”, „Kész”. Ágra koppintva (ujjnyi, ~48 képpontos találati sugár; a vastagabb ág kicsit előnyt kap) az ág és minden, ami rajta nő, halvány, lüktető arany fényburkot kap – már az ujj lenyomásakor, hogy lásd, mit fogsz meg; a burok a lombon át is látszik. Még egy koppintás (vagy „Levágom”): levágás – az ág a tövénél elválik, kifelé dől, lehull, a levelei pörögve szétszóródnak, és pontrácsosan elhalványul (~2,4 mp). Egy ágat megfogva és elhúzva: kötözés – a fogás pontja az ág tövétől nézve az ujj felé fordul (egy húzással legfeljebb 60°, összesen 85°), a cél mentődik, és amíg az ág hajlik, kis fénylő pontsor-zsinór köti a kötés pontját a céljához (napról napra rövidül). A törzs (0. szint) nem vágható és nem köthető (rákoppintva halk tipp). **Visszavonás:** a mai műveletek visszafelé (újrakötésnél a régi kötés visszaáll); a korábbi napokéi már a fa részei. Kilépés: „Kész”, vagy egy koppintás a fa mellé.
  - **Mentés és öröklés:** a lista a fa `shaping` mezőjében (lásd Játékállapot). Az elengedett fa csillaga megőrzi, de a magból kikelő fa – visszahozott csillagból, gyűjtött vagy keresztezett magból – üres listával, a nyers DNS-ből nő.
  - **Olcsó:** az alakítás csak a kirajzolt adatot változtatja (a háromszögszám a levágással csökken); újraépítéskor a részletes szint azonnal, a másik kettő a következő képkockákban épül (natívan 5–25 ms szintenként). A kiemelés egy részfa-mesh additív anyaggal, a zsinór egy ≤160 pontos MultiMesh, a lehulló darab a fa anyagainak `#define FALL` változata (csak a lehullás alatt él).
  - **Teszt:** `?alakit` (leszállás az első fára alakító módban), „nap +1” a hajláshoz.

### Visszahozó elemek

Kikelés másnap, a nap magja, múló virágzás (ilyenkor gyűjthető mag), lassan hajló kötözött ágak, valódi évszakok, barát magja kóddal. **Napi legfeljebb egy értesítés** (pl. „Kikelt a tegnapi magod”). Kihagyott nap után semmi nem vész el.

## Bolygók és csillagok (a kert)

Döntés: 2026. 11. 10. A „kert” kis bolygók sora. A játékos nemcsak fákat, hanem világokat is tenyészt: **a bolygó DNS-ét a rajta élő növények adják**.

### Bolygó

- **Kicsiben indul** 1–3 növénnyel, és minden új fával kicsit nő, kb. 30 fáig (teljesítménykeret).
- **Ha megtelt, mellette új kis bolygó születik.** Ez természetes mérföldkő, kb. 2–3 hetente. A régi bolygó megmarad, a bolygók között lehet váltani.
- **Kamera:** húzással forgatod a bolygót, csípéssel közelítesz. Egy fára koppintva a kamera lerepül hozzá a felszínre: ott van tiltshift, gondozás, metszés.
- **Teljesítmény:** a túloldali fák nem látszanak, kívülről minden fa apró (egyszerűsített szint), a felszín közelében csak a közeli 3–4 fa részletes.

**Godotban (M7, `godot/planet_system.gd` kis bolygók, születés, váltás; `state.gd` megtelés, célbolygó):**
- **Megtelés:** `GameState.PLANET_FULL` = 30 fa (a kelésre váró magokkal együtt). Ha a **legutolsó** bolygó megtelik (az elvetéssel vagy a teszt-feltöltéssel), mellette azonnal új, üres bolygó jön létre a mentésben (`ensure_next_planet`, kód: játékoskód + sorszám, `born_seen` = hamis). A régi bolygó megmarad; ha egy régebbin elengedéssel hely szabadul fel, oda is lehet vetni, de új bolygó csak a legutolsó megtelésekor születik.
- **Születés (~10 mp, koppintás gyorsít):** a következő nyugodt pillanatban (nincs nyitott lap, elvetés, kikelés) a kamera kicsinyít; a megtelt bolygó peremén meleg fénypont gyúl, csóvával, ívben kiúszik a bolygó alá, ott fénygyűrűvel szétnyílik, és fehéren izzó gömbből kibomlik a kis új bolygó, ami lassan a pályájára áll. Felirat: „<régi> megtelt. Mellette megszületett <új>. A következő elvetett magod már oda hull. Koppints rá, és odarepülsz.” Utána `born_seen` = igaz (ha közben bezárul a lap, legközelebb újra lejátszódik).
- **A csupasz bolygó:** amíg nincs látott (kikelt és megmutatott) fája, és nem is engedtek el róla fát, sima, halvány gyöngyház-levendula gömb, fű, hold és gyűrű nélkül („csupasz, fiatal bolygó · még nincs alapító fája”). Az első elvetett mag lesz az alapító (`founders`); amikor másnap kikel, a kikelés-jelenetben a bolygó felveszi a jellegét: a domborzat lassan kiemelkedik (a fák vele mozognak), a színek átúsznak, a fű kinő, a holdak és a gyűrű megjelennek; a feliraton: „Ő <bolygó> alapítója: a bolygó felveszi a jellegét.”
- **Kis bolygók (a többi bolygó):** bolygó-nézetben kicsinyítve (csípés 0 alá: a kamera legfeljebb kétszer messzebb húzódik) a többi bolygó az aktív alatt sorakozik, a háttérben: jobbra az újabbak, balra a régebbiek, a távolabbi sorszámúak lejjebb és hátrébb (oldalanként 3). Olcsó változat: egy alacsony felbontású gömb (~360 háromszög, gyűrűvel ~520) a bolygó színeivel (ugyanabból a bolygó-DNS-ből, `Planet.look_of`), légkör-peremmel, a fák apró színes pöttyök a shaderben (≤16), a kikelésre váró fák meleg, lüktető pöttyök. A valódi méret 0,62-szeresén látszanak. Közelről és leszállva nem látszanak; ha csak egy bolygó van, a kicsinyítés sem megy 0 alá. Átlátszatlan anyag, pontrácsos áttűnéssel (az átlátszót a lencse-utófeldolgozás lefedné).
- **Váltás (~4 mp):** egy kis bolygóra koppintva a kamera felé fordul, ívben odarepül (a cél közben a valódi méretére nő), a légkörébe érve a pára színe egy pillanatra betölti a képet: ekkor cserélődik a teljes bolygó (`active` mentve, a fák a meglévő sorbaállítással, képkockánként épülnek és kinőnek), és a kamera a pára mögül az új bolygó elé ér. Újratöltéskor az aktív bolygó nyílik.
- **Mi közös, mi bolygónkénti:** a magos táska, a nap magja és a keresztezés **közös** (a játékosé). A **csillagok bolygónként** (minden bolygó egén a saját elengedett fái és a rajta választott keresztezés csírái). Az elvetés mindig az aktív bolygóra megy, ha nem telt meg; **megtelt aktív bolygónál a legújabb, még nem megtelt bolygóra** – a táska ezt kiírja („<régi> megtelt. Az elvetett mag a legújabb bolygóra hull: <új> (odarepülünk).”), és az „Elvetem” után a kamera előbb odarepül, ott hull le a mag. A maghozás tempója közös (M8: az összes bolygó kikelt fáiból, napi kb. 1–3 mag összesen), a szomjazás és a virágzás minden bolygón a napokból jön (a nem látott bolygón is, büntetés nélkül).
- **Teszt:** „tele” (a második apró sorban: a bolygó feltöltése kikelt teszt-fákkal → megtelik, megszületik az új), „…” → „új bolygó” (üres bolygó az aktív mellett, akkor is, ha nem telt meg).

### A bolygó DNS-e

| Növény génje | → Bolygó tulajdonsága |
|---|---|
| Virágszín | Légkör, égbolt színe |
| Szirmok | Holdak, gyűrű |
| Levél | Felszíntakaró (fű, moha, páfrány, kavics) |
| Termet | Domborzat (sima, dombos, sziklás, tüskés csúcsok) |
| Kéreg | Kőzet, talaj színe |
| Lomb | A fű színe |

- **Alapító:** a bolygó első növénye adja a karaktert. A darabos tulajdonságok (holdak száma, felszíntakaró fajtája, domborzat típusa) tőle jönnek, és nem változnak.
- **Átlagolás:** a folytonos értékeket (színárnyalatok, holdak mérete) minden további növény finoman elhúzza. A domborzat magassága az alapításkor dől el (az akkori növényekből), később nem változik, hogy a fák ne süllyedjenek el. Az alapító súlya nagyobb (pl. 1/3), a többin a többiek osztoznak. Az árnyalatok átlaga körkörös (szín-kerék).
- **Saját mag:** minden bolygónak van kódja (pl. a játékos kódja + a bolygó sorszáma). Ebből jön a domborzat zaja, a kráterek és a holdak helye, így **két bolygó sosem egyforma**, még azonos növényekkel sem.
- Determinisztikus: a bolygó kinézete = f(bolygókód, a rajta élő növények DNS-e). Ültetéskor és elengedéskor lassan, látványosan változik.

### Csillagok

- **Elengedett fából csillag lesz.** Ha egy fát elengedsz (pl. helyet csinálsz neki, vagy nem kell), felszáll az égre. Nincs selejtezés és nincs halál.
- A bolygó elengedett fái a bolygó egén **csillagképet** rajzolnak. Ez a bolygó emléke és egyben a herbárium: koppintásra látod a fát, és **bármikor visszahozhatod**, újra elvetheted.
- A keresztezés nem választott csírái ugyanígy csillaggá válnak (nincs külön magtár). (M5: a bolygó `stars` listájában `origin` = `csira`, felszálló fény-effekttel.)

**Godotban (M6, `godot/sky_stars.gd` csillagkép és elengedés-látvány, `godot/herbarium.gd` lap, megerősítés, csillagjel):**
- **Elengedés (két koppintás, véletlenül nem megy):** leszállva a fa lebegő táblája alatt halvány „Elengedem…” gomb (vagy hosszan – 0,65 mp – nyomva a fát), utána megerősítés: „Elengeded? <fajnév> fénnyé válik, és csillag lesz <bolygó> egén. A helye felszabadul. Bármikor visszahozhatod.” [Mégse] [Elengedem]. A fa felragyog (fényhullámok futnak fel rajta, önfény), a csúcsaitól kezdve visszahúzódik, és ~40 fénypont válik ki belőle, amelyek spirálban a korona fölé gyűlnek; a gyűlő fény ~3,5 mp után lassan, csóvával, ívben felszáll az égre, közben a kamera felemelkedik és az ég felé fordul. A csillag kigyullad (szétfutó gyűrű), és nyílik a lapja: „<fajnév> csillag lett <bolygó> egén. Bármikor visszahozhatod.” (~8 mp; koppintás gyorsít.) Nem szomorú: fény, nem hervadás.
- **Mentés:** a fa teljes rekordja a `stars` listába kerül (DNS, kód, név, rejtett szín, eredet, ültetés és kikelés napja) + `released` (az elengedés napja) és `seq` (a csillag sorszáma a bolygón). A helye felszabadul (új fa kerülhet oda).
- **A bolygó-DNS** ezután a megmaradt fákból áll össze (a színek lassan átúsznak). **Az alapító elengedése:** a darabos jelleg (domborzat típusa és magassága, felszíntakaró, holdak, gyűrű) a mentett alapító-DNS-ből jön (`founders`), így nem változik, a fák nem süllyednek el; a folytonos színekben az alapító 1/3-os súlyát a legrégebbi megmaradt fa veszi át; ha egy fa sem marad, a színek is az alapítóéi. A megerősítés ilyenkor külön szól: „Ő alapította a bolygót: a bolygó formája, talaja és holdjai megmaradnak…”. **A bolygó nem zsugorodik:** az eddigi legtöbb kikelt fához méreteződik (`peak`), így a fák közti hely sem fogy el.
- **Csillagkép:** az elengedett fák és az el nem választott csírák. A helyük determinisztikus: a bolygókódból és a csillag sorszámából egy lassan növő, ágas minta (minden új csillag egy korábbihoz kapcsolódik – legtöbbször az előzőhöz –, a többitől távol). Vékony, halvány vonal köti mindegyiket a legközelebbi megmaradt őséhez; egy csillag visszahozása nem mozdítja el a többit. A csillag színe a fa virágszíne; nappal halvány, éjjel fényes, lassan pislákol. **Hol:** álló telefonon a látószög keskeny (~20° széles), egy rögzített égbolt-irány alig kerülne a képbe, ezért a bolygó égboltja nagyon messze, a kamera mögött lebeg (mint a Hold az autóablakból): bolygó-nézetben a bolygó fölött, a háttérben (a felirat és a gombsor mögött is átdereng), leszállva a fa mögötti égen. Forgatáskor az ég puhán lemarad, aztán visszaúszik. A bolygó és a fák lombja eltakarja. **Olcsó:** a helyek 3D-ben, a rajz 2D-ben (additív körök és vonalak, ≤64 csillag), a gombsor alatt; weben a képkockánként frissített MultiMesh-példányok a WebGL-es próbán nem rajzolódtak ki, a 2D rajz igen, és a lencse sem mossa el.
- **Herbárium (csillagkép-nézet):** a csillagra koppintva (nagy, ~46 képpontos érintési terület; a fa elsőbbséget kap), vagy a jobb alsó sarok kis csillagjelére (a csillagok száma mellette) a kamera kicsit felfordul az ég felé, a csillagkép megnő és a kiválasztott csillag felé tolódik (gyűrű jelöli), a gombsor eltűnik. Alul lebegő lap: a csillag fája kis forgó 3D-előnézetben (a csíraválasztó előnézete), fajnév, a hat gén röviden, eredet („Elengedett fa · a nap magjából nőtt” / „A keresztezés el nem választott csírája (A × B)”), dátum („Kikelt: … · csillag lett: …”). **Lapozás:** „‹ ›”, vagy jobbra-balra húzás az égen – így a kis pontokra sem kell pontosan koppintani. „Bezár”: a kamera visszafordul.
- **Visszahozás („Visszahozom”):** a csillagból mag lesz a táskában (`origin` = `csillag`, a csillag DNS-ével, kódjával – elvetve **pontosan ugyanaz a fa** nő ki, másnap –, szüleivel, rejtett színével, `star_origin`, `star_day`). A csillag felvillan és elhalványul, **eltűnik az égről** (a mag viszi tovább; ha újra elengeded, új csillag lesz belőle, új helyen). A mag fénye ívben a Táska gombjába hull, a gomb felvillan. A táskában „Csillagról hozott magok” szakasz, aranyos kerettel, „(elengedett fa volt / el nem választott csíra volt)”.
- **Teszt:** „+csillag” a második apró gombsorban (3 teszt-csillag), `?csillag` (a csillagkép-nézet nyitva; ha nincs csillag, 5 teszt-csillaggal).
- **Mások bolygói:** a távoli csillagok más játékosok vagy barátok bolygói. Ráközelítve megnézheted őket és aznapi magjukat. Ehhez szerver kell, így ez később jön; az első verzióban barát bolygója kóddal is megnyitható.

## Art design

Döntés: 2026. 11. 10. **Álomszerű pasztell nappal, világító (biolumineszcens) éjszaka.**
Ihletők: az Avatar filmekből az élő, magától világító, érintésre felragyogó természet *elve*, a Timely ébresztőóra-appból az áramló színátmenetek, a puha mozgás és a finom hangok. A konkrét formákat, lényeket nem vesszük át.

### Érzések → eszközök

| Érzés | Eszköz |
|---|---|
| Nyugalom | Lassú, puha, rugalmas mozgás; pasztell; semmi nem villog vagy ugrik |
| Kíváncsiság | Rejtett éjszakai fény, másnapi kikelés, változó bolygó |
| Csoda | Lebegő bolygó, ködös ég, csillagképek, biolumineszcencia |
| Gondoskodás | Érintésre reagáló növény (fényhullám, hang, rezdülés) |

### Napszak (a telefon órája szerint)

- **Hajnal/nappal:** álomszerű pasztell. Barack, levendula és menta színátmenetek, lágy köd, a bolygó pereme enyhén izzik a légkörtől.
- **Alkony:** mély rózsaszín és lila. A növények fénye ekkor kezd előbújni.
- **Éjszaka:** sötétkék és ibolya ég csillagokkal és csillagképekkel, a növények biolumineszcensen világítanak.
- Az átmenetek folyamatosak, a bolygó légköre (bolygó-DNS) színezi őket.

### Éjszakai fény (rejtett tulajdonság)

- A fény **mintázata és erőssége** a DNS-tábla egy rejtett tulajdonságából jön (pl. az átlók bázispárjaiból), a **színe** a virágszínből. Nem minden fa világít egyformán: van, amelyik csak a virágain, van, amelyiken levélerek vagy a kéreg mintái izzanak.
- Csak éjjel derül ki, és öröklődik, így tenyészthető (pl. „a legfényesebb fa”).
- **Érintésre** fényhullám fut végig az ágakon, nappal finom csillámként.

### Mozgás

- Minden átúszik, rugalmas, csillapított mozgással: a kamera, a feliratok és a szél is. Nincs ugrás vagy hirtelen vágás.
- A növények lassan lélegeznek a szélben, a levelek és virágok külön-külön rezdülnek.
- Lebegő porszemek és spórák (nappal pollen, éjjel szentjánosbogár-szerű fénypontok).

### Felület: a világ része (diegetikus)

- **Szinte nincs képernyőelem.** A fa neve és adatai a fa mellett egy kis táblán állnak, vagy fénylő betűkként lebegnek a fák között. Csak közelről látszanak, aztán elhalványulnak.
- A DNS-tábla is a világban jelenik meg: a mag fölött lebegő, fénylő rács.
- A magos táska, a bolygóváltás és a csillagképek is tárgyként vagy helyként jelennek meg, nem menüként.
- Betű: vékony, kerek, jól olvasható; a lebegő felirat finoman világít.

### Hang (generált, a DNS-ből)

- Minden növénynek saját hangja van a DNS-éből (hangmagasság, hangszín). Érintésre megszólal.
- A bolygó fái együtt halk ambient akkordot adnak, így **minden bolygó máshogy szól**. Az akkord ültetéssel és elengedéssel lassan változik.
- Puha, csilingelő effektek (öntözés, kikelés, csillaggá válás), éjjel tücsökszerű háttér.

**Hang – Godotban (M9, `godot/sound_synth.gd` minták és zene, `godot/sound.gd` lejátszás, ambient, némítás):**
- **Nincs hangfájl:** minden hang kódból készül, előre kiszámolt 16 bites `AudioStreamWAV` (22 050 Hz, a pad és a szél 16 000 Hz). Recept = részhangok (szinusz, FM-harang, csúszó hangmagasság), szűrt zaj (szél, víz, levélzizegés) és Karplus–Strong pengetés, saját burkolóval; a végén enyhe zengés (4 fésű + 2 mindentáteresztő szűrő) **a mintába számolva**, csúcsra normálva, az eleje (3 ms) és a vége (40 ms) puhán nullára húzva. 32 minta, ~81 mp hang, ~3,2 MB; natívan ~1,7 mp számolás összesen.
- **Weben:** a Godot 4.7 weben „sample” módban játszik le (`audio/general/default_playback_type.web` = Sample): a minta Web Audio `AudioBuffer` lesz, a hangmagasság a `pitch_scale` (`playbackRate`), a busz hangereje és némítása működik, buszeffekt és `AudioStreamGenerator` nem – ezért kész WAV-ok és a mintába számolt zengés. A minta az első lejátszáskor kerül át a böngészőbe (csak ami tényleg szól). A számolás a háttérben fut, képkockánként 2,5 ms kerettel (ha egy kért hang még nincs kész, előre kerül, 6 ms kerettel; a fák építése alatt fele), az indulás utáni 1,5 mp-ben semmi. Sorrend: a négy növény-hangszín, a tábla hangjai, a padok, tücsök, szél, aztán az effektek.
- **Az első érintésig csend:** iOS Safari csak felhasználói érintés után enged hangot (a Godot az érintés-eseményben folytatja az `AudioContext`-et). Az első koppintás előtt semmi nem szól és semmi nem ütemeződik; utána ~1,2 mp-cel indul az ambient.
- **Növényhang a DNS-ből** (D-dúr pentaton: D E Fis A H, így minden összeillik): **kéreg → hangszín** (fa/marimba: mogyoró, dió, ében, mahagóni; harang/FM: réz, ezüst, palakék, szén; üveg: hamu, füst, nyírfa; pengetés: vörösfenyő, homok, moha), **virágszín → alaphang** (skálafok), **termet → fekvés** (szomorú, zömök mély; oszlopos, bokros magas), **szirmok → díszítés** (1–4 hangos arpeggio, a harangos virág lassabb, telt virágnál oktáv-kettőzés), **lomb → a díszítés iránya** (lépésminta a skálán), **levélforma → csillogás** (egy fényes felhang-réteg hangereje: a kerek levél puha, a tollas, csipkés fényes); a kódból ±10 cent egyéni hangolás és ±5% tempó. A hangszín négy alapmintája A4-en készül, a fa hangja `pitch_scale`-lel (0,5–3; az oktáv-kettőzés 0,25-ig). Megszólal: koppintás a fára (leszálláskor és leszállva), öntözés (lassabb, a csobbanás után), maggyűjtés (egy oktávval feljebb, ha belefér), kikelés (az új fa első hangja), a három csíra megjelenésekor (egymás után, csak az alaphang).
- **Bolygó-ambient (az Ambient buszon, −6 dB):** a fák alaphangjaiból a leggyakoribb 3–5 hangú akkord (döntetlennél a bolygókód dönt; csupasz bolygón alaphang + kvint). 5–8,5 mp-enként egy lassan duzzadó, 7 mp-es pad-hang az akkordból (néha egy második 1–2 mp-cel később), a lélegzetek ~28%-ában egy fa halk saját hangja. A pad meleg vagy üveges (az első fa virágszíne szerint). Éjjel (night > 0,55) 3–7,5 mp-enként 1–3 halk tücsök-csiripelés, nappal 10–18 mp-enként puha szellő. Minden a bolygókódból számolt saját véletlen sorozatból (xorshift32), így **minden bolygó máshogy szól**; az akkord minden lélegzetkor a jelenlegi fákból áll össze, így ültetéssel, elengedéssel lassan változik. Mérve (offline keverés, 40 mp): 11–14 megszólalás, átlag ~−28 dBFS a busz előtt, a fák koppintása ~−16 dBFS.
- **Effektek (az Effekt buszon):** tábla – A=T két, G≡C három csengő hang, törlés halk koppanás, a sor (gén) szerinti magasságban; kész tábla (felfutó harang-arpeggio), spirál (csavarodó csillanások puha akkord fölött), a mag a táskába ér (pengetés), hullás (lefelé csúszó, légies), földet érés (mély puha koppanás + csengés), kikelés (kinyíló akkord), öntözés (csobbanás + cseppek), maggyűjtés (pop + két csillanás), csírák (saját hangjuk) és a két felszálló csíra, elengedés (duzzadó, felfelé hajló akkord, emelkedő csillanások), a csillag kigyullad, visszahozás (lefelé futó csillanások + pengetés), bolygó születése (a fény kigyúlásakor mély harang, a kibomláskor lassú akkord), átrepülés (légsuhogás, a pára mögött csengő akkord), alakítás (ág kiválasztása, metszés: olló + levélzizegés, kötözés: lágy pengetés, visszavonás).
- **Némítás:** a fő gombsorban rajzolt hangszóró-ikon (a webes betűkészletben nincs hangjegy); a Master buszt némítja, és amíg néma, semmi nem ütemeződik. Mentve: `flags.mute` (verzióváltás nélkül). Az iPhone oldalsó (csendes) kapcsolója a Safari Web Audio hangját is elnémítja; a gomb ettől függetlenül kell (Androidon, gépen nincs ilyen kapcsoló, és bekapcsolt csengőnél is lehessen csendben játszani).
- **Képernyőképnél és parancssori mérésnél** (`--shot`, `--bench`) nincs hang (semmi nem számolódik); a weben futó „mérés” alatt sem számol és nem szól.
- **Ellenőrzés:** `godot --headless -- --soundtest[=mappa]` minden mintát legenerál, kiírja a hosszt, a csúcsot, az RMS-t, a minta szélét (kattanás) és az egyenáramot, a számolás idejét; mappával WAV-okba menti (`save_to_wav`), plusz 6 különböző DNS-ű fa koppintás-hangját és két bolygó 40 mp-es ambientjét (ugyanazzal az ütemezéssel, offline keverve). `godot --headless -- --soundplay` a futó játékban (érintés nélkül) minden effektet és pár fa hangját lejátssza, kiírja a lejátszásokat és a háttérszámolás leghosszabb képkockáját (natívan ~9 ms, sürgős hangnál).

### Technikai irány

- **A színeket a shaderekben „festjük”** (színátmenetek, perem-izzás, köd), nem drága utómunkával, így a webes Compatibility renderer és az olcsó Android is ugyanazt mutatja.
- A ragyogás olcsón készül: önvilágító szín + additív halo-sprite-ok. Valódi glow (bloom) csak ha iPhone-on mérve belefér.
- **Felbontás:** a webes build a telefon teljes pixelsűrűségén renderel (iPhone 15: 1179×2556, kb. 3 millió pixel). Az álomszerű, tiltshiftes képen a csökkentett belső 3D-felbontás alig látszik; a mérés után döntünk az alapértékről.
- **Fák részletessége (3 szint, azonos vázzal):** részletes (a kiválasztott mindig, plusz a legközelebbiek 22 egységen belül, összesen legfeljebb 4), egyszerűsített (kívülről mindenhol, leszállva a kiválasztott fa közelében), távoli (~2,5k háromszög, leszállva a háttérben, ahol a tiltshift úgyis elmossa). Árnyékot csak az egyszerűsített szint vet, részletes fánál csak-árnyékként – így a részletes fát nem kell kétszer kirajzolni.
- **Mérés (iPhone 15, Safari, 2026. 11. 10.):** leszállva kb. 650–700k háromszög fér 60 fps-be 100%-os felbontáson; 30 fával 43 fps volt, nagy fűsűrűségnél a 75%-os felbontás +20%-ot hozott. Ezért sűrű kijelzőn alapból 75% a belső felbontás.
- **Fű:** csomókban (4 szál/példány), a bolygóhoz rögzítve: a felszín kocka-gömb csempékre van osztva (laponként 6×6), egy csomó helyét, irányát, méretét a shader számolja a csempe és a csomó sorszámából, a magasságot a felszín rácsából. Így a fű sosem generálódik újra, akárhogy mozog a kamera. A sűrűség a sorrendből jön: ritkább fűnél csak a csempe első csomói látszanak, sűrűbbnél a továbbiak puhán előnőnek (nem pattannak elő); a kamera körül és a nézett pont (leszállva a fa töve) körül sűrű, kifelé a távolság négyzetével ritkul a bolygót borító alapig. Rajzolás csempecsoportonként (3×3 csempe egy hívás, a pufferben csempénként csak a szükséges csomók), a látóhatáron túli csoportok kimaradnak; a kamerához közeli szálak részletesek (íves), a távoliak egyszerűek, a határ előtt a részletes szál kiegyenesedik, így a váltás nem látszik. A talaj fűszínű, szálas mintájú, így a hézag nem kopasz; a széllökések fényhullámként futnak végig.
- **Lencse (utófeldolgozás, `shaders/lens.gdshader`):**
  - **Bolygó-nézet = makett (tilt-shift):** a kamera ferdén, felülről néz a felszín egy pontjára, mint egy tilt-shift légi fotón; a kép közepén vízszintes éles sáv, fölötte-alatta erősödő elmosás. Húzással a felszín gördül, csípéssel közelítesz; kicsinyítve a kamera felemelkedik, és a végén az egész bolygó látszik szemből (ott enyhébb a sáv).
  - **Leszállva = DSLR-mélységélesség:** a fókusz a fán, a lomb szélességének megfelelő éles zónával; előtér és háttér a távolság arányában mosódik el.
  - **Virágra koppintva makró:** a kamera a virágra közelít, nagyon sekély mélységélességgel. Csípéssel vagy máshová koppintva vissza a fához.
  - **Mélységtudatos elmosás:** egy minta csak akkor kerül a képpont elmosásába, ha mögötte van, vagy ha előtte van, de a saját elmosása elér idáig. Így az éles fa nem folyik bele a mögötte lévő elmosott égbe/háttérbe (nincs glória), az elmosott előtér viszont puhán rálóg. 8–20 minta (az elmosás méretétől függően), mindegyik négy képpont sarkára esik, így négyet átlagol (kevesebb szemcse).
  - Weben a 3D képernyő-textúrának nincs használható mipmapje (a szintjeit a ragyogás/glow használja), ezért ott csak a 0. szintet olvassuk. A 2D (vászon) rétegben van mipmap, de oda a mélység nem jut át az égbolt elvesztése nélkül – ha a szemcsét tovább kell csökkenteni, ez a következő lépés (égbolt saját négyszögön, átlátszó háttér, CoC az alfa-csatornában, a ragyogás a lencsében).
- **Fű:** szálanként renderelve, a [2Retr0/GodotGrass](https://github.com/2Retr0/GodotGrass) (MIT) és a Ghost of Tsushima GDC-előadás ötletei alapján: íves, szélben söprő szálak, a nézetből oldalra esők kiszélesítve, lekerekített normál, átsütő fény. Csak MultiMesh + spatial shader, compute nélkül, így weben is fut. A bolygót mindenhol ugyanaz a rögzített fű borítja; a kamera és a nézett pont körül sűrűbb (lásd fent). Éjjel a szálak egy része a csúcsán világít.

## Játékállapot és mentés

Döntés: 2026. 11. 10. Az egész játék egyetlen JSON-állapot (`godot/state.gd`, `GameState`), helyben mentve (`user://mag_mentes.json` + `.bak` másolat; weben IndexedDB). **Minden változás után azonnal mentünk**, mert a böngésző bármikor bezárhatja a lapot.

- **Játékos:** első indításkor véletlen, 6 jelű kód (félreérthető betűk nélkül). A bolygókód = játékoskód + sorszám (pl. `K7MQ2P-1`), a növénykód = bolygókód + a hely sorszáma.
- **Bolygó:** kód, alapítók (az alapításkori növények DNS-e, rögzítve: ebből jön a darabos jelleg és a domborzat magassága, így újratöltéskor és az alapító elengedése után is ugyanaz a bolygó), fák, csillagok (elengedett fák és el nem választott csírák: a fa-rekord + elengedés napja + sorszám), a következő csillag sorszáma, az eddigi legtöbb kikelt fa (`peak`, a méretéhez).
- **Fa:** DNS, kód, irány a bolygón (mentve, nem újraszámolva), forgatás, méret, eredet, szülők, ültetés napja, kikelés napja, látta-e már a kikelést, utolsó öntözés, utolsó maggyűjtés napja és a leszedett virág helye, alakítási lista, név.
- **Magos táska:** mag = DNS + eredet (napi, gyűjtött, keresztezett, csillagról – ilyenkor a csillag kódjával, eredetével és napjával) + nap + szülők DNS-e + lappangó virágszín (`hidden`); gyűjtött magnál az anyafa azonosítója (`tree`) és a mag neve (`name`, „<fajnév> magja”); keresztezett magnál a csíra kódja (`code`, ezzel nő ki). A táskában szakaszonként (a nap magjai, gyűjtött magok, keresztezett magok – külön színnel).
- **Keresztezés (`cross`):** félkész tábla (`a`, `b` = a két mag, `grid`), vagy kész: választásra váró csírák (`done`, a két szülő DNS-e és neve, a kész tábla, a három csíra DNS-ével, kódjával, rejtett színével, 1/2/M jelével). A két mag a tábla elkészültekor fogy el, így a csírák újratöltés után is megvannak.
- **A nap magja (`daily`):** napsorszám → félkész rács (36 érték), vagy kész jelző + a választott DNS. A 7 napnál régebbi félkész rácsok törlődnek.
- **Verzió 2 (M4):** a fán `gathered` (nap) és `gathered_at` (a virág helye), a magon `tree` és `name`; a régi mentésben hiányzó mezők alapértéket kapnak.
- **Verzió 3 (M5):** a fán, magon és csillagon `hidden` (lappangó virágszín, -1 = a virágszínéhez tartozó alapérték), a játékállapotban `cross`; csillag `origin` = `csira`.
- **Verzió 4 (M6):** a bolygón `next_star` és `peak`, a csillagon `seq` (a régi mentésben a lista sorrendjéből), a csillagról hozott magon `star_origin` és `star_day`.
- **Verzió 5 (M7):** a bolygón `born_seen` (a születését látta-e már a játékos; a régi mentésben igaz). Az `active` (az aktív bolygó indexe) bolygóváltáskor mentődik.
- **Alakítási lista (M8, a v5 `shaping` mezőben, verzióváltás nélkül – eddig mindenhol üres volt):** `[{"op": "metszes" | "kotozes", "branch": ág-index, "day": nap}]`, kötözésnél `"from"` / `"to"` (az ág elfordulása a tövénél az ág eredeti keretében, kvaternió `[x, y, z, w]`: a kötözéskori állás és a cél) és újrakötésnél `"prev"` (a régi kötés, a visszavonáshoz). Betöltéskor a számok egészre / tömbre igazodnak, a hibás bejegyzés kimarad.
- **Napok:** a helyi dátum napsorszáma; minden napfüggő dolog a `GameState.today()`-t használja, amit a teszt-eltolás (`?nap=+1`, „nap +N” gomb) is módosít, így a „másnap” telefonon is kipróbálható.
- **Verziószám** a későbbi migrációhoz; a hiányzó mezőket betöltéskor alapértékkel pótoljuk.
- A `--shot` és a `--bench` nem olvas és nem ír mentést (a `--shot=...,state` csak olvas, vagy a `--state=fájl`-ba ír); a „próba” bolygó sem kerül a mentésbe.

## Bevétel

Ingyenes, reklám nélkül. Támogatás: borravaló fogyó IAP-ként (App Store 3.1.1 megengedi), kozmetikai támogatói csomag (pad, szökőkút, kerti dísz). Weben külső támogatási link. Várható bevétel alacsony, ez nem üzleti terv.

## Platform és motor (döntés: Godot 4.7)

Mérések iPhone 15-ön (2026. 11. 09.):

| Változat | Eredmény |
|---|---|
| Three.js, claude.ai keretben | 26–30 fps, de a valódi render csak 4 ms (az iOS keretben 30 fps-re korlátoz) |
| Godot web, 1 fa, árnyékkal (219k háromszög) | 60 fps |
| Godot web, 30 fa, egyszerűsített (~710k) | 60 fps |
| Godot web, 30 fa, mind teljes (~4,3M) | 40 fps |

Miért Godot: valódi árnyék, ragyogás, tónusleképezés beépítve; natív mobil renderer; a jelenet és a kód szöveges, jól vibe code-olható. Kockázat: a web Compatibility rendererrel fut (gyengébb kép, más színek), az iOS IAP-pluginokat ki kell próbálni, olcsó Androidon még nem mértünk.

## Megoldott/nyitott kérdések

- [x] Engine: Godot 4.7, mobil renderer natívan, Compatibility weben
- [x] Fő mechanika: DNS-tábla
- [x] Kert nézet: szembőli, tiltshift, analóg kar
- [x] Napi kör: kíváncsiság + a nap magja + gondozás (metszés, kötözés)
- [x] Kert = növekvő kis bolygók, bolygó-DNS a növényekből, elengedett fa = csillag
- [x] Art design: pasztell nappal, világító éjjel, diegetikus felület, DNS-ből generált hang
- [x] Bolygó-prototípus: domborzat, légkör, holdak, gyűrű, felszíntakaró a bolygó-DNS-ből; forgatás, csípés, koppintásra leszállás; napszak (valódi idő vagy gomb); rejtett éjszakai fény a tábla átlóiból; érintésre fényhullám; lebegő névtábla
- [x] Új bolygó születése, ha megtelt; bolygóváltás (M7: 30 fánál megtelik, mellette fénypontból kibomló csupasz bolygó, az első kikelő fa adja a jellegét; kicsinyítve a többi bolygó olcsó kis változata, koppintásra átrepülés)
- [ ] Mérés iPhone 15-ön (bolygó-nézet, leszállás 4 részletes fával)
- [x] Csillagképek, visszahozás az égről (M6: elengedés megerősítéssel, fénnyé oszló fa, felszálló fény; determinisztikus, növő csillagkép; herbárium-lap 3D-előnézettel, lapozás; „Visszahozom” → mag a táskában)
- [x] A nap magja: dátumból generált tábla, magos táska (7 nap), egyszerű elvetés (M2)
- [x] Hang a DNS-ből (M9: kódból számolt minták, weben is; fánként saját hangszín, alaphang, díszítés; bolygónként más ambient akkord, éjjel tücskök, nappal szellő; effektek a nagy pillanatokhoz és a gondozáshoz; némítás mentve)
- [x] Alakítási lista a generátorban (metszés, kötözés) (M8: stabil ág-index, levágás és napok alatt hajló kötözés a kirajzolásnál, mindhárom szinten ugyanaz a váz; alakító mód kiemeléssel, lehulló ággal, fénylő zsinórral, visszavonással; nem öröklődik)
- [x] DNS-tábla átvitele Godotba (logika, feladvány, legközelebbi szabályos DNS, felület)
- [x] Kettős spirál és elvetés-animáció átvitele Godotba (M3: spirál, mag a táskába, hullás a bolygóra, a kelésre váró mag jele)
- [x] Helyi mentés (`godot/state.gd`): játékoskód, bolygók és fáik a helyükkel, csillagok, magos táska, napok teszt-eltolással; első indításkor 3 kezdő fa a játékoskódból
- [x] Több saját növény a kertben, másnapi kikelés (M3: kamera odarepül, csíra kinő, felirat, `revealed` mentve)
- [x] Öntözés, lekonyulás, virágzási ciklus (bimbó, virágzás, elnyílás), maggyűjtés virágzó fáról (M4)
- [x] Keresztezés (M5): táska → keresztezett tábla (szülők génjei, legközelebbi szabályos DNS, 1/2/M, szabad sorok a szülők génjeivel) → három csíra 3D-előnézettel → egy mag (spirál), kettő csillag; rejtett virágszín; maghozás tempója (napi 1–3)
- [x] Herbárium (M6: a csillagkép egyben herbárium – lap, lapozás, visszahozás)
- [ ] Mérés olcsó Androidon
- [ ] iOS-build Mac nélkül (GitHub Actions macOS + TestFlight, Apple Developer-tagság kell)
- [ ] IAP próba (borravaló)
