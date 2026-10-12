#!/usr/bin/env python3
"""Generate original Seraph Arena art kit (spritesheets, FX, icons, WC3-mobile HUD)."""
from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/workspace/assets")
SPR = ROOT / "sprites"
UI = ROOT / "ui"


def ensure(p: Path) -> Path:
    p.mkdir(parents=True, exist_ok=True)
    return p


def blank(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def circle(draw: ImageDraw.ImageDraw, c: tuple, r: float, fill, outline=None, width=1):
    x, y = c
    box = [x - r, y - r, x + r, y + r]
    draw.ellipse(box, fill=fill, outline=outline, width=width)


def soft_blob(img: Image.Image, c, r, color, blur=1.2):
    layer = blank(*img.size)
    d = ImageDraw.Draw(layer)
    circle(d, c, r, color)
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(img, layer)


def shade(rgb, f):
    return tuple(max(0, min(255, int(c * f))) for c in rgb) + (255,)


def with_a(rgb, a=255):
    if len(rgb) == 4:
        return rgb
    return rgb + (a,)


# ---------- unit body drawing ----------

def draw_unit_frame(palette: dict, pose: str, facing: float = 0.0, frame_i: int = 0) -> Image.Image:
    """64x64 top-down stylized hero/creep frame."""
    img = blank(64, 64)
    cx, cy = 32, 34
    bob = math.sin(frame_i * 1.2) * (1.5 if pose == "walk" else 0.4)
    cy += bob
    swing = math.sin(frame_i * 1.4) * (6 if pose == "walk" else 0)
    atk = 1.0 if pose == "attack" else 0.0

    # shadow
    img = soft_blob(img, (cx, cy + 14), 14, (0, 0, 0, 70), 2.0)

    body = palette["body"]
    accent = palette["accent"]
    glow = palette.get("glow", accent)
    dark = shade(body[:3], 0.55)
    mid = shade(body[:3], 0.85)

    d = ImageDraw.Draw(img)

    # legs / base disc
    circle(d, (cx - 6 + swing * 0.3, cy + 10), 5.5, dark)
    circle(d, (cx + 6 - swing * 0.3, cy + 10), 5.5, dark)

    # torso
    circle(d, (cx, cy), 13, mid)
    circle(d, (cx, cy - 2), 11, body)
    # chest accent
    circle(d, (cx, cy - 1), 5, with_a(accent[:3], 200))

    # shoulders / arms
    arm_out = 12 + atk * 8
    circle(d, (cx - arm_out, cy + 1 + swing * 0.2), 5, mid)
    circle(d, (cx + arm_out, cy + 1 - swing * 0.2), 5, mid)

    # weapon / staff cue
    wx = cx + 16 + atk * 10
    wy = cy - 4 - atk * 6
    d.line([(cx + 8, cy), (wx, wy)], fill=with_a(glow[:3], 230), width=3)
    circle(d, (wx, wy), 3.5, with_a(glow[:3], 255))

    # head
    circle(d, (cx, cy - 14), 8, shade(body[:3], 1.05))
    circle(d, (cx, cy - 15), 6, (245, 230, 210, 255) if palette.get("humanoid", True) else accent)
    # eyes
    eye_y = cy - 15
    circle(d, (cx - 2.5, eye_y), 1.4, (20, 20, 30, 255))
    circle(d, (cx + 2.5, eye_y), 1.4, (20, 20, 30, 255))

    # halo / horns / crest
    crest = palette.get("crest", "halo")
    if crest == "halo":
        d.arc([cx - 12, cy - 28, cx + 12, cy - 10], 200, 340, fill=with_a(glow[:3], 220), width=2)
    elif crest == "horns":
        d.polygon([(cx - 8, cy - 18), (cx - 14, cy - 28), (cx - 4, cy - 20)], fill=dark)
        d.polygon([(cx + 8, cy - 18), (cx + 14, cy - 28), (cx + 4, cy - 20)], fill=dark)
    elif crest == "wave":
        d.arc([cx - 10, cy - 26, cx + 10, cy - 12], 180, 360, fill=with_a(accent[:3], 230), width=3)
    elif crest == "leaves":
        d.ellipse([cx - 10, cy - 26, cx - 2, cy - 16], fill=accent)
        d.ellipse([cx + 2, cy - 26, cx + 10, cy - 16], fill=accent)

    # attack flash
    if pose == "attack":
        img = soft_blob(img, (wx + 4, wy - 2), 8, with_a(glow[:3], 120), 1.5)

    return img


def make_hero_sheet(name: str, palette: dict) -> None:
    ensure(SPR / "heroes")
    # 4 dirs x 4 frames: idle(1) walk(4) attack(3) — pack as 12 frames horizontal for simplicity
    # Layout: row0 idle x4 slight, row1 walk x4, row2 attack x4
    fw, fh = 64, 64
    cols, rows = 4, 3
    sheet = blank(fw * cols, fh * rows)
    for fi in range(4):
        idle = draw_unit_frame(palette, "idle", frame_i=fi)
        sheet.paste(idle, (fi * fw, 0), idle)
        walk = draw_unit_frame(palette, "walk", frame_i=fi)
        sheet.paste(walk, (fi * fw, fh), walk)
        atk = draw_unit_frame(palette, "attack", frame_i=fi)
        sheet.paste(atk, (fi * fw, fh * 2), atk)
    sheet.save(SPR / "heroes" / f"{name}_sheet.png")
    # also keep single portrait/idle for menus
    idle0 = draw_unit_frame(palette, "idle", frame_i=0)
    idle0.save(SPR / f"hero_{name}.png")


def make_creep_sheet(name: str, palette: dict) -> None:
    ensure(SPR / "creeps")
    fw, fh = 48, 48
    cols, rows = 4, 2
    sheet = blank(fw * cols, fh * rows)
    for fi in range(4):
        # scale drawing via resize from 64
        idle = draw_unit_frame(palette, "idle", frame_i=fi).resize((48, 48), Image.NEAREST)
        walk = draw_unit_frame(palette, "walk", frame_i=fi).resize((48, 48), Image.NEAREST)
        sheet.paste(idle, (fi * fw, 0), idle)
        sheet.paste(walk, (fi * fw, fh), walk)
    sheet.save(SPR / "creeps" / f"{name}_sheet.png")
    idle0 = draw_unit_frame(palette, "idle", frame_i=0)
    if name == "elite":
        idle0 = idle0.resize((72, 72), Image.NEAREST)
    idle0.save(SPR / f"creep_{name}.png")


# ---------- FX ----------

def fx_burst(color, frames=6, size=64) -> Image.Image:
    sheet = blank(size * frames, size)
    for i in range(frames):
        t = i / max(1, frames - 1)
        img = blank(size, size)
        r = 6 + t * 22
        a = int(220 * (1 - t))
        img = soft_blob(img, (size / 2, size / 2), r, with_a(color[:3], a), 2.0)
        img = soft_blob(img, (size / 2, size / 2), r * 0.45, with_a((255, 255, 255), a), 1.0)
        # sparks
        d = ImageDraw.Draw(img)
        for k in range(6):
            ang = k * math.tau / 6 + t * 2
            sx = size / 2 + math.cos(ang) * r
            sy = size / 2 + math.sin(ang) * r
            circle(d, (sx, sy), 2, with_a(color[:3], a))
        sheet.paste(img, (i * size, 0), img)
    return sheet


def fx_ring(color, frames=6, size=80) -> Image.Image:
    sheet = blank(size * frames, size)
    for i in range(frames):
        t = i / max(1, frames - 1)
        img = blank(size, size)
        d = ImageDraw.Draw(img)
        r = 8 + t * 28
        a = int(230 * (1 - t * 0.85))
        box = [size / 2 - r, size / 2 - r, size / 2 + r, size / 2 + r]
        d.ellipse(box, outline=with_a(color[:3], a), width=3)
        sheet.paste(img, (i * size, 0), img)
    return sheet


def fx_slash(color, frames=5, size=64) -> Image.Image:
    sheet = blank(size * frames, size)
    for i in range(frames):
        t = i / max(1, frames - 1)
        img = blank(size, size)
        d = ImageDraw.Draw(img)
        a = int(240 * (1 - abs(t - 0.4)))
        d.arc([8, 10, 56, 54], 200 + t * 40, 320 + t * 30, fill=with_a(color[:3], a), width=4)
        sheet.paste(img, (i * size, 0), img)
    return sheet


def make_fx() -> None:
    ensure(SPR / "fx")
    fx_burst((255, 220, 120)).save(SPR / "fx" / "hit_burst.png")
    fx_burst((120, 220, 255)).save(SPR / "fx" / "heal_burst.png")
    fx_burst((255, 120, 60)).save(SPR / "fx" / "fire_burst.png")
    fx_burst((90, 160, 255)).save(SPR / "fx" / "water_burst.png")
    fx_burst((120, 220, 100)).save(SPR / "fx" / "nature_burst.png")
    fx_burst((255, 240, 180)).save(SPR / "fx" / "holy_burst.png")
    fx_ring((255, 210, 80)).save(SPR / "fx" / "nova_ring.png")
    fx_ring((180, 120, 255)).save(SPR / "fx" / "ascend_ring.png")
    fx_slash((255, 180, 80)).save(SPR / "fx" / "slash.png")
    # death dissipate
    sheet = blank(64 * 5, 64)
    for i in range(5):
        t = i / 4
        img = blank(64, 64)
        img = soft_blob(img, (32, 32), 14 * (1 - t * 0.3), (40, 40, 50, int(180 * (1 - t))), 3)
        sheet.paste(img, (i * 64, 0), img)
    sheet.save(SPR / "fx" / "death_puff.png")
    # gold floater coin
    coin = blank(24, 24)
    d = ImageDraw.Draw(coin)
    circle(d, (12, 12), 10, (240, 190, 50, 255), (180, 130, 20, 255), 2)
    d.text((7, 4), "$", fill=(90, 60, 10, 255))
    coin.save(SPR / "fx" / "gold_coin.png")
    # move marker
    marker = blank(48, 48)
    d = ImageDraw.Draw(marker)
    d.ellipse([6, 6, 42, 42], outline=(120, 220, 255, 220), width=2)
    d.ellipse([16, 16, 32, 32], outline=(180, 240, 255, 180), width=2)
    marker.save(SPR / "fx" / "move_marker.png")
    # attack marker
    am = blank(48, 48)
    d = ImageDraw.Draw(am)
    d.ellipse([4, 4, 44, 44], outline=(255, 80, 70, 230), width=2)
    d.line([(12, 12), (36, 36)], fill=(255, 100, 80, 220), width=2)
    d.line([(36, 12), (12, 36)], fill=(255, 100, 80, 220), width=2)
    am.save(SPR / "fx" / "attack_marker.png")
    # interact marker
    im = blank(48, 48)
    d = ImageDraw.Draw(im)
    d.ellipse([6, 6, 42, 42], outline=(255, 210, 90, 230), width=2)
    d.polygon([(24, 10), (30, 22), (24, 20), (18, 22)], fill=(255, 220, 120, 230))
    im.save(SPR / "fx" / "interact_marker.png")
    # projectile
    proj = blank(16, 16)
    proj = soft_blob(proj, (8, 8), 6, (255, 240, 160, 230), 1)
    proj.save(SPR / "projectile.png")


# ---------- icons ----------

def icon_base(bg, size=64) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = blank(size, size)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2, 2, size - 3, size - 3], radius=10, fill=bg, outline=(30, 28, 22, 255), width=2)
    d.rounded_rectangle([5, 5, size - 6, size - 6], radius=8, outline=(255, 230, 160, 90), width=1)
    return img, d


