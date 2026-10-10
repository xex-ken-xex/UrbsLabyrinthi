# SetupScript — 必要なライブラリとデータを入れる

ゲームを動かすための準備と、開発の道具の導入を、1つのコマンドで行う。

| | 遊ぶ(既定) | 開発(`--dev` / `-Dev`) | 調べるだけ |
|---|---|---|---|
| **Ubuntu 22.04 / 24.04**(x86_64) | `./setup-ubuntu.sh` | `./setup-ubuntu.sh --dev` | `./setup-ubuntu.sh --check` |
| **Windows 10 / 11**(x64) | `setup-windows.bat`(ダブルクリックでよい) | `setup-windows.bat -Dev` | `setup-windows.bat -Check` |

## 「遊ぶ」でやること

**Ubuntu**: `apt` で、実行に必要なライブラリ(OpenGL、X11 の各ライブラリ、音、フォント。24.04 では `libasound2t64`)を入れ、`linux/UrbsLabyrinthi.x86_64` に実行権限を付け、画面を出さずに起動できるか確かめる。`sudo` が要る。
**Windows**: `windows/UrbsLabyrinthi-engine-windows.zip` から `UrbsLabyrinthi.exe`(約110MB)を取り出し、`engine.sha256` と照合して、ダウンロードの印を外す(SmartScreen の警告が減る)。管理者権限は要らない。

どちらも、`UrbsLabyrinthi.pck`(ゲームの中身)が、実行ファイルと同じフォルダに無いときは、止まって知らせる。

## 「開発」で、さらに入れるもの

- Godot 4.7.2 と、書き出しテンプレート(約1GB)。GitHub の公式リリースから取り、**SHA512 を確かめる**
  - Ubuntu: `~/.local/share/godot-4.7.2/`(`~/.local/bin/godot` に張る)、テンプレートは `~/.local/share/godot/export_templates/4.7.2.stable/`
  - Windows: `%LOCALAPPDATA%\Godot\4.7.2\`、テンプレートは `%APPDATA%\Godot\export_templates\4.7.2.stable\`。環境変数 `GODOT` も設定する
- Python 3(Pillow、numpy。スプライトとタイルの生成 `tools/make-*.py` 用)
- Node.js(迷宮データの書き出し `tools/export-floors.mjs` 用)
- Ubuntu のみ: xvfb(画面なしの確認用)、curl、unzip

そのあとのビルド: `GODOT=~/.local/bin/godot tools/build-deploy.sh`(Linux か WSL。Windows 版も、同じスクリプトが書き出す)。

## 注意

- 何度実行してもよい(入っているものは飛ばす)。
- Windows 用のスクリプトは、書いた環境(Linux)で実行して確かめられていない。動かなければ、表示されたメッセージを知らせる。
- Mac は対象外。
