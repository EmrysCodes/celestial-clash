#!/usr/bin/env python3
"""Build hero animation sheets from idle + walk + attack masters."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SRC = Path("/opt/cursor/artifacts/assets")
ISO = Path("/workspace/assets/sprites/source_iso")
OUT = Path("/workspace/assets/sprites")
HEROES = OUT / "heroes"
FX = OUT / "fx"


def remove_bg(img: Image.Image, tol: int = 40) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    corners = [px[2, 2], px[w - 3, 2], px[2, h - 3], px[w - 3, h - 3],
               px[w // 2, 2], px[w // 2, h - 3]]
    def is_bg(c):
        for bc in corners:
            if abs(c[0] - bc[0]) <= tol and abs(c[1] - bc[1]) <= tol and abs(c[2] - bc[2]) <= tol:
                b = (bc[0] + bc[1] + bc[2]) / 3
                s = (c[0] + c[1] + c[2]) / 3
                if b > 190 or b < 45:
                    return abs(s - b) < tol + 12
                return True
        return False
    visited = set()
    stack = []
    for x in range(w):
        stack += [(x, 0), (x, h - 1)]
    for y in range(h):
        stack += [(0, y), (w - 1, y)]
    while stack:
        x, y = stack.pop()
        if (x, y) in visited or x < 0 or y < 0 or x >= w or y >= h:
            continue
        visited.add((x, y))
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    a = img.split()[-1].filter(ImageFilter.MinFilter(3))
    img.putalpha(a)
    return img


def fit(img: Image.Image, size: int = 128) -> Image.Image:
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    scale = min((size - 10) / img.width, (size - 10) / img.height)
    nw, nh = max(1, int(img.width * scale)), max(1, int(img.height * scale))
    img = img.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - nw) // 2, size - nh - 2), img)
    return canvas


def load_pose(path: Path) -> Image.Image:
    return fit(remove_bg(Image.open(path)))


def tween(a: Image.Image, b: Image.Image, t: float) -> Image.Image:
    return Image.blend(a, b, t)


def micro_bob(img: Image.Image, frame: int) -> Image.Image:
    dy = int(math.sin(frame / 4.0 * math.tau) * 2)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, dy), img)
    return out


def build_hero(name: str) -> None:
    HEROES.mkdir(parents=True, exist_ok=True)
    idle = load_pose(ISO / f"hero_{name}_iso.png")
    walk = load_pose(SRC / f"{name}_walk.jpg")
    attack = load_pose(SRC / f"{name}_attack.jpg")
    idle.save(OUT / f"hero_{name}.png")

    # Also stash walk/attack masters
    walk.save(ISO / f"hero_{name}_walk.png")
    attack.save(ISO / f"hero_{name}_attack.png")

    sheet = Image.new("RGBA", (128 * 4, 128 * 3), (0, 0, 0, 0))
    # idle row — bob on idle master
    for i in range(4):
        sheet.paste(micro_bob(idle, i), (i * 128, 0), micro_bob(idle, i))
    # walk row — blend idle↔walk↔idle for cycle
    walk_frames = [
        tween(idle, walk, 0.35),
        walk,
        tween(idle, walk, 0.65),
        tween(idle, walk, 0.25),
    ]
    for i, fr in enumerate(walk_frames):
        fr = micro_bob(fr, i + 1)
        sheet.paste(fr, (i * 128, 128), fr)
    # attack row
    atk_frames = [
        tween(idle, attack, 0.25),
        tween(idle, attack, 0.7),
        attack,
        tween(idle, attack, 0.4),
    ]
    for i, fr in enumerate(atk_frames):
        sheet.paste(fr, (i * 128, 256), fr)
    sheet.save(HEROES / f"{name}_sheet.png")
    print("sheet", name)


def make_particle_textures() -> None:
    FX.mkdir(parents=True, exist_ok=True)
    # soft circle particle
    for name, col in [
        ("particle_soft.png", (255, 255, 255, 255)),
        ("particle_holy.png", (255, 240, 160, 255)),
        ("particle_fire.png", (255, 120, 40, 255)),
        ("particle_water.png", (100, 180, 255, 255)),
        ("particle_nature.png", (120, 220, 90, 255)),
        ("particle_spark.png", (255, 220, 100, 255)),
    ]:
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([2, 2, 29, 29], fill=col)
        img = img.filter(ImageFilter.GaussianBlur(3))
        # restore core
        core = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        ImageDraw.Draw(core).ellipse([10, 10, 21, 21], fill=col)
        img = Image.alpha_composite(img, core)
        img.save(FX / name)
    print("particles")


def main() -> None:
    for h in ("seraph", "ashwalker", "tidebound", "thornwight"):
        build_hero(h)
    make_particle_textures()
    print("Done.")


if __name__ == "__main__":
    main()