def make_ability_icons() -> None:
    ensure(UI / "icons")
    specs = {
        "smite": ((70, 60, 30), "bolt"),
        "mending_light": ((40, 70, 55), "cross"),
        "ascendant_burst": ((80, 70, 35), "star"),
        "cinder_dash": ((90, 40, 25), "dash"),
        "scorch": ((100, 45, 20), "flame"),
        "inferno_form": ((110, 35, 15), "skull"),
        "rip_current": ((25, 45, 90), "wave"),
        "undertow": ((20, 50, 80), "pull"),
        "tidal_crash": ((30, 55, 100), "crash"),
        "bramble_skin": ((35, 70, 35), "shield"),
        "root_snare": ((40, 65, 30), "root"),
        "overgrowth": ((30, 80, 40), "spike"),
    }
    for aid, (bg, kind) in specs.items():
        img, d = icon_base(with_a(bg, 255))
        cx, cy = 32, 32
        if kind == "bolt":
            d.polygon([(28, 12), (38, 28), (32, 28), (36, 52), (22, 30), (30, 30)], fill=(255, 240, 140, 255))
        elif kind == "cross":
            d.rectangle([28, 16, 36, 48], fill=(200, 255, 220, 255))
            d.rectangle([16, 28, 48, 36], fill=(200, 255, 220, 255))
        elif kind == "star":
            pts = []
            for i in range(10):
                ang = -math.pi / 2 + i * math.pi / 5
                r = 16 if i % 2 == 0 else 7
                pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
            d.polygon(pts, fill=(255, 230, 120, 255))
        elif kind == "dash":
            d.polygon([(14, 32), (40, 18), (36, 32), (40, 46)], fill=(255, 160, 80, 255))
        elif kind == "flame":
            d.ellipse([20, 18, 44, 48], fill=(255, 140, 40, 255))
            d.ellipse([26, 14, 38, 30], fill=(255, 220, 100, 255))
        elif kind == "skull":
            circle(d, (cx, cy - 2), 12, (255, 200, 120, 255))
            circle(d, (cx - 5, cy - 4), 3, (40, 20, 10, 255))
            circle(d, (cx + 5, cy - 4), 3, (40, 20, 10, 255))
        elif kind == "wave":
            d.arc([12, 20, 52, 44], 200, 340, fill=(140, 210, 255, 255), width=4)
            d.arc([12, 30, 52, 54], 200, 340, fill=(100, 180, 255, 255), width=3)
        elif kind == "pull":
            d.polygon([(16, 20), (32, 32), (16, 44)], fill=(120, 190, 255, 255))
            d.polygon([(48, 20), (32, 32), (48, 44)], fill=(120, 190, 255, 255))
        elif kind == "crash":
            d.polygon([(12, 40), (32, 14), (52, 40)], fill=(150, 210, 255, 255))
        elif kind == "shield":
            d.polygon([(32, 12), (48, 22), (44, 46), (32, 52), (20, 46), (16, 22)], fill=(140, 220, 120, 255))
        elif kind == "root":
            d.line([(32, 14), (32, 48)], fill=(120, 200, 90, 255), width=4)
            d.line([(32, 28), (18, 42)], fill=(100, 180, 70, 255), width=3)
            d.line([(32, 28), (46, 42)], fill=(100, 180, 70, 255), width=3)
        elif kind == "spike":
            for x in (20, 32, 44):
                d.polygon([(x, 48), (x - 6, 28), (x + 6, 28)], fill=(90, 200, 100, 255))
        img.save(UI / "icons" / f"ability_{aid}.png")


