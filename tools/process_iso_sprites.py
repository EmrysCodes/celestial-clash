#!/usr/bin/env python3
"""Convert generated isometric character JPGs into transparent PNG sheets for Godot."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

SRC = Path("/opt/cursor/artifacts/assets")
OUT = Path("/workspace/assets/sprites")
HEROES = OUT / "heroes"
CREEPS = OUT / "creeps"


def remove_bg(img: Image.Image, tol: int = 38) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    # sample corner colors (studio backdrop)
    corners = [px[2, 2], px[w - 3, 2], px[2, h - 3], px[w - 3, h - 3]]
    # also sample edges midpoints
    corners += [px[w // 2, 2], px[w // 2, h - 3], px[2, h // 2], px[w - 3, h // 2]]

    def is_bg(c):
        for bc in corners:
            if abs(c[0] - bc[0]) <= tol and abs(c[1] - bc[1]) <= tol and abs(c[2] - bc[2]) <= tol:
                # avoid nuking pale armor: require fairly bright OR very dark uniform backdrop
                brightness = (bc[0] + bc[1] + bc[2]) / 3
                sample_b = (c[0] + c[1] + c[2]) / 3
                if brightness > 200 or brightness < 40:
                    return abs(sample_b - brightness) < tol + 10
                return True
        return False

    # flood from edges
    visited = [[False] * h for _ in range(w)]
    stack = []
    for x in range(w):
        stack.append((x, 0))
        stack.append((x, h - 1))
    for y in range(h):
        stack.append((0, y))
        stack.append((w - 1, y))
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or visited[x][y]:
            continue
        visited[x][y] = True
        c = px[x, y]
        if not is_bg(c):
            continue
        px[x, y] = (0, 0, 0, 0)
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

    # soften leftover fringe
    alpha = img.split()[-1]
    alpha = alpha.filter(ImageFilter.MinFilter(3))
    img.putalpha(alpha)
    return img


def autocrop(img: Image.Image, pad: int = 8) -> Image.Image:
    bbox = img.getbbox()
    if not bbox:
        return img
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(img.width, x1 + pad)
    y1 = min(img.height, y1 + pad)
    return img.crop((x0, y0, x1, y1))


def fit_square(img: Image.Image, size: int) -> Image.Image:
    img = autocrop(img)
    # scale to fit
    scale = min((size - 8) / img.width, (size - 8) / img.height)
    nw = max(1, int(img.width * scale))
    nh = max(1, int(img.height * scale))
    img = img.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - nw) // 2, size - nh - 4), img)  # feet near bottom
    return canvas


def anim_variant(base: Image.Image, anim: str, frame: int) -> Image.Image:
    """Cheap but readable idle/walk/attack variants from one master pose."""
    img = base.copy()
    t = frame / 4.0 * math.tau
    if anim == "idle":
        dy = int(math.sin(t) * 2)
        out = Image.new("RGBA", img.size, (0, 0, 0, 0))
        out.paste(img, (0, dy), img)
        return out
    if anim == "walk":
        dy = int(math.sin(t) * 3)
        dx = int(math.cos(t) * 1)
        # slight squash
        squash = 1.0 - abs(math.sin(t)) * 0.03
        nh = max(1, int(img.height * squash))
        scaled = img.resize((img.width, nh), Image.LANCZOS)
        out = Image.new("RGBA", img.size, (0, 0, 0, 0))
        out.paste(scaled, (dx, img.height - nh + dy), scaled)
        return out
    # attack — lean / stretch toward SE
    keys = [0.0, 0.55, 1.0, 0.35]
    k = keys[frame % 4]
    # shift right-up a bit and add orange/white flash on later frames
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (int(k * 6), -int(k * 4)), img)
    if k > 0.5:
        flash = Image.new("RGBA", img.size, (0, 0, 0, 0))
        # soft highlight blob near weapon hand (upper-right of character)
        from PIL import ImageDraw

        d = ImageDraw.Draw(flash)
        cx, cy = int(img.width * 0.72), int(img.height * 0.35)
        r = int(10 + k * 14)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 230, 140, int(90 * k)))
        flash = flash.filter(ImageFilter.GaussianBlur(3))
        out = Image.alpha_composite(out, flash)
    return out


def make_hero_sheet(name: str, src_name: str) -> None:
    HEROES.mkdir(parents=True, exist_ok=True)
    src = Image.open(SRC / src_name)
    cut = remove_bg(src, tol=42)
    master = fit_square(cut, 128)
    master.save(OUT / f"hero_{name}.png")

    sheet = Image.new("RGBA", (128 * 4, 128 * 3), (0, 0, 0, 0))
    for row, anim in enumerate(("idle", "walk", "attack")):
        for col in range(4):
            fr = anim_variant(master, anim, col)
            sheet.paste(fr, (col * 128, row * 128), fr)
    sheet.save(HEROES / f"{name}_sheet.png")
    print("hero", name, master.size)


def make_creep_sheet(kind: str, src_name: str) -> None:
    CREEPS.mkdir(parents=True, exist_ok=True)
    src = Image.open(SRC / src_name)
    cut = remove_bg(src, tol=45)
    master = fit_square(cut, 80)
    name = {"light": "creep_light", "dark": "creep_dark", "elite": "creep_elite"}[kind]
    master.save(OUT / f"{name}.png")

    sheet = Image.new("RGBA", (80 * 4, 80 * 2), (0, 0, 0, 0))
    for row, anim in enumerate(("idle", "walk")):
        for col in range(4):
            fr = anim_variant(master, anim, col)
            # resize variant back if needed
            if fr.size != (80, 80):
                fr = fr.resize((80, 80), Image.LANCZOS)
            sheet.paste(fr, (col * 80, row * 80), fr)
    sheet.save(CREEPS / f"{kind}_sheet.png")
    print("creep", kind, master.size)


def main() -> None:
    make_hero_sheet("seraph", "hero_seraph_iso.jpg")
    make_hero_sheet("ashwalker", "hero_ashwalker_iso.jpg")
    make_hero_sheet("tidebound", "hero_tidebound_iso.jpg")
    make_hero_sheet("thornwight", "hero_thornwight_iso.jpg")
    make_creep_sheet("light", "creep_light_iso.jpg")
    make_creep_sheet("dark", "creep_dark_iso.jpg")
    make_creep_sheet("elite", "creep_elite_iso.jpg")
    # copy masters into project assets for regenerators
    archive = OUT / "source_iso"
    archive.mkdir(parents=True, exist_ok=True)
    for p in SRC.glob("*_iso.jpg"):
        Image.open(p).save(archive / (p.stem + ".png"))
    print("Done.")


if __name__ == "__main__":
    main()
