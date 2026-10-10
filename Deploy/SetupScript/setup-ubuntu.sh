#!/bin/bash
# Urbs Labyrinthi のセットアップ(Ubuntu 22.04 / 24.04)
#
#   ./setup-ubuntu.sh           遊ぶための準備(実行に必要なライブラリを入れ、実行権限を付ける)
#   ./setup-ubuntu.sh --dev     上に加えて、開発の道具(Godot 4.7.2、書き出しテンプレート、Python、Node.js)を入れる
#   ./setup-ubuntu.sh --check   何も入れず、足りないものだけを調べる
#
# apt には sudo が要る(root なら不要)。Godot は GitHub の公式リリースから取り、SHA512 を確かめる。
set -euo pipefail

GODOT_VER="4.7.2"
GODOT_TAG="${GODOT_VER}-stable"
BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}"
HERE="$(cd "$(dirname "$0")" && pwd)"
DEPLOY="$(cd "$HERE/.." && pwd)"
LINUX_DIR="$DEPLOY/linux"
# 配布 ZIP(UrbsLabyrinthi-linux/)では、実行ファイルが、SetupScript の1つ上にある
[ -f "$DEPLOY/UrbsLabyrinthi.x86_64" ] && LINUX_DIR="$DEPLOY"
MODE="play"
for a in "$@"; do
  case "$a" in
    --dev) MODE="dev" ;;
    --check) MODE="check" ;;
    -h|--help) sed -n 2,9p "$0"; exit 0 ;;
    *) echo "知らない引数: $a" >&2; exit 2 ;;
  esac
done

say() { printf '\n== %s\n' "$*"; }
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 && SUDO="sudo" || { [ "$MODE" = "check" ] || { echo "root か sudo が要る" >&2; exit 1; }; }
fi

pkg_installed() { dpkg -s "$1" >/dev/null 2>&1; }
# 24.04 では libasound2 が libasound2t64 に変わった
alsa_pkg() { apt-cache show libasound2t64 >/dev/null 2>&1 && echo libasound2t64 || echo libasound2; }

RUNTIME_PKGS=(libgl1 libegl1 libgl1-mesa-dri libx11-6 libxcursor1 libxi6 libxrandr2 libxinerama1 libxext6 libxrender1 libxkbcommon0 libudev1 libfontconfig1 libpulse0 ca-certificates)
DEV_PKGS=(curl unzip python3 python3-pip python3-pil python3-numpy nodejs xvfb)

say "Ubuntu か確かめる"
. /etc/os-release 2>/dev/null || true
echo "OS: ${PRETTY_NAME:-不明} / $(uname -m)"
[ "$(uname -m)" = "x86_64" ] || { echo "x86_64 のみ対応(同梱の実行ファイルが x86_64)" >&2; exit 1; }

if [ "$MODE" = "check" ]; then
  say "足りないパッケージ"
  missing=0
  for p in "${RUNTIME_PKGS[@]}"; do pkg_installed "$p" || { echo "なし: $p"; missing=1; }; done
  [ "$missing" = 0 ] && echo "実行に必要なパッケージは、そろっている"
  [ -f "$LINUX_DIR/UrbsLabyrinthi.x86_64" ] && echo "あり: linux/UrbsLabyrinthi.x86_64" || echo "なし: linux/UrbsLabyrinthi.x86_64"
  [ -f "$LINUX_DIR/UrbsLabyrinthi.pck" ] && echo "あり: linux/UrbsLabyrinthi.pck" || echo "なし: linux/UrbsLabyrinthi.pck"
  exit 0
fi

say "実行に必要なライブラリを入れる(apt)"
$SUDO apt-get update -y
$SUDO apt-get install -y --no-install-recommends "${RUNTIME_PKGS[@]}" "$(alsa_pkg)"

