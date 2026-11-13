#!/usr/bin/env python3
"""Festett felhők atlasza (2026. 11. 13.): a Nano Banana Pro-val festett gomolyfelhők (art/felho/nyers_*.jpg, zöld
kulcs-háttéren) kivágva → godot/textures/felhok.png (4×2 cella, cellánként egy felhő, alul középre igazítva).
Használat: python3 tools/prep_clouds.py
A háttér színét a kép szélén mért mediánból veszi (képenként kicsit más zöld), az átlátszóságot a háttértől való
színtávolságból, a széleken a zöld visszaverődést levágja (a felhő fehér / lilás: zöldje nem lehet több, mint a piros
és a kék nagyobbika)."""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "felho"
OUT = ROOT / "godot" / "textures" / "felhok.png"
CELL = 384
COLS, ROWS = 4, 2


def key(path: Path) -> Image.Image:
	a = np.asarray(Image.open(path).convert("RGB")).astype(float) / 255.0
	edge = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
	bg = np.median(edge, axis=0)
	dist = np.linalg.norm(a - bg, axis=-1)
	alpha = np.clip((dist - 0.18) / 0.32, 0.0, 1.0)
	rgb = a.copy()
	g_lim = np.maximum(rgb[..., 0], rgb[..., 2])
	rgb[..., 1] = np.minimum(rgb[..., 1], g_lim)
	# a félig átlátszó szélen a háttér kivonása (a kulcsszín ne keveredjen bele)
	al = np.maximum(alpha, 1e-3)[..., None]
	unmix = (a - bg * (1.0 - al)) / al
	unmix[..., 1] = np.minimum(unmix[..., 1], np.maximum(unmix[..., 0], unmix[..., 2]))
	rgb = np.where(alpha[..., None] < 0.98, np.clip(unmix, 0, 1), rgb)
	im = Image.fromarray((np.dstack([rgb, alpha]) * 255 + 0.5).astype(np.uint8), "RGBA")
	return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def main() -> None:
	atlas = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
	files = sorted(SRC.glob("nyers_*.jpg"))
	for i, f in enumerate(files[: COLS * ROWS]):
		im = key(f)
		pad = int(CELL * 0.04)
		s = min((CELL - 2 * pad) / im.width, (CELL - 2 * pad) / im.height)
		im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
		x = (i % COLS) * CELL + (CELL - im.width) // 2
		y = (i // COLS) * CELL + CELL - pad - im.height
		atlas.alpha_composite(im, (x, y))
		print(f.name, "→ cella", i, im.size)
	OUT.parent.mkdir(parents=True, exist_ok=True)
	atlas.save(OUT, optimize=True)
	print(OUT, OUT.stat().st_size // 1024, "KB")


if __name__ == "__main__":
	main()
