# Tamás (játékfejlesztő)

## Első vélemény

### 1. Összkép
Technikailag jóval érettebb, mint amit egy egyszemélyes, telefonról irányított projekttől várnék: a rendszerek determinisztikusak, a tiszta függvényeknek van önellenőrzésük, és van egy végigjátszó integrációs teszt, ami minden zöld. A mag (holnap kikel, amit ma elvetsz) jó, és az első hét tempója rendben van. A gond a 30. nap utáni ív: a gondozás nem skálázódik, nincs középtávú cél, a napi tábla nem fejlődik. Ennél is sürgősebb, hogy a kert egyetlen böngésző-tárhelyen él mentés-export nélkül. Hamarabb vesztik el a játékosok a kertjüket, mint ahogy megunják.

### 2. A mag (core loop)
A lényeg: egy napi logikai feladvány gyárt egy magot, a mag holnap kikel, és egyedi fa lesz belőle. A kíváncsiság („milyen lett?”) a legerősebb horog, és a reggeli pillanat (fátyol, kikelés, a kamera a szomjas fa felé fordul) jól csomagolja. A táblán a két arany sor teszi a magot a játékossá, ez okos döntés. Gyengeség: a 6×6-os Takuzu ~19 üres mezővel egy rutinos rejtvényfejtőnek 1 perc, és a nehézség a 100. napon is ugyanannyi. A megoldás nagy része nem hat a növényre, a tábla inkább kapu.

**Az ív:**
- **1. nap:** 3 fa, tábla, spirál, elvetés, talán egy gyűjtött mag. Rövid, de a „holnap kikel” jó záróhorog.
- **7. nap:** 8–10 fa, a 3. naptól jön a szomjazás, és elérhető a keresztezés. Ez a legjobb szakasz. A keresztezés felülete (1/2/M, arany sorok, rejtett szín, három csíra) viszont egyszerre zúdul a játékosra, és nincs hozzá tipp.
- **30. nap:** megtelik az első bolygó, születik az új. Szép mérföldkő. Itt kezd fájni, hogy a 30 fát egyenként kell öntözni (leszállás + koppintás).
- **100. nap:** napi ~3–4 elvethető maggal becslésem szerint 4–9 bolygó és 100+ fa. A szomjazás minden bolygón számít, így 3 nap kihagyás után mindenhol lekonyult fák, a reggeli üzenet pedig erre figyelmeztet. Tartalomban üres (nincs új cél, ugyanaz a tábla), kezelésben túlzsúfolt (öntözés, egyre hosszabb táska görgetés nélkül).

### 3. Rendszerek
- **Erős:** a nap magja és a kikelés, a gondozás *kis* kertben, az évszakok (olcsók, valódi dátum, ingyen hoznak változatosságot a 100 napra), a hang a DNS-ből (identitást ad a fáknak), a barát magja kóddal (az egyetlen, szerver nélkül működő közösségi hurok).
- **Jó, de cél nélkül lóg:** a keresztezés. Ez lenne a mélység motorja, de nincs mit elérni vele: nincs gyűjtemény, nincs „felfedezted” jelölés. A rejtett hófehér szín a legjobb pillanata, ebből kellene rendszer.
- **Rendben:** csillagok, herbárium (az elengedés büntetés nélkül teremt helyet), bolygók (mérföldkő).
- **Túl korai:** az alakítás (862 sor + generátor-módosítás). Szép bonsai-ötlet, de nem öröklődik, és semmi nem épül rá. A napi Wordle-megosztás pedig üres: a rács mindenkinél ugyanaz (a feladvány adta vagy kikövetkeztetett mező), csak a két arany sor tér el. Hiányzik a személyes eredmény, ami a Wordle-t működteti.

