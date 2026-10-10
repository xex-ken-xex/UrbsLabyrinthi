#!/bin/bash
# Deploy/ の中身を、配布用の ZIP(Windows 用と Linux 用)にまとめる。
#   tools/package-release.sh [出力フォルダ]     既定は dist/
# Windows のエンジン(exe)は、Deploy では zip に入っている(100MB 超で GitHub に置けないため)ので、ここで取り出して入れる。
# ZIP の中は、フォルダ UrbsLabyrinthi-<OS>/ の1つ。展開して、すぐ遊べる形。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/dist}"
D="$ROOT/Deploy"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

for f in linux/UrbsLabyrinthi.x86_64 linux/UrbsLabyrinthi.pck windows/UrbsLabyrinthi.pck windows/UrbsLabyrinthi-engine-windows.zip windows/engine.sha256; do
  [ -f "$D/$f" ] || { echo "Deploy/$f が無い" >&2; exit 1; }
done

common() {   # common 作業フォルダ
  cp "$D/VERSION" "$1/VERSION"
  cp -r "$D/assets" "$1/assets-guide"        # 差し替え画像の説明と見本
  cp -r "$D/SetupScript" "$1/SetupScript"
  cp "$D/README.md" "$1/README.md"
}

# --- Windows ---
W="$WORK/UrbsLabyrinthi-windows"
mkdir -p "$W/assets"
unzip -q "$D/windows/UrbsLabyrinthi-engine-windows.zip" -d "$W"
want="$(tr -d '[:space:]' < "$D/windows/engine.sha256")"
got="$(sha256sum "$W/UrbsLabyrinthi.exe" | awk '{print $1}')"
[ "$want" = "$got" ] || { echo "exe の SHA256 が合わない" >&2; exit 1; }
cp "$D/windows/UrbsLabyrinthi.pck" "$D/windows/UrbsLabyrinthi.console.exe" "$D/windows/run-with-log.bat" "$W/"
cp "$D/windows/assets/README.txt" "$W/assets/README.txt"
common "$W"
(cd "$WORK" && rm -f "$OUT/UrbsLabyrinthi-windows.zip" && zip -qr -9 "$OUT/UrbsLabyrinthi-windows.zip" UrbsLabyrinthi-windows)

# --- Linux ---
L="$WORK/UrbsLabyrinthi-linux"
mkdir -p "$L/assets"
cp "$D/linux/UrbsLabyrinthi.x86_64" "$D/linux/UrbsLabyrinthi.pck" "$L/"
chmod +x "$L/UrbsLabyrinthi.x86_64"
cp "$D/linux/assets/README.txt" "$L/assets/README.txt"
common "$L"
(cd "$WORK" && rm -f "$OUT/UrbsLabyrinthi-linux.zip" && zip -qr -9 -y "$OUT/UrbsLabyrinthi-linux.zip" UrbsLabyrinthi-linux)

(cd "$OUT" && sha256sum UrbsLabyrinthi-windows.zip UrbsLabyrinthi-linux.zip > SHA256SUMS.txt)
ls -la "$OUT"
