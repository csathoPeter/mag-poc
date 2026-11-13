#!/usr/bin/env python3
"""A bolygók talajának csempézhető textúrái (art direction 3. kör: kavics, moha).

Determinisztikus (rögzített mag), a kimenet a repóban van: godot/textures/talaj_*.png. Újragenerálás:
  python3 tools/gen_ground_tex.py
Csatornák (nem szín, lineáris adat – a shader a bolygó saját színével színez):
  R, G: a normáltérkép x, y-ja (0,5 = sík; z = sqrt(1 - x² - y²)), a domborzatból számolva → a kövek, párnák a nap felől
        világosak, a túloldalon árnyékosak (bump map)
  B:    árnyalás (0,5 = semleges; a kövek közti rés sötétebb, a kövek tónusa kőnként kicsit más)
  A:    fedés (1 = kő / mohapárna, 0 = homok / rés): a shader ezzel keveri a két tónust
A textúra minden irányban ismétlődik (a távolságok körbeérnek), a mipmapeket a Godot importálója készíti.
"""
from pathlib import Path

import numpy as np
from PIL import Image

N = 512
OUT = Path(__file__).resolve().parent.parent / "godot" / "textures"


def wrap_dist(xx, yy, cx, cy):
	dx = (xx - cx + N / 2) % N - N / 2
	dy = (yy - cy + N / 2) % N - N / 2
	return dx, dy


def tile_noise(rng, cells, octaves=3):
	"""Csempézhető értékzaj (bilineáris, simított), 0–1."""
	out = np.zeros((N, N))
	amp, tot = 1.0, 0.0
	for o in range(octaves):
		c = cells * 2 ** o
		g = rng.random((c, c))
		x = np.arange(N) * c / N
		i0 = np.floor(x).astype(int)
		f = x - i0
		f = f * f * (3 - 2 * f)
		i1 = (i0 + 1) % c
		a = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
		b = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
		out += amp * (a * (1 - f)[:, None] + b * f[:, None])
		tot += amp
		amp *= 0.5
	return out / tot


def normals(h, strength):
	gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
	gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
	n = np.stack([-gx, -gy, np.ones_like(h)], -1)
	n /= np.linalg.norm(n, axis=-1, keepdims=True)
	return n


def blur(a, r):
	"""Körbeérő doboz-elmosás (kétszer: közel Gauss)."""
	for _ in range(2):
		for ax in (0, 1):
			acc = np.zeros_like(a)
			for k in range(-r, r + 1):
				acc += np.roll(a, k, ax)
			a = acc / (2 * r + 1)
	return a


def save(name, n, shade, cover):
	rgba = np.stack([n[..., 0] * 0.5 + 0.5, n[..., 1] * 0.5 + 0.5, np.clip(shade, 0, 1), np.clip(cover, 0, 1)], -1)
	OUT.mkdir(parents=True, exist_ok=True)
	Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / name)
	print(OUT / name)


def gravel():
	"""Kavics: különböző méretű, nyújtott, elforgatott, lapos kupolájú kövek homokban; a kövek körül halvány rés-árnyék."""
	rng = np.random.default_rng(20261113)
	yy, xx = np.mgrid[0:N, 0:N].astype(float)
	height = np.zeros((N, N))
	cover = np.zeros((N, N))
	tone = np.full((N, N), 0.5)
	# a kövek csoportosan (csempézhető zaj szerinti valószínűség), sok kicsi, kevés nagy
	clump = tile_noise(rng, 4, 2)
	placed = 0
	while placed < 260:
		cx, cy = rng.random(2) * N
		if rng.random() > 0.25 + 0.9 * clump[int(cy), int(cx)]:
			continue
		r = 7 + 26 * rng.random() ** 2.2
		asp = 1.0 + 0.6 * rng.random()
		an = rng.random() * np.pi
		dx, dy = wrap_dist(xx, yy, cx, cy)
		u = (dx * np.cos(an) + dy * np.sin(an)) / (r * asp)
		v = (-dx * np.sin(an) + dy * np.cos(an)) / r
		t = np.sqrt(u * u + v * v)
		inside = t < 1.0
		if not inside.any():
			continue
		# lapos kupola (a kavics nem félgömb): a magasság a sugárral arányos
		dome = np.where(inside, np.sqrt(np.clip(1 - t * t, 0, 1)) ** 0.7 * r * 0.55, 0)
		new = dome > height
		height = np.where(new, dome, height)
		cover = np.maximum(cover, np.clip((1.0 - t) * r * 0.6, 0, 1))
		tone = np.where(new & inside, 0.42 + 0.16 * rng.random(), tone)
		placed += 1
	sand = tile_noise(rng, 64, 2)
	height += (sand - 0.5) * 1.2
	# rés-árnyék: a kövek körül a homok sötétebb (a kő a homokba ül)
	occl = blur(cover, 5)
	shade = np.where(cover > 0.5, tone, 0.5 - 0.22 * occl + (sand - 0.5) * 0.08)
	save("talaj_kavics.png", normals(height, 0.55), shade, cover)


def moss():
	"""Moha: puha, szabálytalan párnák (eltérő méret, hullámos szél, nem rácsban), köztük keskeny, halk rés; finom bolyh.
	Az első, rácsba rázott, egyforma körökből álló változat a telefonon macskakőnek / terítőmintának látszott (Péter)."""
	rng = np.random.default_rng(20261115)
	yy, xx = np.mgrid[0:N, 0:N].astype(float)
	height = np.zeros((N, N))
	cover = np.zeros((N, N))
	# a szél hullámossága: a távolságot csempézhető zajjal torzítjuk
	warp = (tile_noise(rng, 10, 3) - 0.5) * 2.0
	placed = 0
	while placed < 70:
		cx, cy = rng.random(2) * N
		r = 22 + 70 * rng.random() ** 1.6
		asp = 1.0 + 0.5 * rng.random()
		an = rng.random() * np.pi
		dx, dy = wrap_dist(xx, yy, cx, cy)
		u = (dx * np.cos(an) + dy * np.sin(an)) / (r * asp)
		v = (-dx * np.sin(an) + dy * np.cos(an)) / r
		t = np.sqrt(u * u + v * v) * (1.0 + 0.28 * warp)
		dome = np.clip(1 - t * t, 0, 1) ** 0.5 * r * (0.25 + 0.2 * rng.random())
		height = np.maximum(height, dome)
		cover = np.maximum(cover, np.clip((1 - t) * 3, 0, 1))
		placed += 1
	height = blur(height, 2)
	fuzz = tile_noise(rng, 96, 2)
	height += (fuzz - 0.5) * 2.5
	hn = (height - height.min()) / (height.max() - height.min())
	shade = 0.42 + 0.16 * hn + (fuzz - 0.5) * 0.12
	save("talaj_moha.png", normals(height, 0.22), shade, blur(cover, 2))


if __name__ == "__main__":
	gravel()
	moss()
