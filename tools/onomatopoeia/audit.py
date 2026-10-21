#!/usr/bin/env python3
"""擬音の表(docs/08-cue-audit.md)を sfx.gd から作る。語末の標識(陳 2022)と動き方の相性、強さの段、表記を機械的に印を付け、
DECIDE に書いた直し(人が決めたもの)を並べる。  python3 tools/onomatopoeia/audit.py"""
import os, re, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen import parse_cues, parse_style  # noqa
HERE = os.path.dirname(os.path.abspath(__file__))
DOC = os.path.join(HERE, "docs", "08-cue-audit.md")

# 語末 → 合う動き方(陳 2022 の標識: ッ 収束 / ン 余韻 / ー… 持続 / リ 完了。反復は跳ねる・揺れる)
FIT = {
    "ッ": {"slam", "snap", "pop", "drop", "fly", "stagger"},
    "ン": {"slam", "pop", "drop", "snap", "roll", "stagger"},
    "ー": {"stretch", "wave", "shake", "soft", "roll", "fly", "tremble", "loom"},
    "リ": {"soft", "pop", "roll"},
    "反復": {"bounce", "wave", "shake", "roll", "fly", "tremble", "flutter"},
}
def ending(text):
    t = text.rstrip("!?！？")
    if re.search(r"(.)(.)\1\2", t) or re.search(r"(.)\1\1", t) or re.search(r"(..)[、,]\1", t):
        rep = True
    else:
        rep = False
    last = t[-1:] if t else ""
    if last in "ッっ": e = "ッ"
    elif last in "ンん": e = "ン"
    elif last in "…ー〜": e = "ー"
    elif last in "リり": e = "リ"
    else: e = "ほか"
    return e, rep
def script(text):
    if re.search(r"[｡-ﾟ]", text): return "半角"
    if re.search(r"[ぁ-ん]", text): return "平仮名"
    return "片仮名"

# 人が決めた直し: id → {"text":…, "style":…, "size":…, "why":…}
DECIDE = json.load(open(os.path.join(HERE, "decide.json"), encoding="utf-8")) if os.path.exists(os.path.join(HERE, "decide.json")) else {}

def main():
    cues = parse_cues(); style = parse_style()
    rows = []; flags = 0
    for c in cues:
        st = style.get(c["id"], "pop"); e, rep = ending(c["text"]); sc = script(c["text"])
        notes = []
        fit = FIT.get(e, set()) | (FIT["反復"] if rep else set())
        if fit and st not in fit: notes.append("語末と合わない")
        if "!" in c["text"] and c["size"] < 1.2 and st not in ("slam", "snap", "stagger"): notes.append("! なのに弱い")
        if notes: flags += 1
        d = DECIDE.get(c["id"], {})
        rows.append((c["group"], c["id"], c["text"], e + ("+反復" if rep else ""), sc, st, "%.2g" % c["size"], " / ".join(notes), d.get("text", ""), d.get("style", ""), d.get("size", ""), d.get("why", "")))
    with open(DOC, "w", encoding="utf-8") as f:
        f.write("# 擬音の表(語末・動き・強さの見直し)\n\n`audit.py` が `sfx.gd` から作る。印は機械的(語末の標識 ッ=収束 / ン=余韻 / ー…=持続 / リ=完了、反復は跳ねる・揺れる)。「直し」は人が決めて `decide.json` に書いたもの。\n\n")
        f.write("印の付いた擬音: %d / %d\n\n" % (flags, len(rows)))
        f.write("| まとまり | id | 文字 | 語末 | 表記 | 動き | 大きさ | 印 | 直し: 文字 | 直し: 動き | 直し: 大きさ | 理由 |\n|---|---|---|---|---|---|---|---|---|---|---|---|\n")
        for r in rows: f.write("| " + " | ".join(str(x) for x in r) + " |\n")
    print("%d 個、印 %d 個 → %s" % (len(rows), flags, os.path.relpath(DOC)))
    for r in rows:
        if r[7]: print("  ", r[1], r[2], r[3], r[5], r[6], "←", r[7])
if __name__ == "__main__": main()
