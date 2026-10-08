# Deploy — ビルド済みの実行ファイル

Linux(x86_64)と Windows(x86_64)向け。コードやデータを変えたら、`tools/build-deploy.sh` で作り直して、ここへ入れる。
最後のビルドは [`VERSION`](VERSION) を見る。

エンジン本体(変わらない)と、ゲームの中身 `UrbsLabyrinthi.pck`(変わる)を分けてある。
**`.pck` は、実行ファイルと同じフォルダに、同じ名前で置く。**

## Windows

1. `windows/UrbsLabyrinthi-engine-windows.zip` を展開して、`UrbsLabyrinthi.exe` を取り出す(約110MB。GitHub は 100MB を超えるファイルを置けないので、zip にしてある)
2. `windows/UrbsLabyrinthi.pck` を、`UrbsLabyrinthi.exe` と同じフォルダに置く
3. `UrbsLabyrinthi.exe` を実行する(未署名なので、SmartScreen が警告したら「詳細情報」→「実行」)

2回目以降は、`.pck` だけを入れ替えればよい。

## Linux

```sh
cd Deploy/linux
./UrbsLabyrinthi.x86_64        # 同じフォルダの UrbsLabyrinthi.pck を読む
```

実行権限が無ければ `chmod +x UrbsLabyrinthi.x86_64`。

## 操作

[`godot/README.md`](../godot/README.md) を見る。移動は WASD、敵へ押し込んで体当たり、スキルは 1〜4、持ち物は Tab。
