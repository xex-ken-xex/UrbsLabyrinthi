#!/usr/bin/env python3
"""差し替え画像の見本(ゲームが使っている元の絵に近い形・大きさ)を Deploy/assets/samples/ に作る。
背景は godot/tests/art_shots.gd が出した PNG(art_<style>.png)を、bg_<style>.png の名前で写す。
使い方: python3 tools/make-asset-samples.py [art_shots の出力フォルダ]"""
import os, shutil, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "Deploy", "assets", "samples")
FONT = os.path.join(ROOT, "godot", "assets", "fonts", "ZenKakuGothicNew-Regular.ttf")
os.makedirs(OUT, exist_ok=True)
font = ImageFont.truetype(FONT, 44)
small = ImageFont.truetype(FONT, 20)

CLASSES = {"fighter": ("戦", "d9a441"), "barbarian": ("蛮", "c4513a"), "rogue": ("盗", "7a8ca8"),
           "wizard": ("魔", "8a6ad0"), "cleric": ("僧", "e8e4c8"), "ranger": ("野", "5fa05a")}
TYPES = {"undead": "c9c4b2", "beast": "9a6a3c", "swarm": "8a5a3a", "ooze": "6fb04a", "construct": "8c97a6", "plant": "4f8a3c",
         "monstrosity": "b0663a", "aberration": "a05ac0", "fiend": "c0392b", "humanoid": "c79a6a", "elemental": "d98a3c",
         "fey": "c06ab0", "celestial": "e8e0a0", "dragon": "c04030", "giant": "a0805a"}

def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def ball(color, letter=None, eyes=False, size=128):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = 6
    d.ellipse((m, m, size - m, size - m), fill=rgb(color) + (255,), outline=(20, 20, 24, 255), width=5)
    if letter:
        w = d.textlength(letter, font=font)
        d.text(((size - w) / 2, size / 2 - 30), letter, font=font, fill=(14, 14, 20, 255))
    if eyes:
        for dx in (-14, 14):
            d.ellipse((size * 0.62 - 6, size / 2 + dx - 6, size * 0.62 + 6, size / 2 + dx + 6), fill=(10, 10, 12, 255))
    return im

for cls, (ch, col) in CLASSES.items():
    ball(col, letter=ch).save(os.path.join(OUT, f"hero_{cls}.png"))
for t, col in TYPES.items():
    ball(col, eyes=True).save(os.path.join(OUT, f"enemy_type_{t}.png"))

# 床、壁、通路(64×64。1マスに引き伸ばされる)
def tile(base, name, line):
    im = Image.new("RGBA", (64, 64), rgb(base) + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 63, 63), outline=rgb(line) + (255,), width=2)
    im.save(os.path.join(OUT, name))
tile("414d38", "floor_fuyou.png", "353f2e")
tile("3a4532", "corr_fuyou.png", "2e3828")
tile("1a2418", "wall_fuyou.png", "0c120b")

# アイコン(64×64。1マスに引き伸ばされる)
def icon(name, draw_fn):
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(im))
    im.save(os.path.join(OUT, name))
icon("icon_stairs_up.png", lambda d: d.polygon([(32, 8), (56, 52), (8, 52)], fill=(120, 200, 255, 120), outline=(160, 220, 255, 255)))
icon("icon_stairs_down.png", lambda d: d.polygon([(32, 56), (56, 12), (8, 12)], fill=(255, 190, 90, 120), outline=(255, 210, 130, 255)))
icon("icon_trap.png", lambda d: (d.line((14, 14, 50, 50), fill=(230, 64, 51, 255), width=6), d.line((14, 50, 50, 14), fill=(230, 64, 51, 255), width=6)))

# ロゴ(タイトルの文字の代わり。横長の透過PNG)
logo = Image.new("RGBA", (620, 180), (0, 0, 0, 0))
d = ImageDraw.Draw(logo)
big = ImageFont.truetype(FONT, 78)
d.text((20, 40), "Urbs Labyrinthi", font=big, fill=(232, 220, 176, 255))
logo.save(os.path.join(OUT, "logo.png"))

# 背景(1280×720)
src = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/shots"
for style in ["town", "smith", "general", "magic", "temple", "inn", "pleasure"]:
    f = os.path.join(src, f"art_{style}.png")
    if os.path.exists(f):
        shutil.copy(f, os.path.join(OUT, f"bg_{style}.png"))
# 同梱のスプライトシート(tools/make-sprites.py が描いたもの)も、形式の見本として添える
SAMPLE_MONSTERS = {"bandit", "bat", "giant-bat", "giant-rat", "giant-spider", "goblin", "gray-ooze", "green-slime", "rat", "skeleton", "zombie"}
tiles_dir = os.path.join(ROOT, "godot", "assets", "tiles")
if os.path.isdir(tiles_dir):
    for f in sorted(os.listdir(tiles_dir)):
        if f.endswith(".png") and (f.endswith("_fuyou.png") or f.startswith("icon_")):
            shutil.copy(os.path.join(tiles_dir, f), os.path.join(OUT, f))
items_sheet = os.path.join(ROOT, "godot", "assets", "items", "items_sheet.png")
if os.path.exists(items_sheet):
    shutil.copy(items_sheet, os.path.join(OUT, "items_sheet.png"))
spr = os.path.join(ROOT, "godot", "assets", "sprites")
if os.path.isdir(spr):
    for f in sorted(os.listdir(spr)):
        # 魔物は300体を超えるので、見本には、種別の代表と最初の11体だけ
        if f.endswith(".png") and (not f.startswith("esheet_") or f.startswith("esheet_type_") or f[7:-4] in SAMPLE_MONSTERS):
            shutil.copy(os.path.join(spr, f), os.path.join(OUT, f))
print("samples ->", OUT, len(os.listdir(OUT)), "files")
