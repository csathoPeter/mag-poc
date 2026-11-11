# Réka (UX/vizuális designer)

## Első vélemény

### 1. Összkép
A világ hangulata megvan: a pasztell ég, a közeli őszi lomb és az éjszaka (13, 39, 41) olyan nyugalmat ad, amilyet a cozy játékoktól várok. A felület azonban két külön nyelvet beszél. A diegetikus tárgyak (a mag és a batyu) jók. A szövegek és a panelek viszont generikus, sötétlila mobilkártyák, vagy a 3D-képre írt vékony betűk, és ott az olvashatóság meg a rétegezés több helyen elcsúszik.

### 2. Erősségek
1. **A nap magja mint tárgy** (01–04): a halós, aranyló mag egyértelmű fókuszpont, a helyben megjelenő tippek (pontvonal, gyűrű a fa körül – 15) példaszerűen csendesek. Nincs tutorial-ablak, mégis kiderül, mit kell csinálni.
2. **A választás láthatóvá tétele** (05, 22, 23): az arany sorok („te döntesz”), az 1/2/M jelvények (szín és betű együtt, ami színtévesztőknek is jó) és a három csíra 3D-előnézettel jól mutatják, mi lesz a növényből.
3. **Jutalompillanatok** (07, 13–14, 28): a kettős spirál, a kikelő fa hulló levelekkel és az elengedés fénye érzelmileg működik, és nem harsány.

### 3. Problémák, súlyosság szerint

**[kritikus] A leszállt fa szövegtömbje (16–20, 33).** Öt–hét sor vékony fehér szöveg ül közvetlenül a törzsön, a lombon és a füvön. Mértem: a háttérhez képest ~1,3:1, csak a sötét szegély menti. A 20-on már rácsúszik a gombsorra. A lényeg („szomjas – koppints rá”) elvész a fajnév és a tulajdonságok között. Ez a napi gondozás központi képernyője. **Javaslat:** valódi kis tábla a fa *mellett*, puha, ~85%-ban átlátszatlan háttérrel. Egy sor a név, egy kiemelt sor az állapot ikonnal és teendővel, a tulajdonságok koppintásra nyíljanak ki.

**[kritikus] Rétegütközések.** A batyu rárajzolódik az alakító lap „Levágom” gombjára (31, 32), vagyis a fő akciót takarja, és tévkoppintást okoz. A csillagkép a „…” gomb és a cím mögé fut (25). A megosztó lapon átüt a fa szövege (34), a 35-ön lap ül egy másik lapon, a háttérben a táska tartalma. **Javaslat:** legyen egy egyszerű z-rend szabály: nyitott lap alatt minden HUD-tárgy rejtve van, a panelek átlátszatlanok vagy elmosott hátterűek, és a csillagkép kerülje a felső biztonsági sávot.

**[fontos] A fa akciógombjai (16).** Kb. 30 pt magasak, áttetsző pirulák a fű előtt (~2:1), 11 pt körüli betűvel. Az „Elengedem…” középen van, a legkönnyebben elért helyen. **Javaslat:** legalább 44 pt-os gombok; az Alakítás és a Megosztom legyen hangsúlyos, az Elengedem kerüljön szélre vagy a „…” mögé.

**[fontos] Kicsi és kis kontrasztú szövegek.** Az „a nap magja” és a „táska” felirat 9–10 pt-os, és ~1,2:1 a világos égen (01). Az alcím 7 adatot zsúfol egy sorba, a képernyő széléig. A szabályleírás lila a lilán (~3,5:1, 05), a táska kártyáján lila a türkizen (~1,7:1, 08). A „Vissza a kertembe” ~1,5:1 (37). A csírakártyákon csonkolt szöveg áll („kékeszöld lo…”, 23). **Javaslat:** 13 pt alsó határ, a magyarázó szövegnél 4,5:1. A vékony „suttogás” csak nagy címre (20 pt fölött) jó.

**[fontos] Gyenge állapotjelek (17, 19, 44).** A szomjas fa csak fakóbb. A „kék vízcsepp-fény” egy fehér pötty, nem kék, és nem is csepp alakú. A virágzó fán sem a virág, sem az arany csillanás nem látszik. A batyu fénypöttyei pár képpontosak. A 44-en a szöveg mondja, hogy „lekonyult”, a kép nem mutatja. **Javaslat:** forma alapú jelek kellenek (csepp-sziluett, látható hajlás, nagyobb csillanás), a batyun pedig jól olvasható jelvény.

**[fontos] Keretezés (01, 42).** A kezdőképen a 3 fából egy látszik. A képernyő ~70%-át a homályos, „szőrös” fűgolyó tölti ki, holott a fák lennének a főszereplők. A 42-n a fák a peremen félig kilógnak, a talaj pedig barna szőrmének hat. **Javaslat:** távolabbi alapnézet, és a fák a látható félgömbre kerüljenek.

