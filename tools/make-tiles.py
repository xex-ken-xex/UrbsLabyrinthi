#!/usr/bin/env python3
"""迷宮のマップチップ(32×32、つなぎ目なし)を、舞台ごとに描く。
  python3 tools/make-tiles.py            # godot/assets/tiles/ に書き出す
  python3 tools/make-tiles.py --preview  # /tmp/claude-0/tiles-preview.png に、並べた見本も作る
キー: floor_<舞台>(_2 _3 は、ばらつき用)、corr_<舞台>、wall_<舞台>(_2)、door_<舞台>、door_open_<舞台>、
      icon_stairs_up、icon_stairs_down、icon_chest、icon_trap(舞台によらない)"""
import math
import os
import sys

from PIL import Image

N = 32
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "tiles")


def C(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def sh(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (c[3] if len(c) > 3 else 255,)


def hsh(x, y, s):
    h = (x * 374761393 + y * 668265263 + s * 2147483647) & 0xffffffff
    h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
    return ((h ^ (h >> 16)) & 0xffff) / 65535.0


def vnoise(x, y, scale, seed):
    """つなぎ目のない値ノイズ(32 を scale 等分した格子で、端を回り込ませる)"""
    g = N // scale
    fx, fy = x / scale, y / scale
    x0, y0 = int(fx), int(fy)
    tx, ty = fx - x0, fy - y0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)

    def v(i, j):
        return hsh(i % g, j % g, seed)
    a = v(x0, y0) * (1 - tx) + v(x0 + 1, y0) * tx
    b = v(x0, y0 + 1) * (1 - tx) + v(x0 + 1, y0 + 1) * tx
    return a * (1 - ty) + b * ty


def fbm(x, y, seed):
    return vnoise(x, y, 16, seed) * 0.5 + vnoise(x, y, 8, seed + 1) * 0.3 + vnoise(x, y, 4, seed + 2) * 0.2


class T:
    def __init__(self, alpha=False):
        self.im = Image.new("RGBA", (N, N), (0, 0, 0, 0) if alpha else (0, 0, 0, 255))
        self.px = self.im.load()

    def p(self, x, y, c, wrap=True):
        if wrap:
            x, y = x % N, y % N
        if 0 <= x < N and 0 <= y < N and c is not None:
            self.px[x, y] = c

    def r(self, x0, y0, x1, y1, c, wrap=True):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.p(x, y, c, wrap)

    def fill(self, fn):
        for y in range(N):
            for x in range(N):
                self.px[x, y] = fn(x, y)

    def get(self, x, y):
        return self.px[x % N, y % N]


# ---------- 共通の部品 ----------
def stone_ground(base, seed, grain=0.22, speck=0.05):
    t = T()
    t.fill(lambda x, y: sh(base, 1.0 + (fbm(x, y, seed) - 0.5) * grain * 2))
    for _ in range(int(N * N * speck)):
        pass
    for i in range(18):
        x, y = int(hsh(i, 1, seed) * N), int(hsh(i, 2, seed) * N)
        t.p(x, y, sh(base, 0.78 if i % 2 else 1.22))
    return t


def flagstones(base, seed, rows=2, cols=2, gap=sh(C("000000"), 1), jitter=0.12, mortar=None):
    """敷石。rows×cols の石を、目地で区切る"""
    t = T()
    mortar = mortar or sh(base, 0.45)
    sw, sh_ = N // cols, N // rows
    for ry in range(rows):
        off = (sw // 2) if ry % 2 else 0
        for cx in range(cols):
            x0 = (cx * sw + off) % N
            k = 1.0 + (hsh(cx, ry, seed) - 0.5) * jitter * 2
            for yy in range(sh_):
                for xx in range(sw):
                    x, y = x0 + xx, ry * sh_ + yy
                    n = fbm(x, y, seed + cx + ry * 3)
                    c = sh(base, k * (0.9 + n * 0.25))
                    if xx == 0 or yy == 0:
                        c = mortar
                    elif xx == 1 or yy == 1:
                        c = sh(c, 1.15)
                    elif xx == sw - 1 or yy == sh_ - 1:
                        c = sh(c, 0.85)
                    t.p(x, y, c)
    return t


def speckle(t, seed, n, cols):
    for i in range(n):
        x, y = int(hsh(i, 5, seed) * N), int(hsh(i, 6, seed) * N)
        t.p(x, y, cols[i % len(cols)])


def blob(t, cx, cy, r, c, seed, soft=None):
    for y in range(cy - r - 1, cy + r + 2):
        for x in range(cx - r - 1, cx + r + 2):
            d = math.hypot(x - cx, y - cy) + (hsh(x % N, y % N, seed) - 0.5) * 1.6
            if d <= r:
                t.p(x, y, c if soft is None or d < r - 1 else soft)


# ---------- 舞台ごとの絵 ----------
THEMES = {}


def theme(name):
    def deco(fn):
        THEMES[name] = fn
        return fn
    return deco


@theme("fuyou")
def fuyou(kind, v):
    """湿った洞窟。苔、腐葉、青白い茸"""
    earth, moss, leaf, glow = C("414d38"), C("4f7a3a"), C("6a5a30"), C("a7cf86")
    if kind == "floor":
        t = stone_ground(sh(earth, 0.9), 10 + v, 0.3)
        for i in range(10 + v * 3):                                    # 腐葉
            x, y = int(hsh(i, 1, 20 + v) * N), int(hsh(i, 2, 20 + v) * N)
            c = sh(leaf, 0.8 + hsh(i, 3, 5) * 0.5)
            t.p(x, y, c); t.p(x + 1, y, c); t.p(x, y + 1, sh(c, 0.8))
        for i in range(3):
            blob(t, int(hsh(i, 7, 30 + v) * N), int(hsh(i, 8, 30 + v) * N), 2 + (i % 2), sh(moss, 0.9), i)
        if v == 1:                                                     # 小さな茸
            t.p(22, 12, C("cfe8d0")); t.p(21, 12, C("8ab090")); t.p(23, 12, C("8ab090")); t.p(22, 13, C("708a78"))
        if v == 2:
            t.p(8, 22, glow); t.p(9, 22, sh(glow, 0.7)); t.p(8, 23, sh(glow, 0.5))
        return t.im
    if kind == "corr":
        t = stone_ground(sh(earth, 0.78), 14, 0.26)
        for i in range(8):
            blob(t, int(hsh(i, 1, 41) * N), int(hsh(i, 2, 41) * N), 1, sh(earth, 1.35), i)
        speckle(t, 42, 10, [sh(leaf, 0.7), sh(moss, 0.6)])
        return t.im
    if kind == "wall":
        t = T()
        t.fill(lambda x, y: sh(C("2a3226"), 0.75 + fbm(x, y, 50 + v) * 0.7))
        for i in range(7):                                             # 岩の割れ目
            x, y = int(hsh(i, 1, 51 + v) * N), int(hsh(i, 2, 51 + v) * N)
            for k in range(5 + i % 4):
                t.p(x + k // 2, y + k, C("0c120c"))
        for x in range(N):                                             # 上から垂れる苔
            h = int(2 + 4 * vnoise(x, 0, 4, 60 + v) + (3 if v else 0))
            for y in range(h):
                t.p(x, y, sh(moss, 0.7 + 0.5 * (1 - y / max(1, h))))
        for i in range(2 + v):
            x = int(hsh(i, 3, 61 + v) * N); y = 20 + int(hsh(i, 4, 61 + v) * 8)
            t.p(x, y, glow); t.p(x, y + 1, sh(glow, 0.6)); t.p(x - 1, y + 1, sh(glow, 0.4))
        return t.im
    return None


@theme("sabi")
def sabi(kind, v):
    """錆鉄の坑道。砂利、錆びた軌条、坑木"""
    soil, rust, ore = C("4d4137"), C("9a5a30"), C("c8c0b0")
    if kind == "floor":
        t = stone_ground(soil, 70 + v, 0.3)
        for i in range(26):
            x, y = int(hsh(i, 1, 71 + v) * N), int(hsh(i, 2, 71 + v) * N)
            c = sh(soil, 1.4 if i % 2 else 0.6)
            t.p(x, y, c); t.p(x + 1, y, sh(c, 0.85))
        if v == 1:                                                     # 横切る軌条
            for x in range(N):
                t.p(x, 12, sh(rust, 0.7)); t.p(x, 13, rust); t.p(x, 20, sh(rust, 0.7)); t.p(x, 21, rust)
            for x in range(2, N, 8):
                t.r(x, 10, x + 2, 23, sh(C("6a4a2a"), 0.9)); t.r(x, 10, x + 2, 10, sh(C("8a6a40"), 1.0))
            for x in range(N):
                t.p(x, 13, sh(rust, 1.2)); t.p(x, 21, sh(rust, 1.2))
        if v == 2:
            blob(t, 22, 10, 3, sh(rust, 0.6), 3); t.p(21, 9, rust); t.p(23, 11, sh(rust, 1.3))
        return t.im
    if kind == "corr":                                                 # 板敷き
        t = T()
        for row in range(4):
            y0 = row * 8
            for yy in range(8):
                for x in range(N):
                    c = sh(C("6a4e30"), 0.85 + fbm(x, y0 + yy, 80 + row) * 0.4)
                    if yy == 0:
                        c = sh(C("2a1c10"), 1)
                    elif yy == 1:
                        c = sh(c, 1.18)
                    elif (x + row * 11) % 16 == 0:
                        c = sh(C("2a1c10"), 1)
                    t.p(x, y0 + yy, c)
            t.p((row * 9 + 4) % N, y0 + 4, C("2a1c10"))
        return t.im
    if kind == "wall":
        t = T()
        t.fill(lambda x, y: sh(C("3a2e28"), 0.7 + fbm(x, y, 90 + v) * 0.8))
        for i in range(3):                                             # 掘り尽くした鉱脈の白い筋
            x = int(hsh(i, 1, 91 + v) * N); y = int(hsh(i, 2, 91 + v) * N)
            for k in range(14):
                t.p(x + k, y + int(math.sin(k * 0.6 + i) * 2), sh(ore, 0.8 + 0.2 * (k % 2)))
        for i in range(10):
            x, y = int(hsh(i, 3, 92 + v) * N), int(hsh(i, 4, 92 + v) * N)
            t.p(x, y, sh(rust, 0.9))
        if v == 1:                                                     # 支保工の梁
            t.r(0, 0, N - 1, 4, C("6a4a2a")); t.r(0, 0, N - 1, 0, C("8a6a40")); t.r(0, 4, N - 1, 4, C("2a1c10"))
            t.r(14, 5, 18, N - 1, C("5a3e22")); t.r(14, 5, 14, N - 1, C("7a5a38")); t.r(18, 5, 18, N - 1, C("2a1c10"))
        return t.im
    return None


@theme("kagami")
def kagami(kind, v):
    """鏡の水廊。濡れた石と浅い水、磨かれた鏡面"""
    stone, water, lite = C("334852"), C("3a6a8a"), C("a8e0f0")
    if kind == "floor":
        t = flagstones(stone, 100 + v, 2, 2, jitter=0.08)
        if v:                                                          # 水に沈んだ床
            for y in range(N):
                for x in range(N):
                    k = 0.5 + 0.5 * math.sin((x + y * 0.6) * 0.5 + v)
                    t.px[x, y] = mix(t.get(x, y), sh(water, 0.8 + 0.4 * k), 0.55)
            for i in range(3):
                x, y = int(hsh(i, 1, 110 + v) * 24), int(hsh(i, 2, 110 + v) * 28)
                for k in range(6):
                    t.p(x + k, y, sh(lite, 0.9)); t.p(x + k, y + 1, sh(lite, 0.5)) if k in (0, 5) else None
        else:
            for i in range(5):
                x, y = int(hsh(i, 1, 120) * N), int(hsh(i, 2, 120) * N)
                t.p(x, y, sh(lite, 0.7)); t.p(x + 1, y, sh(lite, 0.5))
        return t.im
    if kind == "corr":
        t = flagstones(sh(stone, 0.85), 130, 4, 2, jitter=0.1)
        for i in range(8):
            x, y = int(hsh(i, 1, 131) * N), int(hsh(i, 2, 131) * N)
            t.p(x, y, sh(lite, 0.55))
        return t.im
    if kind == "wall":                                                 # 鏡面
        t = T()
        for y in range(N):
            for x in range(N):
                g = 0.55 + 0.35 * (y / N) + (fbm(x, y, 140 + v) - 0.5) * 0.3
                t.px[x, y] = sh(C("284050"), g)
        for k in range(N):                                             # 斜めの反射
            x = (k + 6 * (1 + v)) % N
            t.p(x, k, sh(lite, 0.75)); t.p(x + 1, k, sh(lite, 0.45))
            t.p(x + 5, k, sh(lite, 0.35))
        t.r(0, 0, N - 1, 1, C("1a2a34")); t.r(0, N - 2, N - 1, N - 1, C("1a2a34"))
        t.r(0, 0, 1, N - 1, C("1a2a34")); t.r(N - 2, 0, N - 1, N - 1, C("1a2a34"))
        return t.im
    return None


@theme("hone")
def hone(kind, v):
    """骨の大聖堂。骨の板、肋骨の柱、頭蓋の壁龕"""
    bone, dark = C("c8c0a8"), C("26202a")
    if kind == "floor":
        t = T()
        t.fill(lambda x, y: sh(C("4c4852"), 0.8 + fbm(x, y, 150 + v) * 0.5))
        for row in range(2):                                           # 骨の板
            for col in range(2):
                x0, y0 = col * 16 + (8 if row else 0), row * 16
                for yy in range(1, 15):
                    for xx in range(1, 15):
                        c = sh(bone, 0.36 + fbm(x0 + xx, y0 + yy, 160 + row * 2 + col + v) * 0.3)
                        if xx in (1, 14) or yy in (1, 14):
                            c = sh(c, 0.75)
                        t.p(x0 + xx, y0 + yy, c)
        for i in range(4):
            x, y = int(hsh(i, 1, 170 + v) * N), int(hsh(i, 2, 170 + v) * N)
            t.p(x, y, dark); t.p(x + 1, y + 1, dark)
        if v == 2:                                                     # 刻み(祈りの文句)
            for k in range(6):
                t.p(6 + k * 2, 8, dark)
        return t.im
    if kind == "corr":
        t = flagstones(C("6a665c"), 180, 2, 4, jitter=0.12, mortar=dark)
        return t.im
    if kind == "wall":
        t = T()
        t.fill(lambda x, y: sh(C("34303a"), 0.7 + fbm(x, y, 190 + v) * 0.6))
        if v == 0:                                                     # 肋骨が並ぶ
            for x0 in (3, 17):
                for y in range(N):
                    w = 5 - abs((y % 16) - 8) // 3
                    for xx in range(x0 - w // 2, x0 + w // 2 + 2):
                        t.p(xx, y, sh(bone, 0.55 + 0.4 * (xx - x0 + w) / (2 * w + 1)))
                t.r(x0 - 3, 0, x0 - 3, N - 1, dark)
        else:                                                          # 頭蓋の壁龕
            t.r(8, 6, 23, 25, C("0e0c12"))
            t.r(10, 8, 21, 21, sh(bone, 0.8)); t.r(11, 21, 20, 23, sh(bone, 0.7))
            t.r(12, 12, 14, 15, dark); t.r(17, 12, 19, 15, dark); t.r(15, 16, 16, 18, dark)
            for x in range(12, 21, 2):
                t.p(x, 22, dark)
            t.r(8, 6, 23, 6, sh(bone, 0.5)); t.r(8, 25, 23, 25, sh(bone, 0.35))
        return t.im
    return None


@theme("soko")
def soko(kind, v):
    """第10層以降。継ぎ目のない、呼吸する面"""
    base = C("3a3c52")
    if kind in ("floor", "corr"):
        k = 0.8 if kind == "corr" else 1.0
        t = T()
        t.fill(lambda x, y: sh(base, k * (0.8 + fbm(x, y, 200 + v) * 0.45)))
        for i in range(2 + v):                                         # ゆるい輪
            cx, cy, r = int(hsh(i, 1, 210 + v) * N), int(hsh(i, 2, 210 + v) * N), 6 + i * 3
            for a in range(0, 360, 6):
                t.p(cx + int(math.cos(math.radians(a)) * r), cy + int(math.sin(math.radians(a)) * r), sh(C("b9b4ff"), 0.45))
        return t.im
    if kind == "wall":
        t = T()
        t.fill(lambda x, y: sh(C("1c1c30"), 0.7 + fbm(x, y, 220 + v) * 0.6 + 0.12 * math.sin((x + y) * 0.4)))
        for i in range(2):
            x, y = int(hsh(i, 1, 230 + v) * N), int(hsh(i, 2, 230 + v) * N)
            t.p(x, y, C("b9b4ff")); t.p(x + 1, y, sh(C("b9b4ff"), 0.5))
        return t.im
    return None


@theme("generic")
def generic(kind, v):
    """汎用。石のレンガ"""
    base = C("4a4a52")
    if kind == "floor":
        return flagstones(base, 240 + v, 2, 2).im
    if kind == "corr":
        return flagstones(sh(base, 0.82), 250, 4, 2).im
    if kind == "wall":
        t = T()
        for row in range(4):
            off = 8 if row % 2 else 0
            for col in range(2):
                x0 = col * 16 + off
                for yy in range(8):
                    for xx in range(16):
                        c = sh(C("5a5a64"), 0.7 + fbm(x0 + xx, row * 8 + yy, 260 + v + row) * 0.5)
                        if xx == 0 or yy == 0:
                            c = C("1c1c22")
                        elif yy == 1:
                            c = sh(c, 1.15)
                        t.p(x0 + xx, row * 8 + yy, c)
        return t.im
    return None



# ---------- 壁の見せ方 ----------
# 真上から見た壁は、床と同じ平らな絵になって、壁に見えない。そこで、壁を2枚に分ける。
#   wall_<舞台>     … 壁の「正面」。南側が床のマスに使う。上端に明るい縁(天端)、下端に暗い接地線を焼き込み、高さを出す
#   walltop_<舞台>  … 壁の「天面」。それ以外の岩のマスに使う。床よりずっと暗い、平らな石の上面
LIP = {"fuyou": C("6a9a50"), "sabi": C("8a6a48"), "kagami": C("a8d8e8"), "hone": C("e0d8c0"), "soko": C("a8a0f0"), "generic": C("9a9aa8")}
CAP = {"fuyou": C("232a22"), "sabi": C("261c16"), "kagami": C("0f1c24"), "hone": C("1e1a24"), "soko": C("141428"), "generic": C("26262e")}


def face_finish(im, name):
    t = T(); t.im = im.copy(); t.px = t.im.load()
    lip = LIP[name]
    for x in range(N):
        t.px[x, 0] = mix(t.px[x, 0], lip, 0.85)
        t.px[x, 1] = mix(t.px[x, 1], lip, 0.5)
        t.px[x, 2] = mix(t.px[x, 2], lip, 0.2)
        t.px[x, 3] = sh(t.px[x, 3], 1.15)
    for i, k in enumerate((0.8, 0.66, 0.5, 0.36, 0.22)):          # 下へ向かって暗く(接地)
        y = N - 5 + i
        for x in range(N):
            t.px[x, y] = sh(t.px[x, y], k)
    return t.im


def wall_top(name, v=0):
    cap = CAP[name]
    t = T()
    t.fill(lambda x, y: sh(cap, 0.85 + fbm(x, y, 300 + v) * 0.5))
    for row in range(4):                                          # 天面の石積み(段ごとに半分ずらす)
        for col in range(2):
            x0, y0 = col * 16 + (8 if row % 2 else 0), row * 8
            for k in range(16):
                t.p(x0 + k, y0, sh(cap, 0.45))                   # 目地(暗)
                t.p(x0 + k, y0 + 1, sh(cap, 1.55))               # 面の上の縁(明)
            for k in range(8):
                t.p(x0, y0 + k, sh(cap, 0.45))
            t.p(x0 + 1, y0 + 2, sh(cap, 1.3))
    for i in range(10):
        x, y = int(hsh(i, 1, 310 + v) * N), int(hsh(i, 2, 310 + v) * N)
        t.p(x, y, sh(cap, 0.7))
    return t.im


# ---------- 扉と記号 ----------
def door(theme_name, open_):
    """縦長の板(東西に抜ける扉の向き)。南北に抜ける扉は、ゲームが 90 度回して使う"""
    pal = {"fuyou": C("6a5a30"), "sabi": C("6a4a2a"), "kagami": C("8aa0aa"), "hone": C("c8c0a8"), "soko": C("6a6a9a"), "generic": C("7a5a38")}[theme_name]
    t = T(alpha=True)
    if open_:
        t.r(1, 0, 4, N - 1, pal); t.r(1, 0, 1, N - 1, sh(pal, 1.3)); t.r(4, 0, 4, N - 1, sh(pal, 0.5))
        for y in range(2, N, 6):
            t.r(1, y, 4, y, sh(pal, 0.6))
        return t.im
    t.r(10, 0, 21, N - 1, sh(pal, 0.9))
    for y in range(N):
        for x in range(10, 22):
            n = vnoise(x * 2 % N, y, 4, 7)
            t.p(x, y, sh(pal, 0.75 + n * 0.35))
    t.r(10, 0, 10, N - 1, sh(pal, 1.3)); t.r(21, 0, 21, N - 1, sh(pal, 0.45))
    for y in (6, 25):
        t.r(10, y, 21, y + 1, C("3a3a44")); t.p(12, y, C("a0a0b0")); t.p(19, y, C("a0a0b0"))
    t.r(15, 0, 16, N - 1, sh(pal, 0.6))
    t.r(13, 14, 14, 17, C("8a8a98")); t.p(14, 15, C("2a2a30"))
    return t.im


def icon_stairs(up):
    t = T()
    t.fill(lambda x, y: (0, 0, 0, 0))
    t.im = Image.new("RGBA", (N, N), (0, 0, 0, 0)); t.px = t.im.load()
    for i in range(6):
        y0 = 4 + i * 4
        w = 24 - i * 2 if up else 12 + i * 2
        x0 = 16 - w // 2
        c = sh(C("8a8a9a"), 0.7 + 0.12 * i if up else 1.1 - 0.12 * i)
        t.r(x0, y0, x0 + w - 1, y0 + 2, c)
        t.r(x0, y0, x0 + w - 1, y0, sh(c, 1.3)); t.r(x0, y0 + 3, x0 + w - 1, y0 + 3, sh(c, 0.4))
    arrow = C("f0d878")
    ay = 3 if up else 28
    for k in range(4):
        d = k if up else -k
        t.p(16 - k, ay + d, arrow); t.p(16 + k, ay + d, arrow)
    outline(t)
    return t.im


def icon_chest():
    t = T(alpha=True)
    t.r(6, 12, 25, 26, C("7a4a22")); t.r(6, 12, 25, 13, C("a06a32"))
    t.r(6, 7, 25, 13, C("8a5a2a")); t.r(7, 6, 24, 6, C("6a4220"))
    for x in (6, 15, 25):
        t.r(x, 7, x + (1 if x == 15 else 0), 26, C("b8b0a0"))
    t.r(6, 20, 25, 20, C("3a2410"))
    t.r(14, 16, 17, 20, C("f0d060")); t.p(15, 18, C("3a2410"))
    for y in (13, 26):
        t.r(6, y, 25, y, C("3a2410"))
    outline(t)
    return t.im


def icon_trap():
    t = T(alpha=True)
    t.r(5, 20, 26, 26, C("3a3a44")); t.r(5, 20, 26, 20, C("5a5a66"))
    for x in range(7, 26, 5):
        for k in range(8):
            w = max(0, 2 - k // 3)
            t.r(x - w // 1, 19 - k, x + w, 19 - k, C("c8ccd8") if k < 6 else C("f0f4ff"))
    t.p(7, 10, C("e04040")); t.p(24, 8, C("e04040"))
    outline(t)
    return t.im


def outline(t):
    src = t.im.copy().load()
    for y in range(N):
        for x in range(N):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < N and 0 <= ny < N and src[nx, ny][3] > 0:
                        t.px[x, y] = (16, 14, 24, 255)
                        break


def main():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for name, fn in THEMES.items():
        for v, suffix in enumerate(("", "_2", "_3")):
            fn("floor", v).save(os.path.join(OUT, f"floor_{name}{suffix}.png")); n += 1
        fn("corr", 0).save(os.path.join(OUT, f"corr_{name}.png")); n += 1
        for v, suffix in enumerate(("", "_2")):
            face_finish(fn("wall", v), name).save(os.path.join(OUT, f"wall_{name}{suffix}.png")); n += 1
        wall_top(name).save(os.path.join(OUT, f"walltop_{name}.png")); n += 1
        door(name, False).save(os.path.join(OUT, f"door_{name}.png"))
        door(name, True).save(os.path.join(OUT, f"door_open_{name}.png")); n += 2
    icon_stairs(True).save(os.path.join(OUT, "icon_stairs_up.png"))
    icon_stairs(False).save(os.path.join(OUT, "icon_stairs_down.png"))
    icon_chest().save(os.path.join(OUT, "icon_chest.png"))
    icon_trap().save(os.path.join(OUT, "icon_trap.png")); n += 4
    print(f"{n} tiles ->", os.path.abspath(OUT))
    if "--preview" in sys.argv:
        names = list(THEMES)
        S = 2
        pv = Image.new("RGBA", (N * S * 10 + 20, (N * S + 4) * len(names)), (20, 20, 24, 255))
        for r, name in enumerate(names):
            keys = ["floor_%s" % name, "floor_%s_2" % name, "floor_%s_3" % name, "corr_%s" % name, "wall_%s" % name, "wall_%s_2" % name]
            x = 0
            for k in keys:
                im = Image.open(os.path.join(OUT, k + ".png")).resize((N * S, N * S), Image.NEAREST)
                pv.paste(im, (x, r * (N * S + 4))); x += N * S
            for k in ("door_%s" % name, "door_open_%s" % name):
                base = Image.open(os.path.join(OUT, "corr_%s.png" % name)).resize((N * S, N * S), Image.NEAREST)
                d = Image.open(os.path.join(OUT, k + ".png")).resize((N * S, N * S), Image.NEAREST)
                base.alpha_composite(d)
                pv.paste(base, (x, r * (N * S + 4))); x += N * S
            for k in ("icon_stairs_down", "icon_chest"):
                base = Image.open(os.path.join(OUT, "floor_%s.png" % name)).resize((N * S, N * S), Image.NEAREST)
                d = Image.open(os.path.join(OUT, k + ".png")).resize((N * S, N * S), Image.NEAREST)
                base.alpha_composite(d)
                pv.paste(base, (x, r * (N * S + 4))); x += N * S
        pv.save("/tmp/claude-0/tiles-preview.png")
        # 実際の並びを確かめる、部屋と壁の見本
        big = Image.new("RGBA", (N * 8 * len(names) // 2 * 1, N * 8), (0, 0, 0, 255))


if __name__ == "__main__":
    main()