def make_item_icons() -> None:
    ensure(UI / "icons")
    items = {
        "boots": ((50, 40, 30), "boot"),
        "blade": ((60, 45, 35), "sword"),
        "cloak": ((40, 45, 70), "cloak"),
        "potion": ((70, 30, 40), "potion"),
        "shield": ((55, 55, 40), "shield"),
        "ring": ((70, 55, 25), "ring"),
        "amulet": ((50, 40, 70), "gem"),
        "tome": ((35, 45, 65), "book"),
    }
    for name, (bg, kind) in items.items():
        img, d = icon_base(with_a(bg, 255), 48)
        if kind == "boot":
            d.polygon([(14, 18), (28, 16), (30, 34), (12, 34)], fill=(200, 160, 90, 255))
        elif kind == "sword":
            d.polygon([(24, 8), (28, 8), (28, 32), (24, 32)], fill=(220, 220, 230, 255))
            d.rectangle([18, 32, 34, 36], fill=(180, 140, 60, 255))
        elif kind == "cloak":
            d.polygon([(24, 10), (36, 18), (34, 40), (14, 40), (12, 18)], fill=(120, 140, 210, 255))
        elif kind == "potion":
            d.ellipse([16, 18, 32, 38], fill=(255, 80, 100, 255))
            d.rectangle([20, 10, 28, 18], fill=(200, 180, 120, 255))
        elif kind == "shield":
            d.polygon([(24, 8), (36, 14), (34, 34), (24, 40), (14, 34), (12, 14)], fill=(200, 180, 90, 255))
        elif kind == "ring":
            d.ellipse([14, 14, 34, 34], outline=(255, 210, 80, 255), width=4)
        elif kind == "gem":
            d.polygon([(24, 10), (34, 24), (24, 38), (14, 24)], fill=(180, 120, 255, 255))
        elif kind == "book":
            d.rectangle([12, 12, 36, 36], fill=(180, 200, 230, 255), outline=(40, 40, 60, 255))
        img.save(UI / "icons" / f"item_{name}.png")