**[apró] Konzisztencia.** Háromféle gombkeret van (arany, szürke, rózsaszín „Kód beírása”). A táskában kétszer szerepel a „Megosztom” (08). Technikai címkék is maradtak: „Mentés + vágólap”, és az elengedésnél „formája, talaja és holdjai” (27). A megosztott képen **kék a fa törzse** (34), ami vagy hiba, vagy stílustörés. Vendégként is látszik a nap magja és a táska (37).

**[apró] Hibajelzés.** A korall hibakeret a korall G≡C mezőn összemosódik (06), színtévesztővel ez rosszabb. Jobb lenne alakkal jelezni (szaggatott keret vagy rezdülés). A Wordle-rács színeinek (35) nincs magyarázata.

### 4. Felfedezhetőség
- **A nap magja:** kiváló.
- **Fa:** jó (a tipp gyűrűvel jelöli).
- **Táska:** a batyu felismerhető, de az arany kötője szemüvegnek vagy arcnak hat, a felirata apró.
- **Alakítás:** a gomb megvan, de a „húzással kötözés” csak szövegből derül ki, kellene egy pillanatnyi szellemkéz-animáció.
- **Csillagok:** csak elengedés után léteznek; a jobb alsó csillagjel addig nincs ott, nappal halvány.
- **Bolygók:** egyetlen tipp mutatja („Csípd kifelé”). A kis bolygóknak nincs nevük, nem tudni, melyik melyik (30).
- **Rejtett gesztusok:** a hosszú nyomás (elengedés) és a koppintás a gyorsításhoz rejtett.
- **Keresztezés:** csak a táskában, gyűjtött magon érhető el. Elfogadható, de egyszer meg kellene mutatni.

### 5. Vizuális stílus
Az ég, a közeli lomb (41), az alkony és az éjszaka átadja a puha, stilizált, Sky-szerű pasztell célt. Ami kilóg:
- **A fű:** távolról zajos, szőrös felület (01, 42), éppen az, amit el akartak kerülni.
- **A panelek:** sötét, lila „glassmorphism” kártyák, egy produktivitási app nyelvén, nem a világén.
- **A spirál (07):** neon vonalrajz elsötétített képen, keményebb, mint minden más.
- **A batyu:** lapos 2D-rajz a 3D-világ előtt. Elmegy, de a csillagjellel együtt egységes ikonstílus kellene.

### 6. Szándék vs. eredmény (DESIGN.md után)
- **„Vékony, kerek, jól olvasható” betű:** a vékony és a jól olvasható a világos pasztell égen ütközik; a sötét szegély csak félmegoldás.
- **„A fa neve egy kis táblán áll, csak közelről látszik, aztán elhalványul”:** nincs tábla, a szöveg nem halványul el, és a törzsre kerül.
- **„A DNS-tábla a mag fölött lebegő, fénylő rács” és „a táska tárgyként, nem menüként”:** mindkettő teljes képernyős modális kártya, elmosott világgal. A belépés diegetikus, a belső tér nem.
- **„A fűmező szőnyeg”:** közelről igen (14), kívülről nem.
- **„Semmi nem villog vagy ugrik”:** a képek alapján rendben.

### 7. Ha egy dolgot változtathatnék
A leszállt fa nézetet (16–20) terveztetném újra egységként. A fa mellé egy puha, olvasható táblát tennék, rajta egy kiemelt állapot- és teendősorral, alatta 44 pt-os, rangsorolt gombokkal, és minden más HUD-elem tisztelné ezt a réteget. Itt dől el naponta, érti-e a játékos, mit kér tőle a kert.

### 8. Amit képekből nem lehet megítélni
- A mozgás és az átmenetek időzítése, rugalmassága; a hang és a haptika.
- A valódi érintési pontosság (38 pt-os táblamezők 4 pt-os réssel, ág-találat sűrű lombban).
- A safe area: a „táska” felirat ~20 pt-ra van az aljától (home indicator), a „…” a Dynamic Island közelében.
- A tippek időzítése és sorrendje élesben.
- A valódi kijelző élessége (a fű zajossága részben a szoftveres renderelő miatt lehet).
- A képernyőolvasó és a nagyobb rendszerbetűméret támogatása. Canvasban ez valószínűleg nincs, ezt érdemes nyíltan vállalni.

## Kerekasztal, 1. kör

### 1. Miben értek egyet
- **Mindenki egyetért a leszállt fa nézetről.** Bence, Dóra és Marika tőlem függetlenül ugyanazt a falat látta (16–20). Ez a probléma így már nem ízlés kérdése.
- **Marikával a nyelvben és a betűméretben.** Ő a tesztem: ha neki nem olvasható, akkor senkinek sem a villamoson, napfényben (ezt Dóra is mondja).
- **Dórával az egykezes használatban.** Ezt én kihagytam. A „…” jobb fent van, a csípés két ujjat kér, pedig a fő mozdulatoknak a hüvelykujj-zónában a helyük.
- **Tamással a mentésben.** Ez nekem is UX-kérdés: a bizalom a cozy játék alapja. Az összesített listán az ő 1. pontja előzze meg az enyéimet.