### 4. Működőképesség
**Futtatott önellenőrzések (mind 0-s kilépési kóddal):**
- `--playtest`: `EREDMÉNY: rendben (33 lépés)`, 14 mp, ~10 játéknap, v1/v3 mentés felhozása is.
- `--boardtest=60`: 0 nem egyértelmű, 0 logikával nem megoldható tábla, `rendben`.
- `--crosstest=100`: 0 szabálytalan csíra, átlag 4,24 mutált mező, a rejtett szín 16%-ban bújik elő, maghozás 3 fánál 1,1, 20 fától 3,0 naponta.
- `--sharetest=500`: 0 hibás, 0 ütköző kód; a bolygó-link 30 fával szokásosan 390 jel, alakított fákkal ~830.
- `--shapetest`: `minden rendben`.
- `--soundtest`: 32 minta, `hibás: 0`, natívan 1,85 mp számolás.

A kilépéskori „RID leaked / resources still in use” üzenetek ártalmatlanok. Ilyen tesztfegyelmet ritkán látok indie projektben.

**Hibák és kockázatok, kódban látva:**
1. **Sérült mentés felülíródik.** `state.gd load_or_new()`: ha a fő fájl és a `.bak` sem olvasható, `new_game()` + `save()` jön, vagyis csendben új játék indul, és mindkét fájl felülíródik. Helyreállításra nincs esély. A `.bak` ráadásul ugyanabban a hívásban, ugyanazzal a tartalommal íródik, így csak félbeszakadt írás ellen véd, logikai hiba ellen nem.
2. **Nincs export és nincs tartós tárhely.** A kódban nincs `navigator.storage.persist()` és nincs mentés-export. *Platformismeret, nem futásban láttam:* a Safari a 7 napig nem látogatott oldal szkriptből írt tárhelyét (az IndexedDB-t is) törölheti. Ez pont a „kihagyott nap után semmi nem vész el” ígéretet töri meg. A főképernyős webapp külön tárhelye (ez dokumentált) miatt a Safariban kezdett kert nem vihető át.
3. **A tesztparaméterek élesben is működnek.** A `?uj` megerősítés nélkül töröl, és mivel bent marad az URL-ben, minden újratöltéskor újra. A `?nap=+N` tartósan eltolja a mentés napját, a `?kereszt` teszt-magokat ír a mentésbe. Elég egy továbbküldött tesztlink. A hármas koppintás bal fent fejlesztői módot nyit, ott van a „törlés” (két koppintás). Valószínűsége kicsi, a kára teljes.
4. **64 csillag bolygónként.** Minden keresztezés 2 csillagot ad, így egy rendszeresen keresztező játékosnál ez az ismert korlát a 30–40. nap körül eléri az aktív bolygót. A 65. csillagtól a csillag nem látszik és nem hozható vissza.
5. **A CI nem futtat tesztet:** a `deploy-web.yml` közvetlenül exportál, és az import hibáit `|| true` nyeli el. Péter telefonról nem lát hibát, mielőtt élesbe megy.

**Teljesítmény:** az iPhone 15 melegedését az önálló felbontás és a fűsűrűség-visszavétel kezeli (mérve 56–60 fps). Egy részletes fa ~220k háromszög, ez mobilon nagyon drága. Olcsó Androidon senki nem mért, ez szerintem vakfolt.

**Kód:** a modulokra bontás jó (care, breeding, share_code, dna_board tiszta függvények). A `main.gd` viszont 3525 sor, 124 függvény, ebből ~760 sor képernyőkép- és mérő-segédkód, és benne maradt a régi „repülős kert” is, amit csak a `--shot` ér el. Furcsa, de mérhető kockázat: a `DESIGN.md` ~34k token, egyben nem is fér be az AI olvasási keretébe (nekem két részben kellett olvasnom). A dokumentáció, amire az AI-fejlesztés épül, kezd túlnőni az eszközön.

