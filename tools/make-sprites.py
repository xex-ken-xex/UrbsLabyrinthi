#!/usr/bin/env python3
"""ドット絵のスプライトシートを、コードで描いて godot/assets/sprites/ に書き出す。

形式(AI 画像生成のプロンプトと同じ。docs/asset-prompts.md):
  64×64 のコマを 12 枚、横一列(768×64)。透過PNG。
  コマ 1〜3: 下向き(DOWN)、4〜6: 左向き(LEFT)、7〜9: 右向き(RIGHT)、10〜12: 上向き(UP)。各向きに、歩きの3コマ。
内部は 32×32 の格子で描いて、輪郭を足し、最近傍で2倍にする(ドットの粒が、64×64 の中で 2×2 になる)。

  sheet_<M|F>_<WARRIOR|CLERIC|FIGHTER|THIEF|MAGE>.png   仲間(男女 × 5種)
  esheet_<SRDのindex>.png                               魔物
使い方: python3 tools/make-sprites.py            (godot/assets/sprites/ に書く)
"""
import os, sys
from PIL import Image

G = 32
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "sprites")
OUTLINE = (16, 14, 24, 255)


def C(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


class Canvas:
    def __init__(self):
        self.im = Image.new("RGBA", (G, G), (0, 0, 0, 0))
        self.px = self.im.load()

    def p(self, x, y, c):
        if c is not None and 0 <= x < G and 0 <= y < G:
            self.px[int(x), int(y)] = c

    def r(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.p(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        x0, y0, x1, y1 = round(x0), round(y0), round(x1), round(y1)
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.p(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)

    def outline(self):
        src = self.im.copy().load()
        for y in range(G):
            for x in range(G):
                if src[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < G and 0 <= ny < G and src[nx, ny][3] > 0:
                            self.px[x, y] = OUTLINE
                            break


# ---------- 持ち物 ----------
STEEL = C("b4bccb")
STEEL_D = C("6c7686")
GOLD = C("d2a63c")
WOOD = C("7a5230")


def item(c, kind, x, y, side=False):
    """(x, y) は、握っている手の位置。縦に立てて持つ"""
    if kind == "sword":
        c.r(x, y - 9, x, y - 1, STEEL); c.p(x, y - 10, C("e8ecf4")); c.r(x - 1, y, x + 1, y, GOLD); c.p(x, y + 1, WOOD)
    elif kind == "shortsword":
        c.r(x, y - 6, x, y - 1, STEEL); c.r(x - 1, y, x + 1, y, GOLD); c.p(x, y + 1, WOOD)
    elif kind == "dagger":
        c.r(x, y - 4, x, y - 1, STEEL); c.p(x, y, GOLD); c.p(x, y + 1, WOOD)
    elif kind == "shield":
        w = 2 if side else 5
        c.r(x - w // 2 - 1, y - 6, x + w // 2 + 1, y + 2, STEEL_D)
        c.r(x - w // 2, y - 5, x + w // 2, y + 1, STEEL)
        if not side:
            c.r(x, y - 5, x, y + 1, GOLD); c.r(x - 1, y - 3, x + 1, y - 3, GOLD)
    elif kind == "mace":
        c.r(x, y - 5, x, y + 1, WOOD); c.r(x - 1, y - 8, x + 1, y - 5, STEEL_D); c.p(x, y - 7, STEEL)
    elif kind == "book":
        c.r(x - 1, y - 4, x + 2, y + 1, C("2c4a9a")); c.r(x - 1, y - 4, x - 1, y + 1, GOLD); c.p(x + 1, y - 2, GOLD)
    elif kind == "staff":
        c.r(x, y - 15, x, y + 3, WOOD)
    elif kind == "wand":
        c.r(x, y - 8, x, y, WOOD)


def crystal(c, x, y, col):
    c.r(x - 1, y - 1, x + 1, y + 1, col); c.p(x, y - 2, shade(col, 1.3)); c.p(x, y, shade(col, 1.5))


def cross(c, x, y, col):
    c.r(x, y - 2, x, y + 2, col); c.r(x - 1, y - 1, x + 1, y - 1, col)


# ---------- 人型 ----------
def headgear_front(c, st, bob, back):
    hx0, hx1, hy0, hy1 = 12, 19, 4 + bob, 11 + bob
    skin, hc = st["skin"], st.get("head_col")
    h = st["head"]
    # 顔(地)
    if h in ("bare", "hat", "veil", "hood"):
        c.r(hx0, hy0 + 1, hx1, hy1, skin)
    if h == "helmet":
        c.r(hx0 - 1, hy0, hx1 + 1, hy1, hc)
        c.r(hx0 - 1, hy0, hx1 + 1, hy0, shade(hc, 1.25))
        c.r(hx0, hy0 + 1, hx0, hy1, shade(hc, 0.8))
        if not back:
            c.r(hx0 + 1, hy0 + 4, hx1 - 1, hy0 + 4, C("101018"))       # 目の細い隙間
            c.r(15, hy0 + 5, 16, hy1, shade(hc, 0.75))                 # 鼻の板
        if st.get("plume"):
            c.r(15, hy0 - 2, 16, hy0 - 1, st["plume"])
    elif h == "hood":
        c.r(hx0 - 1, hy0, hx1 + 1, hy1, hc)
        c.r(hx0 - 1, hy0, hx1 + 1, hy0, shade(hc, 1.2))
        if not back:
            c.r(hx0 + 1, hy0 + 2, hx1 - 1, hy1 - 1, skin)
            c.r(hx0 + 1, hy0 + 2, hx1 - 1, hy0 + 2, shade(hc, 0.7))
    elif h == "hat":
        c.r(hx0 - 2, hy0 + 1, hx1 + 2, hy0 + 2, hc)                    # つば
        c.r(hx0, hy0 - 3, hx1, hy0, hc)
        c.r(hx0 + 2, hy0 - 6, hx1 - 2, hy0 - 4, hc)
        c.r(15, hy0 - 8, 16, hy0 - 7, hc)
        c.r(hx0, hy0 + 1, hx1, hy0 + 1, shade(hc, 1.3))
        if st.get("hat_band"):
            c.r(hx0, hy0, hx1, hy0, st["hat_band"])
    elif h == "veil":
        c.r(hx0 - 1, hy0, hx1 + 1, hy0 + 2, hc)
        c.r(hx0 - 1, hy0, hx0, hy1 + 2, hc)
        c.r(hx1, hy0, hx1 + 1, hy1 + 2, hc)
        c.r(hx0, hy0, hx1, hy0, shade(hc, 1.15))
        if st.get("trim"):
            c.r(hx0 - 1, hy0 + 2, hx1 + 1, hy0 + 2, st["trim"])
    if st.get("muzzle") and not back:
        mz = st["muzzle"]
        c.r(13, 8 + bob, 18, 11 + bob, mz); c.p(14, 10 + bob, C("14141c")); c.p(17, 10 + bob, C("14141c"))
    if st.get("horns"):
        hc2 = st["horns"]
        c.r(hx0 - 1, hy0 - 3, hx0, hy0, hc2); c.p(hx0 - 2, hy0 - 4, hc2); c.r(hx1, hy0 - 3, hx1 + 1, hy0, hc2); c.p(hx1 + 2, hy0 - 4, hc2)
    if st.get("ears"):
        e2 = st.get("ear_col", skin)
        c.r(hx0 - 3, hy0 + 2, hx0 - 1, hy0 + 3, e2); c.p(hx0 - 4, hy0 + 1, e2); c.r(hx1 + 1, hy0 + 2, hx1 + 3, hy0 + 3, e2); c.p(hx1 + 4, hy0 + 1, e2)
    # 髪
    hair = st.get("hair")
    if hair and h in ("bare", "hat", "veil"):
        if back or h == "bare":
            c.r(hx0, hy0 + (1 if h == "bare" else 2), hx1, hy0 + 2, hair)
        if back:
            c.r(hx0, hy0, hx1, hy1 - 1, hair)
        elif h == "bare":
            c.r(hx0, hy0 + 1, hx0 + 1, hy0 + 4, hair); c.r(hx1 - 1, hy0 + 1, hx1, hy0 + 4, hair)
        if st.get("hair_long"):
            c.r(hx0 - 1, hy0 + 2, hx0, hy1 + 5, hair); c.r(hx1, hy0 + 2, hx1 + 1, hy1 + 5, hair)
            if back:
                c.r(hx0, hy1, hx1, hy1 + 6, hair)
    if st.get("ponytail") and h in ("helmet", "bare", "hood"):
        if back:
            c.r(15, hy0 + 2, 16, hy1 + 5, st["ponytail"]); c.r(14, hy0 + 3, 17, hy0 + 4, st["ponytail"])
        else:
            c.r(hx1 + 1, hy0 + 1, hx1 + 2, hy0 + 5, st["ponytail"])
    # 目、覆面、髭
    if not back and h in ("bare", "hat", "veil", "hood"):
        ec = st.get("eye", C("14141c"))
        c.p(14, 7 + bob, ec); c.p(17, 7 + bob, ec)
        if st.get("tusks"):
            c.p(13, 10 + bob, st["tusks"]); c.p(18, 10 + bob, st["tusks"]); c.p(13, 11 + bob, st["tusks"]); c.p(18, 11 + bob, st["tusks"])
        if st.get("fangs"):
            c.p(14, 10 + bob, C("f0f0f0")); c.p(17, 10 + bob, C("f0f0f0"))
        if st.get("mask"):
            c.r(hx0, 8 + bob, hx1, hy1, st["mask"]); c.r(hx0, 8 + bob, hx1, 8 + bob, shade(st["mask"], 1.25))
        elif st.get("beard"):
            c.r(hx0, 9 + bob, hx1, hy1 + 3, st["beard"]); c.r(14, 9 + bob, 17, 9 + bob, shade(st["beard"], 0.8))
        else:
            c.p(15, 9 + bob, shade(skin, 0.8)); c.p(16, 9 + bob, shade(skin, 0.8))
    if back and st.get("mask") and h == "hood":
        pass


def wings_front(c, st, bob):
    wc = st["wings"]
    for x0, x1, sg in ((3, 9, -1), (22, 28, 1)):
        c.r(x0, 8 + bob, x1, 17 + bob, wc)
        c.r(x0 if sg < 0 else x1 - 3, 17 + bob, x0 + 3 if sg < 0 else x1, 21 + bob, wc)
        c.r(x0, 8 + bob, x1, 8 + bob, shade(wc, 1.3))
        c.line(x0, 9 + bob, x0 + 5 if sg < 0 else x1 - 5, 18 + bob, shade(wc, 0.7))


def humanoid_front(c, st, sw, bob, back):
    cx = 16
    female = st.get("female")
    tw0, tw1 = (12, 19) if female else (11, 20)
    tw0 -= st.get("wide", 0); tw1 += st.get("wide", 0)
    if st.get("wings") and not back:
        wings_front(c, st, bob)
    if st.get("tail") and not back:
        c.line(16, 26, 16, 30, st["tail"]); c.p(15, 30, st["tail"]); c.p(17, 31, st["tail"])
    ty0, ty1 = 12 + bob, 21 + bob
    robe = st.get("robe")
    torso, trim, belt = st["torso"], st.get("trim"), st.get("belt")
    # マント(背面)
    if st.get("cape") and back:
        c.r(tw0 - 1, ty0, tw1 + 1, 27 + bob, st["cape"]); c.r(tw0 - 1, ty0, tw1 + 1, ty0, shade(st["cape"], 1.2))
    # 脚、または裾
    if robe:
        rb = st["robe_col"]
        c.r(tw0 - 1, 21 + bob, tw1 + 1, 27, rb)
        c.r(tw0 - 1, 27, tw1 + 1, 27, st.get("trim") or shade(rb, 0.8))
        c.r(15, 22 + bob, 16, 27, st.get("trim2") or shade(rb, 1.2))
        for fx, fy in ((14, 28 + sw), (18, 28 - sw)):
            c.r(fx - 1, 28, fx + 1, min(29, 28 + abs(sw)), st["boots"])
    else:
        lfoot, rfoot = 28 + sw, 28 - sw
        c.r(13, 21 + bob, 15, lfoot, st["pants"]); c.r(17, 21 + bob, 19, rfoot, st["pants"])
        c.r(13, lfoot - 2, 15, lfoot, st["boots"]); c.r(17, rfoot - 2, 19, rfoot, st["boots"])
        c.r(13, 21 + bob, 13, lfoot - 3, shade(st["pants"], 0.8)); c.r(19, 21 + bob, 19, rfoot - 3, shade(st["pants"], 0.8))
        c.r(13, lfoot - 3, 15, lfoot - 3, shade(st["boots"], 1.2)); c.r(17, rfoot - 3, 19, rfoot - 3, shade(st["boots"], 1.2))
    # 胴
    c.r(tw0, ty0, tw1, ty1, torso)
    c.r(tw0, ty0, tw1, ty0, shade(torso, 1.25))
    c.r(tw0, ty0, tw0, ty1, shade(torso, 0.82))
    if st.get("chest") and (not back or st.get("shoulder")):
        c.r(tw0 + 2, ty0 + 2, tw1 - 2, ty0 + 5, st["chest"])
    if not back:
        if st.get("cross"):
            cross(c, cx, ty0 + 4, st["cross"])
        if trim and robe:
            c.r(15, ty0, 16, ty1, trim)
        if st.get("sash"):
            c.r(tw0, ty0 + 3, tw1, ty0 + 3, st["sash"]); c.r(tw0, ty0 + 4, tw1, ty0 + 4, shade(st["sash"], 0.8))
    if belt:
        c.r(tw0, ty1 - 2, tw1, ty1 - 2, belt)
        if not back:
            c.p(cx, ty1 - 2, GOLD)
    if female and not robe:
        c.r(tw0 - 1, ty1 - 1, tw1 + 1, ty1, shade(torso, 0.9))
    # 腕、肩
    asw = (sw, 0, -sw)[0] if False else sw
    larm_dy, rarm_dy = -sw, sw          # 左(画面の左)の腕は、足と逆に振る
    for ax0, ax1, dy in ((9, 10, larm_dy), (21, 22, rarm_dy)):
        sleeve = st.get("sleeve", torso)
        c.r(ax0, 13 + bob, ax1, 17 + bob + dy, sleeve)
        c.r(ax0, 18 + bob + dy, ax1, 19 + bob + dy, st.get("glove", st["skin"]))
        if st.get("cuff"):
            c.r(ax0, 17 + bob + dy, ax1, 17 + bob + dy, st["cuff"])
        if st.get("bracer") and not robe:
            c.r(ax0, 16 + bob + dy, ax1, 17 + bob + dy, st["bracer"])
    if st.get("shoulder"):
        sc = st["shoulder"]
        for x0 in (9, 20):
            c.r(x0, 12 + bob, x0 + 2, 14 + bob, sc); c.r(x0, 12 + bob, x0 + 2, 12 + bob, shade(sc, 1.3))
    if st.get("wings") and back:
        wings_front(c, st, bob)
    if st.get("tail") and back:
        c.line(16, 24, 16, 30, st["tail"]); c.p(15, 30, st["tail"]); c.p(17, 31, st["tail"])
    if st.get("fur"):
        for yy in range(ty0 + 1, ty1, 3):
            c.r(tw0, yy, tw1, yy, shade(torso, 0.8))
    if st.get("bandage"):
        for yy in range(ty0 + 1, ty1 + 1, 2):
            c.r(tw0, yy, tw1, yy, st["bandage"])
    # 頭
    headgear_front(c, st, bob, back)
    # 持ち物: 画面の左(その人の右手)と右(左手)。後ろ向きは逆
    rh, lh = st.get("right_hand"), st.get("left_hand")
    rx, lx = (8, 23)
    if back:
        rx, lx = lx, rx
    ry = 19 + bob + (larm_dy if not back else rarm_dy)
    ly = 19 + bob + (rarm_dy if not back else larm_dy)
    if lh:
        item_draw(c, lh, lx, ly, back)
    if rh:
        item_draw(c, rh, rx, ry, back)
    if st.get("two_hands"):
        pass


def item_draw(c, spec, x, y, back):
    kind, extra = spec if isinstance(spec, tuple) else (spec, None)
    item(c, kind, x, y)
    if kind == "staff" and extra:
        crystal(c, x, y - 16, extra)
    if kind == "wand" and extra:
        crystal(c, x, y - 9, extra)


def humanoid_side(c, st, sw, bob):
    """左向き。右向きは、これを反転する"""
    female = st.get("female")
    if st.get("wings"):
        wc = st["wings"]
        c.r(17, 8 + bob, 25, 17 + bob, wc); c.r(21, 17 + bob, 25, 21 + bob, wc); c.r(17, 8 + bob, 25, 8 + bob, shade(wc, 1.3))
    if st.get("tail"):
        c.line(19, 24, 25, 25, st["tail"]); c.line(25, 25, 27, 22, st["tail"])
    ty0, ty1 = 12 + bob, 21 + bob
    robe = st.get("robe")
    torso = st["torso"]
    if st.get("cape"):
        c.r(18, ty0, 21, 26 + bob, st["cape"]); c.r(17, ty0, 21, ty0, shade(st["cape"], 1.2))
    # 脚(奥は暗く)
    near_x, far_x = 14 - 2 * sw, 14 + 2 * sw
    if robe:
        rb = st["robe_col"]
        c.r(12, 21 + bob, 19, 27, rb); c.r(12, 27, 19, 27, st.get("trim") or shade(rb, 0.8))
        c.r(near_x, 28, near_x + 2, 28, st["boots"]); c.r(far_x, 28, far_x + 2, 28, shade(st["boots"], 0.8))
    else:
        for x, dark in ((far_x, 0.75), (near_x, 1.0)):
            c.r(x, 21 + bob, x + 2, 28, shade(st["pants"], dark))
            c.r(x - 1, 26, x + 2, 28, shade(st["boots"], dark))
    # 胴
    wd = st.get("wide", 0)
    c.r(13 - wd, ty0, 19 + wd, ty1, torso)
    c.r(13 - wd, ty0, 19 + wd, ty0, shade(torso, 1.25)); c.r(19 + wd, ty0, 19 + wd, ty1, shade(torso, 0.8))
    if st.get("bandage"):
        for yy in range(ty0 + 1, ty1 + 1, 2):
            c.r(13 - wd, yy, 19 + wd, yy, st["bandage"])
    if st.get("belt"):
        c.r(13, ty1 - 2, 19, ty1 - 2, st["belt"])
    if st.get("chest"):
        c.r(13, ty0 + 2, 15, ty0 + 5, st["chest"])
    if robe and st.get("trim"):
        c.r(13, ty1, 13, 27, st["trim"])
    # 頭
    hx0, hy0, hy1 = 11, 4 + bob, 11 + bob
    skin, h, hc = st["skin"], st["head"], st.get("head_col")
    c.r(hx0, hy0 + 1, 18, hy1, skin)
    c.p(hx0 - 1, 8 + bob, skin)
    if h == "helmet":
        c.r(hx0 - 1, hy0, 19, hy1, hc); c.r(hx0 - 1, hy0, 19, hy0, shade(hc, 1.25))
        c.r(hx0 - 1, hy0 + 4, hx0 + 3, hy0 + 4, C("101018"))
        c.r(17, hy0 + 1, 19, hy1, shade(hc, 0.8))
        if st.get("plume"):
            c.r(14, hy0 - 2, 17, hy0 - 1, st["plume"])
    elif h == "hood":
        c.r(hx0 + 1, hy0, 19, hy1, hc); c.r(hx0, hy0, 19, hy0, shade(hc, 1.2))
        c.r(hx0, hy0 + 2, hx0 + 3, hy1 - 1, skin)
        c.r(hx0, hy0 + 1, hx0 + 4, hy0 + 1, hc)
        c.r(16, hy0 + 2, 19, hy1 + 2, hc)
    elif h == "hat":
        c.r(hx0 - 2, hy0 + 1, 20, hy0 + 2, hc)
        c.r(hx0 + 1, hy0 - 3, 18, hy0, hc)
        c.r(hx0 + 3, hy0 - 6, 16, hy0 - 4, hc)
        c.r(14, hy0 - 8, 15, hy0 - 7, hc)
        c.r(hx0 + 1, hy0 + 1, 19, hy0 + 1, shade(hc, 1.3))
        if st.get("hat_band"):
            c.r(hx0 + 1, hy0, 18, hy0, st["hat_band"])
    elif h == "veil":
        c.r(hx0, hy0, 19, hy0 + 2, hc); c.r(15, hy0, 19, hy1 + 2, hc); c.r(hx0, hy0, 19, hy0, shade(hc, 1.15))
        if st.get("trim"):
            c.r(hx0, hy0 + 2, 19, hy0 + 2, st["trim"])
    hair = st.get("hair")
    if hair and h in ("bare", "hat", "veil"):
        if h == "bare":
            c.r(hx0, hy0 + 1, 18, hy0 + 2, hair)
        c.r(15, hy0 + 1, 19, hy1 - 1, hair)
        if st.get("hair_long"):
            c.r(15, hy0 + 2, 19, hy1 + 6, hair)
    if st.get("ponytail") and h in ("helmet", "bare", "hood"):
        c.r(19, hy0 + 2, 20, hy1 + 4, st["ponytail"]); c.r(19, hy0 + 2, 21, hy0 + 3, st["ponytail"])
    if st.get("horns"):
        c.r(14, hy0 - 3, 15, hy0, st["horns"]); c.p(13, hy0 - 4, st["horns"]); c.r(17, hy0 - 2, 18, hy0, st["horns"])
    if st.get("ears"):
        e2 = st.get("ear_col", skin)
        c.r(17, hy0 + 2, 20, hy0 + 3, e2); c.p(21, hy0 + 1, e2)
    if st.get("tusks"):
        c.p(hx0, 10 + bob, st["tusks"]); c.p(hx0, 11 + bob, st["tusks"])
    if st.get("muzzle"):
        c.r(hx0 - 3, 8 + bob, hx0 + 2, 11 + bob, st["muzzle"]); c.p(hx0 - 3, 9 + bob, C("14141c"))
    if h in ("bare", "hat", "veil", "hood"):
        c.p(hx0 + 1, 7 + bob, st.get("eye", C("14141c")))
        if st.get("mask"):
            c.r(hx0 - 1, 8 + bob, 16, hy1, st["mask"])
        elif st.get("beard"):
            c.r(hx0, 9 + bob, 15, hy1 + 3, st["beard"])
    # 腕と持ち物(手前の腕)
    ax = 15 + 2 * sw
    c.r(ax, 13 + bob, ax + 2, 17 + bob, st.get("sleeve", torso))
    c.r(ax, 18 + bob, ax + 2, 19 + bob, st.get("glove", skin))
    if st.get("shoulder"):
        c.r(ax - 1, 12 + bob, ax + 3, 14 + bob, st["shoulder"])
    near_item = st.get("left_hand") or st.get("right_hand")
    if st.get("left_hand") == "shield":
        item(c, "shield", ax - 1, 19 + bob, side=True)
    far = st.get("right_hand") if st.get("left_hand") == "shield" else None
    other = None
    for spec in (st.get("right_hand"), st.get("left_hand")):
        if spec and spec != "shield":
            other = spec
            break
    if other:
        item_draw(c, other, ax - 1 + (1 if isinstance(other, tuple) else 0), 19 + bob, False)
    if st.get("dual"):
        item(c, "shortsword", ax + 3 - 2 * sw, 19 + bob)


def render_humanoid(st, d, ph, ol=True):
    c = Canvas()
    sw = (1, 0, -1)[ph]
    bob = -1 if ph == 1 else 0
    if d in ("L", "R"):
        humanoid_side(c, st, sw, bob)
    else:
        humanoid_front(c, st, sw, bob, back=(d == "U"))
    if ol:
        c.outline()
    return c.im.transpose(Image.FLIP_LEFT_RIGHT) if d == "R" else c.im


def sheet_from(fn):
    """fn(dir, phase) -> 32x32 画像。DOWN、LEFT、RIGHT、UP の順に3コマずつ並べ、2倍にして 768×64 にする"""
    sheet = Image.new("RGBA", (64 * 12, 64), (0, 0, 0, 0))
    i = 0
    for d in ("D", "L", "R", "U"):
        for ph in range(3):
            fr = fn(d, ph).resize((64, 64), Image.NEAREST)
            sheet.paste(fr, (64 * i, 0))
            i += 1
    return sheet


# ---------- 仲間 ----------
SKIN = C("e0b48c")
SKIN_F = C("e8bf9a")
HEROES = {}


def hero(name, **st):
    st.setdefault("skin", SKIN_F if name.startswith("F_") else SKIN)
    st["female"] = name.startswith("F_")
    HEROES[name] = st


STEEL_PLATE = C("9aa4b6")
hero("M_WARRIOR", head="helmet", head_col=C("8d97a8"), plume=C("a83a3a"), torso=C("8d97a8"), chest=C("a9b3c4"), shoulder=C("b4bccb"),
     sleeve=C("5a6272"), glove=C("4a4f5c"), belt=C("3b2e26"), pants=C("2e3038"), boots=C("5a6272"), cross=None,
     right_hand="sword", left_hand="shield")
hero("F_WARRIOR", head="helmet", head_col=C("8d97a8"), ponytail=C("7a4a2a"), torso=C("8d97a8"), chest=C("a9b3c4"), shoulder=C("b4bccb"),
     sleeve=C("5a6272"), glove=C("4a4f5c"), belt=C("3b2e26"), pants=C("3a3028"), boots=C("5a6272"),
     right_hand="sword", left_hand="shield")
hero("M_CLERIC", head="hood", head_col=C("2f4f9a"), torso=C("2f4f9a"), robe=True, robe_col=C("2f4f9a"), trim=GOLD, trim2=C("e8e8f0"),
     sleeve=C("e8e8f0"), cuff=GOLD, glove=SKIN, belt=C("5a3c26"), boots=C("4a3426"), sash=None, right_hand="mace", left_hand="book")
hero("F_CLERIC", head="veil", head_col=C("f0f0f6"), trim=GOLD, hair=C("c89a5a"), torso=C("f0f0f6"), robe=True, robe_col=C("f0f0f6"),
     sleeve=C("f0f0f6"), cuff=GOLD, glove=SKIN_F, sash=GOLD, boots=C("8a6a3a"), right_hand=("staff", C("f0c850")))
hero("M_FIGHTER", head="bare", hair=C("3a2e2a"), torso=C("3a3a46"), chest=C("7e8496"), sleeve=C("3a3a46"), bracer=C("5a7aa8"), glove=C("2a2a32"),
     belt=C("5a7aa8"), pants=C("2e2e38"), boots=C("2a2a32"), right_hand="shortsword", left_hand="shortsword", dual=True)
hero("F_FIGHTER", head="bare", hair=C("7a4a2a"), ponytail=C("7a4a2a"), torso=C("4a3228"), chest=C("a84a4a"), sleeve=C("4a3228"), bracer=C("8a8fa0"),
     glove=C("2a2a32"), belt=C("a84a4a"), pants=C("3a2c28"), boots=C("2a2a32"), right_hand="shortsword", left_hand="shortsword", dual=True)
hero("M_THIEF", head="hood", head_col=C("34303e"), mask=C("26242e"), cape=C("34303e"), torso=C("4a3a58"), chest=C("5a4a68"), sleeve=C("34303e"),
     glove=C("2a2830"), belt=C("6a4a30"), pants=C("2e2c36"), boots=C("26242e"), right_hand="dagger")
hero("F_THIEF", head="hood", head_col=C("34303e"), mask=C("7a2a38"), cape=C("34303e"), torso=C("6a2a36"), chest=C("7a3a48"), sleeve=C("34303e"),
     glove=C("2a2830"), belt=C("6a4a30"), pants=C("2e2c36"), boots=C("26242e"), right_hand="dagger", left_hand="dagger")
hero("M_MAGE", head="hat", head_col=C("5a3c98"), hat_band=GOLD, beard=C("e8e8ee"), torso=C("5a3c98"), robe=True, robe_col=C("4a3488"),
     trim=GOLD, trim2=C("2c3c8a"), sleeve=C("2c3c8a"), cuff=GOLD, glove=SKIN, belt=C("8a6a30"), boots=C("3a2c4a"), right_hand=("staff", C("5ac8ff")))
hero("F_MAGE", head="hat", head_col=C("4a2a78"), hat_band=C("c8a040"), hair=C("2a1c3a"), hair_long=True, torso=C("4a2a78"), robe=True,
     robe_col=C("4a2a78"), trim=GOLD, trim2=C("7a52b8"), sleeve=C("4a2a78"), cuff=GOLD, glove=SKIN_F, belt=C("8a6a30"), boots=C("2e2040"),
     right_hand=("wand", C("c07aff")))


# ---------- 魔物 ----------
def render_rat(d, ph, col=C("8a7060"), belly=C("b8a090")):
    c = Canvas()
    bob = -1 if ph == 1 else 0
    sw = (1, 0, -1)[ph]
    if d in ("L", "R"):
        c.r(9, 17 + bob, 21, 24 + bob, col); c.r(9, 17 + bob, 21, 17 + bob, shade(col, 1.2))
        c.r(5, 15 + bob, 11, 22 + bob, col)                         # 頭
        c.p(4, 19 + bob, C("e0a0a0")); c.p(6, 17 + bob, C("101018")); c.r(6, 13 + bob, 7, 14 + bob, shade(col, 1.2)); c.r(9, 13 + bob, 10, 15 + bob, shade(col, 1.2))
        c.line(21, 20 + bob, 28, 17 + bob + sw, C("c09080"))        # 尾
        for x, o in ((10, sw), (17, -sw)):
            c.r(x, 24 + bob, x + 2, 27, shade(col, 0.8)); c.r(x + o, 27, x + o + 2, 27, shade(col, 0.7))
        c.r(10, 23 + bob, 20, 24 + bob, belly)
    else:
        back = d == "U"
        c.r(10, 12 + bob, 21, 25 + bob, col); c.r(10, 12 + bob, 21, 12 + bob, shade(col, 1.2))
        if not back:
            c.r(12, 18 + bob, 19, 25 + bob, belly)
            c.r(11, 8 + bob, 20, 14 + bob, col); c.r(10, 5 + bob, 12, 8 + bob, shade(col, 1.2)); c.r(19, 5 + bob, 21, 8 + bob, shade(col, 1.2))
            c.p(13, 11 + bob, C("101018")); c.p(18, 11 + bob, C("101018")); c.r(15, 14 + bob, 16, 15 + bob, C("e0a0a0"))
        else:
            c.r(11, 8 + bob, 20, 12 + bob, col); c.r(10, 5 + bob, 12, 8 + bob, shade(col, 1.2)); c.r(19, 5 + bob, 21, 8 + bob, shade(col, 1.2))
            c.line(16, 25 + bob, 16, 30, C("c09080"))
        c.r(11, 25 + bob, 13, 28 + (sw if sw > 0 else 0), shade(col, 0.8)); c.r(18, 25 + bob, 20, 28 + (-sw if sw < 0 else 0), shade(col, 0.8))
    c.outline()
    return c.im.transpose(Image.FLIP_LEFT_RIGHT) if d == "R" else c.im


def render_slime(d, ph, col=C("78a878")):
    c = Canvas()
    squash = (0, 2, 1)[ph]
    w = 9 + (1 if ph == 1 else 0)
    top = 14 + squash
    for y in range(top, 28):
        t = (y - top) / max(1, 27 - top)
        half = int(round(5 + (w - 5) * (t ** 0.6)))
        c.r(16 - half, y, 16 + half, y, shade(col, 1.25 - 0.5 * t))
    c.r(11, 26, 21, 27, shade(col, 0.7))
    if d != "U":
        ex = {"D": (13, 18), "L": (11, 14), "R": (17, 20)}[d]
        for x in ex:
            c.r(x, top + 4, x + 1, top + 6, C("f8f8f8")); c.p(x + (0 if d != "R" else 1), top + 5, C("101018"))
    c.p(13, top + 2, C("d8f0d8")); c.p(14, top + 1, C("d8f0d8"))
    c.outline()
    return c.im


def render_spider(d, ph, col=C("3a3a4a")):
    c = Canvas()
    sw = (1, 0, -1)[ph]
    bob = -1 if ph == 1 else 0
    c.r(11, 14 + bob, 20, 24 + bob, col); c.r(11, 14 + bob, 20, 14 + bob, shade(col, 1.4))
    c.r(13, 9 + bob, 18, 14 + bob, shade(col, 1.15))
    if d != "U":
        c.p(14, 11 + bob, C("e04040")); c.p(17, 11 + bob, C("e04040")); c.p(15, 10 + bob, C("e04040")); c.p(16, 10 + bob, C("e04040"))
    c.r(14, 17 + bob, 17, 21 + bob, C("a83a3a"))
    for i in range(4):
        y = 14 + i * 3 + bob
        o = sw if i % 2 == 0 else -sw
        c.line(11, y, 5, y - 2 + o, shade(col, 1.5)); c.line(5, y - 2 + o, 3, y + 5, shade(col, 1.3))
        c.line(20, y, 26, y - 2 - o, shade(col, 1.5)); c.line(26, y - 2 - o, 28, y + 5, shade(col, 1.3))
    c.outline()
    return c.im


def render_bat(d, ph, col=C("5a4a6a")):
    c = Canvas()
    flap = (-4, 0, 4)[ph]
    c.r(14, 14, 17, 21, col); c.r(13, 10, 18, 14, shade(col, 1.15)); c.r(12, 8, 13, 10, col); c.r(18, 8, 19, 10, col)
    if d != "U":
        c.p(14, 12, C("e04040")); c.p(17, 12, C("e04040"))
    for s in (-1, 1):
        x0 = 14 if s < 0 else 17
        c.line(x0, 15, x0 + s * 9, 15 + flap, shade(col, 1.2)); c.line(x0 + s * 9, 15 + flap, x0 + s * 6, 22, shade(col, 0.9))
        c.line(x0 + s * 6, 22, x0 + s * 3, 19, shade(col, 0.9)); c.line(x0, 17, x0 + s * 6, 22, shade(col, 0.9))
    c.outline()
    return c.im


def mon_humanoid(name, **st):
    st.setdefault("skin", C("c8c8b8"))
    st.setdefault("female", False)
    return lambda d, ph: render_humanoid(st, d, ph)


MONSTERS = {
    "giant-rat": render_rat,
    "rat": lambda d, ph: render_rat(d, ph, C("6a5a50")),
    "gray-ooze": lambda d, ph: render_slime(d, ph, C("8a94a0")),
    "green-slime": lambda d, ph: render_slime(d, ph, C("78b068")),
    "giant-spider": render_spider,
    "giant-bat": render_bat,
    "bat": lambda d, ph: render_bat(d, ph, C("4a3a54")),
    "skeleton": mon_humanoid("skeleton", head="helmet", head_col=C("dcd8c8"), torso=C("cfc8b4"), chest=C("e8e2d0"), sleeve=C("cfc8b4"), glove=C("dcd8c8"),
                             pants=C("cfc8b4"), boots=C("dcd8c8"), belt=C("6a5a4a"), right_hand="shortsword", skin=C("dcd8c8")),
    "zombie": mon_humanoid("zombie", head="bare", hair=C("3a3a30"), skin=C("7a9a6a"), torso=C("6a5a48"), sleeve=C("5a4e40"), glove=C("7a9a6a"),
                           pants=C("4a4438"), boots=C("3a3830"), belt=C("3a3028")),
    "bandit": mon_humanoid("bandit", head="hood", head_col=C("5a4a38"), mask=C("3a2e26"), cape=C("4a3c2c"), torso=C("6a4a30"), sleeve=C("5a4030"),
                           glove=C("3a2e26"), pants=C("3a3430"), boots=C("2a2420"), belt=C("2a2420"), right_hand="shortsword", skin=C("d0a880")),
    "goblin": mon_humanoid("goblin", head="bare", hair=None, skin=C("7aa850"), torso=C("6a4a30"), sleeve=C("5a4030"), glove=C("7aa850"),
                           pants=C("4a3a2a"), boots=C("3a2c20"), belt=C("2a2018"), right_hand="dagger"),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for name, st in HEROES.items():
        sheet_from(lambda d, ph, s=st: render_humanoid(s, d, ph)).save(os.path.join(OUT, f"sheet_{name}.png"))
        n += 1
    for key, fn in MONSTERS.items():
        sheet_from(fn).save(os.path.join(OUT, f"esheet_{key}.png"))
        n += 1
    print(f"{n} sheets ->", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
