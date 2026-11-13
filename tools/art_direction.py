#!/usr/bin/env python3
"""Art direction a Nano Banana-val (Google Gemini képmodellek).

A játék valódi képernyőképét elküldi a képmodellnek egy stílusleírással, és a változatokat
egy telefonon nézhető, önálló HTML-oldalra teszi (a játék képe mellé). Csak fejlesztéshez:
a játékba nem kerül be semmi (a növény a DNS-ből nő, determinisztikusan).

Kulcs: a felhős környezetben a hálózati proxy teszi hozzá (x-goog-api-key a
generativelanguage.googleapis.com-ra); helyben a GEMINI_API_KEY környezeti változóból.

Használat:
  tools/art_direction.py run art/kor01/terv.json        # képernyőképek (ha hiányoznak) + generálás + oldal
  tools/art_direction.py run art/kor01/terv.json --csak-oldal
  tools/art_direction.py gen be.png ki.jpg --modell pro --prompt "..."   # egy kép

A terv (JSON):
  {"cim": "...", "stilus": "közös stílusleírás (angolul)",
   "jelenetek": [{"nev": "kint", "cim": "A bolygó kívülről", "shot": "planet,bolygo01,14,12,zoom0,clean"}],
   "iranyok":   [{"nev": "ghibli", "cim": "Ghibli-háttér", "prompt": "...", "modellek": ["pro", "nb2"]}]}
Kimenet a terv mappájában: jatek_<jelenet>.png, <jelenet>_<irány>_<modell>.jpg, eredmeny.json, oldal.html.
"""
import argparse
import base64
import concurrent.futures as cf
import io
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
API = "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent"
MODELLEK = {
	"pro": "gemini-3-pro-image",          # Nano Banana Pro: hűbb a bemeneti képhez, pontosabb
	"nb2": "gemini-3.1-flash-image",      # Nano Banana 2: gyors, olcsóbb, próbálgatáshoz
	"lite": "gemini-3.1-flash-lite-image",
	"nb1": "gemini-2.5-flash-image",
}
MODELL_NEV = {"pro": "Nano Banana Pro", "nb2": "Nano Banana 2", "lite": "Nano Banana 2 Lite", "nb1": "Nano Banana"}

# A modellnek minden kérésnél: a játék képéből dolgozzon, ne rajzolja újra a jelenetet.
ALAP = (
	"This is a real-time 3D frame from a calm mobile game about unique procedurally grown plants on a tiny planet. "
	"Repaint THIS EXACT frame as a target look for the game's art direction. Keep the camera, framing, composition, "
	"the planet's silhouette, every tree's position, size, trunk and branch structure and the plant colours' hues "
	"recognisable – change only rendering style, lighting, materials and atmosphere. Do not add or remove objects, "
	"characters, buildings, text, UI or logos. It must stay achievable in a real-time stylized 3D renderer on a phone: "
	"broad soft shapes, no fine line-art, no black outlines, no photorealism."
)


def api_key_header() -> dict:
	k = os.environ.get("GEMINI_API_KEY", "")
	return {"x-goog-api-key": k} if k else {}  # felhőben a proxy teszi hozzá


def kep_b64(path: Path, max_px: int = 1536) -> tuple[str, str]:
	im = Image.open(path).convert("RGB")
	im.thumbnail((max_px, max_px))
	buf = io.BytesIO()
	im.save(buf, "PNG")
	return base64.b64encode(buf.getvalue()).decode(), "image/png"


def generate(be: Path | None, prompt: str, modell: str, ki: Path, arany: str = "9:16", refek: list | None = None) -> dict:
	"""Egy kép a modelltől. Visszaadja a metaadatokat (idő, tokenek, a modell szövege).
	refek: [(kép, mire jó)] – stílusminták a játék képe után (a modell a sorrendjükből tudja, melyik melyik)."""
	parts: list = []
	if be is not None:
		data, mime = kep_b64(be)
		parts.append({"inlineData": {"mimeType": mime, "data": data}})
	if refek:
		leiras = ["Image 1 is the game frame to repaint (keep its content and composition)."]
		for i, (rp, mire) in enumerate(refek, start=2):
			data, mime = kep_b64(Path(rp), 1024)
			parts.append({"inlineData": {"mimeType": mime, "data": data}})
			leiras.append(f"Image {i} is a STYLE reference only – take from it: {mire}. Do not copy its content or composition.")
		parts.append({"text": " ".join(leiras)})
	parts.append({"text": prompt})
	body = {
		"contents": [{"parts": parts}],
		"generationConfig": {"responseModalities": ["IMAGE", "TEXT"], "imageConfig": {"aspectRatio": arany}},
	}
	req = urllib.request.Request(
		API.format(MODELLEK[modell]), data=json.dumps(body).encode(),
		headers={"Content-Type": "application/json", **api_key_header()}, method="POST")
	t0 = time.time()
	for proba in range(4):
		try:
			with urllib.request.urlopen(req, timeout=300) as r:
				d = json.load(r)
			break
		except urllib.error.HTTPError as e:
			szoveg = e.read().decode(errors="replace")[:500]
			if e.code in (429, 500, 502, 503, 504) and proba < 3:
				time.sleep(5 * 2 ** proba)
				continue
			return {"hiba": f"HTTP {e.code}: {szoveg}"}
		except (urllib.error.URLError, TimeoutError) as e:
			if proba < 3:
				time.sleep(5 * 2 ** proba)
				continue
			return {"hiba": str(e)}
	meta = {"mp": round(time.time() - t0, 1), "tokenek": d.get("usageMetadata", {})}
	szoveg = []
	kep = None
	for c in d.get("candidates", []):
		for p in (c.get("content") or {}).get("parts", []):
			if "inlineData" in p:
				kep = base64.b64decode(p["inlineData"]["data"])
			elif "text" in p and not p.get("thought"):
				szoveg.append(p["text"])
	if kep is None:
		meta["hiba"] = "nincs kép a válaszban: " + json.dumps(d)[:500]
		return meta
	im = Image.open(io.BytesIO(kep)).convert("RGB")
	meta["meret"] = list(im.size)
	ki.parent.mkdir(parents=True, exist_ok=True)
	im.save(ki, "JPEG", quality=88)
	if szoveg:
		meta["szoveg"] = " ".join(szoveg)[:400]
	return meta


