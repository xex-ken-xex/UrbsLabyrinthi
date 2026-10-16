# Deploy — ビルド済みの実行ファイル

Linux(x86_64)と Windows(x86_64)向け。コードやデータを変えたら、`tools/build-deploy.sh` で作り直して、ここへ入れる。
最後のビルドは [`VERSION`](VERSION) を見る。

エンジン本体(変わらない)と、ゲームの中身 `UrbsLabyrinthi.pck`(変わる)を分けてある。
**`.pck` は、実行ファイルと同じフォルダに、同じ名前で置く。**

## Release「test」と ZIP

このリポジトリはリリースを目的としない(リポジトリ直下の README)。`main` にマージされるたびに、GitHub Actions(`.github/workflows/release.yml`)が、自動更新用の `.pck` と `latest.json` だけを、テスト用の Release「test」に上書きで置く(最新版の印が付く)。ほかの Release とタグは消す。
`UrbsLabyrinthi-windows.zip`、`UrbsLabyrinthi-linux.zip`、インストーラーは、その実行の成果物(Actions の Artifacts、90日)に置く。
手元で作るなら `tools/package-release.sh`(`dist/` に出る)。ZIP の中身は `Deploy/` のコミット済みのビルドなので、コードを変えたら先に `tools/build-deploy.sh` を実行してコミットする。

## Windows のインストーラー

Actions の成果物にある `UrbsLabyrinthi-setup.exe` を実行すると、`%LOCALAPPDATA%\Programs\UrbsLabyrinthi` に入る(管理者の権限は要らない。場所は変えられる)。
スタートメニューに、起動、ログを取って起動、差し替え画像のフォルダ、アンインストールが並ぶ。デスクトップのショートカットは選べる。
新しい版は、上から入れ直せばよい。アンインストールしても、セーブ(`%APPDATA%\Godot\app_userdata\Urbs Labyrinthi\`)と、`assets\` に自分で置いた画像は残る。
作り方は `installer/UrbsLabyrinthi.nsi`。`tools/package-release.sh` が、`makensis`(Ubuntu は `apt install nsis`)があればいっしょに作る。

## 起動時の自動更新(.pck だけ)

書き出したゲームは、起動するたびに GitHub の最新の Release の `latest.json` を見て、ゲームの中身(`.pck`)が違えば受け取り、実行ファイルの隣の `UrbsLabyrinthi.pck` を入れ替えて起動し直す(`scripts/updater.gd`)。
実行ファイル(エンジン)は入れ替えない。エンジンの版が変わったときは、インストーラーか ZIP で入れ直すよう、タイトルに出る。

- 受け取りは、いったん `UrbsLabyrinthi.pck.new` に置き、SHA-256 を確かめてから入れ替える。Windows では、ゲームが終わるのを PowerShell が待って入れ替え、起動し直す
- 通信できないとき、フォルダに書き込めないときは、そのまま今の版で起動する(タイトルの下に理由が出る)
- 確かめている間に Esc(コントローラーは B)で飛ばせる。`-- --no-update` を付けて起動すると、確かめない
- 同じ版への入れ替えは一度だけ試す(覚えておく場所は `user://update.cfg`)。入れ替えに失敗しても、起動し直しを繰り返さない
- 確かめている間は 30fps・省電力で描き、ハッシュの計算は裏で行う。各段階はログに `[urbs] 更新:` として残る
- Release「test」には `UrbsLabyrinthi-windows.pck`、`UrbsLabyrinthi-linux.pck`、`latest.json` を `tools/package-release.sh` が作って載せる(`RELEASE_TAG=test` で、`.pck` の URL が test を指す)

## セットアップ(必要なライブラリを入れる)

[`SetupScript/`](SetupScript/README.md) に、Ubuntu 用(`setup-ubuntu.sh`)と Windows 用(`setup-windows.bat`)がある。
`--dev`(Windows は `-Dev`)を付けると、Godot とビルドの道具まで入れる。

## Windows

1. `windows/UrbsLabyrinthi-engine-windows.zip` を展開して、`UrbsLabyrinthi.exe` を取り出す(約110MB。GitHub は 100MB を超えるファイルを置けないので、zip にしてある)
2. `windows/UrbsLabyrinthi.pck` を、`UrbsLabyrinthi.exe` と同じフォルダに置く
3. `UrbsLabyrinthi.exe` を実行する(未署名なので、SmartScreen が警告したら「詳細情報」→「実行」)

2回目以降は、`.pck` だけを入れ替えればよい。

### 強制終了などの調べ方(ログ)
1. `windows/UrbsLabyrinthi.console.exe` と `windows/run-with-log.bat` を、`UrbsLabyrinthi.exe` と同じフォルダに置く
2. `run-with-log.bat` を実行して、終了するまで遊ぶ(または再現させる)
3. 同じフォルダにできた `urbs-log.txt` を渡す。最後の `[urbs]` の行が、どの処理で止まったかを示す
4. ゲーム自身も、ログを `%APPDATA%\Godot\app_userdata\Urbs Labyrinthi\logs\godot.log` に書く

## Linux

```sh
cd Deploy/linux
./UrbsLabyrinthi.x86_64        # 同じフォルダの UrbsLabyrinthi.pck を読む
```

実行権限が無ければ `chmod +x UrbsLabyrinthi.x86_64`。

## 操作

[`godot/README.md`](../godot/README.md) を見る。移動は WASD、敵へ押し込んで体当たり、スキルは 1〜4、持ち物は Tab。


## 画像・フォントの差し替え
背景、キャラクター、魔物、床や壁、アイコン、ロゴ、フォントを、画像ファイルを置くだけで差し替えられる。
実行ファイルと同じフォルダの `assets/` に、`キー.png` を置く(`windows/assets/`、`linux/assets/`)。ゲーム中に **F6** で読み込み直す。
キーの一覧と大きさは [`assets/README.md`](assets/README.md)、見本は [`assets/samples/`](assets/samples/)。
