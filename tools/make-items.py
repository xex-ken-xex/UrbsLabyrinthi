#!/usr/bin/env python3
"""アイテムのアイコン(32×32 のドット絵)を1枚のシートに並べ、索引とゲームのデータを書き出す。
  python3 tools/make-items.py [--preview]
出力:
  godot/assets/items/items_sheet.png   16列のシート(1マス 32×32、透明な背景)
  godot/data/item-icons.json           id → マスの番号
  godot/scripts/items_forage.gd        自生物、素材、遺品の定義と、出現・ドロップの表(自動生成。手で直さない)
一覧は tools/item-catalog.py。"""
import importlib.util
import json
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, file))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


ms = load("ms", "make-sprites.py")
cat = load("cat", "item-catalog.py")
C, shade, Canvas = ms.C, ms.shade, ms.Canvas
OL = ms.OUTLINE
COLS = 16


def hx(s):
    return C(s) if isinstance(s, str) else s


# ---------- 部品 ----------
def disc(c, cx, cy, r, col, flat=1.0):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if ((x - cx) ** 2) / (r * r) + ((y - cy) ** 2) / ((r * flat) ** 2) <= 1.0:
                c.p(x, y, col)


def twinkle(c, x, y, col=(255, 255, 255, 255), big=False):
    c.p(x, y, col)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        c.p(x + dx, y + dy, tuple(list(col[:3]) + [170]))
    if big:
        for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            c.p(x + dx, y + dy, tuple(list(col[:3]) + [110]))


def mushroom1(c, x, base_y, cap, stem, dots, h, w, glow, skull=False):
    c.r(x - 1, base_y - h, x + 1, base_y, stem)
    c.p(x - 1, base_y, shade(stem, 0.7)); c.p(x + 1, base_y, shade(stem, 0.7))
    top = base_y - h - w
    for y in range(w + 1):
        half = int(round(w * math.sqrt(max(0.0, 1 - ((w - y) / (w + 0.5)) ** 2)))) + 1
        for xx in range(-half, half + 1):
            col = shade(cap, 1.25 - 0.45 * y / w)
            c.p(x + xx, top + y, col)
    if skull:
        c.r(x - 2, top + 2, x - 1, top + 3, dots); c.r(x + 1, top + 2, x + 2, top + 3, dots)
    elif dots:
        for dx, dy in ((-2, 1), (1, 2), (3, 1), (-1, 3)):
            c.p(x + dx, top + dy, dots)
    if glow:
        twinkle(c, x + w, top - 1, hx(glow))


def draw_mushroom(c, cap, stem, dots=None, glow=None, n=1, tall=False, skull=False):
    cap, stem = hx(cap), hx(stem)
    dots = hx(dots) if dots else None
    h = 9 if tall else 6
    if n == 1:
        mushroom1(c, 16, 27, cap, stem, dots, h, 7, glow, skull)
    else:
        mushroom1(c, 10, 27, cap, stem, dots, 5, 5, glow)
        mushroom1(c, 21, 27, shade(cap, 0.9), stem, dots, 8, 6, glow)


def draw_moss(c, col, glow=None, drops=False, crystal=False):
    col = hx(col)
    # こんもりした苔の塊(楕円の山に、濃淡の粒を散らす)
    for y in range(11, 27):
        for x in range(4, 28):
            dx, dy = (x - 16) / 12.0, (y - 26) / 15.0
            if dx * dx + dy * dy <= 1.0:
                k = 0.75 + 0.5 * ((x * 7 + y * 13) % 5) / 4.0 + (0.12 if y < 16 else 0)
                c.p(x, y, shade(col, k))
    c.r(5, 26, 26, 26, shade(col, 0.55))
    for (x, y) in ((9, 18), (14, 14), (20, 17), (24, 22), (11, 23)):
        c.p(x, y, shade(col, 1.5))
    if glow:
        for x, y in ((8, 10), (22, 9), (26, 17)):
            twinkle(c, x, y, hx(glow))
    if drops:
        for x, y in ((12, 28), (20, 29)):
            c.p(x, y, C("c8f0ff")); c.p(x, y - 1, C("80c0e0"))
    if crystal:
        for x, y in ((10, 14), (18, 13), (22, 18)):
            c.r(x, y, x, y + 3, C("e8ffff")); c.p(x, y - 1, C("ffffff"))


