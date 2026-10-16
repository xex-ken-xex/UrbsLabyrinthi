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
# インストーラー(makensis があれば。Ubuntu は apt install nsis)
SUMS="UrbsLabyrinthi-windows.zip UrbsLabyrinthi-linux.zip"
if command -v makensis >/dev/null 2>&1; then
  VER="${INSTALLER_VERSION:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo dev)}"
  rm -f "$OUT/UrbsLabyrinthi-setup.exe"
  makensis -V2 -INPUTCHARSET UTF8 "-DSRC=$W" "-DVERSION=$VER" "-DOUTFILE=$OUT/UrbsLabyrinthi-setup.exe" "$ROOT/installer/UrbsLabyrinthi.nsi"
  SUMS="$SUMS UrbsLabyrinthi-setup.exe"
else
  echo "makensis が無いので、インストーラーは作らない" >&2
fi

# --- Linux ---
L="$WORK/UrbsLabyrinthi-linux"
mkdir -p "$L/assets"
cp "$D/linux/UrbsLabyrinthi.x86_64" "$D/linux/UrbsLabyrinthi.pck" "$L/"
chmod +x "$L/UrbsLabyrinthi.x86_64"
cp "$D/linux/assets/README.txt" "$L/assets/README.txt"
common "$L"
(cd "$WORK" && rm -f "$OUT/UrbsLabyrinthi-linux.zip" && zip -qr -9 -y "$OUT/UrbsLabyrinthi-linux.zip" UrbsLabyrinthi-linux)

# 起動時の更新用: ゲームの中身(.pck)と、latest.json(版と、.pck の場所とハッシュ)
# TAG は版の名前(タイトルに出る)。.pck の URL は、RELEASE_TAG の Release を指す(既定は TAG と同じ)
TAG="${INSTALLER_VERSION:-dev}"
URL_TAG="${RELEASE_TAG:-$TAG}"
REPO="${GITHUB_REPOSITORY:-xex-ken-xex/UrbsLabyrinthi}"
cp "$D/windows/UrbsLabyrinthi.pck" "$OUT/UrbsLabyrinthi-windows.pck"
cp "$D/linux/UrbsLabyrinthi.pck" "$OUT/UrbsLabyrinthi-linux.pck"
python3 - "$OUT" "$TAG" "$REPO" "$D/VERSION" "$URL_TAG" <<'PY'
import hashlib, json, os, re, sys
out, tag, repo, ver, url_tag = sys.argv[1:6]
m = re.search(r"godot:\s*(\d+)\.(\d+)(?:\.(\d+))?", open(ver).read())
godot = "%s.%s.%s" % (m.group(1), m.group(2), m.group(3) or "0")
pck = {}
for os_name, f in (("Windows", "UrbsLabyrinthi-windows.pck"), ("Linux", "UrbsLabyrinthi-linux.pck")):
    p = os.path.join(out, f)
    pck[os_name] = {"url": "https://github.com/%s/releases/download/%s/%s" % (repo, url_tag, f),
                    "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest(), "size": os.path.getsize(p)}
json.dump({"tag": tag, "godot": godot, "pck": pck}, open(os.path.join(out, "latest.json"), "w"), indent=1)
PY
SUMS="$SUMS UrbsLabyrinthi-windows.pck UrbsLabyrinthi-linux.pck latest.json"
(cd "$OUT" && sha256sum $SUMS > SHA256SUMS.txt)
ls -la "$OUT"