### 5. Top 5 javaslat (prioritás szerint)
1. **A mentés biztonsága (1–3 nap):** `navigator.storage.persist()`; „Kertem kódja” export/import (a bolygó-link kódolójára építve, tömörített JSON a teljes mentésből, vágólapra vagy fájlba). Sérült mentésnél nevezzék át a fájlt (`.serult`), ne írják felül. A `.bak` legyen a *tegnapi* állapot. A `?uj`, `?nap`, `?kereszt` csak fejlesztői módban működjön, a `?uj` kérjen megerősítést, és kerüljön le az URL-ről.
2. **A gondozás skálázása (0,5–1 nap):** csak az aktív, vagy a legutóbb látogatott bolygó szomjazzon, és legyen egy mozdulatos „eső” az egész bolygóra. A cél: a nagy kert ne legyen nyomasztó.
3. **Halk középtávú cél (2–4 nap):** gén-atlasz (6×14 változat + rejtett színek + éjszakai fények), „felfedezve” jelöléssel, jutalom és kényszer nélkül. Ettől kap értelmet a keresztezés.
4. **A napi tábla ritmusa és a megosztás (1–2 nap):** heti változatosság (pl. vasárnap kevesebb megadott mező, időzítő nélkül), a megosztásban legyen személyes adat (súgások száma, a választás).
5. **CI-kapu és rendrakás (1 nap):** deploy előtt `--playtest`, `--boardtest`, `--sharetest` és import-hiba ellenőrzés. A `_shot_*` és a mérő kód menjen külön fájlba, a régi kert törlődjön. A 64 csillagos korlát legyen kezelve (lapozás vagy halványuló régi csillagok).

### 6. Amit NE csináljanak most
Új rendszert ne: se szervert, se natív iOS-t, se IAP-ot, se további megosztási formát. Az alakítás és a látvány (fű, puha stílus) további csiszolása várjon, amíg a mentés nem biztonságos és a 30+ napos ív nincs kijavítva. A `CLAUDE.md`-be és a `DESIGN.md`-be ne kerüljön több mérési napló. Inkább rövidítsék: a döntések maradjanak, a történet menjen ki.

### 7. Ha egy dolgot változtathatnék
A mentés hordozható és tartós legyen: egy „Kertem kódja” gomb és a `persist()`. Egy cozy játék a játékos bizalmából él. Egy 60 napos kert egyetlen elvesztése rosszabb, mint bármelyik hiányzó funkció, és ezt a játékos nem bocsátja meg.

## Kerekasztal, 1. kör

### 1. Miben értek egyet
- **Dórával:** a gondozás nem skálázódhat a fák számával. Az ő változata (reggeli összefoglaló, öntözés leszállás nélkül) jobb, mint az enyém.
- **Bencével és Dórával:** a napi rács üres, mert mindenkinek ugyanaz.
- **Rékával:** a leszállt fa nézete a nap legtöbbet használt képernyője, és most nem olvasható.
- **Mindenkivel:** a kék törzs (34) és a batyu a „Levágom” gombon hiba, nem ízlés kérdése.

### 2. Miben vitatkozom
- **Réka kritikus pontjai nem látványcsiszolás.** Ha a batyu eltakarja a fő gombot, az tévkoppintást okoz. Ha a teendő („szomjas, koppints”) nem olvasható, a gondozás nem működik. Ezeket a hibák közé sorolom. A paneleket „a világ nyelvére” hangolni, a spirált puhítani, egységes ikonstílust csinálni viszont tényleg csiszolás, az várjon.
- **Bence ritkaságigénye csak félig jogos.** A „csoportból elsőként” szerver nélkül nem megy. A ritkasági szintek („közönséges”) ráadásul leértékelnék a fák 90%-át, pedig a játék ígérete, hogy minden fa egyedi. A rejtett szín és a mutáció kapjon jelet, de ne legyen belőle ritkasági rangsor.
- **Marikával csak félig.** Az olcsó nyelvi cseréket csinálják meg: „Mentés + vágólap” helyett „Küldés”, „Kód beírása” helyett „Barátom kódja”. A becenév is jó ötlet, de mentésbe és megosztásba kell, ez kb. fél nap. A latin név és az A=T maradjon, mert ez a játék identitása. Elé kerüljön egy magyar, génnevekből képzett név („Bíbor csipkés”), ehhez a `Genes` változatnevei már megvannak. A táblán a szín legyen az elsődleges jel, a betű csak másodlagos.

