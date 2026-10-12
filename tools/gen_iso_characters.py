#!/usr/bin/env python3
"""
Isometric 2.5D character sprites — WC3 Angel Arena inspired.
3/4 camera, volumetric plates, readable silhouettes (wings, weapons, auras).
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = Path("/workspace/assets/sprites")
HEROES = ROOT / "heroes"
CREEPS = ROOT / "creeps"


def blank(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def C(rgb, f=1.0, a=255):
    return tuple(max(0, min(255, int(c * f))) for c in rgb[:3]) + (a,)


def composite(base, layer):
    return Image.alpha_composite(base, layer)


def soft(img, box, fill, blur=1.0):
    layer = blank(*img.size)
    ImageDraw.Draw(layer).ellipse(box, fill=fill)
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return composite(img, layer)


def oval(img, cx, cy, rx, ry, color, hi=1.15, lo=0.55):
    """Shaded ellipsoid — light from upper-left (isometric key light)."""
    layer = blank(*img.size)
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=C(color, lo))
    d.ellipse([cx - rx * 0.88, cy - ry * 0.88, cx + rx * 0.72, cy + ry * 0.72], fill=C(color, 0.88))
    d.ellipse(
        [cx - rx * 0.55 - rx * 0.2, cy - ry * 0.55 - ry * 0.25, cx + rx * 0.25, cy + ry * 0.15],
        fill=C(color, hi, 210),
    )
    d.arc([cx - rx, cy - ry, cx + rx, cy + ry], 210, 330, fill=C(color, hi + 0.15, 140), width=2)
    return composite(img, layer)


def poly(img, pts, color, outline=None):
    layer = blank(*img.size)
    d = ImageDraw.Draw(layer)
    d.polygon(pts, fill=C(color, 1.0), outline=outline)
    return composite(img, layer)


def limb(img, x0, y0, x1, y1, r, color):
    layer = blank(*img.size)
    d = ImageDraw.Draw(layer)
    d.line([(x0, y0), (x1, y1)], fill=C(color, 0.65), width=int(r * 2.2))
    d.line([(x0, y0), (x1, y1)], fill=C(color, 1.0), width=max(2, int(r * 1.35)))
    for x, y in ((x0, y0), (x1, y1)):
        d.ellipse([x - r, y - r, x + r, y + r], fill=C(color, 0.95))
        d.ellipse([x - r * 0.45, y - r * 0.55, x + r * 0.2, y + r * 0.15], fill=C(color, 1.2, 160))
    return composite(img, layer)


def plate(img, pts, color):
    """Armor plate with edge highlight."""
    layer = blank(*img.size)
    d = ImageDraw.Draw(layer)
    d.polygon(pts, fill=C(color, 0.75))
    # inset highlight along top-left edges
    if len(pts) >= 3:
        d.line([pts[0], pts[1]], fill=C(color, 1.25, 200), width=2)
        d.line([pts[0], pts[-1]], fill=C(color, 1.1, 160), width=1)
    d.polygon(pts, outline=C(color, 0.4, 200))
    return composite(img, layer)


def shadow(img, cx, cy, rx=26, ry=9):
    return soft(img, [cx - rx, cy - ry, cx + rx, cy + ry], (0, 0, 0, 100), 2.0)


def pose(anim, frame):
    t = frame / 4.0 * math.tau
    bob = math.sin(t) * (1.4 if anim == "idle" else 2.8 if anim == "walk" else 0.6)
    stride = math.sin(t) * (0 if anim != "walk" else 7)
    arm = math.sin(t) * (2.5 if anim == "idle" else 9 if anim == "walk" else 0)
    atk = 0.0
    if anim == "attack":
        atk = [0.05, 0.75, 1.0, 0.4][frame % 4]
        bob = -atk * 3
    return bob, stride, arm, atk


def angel_wings(img, cx, cy, span=1.0, fold=0.0, tint=(255, 245, 220)):
    # layered feather plates — isometric, left back / right forward
    L = [
        (cx - 6, cy),
        (cx - 20 * span, cy - 22 * span + fold * 8),
        (cx - 36 * span, cy - 8),
        (cx - 30 * span, cy + 14),
        (cx - 14, cy + 10),
    ]
    R = [
        (cx + 8, cy - 2),
        (cx + 26 * span, cy - 26 * span + fold * 8),
        (cx + 40 * span, cy - 6),
        (cx + 32 * span, cy + 16),
        (cx + 12, cy + 10),
    ]
    img = poly(img, L, C(tint, 0.55))
    img = poly(img, R, C(tint, 0.78))
    # inner feathers
    img = poly(
        img,
        [(cx - 4, cy + 2), (cx - 16 * span, cy - 10), (cx - 22 * span, cy + 6), (cx - 8, cy + 8)],
        C(tint, 0.9),
    )
    img = poly(
        img,
        [(cx + 6, cy), (cx + 18 * span, cy - 12), (cx + 24 * span, cy + 8), (cx + 10, cy + 8)],
        C(tint, 1.05),
    )
    return img


def demon_wings(img, cx, cy, span=1.0, fold=0.0):
    tint = (75, 40, 95)
    L = [
        (cx - 4, cy),
        (cx - 18 * span, cy - 24 * span + fold * 5),
        (cx - 38 * span, cy - 4),
        (cx - 28 * span, cy + 16),
        (cx - 10, cy + 8),
    ]
    R = [
        (cx + 6, cy - 2),
        (cx + 22 * span, cy - 28 * span + fold * 5),
        (cx + 42 * span, cy - 2),
        (cx + 30 * span, cy + 18),
        (cx + 12, cy + 8),
    ]
    img = poly(img, L, C(tint, 0.7))
    img = poly(img, R, C(tint, 0.95))
    # bone ridges
    d = ImageDraw.Draw(img)
    d.line([L[0], L[1], L[2]], fill=C((40, 20, 50), 1.2), width=2)
    d.line([R[0], R[1], R[2]], fill=C((50, 25, 60), 1.2), width=2)
    return img


def face(img, cx, cy, skin, eye=(30, 35, 55), brow=None):
    img = oval(img, cx, cy, 11, 12, skin, hi=1.2, lo=0.6)
    d = ImageDraw.Draw(img)
    # eye whites / iris
    d.ellipse([cx - 5, cy - 3, cx - 1, cy + 1], fill=(250, 250, 255, 230))
    d.ellipse([cx + 2, cy - 3, cx + 6, cy + 1], fill=(250, 250, 255, 230))
    d.ellipse([cx - 4, cy - 2, cx - 2, cy], fill=eye + (255,))
    d.ellipse([cx + 3, cy - 2, cx + 5, cy], fill=eye + (255,))
    if brow:
        d.arc([cx - 8, cy - 8, cx + 8, cy + 2], 200, 340, fill=C(brow, 0.8), width=2)
    return img


# -------------------- heroes --------------------

def draw_seraph(size, anim, frame):
    img = blank(size, size)
    cx, foot = size // 2, int(size * 0.78)
    bob, stride, arm, atk = pose(anim, frame)
    cy = foot + bob
    gold = (210, 170, 55)
    cloth = (240, 232, 215)
    skin = (250, 230, 210)
    wing = (255, 250, 230)

    img = shadow(img, cx, cy + 4)
    img = angel_wings(img, cx, cy - 28, span=1.1, fold=atk * 0.25, tint=wing)

    # legs isometric
    img = limb(img, cx - 7, cy - 6, cx - 12 + stride * 0.4, cy + 18, 5.5, C(cloth, 0.85)[:3])
    img = limb(img, cx + 6, cy - 6, cx + 12 - stride * 0.4, cy + 18, 5.5, cloth)
    img = oval(img, cx - 12 + stride * 0.4, cy + 20, 8, 4.5, gold)
    img = oval(img, cx + 12 - stride * 0.4, cy + 20, 8, 4.5, gold)

    # skirt / tabard
    img = plate(
        img,
        [(cx - 16, cy - 8), (cx + 16, cy - 10), (cx + 14, cy + 10), (cx - 14, cy + 12)],
        C(cloth, 0.9)[:3],
    )

    # torso armor
    img = oval(img, cx, cy - 22, 16, 18, cloth, hi=1.12, lo=0.6)
    img = plate(
        img,
        [(cx - 12, cy - 34), (cx + 12, cy - 36), (cx + 14, cy - 12), (cx - 14, cy - 10)],
        gold,
    )
    img = oval(img, cx, cy - 22, 5, 5, (255, 235, 120))

    # pauldrons
    img = oval(img, cx - 16, cy - 28, 8, 6, gold)
    img = oval(img, cx + 16, cy - 30, 8, 6, gold)

    # back arm
    img = limb(img, cx - 14, cy - 24, cx - 24 - arm, cy - 6, 5, skin)

    # head + hair
    img = soft(img, [cx - 12, cy - 58, cx + 14, cy - 40], C((255, 248, 230), 0.95, 230), 0.6)
    img = face(img, cx + 1, cy - 46, skin, eye=(50, 70, 120))
    d = ImageDraw.Draw(img)
    d.arc([cx - 14, cy - 64, cx + 16, cy - 46], 200, 340, fill=C(gold, 1.1), width=3)

    # staff arm + holy orb
    sx = cx + 20 + atk * 22
    sy = cy - 40 - atk * 14
    img = limb(img, cx + 14, cy - 24, sx - 4, sy + 10, 5, skin)
    img = limb(img, sx - 2, sy + 28, sx, sy - 8, 3, gold)
    img = oval(img, sx, sy - 12, 7 + atk * 4, 7 + atk * 4, (255, 245, 170), hi=1.3)
    if atk > 0.45:
        img = soft(img, [sx - 18, sy - 28, sx + 18, sy - 2], (255, 240, 150, 110), 3)
    return img


def draw_ashwalker(size, anim, frame):
    img = blank(size, size)
    cx, foot = size // 2, int(size * 0.78)
    bob, stride, arm, atk = pose(anim, frame)
    cy = foot + bob
    body = (50, 35, 70)
    skin = (95, 55, 100)
    fire = (255, 110, 35)
    dark = (30, 20, 40)

    img = shadow(img, cx, cy + 4)
    img = demon_wings(img, cx, cy - 26, span=1.2, fold=-atk * 0.15)

    img = limb(img, cx - 6, cy - 4, cx - 11 + stride * 0.45, cy + 18, 6, dark)
    img = limb(img, cx + 6, cy - 4, cx + 12 - stride * 0.45, cy + 18, 6, body)
    img = oval(img, cx - 11 + stride * 0.45, cy + 20, 8, 4.5, dark)
    img = oval(img, cx + 12 - stride * 0.45, cy + 20, 8, 4.5, dark)

    img = oval(img, cx, cy - 20, 17, 19, body, hi=1.1, lo=0.5)
    img = plate(
        img,
        [(cx - 10, cy - 32), (cx + 10, cy - 34), (cx + 12, cy - 10), (cx - 12, cy - 8)],
        C(dark, 1.1)[:3],
    )
    img = oval(img, cx, cy - 18, 7, 7, fire, hi=1.35)
    img = soft(img, [cx - 10, cy - 26, cx + 10, cy - 10], (255, 120, 40, 70), 2)

    # horns
    img = poly(img, [(cx - 6, cy - 40), (cx - 18, cy - 58), (cx - 2, cy - 44)], dark)
    img = poly(img, [(cx + 8, cy - 42), (cx + 20, cy - 60), (cx + 4, cy - 44)], C(dark, 1.15)[:3])

    img = limb(img, cx - 14, cy - 22, cx - 24 - arm, cy - 2, 5.5, skin)
    img = face(img, cx + 2, cy - 44, skin, eye=(255, 160, 50), brow=dark)

    bx = cx + 18 + atk * 24
    by = cy - 32 - atk * 10
    img = limb(img, cx + 12, cy - 22, bx, by, 5.5, skin)
    # flame blade
    img = limb(img, bx, by, bx + 14 + atk * 8, by - 22 - atk * 6, 3.5, fire)
    img = oval(img, bx + 14 + atk * 8, by - 24 - atk * 6, 5, 5, (255, 200, 80))
    if atk > 0.4:
        img = soft(img, [bx, by - 28, bx + 36, by + 6], (255, 90, 30, 120), 2.5)
    return img


def draw_tidebound(size, anim, frame):
    img = blank(size, size)
    cx, foot = size // 2, int(size * 0.78)
    bob, stride, arm, atk = pose(anim, frame)
    cy = foot + bob
    robe = (35, 75, 140)
    deep = (25, 50, 100)
    foam = (150, 210, 255)
    skin = (210, 225, 240)

    img = shadow(img, cx, cy + 4)
    # robe train
    img = soft(img, [cx - 22, cy - 6, cx + 24, cy + 20], C(deep, 0.9, 200), 1.5)
    img = plate(
        img,
        [(cx - 18, cy - 10), (cx + 18, cy - 12), (cx + 20, cy + 14), (cx - 20, cy + 16)],
        robe,
    )

    img = limb(img, cx - 5, cy - 2, cx - 8 + stride * 0.25, cy + 14, 4.5, deep)
    img = limb(img, cx + 5, cy - 2, cx + 9 - stride * 0.25, cy + 14, 4.5, robe)

    img = oval(img, cx, cy - 22, 15, 20, robe, hi=1.1, lo=0.55)
    img = oval(img, cx, cy - 18, 8, 9, foam, hi=1.25)

    # hood
    img = poly(
        img,
        [(cx - 14, cy - 36), (cx + 14, cy - 38), (cx + 16, cy - 22), (cx - 16, cy - 20)],
        deep,
    )
    img = face(img, cx + 1, cy - 42, skin, eye=(20, 50, 100))

    img = limb(img, cx - 12, cy - 24, cx - 20 - arm, cy - 6, 4.5, skin)
    sx = cx + 18 + atk * 16
    sy = cy - 38 - atk * 14
    img = limb(img, cx + 12, cy - 24, sx, sy + 8, 4.5, skin)
    img = limb(img, sx, sy + 22, sx, sy - 10, 2.8, foam)
    img = oval(img, sx, sy - 14, 9 + atk * 5, 9 + atk * 5, foam, hi=1.35)
    if atk > 0.5:
        img = soft(img, [sx - 20, sy - 30, sx + 20, sy], (80, 170, 255, 120), 3)
    return img


def draw_thornwight(size, anim, frame):
    img = blank(size, size)
    cx, foot = size // 2, int(size * 0.78)
    bob, stride, arm, atk = pose(anim, frame)
    cy = foot + bob
    bark = (50, 85, 42)
    moss = (35, 65, 32)
    leaf = (85, 165, 65)
    wood = (100, 65, 30)

    img = shadow(img, cx, cy + 4)
    # canopy
    img = soft(img, [cx - 28, cy - 48, cx - 4, cy - 22], C(leaf, 0.85, 210), 1.2)
    img = soft(img, [cx + 6, cy - 50, cx + 30, cy - 24], C(leaf, 1.0, 210), 1.2)

    img = limb(img, cx - 7, cy - 4, cx - 12 + stride * 0.4, cy + 18, 6.5, moss)
    img = limb(img, cx + 7, cy - 4, cx + 13 - stride * 0.4, cy + 18, 6.5, bark)
    img = oval(img, cx - 12 + stride * 0.4, cy + 20, 9, 5, wood)
    img = oval(img, cx + 13 - stride * 0.4, cy + 20, 9, 5, wood)

    img = oval(img, cx, cy - 20, 18, 20, bark, hi=1.08, lo=0.5)
    img = plate(
        img,
        [(cx - 14, cy - 34), (cx + 12, cy - 36), (cx + 16, cy - 8), (cx - 16, cy - 6)],
        moss,
    )
    # vine wrap
    d = ImageDraw.Draw(img)
    d.arc([cx - 14, cy - 28, cx + 14, cy - 4], 30, 150, fill=C(leaf, 1.1), width=3)

    img = limb(img, cx - 14, cy - 22, cx - 24 - arm, cy + 2, 6, bark)
    img = face(img, cx + 1, cy - 44, C(bark, 1.15)[:3], eye=(20, 40, 15), brow=moss)
    d.ellipse([cx - 10, cy - 56, cx + 12, cy - 42], outline=C(leaf, 1.1), width=3)

    bx = cx + 16 + atk * 18
    by = cy - 28 - atk * 8
    img = limb(img, cx + 12, cy - 20, bx, by, 6, bark)
    img = oval(img, bx + 6 + atk * 4, by - 2, 11 + atk * 3, 9, wood, hi=1.1)
    if atk > 0.5:
        img = soft(img, [bx - 6, by - 10, bx + 28, by + 16], (100, 200, 70, 100), 2.5)
    return img


HERO_DRAW = {
    "seraph": draw_seraph,
    "ashwalker": draw_ashwalker,
    "tidebound": draw_tidebound,
    "thornwight": draw_thornwight,
}


def draw_creep(kind, size, anim, frame):
    img = blank(size, size)
    cx, foot = size // 2, int(size * 0.72)
    bob, stride, _, _ = pose("walk" if anim == "attack" else anim, frame)
    cy = foot + bob * 0.6
    img = shadow(img, cx, cy + 2, rx=16, ry=6)

    if kind == "light":
        fur = (185, 175, 145)
        img = oval(img, cx - 7 + stride * 0.2, cy + 8, 6, 3.5, C(fur, 0.7)[:3])
        img = oval(img, cx + 8 - stride * 0.2, cy + 8, 6, 3.5, C(fur, 0.85)[:3])
        img = oval(img, cx, cy - 2, 14, 12, fur)
        img = oval(img, cx + 10, cy - 10, 9, 8, fur, hi=1.15)
        d = ImageDraw.Draw(img)
        d.ellipse([cx + 12, cy - 12, cx + 15, cy - 9], fill=(25, 25, 35, 255))
        img = poly(img, [(cx - 2, cy - 12), (cx - 8, cy - 24), (cx + 2, cy - 12)], C(fur, 0.65)[:3])
        img = poly(img, [(cx + 6, cy - 12), (cx + 4, cy - 24), (cx + 12, cy - 12)], C(fur, 0.75)[:3])
    elif kind == "dark":
        body = (75, 40, 55)
        img = oval(img, cx - 6, cy + 8, 6, 3.5, C(body, 0.55)[:3])
        img = oval(img, cx + 7, cy + 8, 6, 3.5, C(body, 0.7)[:3])
        img = oval(img, cx, cy - 2, 13, 13, body)
        img = oval(img, cx + 3, cy - 14, 9, 9, C(body, 1.1)[:3])
        d = ImageDraw.Draw(img)
        d.ellipse([cx + 1, cy - 16, cx + 4, cy - 13], fill=(255, 70, 70, 255))
        d.ellipse([cx + 6, cy - 16, cx + 9, cy - 13], fill=(255, 70, 70, 255))
        img = poly(img, [(cx - 4, cy - 18), (cx - 12, cy - 30), (cx + 2, cy - 18)], C(body, 0.5)[:3])
        img = poly(img, [(cx + 8, cy - 18), (cx + 14, cy - 30), (cx + 2, cy - 18)], C(body, 0.55)[:3])
    else:
        body = (48, 42, 78)
        gold = (215, 175, 55)
        img = oval(img, cx - 8, cy + 10, 7, 4, C(body, 0.5)[:3])
        img = oval(img, cx + 9, cy + 10, 7, 4, C(body, 0.65)[:3])
        img = oval(img, cx, cy, 17, 15, body, hi=1.08)
        img = plate(
            img,
            [(cx - 10, cy - 10), (cx + 10, cy - 12), (cx + 12, cy + 6), (cx - 12, cy + 8)],
            gold,
        )
        img = oval(img, cx + 2, cy - 16, 11, 11, C(body, 1.05)[:3])
        d = ImageDraw.Draw(img)
        d.ellipse([cx, cy - 18, cx + 3, cy - 15], fill=(255, 220, 80, 255))
        d.ellipse([cx + 5, cy - 18, cx + 8, cy - 15], fill=(255, 220, 80, 255))
        for dx in (-10, 0, 10):
            img = poly(img, [(cx + dx, cy - 24), (cx + dx - 4, cy - 36), (cx + dx + 4, cy - 24)], gold)
    return img


def sheet_hero(hid):
    HEROES.mkdir(parents=True, exist_ok=True)
    fw = fh = 128
    sheet = blank(fw * 4, fh * 3)
    draw = HERO_DRAW[hid]
    for row, anim in enumerate(("idle", "walk", "attack")):
        for col in range(4):
            fr = draw(fw, anim, col)
            sheet.paste(fr, (col * fw, row * fh), fr)
    sheet.save(HEROES / f"{hid}_sheet.png")
    idle = draw(128, "idle", 0)
    # slightly sharpen for crisp silhouette
    idle = ImageEnhance.Sharpness(idle).enhance(1.15)
    idle.save(ROOT / f"hero_{hid}.png")
    print("  hero", hid)


def sheet_creep(kind):
    CREEPS.mkdir(parents=True, exist_ok=True)
    fw = fh = 80
    sheet = blank(fw * 4, fh * 2)
    for row, anim in enumerate(("idle", "walk")):
        for col in range(4):
            fr = draw_creep(kind, fw, anim, col)
            sheet.paste(fr, (col * fw, row * fh), fr)
    sheet.save(CREEPS / f"{kind}_sheet.png")
    idle = draw_creep(kind, 80, "idle", 0)
    name = {"light": "creep_light", "dark": "creep_dark", "elite": "creep_elite"}[kind]
    idle.save(ROOT / f"{name}.png")
    print("  creep", kind)


def main():
    print("Generating WC3-style isometric 2.5D characters…")
    for h in HERO_DRAW:
        sheet_hero(h)
    for c in ("light", "dark", "elite"):
        sheet_creep(c)
    print("Done.")


if __name__ == "__main__":
    main()