def shot(spec: str, ki: Path, res: str = "780x1560", extra: str = "") -> None:
	"""Képernyőkép fej nélkül (szoftveres Vulkan, Mobile renderer), mint a render_shots.sh, nagyobb felbontásban."""
	w, h = res.split("x")
	env = dict(os.environ, VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/lvp_icd.json")
	cmd = ["timeout", "400", "xvfb-run", "-a", "-s", f"-screen 0 {w}x{h}x24", str(Path.home() / "godot-bin/godot"),
		"--path", ".", "--rendering-method", "mobile", "--rendering-driver", "vulkan", "--resolution", res, "--",
		*extra.split(), f"--shot={ki},{spec}"]
	r = subprocess.run(cmd, cwd=ROOT / "godot", env=env, capture_output=True, text=True)
	if not ki.exists():
		sys.exit(f"nem készült kép: {spec}\n{r.stdout[-2000:]}\n{r.stderr[-2000:]}")


def run(terv_path: Path, csak_oldal: bool, ujra: bool) -> None:
	terv = json.loads(terv_path.read_text())
	mappa = terv_path.parent
	eredmeny_path = mappa / "eredmeny.json"
	eredmeny = json.loads(eredmeny_path.read_text()) if eredmeny_path.exists() else {}
	if not csak_oldal:
		with cf.ThreadPoolExecutor(3) as ex:
			fut = {}
			for j in terv["jelenetek"]:
				p = mappa / f"jatek_{j['nev']}.png"
				if ujra or not p.exists():
					fut[ex.submit(shot, j["shot"], p, terv.get("felbontas", "780x1560"), terv.get("godot_args", ""))] = j["nev"]
			for f in cf.as_completed(fut):
				f.result()
				print("képernyőkép:", fut[f], flush=True)
		feladatok = []
		for j in terv["jelenetek"]:
			for ir in terv["iranyok"]:
				refek = [(mappa / r["kep"], r["mire"]) for r in ir.get("referenciak", [])]
				for m in ir.get("modellek", ["pro"]):
					for v in range(ir.get("valtozatok", 1)):
						kulcs = f"{j['nev']}_{ir['nev']}_{m}" + (f"_{v + 1}" if v else "")
						if not ujra and kulcs in eredmeny and "hiba" not in eredmeny[kulcs]:
							continue
						prompt = "\n\n".join(x for x in [ALAP, terv.get("stilus", ""), ir["prompt"], j.get("prompt", "")] if x)
						feladatok.append((kulcs, mappa / f"jatek_{j['nev']}.png", prompt, m, refek))
		with cf.ThreadPoolExecutor(6) as ex:
			fut = {ex.submit(generate, be, pr, m, mappa / f"{k}.jpg", "9:16", rf): k for k, be, pr, m, rf in feladatok}
			for f in cf.as_completed(fut):
				k = fut[f]
				eredmeny[k] = f.result()
				print(k, eredmeny[k].get("hiba") or f"{eredmeny[k]['mp']} mp", flush=True)
				eredmeny_path.write_text(json.dumps(eredmeny, ensure_ascii=False, indent=1))
	oldal(terv, mappa, eredmeny)


def data_uri(path: Path, max_h: int = 1100) -> str:
	im = Image.open(path).convert("RGB")
	if im.height > max_h:
		im = im.resize((round(im.width * max_h / im.height), max_h), Image.LANCZOS)
	buf = io.BytesIO()
	im.save(buf, "JPEG", quality=82)
	return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def oldal(terv: dict, mappa: Path, eredmeny: dict) -> None:
	"""Önálló HTML (a képek data: URI-ként): jelenetenként vízszintesen görgethető sor, a játék képe az első."""
	esc = lambda s: s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
	sorok = []
	for j in terv["jelenetek"]:
		kartyak = [f'<figure class="kartya jatek"><img src="{data_uri(mappa / f"jatek_{j["nev"]}.png")}" alt="">'
			f'<figcaption><b>A játék most</b><span>{esc(j["shot"])}</span></figcaption></figure>']
		for ir in terv["iranyok"]:
			for m, k in ((m, f"{j['nev']}_{ir['nev']}_{m}" + (f"_{v + 1}" if v else ""))
					for m in ir.get("modellek", ["pro"]) for v in range(ir.get("valtozatok", 1))):
				e = eredmeny.get(k, {})
				if "hiba" in e or not (mappa / f"{k}.jpg").exists():
					kartyak.append(f'<figure class="kartya"><div class="hiba">Nem készült el.<br>{esc(str(e.get("hiba", "")))[:200]}</div>'
						f'<figcaption><b>{esc(ir["cim"])}</b><span>{MODELL_NEV[m]}</span></figcaption></figure>')
					continue
				kartyak.append(f'<figure class="kartya"><img src="{data_uri(mappa / f"{k}.jpg")}" alt="" loading="lazy">'
					f'<figcaption><b>{esc(ir["cim"])}</b><span>{MODELL_NEV[m]} · {e.get("mp", "?")} mp</span></figcaption></figure>')
		sorok.append(f'<section><h2>{esc(j["cim"])}</h2><div class="sor">{"".join(kartyak)}</div></section>')
	iranyok = "".join(f'<li><b>{esc(ir["cim"])}</b> – {esc(ir.get("leiras", ""))}</li>' for ir in terv["iranyok"])
	html = f"""<!DOCTYPE html>
<html lang="hu"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(terv["cim"])}</title>
<style>
:root {{ color-scheme: dark; }}
body {{ margin: 0; font: 15px/1.45 -apple-system, system-ui, sans-serif; background: #15131c; color: #e9e6f2; }}
header {{ padding: 18px 16px 4px; }}
h1 {{ font-size: 20px; margin: 0 0 6px; font-weight: 600; }}
header p, header li {{ color: #b9b3c9; margin: 4px 0; }}
header ul {{ padding-left: 18px; margin: 6px 0; }}
h2 {{ font-size: 17px; margin: 22px 16px 8px; font-weight: 600; }}
.sor {{ display: flex; gap: 10px; overflow-x: auto; scroll-snap-type: x mandatory; padding: 0 16px 10px; }}
.kartya {{ flex: 0 0 72vw; max-width: 340px; margin: 0; scroll-snap-align: center; }}
.kartya img {{ width: 100%; aspect-ratio: 9/16; object-fit: cover; border-radius: 12px; display: block; background: #222; }}
.kartya.jatek img {{ outline: 2px solid #8fd6b4; outline-offset: -2px; }}
figcaption {{ padding: 6px 2px; display: flex; flex-direction: column; }}
figcaption span {{ color: #9a93ad; font-size: 13px; }}
.hiba {{ aspect-ratio: 9/16; border-radius: 12px; background: #2a2533; color: #d99; padding: 14px; font-size: 13px; }}
.nagy {{ position: fixed; inset: 0; background: #000e; display: none; align-items: center; justify-content: center; z-index: 9; }}
.nagy img {{ max-width: 100vw; max-height: 100vh; }}
</style></head><body>
<header><h1>{esc(terv["cim"])}</h1><p>{esc(terv.get("bevezeto", ""))}</p><ul>{iranyok}</ul>
<p>Húzd oldalra a sorokat; képre koppintva nagyban látszik.</p></header>
{"".join(sorok)}
<div class="nagy" id="nagy"><img alt=""></div>
<script>
const n = document.getElementById('nagy');
document.querySelectorAll('.kartya img').forEach(i => i.addEventListener('click', () => {{ n.firstElementChild.src = i.src; n.style.display = 'flex'; }}));
n.addEventListener('click', () => n.style.display = 'none');
</script>
</body></html>"""
	(mappa / "oldal.html").write_text(html)
	print("oldal:", mappa / "oldal.html", f"{len(html) / 1e6:.1f} MB")


def main() -> None:
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	sub = ap.add_subparsers(dest="cmd", required=True)
	r = sub.add_parser("run")
	r.add_argument("terv", type=Path)
	r.add_argument("--csak-oldal", action="store_true", help="csak az oldalt építi újra")
	r.add_argument("--ujra", action="store_true", help="a meglévő képeket is újra készíti")
	g = sub.add_parser("gen")
	g.add_argument("be", help="bemeneti kép, vagy - (csak szöveg)")
	g.add_argument("ki", type=Path)
	g.add_argument("--prompt", required=True)
	g.add_argument("--modell", default="pro", choices=MODELLEK)
	g.add_argument("--arany", default="9:16")
	a = ap.parse_args()
	if a.cmd == "run":
		run(a.terv.resolve(), a.csak_oldal, a.ujra)
	else:
		be = None if a.be == "-" else Path(a.be)
		print(json.dumps(generate(be, (ALAP + "\n\n" if be else "") + a.prompt, a.modell, a.ki, a.arany), ensure_ascii=False))


if __name__ == "__main__":
	main()
