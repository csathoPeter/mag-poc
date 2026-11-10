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
- **Szabad gének:** 1–2 sorban több jó megoldás van, ott a játékos dönt, így irányítja a tenyésztést.

## Keresztezés

- Két szülő génjeit a táblára tesszük; mivel ritkán férnek össze szabályosan, a játék a legközelebbi szabályos DNS-t keresi. **Az eltérés maga a mutáció** (a szabályokból következik, nem külön véletlen).
- A sorok mellett jelölés: 1 / 2 = melyik szülőtől jött, M = mutáció.
- Tervezett: 4–5 jól látható tulajdonság öröklése, rejtett gének (két kék szülőtől néha fehér utód), egy keresztezésből három csíra, ebből egyet nevel tovább a játékos (szelekció).

## A nagy pillanat

A kész tábla sorai kettős spirállá csavarodnak, maggá húzódnak, a földbe hullanak, és kinő a növény. (A Three.js-es prototípusban kész, Godotba még át kell vinni.)

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
4. **Ha van kedved: keresztezés** a gyűjtött magokkal. Ezek is másnap kelnek ki.
5. **Nézelődés:** repülés a kertben.

### A nap magja

- **Mindenkinek ugyanaz a tábla**, de 1–2 szabad génnél a játékos választ → rokon, mégis saját növény.
- A tábla a dátumból determinisztikusan generálható, **szerver nélkül, offline is** működik.
- Megosztás az első verzióban: kép + kód. „Mások mit választottak” statisztikához később szerver kell.
- **Kihagyás:** az elmúlt 7 nap magjai a magos táskában várnak, bármikor elvethetők. Régebbiek nem.

### Tempó

- A nap magja: naponta 1.
- Keresztezés: annyiszor, **ahány magot gyűjtöttél** a virágzó fákról (napi kb. 1–3). A virágzás napokig tart, a korlátot a természet adja, nem számláló vagy pénz.
- **Minden elvetett mag másnap kel ki.** Ez az egyetlen várakozás a játékban, és jutalom, nem büntetés.

### Gondozás

- **Öntözés:** ingyenes, korlátlan, nincs vízszámláló. Az elhanyagolt növény csak lekonyul (és nem fejlődik tovább), egy öntözéstől feléled. Nincs halál.
- **Maggyűjtés:** virágzáskor a fáról érintéssel. Ez köti össze a gondozást a keresztezéssel.
- **Metszés:** egy ág levágása egy érintéssel, azonnal.
- **Kötözés:** egy ágat irányba húzol, az napok alatt lassan arra hajlik (bonsai-érzés, újabb ok a visszatérésre).
- **Az alakítás nem öröklődik**, és a DNS-t sem változtatja. Az utód a nyers DNS-ből nő.
- **Technikai feltétel:** a növény = DNS + kód + *alakítási lista* (ág-index, művelet, kezdőnap). A generátor (`plant_gen.gd`) minden ágat ugyanúgy végigszámol (a véletlenszám-sorrend nem tolódhat el), és a listát csak a kirajzolásnál alkalmazza. Így determinisztikus marad, és minden részletességi szinten ugyanaz a váz.

### Visszahozó elemek

Kikelés másnap, a nap magja, múló virágzás (ilyenkor gyűjthető mag), lassan hajló kötözött ágak, valódi évszakok, barát magja kóddal. **Napi legfeljebb egy értesítés** (pl. „Kikelt a tegnapi magod”). Kihagyott nap után semmi nem vész el.

## Bolygók és csillagok (a kert)

Döntés: 2026. 11. 10. A „kert” kis bolygók sora. A játékos nemcsak fákat, hanem világokat is tenyészt: **a bolygó DNS-ét a rajta élő növények adják**.

### Bolygó

- **Kicsiben indul** 1–3 növénnyel, és minden új fával kicsit nő, kb. 30 fáig (teljesítménykeret).
- **Ha megtelt, mellette új kis bolygó születik.** Ez természetes mérföldkő, kb. 2–3 hetente. A régi bolygó megmarad, a bolygók között lehet váltani.
- **Kamera:** húzással forgatod a bolygót, csípéssel közelítesz. Egy fára koppintva a kamera lerepül hozzá a felszínre: ott van tiltshift, gondozás, metszés.
- **Teljesítmény:** a túloldali fák nem látszanak, kívülről minden fa apró (egyszerűsített szint), a felszín közelében csak a közeli 3–4 fa részletes.

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
- **Átlagolás:** a folytonos értékeket (színárnyalatok, domborzat magassága, holdak mérete) minden további növény finoman elhúzza. Az alapító súlya nagyobb (pl. 1/3), a többin a többiek osztoznak. Az árnyalatok átlaga körkörös (szín-kerék).
- **Saját mag:** minden bolygónak van kódja (pl. a játékos kódja + a bolygó sorszáma). Ebből jön a domborzat zaja, a kráterek és a holdak helye, így **két bolygó sosem egyforma**, még azonos növényekkel sem.
- Determinisztikus: a bolygó kinézete = f(bolygókód, a rajta élő növények DNS-e). Ültetéskor és elengedéskor lassan, látványosan változik.

### Csillagok

- **Elengedett fából csillag lesz.** Ha egy fát elengedsz (pl. helyet csinálsz neki, vagy nem kell), felszáll az égre. Nincs selejtezés és nincs halál.
- A bolygó elengedett fái a bolygó egén **csillagképet** rajzolnak. Ez a bolygó emléke és egyben a herbárium: koppintásra látod a fát, és **bármikor visszahozhatod**, újra elvetheted.
- A keresztezés nem választott csírái ugyanígy csillaggá válnak (nincs külön magtár).
- **Mások bolygói:** a távoli csillagok más játékosok vagy barátok bolygói. Ráközelítve megnézheted őket és aznapi magjukat. Ehhez szerver kell, így ez később jön; az első verzióban barát bolygója kóddal is megnyitható.

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
- [ ] Bolygó-generátor (gömb, domborzat, légkör, holdak) és kamera (forgatás, ráközelítés)
- [ ] Csillagképek, visszahozás az égről
- [ ] A nap magja: dátumból generált tábla, magos táska (7 nap)
- [ ] Alakítási lista a generátorban (metszés, kötözés)
- [ ] DNS-tábla és spirál átvitele Godotba
- [ ] Mentés (helyi), több saját növény a kertben, másnapi kikelés
- [ ] Öntözés, herbárium, keresztezés UI
- [ ] Mérés olcsó Androidon
- [ ] iOS-build Mac nélkül (GitHub Actions macOS + TestFlight, Apple Developer-tagság kell)
- [ ] IAP próba (borravaló)
