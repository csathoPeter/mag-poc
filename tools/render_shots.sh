#!/usr/bin/env bash
# Képernyőképek fej nélkül, szoftveres Vulkannal (lassú, csak a kép ellenőrzésére jó, a fps itt nem mérvadó).
# Használat: tools/render_shots.sh kimenet.png SPEC [SPEC...]
#   SPEC = dna,kód,növekedés[,kapcsolók…]   pl. 2-5-1-3-0-5,kert01,1   vagy   2-5-1-3-0-5,kert01,1,fly,go
#   "fly" a repülős kertet tölti be, "go" ráadásul előretolja az analóg kart.
#   "board" megnyitja a DNS-táblát, "cross" keresztezéses táblát nyit, "solve" kirakja,
#   "helix1.3" a kettős spirált 1,3 másodpercnél mutatja (a növekedés ilyenkor legyen 0).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="$HOME/godot-bin/godot"
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
out=$1; shift; i=0; files=()
for s in "$@"; do i=$((i+1)); f=/tmp/shot_$i.png
  (cd "$ROOT/godot" && timeout 280 xvfb-run -a -s "-screen 0 390x780x24" "$G" --path . --rendering-method mobile \
     --rendering-driver vulkan --resolution 390x780 -- --shot="$f,$s" 2>&1 | grep -E "STATS|SCRIPT ERROR|SHADER ERROR|Parse Error" || true)
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
