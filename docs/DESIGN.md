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

A kész tábla sorai kettős spirállá csavarodnak, maggá húzódnak, a földbe hullanak, és kinő a növény. (Godotban kész: `godot/helix.gd`.)

## A kert

- Szembőli nézet, **tiltshift** (mélységalapú háttérblur + a kép teteje/alja enyhén elmosva), makettszerű hatás.
- **Analóg karral repülsz** a kertben, máshol húzva körülnézel.
- A közeli 4 fa teljes részletes, a többi egyszerűsített, azonos vázzal (a váltás ne látsszon).

## Napi kör és visszatérés (terv)

1. Megnézed a kertet: kihajtott egy mag, kinyílt egy bimbó.
2. Keresztezel egy céllal (pl. kék virág szomorú termeten).
3. Kirakod a DNS-t (1–2 perc), elülteted.
4. Öntözöl a pályákért kapott vízzel; a növény napok alatt fejlődik.
5. Selejtezel: három csírából egyet nevelsz.

Visszahozó elemek: kíváncsiság (a mag csak másnap kel ki), múló virágzás (ilyenkor gyűjthető mag), herbárium üres lapokkal célként, valódi évszakok, a nap közös magja, barát magja kóddal. Napi legfeljebb egy értesítés.

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
- [x] DNS-tábla, keresztezés és spirál átvitele Godotba
- [ ] Mentés (helyi), több saját növény a kertben, másnapi kikelés
- [ ] Öntözés, herbárium, keresztezés UI
- [ ] Mérés olcsó Androidon
- [ ] iOS-build Mac nélkül (GitHub Actions macOS + TestFlight, Apple Developer-tagság kell)
- [ ] IAP próba (borravaló)
