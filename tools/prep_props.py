#!/usr/bin/env python3
"""Díszek a kopár bolygókra: a Quaternius Stylized Nature MegaKit (CC0, Standard) kiválasztott modelljei.

A csomag: https://store.godotengine.org/asset/quaternius/stylized-nature-megakit/ (zip). Használat:
  python3 tools/prep_props.py /útvonal/Stylized_Nature_MegaKitStandard.zip
Csak a szükséges glTF-eket és textúrákat másolja a godot/props/quaternius/ mappába; a textúrákat lekicsinyíti (a webes
build mérete miatt), a glTF-ek képhivatkozásait átírja rájuk. A licenc (CC0) a mappába kerül.
"""
import io
import json
import sys
import zipfile
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "godot" / "props" / "quaternius"
MODELS = [
	"Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3",
	"Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3", "Pebble_Round_4", "Pebble_Round_5",
	"Mushroom_Common", "Clover_1", "Clover_2", "Fern_1", "Plant_1", "Plant_7", "Flower_3_Group", "Flower_4_Group",
]
# textúra → legnagyobb oldal (a levelek atlasza nagyobb marad: a kivágott körvonal ott látszik)
TEXTURES = {"Rocks_Diffuse.png": 512, "PathRocks_Diffuse.png": 512, "Mushrooms.png": 512, "Leaves.png": 1024,
	"Flowers.png": 512}


def main(zip_path: str) -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	with zipfile.ZipFile(zip_path) as z:
		names = z.namelist()
		lic = next(n for n in names if n.endswith("License_Standard.txt"))
		(OUT / "LICENSE_Quaternius_CC0.txt").write_bytes(z.read(lic))
		for tex, size in TEXTURES.items():
			src = next(n for n in names if n.endswith("Textures/" + tex))
			im = Image.open(io.BytesIO(z.read(src)))
			im.thumbnail((size, size), Image.LANCZOS)
			im.save(OUT / tex, optimize=True)
		for m in MODELS:
			g = json.loads(z.read(next(n for n in names if n.endswith("glTF/" + m + ".gltf"))))
			for img in g.get("images", []):
				img["uri"] = Path(img["uri"]).name
				assert img["uri"] in TEXTURES, img["uri"]
			bin_name = g["buffers"][0]["uri"]
			(OUT / (m + ".gltf")).write_text(json.dumps(g, indent=1))
			(OUT / bin_name).write_bytes(z.read(next(n for n in names if n.endswith("glTF/" + bin_name))))
	print("kész:", OUT)


if __name__ == "__main__":
	main(sys.argv[1])
