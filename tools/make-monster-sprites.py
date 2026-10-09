#!/usr/bin/env python3
"""魔物のスプライトシートを、型(アーキタイプ)ごとの描き方で量産する。
  python3 tools/make-monster-sprites.py            # godot/assets/sprites/ に esheet_*.png
  python3 tools/make-monster-sprites.py --preview  # 一覧画像 /tmp/monster-preview.png も作る
名前の一部(キーワード)で型と色を決める。すでに make-sprites.py に手描き定義がある魔物は上書きしない。
型ごとの代表(esheet_type_<type>.png)も作る。"""
import importlib.util
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("ms", os.path.join(HERE, "make-sprites.py"))
ms = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ms)
C, shade, Canvas, sheet_from, render_humanoid = ms.C, ms.shade, ms.Canvas, ms.sheet_from, ms.render_humanoid
EYE = C("101018")
RED = C("e04040")


def fin(c, d):
    c.outline()
    return c.im.transpose(Image.FLIP_LEFT_RIGHT) if d == "R" else c.im


def seeded(n, seed):
    out, s = [], seed
    for _ in range(n):
        s = (s * 1103515245 + 12345) & 0x7fffffff
        a = s % 1000
        s = (s * 1103515245 + 12345) & 0x7fffffff
        out.append((a, s % 1000))
    return out