def draw_tuber(c, col, sprout):
    col = hx(col)
    disc(c, 13, 20, 7, col, 0.85); disc(c, 21, 22, 6, shade(col, 0.9), 0.85)
    for x, y in ((11, 18), (19, 20), (14, 23), (22, 25)):
        c.p(x, y, shade(col, 0.6))
    c.p(10, 16, shade(col, 1.3)); c.p(11, 16, shade(col, 1.3))
    c.line(13, 13, 12, 8, hx(sprout)); c.r(10, 6, 13, 8, hx(sprout)); c.p(14, 7, hx(sprout))


def draw_herb(c, col, flower=None, round=False, blade=False):
    col = hx(col)
    if blade:
        for i, x in enumerate((9, 13, 17, 21)):
            c.line(x, 27, x + (i % 2) * 2 - 1, 8 + (i % 3) * 2, col)
            c.line(x + 1, 27, x + 1 + (i % 2) * 2 - 1, 9 + (i % 3) * 2, shade(col, 1.2))
        c.r(8, 24, 22, 27, C("e8dcc0"))
        return
    c.line(16, 27, 16, 12, shade(col, 0.8))
    for k, (dx, dy) in enumerate(((-6, -2), (6, -4), (-5, -9), (5, -11), (0, -14))):
        ex, ey = 16 + dx, 24 + dy
        if round:
            disc(c, ex, ey, 4, shade(col, 1.0 + 0.1 * k), 0.8)
        else:
            c.line(16, 24 + dy // 2, ex, ey, col)
            disc(c, ex, ey, 3, shade(col, 1.0 + 0.08 * k), 0.7)
    if flower:
        disc(c, 16, 9, 2, hx(flower)); c.p(16, 9, C("e0a030"))


def draw_flower(c, petal, center, bone=False):
    petal, center = hx(petal), hx(center)
    c.line(16, 28, 16, 17, C("4a7a48"))
    c.line(16, 24, 11, 21, C("4a7a48")); c.line(16, 25, 21, 22, C("4a7a48"))
    for k in range(6):
        a = k * math.pi / 3
        disc(c, 16 + math.cos(a) * 5, 12 + math.sin(a) * 5, 3, shade(petal, 1.0 if k % 2 else 0.85), 1)
    disc(c, 16, 12, 2.5, center)
    if bone:
        c.p(16, 12, C("2a2630"))


def draw_jar(c, col, lid, glow=False):
    col, lid = hx(col), hx(lid)
    c.r(9, 12, 22, 26, shade(col, 0.9)); c.r(10, 13, 21, 25, col)
    c.r(11, 14, 12, 23, shade(col, 1.4))
    c.r(8, 8, 23, 12, lid); c.r(8, 8, 23, 8, shade(lid, 1.3)); c.r(8, 12, 23, 12, shade(lid, 0.6))
    if glow:
        twinkle(c, 24, 10, C("fff8d0")); twinkle(c, 7, 20, C("fff8d0"))


def draw_bottle(c, liquid, big=False, flask=False, glow=False):
    liq = hx(liquid)
    glass = C("c8e0f0")
    if flask:
        c.r(13, 6, 18, 12, glass); c.r(8, 13, 23, 27, glass)
        c.r(9, 17, 22, 26, liq); c.r(9, 17, 22, 17, shade(liq, 1.3))
    else:
        w0 = 9 if big else 10
        c.r(14, 6, 17, 12, glass); c.r(w0, 13, 31 - w0, 27, glass)
        c.r(w0 + 1, 16, 30 - w0, 26, liq); c.r(w0 + 1, 16, 30 - w0, 16, shade(liq, 1.3))
    c.r(13, 4, 18, 6, C("8a5a2a")); c.r(13, 4, 18, 4, C("b07a3a"))
    c.p(12, 19, C("ffffff")); c.p(12, 21, C("ffffff"))
    if glow:
        twinkle(c, 25, 12, C("ffe8f0")); twinkle(c, 6, 22, C("ffe8f0"))


def draw_charm(c, col):
    col = hx(col)
    disc(c, 16, 16, 9, shade(col, 0.8)); disc(c, 16, 16, 7, col)
    c.r(15, 10, 16, 22, C("a83a2a")); c.r(10, 15, 22, 16, C("a83a2a"))
    c.r(15, 4, 16, 7, C("c8b890"))
    twinkle(c, 24, 9, C("ffffff"))


def draw_scroll(c, col):
    col = hx(col)
    c.r(8, 8, 23, 24, col); c.r(8, 8, 23, 8, shade(col, 1.2))
    c.r(6, 6, 25, 9, C("c8a060")); c.r(6, 23, 25, 26, C("c8a060"))
    for y in (13, 16, 19):
        c.r(11, y, 20, y, C("7a6a50"))
    c.r(14, 24, 17, 28, C("a83a2a"))


def draw_fish(c, col):
    col = hx(col)
    for x in range(5, 24):
        h = int(2 + 5 * (1 - abs((x - 13) / 9.0) ** 1.5))
        c.r(x, 16 - h, x, 16 + h, col)
        c.p(x, 16 + h, shade(col, 0.8))
    c.line(24, 16, 28, 12, shade(col, 0.9)); c.line(24, 16, 28, 21, shade(col, 0.9)); c.r(28, 12, 28, 21, shade(col, 0.9))
    c.r(12, 9, 15, 11, shade(col, 0.8))
    c.p(8, 15, shade(col, 0.5))   # 目の跡


def draw_shell(c, col):
    col = hx(col)
    for r in range(10, 0, -1):
        for y in range(-r, 1):
            for x in range(-r - 4, r + 5):
                if (x / (r + 4.0)) ** 2 + (y / float(r)) ** 2 <= 1.0:
                    c.p(16 + x, 22 + y, shade(col, 0.7 + (10 - r) * 0.04))
    for k in range(-3, 4):
        c.line(16, 22, 16 + k * 3, 14 + abs(k), shade(col, 0.55))
    c.r(8, 22, 24, 24, shade(col, 0.6))
    disc(c, 16, 23, 2.5, C("f4eef8"))


def draw_pearl(c):
    disc(c, 16, 17, 7, C("e8e4f0")); disc(c, 16, 17, 5, C("f8f4ff"))
    c.p(13, 14, C("ffffff")); c.p(14, 14, C("ffffff")); c.p(13, 15, C("ffffff"))
    c.p(19, 21, C("b8a8d0")); c.p(18, 22, C("b8a8d0"))
    twinkle(c, 24, 9, C("ffffff"), big=True)


def draw_slime(c, col, glow=False, leech=False):
    col = hx(col)
    if leech:
        for i in range(14):
            x = 6 + i * 1.5
            c.r(int(x), int(16 + 3 * math.sin(i * 0.6)), int(x) + 2, int(18 + 3 * math.sin(i * 0.6)), shade(col, 0.8 + 0.03 * i))
        c.p(5, 17, C("e04040"))
        return
    for y in range(12, 27):
        t = (y - 12) / 14
        half = int(round(4 + 8 * (t ** 0.6)))
        for x in range(-half, half + 1):
            c.p(16 + x, y, shade(col, 1.25 - 0.5 * t))
    c.p(12, 15, shade(col, 1.7)); c.p(13, 14, shade(col, 1.7))
    if glow:
        twinkle(c, 24, 9, C("ffffff")); twinkle(c, 7, 12, hx("e8e0ff"))


def draw_lump(c, col, kind):
    col = hx(col)
    if kind == "salt":
        for (x, y, s) in ((8, 16, 8), (16, 12, 9), (14, 20, 8)):
            c.r(x, y, x + s - 1, y + s - 1, shade(col, 1.0)); c.r(x, y, x + s - 1, y, C("ffffff")); c.r(x + s - 1, y, x + s - 1, y + s - 1, shade(col, 0.7))
    elif kind == "dung":
        for (x, y, r) in ((13, 20, 6), (20, 21, 5), (16, 14, 4)):
            disc(c, x, y, r, shade(col, 1.0), 0.8)
        c.p(12, 18, shade(col, 1.6)); c.p(19, 19, shade(col, 1.6))
    elif kind == "resin":
        disc(c, 16, 18, 8, shade(col, 0.8), 0.9); disc(c, 16, 17, 6, col, 0.9)
        c.p(13, 14, C("fff0c0")); c.p(14, 14, C("fff0c0"))
    elif kind == "wax":
        c.r(9, 12, 22, 26, shade(col, 0.85)); c.r(10, 12, 21, 25, col)
        c.r(10, 12, 21, 12, C("ffffff")); c.line(15, 12, 15, 6, C("5a4a3a")); c.p(15, 5, C("ffc040"))
    elif kind == "ember":
        for (x, y, r) in ((13, 19, 6), (21, 21, 5)):
            disc(c, x, y, r, C("3a2a28"), 0.8)
        for (x, y) in ((11, 18), (14, 21), (20, 20), (22, 23)):
            c.p(x, y, col); c.p(x + 1, y, shade(col, 1.3))
        twinkle(c, 16, 12, C("ffc040"))


def draw_meat(c, col):
    col = hx(col)
    disc(c, 15, 18, 8, shade(col, 0.8), 0.8); disc(c, 15, 17, 6, col, 0.8)
    c.r(21, 21, 26, 23, C("e8e0d0")); disc(c, 27, 22, 2, C("f4f0e4"))
    c.p(12, 15, shade(col, 1.5)); c.p(13, 14, shade(col, 1.5))
    c.line(10, 19, 18, 16, shade(col, 0.6))


def draw_pelt(c, col):
    col = hx(col)
    c.r(8, 10, 24, 25, col)
    for k in range(4):
        c.r(5 + k * 0, 12 + k * 3, 8, 13 + k * 3, col); c.r(24, 12 + k * 3, 27 + (k % 2), 13 + k * 3, col)
    for y in range(11, 25, 2):
        c.r(9, y, 23, y, shade(col, 0.8))
    c.r(8, 10, 24, 10, shade(col, 1.3))


def draw_fang(c, col):
    col = hx(col)
    for (x, y, h, s) in ((11, 8, 16, 4), (19, 12, 12, 3)):
        for i in range(h):
            w = max(0, s - i * s // h)
            c.r(x - w // 2, y + i, x + w // 2, y + i, shade(col, 1.0 - i * 0.02))
    c.p(10, 10, C("ffffff")); c.p(10, 11, C("ffffff"))


def draw_bone(c, col):
    col = hx(col)
    c.line(9, 22, 22, 10, col); c.line(10, 22, 23, 10, shade(col, 0.9)); c.line(9, 21, 22, 9, shade(col, 1.15))
    for (x, y) in ((7, 22), (9, 24), (22, 8), (24, 10)):
        disc(c, x, y, 2, col)
    c.r(19, 22, 25, 24, shade(col, 0.9)); c.p(26, 23, shade(col, 0.8))


def draw_scrap(c, col):
    col = hx(col)
    for (pts, k) in (([(8, 22), (16, 12), (22, 24)], 1.0), ([(14, 24), (24, 14), (26, 26)], 0.8)):
        for y in range(10, 28):
            for x in range(6, 28):
                (x0, y0), (x1, y1), (x2, y2) = pts
                d = ((y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2))
                if d == 0:
                    continue
                a = ((y1 - y2) * (x - x2) + (x2 - x1) * (y - y2)) / d
                b = ((y2 - y0) * (x - x2) + (x0 - x2) * (y - y2)) / d
                if a >= 0 and b >= 0 and a + b <= 1:
                    c.p(x, y, shade(col, k * (0.8 + 0.4 * a)))
    c.p(16, 18, C("5a3a2a")); c.p(17, 19, C("5a3a2a"))


def draw_scale(c, col):
    col = hx(col)
    for (x, y) in ((16, 10), (11, 16), (21, 16), (16, 22)):
        disc(c, x, y, 5, shade(col, 0.8), 1.0); disc(c, x, y - 1, 4, col, 0.9)
        c.p(x - 1, y - 3, shade(col, 1.6))


def draw_gland(c, col):
    col = hx(col)
    disc(c, 16, 18, 8, shade(col, 0.7), 0.9); disc(c, 16, 17, 6, col, 0.9)
    c.p(13, 14, C("f4ffd0")); c.p(14, 14, C("f4ffd0"))
    c.line(16, 10, 16, 6, shade(col, 0.6)); c.r(14, 4, 18, 6, C("5a4a2a"))


def draw_feather(c, col):
    col = hx(col)
    c.line(8, 26, 24, 6, shade(col, 0.6))
    for i in range(14):
        t = i / 13
        x, y = 8 + 16 * t, 26 - 20 * t
        c.line(x, y, x + 5 - 3 * t, y + 1, shade(col, 0.9 + 0.2 * (1 - t)))
        c.line(x, y, x - 4 + 2 * t, y + 3, shade(col, 0.8))


def draw_fruit(c, col, leaf):
    col, leaf = hx(col), hx(leaf)
    disc(c, 16, 18, 8, shade(col, 0.8)); disc(c, 15, 17, 6, col)
    c.p(12, 13, shade(col, 1.7)); c.p(13, 13, shade(col, 1.7)); c.p(12, 14, shade(col, 1.7))
    c.line(16, 10, 17, 6, C("5a4a3a")); c.r(17, 6, 22, 8, leaf)
    twinkle(c, 24, 20, C("ffffff"))


def draw_bundle(c, col, kind):
    col = hx(col)
    if kind == "gear":
        c.r(10, 10, 21, 24, shade(col, 0.8)); c.r(11, 11, 20, 23, col)
        c.r(7, 11, 10, 15, shade(col, 0.9)); c.r(21, 11, 24, 15, shade(col, 0.9))
        c.r(13, 8, 18, 10, shade(col, 1.2)); c.r(14, 15, 17, 20, shade(col, 1.3))
        c.line(10, 24, 21, 24, C("4a3a2a"))
        c.p(14, 12, shade(col, 1.6))
    else:
        c.r(8, 16, 24, 25, C("7a5a3a")); c.r(8, 16, 24, 17, C("a07a4a"))
        c.line(9, 15, 21, 6, C("8a8a98")); c.r(20, 4, 24, 8, C("9aa0b0"))  # つるはし
        c.r(21, 17, 21, 25, C("3a2a1a")); c.r(13, 12, 14, 16, C("c0c0d0"))


def draw_tag(c, col):
    col = hx(col)
    c.r(10, 10, 21, 24, shade(col, 0.8)); c.r(11, 11, 20, 23, col)
    c.r(11, 11, 20, 11, shade(col, 1.4))
    disc(c, 15, 7, 2, C("3a3a44")); c.line(15, 5, 12, 0, C("5a5a64")); c.line(15, 5, 18, 0, C("5a5a64"))
    for y in (15, 18, 21):
        c.r(13, y, 18, y, shade(col, 0.55))


def draw_coins(c, col):
    col = hx(col)
    for (x, y) in ((10, 20), (17, 22), (14, 15), (21, 16)):
        disc(c, x, y, 4, shade(col, 0.7), 0.8); disc(c, x, y - 1, 4, col, 0.8)
        c.p(x - 1, y - 2, shade(col, 1.5))


DRAW = {
    "mushroom": draw_mushroom, "moss": draw_moss, "tuber": draw_tuber, "herb": draw_herb, "flower": draw_flower,
    "jar": draw_jar, "bottle": draw_bottle, "charm": draw_charm, "scroll": draw_scroll, "fish": draw_fish, "shell": draw_shell,
    "pearl": draw_pearl, "slime": draw_slime, "lump": draw_lump, "meat": draw_meat, "pelt": draw_pelt, "fang": draw_fang,
    "bone": draw_bone, "scrap": draw_scrap, "scale": draw_scale, "gland": draw_gland, "feather": draw_feather, "fruit": draw_fruit,
    "bundle": draw_bundle, "tag": draw_tag, "coins": draw_coins,
}

# ---------- 燐晶 ----------
CRYSTAL_COL = {
    "low": ("93aab8", "c4d6e0"),
    "mid": ("3fa0d0", "8ad8f8"),
    "high": ("78e8f8", "e0ffff"),
    "pure": ("c898ff", "fff0ff"),
    "unk": ("3a2a5a", "b9b4ff"),
}


def shard(c, x, y, w, h, base, hi, tilt=0):
    """先のとがった結晶1本"""
    for i in range(h):
        t = i / max(1, h - 1)
        half = max(0, int(round(w / 2.0 * (1 - (1 - t) ** 2 * 0.7)))) if i < h * 0.6 else int(w / 2)
        top = i < h * 0.35
        half = int(round((w / 2.0) * (0.25 + 0.75 * min(1.0, t / 0.4))))
        xo = int(round(tilt * (1 - t)))
        c.r(x - half + xo, y + i, x + half + xo, y + i, shade(base, 1.0 - 0.25 * t))
        c.p(x - half + xo, y + i, hi)
        c.p(x + half + xo, y + i, shade(base, 0.6))
    c.p(x + (tilt), y, hi)


def draw_crystal(c, purity, size):
    base, hi = CRYSTAL_COL[purity]
    base, hi = hx(base), hx(hi)
    layouts = {
        "s": [(16, 15, 6, 11, 0)],
        "m": [(12, 14, 5, 12, -2), (19, 12, 6, 14, 1), (16, 17, 5, 9, 0)],
        "l": [(9, 15, 5, 11, -2), (23, 15, 5, 11, 2), (14, 9, 7, 16, -1), (20, 12, 6, 13, 1), (16, 16, 6, 10, 0)],
    }
    if size == "l":
        c.r(6, 26, 25, 27, C("4a4a52")); c.r(8, 25, 23, 25, C("5a5a64"))
    for (x, y, w, h, t) in layouts[size]:
        shard(c, x, y, w, h, base, hi, t)
    if purity in ("high", "pure", "unk"):
        twinkle(c, 6, 8, hi, big=True)
        if size != "s":
            twinkle(c, 26, 10, hi)
    if purity == "pure":
        for (x, y, col) in ((10, 20, "ff80c0"), (21, 20, "80c8ff"), (16, 24, "ffe880")):
            c.p(x, y, hx(col))
    if purity == "unk":
        c.p(15, 17, C("ffffff")); c.p(17, 20, C("ffffff"))


def finish(c, outline=True):
    if outline:
        c.outline()
    return c.im


# ---------- 組み立て ----------
def build():
    order = []   # (id, 画像)

    def add(i, drawer):
        c = Canvas()
        drawer(c)
        order.append((i, finish(c)))

    for pid, _jp, _p in cat.PURITIES:
        for size in cat.CRYSTAL_SIZES:
            add(f"crystal_{pid}_{size}", lambda c, p=pid, s=size: draw_crystal(c, p, s))
    for (i, recipe, kw) in cat.EXISTING:
        add(i, lambda c, r=recipe, k=kw: DRAW[r](c, **k))
    for it in cat.FORAGE:
        r, kw = it["icon"]
        add(it["id"], lambda c, r=r, k=kw: DRAW[r](c, **k))
    # 死体(地面に置く絵)
    def corpse(c):
        c.r(7, 20, 24, 25, C("5a4a3a")); c.r(8, 19, 23, 21, C("6a5a48"))
        disc(c, 25, 21, 3, C("d0b090")); c.r(5, 22, 8, 26, C("3a3028"))
        c.r(10, 18, 16, 20, C("4a5a8a")); c.p(26, 20, C("1a1418"))
    add("corpse", corpse)
    return order


def write_sheet(order):
    rows = (len(order) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * 32, rows * 32), (0, 0, 0, 0))
    index = {}
    for n, (i, im) in enumerate(order):
        sheet.paste(im, ((n % COLS) * 32, (n // COLS) * 32))
        index[i] = n
    out = os.path.join(ROOT, "godot", "assets", "items")
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, "items_sheet.png"))
    json.dump({"cols": COLS, "cell": 32, "icons": index}, open(os.path.join(ROOT, "godot", "data", "item-icons.json"), "w"), ensure_ascii=False)
    return sheet, index


def gd_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_gd():
    lines = ["# 自動生成: tools/make-items.py(元は tools/item-catalog.py)。手で直さない。",
             "class_name ForageData", "extends RefCounted", "",
             "## 自生物、魔物の素材、遺品の定義。ItemDB.ITEMS に併せて使う。税がかからないもの(燐晶ではない)。", "",
             "const ITEMS := {"]
    for it in cat.FORAGE:
        kind = it.get("kind", "consumable")
        parts = [f'"name": {gd_str(it["name"])}', f'"kind": "{kind}"', f'"price": {it["price"]}', '"free": true']
        if kind == "consumable":
            parts.append(f'"use": "{it["use"]}"')
            if "buff" in it:
                parts.append(f'"buff": "{it["buff"]}"')
            parts.append(f'"v": {float(it.get("v", 0)):.2f}')
            if "t" in it:
                parts.append(f'"t": {float(it["t"]):.1f}')
            if "min" in it:
                parts.append(f'"min": {float(it["min"]):.1f}')
        parts.append(f'"desc": {gd_str(it["desc"])}')
        lines.append(f'\t"{it["id"]}": {{' + ", ".join(parts) + "},")
    lines.append("}")
    lines += ["", "## 舞台ごとの出現。[品物, 重み, 場所, 最も浅い層]", "const SPOTS := {"]
    by_theme = {}
    for it in cat.FORAGE:
        for (th, w, spot, fl) in it.get("spots", []):
            by_theme.setdefault(th, []).append((it["id"], w, spot, fl))
    for th, arr in by_theme.items():
        lines.append(f'\t"{th}": [')
        for (i, w, spot, fl) in arr:
            lines.append(f'\t\t["{i}", {float(w):.2f}, "{spot}", {fl}],')
        lines.append("\t],")
    lines.append("}")
    lines += ["", "## 魔物が落とすもの。[対象, 品物, 確率]。対象は type:○○ か idx:○○(index に含まれる語)", "const DROPS := ["]
    for (tgt, i, p, _cr) in cat.DROPS:
        lines.append(f'\t["{tgt}", "{i}", {p:.2f}],')
    lines.append("]")
    lines += ["", "## 燐晶の純度。[id, 名前, 銀貨/kg]", "const PURITIES := ["]
    for (pid, jp, price) in cat.PURITIES:
        lines.append(f'\t["{pid}", "{jp}", {price}],')
    lines.append("]")
    open(os.path.join(ROOT, "godot", "scripts", "items_forage.gd"), "w").write("\n".join(lines) + "\n")


def main():
    order = build()
    sheet, index = write_sheet(order)
    write_gd()
    print(f"{len(order)} icons, sheet {sheet.size}, {len(cat.FORAGE)} forage items")
    if "--preview" in sys.argv:
        S = 3
        names = [i for i, _ in order]
        prev = Image.new("RGBA", (COLS * 32 * S // 2 * 1, 0), (0, 0, 0, 0))
        big = Image.new("RGBA", (sheet.width * 2, sheet.height * 2), (52, 58, 52, 255))
        big.alpha_composite(sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST))
        big.save("/tmp/claude-0/items-preview.png")
        print("names:", ", ".join(f"{n}:{i}" for i, n in enumerate(names)))


if __name__ == "__main__":
    main()
