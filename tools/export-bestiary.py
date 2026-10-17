#!/usr/bin/env python3
"""冒険日記帳の魔物の一覧(godot/data/bestiary.json)を、書き出した層のデータから作る。

層(meta.floor)ごとに、遭遇に出てくる魔物の index を集める。名前・種別・CR は
encounter-data.json から。層のデータを書き出し直したら、これも流し直す:
    python3 tools/export-bestiary.py
"""
import glob
import gzip
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "data")

def main() -> None:
    data = {m["i"]: m for m in json.load(open(os.path.join(ROOT, "encounter-data.json"), encoding="utf-8"))["monsters"]}
    layers = {}
    mons = {}
    for p in sorted(glob.glob(os.path.join(ROOT, "floors", "*.json.gz"))):
        d = json.load(gzip.open(p))
        meta = d["meta"]
        layer = int(meta["floor"])
        lay = layers.setdefault(layer, {"name": meta["theme_name"].split(" ", 1)[-1], "theme": meta["theme"], "mons": []})
        for e in d["encounters"]:
            for m in e["monsters"]:
                idx = m["index"]
                if idx not in lay["mons"]:
                    lay["mons"].append(idx)
                src = data.get(idx, {})
                ent = mons.setdefault(idx, {"name": m.get("world_name") or m["name_ja"], "name_ja": m["name_ja"],
                    "type": m.get("type", src.get("t", "")), "cr": m.get("cr", src.get("cr", 0)), "size": m.get("size", src.get("z", "M")),
                    "hp": m.get("hp", src.get("hp", 0)), "ac": m.get("ac", src.get("ac", 0)), "layers": []})
                if layer not in ent["layers"]:
                    ent["layers"].append(layer)
    for lay in layers.values():
        lay["mons"].sort(key=lambda i: (mons[i]["cr"], mons[i]["name"]))
    out = {"layers": {str(k): layers[k] for k in sorted(layers)}, "monsters": mons}
    with open(os.path.join(ROOT, "bestiary.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print("層 %d、魔物 %d 種" % (len(layers), len(mons)))

if __name__ == "__main__":
    main()
