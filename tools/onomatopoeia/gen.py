#!/usr/bin/env python3
"""擬音の実験室(tools/onomatopoeia)のデータを、ゲームの sfx.gd から書き出す。
  python3 tools/onomatopoeia/gen.py      # tools/onomatopoeia/cues.js を作り直す
CUES の文字・色・大きさ、STYLE の動き方、sfx.gd の「# 見出し」のまとまりを拾う。
層の主の咆哮(layer_boss.gd の roar)も、まとまり「層の主の咆哮」として足す。
実験室の HTML(index.html)と描き方(cue_lab.js)は手で書く。cues.js は作り直すので手で直さない。"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
SFX = os.path.join(ROOT, "godot", "scripts", "sfx.gd")
BOSS = os.path.join(ROOT, "godot", "scripts", "layer_boss.gd")
OUT = os.path.join(HERE, "cues.js")

CUE_RE = re.compile(r'^\s*"(?P<id>[a-z_0-9]+)":\s*\["(?P<text>[^"]*)",\s*Color\((?P<r>[\d.]+),\s*(?P<g>[\d.]+),\s*(?P<b>[\d.]+)\)(?:,\s*(?P<size>[\d.]+))?\]')
STYLE_RE = re.compile(r'"(?P<id>[a-z_0-9]+)":\s*"(?P<style>[a-z]+)"')
GROUP_RE = re.compile(r'^\s*#\s*(?P<name>[^(（。]+)')
ROAR_RE = re.compile(r'^\s*(?P<n>\d+):\s*\{"room":\s*"(?P<room>[^"]+)",\s*"roar":\s*"(?P<roar>[^"]+)"')


def parse() -> tuple:
    """sfx.gd の CUES と STYLE を読む → (cues, styles)。cues は [{id, text, group, color, size}]"""
    cues = []
    styles = {}
    group = "迷宮"
    section = None
    with open(SFX, encoding="utf-8") as f:
        for line in f:
            if line.startswith("const CUES"):
                section = "cues"
                continue
            if line.startswith("const STYLE"):
                section = "style"
                continue
            if line.startswith("const SKILL_CUE"):
                section = None
                continue
            if section == "cues":
                m = GROUP_RE.match(line)
                if m:
                    group = m.group("name").strip()
                    continue
                m = CUE_RE.match(line)
                if m:
                    d = m.groupdict()
                    cues.append({
                        "id": d["id"], "text": d["text"], "group": group,
                        "color": [round(float(d["r"]), 3), round(float(d["g"]), 3), round(float(d["b"]), 3)],
                        "size": float(d["size"]) if d["size"] else 1.0,
                    })
            elif section == "style":
                for m in STYLE_RE.finditer(line):
                    styles[m.group("id")] = m.group("style")
    return cues, styles


def parse_cues() -> list:
    return parse()[0]


def parse_style() -> dict:
    return parse()[1]


def main() -> None:
    cues, styles = parse()
    for c in cues:
        c["style"] = styles.get(c["id"], "pop")
    with open(BOSS, encoding="utf-8") as f:
        for line in f:
            m = ROAR_RE.match(line)
            if m:
                cues.append({
                    "id": "roar_%s" % m.group("n"), "text": m.group("roar"), "group": "層の主の咆哮(BossFx が画面いっぱいに描く)",
                    "color": [1.0, 0.45, 0.4], "size": 3.0, "style": "slam",
                })
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("// tools/onomatopoeia/gen.py が sfx.gd から作る。手で直さない。\n")
        f.write("window.CUE_DATA = ")
        json.dump({"cues": cues, "styles": sorted(set(styles.values()))}, f, ensure_ascii=False, indent=1)
        f.write(";\n")
    print("%d 個の擬音を %s に書いた" % (len(cues), os.path.relpath(OUT, ROOT)))


if __name__ == "__main__":
    main()
