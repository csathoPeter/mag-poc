#!/usr/bin/env bash
# Képernyőképek fej nélkül, szoftveres Vulkannal (lassú, csak a kép ellenőrzésére jó, a fps itt nem mérvadó).
# Használat: tools/render_shots.sh kimenet.png SPEC [SPEC...]
#   SPEC = dna,kód,növekedés[,fly[,go]]   pl. 2-5-1-3-0-5,kert01,1   vagy   2-5-1-3-0-5,kert01,1,fly,go
#   "fly" a repülős kertet tölti be, "go" ráadásul előretolja az analóg kart.
#   Bolygó: planet,kód,fák száma[,óra[,focusN|plant]]   pl. planet,bolygo01,14,23,focus2
#   (óra: napszak 0–24; focusN: leszáll az N-edik fához; plant: ültet egy újat és odarepül)
#   Mentésből: state[,óra[,focusN|plant|zoomZ|macro]]; a mentés helye a MAG_ARGS-ban, pl.
#   MAG_ARGS="--state=/tmp/s.json --player=TESZT1" tools/render_shots.sh /tmp/a.png state,12 state,12,zoom0
#   (ha a fájl nincs meg, új játékot kezd és elmenti; --state nélkül a valódi mentést csak olvassa)
#   DNS-tábla és táska: state,óra,board | boardNN | boardNNx | boardplay | solve | bag   pl. state,12,board50x
#   A nagy pillanat: state,óra,helixNN (a kettős spirál NN%-ánál, pl. helix45 = a spirál közepe)
#     sow (a mag földet ért: jel + felirat) | sowNN (az elvetés NN%-ánál, pl. sow30 = a mag hullik)
#     hatchNN (elvetés, nap +1, a kikelés NN%-ánál, pl. hatch50) | revealNN (a mentésből kikelő fa, --state és --nap=+1 kell)
#   Gondozás: state,óra,thirsty (3 nap múlva, lekonyulva) | waterNN (öntözés NN%-nál) | bloom | bud | wilt | gatherNN (maggyűjtés)
#   Keresztezés (két teszt-maggal a kert fáiról): state,óra,crossbag (táska párválasztó módban) | cross / crossNN (a keresztezett
#     tábla, a lezárt sorok kitöltve, 1/2/M jellel) | sprouts / sproutsNN (a három csíra, a kinövés NN%-ánál) | starsNN (a 0. csíra
#     választva: a két csillag felszáll, NN% ≈ 45 a spirál eleje) | crossplay (valódi koppintások: Keresztezem → Ezzel → tábla →
#     Ezt nevelem; --state=fájl-lal a mentésbe is)
#   Csillagok (M6; ha 6-nál kevesebb csillag van, teszt-csillagokkal pótolja): state,óra,sky / skyZ (kívülről, Z közelséggel) |
#     skyland (leszállva, a fa mögötti égen) | herb / herbN (a csillagkép-nézet, az N. csillag lapja) | herbland (ugyanez
#     leszállva) | releaseask (az elengedés megerősítése) | releaseNN (a 0. fa elengedése NN%-nál: 25 oszlik, 55 a fény
#     felszáll, 92 a csillag kigyullad) | releaseplay / herbplay (valódi koppintásokkal; --state=fájl-lal a mentésbe is)
#   Bolygók (M7): state,óra,birth / birthNN (megtelik, az új bolygó születése NN%-nál) | system / systemN / systemNzZ
#     (N bolygó kicsinyítve, a középső aktív) | hopNN (átrepülés NN%-nál, ~74 a csere) | hopplay (valódi koppintás a kis
#     bolygóra; --state-tel mentve) | hopsow (megtelt bolygóról elvetés: átrepülés az új bolygóra, ott hull le a mag)
#   Alakítás (M8, planet vagy state, a 0. fán): shape | shapehi | shapecut / shapecutNN | shapeundo | shapetieD (D napja
#     kötözve) | shapedayN (N napváltás) | shapedrag | shapeplay (valódi érintések) | shapesave (--state-tel mentve);
#     hetedik elemként lodK (a fa a K. részletességi szinten), pl. planet,bolygo01,5,12,shapetie3,lod2
#   Megosztás (M10, state): share | shareseed | shareherb | sharedaily | shareplanet (a lap a keretezett képpel; a kép a
#     kimenet mellé is: *_kep.jpg) | gift / giftNN („Kaptál egy magot”) | guest / guestfocus / guestask (a saját bolygó
#     linkje vendégként, „Magot kérek”) | codeentry | codebad; URL-paraméterek: MAG_ARGS="--mag=KOD" vagy "--bolygo=…"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="$HOME/godot-bin/godot"
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
out=$1; shift; i=0; files=()
for s in "$@"; do i=$((i+1)); f=/tmp/shot_$i.png
  (cd "$ROOT/godot" && timeout 280 xvfb-run -a -s "-screen 0 390x780x24" "$G" --path . --rendering-method mobile \
     --rendering-driver vulkan --resolution 390x780 -- ${MAG_ARGS:-} --shot="$f,$s" 2>&1 | grep -E "STATS|STATE|SHAPE|SHARE|TOUCH|CLICK|^  [^ ]|SCRIPT ERROR|SHADER ERROR|Parse Error" || true)
  files+=("$f"); done
python3 - "$out" "${files[@]}" <<'P'
import sys
from PIL import Image
ims=[Image.open(f) for f in sys.argv[2:]]
S=Image.new('RGB',(sum(i.width for i in ims),ims[0].height)); x=0
for i in ims: S.paste(i,(x,0)); x+=i.width
S.save(sys.argv[1])
P
echo "kész: $out"
