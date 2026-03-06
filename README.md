# factorio-with-ai

Codex から Factorio: Space Age を操作して、どこまで高度な自動化でクリアに近づけるかを試すリポジトリです。  
単に AI に遊ばせるだけではなく、観測、制約、行動実行、記事化まで含めて、再現できる形で積み上げていくことを目的にしています。

## この企画について

この取り組みでは、「AI がすごい」で終わらせず、ゲーム内のルールを守ったままどこまで自動化できるかを詰めていきます。  
そのために、Factorio の Mod、Python controller、RCON、ローカル Kanban、記事運用をこのリポジトリでまとめて管理しています。

現時点の基本方針は次の通りです。

- 対象は Factorio: Space Age
- 非公式 Mod はこのリポジトリで管理する『fwai_bridge』のみ
- プレイヤー inventory は使わず、Bot 自身の inventory とゲーム内 entity の inventory を使う
- 届かない位置への遠隔操作はしない
- 観測者がサーバーへ入っていない間は action を流さない

## リンク

- リポジトリ
  - https://github.com/okash1n/factorio-with-ai
- note マガジン
  - https://note.com/okash1n/m/m9def00095cdf

## スコープ

- Space Age 有効 『base』『elevated-rails』『quality』『space-age』
- ローカルの headless server をこのリポジトリから管理
- Mod は `mod/fwai_bridge` を開発し、サーバーとクライアントへ同期
- controller は Python から RCON 経由でゲームへ action を送る

## 前提環境

- macOS
- Steam 版 Factorio
- Python 3.11 以上

Steam 版 Factorio の既定バイナリは次です。

```text
~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio
```

## クイックスタート

1. サーバーを起動する

```bash
./scripts/start_server.sh
```

2. 別ターミナルで controller を起動する

```bash
./scripts/run_controller.sh
```

3. 必要ならローカル GUI クライアントで接続する

```bash
./scripts/start_client_mac.sh
```

『start_client_mac.sh』は `.runtime/client/` 配下に専用 client runtime を作り、そこへ『fwai_bridge』を入れます。  
そのため Mod Portal に上がっていない状態でもローカル接続できます。

既定のユーザープロファイル側の mods ディレクトリを使いたい場合は、次を実行します。

```bash
./scripts/install_client_mod.sh
```

『install_client_mod.sh』は既定で symlink 方式を使います。

- `~/Library/Application Support/Factorio/mods/fwai_bridge` をこのリポジトリの `mod/fwai_bridge` へ向ける
- このリポジトリの Mod 更新がローカル client 側へそのまま反映される
- 反映には client 再起動が必要

Windows 観測クライアントへ配る場合は、次を使います。

```bash
./scripts/export_mod_bundle.sh
```

生成された `dist/` 配下の zip を `%APPDATA%\\Factorio\\mods\\` へ配置してください。

## launchd での常駐実行

サーバーを user LaunchAgent として入れて起動する場合は次です。

```bash
./scripts/launchd_server.sh start
```

よく使うコマンド:

```bash
./scripts/launchd_server.sh status
./scripts/launchd_server.sh logs
./scripts/launchd_server.sh stop
./scripts/launchd_server.sh uninstall
```

## ローカル Kanban

作業面としてローカルの Kanban UI を用意しています。

```bash
./scripts/start_board.sh
```

既定 URL:

```text
http://127.0.0.1:8127
```

構成は次の通りです。

- board レイアウトは `board/board.json`
- task の実体は `board/cards/00001.md` 形式の Markdown
- browser UI から列移動、編集、保存ができる
- UI 上の card ID は数字で表示される
- `key:` は空欄でもよく、保存時に server 側で補完する

launchd で board を動かす場合は次です。

```bash
./scripts/launchd_board.sh start
```

よく使うコマンド:

```bash
./scripts/launchd_board.sh status
./scripts/launchd_board.sh logs
./scripts/launchd_board.sh stop
./scripts/launchd_board.sh uninstall
```

## 環境変数

- `FACTORIO_BIN`: Factorio バイナリパスを上書きする
- `RCON_PORT`: 既定 `27015`
- `RCON_PASSWORD`: 既定 `fwai-local`
- `GAME_PORT`: 既定 `34197`
- `LOOP_SECONDS`: controller loop の待機秒数。既定 `1.0`
- `ITERATIONS`: loop 回数。既定 `0` で無限

## 補足

- サーバー runtime は `.runtime/server/` に分離する
- client runtime は `.runtime/client/` に分離する
- `scripts/verify_modset.sh` で有効 Mod セットを検証できる
- 既定の LaunchAgent label は `com.okash1n.fwai.server`