# ---------- HUD chrome (WC3-inspired, mobile) ----------

def make_hud() -> None:
    ensure(UI / "hud")
    # bottom bar strip
    bar = blank(720, 220)
    d = ImageDraw.Draw(bar)
    # dark stone panel
    for y in range(220):
        t = y / 220
        c = int(18 + t * 10)
        d.line([(0, y), (719, y)], fill=(c, c + 2, c + 6, 235))
    d.rectangle([0, 0, 719, 219], outline=(140, 110, 55, 255), width=3)
    d.line([(0, 4), (719, 4)], fill=(210, 170, 80, 180), width=2)
    # left portrait well
    d.rounded_rectangle([12, 24, 140, 196], radius=8, fill=(12, 14, 18, 255), outline=(170, 135, 60, 255), width=2)
    # center info wells
    d.rounded_rectangle([152, 24, 430, 100], radius=6, fill=(10, 12, 16, 230), outline=(120, 95, 45, 200), width=1)
    # inventory 2x3
    sx, sy = 152, 112
    for r in range(2):
        for c in range(3):
            x = sx + c * 46
            y = sy + r * 46
            d.rounded_rectangle([x, y, x + 40, y + 40], radius=4, fill=(8, 10, 14, 255), outline=(150, 120, 50, 220), width=1)
    # command card well (right)
    d.rounded_rectangle([448, 24, 700, 196], radius=8, fill=(10, 12, 16, 235), outline=(170, 135, 60, 220), width=2)
    bar.save(UI / "hud" / "bottom_bar.png")

    # portrait frame
    pf = blank(128, 128)
    d = ImageDraw.Draw(pf)
    d.rounded_rectangle([4, 4, 124, 124], radius=10, fill=(20, 22, 28, 255), outline=(200, 160, 70, 255), width=3)
    d.rounded_rectangle([10, 10, 118, 118], radius=8, outline=(255, 220, 120, 80), width=1)
    pf.save(UI / "hud" / "portrait_frame.png")

    # HP / MP bar tracks
    for name, fill in [("hp_track", (40, 20, 20)), ("mp_track", (20, 25, 45))]:
        img = blank(256, 18)
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([0, 0, 255, 17], radius=4, fill=with_a(fill, 255), outline=(0, 0, 0, 180), width=1)
        img.save(UI / "hud" / f"{name}.png")
    for name, col in [("hp_fill", (60, 190, 80)), ("mp_fill", (70, 130, 230))]:
        img = blank(256, 14)
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([0, 0, 255, 13], radius=3, fill=with_a(col, 255))
        # highlight
        d.rectangle([0, 0, 255, 4], fill=(255, 255, 255, 50))
        img.save(UI / "hud" / f"{name}.png")

    # inventory slot
    slot = blank(44, 44)
    d = ImageDraw.Draw(slot)
    d.rounded_rectangle([1, 1, 42, 42], radius=4, fill=(8, 10, 14, 255), outline=(160, 125, 55, 230), width=2)
    slot.save(UI / "hud" / "inv_slot.png")

    # command button frame
    for name, bg in [("cmd_frame", (35, 40, 50)), ("cmd_frame_hot", (55, 50, 30))]:
        img = blank(72, 72)
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([2, 2, 69, 69], radius=8, fill=with_a(bg, 240), outline=(190, 150, 70, 255), width=2)
        img.save(UI / "hud" / f"{name}.png")

    # minimap frame
    mm = blank(168, 168)
    d = ImageDraw.Draw(mm)
    d.rounded_rectangle([2, 2, 165, 165], radius=6, fill=(8, 10, 14, 200), outline=(180, 145, 60, 255), width=3)
    mm.save(UI / "hud" / "minimap_frame.png")

    # top resource chip
    chip = blank(160, 36)
    d = ImageDraw.Draw(chip)
    d.rounded_rectangle([0, 0, 159, 35], radius=8, fill=(12, 14, 18, 210), outline=(160, 130, 55, 220), width=1)
    chip.save(UI / "hud" / "resource_chip.png")

    # gold icon
    g = blank(24, 24)
    d = ImageDraw.Draw(g)
    circle(d, (12, 12), 10, (240, 190, 50, 255), (160, 110, 20, 255), 2)
    g.save(UI / "hud" / "gold_icon.png")

    # ability button skins
    for name, col in [("btn_attack", (140, 50, 40)), ("btn_ability", (45, 55, 80))]:
        img = blank(72, 72)
        d = ImageDraw.Draw(img)
        d.ellipse([2, 2, 69, 69], fill=with_a(col, 230), outline=(220, 180, 90, 255), width=3)
        d.ellipse([8, 8, 63, 63], outline=(255, 255, 255, 40), width=1)
        img.save(UI / f"{name}.png")

    # joystick
    jb = blank(128, 128)
    d = ImageDraw.Draw(jb)
    d.ellipse([4, 4, 123, 123], fill=(20, 24, 30, 160), outline=(170, 140, 70, 200), width=3)
    d.ellipse([28, 28, 99, 99], outline=(255, 255, 255, 30), width=1)
    jb.save(UI / "joystick_base.png")
    jk = blank(64, 64)
    d = ImageDraw.Draw(jk)
    d.ellipse([2, 2, 61, 61], fill=(200, 170, 90, 230), outline=(255, 230, 150, 255), width=2)
    jk.save(UI / "joystick_knob.png")

    # panel + menu bg refresh
    panel = blank(256, 64)
    d = ImageDraw.Draw(panel)
    d.rounded_rectangle([0, 0, 255, 63], radius=8, fill=(18, 20, 28, 230), outline=(170, 135, 60, 220), width=2)
    panel.save(UI / "panel.png")

    menu = blank(720, 1280)
    d = ImageDraw.Draw(menu)
    for y in range(1280):
        t = y / 1280
        # celestial gradient: deep indigo → warm ash (avoid purple-AI cliché by going teal-night + ember)
        r = int(12 + t * 40)
        g_ = int(18 + (1 - t) * 25)
        b = int(28 + (1 - t) * 35)
        d.line([(0, y), (719, y)], fill=(r, g_, b, 255))
    # soft light rays
    for i in range(8):
        x = 80 + i * 80
        menu = soft_blob(menu, (x, 180), 90, (255, 220, 140, 18), 20)
    menu = soft_blob(menu, (360, 1100), 200, (180, 60, 40, 25), 30)
    menu.save(UI / "menu_bg.png")

    # app icon
    icon = blank(128, 128)
    d = ImageDraw.Draw(icon)
    d.rounded_rectangle([4, 4, 123, 123], radius=24, fill=(30, 35, 48, 255))
    # winged crest
    d.ellipse([34, 34, 94, 94], fill=(240, 210, 120, 255))
    d.polygon([(64, 20), (78, 50), (64, 44), (50, 50)], fill=(255, 240, 180, 255))
    d.arc([20, 40, 64, 90], 200, 340, fill=(220, 200, 140, 255), width=4)
    d.arc([64, 40, 108, 90], 200, 340, fill=(220, 200, 140, 255), width=4)
    icon.save(UI / "icon.png")