### 2. Miben vitatkozom
- **Tamás (H): „a látványcsiszolás várjon”.** A fű és a stílus finomítása várhat, ebben igaza van. A kritikus pontjaim viszont nem csiszolások, hanem használhatósági hibák: a batyu rajta van a „Levágom” gombon, a fa állapota ~1,3:1-es kontraszttal olvashatatlan, a gombsor csak ~30 pt magas. Ezek kicsi munkák, és a hibajavítások közé tartoznak, nem a „szépítés” közé.
- **Bence: „a csoportból elsőként”.** Szerver nélkül ez nem megy, és a versengő hang ütközik Péter alapelveivel. A villogni való legyen *ritka és szép*, ne *gyorsabb*.
- **Marika: betűk helyett két szín.** Pusztán szín alapján nem jelezhetünk, mert a színtévesztők kiesnek. Megoldás: szín *és* forma együtt (2 vs. 3 vonalka a mezőben), és a betűk eltűnhetnek.

### 3. Válasz a vitás kérdésekre
- **A (gyűjtemény):** a herbárium kapjon „Fajtár” lapokat génenként (virágszín, levélforma…), és csak a felfedezett változatok látszanak, szép kártyán. Szürke „?”-rács és százalék ne legyen, csak egy halk sor: „még 9 virágszín vár valahol”. A lapok a napi magokból is telnek, így a keresztezés nélkül játszók (Marika) sem esnek ki. A ritka (rejtett szín, mutáció) kapjon finom fénykeretet.
- **B (öntözés):** a mozdulat maradjon, ez a rituálé. A *leszállás* legyen elhagyható: kívülről is látsszon egy valódi, kék csepp-sziluett a szomjas fa fölött, és arra koppintva öntözzön, a cseppek innen is hulljanak. Szomjazni csak az aktív bolygó szomjazzon. „Eső” gomb ne legyen, az kipipálja a rituálét.
- **C (napi megosztás):** legyen személyes és vizuális. A rács az arany sorokban a *valódi* választott színt mutassa (magenta, éjkék), másnap pedig legyen megosztható kártya a kikelt fáról: „A tegnapi magomból ez kelt ki”. A súgásszám ne kerüljön bele, mert szégyenérzetet kelt.
- **D (nyelv):** a DNS-motívum vizuálisan maradjon (spirál, rács). A szavak legyenek hétköznapiak:
  - „bázispár” helyett „pár”;
  - „Mentés + vágólap” helyett „Küldés…” / „Link másolása”;
  - a „Kód beírása” helyett „Barát magjának kódja”;
  - a fő név legyen magyar, leíró („Bíbor csipkés”), a latin név kisebben alatta, és legyen becenév-lehetőség.
- **E:** igen, ez az első számú felületi munka.
- **G:** igen, az első 10 másodperc a legfontosabb. A kamera legyen távolabb, és a bolygó forduljon úgy, hogy mind a 3 fa a látható oldalra essen. Az első indításkor a kép egy fáról is indulhatna, és onnan húzódhatna ki. A kikelt fa közelről (14) a legjobb kép, ezt mutassuk meg először.

### 4. Végső top 3 prioritásom (Tamás mentés-pontja után)
1. **A leszállt fa nézet és a rétegrend:** puha, olvasható tábla a fa mellett, kiemelt állapot- és teendősorral, 44 pt-os gombokkal; nyitott lapnál minden HUD-elem rejtve. – *közepes*
2. **Olvashatósági és nyelvi kör:** legalább 13 pt-os betű, 4,5:1 a magyarázó szövegeknél, átlátszatlan panelek, egyszerű szavak, a kék törzs javítása. – *kicsi–közepes*
3. **Kezdőkép és látható állapotjelek:** a fák a látható oldalon, és kívülről koppintható, csepp alakú szomjas-jel (ez egyben a B kérdés válasza). – *közepes*

## Záró kör

**(1) Aláírom.** A 0. és a 2. pont pontosan azt fedi le, amit kritikusnak tartottam.

**(2) Egy módosítás:** a panelek átlátszatlansága kerüljön ki a „Most NE: panelek stílusa” alól, és menjen a 0. pontba. Ez nem stílus, hanem olvashatóság. A 34-en a megosztó lapon átüt a fa szövege, a 35-ön lap ül a lapon, és a háttérben a táska szövege kavarog. Kicsi munka: a panel ~90%-os fedése vagy elmosott háttér. A szín és forma együtt a táblán maradhat a „Később” alatt, mert ott a betű már ad második jelet.

**(3) A fajtár helye:** a 0–4. pont után jöjjön, vagyis maradjon a 6. A 0., 3. és 4. pont kicsi, így ez néhány napnyi csúszás. A fajtár pedig az olvasható, rendbe tett felületre épüljön, mert egy szép gyűjtemény olvashatatlan táblákon nem tart meg senkit. Bence aggodalma jogos: a fajtár legyen az első *új* dolog, ne kerüljön a „Később” közé.