say "実行ファイルを整える"
[ -f "$LINUX_DIR/UrbsLabyrinthi.x86_64" ] || { echo "linux/UrbsLabyrinthi.x86_64 が無い" >&2; exit 1; }
[ -f "$LINUX_DIR/UrbsLabyrinthi.pck" ] || { echo "linux/UrbsLabyrinthi.pck が無い(実行ファイルと同じフォルダに要る)" >&2; exit 1; }
chmod +x "$LINUX_DIR/UrbsLabyrinthi.x86_64"
mkdir -p "$LINUX_DIR/assets"
echo "OK: $LINUX_DIR"
# 起動できるか(画面を出さずに、すぐ終わらせる)
if "$LINUX_DIR/UrbsLabyrinthi.x86_64" --headless --quit >/dev/null 2>&1; then
  echo "起動の確認: 通った"
else
  echo "起動の確認: 通らなかった。  $LINUX_DIR/UrbsLabyrinthi.x86_64 を端末から実行して、メッセージを見る" >&2
fi

if [ "$MODE" = "dev" ]; then
  say "開発の道具を入れる(apt)"
  $SUDO apt-get install -y --no-install-recommends "${DEV_PKGS[@]}"

  say "Godot ${GODOT_VER} を入れる"
  GODOT_DIR="$HOME/.local/share/godot-${GODOT_VER}"
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  curl -fsSL "$BASE_URL/SHA512-SUMS.txt" -o "$TMP/SUMS"
  fetch() {   # fetch ファイル名  … ダウンロードして SHA512 を確かめる
    local f="$1" want
    want="$(grep " $f\$" "$TMP/SUMS" | awk '{print $1}')"
    [ -n "$want" ] || { echo "SHA512 が見つからない: $f" >&2; exit 1; }
    curl -fL --retry 4 --retry-delay 3 -o "$TMP/$f" "$BASE_URL/$f"
    echo "$want  $TMP/$f" | sha512sum -c - >/dev/null || { echo "SHA512 が合わない: $f" >&2; exit 1; }
  }
  mkdir -p "$GODOT_DIR" "$HOME/.local/bin"
  if [ ! -x "$GODOT_DIR/Godot_v${GODOT_TAG}_linux.x86_64" ]; then
    fetch "Godot_v${GODOT_TAG}_linux.x86_64.zip"
    unzip -qo "$TMP/Godot_v${GODOT_TAG}_linux.x86_64.zip" -d "$GODOT_DIR"
    chmod +x "$GODOT_DIR/Godot_v${GODOT_TAG}_linux.x86_64"
  fi
  ln -sf "$GODOT_DIR/Godot_v${GODOT_TAG}_linux.x86_64" "$HOME/.local/bin/godot"
  echo "godot: $HOME/.local/bin/godot"

  say "書き出しテンプレート(約1GB)を入れる"
  TPL="$HOME/.local/share/godot/export_templates/${GODOT_VER}.stable"
  if [ ! -f "$TPL/linux_release.x86_64" ] || [ ! -f "$TPL/windows_release_x86_64.exe" ]; then
    fetch "Godot_v${GODOT_TAG}_export_templates.tpz"
    mkdir -p "$TMP/tpl" "$TPL"
    unzip -qo "$TMP/Godot_v${GODOT_TAG}_export_templates.tpz" -d "$TMP/tpl"
    cp -r "$TMP/tpl/templates/." "$TPL/"
  fi
  echo "テンプレート: $TPL"

  say "Python のライブラリを確かめる(スプライトとタイルの生成用)"
  python3 -c "import PIL, numpy; print('Pillow', PIL.__version__, '/ numpy', numpy.__version__)"
  node --version >/dev/null 2>&1 && echo "Node.js $(node --version)(迷宮データの書き出し用)"

  cat <<MSG

開発の準備ができた。PATH に ~/.local/bin が無ければ、足す:  export PATH="\$HOME/.local/bin:\$PATH"
  ビルド:  GODOT=\$HOME/.local/bin/godot tools/build-deploy.sh
MSG
fi

say "できた"
echo "遊ぶ:  cd \"$LINUX_DIR\" && ./UrbsLabyrinthi.x86_64"