def make_cursors() -> None:
    ensure(UI / "cursors")
    # move cursor
    m = blank(32, 32)
    d = ImageDraw.Draw(m)
    d.ellipse([4, 4, 27, 27], outline=(120, 220, 255, 255), width=2)
    d.line([(16, 2), (16, 10)], fill=(120, 220, 255, 255), width=2)
    d.line([(16, 22), (16, 30)], fill=(120, 220, 255, 255), width=2)
    d.line([(2, 16), (10, 16)], fill=(120, 220, 255, 255), width=2)
    d.line([(22, 16), (30, 16)], fill=(120, 220, 255, 255), width=2)
    m.save(UI / "cursors" / "move.png")
    a = blank(32, 32)
    d = ImageDraw.Draw(a)
    d.ellipse([3, 3, 28, 28], outline=(255, 80, 70, 255), width=2)
    d.line([(8, 8), (24, 24)], fill=(255, 100, 80, 255), width=2)
    d.line([(24, 8), (8, 24)], fill=(255, 100, 80, 255), width=2)
    a.save(UI / "cursors" / "attack.png")
    i = blank(32, 32)
    d = ImageDraw.Draw(i)
    d.ellipse([4, 4, 27, 27], outline=(255, 210, 90, 255), width=2)
    d.polygon([(16, 8), (20, 16), (16, 14), (12, 16)], fill=(255, 220, 120, 255))
    i.save(UI / "cursors" / "interact.png")