### 3. A vitás kérdések
- **A (gyűjtési cél):** az atlasz *minden* kikelt fából töltődjön, a nap magjából is. Marika így keresztezés nélkül is gyűjt, a keresztezés csak gyorsabb út, nem feltétel. Az atlasz a herbáriumban éljen, és ne legyen százalék a főképernyőn. A hiányzó változat halvány sziluettként látszódjon, ne üres pipaként. FOMO nincs benne, mert nem fogy el semmi.
- **B (öntözés):** a rituálé maradjon, csak legyen kevesebb belőle. Csak az aktív, vagy a legutóbb látogatott bolygó szomjazzon. Kívülről a vízcsepp-jelre koppintva le lehessen locsolni a fát leszállás nélkül, az animáció maradjon. A reggeli üzenet legfeljebb egy fát nevezzen meg. Marika így ugyanúgy öntöz, Dóra pedig nem kap teendőlistát.
- **C (napi megosztás):** a legszemélyesebb a *saját fa képe*. Javaslatom: „Tegnapi magom kikelt: Bíbor csipkés” + a kép + „súgás nélkül” vagy „2 súgással” + a választás. Ez nem verseny, Marikának mégis van mit küldenie, Bencének pedig van mit mutatnia.
- **F (mentés):** a játékosok addig nem törődnek vele, amíg el nem veszítik a kertet. Utána viszont nem jönnek vissza. A `persist()` egy sor kód. A „Kertem kódja” mehet a „…” lapra, ott senkit nem zavar.
- **H:** fenntartom, de a fentiek szerint: a hibajavítás és az olvashatóság nem számít új rendszernek.

**Kék törzs, gyanú (nem futtattam):** a `share.gd` előnézeti világában két irányfény van, köztük egy kékes kitöltő fény (`.62,.7,1`), és lilás a környezeti fény. A puha stílus `soft_light()` függvénye fényenként hozzáadja a globális `shade_tint` légkörszínt, így az árnyékos törzsre ez kétszer kerül rá. Ezt a beállítást a bolygóra hangolták, nem erre a jelenetre.

### 4. Végső top 3 Péternek
1. **Mentésbiztonság (1–2 nap):** `persist()`, a sérült mentés ne íródjon felül, „Kertem kódja”, `?uj`/`?nap` csak fejlesztői módban, és deploy előtt fusson a `--playtest`.
2. **A leszállt fa nézete és a rétegütközések (2–3 nap):** olvasható tábla kiemelt teendősorral, 44 pt-os gombok, z-rend szabály, Marika olcsó szócseréi és a kék törzs javítása.
3. **A gondozás skálázása (0,5–1 nap):** csak az aktív bolygó szomjazzon, öntözés kívülről a csepp-jelre koppintva. Ezután, negyedikként jöhet az atlasz.

## Záró kör

**(1) Aláírom.** A mentés az 1. helyen van, a próbák pedig élesítés előtt lefutnak. Ennél többet nem kérhettem volna.

**(2) Egy módosítás:** a 64 csillagos korlát kerüljön be a 3. pontba. A 65. csillag nem látszik és nem hozható vissza. Ez csendes veszteség, ami megszegi az „Elengedem – bármikor visszahozhatod” ígéretet. Rendszeres keresztezésnél a 30–40. nap körül el is jön, így ugyanoda tartozik, ahová a mentés. Ennek a megoldása fél nap: lapozás vagy összevont régi csillagok. A dokumentáció rövidítése nem kell a listára. Az Péter munkamódszere, nem a játékosé.

**(3) A fajtár maradjon a 6. helyen.** Nem ér semmit, ha közben elveszik a kert, vagy a 30. napon nyomasztó lesz a gondozás. A 4. és az 5. pont kicsi, mehet vele párhuzamosan. A 0→6 sorrend reális: nagyjából 2–3 hét. Ehhez az kell, hogy minden pont külön, kis lépésben menjen ki, és mindegyik bővítse a `--playtest`-et, mert Péter telefonról csak így látja, hogy nem tört el semmi.