# ---------- 四つ足(獣・竜・馬など) ----------
def quad(**st):
    col = st["col"]
    belly = st.get("belly", shade(col, 1.25))
    bl, bh, lh = st.get("bl", 14), st.get("bh", 8), st.get("lh", 5)
    hw, hh = st.get("hw", 6), st.get("hh", 6)
    hcol = st.get("hcol", col)
    eye = st.get("eye", EYE)

    def fn(d, ph):
        c = Canvas()
        sw = (1, 0, -1)[ph]
        bob = -1 if ph == 1 else 0
        g = 28
        yl = g - lh
        y0 = yl - bh + bob
        if d in ("L", "R"):
            x0 = 16 - bl // 2 + 3
            x1 = x0 + bl
            if st.get("tail"):
                tc, tl = st["tail"], st.get("tl", 5)
                c.line(x1, y0 + 1, x1 + tl, y0 - 2 + sw, tc); c.line(x1, y0 + 2, x1 + tl, y0 - 1 + sw, tc)
                if st.get("spike_tail"):
                    c.r(x1 + tl - 1, y0 - 4 + sw, x1 + tl + 1, y0 - 2 + sw, st["spike_tail"])
            if st.get("wing"):
                wc = st["wing"]
                for k in range(7):
                    c.line(x0 + 4 + k, y0, x0 + 8 + k // 2, y0 - 9 + k - (2 if ph == 1 else 0), wc)
                c.line(x0 + 4, y0, x0 + 8, y0 - 9, shade(wc, 1.3))
            for xx, o in ((x0 + 1, sw), (x0 + 3, -sw), (x1 - 4, -sw), (x1 - 2, sw)):
                far = xx in (x0 + 3, x1 - 2)
                lc = shade(col, 0.7 if far else 0.9)
                c.r(xx, yl + bob, xx + 1, g - 1, lc); c.r(xx + o, g, xx + o + 2, g, shade(lc, 0.7))
            c.r(x0, y0, x1, y0 + bh - 1, col)
            c.r(x0, y0, x1, y0, shade(col, 1.2))
            c.r(x0 + 1, y0 + bh - 2, x1 - 1, y0 + bh - 1, belly)
            if st.get("stripes"):
                for xx in range(x0 + 2, x1, 3):
                    c.r(xx, y0 + 1, xx, y0 + bh - 3, st["stripes"])
            if st.get("spots"):
                for a, b in seeded(7, 3):
                    c.p(x0 + 1 + a % (bl - 1), y0 + 1 + b % max(1, bh - 3), st["spots"])
            if st.get("hump"):
                c.r(x0 + 3, y0 - 3, x0 + 8, y0 - 1, st["hump"])
            if st.get("plates"):
                for xx in range(x0 + 1, x1, 2):
                    c.r(xx, y0 - 2, xx, y0 - 1, st["plates"])
            hx0 = x0 - hw + 2
            hy0 = y0 - 2 + (st.get("hy", 0))
            if st.get("neck"):
                c.r(x0 - 1, hy0 + 1, x0 + 3, y0 + 2, col)
            c.r(hx0, hy0, x0 + 1, hy0 + hh - 1, hcol)
            if st.get("snout"):
                c.r(hx0 - st["snout"], hy0 + hh - 4, hx0, hy0 + hh - 1, shade(hcol, 1.1))
                c.p(hx0 - st["snout"], hy0 + hh - 4, EYE)
            c.p(hx0 + 1, hy0 + 2, eye)
            if st.get("beak"):
                c.r(hx0 - 2, hy0 + 2, hx0, hy0 + 3, st["beak"])
            if st.get("ears"):
                c.r(hx0 + 2, hy0 - 2, hx0 + 3, hy0 - 1, hcol); c.p(hx0 + 2, hy0 - 3, hcol)
            if st.get("horns"):
                c.r(hx0 + 1, hy0 - 3, hx0 + 1, hy0 - 1, st["horns"]); c.r(hx0, hy0 - 4, hx0 + 1, hy0 - 4, st["horns"])
                c.r(hx0 + 3, hy0 - 2, hx0 + 3, hy0 - 1, st["horns"])
            if st.get("antler"):
                ac = st["antler"]
                c.line(hx0 + 2, hy0 - 1, hx0 + 2, hy0 - 6, ac); c.line(hx0 + 2, hy0 - 4, hx0, hy0 - 6, ac); c.line(hx0 + 2, hy0 - 4, hx0 + 4, hy0 - 6, ac)
            if st.get("tusk"):
                c.r(hx0 - 1, hy0 + hh - 2, hx0 - 1, hy0 + hh + 1, st["tusk"])
            if st.get("trunk"):
                c.r(hx0 - 2, hy0 + 2, hx0, hy0 + 3, st["trunk"]); c.r(hx0 - 2, hy0 + 4, hx0 - 1, hy0 + hh + 2, st["trunk"])
            if st.get("mane"):
                c.r(x0 - 1, y0 - 2, x0 + 4, y0 + 1, st["mane"]); c.r(hx0 + 2, hy0 - 1, x0, hy0, st["mane"])
            if st.get("fangs"):
                c.p(hx0 - (st.get("snout", 0)), hy0 + hh, C("f0f0e8"))
        else:
            back = d == "U"
            bw = bh + 4
            xa, xb = 16 - bw // 2, 16 + bw // 2 - 1
            if st.get("wing"):
                wc = st["wing"]
                fl = 2 if ph == 1 else 0
                for sgn, xs in ((-1, xa), (1, xb)):
                    for k in range(8):
                        c.line(xs, y0 + 1, xs + sgn * (4 + k // 2), y0 - 6 + k - fl, wc)
            if back and st.get("tail"):
                c.line(16, y0 + bh - 1, 16, y0 + bh + st.get("tl", 5), st["tail"]); c.line(15, y0 + bh, 15, y0 + bh + 4, st["tail"])
            for xx, o in ((xa + 1, sw), (xb - 2, -sw)):
                c.r(xx, yl + bob, xx + 1, g - 1, shade(col, 0.85)); c.r(xx - 1, g, xx + 2, g, shade(col, 0.6))
                c.p(xx + o, g, shade(col, 0.5))
            c.r(xa, y0 + 2, xb, y0 + bh - 1, col)
            c.r(xa, y0 + 2, xb, y0 + 2, shade(col, 1.2))
            if not back:
                c.r(xa + 2, y0 + bh - 3, xb - 2, y0 + bh - 1, belly)
            if st.get("stripes"):
                for xx in range(xa + 1, xb, 3):
                    c.r(xx, y0 + 3, xx, y0 + bh - 2, st["stripes"])
            if st.get("spots"):
                for a, b in seeded(6, 3):
                    c.p(xa + a % bw, y0 + 3 + b % max(1, bh - 4), st["spots"])
            if st.get("plates"):
                for yy in range(y0 + 2, y0 + bh, 2):
                    c.p(16, yy, st["plates"]); c.p(15, yy, st["plates"])
            hx0, hx1 = 16 - hw // 2, 16 + hw // 2 - 1
            hy0 = y0 - hh + 4
            if st.get("mane"):
                c.r(hx0 - 1, hy0 - 1, hx1 + 1, hy0 + hh, st["mane"])
            c.r(hx0, hy0, hx1, hy0 + hh - 1, hcol)
            c.r(hx0, hy0, hx1, hy0, shade(hcol, 1.2))
            if st.get("ears"):
                c.r(hx0, hy0 - 2, hx0 + 1, hy0 - 1, hcol); c.r(hx1 - 1, hy0 - 2, hx1, hy0 - 1, hcol)
                c.p(hx0, hy0 - 3, hcol); c.p(hx1, hy0 - 3, hcol)
            if st.get("horns"):
                hc2 = st["horns"]
                c.r(hx0 - 1, hy0 - 3, hx0, hy0 - 1, hc2); c.r(hx1, hy0 - 3, hx1 + 1, hy0 - 1, hc2)
                c.p(hx0 - 2, hy0 - 4, hc2); c.p(hx1 + 2, hy0 - 4, hc2)
            if st.get("antler"):
                ac = st["antler"]
                for xs, sg in ((hx0, -1), (hx1, 1)):
                    c.line(xs, hy0, xs + sg * 1, hy0 - 6, ac); c.line(xs + sg, hy0 - 4, xs + sg * 4, hy0 - 6, ac)
            if not back:
                c.p(hx0 + 1, hy0 + 2, eye); c.p(hx1 - 1, hy0 + 2, eye)
                if st.get("snout") or st.get("beak"):
                    mz = st.get("beak") or shade(hcol, 1.2)
                    c.r(15, hy0 + 3, 16, hy0 + hh - 1, mz)
                    if st.get("beak"):
                        c.p(15, hy0 + hh, mz)
                else:
                    c.r(15, hy0 + hh - 2, 16, hy0 + hh - 1, shade(hcol, 1.2))
                if st.get("tusk"):
                    c.p(hx0, hy0 + hh, st["tusk"]); c.p(hx1, hy0 + hh, st["tusk"])
                if st.get("fangs"):
                    c.p(hx0 + 1, hy0 + hh, C("f0f0e8")); c.p(hx1 - 1, hy0 + hh, C("f0f0e8"))
                if st.get("trunk"):
                    c.r(15, hy0 + 3, 16, hy0 + hh + 3, st["trunk"])
        return fin(c, d)
    return fn


# ---------- 鳥・飛ぶもの ----------
def bird(**st):
    col = st["col"]
    belly = st.get("belly", shade(col, 1.3))
    wing = st.get("wing", shade(col, 0.8))
    big = st.get("big", 0)

    def fn(d, ph):
        c = Canvas()
        flap = (-5, 0, 5)[ph]
        by = 14
        w = 3 + big
        if d in ("L", "R"):
            c.r(16 - w - 2, by, 16 + w + 2, by + 6 + big, col); c.r(16 - w, by + 4, 16 + w, by + 6 + big, belly)
            c.r(16 - w - 5, by - 2, 16 - w - 1, by + 3, col)                      # 頭
            c.p(16 - w - 4, by, EYE)
            bk = st.get("beak", C("e0b040"))
            c.r(16 - w - 8, by + 1, 16 - w - 5, by + 2, bk)
            c.line(16 + w + 2, by + 3, 16 + w + 7, by + 6, shade(col, 0.8))      # 尾
            c.line(16, by, 16 + 4 + big, by - 7 - flap // 2, wing); c.line(16 + 1, by + 1, 16 + 7 + big, by - 4 - flap // 2, wing)
            c.line(16, by - 1, 16 + 6 + big, by - 8 - flap // 2, shade(wing, 1.2))
            if st.get("legs"):
                c.r(15, by + 7 + big, 15, by + 9 + big, st["legs"]); c.r(18, by + 7 + big, 18, by + 9 + big, st["legs"])
        else:
            back = d == "U"
            c.r(16 - w, by - 1, 16 + w - 1, by + 7 + big, col)
            if not back:
                c.r(16 - w + 1, by + 3, 16 + w - 2, by + 7 + big, belly)
            for sg in (-1, 1):
                x0 = 16 + sg * w - (1 if sg < 0 else 0)
                for k in range(4):
                    c.line(x0, by + k, x0 + sg * (8 + big), by - 3 + flap + k * 2, shade(wing, 1.0 - k * 0.07))
            c.r(16 - 2 - big // 2, by - 5, 16 + 1 + big // 2, by - 1, col)
            if not back:
                c.p(14, by - 3, EYE); c.p(17, by - 3, EYE)
                c.r(15, by - 2, 16, by, st.get("beak", C("e0b040")))
            if st.get("tail_back") and back:
                c.r(15, by + 8 + big, 16, by + 11 + big, shade(col, 0.8))
        return fin(c, d)
    return fn


# ---------- 虫・蜘蛛・蠍 ----------
def bug(**st):
    col = st["col"]
    kind = st.get("kind", "beetle")

    def fn(d, ph):
        c = Canvas()
        sw = (1, 0, -1)[ph]
        bob = -1 if ph == 1 else 0
        lc = shade(col, 0.7)
        if kind == "wasp":
            flap = (-2, 0, 2)[ph]
            c.r(13, 12, 18, 16, st.get("head", col)); c.r(12, 17, 19, 24, col)
            for y in range(18, 24, 2):
                c.r(12, y, 19, y, EYE)
            c.line(16, 24, 16, 27, C("d0d0d0"))
            c.p(14, 13, RED); c.p(17, 13, RED)
            for sg in (-1, 1):
                c.line(16 + sg * 2, 13, 16 + sg * 9, 6 + flap, C("c8e0f0")); c.line(16 + sg * 2, 14, 16 + sg * 8, 11 + flap, C("c8e0f0"))
            return fin(c, d)
        if kind == "centipede":
            horiz = d in ("L", "R")
            for i in range(9):
                x, y = (6 + i * 2.6, 20 + (i % 2) * 1 + (sw if i % 2 else -sw) * 0) if horiz else (16 + (i % 2) * 1, 6 + i * 2.4)
                x, y = int(x), int(y)
                c.r(x, y, x + 2, y + 2, col if i else shade(col, 1.2))
                if horiz:
                    c.p(x, y + 3 + (sw if i % 2 else -sw), lc); c.p(x + 1, y - 1 - (sw if i % 2 else -sw), lc)
                else:
                    c.p(x - 1 - (sw if i % 2 else -sw), y + 1, lc); c.p(x + 3 + (sw if i % 2 else -sw), y + 1, lc)
            if d != "U":
                hx, hy = (6, 20) if horiz else (16, 24)
                c.p(hx, hy, RED); c.p(hx + 2, hy, RED)
            return fin(c, d)
        if kind == "scorpion":
            c.r(11, 16 + bob, 20, 24 + bob, col); c.r(11, 16 + bob, 20, 16 + bob, shade(col, 1.25))
            c.r(13, 12 + bob, 18, 16 + bob, shade(col, 1.1))
            if d != "U":
                c.p(14, 13 + bob, EYE); c.p(17, 13 + bob, EYE)
            tc = shade(col, 1.2)
            c.line(16, 24 + bob, 16, 28, tc); c.line(16, 28, 20, 24, tc); c.line(20, 24, 22, 17, tc); c.line(22, 17, 20, 15, C("c04040"))
            for sg in (-1, 1):
                c.line(16 + sg * 3, 13 + bob, 16 + sg * 8, 7 + bob - sw * sg, lc); c.r(16 + sg * 8 - 1, 5 + bob, 16 + sg * 8 + 1, 7 + bob, shade(col, 1.3))
                for i in range(3):
                    y = 17 + i * 3 + bob
                    o = sw if i % 2 == 0 else -sw
                    c.line(11 if sg < 0 else 20, y, 11 + sg * 6 if sg < 0 else 20 + 6, y + 2 + o, lc)
            return fin(c, d)
        # beetle / ant
        shell = st.get("shell", shade(col, 1.0))
        c.r(11, 13 + bob, 20, 25 + bob, shell)
        c.r(11, 13 + bob, 20, 13 + bob, shade(shell, 1.3)); c.line(16, 14 + bob, 16, 25 + bob, shade(shell, 0.7))
        c.r(13, 8 + bob, 18, 12 + bob, shade(col, 0.9))
        if d != "U":
            c.p(14, 10 + bob, RED); c.p(17, 10 + bob, RED)
        c.line(14, 8 + bob, 12, 5 + bob, lc); c.line(17, 8 + bob, 19, 5 + bob, lc)
        if st.get("glow"):
            c.r(14, 21 + bob, 17, 24 + bob, st["glow"])
        for i in range(3):
            y = 15 + i * 4 + bob
            o = sw if i % 2 == 0 else -sw
            c.line(11, y, 6, y + 1 + o, lc); c.line(20, y, 25, y + 1 - o, lc)
        return fin(c, d)
    return fn


# ---------- 蛇・竜蛇・ワーム ----------
def snake(**st):
    col = st["col"]
    belly = st.get("belly", shade(col, 1.3))
    th = st.get("th", 2)
    n = st.get("n", 1)

    def fn(d, ph):
        c = Canvas()
        pts = []
        L = 22
        for i in range(L):
            t = i / (L - 1)
            if d in ("L", "R"):
                x = 6 + t * 20
                y = 22 + 2.5 * __import__("math").sin(t * 7 + ph * 2.1)
                pts.append((x, y))
            else:
                y = 8 + t * 18 if d == "D" else 26 - t * 18
                x = 16 + 4 * __import__("math").sin(t * 7 + ph * 2.1)
                pts.append((x, y))
        order = pts if d in ("L", "R") else (pts if d == "D" else pts)
        for x, y in (pts if d != "L" else pts):
            c.r(int(x) - th // 2, int(y) - th // 2, int(x) + th // 2, int(y) + th // 2, col)
        for k, (x, y) in enumerate(pts):
            if k % 3 == 0:
                c.p(int(x), int(y), st.get("pat", shade(col, 0.7)))
        # 頭は、進む向きの先(LEFT=左端、DOWN=手前下)
        hx, hy = (pts[0] if d == "L" or d == "R" else pts[-1] if d == "D" else pts[-1])
        if d == "L":
            hx, hy = pts[0]
        elif d == "R":
            hx, hy = pts[0]
        hx, hy = int(hx), int(hy)
        hs = th // 2 + 2
        c.r(hx - hs, hy - hs + 1, hx + hs, hy + hs, shade(col, 1.15))
        if st.get("hood"):
            c.r(hx - hs - 2, hy - hs, hx + hs + 2, hy + hs - 1, shade(col, 1.0))
        if d != "U":
            c.p(hx - 1, hy - 1, RED); c.p(hx + 1, hy - 1, RED)
            c.p(hx, hy + hs, C("e04060"))
        for _ in range(n - 1):  # 多頭(ヒュドラ)
            c.r(hx - 6, hy - 6, hx - 4, hy - 4, shade(col, 1.15)); c.r(hx + 4, hy - 7, hx + 6, hy - 5, shade(col, 1.15))
            c.line(hx - 5, hy - 4, hx - 1, hy, col); c.line(hx + 5, hy - 5, hx + 1, hy, col)
        return fin(c, d)
    return fn


# ---------- ぷよぷよ ----------
def ooze(**st):
    col = st["col"]
    kind = st.get("kind", "blob")

    def fn(d, ph):
        c = Canvas()
        squash = (0, 2, 1)[ph]
        if kind == "cube":
            top = 10 + squash
            c.r(7, top, 24, 27, (col[0], col[1], col[2], 190))
            c.r(7, top, 24, top + 1, shade(col, 1.4)); c.r(7, top, 8, 27, shade(col, 1.3)); c.r(23, top + 2, 24, 27, shade(col, 0.7))
            c.r(11, 18, 13, 20, C("d0d0d0")); c.r(17, 22, 19, 23, C("c0a050")); c.p(15, 16, C("e8e0c0"))
            return fin(c, d)
        w = st.get("w", 9) + (1 if ph == 1 else 0)
        top = st.get("top", 14) + squash
        for y in range(top, 28):
            t = (y - top) / max(1, 27 - top)
            half = int(round(5 + (w - 5) * (t ** 0.6)))
            c.r(16 - half, y, 16 + half, y, shade(col, 1.25 - 0.5 * t))
        c.r(16 - w + 2, 26, 16 + w - 2, 27, shade(col, 0.7))
        if kind == "mound":
            for a, b in seeded(10, 5):
                c.r(8 + a % 17, top + b % 10, 9 + a % 17, top + 1 + b % 10, st.get("leaf", C("3a7a30")))
            for xx in (9, 15, 21):
                c.line(xx, top + 3, xx - 2, top - 2 + ph, st.get("leaf", C("3a7a30")))
        if d != "U":
            ex = {"D": (13, 18), "L": (11, 14), "R": (17, 20)}[d]
            for x in ex:
                c.r(x, top + 4, x + 1, top + 6, C("f8f8f8")); c.p(x + (0 if d != "R" else 1), top + 5, EYE)
        c.p(13, top + 2, shade(col, 1.6)); c.p(14, top + 1, shade(col, 1.6))
        return fin(c, d)
    return fn


# ---------- 幽霊・精霊・ウィスプ ----------
def ghost(**st):
    col = st["col"]
    a = st.get("alpha", 210)
    kind = st.get("kind", "ghost")

    def fn(d, ph):
        c = Canvas()
        fl = (0, -1, 0)[ph] + (1 if ph == 2 else 0)
        wob = (1, 0, -1)[ph]
        cc = (col[0], col[1], col[2], a)
        if kind == "wisp":
            for r in range(6, 0, -1):
                for y in range(-r, r + 1):
                    for x in range(-r, r + 1):
                        if x * x + y * y <= r * r:
                            k = 1.0 + (6 - r) * 0.1
                            c.p(16 + x, 16 + y + fl, tuple(min(255, int(v * k)) for v in col[:3]) + (a if r > 3 else 255,))
            if d != "U":
                c.p(14, 15 + fl, EYE); c.p(18, 15 + fl, EYE)
            for sg in (-1, 1):
                c.line(16 + sg * 7, 12 + fl, 16 + sg * 10, 8 + fl + wob * sg, cc)
            return fin(c, d)
        top = 6 + fl
        c.r(11, top + 2, 20, 21 + fl, cc); c.r(12, top, 19, top + 1, cc)
        for x in range(11, 21):
            c.r(x, 22 + fl, x, 23 + fl + ((x + ph) % 3 == 0), cc)
        c.r(8, 12 + fl, 10, 19 + fl + wob, cc); c.r(21, 12 + fl, 23, 19 + fl - wob, cc)
        if kind == "wraith":
            c.r(11, top - 1, 20, top + 3, shade(col, 0.6)); c.r(13, top + 3, 18, top + 6, C("08080c"))
        if d != "U":
            c.p(14, top + 5, st.get("eye", C("e8f0ff"))); c.p(17, top + 5, st.get("eye", C("e8f0ff")))
            c.r(15, top + 8, 16, top + 9, C("101018"))
        return fin(c, d)
    return fn


# ---------- 目玉・触手 ----------
def eyeball(**st):
    col = st["col"]
    eyes = st.get("eyes", 0)

    def fn(d, ph):
        c = Canvas()
        fl = (0, -1, 0)[ph]
        for r in range(8, 0, -1):
            for y in range(-r, r + 1):
                for x in range(-r, r + 1):
                    if x * x + y * y <= r * r:
                        c.p(16 + x, 16 + y + fl, shade(col, 0.8 + (8 - r) * 0.06))
        if d != "U":
            c.r(13, 14 + fl, 18, 18 + fl, C("f4f4f0")); c.r(15, 15 + fl, 16, 17 + fl, st.get("iris", C("30c040")))
        for i in range(eyes):
            ang = i * 6.283 / max(1, eyes)
            m = __import__("math")
            ex, ey = 16 + 9 * m.cos(ang), 16 + 8 * m.sin(ang) + fl
            c.line(16 + 6 * m.cos(ang), 16 + 6 * m.sin(ang) + fl, ex, ey, shade(col, 0.9))
            c.p(int(ex), int(ey), C("f4f4f0"))
        for k, xx in enumerate((11, 14, 17, 20)):
            c.line(xx, 23 + fl, xx + ((k + ph) % 3) - 1, 28, shade(col, 0.9))
        return fin(c, d)
    return fn


# ---------- 甲殻・蛸・魚 ----------
def crab(**st):
    col = st["col"]

    def fn(d, ph):
        c = Canvas()
        sw = (1, 0, -1)[ph]
        c.r(10, 16, 21, 24, col); c.r(10, 16, 21, 16, shade(col, 1.25))
        c.r(8, 18, 9, 22, col); c.r(22, 18, 23, 22, col)
        for sg in (-1, 1):
            cx = 16 + sg * 10
            c.line(16 + sg * 5, 17, cx, 11, shade(col, 0.9)); c.r(cx - 2, 7, cx + 2, 11, shade(col, 1.15))
            c.p(cx, 9, shade(col, 0.5))
            for i in range(3):
                y = 20 + i * 2
                o = sw if i % 2 == 0 else -sw
                c.line(16 + sg * 6, y, 16 + sg * 11, y + 3 + o, shade(col, 0.7))
        if d != "U":
            c.p(13, 14, EYE); c.p(18, 14, EYE); c.r(13, 15, 13, 16, col); c.r(18, 15, 18, 16, col)
        return fin(c, d)
    return fn


def octo(**st):
    col = st["col"]
    big = st.get("big", 0)

    def fn(d, ph):
        c = Canvas()
        sw = (1, 0, -1)[ph]
        for r in range(8 + big, 0, -1):
            for y in range(-r, r + 1):
                for x in range(-r, r + 1):
                    if x * x + y * y <= r * r:
                        c.p(16 + x, 11 + y, shade(col, 0.8 + (8 - r) * 0.07))
        for k in range(8):
            x = 8 + k * 2 + (k // 4)
            amp = sw if k % 2 else -sw
            c.line(x, 18, x + amp, 22, shade(col, 0.85)); c.line(x + amp, 22, x - amp + (k - 3.5) // 2, 27, shade(col, 0.85))
        if d != "U":
            c.p(13, 12, C("f8f8c0")); c.p(18, 12, C("f8f8c0")); c.p(13, 13, EYE); c.p(18, 13, EYE)
        return fin(c, d)
    return fn


def fish(**st):
    col = st["col"]
    belly = st.get("belly", shade(col, 1.5))
    sz = st.get("sz", 0)

    def fn(d, ph):
        c = Canvas()
        t = (-1, 0, 1)[ph]
        if d in ("L", "R"):
            for x in range(5, 24):
                h = int(2 + (4 + sz) * (1 - abs((x - 13) / 9.0) ** 1.6))
                c.r(x, 17 - h, x, 17 + h, col)
                c.p(x, 17 + h, belly)
            c.r(13, 8 - sz, 15, 12, col) if st.get("fin", True) else None
            c.line(24, 17, 28, 13 + t, col); c.line(24, 17, 28, 21 - t, col)
            c.p(8, 16, C("f8f8f8")); c.p(8, 15, EYE) if False else c.p(8, 16, EYE)
            if st.get("teeth"):
                c.r(5, 19, 8, 19, C("f0f0e8"))
        else:
            c.r(12, 10, 19, 24, col); c.r(14, 22, 17, 26, col)
            c.r(8, 16, 11, 18, col); c.r(20, 16, 23, 18, col)
            c.r(15, 6, 16, 12, shade(col, 0.8))
            c.line(15, 27, 12, 30 + t, col); c.line(16, 27, 19, 30 - t, col)
            if d != "U":
                c.p(13, 13, EYE); c.p(18, 13, EYE)
                if st.get("teeth"):
                    c.r(14, 18, 17, 18, C("f0f0e8"))
        return fin(c, d)
    return fn


# ---------- 植物・きのこ ----------
def plant(**st):
    col = st["col"]
    kind = st.get("kind", "shrub")

    def fn(d, ph):
        c = Canvas()
        sw = (1, 0, -1)[ph]
        if kind == "mushroom":
            c.r(14, 16, 17, 27, st.get("stem", C("d8c8a8")))
            for r in range(8, 0, -1):
                for y in range(-r // 2, 1):
                    for x in range(-r, r + 1):
                        if x * x + (2 * y) ** 2 <= r * r:
                            c.p(16 + x, 14 + y, shade(col, 0.8 + (8 - r) * 0.05))
            for a, b in seeded(5, 9):
                c.p(10 + a % 12, 10 + b % 4, C("f0e8d0"))
            for k, xx in enumerate((10, 13, 19, 22)):
                c.line(xx, 18, xx + ((k + ph) % 3) - 1, 24 + (k % 2), shade(col, 1.0))
        elif kind == "stalk":
            c.r(12, 14, 19, 27, C("7a6a58")); c.r(13, 8, 18, 14, C("6a5a48"))
            for k, xx in enumerate((10, 14, 18, 22)):
                c.line(xx, 14, xx - 2 + k, 4 + ph, col)
            c.r(14, 10, 17, 12, C("d0d0a0")); c.p(15, 11, EYE) if d != "U" else None
        else:
            for a, b in seeded(40, 11):
                x, y = 7 + a % 18, 12 + b % 15
                c.r(x, y, x + 1, y + 1, shade(col, 0.7 + (a % 5) * 0.12))
            c.r(10, 18, 22, 26, col); c.r(12, 14, 20, 18, col)
            if d != "U":
                c.p(13, 18, RED); c.p(18, 18, RED)
            c.line(9, 20, 5, 15 + sw, shade(col, 0.8)); c.line(22, 20, 26, 15 - sw, shade(col, 0.8))
        return fin(c, d)
    return fn


# ---------- 群れ ----------
def swarm(**st):
    col = st["col"]
    shape = st.get("shape", "dot")

    def fn(d, ph):
        c = Canvas()
        for k, (a, b) in enumerate(seeded(15, st.get("seed", 1))):
            x = 5 + a % 22 + ((k + ph) % 3) - 1
            y = 6 + b % 20 + ((k * 2 + ph) % 3) - 1
            if shape == "bat":
                c.r(x - 1, y, x + 1, y, col); c.p(x, y + 1, shade(col, 0.7))
                c.p(x - 2, y - 1 + (ph % 2), col); c.p(x + 2, y - 1 + (ph % 2), col)
            elif shape == "snake":
                c.r(x - 2, y, x + 2, y, col); c.p(x + 2, y - 1, shade(col, 1.3)); c.p(x - 1, y + 1, col)
            elif shape == "fish":
                c.r(x - 1, y, x + 1, y, col); c.p(x + 2, y - 1 + (ph % 2), col); c.p(x + 2, y + 1 - (ph % 2), col)
            elif shape == "wasp":
                c.r(x, y, x + 1, y + 1, col); c.p(x - 1, y - 1, C("c8e0f0")); c.p(x + 2, y - 1, C("c8e0f0"))
            else:
                c.r(x, y, x + 1, y + 1, col); c.p(x - 1, y + 2, shade(col, 0.7)); c.p(x + 2, y + 2, shade(col, 0.7))
        for a, b in seeded(15, st.get("seed", 1))[:5]:
            c.p(5 + a % 22, 6 + b % 20, RED)
        return fin(c, d)
    return fn


# ---------- 人型(拡張) ----------
SK = {
    "orc": C("7a9a60"), "ogre": C("b09870"), "troll": C("6a8a5a"), "stone": C("8a8a90"), "pale": C("c8d0d8"),
    "red": C("c04a40"), "blue": C("4a6ac0"), "dark": C("5a4870"), "tan": C("d0a880"), "brown": C("8a6a48"),
}


def human(skin="tan", **st):
    st.setdefault("head", "bare")
    st.setdefault("female", False)
    st["skin"] = SK.get(skin, skin) if isinstance(skin, str) else skin
    st.setdefault("hair", None)
    st.setdefault("torso", C("6a5a48")); st.setdefault("sleeve", shade(st["torso"], 0.85)); st.setdefault("glove", st["skin"])
    st.setdefault("pants", C("4a4438")); st.setdefault("boots", C("3a3028")); st.setdefault("belt", C("2a2018"))
    return lambda d, ph: render_humanoid(st, d, ph)


# ---------- 名前 → 型 ----------
DRAGON = {"black": C("3a3a48"), "blue": C("4a6ac0"), "brass": C("c8a040"), "bronze": C("a06a30"), "copper": C("b0602c"),
          "gold": C("e0b830"), "green": C("4a9a48"), "red": C("c8402c"), "silver": C("c8ccd8"), "white": C("e0e8f0")}


def dragon(name, size):
    col = next((v for k, v in DRAGON.items() if k in name), C("6a8a5a"))
    big = size in ("H", "G") or "ancient" in name or "adult" in name
    wy = "wyrmling" in name
    if wy:
        return quad(col=col, bl=10, bh=6, lh=3, hw=5, hh=5, snout=2, horns=shade(col, 1.4), wing=shade(col, 0.8), tail=col, tl=5, eye=RED)
    return quad(col=col, bl=18 if big else 15, bh=10 if big else 8, lh=5, hw=7, hh=6, snout=3, horns=shade(col, 1.5), wing=shade(col, 0.75),
                tail=col, tl=7, spike_tail=shade(col, 1.4), eye=RED, neck=True, hy=-2, plates=shade(col, 0.7))


def rules(name, typ, size):
    """名前の一部と型から、描き方を決める。上にあるほど優先"""
    n = name
    has = lambda *ws: any(w in n for w in ws)
    # 竜
    if has("dragon") and not has("turtle", "half-"):
        return dragon(n, size)
    if has("wyvern"):
        return quad(col=C("6a8a50"), bl=15, bh=8, lh=4, hw=6, hh=5, snout=2, wing=C("4a6a38"), tail=C("6a8a50"), tl=8, spike_tail=C("c8c0a0"), eye=RED, neck=True)
    if has("pseudodragon"):
        return quad(col=C("c04a40"), bl=9, bh=5, lh=3, hw=5, hh=4, snout=1, wing=C("902a28"), tail=C("c04a40"), tl=6, horns=C("e0d8b0"))
    if has("dragon-turtle"):
        return quad(col=C("4a8a7a"), bl=18, bh=10, lh=3, hw=7, hh=6, snout=2, plates=C("8ac0a0"), tail=C("4a8a7a"), tl=3, neck=True, eye=RED)
    # 蛇
    if has("hydra"):
        return snake(col=C("4a7a58"), th=4, n=3)
    if has("naga"):
        return snake(col=C("7a4a9a"), th=4, hood=True)
    if has("constrictor"):
        return snake(col=C("7a8a50"), th=4)
    if has("snake"):
        return snake(col=C("8a9a50") if has("flying") else C("5a8a4a"), th=3 if has("giant") else 2)
    if has("lamia"):
        return snake(col=C("a06a48"), th=4, hood=True)
    if has("couatl"):
        return snake(col=C("40b878"), th=3, hood=True, pat=C("e8d040"))
    if has("purple-worm"):
        return snake(col=C("7a3a8a"), th=7)
    # 群れ
    if has("swarm"):
        if has("bat"):
            return swarm(col=C("4a3a54"), shape="bat")
        if has("raven"):
            return swarm(col=C("22222c"), shape="bat", seed=4)
        if has("wasp"):
            return swarm(col=C("d0b030"), shape="wasp", seed=3)
        if has("snake"):
            return swarm(col=C("5a8a4a"), shape="snake", seed=5)
        if has("quipper"):
            return swarm(col=C("6a8aa8"), shape="fish", seed=6)
        if has("rat"):
            return swarm(col=C("6a5a50"), seed=7)
        if has("spider"):
            return swarm(col=C("3a3a4a"), seed=8)
        return swarm(col=C("4a3a30"), seed=2)
    # ぷよぷよ
    if has("cube"):
        return ooze(col=C("78c8a8"), kind="cube")
    if has("black-pudding"):
        return ooze(col=C("30303a"), w=11, top=12)
    if has("ochre"):
        return ooze(col=C("c89a3a"), w=10)
    if has("shambling-mound"):
        return ooze(col=C("5a8a40"), kind="mound", w=11, top=10)
    if has("pudding", "jelly", "ooze", "slime"):
        return ooze(col=C("78b068"))
    # 目・触手
    if has("aboleth"):
        return fish(col=C("5a8a8a"), sz=3, teeth=True)
    if has("beholder", "gibbering"):
        return eyeball(col=C("8a6a98"), eyes=6)
    if has("darkmantle"):
        return ooze(col=C("5a5a6a"), w=7, top=16)
    if has("kraken"):
        return octo(col=C("4a5a9a"), big=3)
    if has("octopus"):
        return octo(col=C("b0604a"), big=1 if has("giant") else 0)
    if has("crab", "chuul"):
        return crab(col=C("c0603a") if has("crab") else C("5a7a68"))
    if has("roper"):
        return plant(col=C("7a6a58"), kind="stalk")
    if has("scorpion"):
        return bug(col=C("c0904a"), kind="scorpion")
    if has("remorhaz", "bulette"):
        return quad(col=C("7a6a88") if has("bulette") else C("a8c0d8"), bl=18, bh=10, lh=3, hw=7, hh=7, snout=2, plates=C("e0e8f0") if has("remorhaz") else C("5a4a68"), tail=None, fangs=True, eye=RED)
    # 魚・海
    if has("shark", "whale", "plesiosaurus", "sahuagin-fish"):
        return fish(col=C("708090") if not has("killer") else C("20202a"), belly=C("e0e0e0"), sz=2 if has("giant", "killer", "plesio") else 1, teeth=True)
    if has("sea-horse"):
        return fish(col=C("e0a040"), sz=1, fin=True)
    if has("quipper"):
        return fish(col=C("6a8aa8"), sz=-1, teeth=True)
    if has("merfolk", "merrow", "sahuagin"):
        return human(skin=C("5aa090") if not has("merfolk") else C("a8c0d0"), right_hand=("staff", C("40a0ff")) if has("merfolk") else "shortsword", tail=C("4a8a78"), torso=C("2a6a68"), pants=C("2a6a68"))
    # 虫
    if has("wasp"):
        return bug(col=C("d0b030"), kind="wasp")
    if has("centipede"):
        return bug(col=C("a05a30"), kind="centipede")
    if has("beetle"):
        return bug(col=C("6a3a28"), kind="beetle", glow=C("ffa030"))
    if has("ankheg"):
        return bug(col=C("a0804a"), kind="beetle")
    if has("stirge"):
        return bug(col=C("a05a48"), kind="wasp", head=C("c07060"))
    if has("spider", "drider", "ettercap") and not has("phase") and not has("drider", "ettercap"):
        return ms.render_spider if has("giant-spider") else (lambda d, ph, c0=C("5a4a3a") if has("wolf") else C("3a3a4a"): ms.render_spider(d, ph, c0))
    if has("phase-spider"):
        return lambda d, ph: ms.render_spider(d, ph, C("3a5a8a"))
    if has("drider"):
        return human(skin="dark", hair=C("e8e8f0"), torso=C("2a2030"), pants=C("2a2030"), boots=C("2a2030"), wide=2, right_hand="shortsword")
    if has("ettercap"):
        return human(skin=C("a0a890"), hair=None, torso=C("6a6a58"), sleeve=C("a0a890"), pants=C("5a5a48"), fangs=True, wide=1)
    # 鳥
    if has("roc", "giant-eagle", "giant-owl", "giant-vulture", "giant-hawk"):
        return bird(col=C("8a6a40") if not has("owl", "vulture") else C("6a6a60"), big=3, legs=C("e0b040"))
    if has("eagle", "hawk", "vulture", "raven", "owl", "axe-beak", "blood-hawk"):
        c0 = C("22222c") if has("raven") else C("8a6a40") if has("eagle", "hawk") else C("6a5a50")
        return bird(col=c0, big=1 if has("owl", "vulture", "axe") else 0, legs=C("e0b040"))
    if has("griffon"):
        return quad(col=C("c0a050"), bl=15, bh=8, lh=4, hw=6, hh=6, beak=C("e8c050"), wing=C("e0e0d0"), tail=C("c0a050"), tl=5, ears=True, eye=C("e8c050"))
    if has("hippogriff"):
        return quad(col=C("9a7a50"), bl=15, bh=8, lh=5, hw=6, hh=6, beak=C("e8c050"), wing=C("e0e0d0"), tail=C("6a4a30"), tl=4, eye=C("e8c050"))
    if has("pegasus"):
        return quad(col=C("f0f0f4"), bl=15, bh=8, lh=6, hw=6, hh=6, snout=2, wing=C("ffffff"), tail=C("d0d8e8"), tl=6, mane=C("d0d8e8"), neck=True)
    if has("harpy"):
        return human(skin="tan", hair=C("3a2a38"), torso=C("6a5a70"), wings=C("6a5a48"), pants=C("c0a050"), boots=C("c0a050"), tail=C("6a5a48"))
    if has("cockatrice"):
        return bird(col=C("a0a870"), beak=C("e0b040"), legs=C("e0b040"), tail_back=True)
    if has("basilisk"):
        return quad(col=C("6a7a4a"), bl=15, bh=7, lh=3, hw=6, hh=5, snout=2, tail=C("6a7a4a"), tl=6, eye=C("f0f060"), plates=C("a0b070"))
    if has("manticore"):
        return quad(col=C("b06a40"), bl=16, bh=9, lh=5, hw=7, hh=7, snout=1, wing=C("6a4a38"), tail=C("b06a40"), tl=6, spike_tail=C("e0d8c0"), mane=C("8a4a30"), fangs=True)
    if has("chimera"):
        return quad(col=C("b09050"), bl=16, bh=9, lh=5, hw=7, hh=7, snout=1, horns=C("e0d8c0"), wing=C("6a4a38"), tail=C("5a8a48"), tl=6, mane=C("8a6a30"), fangs=True)
    if has("sphinx"):
        return quad(col=C("c8a860"), bl=16, bh=9, lh=4, hw=7, hh=7, snout=0, wing=C("e0d8b0"), tail=C("c8a860"), tl=5, mane=C("3a6ac0"), eye=C("20a0e0"))
    if has("owlbear"):
        return quad(col=C("7a5a3a"), bl=14, bh=11, lh=4, hw=7, hh=7, beak=C("e0b040"), ears=True, eye=RED, hy=-1)
    # 馬など
    if has("nightmare"):
        return quad(col=C("22222c"), bl=16, bh=9, lh=7, hw=6, hh=6, snout=2, mane=C("e05030"), tail=C("e05030"), tl=6, eye=C("ffa030"), neck=True)
    if has("unicorn"):
        return quad(col=C("f8f8ff"), bl=15, bh=8, lh=7, hw=6, hh=6, snout=2, horns=C("f0d860"), mane=C("e0b0e8"), tail=C("e0b0e8"), tl=6, neck=True)
    if has("horse", "mule", "pony", "camel", "elk", "deer", "goat"):
        col = C("8a5a38") if has("riding", "pony") else C("5a4a40") if has("warhorse", "draft", "mule") else C("a08860") if has("camel", "goat") else C("8a6a48")
        return quad(col=col, bl=15, bh=8, lh=7 if not has("goat", "pony", "mule") else 5, hw=6, hh=6, snout=2, ears=True, tail=col, tl=5, mane=shade(col, 0.6) if has("horse") else None,
                    antler=C("e0d0a8") if has("elk", "deer") else None, horns=C("e0d8c0") if has("goat") else None, hump=col if has("camel") else None, neck=True)
    if has("centaur"):
        return quad(col=C("8a5a38"), bl=14, bh=8, lh=6, hw=5, hh=5, snout=1, tail=C("3a2a20"), tl=5, mane=C("3a2a20"), neck=True, hy=-4)
    # 獣
    if has("elephant", "mammoth"):
        return quad(col=C("8a8a90") if has("elephant") else C("6a4a38"), bl=18, bh=12, lh=5, hw=8, hh=8, trunk=C("7a7a80") if has("elephant") else C("5a3a28"), tusk=C("f0f0e0"), ears=True, hy=-1, tail=None)
    if has("triceratops"):
        return quad(col=C("7a8a58"), bl=18, bh=10, lh=4, hw=8, hh=7, horns=C("f0f0e0"), plates=C("a05a40"), tail=C("7a8a58"), tl=4, snout=1)
    if has("tyrannosaurus"):
        return quad(col=C("6a7a48"), bl=16, bh=10, lh=7, hw=8, hh=7, snout=3, fangs=True, tail=C("6a7a48"), tl=7, hy=-3, eye=RED, neck=True)
    if has("rhinoceros", "gorgon"):
        return quad(col=C("8a8a90") if has("rhino") else C("5a5a60"), bl=16, bh=10, lh=4, hw=7, hh=7, horns=C("f0f0e0"), snout=1, tail=C("8a8a90"), tl=3, ears=True)
    if has("boar", "minotaur"):
        pass
    if has("bear"):
        c0 = C("e8e8ee") if has("polar") else C("2a2420") if has("black") else C("6a4a30")
        return quad(col=c0, bl=14, bh=10, lh=4, hw=7, hh=7, snout=1, ears=True, eye=EYE)
    if has("boar"):
        return quad(col=C("6a4a38"), bl=14, bh=9, lh=4, hw=6, hh=6, snout=2, tusk=C("f0f0e0"), ears=True, tail=C("6a4a38"), tl=2)
    if has("saber"):
        return quad(col=C("c0a060"), bl=15, bh=8, lh=5, hw=6, hh=6, snout=1, ears=True, fangs=True, tusk=C("f0f0e0"), tail=C("c0a060"), tl=4)
    if has("lion", "tiger", "panther", "cat", "weasel", "jackal", "hyena", "mastiff", "wolf", "dog", "worg", "hound", "lizard", "crocodile", "badger", "frog", "toad", "baboon", "ape", "rat", "ankheg", "stirge"):
        big = has("giant", "dire", "winter", "worg", "tiger", "lion", "crocodile")
        c0 = (C("c8a050") if has("lion") else C("d08a30") if has("tiger") else C("22222c") if has("panther") else C("8a8a90") if has("wolf", "worg") else
              C("5a7a48") if has("lizard", "crocodile", "frog", "toad") else C("6a5a50"))
        if has("winter"):
            c0 = C("d8e4f0")
        if has("hell"):
            c0 = C("a03a28")
        return quad(col=c0, bl=14 if big else 10, bh=7 if big else 5, lh=4 if not has("lizard", "crocodile") else 2,
                    hw=6 if big else 5, hh=5, snout=2 if not has("frog", "toad", "ape", "baboon") else 0, ears=not has("lizard", "crocodile", "frog", "toad"),
                    stripes=C("302018") if has("tiger") else None, spots=C("3a2a20") if has("hyena", "frog", "toad") else None,
                    mane=C("8a6030") if has("lion") else None, tail=c0 if not has("frog", "toad", "ape", "baboon") else None, tl=4,
                    fangs=has("wolf", "worg", "hound", "dog", "crocodile", "lion", "tiger", "hyena"), eye=RED if has("hell", "worg", "death") else EYE)
    return None


def build(m):
    i, typ, size = m["i"], m["t"], m["z"]
    fn = rules(i, typ, size)
    if fn is not None:
        return fn
    return TYPE_DEFAULT.get(typ if not typ.startswith("swarm") else "swarm", TYPE_DEFAULT["beast"])(i, size) if callable(TYPE_DEFAULT.get(typ)) else None


# ---------- 人型や特殊な個別定義 ----------
SPECIAL = {
    # 悪魔・魔神
    "imp": human(skin="red", torso=C("902a28"), pants=C("902a28"), wings=C("5a1a1a"), horns=C("e0d0a0"), tail=C("c04a40"), ears=C("c04a40"), fangs=True, eye=C("ffe040")),
    "quasit": human(skin=C("7a4a98"), torso=C("5a3a78"), pants=C("5a3a78"), wings=C("3a2a58"), horns=C("e0d0a0"), tail=C("7a4a98"), fangs=True, eye=C("ffe040")),
    "lemure": human(skin=C("a08a98"), torso=C("8a7a88"), sleeve=C("8a7a88"), pants=C("7a6a78"), wide=1),
    "dretch": human(skin=C("a0907a"), torso=C("8a7a68"), pants=C("7a6a58"), fangs=True, wide=1),
    "homunculus": human(skin=C("78a068"), torso=C("78a068"), pants=C("78a068"), wings=C("a8c898"), fangs=True, eye=RED),
}
DEVILS = {  # 色, 角, 翼
    "barbed-devil": (C("a0402c"), True, True), "bearded-devil": (C("8a3030"), True, False), "bone-devil": (C("d0c8b0"), True, True),
    "chain-devil": (C("902a30"), False, False), "horned-devil": (C("7a2020"), True, True), "ice-devil": (C("90b8d8"), True, True),
    "erinyes": (C("d0a880"), False, True), "glabrezu": (C("a05a3a"), True, False), "marilith": (C("a0402c"), False, False),
    "nalfeshnee": (C("7a5a40"), True, True), "pit-fiend": (C("b02820"), True, True), "balor": (C("902018"), True, True),
    "vrock": (C("8a8a60"), True, True), "hezrou": (C("5a7a50"), True, False), "succubus-incubus": (C("d09080"), True, True),
    "rakshasa": (C("d0a050"), False, False), "night-hag": (C("5a4a70"), False, False), "oni": (C("4a6ac0"), True, False),
}


def devil(name):
    col, horn, wing = DEVILS[name]
    w = 2 if name in ("bone-devil", "horned-devil", "nalfeshnee", "pit-fiend", "balor", "hezrou", "glabrezu") else 1
    kw = dict(skin=col, torso=shade(col, 0.85), sleeve=col, pants=shade(col, 0.7), boots=shade(col, 0.6), glove=col, wide=w, tail=col, eye=C("ffe040"), fangs=True)
    if horn:
        kw["horns"] = C("e0d0a0")
    if wing:
        kw["wings"] = shade(col, 0.6)
    if name in ("erinyes", "succubus-incubus"):
        kw.update(hair=C("2a1a20"), female=True, torso=C("5a2030"), pants=C("5a2030"))
    if name in ("rakshasa",):
        kw.update(head="hat", head_col=C("e0d0a0"), hat_band=C("d2a63c"), torso=C("8a2a2a"), robe=True, robe_col=C("8a2a2a"), trim=C("d2a63c"), trim2=C("d2a63c"), cuff=C("d2a63c"), sash=None, belt=C("d2a63c"))
        kw.pop("wide", None)
    if name == "night-hag":
        kw.update(head="hood", head_col=C("2a2038"), hair=None, torso=C("3a2a4a"), robe=True, robe_col=C("3a2a4a"), trim=C("5a4a70"), trim2=C("5a4a70"), cuff=C("5a4a70"), sash=None, right_hand=("staff", C("a060ff")))
        kw.pop("wide", None); kw.pop("tail", None)
    if name in ("pit-fiend", "balor", "marilith", "chain-devil", "horned-devil", "barbed-devil", "glabrezu"):
        kw["right_hand"] = "sword"
    return human(**kw)


SPECIAL.update({k: devil(k) for k in DEVILS})
SPECIAL.update({
    # 人間系
    "bandit-captain": human(head="hood", head_col=C("5a3030"), mask=C("2a1818"), cape=C("5a3030"), torso=C("5a3a30"), chest=C("8a8a96"), right_hand="sword", left_hand="dagger"),
    "berserker": human(skin="tan", hair=C("c06030"), torso=C("6a3a2a"), sleeve=C("c0a080"), pants=C("5a4a3a"), fur=True, wide=2, right_hand="sword"),
    "hobgoblin": human(skin=C("b87a3a"), head="helmet", head_col=C("8a3030"), torso=C("8a3030"), chest=C("a84a4a"), pants=C("4a3028"), right_hand="sword", left_hand="shield"),
    "knight": human(skin="tan", head="helmet", head_col=C("9aa4b6"), plume=C("3a5ac0"), torso=C("9aa4b6"), chest=C("b8c0d0"), shoulder=C("b4bccb"), pants=C("5a6272"), boots=C("5a6272"), right_hand="sword", left_hand="shield"),
    "veteran": human(skin="tan", head="helmet", head_col=C("7a8090"), torso=C("6a6a78"), chest=C("8a90a0"), right_hand="sword", left_hand="shield"),
    "spy": human(head="hood", head_col=C("2e2e3a"), mask=C("1e1e28"), cape=C("2e2e3a"), torso=C("3a3a4a"), right_hand="dagger"),
    "ogre": human(skin="ogre", torso=C("6a4a30"), sleeve=C("6a4a30"), pants=C("4a3a2a"), wide=3, fur=True, tusks=C("f0f0e0"), right_hand=("mace", None)),
    "minotaur": human(skin=C("7a5030"), torso=C("5a3a28"), pants=C("4a3a2a"), wide=3, horns=C("f0f0e0"), muzzle=C("9a7050"), right_hand="sword"),
    "minotaur-skeleton": human(skin=C("dcd8c8"), torso=C("cfc8b4"), chest=C("e8e2d0"), pants=C("cfc8b4"), wide=3, horns=C("a09878"), muzzle=C("dcd8c8"), eye=C("e04040"), right_hand="sword"),
    "ogre-zombie": human(skin=C("7a9a6a"), torso=C("5a4a38"), pants=C("4a4038"), wide=3, bandage=None, fangs=True),
    "troll": human(skin="troll", hair=C("2a3a20"), torso=C("4a5a3a"), sleeve=C("6a8a5a"), pants=C("3a3a30"), wide=2, ears=C("6a8a5a"), tusks=C("e0d8b0")),
    "ettin": human(skin="ogre", torso=C("6a4a30"), pants=C("4a3a2a"), wide=3, fur=True, tusks=C("f0f0e0")),
    "bugbear": human(skin=C("a07a40"), torso=C("6a4a30"), pants=C("4a3a2a"), wide=2, ears=C("a07a40"), fangs=True, fur=True, right_hand="mace"),
    "gnoll": human(skin=C("b8a060"), torso=C("6a5030"), pants=C("4a3a2a"), wide=1, ears=C("b8a060"), muzzle=C("c8b070"), fangs=True, right_hand="shortsword"),
    "orc": human(skin="orc", torso=C("5a4a38"), chest=C("7a7a80"), pants=C("4a3a2a"), wide=2, tusks=C("f0f0e0"), right_hand="sword"),
    "kobold": human(skin=C("a05a3a"), torso=C("5a4a38"), pants=C("4a3a2a"), horns=C("e0d0a0"), tail=C("a05a3a"), ears=C("a05a3a"), right_hand="dagger"),
    "lizardfolk": human(skin=C("5a8a50"), torso=C("5a8a50"), pants=C("6a5a3a"), tail=C("5a8a50"), muzzle=C("6a9a5a"), right_hand="shortsword", left_hand="shield"),
    "grimlock": human(skin=C("8a8a98"), torso=C("6a6a78"), pants=C("5a5a68"), wide=1, bandage=C("a0a0b0"), right_hand="mace"),
    "drow": human(skin=C("5a4a70"), hair=C("e8e8f0"), torso=C("2a2a3a"), pants=C("2a2a3a"), cape=C("2a2a3a"), right_hand="shortsword", left_hand="dagger"),
    "duergar": human(skin=C("8a8a98"), head="helmet", head_col=C("6a6a78"), beard=C("5a5a68"), torso=C("6a6a78"), chest=C("8a8a98"), right_hand="mace", left_hand="shield"),
    "deep-gnome-svirfneblin": human(skin=C("a0a090"), head="hat", head_col=C("6a5a48"), beard=C("e0e0d8"), torso=C("6a5a48"), right_hand="mace"),
    "gargoyle": human(skin="stone", torso=C("7a7a82"), pants=C("6a6a72"), wings=C("6a6a72"), horns=C("5a5a62"), tail=C("7a7a82"), fangs=True, eye=RED, wide=1),
    "lich": human(skin=C("dcd8c8"), head="hood", head_col=C("2a1a4a"), torso=C("3a2a6a"), robe=True, robe_col=C("3a2a6a"), trim=C("a060ff"), trim2=C("a060ff"), cuff=C("a060ff"), sash=None, right_hand=("staff", C("a060ff"))),
    "mummy": human(skin=C("c8b898"), torso=C("d0c0a0"), sleeve=C("d0c0a0"), pants=C("d0c0a0"), boots=C("c0b090"), bandage=C("a89878"), eye=RED),
    "mummy-lord": human(skin=C("c8b898"), head="hat", head_col=C("d0b050"), torso=C("d0c0a0"), sleeve=C("d0c0a0"), pants=C("d0c0a0"), bandage=C("a89878"), eye=C("40e0ff"), right_hand=("staff", C("40e0ff"))),
    "ghoul": human(skin=C("8a9a8a"), torso=C("5a5a50"), pants=C("4a4a40"), fangs=True, wide=0, eye=C("e0e040")),
    "ghast": human(skin=C("7a8a7a"), torso=C("4a4a40"), pants=C("3a3a30"), fangs=True, eye=C("e04040"), wide=1),
    "wight": human(skin=C("8a8a98"), head="helmet", head_col=C("5a5a68"), torso=C("4a4a58"), chest=C("6a6a78"), eye=C("e04040"), right_hand="sword"),
    "vampire-spawn": human(skin=C("c8c8d0"), hair=C("2a2020"), torso=C("5a2030"), pants=C("2a2030"), fangs=True, eye=RED, cape=C("5a2030")),
    "vampire-vampire": human(skin=C("d0d0d8"), hair=C("1a1418"), torso=C("2a1a2a"), pants=C("1a1a24"), fangs=True, eye=RED, cape=C("8a1a2a")),
    "vampire-mist": ghost(col=C("a02030"), kind="wisp", alpha=170),
    "flesh-golem": human(skin=C("a0907a"), torso=C("8a7a68"), sleeve=C("a0907a"), pants=C("5a5a68"), wide=3, bandage=C("5a3a30")),
    "clay-golem": human(skin=C("b08050"), torso=C("b08050"), sleeve=C("a07040"), pants=C("a07040"), boots=C("906030"), glove=C("b08050"), wide=3, eye=C("ffd040")),
    "stone-golem": human(skin="stone", torso=C("8a8a90"), sleeve=C("7a7a82"), pants=C("7a7a82"), boots=C("6a6a72"), glove=C("8a8a90"), wide=3, eye=C("ffd040")),
    "iron-golem": human(skin=C("8a90a0"), torso=C("7a8090"), sleeve=C("6a7080"), pants=C("6a7080"), boots=C("5a6070"), glove=C("8a90a0"), wide=3, eye=C("ff6040")),
    "shield-guardian": human(skin=C("9a8a70"), torso=C("8a7a60"), chest=C("6a8ac0"), pants=C("7a6a50"), wide=3, eye=C("40c0ff"), left_hand="shield"),
    "animated-armor": human(skin=C("2a2a30"), head="helmet", head_col=C("8a90a0"), plume=C("a03030"), torso=C("8a90a0"), chest=C("a0a8b8"), shoulder=C("b0b8c8"), pants=C("6a7080"), boots=C("6a7080"), glove=C("6a7080"), right_hand="sword", eye=C("40c0ff")),
    "flying-sword": bug(col=C("b4bccb"), kind="wasp"),
    "rug-of-smothering": ooze(col=C("a03a3a"), kind="mound", leaf=C("e0c060"), w=10, top=18),
    "mimic": ooze(col=C("7a5230"), w=10, top=14, kind="mound", leaf=C("d2a63c")),
    # 妖精・植物
    "dryad": human(skin=C("90b878"), hair=C("3a7a30"), hair_long=True, torso=C("4a7a38"), robe=True, robe_col=C("4a7a38"), trim=C("90b878"), trim2=C("90b878"), cuff=C("90b878"), sash=None, female=True),
    "green-hag": human(head="hood", head_col=C("3a4a30"), skin=C("6a8a58"), torso=C("3a4a30"), robe=True, robe_col=C("3a4a30"), trim=C("5a6a48"), trim2=C("5a6a48"), cuff=C("5a6a48"), sash=None, right_hand=("staff", C("80ff60"))),
    "sea-hag": human(head="hood", head_col=C("2a4a4a"), skin=C("6a9088"), torso=C("2a4a4a"), robe=True, robe_col=C("2a4a4a"), trim=C("4a7a7a"), trim2=C("4a7a7a"), cuff=C("4a7a7a"), sash=None, right_hand=("staff", C("60ffd0"))),
    "satyr": human(skin=C("b88860"), hair=C("5a3a28"), torso=C("b88860"), sleeve=C("b88860"), pants=C("6a4a30"), boots=C("4a3020"), horns=C("e0d0a0"), ears=C("b88860"), tail=C("6a4a30"), right_hand=("staff", None)),
    "sprite": bird(col=C("90e0a0"), wing=C("e0f8ff"), big=-1, beak=C("f0f0a0")),
    "treant": human(skin=C("6a4a30"), hair=C("3a7a30"), torso=C("5a3a28"), sleeve=C("5a3a28"), pants=C("4a3020"), boots=C("4a3020"), glove=C("6a4a30"), wide=4, eye=C("e0e040")),
    "awakened-tree": human(skin=C("6a4a30"), hair=C("3a7a30"), torso=C("5a3a28"), sleeve=C("5a3a28"), pants=C("4a3020"), boots=C("4a3020"), glove=C("6a4a30"), wide=3, eye=C("e0e040")),
    "awakened-shrub": plant(col=C("4a7a38")),
    "violet-fungus": plant(col=C("7a4a9a"), kind="mushroom"),
    "shrieker": plant(col=C("a08a98"), kind="mushroom"),
    # 巨人
    "hill-giant": human(skin=C("c8a078"), torso=C("6a5a3a"), pants=C("5a4a30"), wide=4, fur=True, right_hand=("mace", None)),
    "stone-giant": human(skin="stone", torso=C("6a6a70"), pants=C("5a5a60"), wide=4, right_hand=("mace", None)),
    "frost-giant": human(skin=C("c8d8e8"), hair=C("d0d8e8"), torso=C("5a6a8a"), pants=C("4a5a7a"), wide=4, fur=True, right_hand="sword"),
    "fire-giant": human(skin=C("c07050"), hair=C("2a1a18"), torso=C("2a2a30"), chest=C("8a3a2a"), pants=C("3a3030"), wide=4, right_hand="sword"),
    "cloud-giant": human(skin=C("a0b8e0"), hair=C("e0e8f8"), torso=C("e0e8f8"), pants=C("c0d0e8"), wide=4, right_hand="sword"),
    "storm-giant": human(skin=C("90a8e0"), hair=C("3a3a8a"), torso=C("3a4a9a"), pants=C("2a3a7a"), wide=4, right_hand=("staff", C("ffe840"))),
    "tarrasque": quad(col=C("7a4a3a"), bl=20, bh=12, lh=6, hw=9, hh=8, horns=C("e0d0b0"), snout=2, plates=C("5a3a2a"), tail=C("7a4a3a"), tl=8, spike_tail=C("e0d0b0"), fangs=True, eye=RED),
    # 精霊
    "air-elemental": ghost(col=C("d0e0f0"), kind="wisp", alpha=180),
    "fire-elemental": ghost(col=C("ff7a20"), kind="wisp"),
    "water-elemental": ghost(col=C("4a8ae0"), kind="wisp", alpha=200),
    "earth-elemental": human(skin=C("7a6048"), torso=C("6a5038"), sleeve=C("7a6048"), pants=C("5a4028"), wide=3, eye=C("ffd040")),
    "magmin": human(skin=C("3a2a28"), torso=C("e05020"), sleeve=C("3a2a28"), pants=C("3a2a28"), eye=C("ffe040")),
    "salamander": snake(col=C("e05a20"), th=4, hood=True, pat=C("ffd040")),
    "azer": human(skin=C("c07040"), head="helmet", head_col=C("d0a040"), beard=C("e05020"), torso=C("b08030"), chest=C("d0a040"), wide=1, right_hand="mace"),
    "dust-mephit": bird(col=C("c8b890"), wing=C("e0d0b0"), big=-1), "magma-mephit": bird(col=C("e05020"), wing=C("902010"), big=-1),
    "ice-mephit": bird(col=C("a0d8f0"), wing=C("e0f4ff"), big=-1), "steam-mephit": bird(col=C("d0d8e0"), wing=C("f0f4f8"), big=-1),
    "djinni": ghost(col=C("5aa0e0"), kind="ghost", alpha=230, eye=C("ffe040")),
    "efreeti": ghost(col=C("e0502a"), kind="ghost", alpha=230, eye=C("ffe040")),
    # 不死
    "ghost": ghost(col=C("c8d8e8")), "specter": ghost(col=C("98a8c0"), alpha=170), "shadow": ghost(col=C("2a2a38"), alpha=190, eye=RED),
    "wraith": ghost(col=C("4a4a5a"), kind="wraith", eye=RED), "will-o-wisp": ghost(col=C("90f0c0"), kind="wisp"),
    "invisible-stalker": ghost(col=C("b0c0d0"), kind="wisp", alpha=90),
    "warhorse-skeleton": quad(col=C("dcd8c8"), bl=15, bh=8, lh=7, hw=6, hh=6, snout=2, tail=C("a09878"), tl=5, neck=True, eye=RED),
    # 天使
    "deva": human(skin=C("f0e0d0"), hair=C("f0d870"), torso=C("f8f8f8"), robe=True, robe_col=C("f8f8f8"), trim=C("d2a63c"), trim2=C("d2a63c"), cuff=C("d2a63c"), sash=C("d2a63c"), wings=C("ffffff"), right_hand="mace"),
    "planetar": human(skin=C("90b890"), hair=C("f0f0f0"), torso=C("f8f8f8"), robe=True, robe_col=C("f8f8f8"), trim=C("d2a63c"), trim2=C("d2a63c"), cuff=C("d2a63c"), sash=C("d2a63c"), wings=C("ffffff"), wide=2, right_hand="sword"),
    "solar": human(skin=C("f0d8a0"), hair=C("f8e890"), torso=C("f8f0d0"), robe=True, robe_col=C("f8f0d0"), trim=C("e8b830"), trim2=C("e8b830"), cuff=C("e8b830"), sash=C("e8b830"), wings=C("fffff0"), wide=2, right_hand="sword"),
    # 怪異
    "medusa": snake(col=C("5aa070"), th=4, hood=True),
    "doppelganger": human(skin=C("a0a0b0"), head="hood", head_col=C("4a4a5a"), torso=C("4a4a5a"), eye=C("e0e040")),
    "cloaker": ghost(col=C("2a2a3a"), eye=RED, kind="wraith"),
    "grick": snake(col=C("6a6a5a"), th=4, hood=True),
    "otyugh": ooze(col=C("6a7a48"), w=11, top=12, kind="mound", leaf=C("4a5a38")),
    "rust-monster": quad(col=C("c07040"), bl=12, bh=7, lh=4, hw=5, hh=5, snout=1, tail=C("c07040"), tl=6, spike_tail=C("a05030"), ears=True, horns=C("a05030")),
    "death-dog": quad(col=C("4a3a38"), bl=12, bh=6, lh=4, hw=6, hh=5, snout=2, ears=True, fangs=True, eye=RED, tail=C("4a3a38"), tl=4, horns=None),
    "blink-dog": quad(col=C("a0a0c0"), bl=11, bh=6, lh=4, hw=5, hh=5, snout=2, ears=True, tail=C("a0a0c0"), tl=4),
    "behir": snake(col=C("3a5a98"), th=5, hood=True),
    "guardian-naga": snake(col=C("48a0a8"), th=4, hood=True),
    "gynosphinx": quad(col=C("c8a860"), bl=16, bh=9, lh=4, hw=7, hh=7, wing=C("e0d8b0"), tail=C("c8a860"), tl=5, mane=C("a04a8a"), eye=C("a04a8a")),
    "androsphinx": quad(col=C("c8a860"), bl=16, bh=9, lh=4, hw=7, hh=7, wing=C("e0d8b0"), tail=C("c8a860"), tl=5, mane=C("8a5a2a"), eye=C("e0a020")),
    "giant-wasp": bug(col=C("d0b030"), kind="wasp"),
})
SPECIAL["ghost"] = SPECIAL["ghost"]
for k in ("ogre-zombie",):
    pass

SPECIAL.update({
    "commoner": human(skin="tan", hair=C("6a4a30"), torso=C("8a7a58"), pants=C("5a4a38"), right_hand=("staff", None)),
    "noble": human(skin="tan", hair=C("e0c070"), torso=C("7a2a5a"), chest=C("d2a63c"), pants=C("3a2a4a"), right_hand="shortsword"),
    "guard": human(skin="tan", head="helmet", head_col=C("8a90a0"), torso=C("4a5a8a"), chest=C("8a90a0"), right_hand=("staff", None), left_hand="shield"),
    "cultist": human(head="hood", head_col=C("5a2a2a"), skin="tan", torso=C("5a2a2a"), robe=True, robe_col=C("5a2a2a"), trim=C("2a1a1a"), trim2=C("2a1a1a"), cuff=C("2a1a1a"), sash=None, right_hand="dagger"),
    "cult-fanatic": human(head="hood", head_col=C("3a2a5a"), skin="tan", torso=C("3a2a5a"), robe=True, robe_col=C("3a2a5a"), trim=C("c0a040"), trim2=C("c0a040"), cuff=C("c0a040"), sash=None, right_hand="dagger", left_hand="dagger"),
    "tribal-warrior": human(skin=C("b88860"), hair=C("2a1a18"), torso=C("b88860"), sleeve=C("b88860"), pants=C("6a4a30"), fur=True, right_hand="shortsword", left_hand="shield"),
    "acolyte": human(head="hood", head_col=C("c8c0a0"), skin="tan", torso=C("c8c0a0"), robe=True, robe_col=C("c8c0a0"), trim=C("8a6a3a"), trim2=C("8a6a3a"), cuff=C("8a6a3a"), sash=None, right_hand="mace"),
    "priest": human(head="hood", head_col=C("e8e8f0"), skin="tan", torso=C("e8e8f0"), robe=True, robe_col=C("e8e8f0"), trim=C("d2a63c"), trim2=C("d2a63c"), cuff=C("d2a63c"), sash=C("d2a63c"), right_hand="mace", left_hand="book"),
    "scout": human(head="hood", head_col=C("4a6a3a"), skin="tan", cape=C("4a6a3a"), torso=C("5a6a3a"), right_hand="shortsword"),
    "thug": human(skin="tan", hair=None, torso=C("3a3a42"), chest=C("6a6a72"), wide=1, pants=C("2e2e38"), right_hand="mace"),
    "druid": human(head="hood", head_col=C("4a6a3a"), skin="tan", beard=C("a0a090"), torso=C("4a6a3a"), robe=True, robe_col=C("4a6a3a"), trim=C("8a6a3a"), trim2=C("8a6a3a"), cuff=C("8a6a3a"), sash=None, right_hand=("staff", C("80e060"))),
    "gladiator": human(skin="tan", head="helmet", head_col=C("b0a060"), plume=C("c03030"), torso=C("8a5a38"), chest=C("b0a060"), wide=1, right_hand="sword", left_hand="shield"),
    "half-red-dragon-veteran": human(skin=C("c05040"), head="helmet", head_col=C("7a8090"), torso=C("6a6a78"), chest=C("8a90a0"), wings=C("902a28"), horns=C("e0d0a0"), right_hand="sword", left_hand="shield"),
    "xorn": ooze(col=C("8a7a68"), w=9, top=14, kind="mound", leaf=C("e0c060")),
    "mage": human(head="hat", head_col=C("2a5a9a"), skin="tan", beard=C("a0a0b0"), torso=C("2a5a9a"), robe=True, robe_col=C("2a5a9a"), trim=C("d2a63c"), trim2=C("d2a63c"), cuff=C("d2a63c"), sash=None, right_hand=("staff", C("5ac8ff"))),
    "archmage": human(head="hat", head_col=C("8a2a8a"), skin="tan", beard=C("e8e8f0"), torso=C("8a2a8a"), robe=True, robe_col=C("8a2a8a"), trim=C("d2a63c"), trim2=C("d2a63c"), cuff=C("d2a63c"), sash=None, right_hand=("staff", C("ff6af0"))),
    "assassin": human(head="hood", head_col=C("1e1e26"), mask=C("101018"), cape=C("1e1e26"), skin="tan", torso=C("2a2a34"), right_hand="dagger", left_hand="dagger"),
    "vampire-bat": bird(col=C("3a2a44"), wing=C("2a1a34"), beak=C("c04040"), big=0),
})

# 型ごとの代表(esheet_type_<type>)
TYPES = {
    "aberration": eyeball(col=C("8a6a98"), eyes=4),
    "beast": quad(col=C("8a6a48"), bl=13, bh=7, lh=4, hw=6, hh=5, snout=2, ears=True, tail=C("8a6a48"), tl=4),
    "celestial": SPECIAL["deva"],
    "construct": SPECIAL["stone-golem"],
    "dragon": dragon("green-dragon-wyrmling", "M"),
    "elemental": ghost(col=C("e0a040"), kind="wisp"),
    "fey": SPECIAL["dryad"],
    "fiend": SPECIAL["horned-devil"],
    "giant": SPECIAL["hill-giant"],
    "humanoid": human(skin="tan", torso=C("6a5a48"), right_hand="shortsword"),
    "monstrosity": quad(col=C("8a6a50"), bl=15, bh=9, lh=5, hw=7, hh=6, snout=1, horns=C("e0d8c0"), tail=C("8a6a50"), tl=5, fangs=True),
    "ooze": ooze(col=C("78b068")),
    "plant": plant(col=C("4a7a38")),
    "swarm": swarm(col=C("4a3a30")),
    "undead": SPECIAL["zombie"] if "zombie" in SPECIAL else ms.MONSTERS["zombie"],
}


def main():
    data = json.load(open(os.path.join(HERE, "..", "godot", "data", "encounter-data.json")))
    os.makedirs(ms.OUT, exist_ok=True)
    made, skipped, missing = [], [], []
    for m in data["monsters"]:
        i = m["i"]
        if i in ms.MONSTERS:
            skipped.append(i)
            continue
        fn = SPECIAL.get(i) or rules(i, m["t"], m["z"])
        if fn is None:
            tp = "swarm" if m["t"].startswith("swarm") else m["t"]
            fn = TYPES.get(tp)
            missing.append(i)
        sheet_from(fn).save(os.path.join(ms.OUT, f"esheet_{i}.png"))
        made.append(i)
    for tp, fn in TYPES.items():
        sheet_from(fn).save(os.path.join(ms.OUT, f"esheet_type_{tp}.png"))
    print(f"{len(made)} monster sheets (+{len(skipped)} hand-drawn kept, {len(TYPES)} type fallbacks)")
    print("fallback-by-type (no specific rule):", len(missing))
    open("/tmp/claude-0/monster-fallback.txt", "w").write("\n".join(missing))
    if "--preview" in sys.argv:
        ids = sorted(set(made) | set(skipped))
        cols = 12
        cell = 64
        rows = (len(ids) + cols - 1) // cols
        im = Image.new("RGBA", (cols * cell, rows * cell), (60, 70, 60, 255))
        for k, i in enumerate(ids):
            sh = Image.open(os.path.join(ms.OUT, f"esheet_{i}.png"))
            fr = sh.crop((0, 0, 64, 64))
            im.alpha_composite(fr, ((k % cols) * cell, (k // cols) * cell))
        im.save("/tmp/claude-0/monster-preview.png")
        print("preview", len(ids))


if __name__ == "__main__":
    main()