def make_world_props() -> None:
    # shop
    shop = blank(64, 64)
    d = ImageDraw.Draw(shop)
    shop = soft_blob(shop, (32, 48), 18, (0, 0, 0, 60), 2)
    d = ImageDraw.Draw(shop)
    d.rectangle([14, 28, 50, 54], fill=(90, 70, 45, 255), outline=(40, 30, 20, 255))
    d.polygon([(10, 28), (32, 10), (54, 28)], fill=(160, 50, 45, 255))
    d.rectangle([26, 36, 38, 54], fill=(40, 30, 20, 255))
    d.ellipse([28, 18, 36, 26], fill=(255, 210, 80, 255))
    shop.save(SPR / "shop.png")
    # fountains
    for name, col in [("fountain_angel", (180, 210, 255)), ("fountain_demon", (255, 120, 90))]:
        img = blank(64, 64)
        img = soft_blob(img, (32, 48), 16, (0, 0, 0, 60), 2)
        d = ImageDraw.Draw(img)
        d.rectangle([22, 30, 42, 52], fill=(90, 90, 100, 255))
        circle(d, (32, 26), 12, with_a(col, 220))
        img = soft_blob(img, (32, 22), 10, with_a(col[:3], 100), 2)
        img.save(SPR / f"{name}.png")
    # tiles refresh lightly
    ensure(ROOT / "tiles")
    for name, base in [
        ("grass", (46, 78, 42)),
        ("dirt", (92, 70, 48)),
        ("stone", (78, 78, 86)),
        ("base_angel", (70, 85, 110)),
        ("base_demon", (95, 55, 50)),
    ]:
        tile = blank(64, 64)
        d = ImageDraw.Draw(tile)
        d.rectangle([0, 0, 63, 63], fill=with_a(base, 255))
        for _ in range(40):
            import random
            x, y = random.randint(0, 63), random.randint(0, 63)
            f = 0.85 + random.random() * 0.3
            d.point((x, y), fill=shade(base, f))
        tile.save(ROOT / "tiles" / f"{name}.png")


