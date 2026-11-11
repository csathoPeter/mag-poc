# Értékelés és kerekasztal – 2026. 11. 11.

Öt független értékelő nézte meg a játékot (a `5a0a108` állapotot), majd két körben átbeszélték a véleményüket. A moderátor Pétert képviselte: az alapelveket (nincs büntetés, időzítő, szerver, fizetős gyorsítás) és azt, hogy egy ember fejleszt, telefonról.

| Értékelő | Ki ő | Mit látott | Pontszám |
|---|---|---|---|
| [Bence](01_bence.md) | 18, egyetemista, Brawl Stars, a Wordle-t a haverok miatt játssza | 45 kép + játékos-leírás | 5/10 |
| [Dóra](02_dora.md) | 32, product manager, villamoson ingázik, cozy játékok, Wordle/Duolingo | 45 kép + játékos-leírás | 7/10 |
| [Marika](03_marika.md) | 52, iskolatitkár, nem tech savvy, pasziánsz, Wordle a lányától | 45 kép (a leírást „nem kapta meg”) | 6/10 |
| [Réka](04_reka.md) | UX/UI és vizuális designer | 45 kép, utána a DESIGN.md „Felület” és „Stílus” része | – |
| [Tamás](05_tamas.md) | játékfejlesztő, mobil puzzle/cozy, Godot | kód, DESIGN.md, a próbák lefuttatva | – |

A képek ([kepek_1.jpg](kepek_1.jpg), [kepek_2.jpg](kepek_2.jpg)) fej nélkül, szoftveres renderelővel készültek, 390×780-as telefon-képernyőn, egy friss játékkal (a 21–30., 33. képhez a teszt-módok adtak magot, csillagot, teli bolygót). A játékos-leírás: [06](06_jatekleiras_a_reviewereknek.md), a moderátor bevezetője a tényellenőrzéssel: [07](07_moderator_bevezeto.md). **Amit egyikük sem tudott megítélni:** az érintés érzését, a hangot, a valódi sebességet és a betöltési időt. Ezeket Péter telefonos tesztje adja.

## Amiben mindenki egyetértett

- **Az alapötlet erős:** a napi feladványból kel ki a saját fa, és másnap derül ki, mi lett belőle. Ez a legjobb visszahívó, és a „holnap kikel” horog büntetés nélkül működik. A kedvenc pillanatok: a kikelt fa közelről (13–14), a három csíra (23), az öntözés kedves szövege (44).
- **A leszállt fa nézete a legnagyobb felületi gond:** 5–7 sor vékony fehér szöveg a fán és a füvön (~1,3:1 kontraszt), ráadásul a gombokra csúszik. A teendő elvész, a gombok kicsik, és az „Elengedem…” középen ijesztő.
- **Az első kép nem mutatja a kertet:** a három fából egy látszik, a képet a homályos fű tölti ki.
- **A kert elvesztése mindennél rosszabb.** Ezt Tamás hozta fel, és a játékosok mind a listájuk elejére tették.
- **A napi megosztásban nincs semmi személyes.** Ennek ellenére Marikának a küldés maga a rituálé, ezért a rácsot nem kidobni kell, hanem gazdagítani.
- **Nyelv:** a „Mentés + vágólap”, a „Kód beírása”, a „bázispár” és a latin név az első helyen nehéz egy nem technikás játékosnak. A DNS-téma maradjon (ez a játék identitása), de a szavak legyenek hétköznapiak.

## Tényellenőrzés (moderátor)

- **Valódi hibák:**
  - A megosztott képen kék a fa törzse (34), a teljes 1080×1350-es képen is. Tamás gyanúja: a `share.gd` előnézeti jelenetében egy kékes kitöltő fény van, és a puha stílus árnyékszíne fényenként hozzáadódik, ezért kétszer kerül rá.
  - A batyu takarja a „Levágom” gombot (31–32).
  - Sérült mentésnél csendben új játék indul, és felülírja a régit (`state.gd load_or_new`).
  - Nincs tartós tárhely-kérés (`navigator.storage.persist()`).
  - A webes CI elnyeli az import hibáit (`|| true`), és nem futtat próbát.
- **Nem hibák:**
  - A „Teszt-csillag” felirat csak a tesztképeken van.
  - A „Mirra · 30 növény” helyes: az aktív, megtelt bolygó neve.
  - A sötét 45-ös kép egy reggeli átúszás 0,6. másodperce.
- **Tamás próbái (mind rendben):** `--playtest` (33 lépés), `--boardtest=60`, `--crosstest=100`, `--sharetest=500`, `--shapetest`, `--soundtest`.

## A közös prioritási lista

Mind az öten aláírták. A záró körben kért módosítások be vannak építve, az értékelő nevével jelölve. Tamás becslése szerint a 0–6. pont 2–3 hét, ha minden pont külön, kis lépésben megy ki, és mindegyik bővíti a `--playtest`-et.

**0. Azonnali hibák** (kicsi)
- A kék törzs a megosztott képen.
- A batyu a „Levágom” gombon.
- A fa szövege rácsúszik a gombokra.
- Szabály: nyitott lap alatt minden felületi tárgy (batyu, nap magja, csillagjel) rejtve.
- A panelek legyenek átlátszatlanok (~90%) vagy elmosott hátterűek, hogy ne üssön át a lap alatti szöveg (34, 35). *(Réka)*

