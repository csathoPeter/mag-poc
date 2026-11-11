# Kerekasztal – a moderátor (Péter képviselője) bevezetője

Köszönöm mind az öt véleményt. A pontszámok: Bence 5/10, Marika 6/10, Dóra 7/10; Réka és Tamás szakmai értékelést adott pontszám nélkül.

## Tényellenőrzés (a kódban / a képek forrásában megnéztem)
- **Kék törzs a megosztott képen (34): valódi hiba.** A teljes 1080×1350-es kép is kék törzset mutat, a játékban barna. Javítani fogjuk.
- **„Teszt-csillag (a „+csillag” gombtól)” (26): nem játékos-hiba.** A képsorozathoz teszt-csillagokat adtam; valódi játékos ezt a feliratot nem látja.
- **„Mirra · 30 növény” (30): helyes.** A rendszer-képen a középső, megtelt bolygó (Mirra) az aktív; a csupasz az újabb.
- **45-ös kép (sötét fátyol):** egy reggeli átúszás 0,6. másodperce, nem fagyás – de a megjegyzés jogos, ha egy pillanatig is lefagyottnak tűnik.
- **35 (lap a lapon):** valódi folyamat – a napi megosztás a táskából nyílik, a táska alatta marad.
- **Tamás mentési állításai igazak:** sérült mentésnél csendben új játék indul és felülírja a régit (state.gd), nincs `navigator.storage.persist()`, a CI elnyeli az import hibáit (`|| true`), és nem futtat tesztet.
- **A batyu a „Levágom” gombon (31–32):** a képen valóban takarja – hibának tekintjük.

## Péter alapelvei (ezeket képviselem; javaslat ezekkel ütközve nem kerül a listára)
- Nincs halál, bukás, **időzítő**, streak-büntetés, bűntudat; az idő nem eladó (nincs fizetős gyorsítás, energia, reklám).
- Napi 3–5 perc teljes élmény, de bármennyit lehet maradni.
- Minden növény egyedi, kódból generált, determinisztikus.
- **Nincs szerver** (statikus webes build, GitHub Pages): ranglista, „a csoportból elsőként”, push-értesítés most nem megoldható.
- Péter egyedül fejleszt, telefonról, AI-val: a javaslatok mérete számít.

## Vitás kérdések – ezekre reagáljatok
- **A. Gyűjtési cél / ritkaság** (Bence, Tamás): kell-e gén-atlasz / „fajtár” felfedezve-jelöléssel? Hogyan, hogy ne legyen nyomasztó pipálás, FOMO? Marika szerint a keresztezés már most túl bonyolult – ha erre épül a cél, kizárjuk-e a Marikákat?
- **B. Gondozás skálázása** (Dóra, Tamás): „eső” egy koppintással az egész bolygóra, vagy csak az aktív bolygó szomjazzon? Marikának épp az öntözés a kedvence – nem öljük meg a rituálét?
- **C. Napi megosztás** (Bence, Dóra, Tamás: üres; Marika: szívesen küldené): időzítő nélkül mi legyen benne személyes (súgások száma? hibák? a választás? a kikelt fa képe?)
- **D. Nyelv** (Marika): latin fajnevek, „bázispár”, „A=T / G≡C”, „mutáció”, „vágólap”. A DNS-téma a játék identitása – mit egyszerűsítsünk, mit hagyjunk? Saját becenév a fának?
- **E. A leszállt fa nézete** (Réka kritikus; Bence, Marika, Dóra is jelezte): egyetértetek, hogy ez az első számú felületi munka?
- **F. Mentés biztonsága** (Tamás első helyen): a játékosok szerint mennyire fontos? Használnátok egy „Kertem kódja” mentést?
- **G. Kezdőkép / keretezés** (Bence, Réka, Dóra): fontosabb-e, mint gondolnánk (az első 10 mp)?
- **H. Mit NE csináljunk:** Tamás szerint most semmi új rendszer, az alakítás és a látványcsiszolás várjon. Egyetértetek?