def main() -> None:
    print("Generating Seraph Arena art kit…")
    heroes = {
        "seraph": {"body": (230, 215, 170, 255), "accent": (255, 230, 120, 255), "glow": (255, 245, 180, 255), "crest": "halo"},
        "ashwalker": {"body": (90, 45, 35, 255), "accent": (255, 120, 50, 255), "glow": (255, 160, 60, 255), "crest": "horns"},
        "tidebound": {"body": (40, 70, 120, 255), "accent": (100, 180, 255, 255), "glow": (140, 210, 255, 255), "crest": "wave"},
        "thornwight": {"body": (45, 80, 45, 255), "accent": (120, 200, 90, 255), "glow": (160, 230, 120, 255), "crest": "leaves"},
    }
    for name, pal in heroes.items():
        make_hero_sheet(name, pal)
        print("  hero", name)

    creeps = {
        "light": {"body": (160, 150, 120, 255), "accent": (200, 190, 140, 255), "glow": (230, 220, 160, 255), "crest": "halo", "humanoid": False},
        "dark": {"body": (70, 45, 55, 255), "accent": (160, 70, 80, 255), "glow": (200, 90, 90, 255), "crest": "horns", "humanoid": False},
        "elite": {"body": (50, 45, 70, 255), "accent": (200, 160, 70, 255), "glow": (255, 200, 80, 255), "crest": "horns", "humanoid": False},
    }
    for name, pal in creeps.items():
        make_creep_sheet(name, pal)
        print("  creep", name)

    make_fx()
    print("  fx")
    make_ability_icons()
    print("  ability icons")
    make_item_icons()
    print("  item icons")
    make_hud()
    print("  hud")
    make_cursors()
    print("  cursors")
    make_world_props()
    print("  world props")
    print("Done.")


if __name__ == "__main__":
    main()
