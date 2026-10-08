#!/bin/bash
# Linux と Windows 向けにビルドして、Deploy/ に置く。コードやデータを変えたら、毎回これを実行してコミットする。
#
#   GODOT=/path/to/godot tools/build-deploy.sh
#
# 書き出しテンプレート(4.7.2)が入っていること。
# エンジン本体(変わらない)と、ゲームの中身 UrbsLabyrinthi.pck(変わる)を分けて置く。
# こうすると、コミットのたびに増えるのは .pck(約8MB)だけで済む。
# Windows のエンジン(exe)は 100MB を超え GitHub に置けないため、zip にして置く(中身は毎回同じ)。
set -euo pipefail
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/Deploy/linux" "$ROOT/Deploy/windows"

"$GODOT" --headless --path "$ROOT/godot" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/godot" --export-release "Linux" "$ROOT/Deploy/linux/UrbsLabyrinthi.x86_64" 2>&1 | grep -i "error" || true
"$GODOT" --headless --path "$ROOT/godot" --export-release "Windows Desktop" "$ROOT/Deploy/windows/UrbsLabyrinthi.exe" 2>&1 | grep -i "error" || true

# Windows のエンジンを、決まった形で zip にする(中身が同じなら、zip も同じバイト列になる)
python3 - "$ROOT/Deploy/windows" <<'PY'
import hashlib, os, sys, zipfile
d = sys.argv[1]
exe = os.path.join(d, "UrbsLabyrinthi.exe")
zp = os.path.join(d, "UrbsLabyrinthi-engine-windows.zip")
sha = hashlib.sha256(open(exe, "rb").read()).hexdigest()
marker = os.path.join(d, "engine.sha256")
if not (os.path.exists(zp) and os.path.exists(marker) and open(marker).read().strip() == sha):
    with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        zi = zipfile.ZipInfo("UrbsLabyrinthi.exe", date_time=(1980, 1, 1, 0, 0, 0))
        zi.compress_type = zipfile.ZIP_DEFLATED
        zi.external_attr = 0o755 << 16
        z.writestr(zi, open(exe, "rb").read(), compresslevel=9)
    open(marker, "w").write(sha + "\n")
    print("Windows エンジンを zip にした")
os.remove(exe)
PY
chmod +x "$ROOT/Deploy/linux/UrbsLabyrinthi.x86_64"

# 書き出したビルドで、迷宮→街→全滅→帰還の札→つづきから、を通す(xvfb があれば)。
# headless のテストでは見つからない強制終了(null の Hero への参照など)を、ここで検出する
if command -v xvfb-run >/dev/null 2>&1; then
  OUT="$(cd "$ROOT/Deploy/linux" && timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" ./UrbsLabyrinthi.x86_64 --rendering-driver opengl3 -- --autotest-town 2>&1)" || { echo "$OUT" | tail -5; echo "ビルドの確認で強制終了した" >&2; exit 1; }
  echo "$OUT" | grep -q "AUTOTEST done" || { echo "$OUT" | tail -5; echo "ビルドの確認が最後まで通らなかった" >&2; exit 1; }
  echo "ビルドの確認: 迷宮→街→全滅→帰還の札→つづきから が通った"
fi
{
  echo "commit: $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo "built:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "godot:  $("$GODOT" --version 2>/dev/null | head -1)"
} > "$ROOT/Deploy/VERSION"
ls -la "$ROOT/Deploy/linux" "$ROOT/Deploy/windows"
