#!/usr/bin/env python3
"""Génère le fond d'écran SeleneOS : ciel nocturne, grande lune, étoiles, crêtes brumeuses.

Usage : python3 tools/make-wallpaper.py [sortie.jpg] [largeur hauteur]
Dépendances : pip install numpy pillow
Change SEED pour obtenir un ciel différent, ou joue avec les couleurs ci-dessous.
"""
import sys

import numpy as np
from PIL import Image, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "wallpaper.jpg"
W, H = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (2880, 1800)
SEED = 7
rng = np.random.default_rng(SEED)

# --- palette ---------------------------------------------------------------
SKY_TOP = np.array([5, 6, 18]) / 255
SKY_MID = np.array([14, 15, 42]) / 255
SKY_LOW = np.array([44, 30, 92]) / 255      # lueur violette à l'horizon
HALO = np.array([140, 150, 255]) / 255      # halo bleu-lavande de la lune
MOON = np.array([236, 238, 255]) / 255

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
u, v = xx / W, yy / H


def smooth(x):
    return x * x * (3 - 2 * x)


def noise(scale, seed):
    """Bruit lissé (valeur) à l'échelle donnée (en cellules sur la largeur)."""
    r = np.random.default_rng(seed)
    gw, gh = max(2, int(scale)), max(2, int(scale * H / W))
    small = r.random((gh + 2, gw + 2)).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255


def fbm(base, octaves, seed):
    total, amp, norm = np.zeros((H, W), np.float32), 1.0, 0.0
    for o in range(octaves):
        total += amp * noise(base * 2**o, seed + o)
        norm += amp
        amp *= 0.5
    return total / norm


# --- ciel : dégradé vertical -------------------------------------------------
t = v[..., None]
img = np.where(
    t < 0.55,
    SKY_TOP + (SKY_MID - SKY_TOP) * smooth(np.clip(t / 0.55, 0, 1)),
    SKY_MID + (SKY_LOW - SKY_MID) * smooth(np.clip((t - 0.55) / 0.45, 0, 1)),
).astype(np.float32)

# --- voie lactée discrète ----------------------------------------------------
band = np.exp(-(((u * 0.62 - v * 0.95 + 0.18)) ** 2) / 0.012)
cloud = np.clip(fbm(5, 5, 100) * 1.6 - 0.55, 0, 1)
milky = (band * cloud * 0.30)[..., None] * np.array([0.55, 0.50, 0.95])
img += milky

# --- lune --------------------------------------------------------------------
mx, my, mr = 0.745 * W, 0.285 * H, 0.105 * H
d = np.sqrt((xx - mx) ** 2 + (yy - my) ** 2)
# halo : somme de gaussiennes larges
for k, (s, a) in enumerate([(0.9, 0.34), (2.2, 0.20), (5.0, 0.10), (11.0, 0.05)]):
    img += (a * np.exp(-((d / (mr * s)) ** 2)))[..., None] * HALO
disk = np.clip((mr - d) / 2.2 + 0.5, 0, 1)  # bord antialiasé
# relief : cratères = taches sombres à grande échelle + grain fin
craters = fbm(14, 4, 300)
fine = fbm(46, 3, 700)
maria = np.clip((fbm(4, 3, 500) - 0.42) * 2.4, 0, 1)
shade = 1.04 - 0.30 * maria - 0.22 * (craters - 0.5) - 0.16 * (fine - 0.5)
limb = np.clip(1 - (d / mr) ** 4 * 0.12, 0, 1)         # léger assombrissement du bord
# éclairage doux venant du haut-gauche
light = 0.97 + 0.10 * np.clip(((mx - xx) * 0.5 + (my - yy) * 0.8) / mr, -1, 1)
moon_rgb = np.clip(MOON * (shade * limb * light)[..., None] * 1.06, 0, 1)
img = img * (1 - disk[..., None]) + moon_rgb * disk[..., None]

# --- étoiles -----------------------------------------------------------------
n = int(W * H / 2500)
sx, sy = rng.random(n) * W, rng.random(n) ** 1.15 * H * 0.78
mag = rng.pareto(2.2, n) * 0.18 + 0.12                  # beaucoup de faibles, quelques brillantes
mag = np.clip(mag, 0.1, 1.0)
tint = rng.choice(3, n, p=[0.6, 0.25, 0.15])
cols = np.array([[0.85, 0.9, 1.0], [1.0, 0.95, 0.85], [0.8, 0.8, 1.0]])[tint]
stars = np.zeros((H, W, 3), np.float32)
for x, y, m, c in zip(sx, sy, mag, cols):
    if np.hypot(x - mx, y - my) < mr * 1.5:             # pas d'étoiles devant la lune
        continue
    xi, yi = int(x), int(y)
    if 0 <= xi < W - 1 and 0 <= yi < H - 1:
        stars[yi : yi + 2, xi : xi + 2] += (m * c)[None, None, :] * 0.9
img_stars = Image.fromarray((np.clip(stars, 0, 1) * 255).astype(np.uint8))
soft = np.asarray(img_stars.filter(ImageFilter.GaussianBlur(0.8)), dtype=np.float32) / 255
img += soft * 2.2
# quelques étoiles brillantes avec éclat en croix
for i in np.argsort(-mag)[:34]:
    x, y, m, c = int(sx[i]), int(sy[i]), mag[i], cols[i]
    if np.hypot(x - mx, y - my) < mr * 1.8 or not (30 < x < W - 30 and 30 < y < H * 0.7):
        continue
    L = int(10 + 26 * m)
    for k in range(1, L):
        f = (1 - k / L) ** 2 * 0.55 * m
        for (a, b) in ((x + k, y), (x - k, y), (x, y + k), (x, y - k)):
            img[b, a] += f * c
    img[y - 1 : y + 2, x - 1 : x + 2] += 0.9 * c

# --- crêtes brumeuses (3 plans) ---------------------------------------------
layers = [
    (0.74, 0.050, 11, np.array([30, 24, 72]) / 255, 0.55),
    (0.82, 0.060, 8, np.array([20, 16, 54]) / 255, 0.70),
    (0.91, 0.070, 6, np.array([10, 8, 30]) / 255, 0.90),
]
cx = np.linspace(0, 1, W, dtype=np.float32)
for li, (base, amp, freq, col, opa) in enumerate(layers):
    ridge = np.zeros(W, np.float32)
    for o in range(5):
        ridge += np.sin(cx * freq * 2**o * np.pi + rng.random() * 6.28) / (1.9**o)
    ridge = base + amp * ridge / 2.2
    mask = np.clip((v - ridge[None, :]) * H / 2.0 + 0.5, 0, 1)
    fog = np.exp(-np.clip(v - ridge[None, :], 0, 1) * 7)[..., None]     # brume près des crêtes
    layer_col = col * (0.75 + 0.25 * fog)
    img = img * (1 - (mask * opa)[..., None]) + layer_col * (mask * opa)[..., None]
    # voile de brume entre les plans
    haze = np.exp(-((v - (ridge[None, :] - 0.015)) ** 2) / 0.0006) * 0.10
    img += haze[..., None] * np.array([0.45, 0.40, 0.9])

# --- vignette + grain --------------------------------------------------------
vig = 1 - 0.38 * np.clip(((u - 0.5) ** 2 + (v - 0.45) ** 2) * 1.7, 0, 1)
img *= vig[..., None]
img += rng.normal(0, 0.006, img.shape).astype(np.float32)           # anti-banding

out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
out.save(OUT, quality=90, optimize=True, progressive=True)
print(f"OK {OUT} {W}x{H}")
