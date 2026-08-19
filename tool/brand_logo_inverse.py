#!/usr/bin/env python3
"""Fabrique `assets/images/brand_logo_inverse.webp` à partir de l'emblème source.

    python3 tool/brand_logo_inverse.py <emblème.png>

L'emblème imprimé est indigo sur disque blanc. Le menu latéral est peint au bleu
de marque : posée telle quelle, la pièce y ferait une tache blanche. La variante
inverse la lecture — structure et tracé de la colombe en **blanc**, disque
**évidé**, textes dans le **bleu primaire** — et c'est ce fichier-là que rend
`BrandLogo.inverse`.

**Pourquoi un script et non une permutation de couleurs.** Trois choses sont
« blanches » dans le fichier source et doivent partir dans trois directions :
le disque et l'intérieur de la colombe (à vider), les lettres de l'anneau et du
bandeau (à passer en bleu), et les intérieurs de plumes (à vider, alors qu'ils
font exactement la taille d'un glyphe). Aucune règle sur la couleur seule ne les
sépare. On étiquette donc les **composantes connexes** des blancs, puis on
tranche par géométrie : une composante est une lettre si son centroïde tombe
hors du disque intérieur (texte de l'anneau) ou sous le haut du bandeau (texte
du bandeau). Les plumes, enfermées dans le disque, restent du côté du dessin.

Les constantes géométriques sont **relevées sur le fichier source** (centre et
rayon du cercle, haut du bandeau). Changer d'emblème demande de les relever à
nouveau — le script ne les devine pas.

Sortie en PNG, puis `cwebp -lossless` (l'asset du dépôt est en WebP) :

    cwebp -lossless -q 100 /tmp/brand_logo_inverse.png \
        -o assets/images/brand_logo_inverse.webp
"""
import math
import sys
from collections import deque

import _png

CX, CY, R_IN = 614.5, 610.5, 455.5   # cercle de l'emblème, en pixels source
RIBBON_TOP = 1090                    # au-dessous : le texte du bandeau
BLUE = (34, 59, 140)                 # AppColors.primary
INK = (49, 39, 131)                  # l'indigo du fichier source
MIN_GLYPH = 50                       # en deçà : poussière d'anti-crénelage
DST = '/tmp/brand_logo_inverse.png'


def main(src):
    w, h, b = _png.read_rgba(src)
    n_px = w * h

    white = bytearray(n_px)
    for i in range(n_px):
        j = i * 4
        if b[j + 3] > 128 and b[j] > 170 and b[j + 1] > 170 and b[j + 2] > 170:
            white[i] = 1

    lab = [0] * n_px
    glyph = bytearray(n_px)   # lettres -> bleu
    open_ = bytearray(n_px)   # disque + intérieurs du dessin -> transparent
    cur = 0
    for s in range(n_px):
        if white[s] and not lab[s]:
            cur += 1
            q = deque([s]); lab[s] = cur
            pixels = [s]; sx = sy = 0
            while q:
                i = q.popleft(); x, y = i % w, i // w; sx += x; sy += y
                for nb, ok in ((i - 1, x > 0), (i + 1, x < w - 1),
                               (i - w, y > 0), (i + w, y < h - 1)):
                    if ok and white[nb] and not lab[nb]:
                        lab[nb] = cur; q.append(nb); pixels.append(nb)
            n = len(pixels); cx, cy = sx / n, sy / n
            is_glyph = (n >= MIN_GLYPH
                        and (math.hypot(cx - CX, cy - CY) > R_IN
                             or cy > RIBBON_TOP))
            target = glyph if is_glyph else open_
            for i in pixels:
                target[i] = 1

    # Les pixels d'anti-crénelage voisins d'une zone vidée doivent se fondre vers
    # la transparence ; ceux qui bordent un glyphe restent sur la plaque opaque.
    near_open = bytearray(open_)
    for _ in range(3):
        nxt = bytearray(near_open)
        for i in range(n_px):
            if near_open[i]:
                x, y = i % w, i // w
                if x > 0: nxt[i - 1] = 1
                if x < w - 1: nxt[i + 1] = 1
                if y > 0: nxt[i - w] = 1
                if y < h - 1: nxt[i + w] = 1
        near_open = nxt

    out = bytearray(n_px * 4)
    for i in range(n_px):
        j = i * 4
        a = b[j + 3]
        if a == 0:
            continue
        # « encrage » : 0 = papier blanc, 1 = indigo plein.
        t = (255 - b[j]) / (255 - INK[0])
        t = 0.0 if t < 0 else (1.0 if t > 1 else t)
        if glyph[i]:
            out[j:j + 4] = bytes((*BLUE, a))
        elif open_[i]:
            pass                                  # vidé
        elif near_open[i]:
            out[j:j + 4] = bytes((255, 255, 255, round(a * t)))
        else:
            # plaque opaque : du bleu (papier, donc glyphe) vers le blanc
            out[j:j + 4] = bytes((
                round(BLUE[0] + (255 - BLUE[0]) * t),
                round(BLUE[1] + (255 - BLUE[1]) * t),
                round(BLUE[2] + (255 - BLUE[2]) * t),
                a,
            ))

    _png.write_rgba(DST, w, h, out)
    print('écrit', DST)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