**1. A kert ne vesszen el** (1–2 nap)
- Tartós böngésző-tárhely kérése (`persist()`).
- Sérült mentés ne íródjon felül, hanem kerüljön félre. A tartalék a tegnapi állapot legyen.
- „Kertem kódja” a „…” lapon. Az első hét végén a játék egyszer, szelíden ajánlja fel: „Küldd el magadnak, hogy meglegyen”. Egy koppintás, link, nem begépelendő kód. Ez a Safari ↔ főképernyő átvitelt is megoldja.
- A teszt-paraméterek (`?uj`, `?nap`, `?kereszt`) csak fejlesztői módban működjenek, a `?uj` megerősítéssel.
- Élesítés előtt fussanak a próbák (`--playtest`, `--boardtest`, `--sharetest`), és az import hibája állítsa meg a deployt.
- A 64 csillagos korlát: a 65. csillag ma nem látszik és nem hozható vissza, ez megszegi az „Elengedem – bármikor visszahozhatod” ígéretet. Megoldás: lapozás vagy összevont régi csillagok, kb. fél nap. *(Tamás)*

**2. A leszállt fa nézete és az olvashatóság** (2–3 nap)
- Kis, olvasható tábla a fa mellett. Az első sorban **magyar, leíró név a génekből** („Bíbor csipkés”), alatta kisebben a latin. *(Marika)* Ezután egy kiemelt sor az állapottal és a teendővel; a tulajdonságok koppintásra nyílnak.
- Nagy (44 pt) gombok, az „Elengedem…” a szélre.
- Legalább 13 pt-os betű, a magyarázó szövegnél 4,5:1 kontraszt.
- Szócserék: „Küldés…” / „Link másolása”, „Barátom kódja”, „bázispár” → egyszerűbb.
- Egykezes könnyítés: dupla koppintás a kicsinyítéshez, a csípés mellett. *(Dóra)*

**3. A gondozás ne nőjön a kerttel** (0,5–1 nap)
- Csak az aktív bolygó fái szomjaznak.
- A szomjas fa fölött kívülről is látszó, csepp alakú jel: rá koppintva öntözés leszállás nélkül, a cseppek animációja marad.
- A reggeli üzenet legfeljebb egy fát nevez meg.
- Nincs „eső” gomb: a rituálé megmarad, csak kevesebb lesz belőle.

**4. Kezdőkép** (kicsi)
- A kamera úgy induljon, hogy mindhárom fa látsszon, ne a fű uralja a képet.

**5. Fajtár a herbáriumban** (2–4 nap) – az első *új* funkció
- Génenként a felfedezett változatok, szép kártyán.
- Minden kikelt fából telik, a napi magból is, keresztezés nélkül is.
- Nincs százalék, nincs szürke rács, csak egy halk sor: „még 9 virágszín vár valahol”.
- A rejtett szín és a mutáció finom fénykeretet kap. Ritkasági rangsor nincs, mert minden fa egyedi.

**6. Személyesebb napi megosztás** (kicsi–közepes)
- A rácsban a választott színek látszanak.
- Másnap megosztható kártya „A tegnapi magomból ez kelt ki” felirattal, a fa képével.
- Súgás csak akkor kerül bele, ha nulla volt („súgás nélkül”), egyébként semmi.
- A rejtett szín és a mutáció fénykerete (és egy szó, pl. „rejtett szín”) a megosztott képen is látsszon. *(Bence)*

**7. Később**
- Becenév a fának.
- A tábla jelei szín *és* forma (2 vs. 3 vonalka), színtévesztőknek.
- Esetleg a dátumból számolt, magától eső eső (Dóra ötlete, a záró körben elengedte).

**Most NE:** új rendszer, szerver, vásárlás; az alakítás bővítése; látványcsiszolás (a panelek stílusa a „világ nyelvére”, a spirál puhítása, a fű, az egységes ikonstílus).

## Ahol nem értettek egyet, és mi lett belőle

- **A fajtár helye:** Bence szerint a 2. pont után jöjjön, mert ez az egyetlen ok, hogy két hét múlva is visszajöjjön. Dóra a 0–3. pont után tenné, Réka a 0–4. után, első új funkcióként, Tamás a 6. helyre. **A moderátor döntése: az 5. hely**, a hibák, a mentés, a fa nézete, a gondozás és a (kicsi) kezdőkép után, de a megosztás előtt, mert annak a ritka-jelzése a fajtárra épül.
- **Ritkaság:** Bence eleinte „a csoportból elsőként”-et kért, ezt visszavonta, mert szerver nélkül nem megy. Marikát a versengés elküldené, Tamás szerint a ritkasági szintek leértékelnék a fák 90%-át. **Eredmény:** nincs rangsor, csak a rejtett szín és a mutáció kap jelet.
- **Súgásszám a megosztásban:** Bence és Tamás mellette volt, Marika és Réka ellene (szégyenérzet). **Eredmény:** csak a „súgás nélkül” jelenik meg.
- **Öntözés:** Dóra egy koppintásos esőt akart, Marikának viszont az öntözés a kedvence. **Eredmény:** kívülről, fánként, a csepp-jelre koppintva, és csak az aktív bolygón.
- **Nyelv:** Marika két színt kért a betűk helyett. Réka szerint a csak színes jel kizárja a színtévesztőket, ezért szín és forma együtt kell. A latin név és az A=T megmarad, de a magyar név kerül előre.
- **Halasztás:** Tamás szerint a látványcsiszolás várjon. Réka szerint a kritikus pontjai nem csiszolások, hanem használhatósági hibák, és Tamás ebben egyetértett. Így a 0. és a 2. pontba kerültek.

## Tamás további megjegyzései (nem kerültek a listára)

- A `main.gd` 3525 sor; ~760 sor képernyőkép- és mérő-segédkód, és benne van a régi repülős kert is. Érdemes külön fájlba tenni, illetve törölni.
- A `DESIGN.md` már egyben sem fér az AI olvasási keretébe. A záró körben azt mondta, ez Péter munkamódszere, nem a játékosé, ezért nem kell a listára.
- Olcsó Androidon senki nem mért: vakfolt.
