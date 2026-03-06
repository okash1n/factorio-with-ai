# Factorio Space Age 実装計画（Codex制御）

## 1. 目的
- Codex だけで Factorio を操作し、最終的に Space Age のクリア条件達成まで到達する。
- 非公式の追加 Mod は自作 `fwai_bridge` のみを使う。
- 公式コンテンツは `base`, `elevated-rails`, `quality`, `space-age` を許可セットとして扱う。
- MVP は「Nauvis 軌道に到達し、宇宙側で運用開始（軌道到達 + 滞在）」を無介入で達成する。
- 最終目標は、Space Age の勝利条件である `solar-system-edge` 到達により force 勝利状態へ入ることとする。

## 2. 合意済み前提
- あなたはゲームに参加して観測する（MVP中は観測のみ、介入なし）。
- AI は実プレイヤーではなく、ゲーム内に見える専用 Bot エンティティとして動かす。
- Bot 実体は custom `spider-vehicle` prototype `fwai-bot` として実装する。
- 「ゲーム内で実際にできないこと」は禁止する。
- 敵設定は通常。
- 実行は macOS 同居構成を主経路とし、Windows 参加は対応経路として扱う。

## 3. 非チート制約（最重要）
以下をすべて満たさない action は実行せず失敗として返す。

1. ReachGate  
   到達距離外での採掘・設置・回収を禁止する。
2. CollisionGate  
   置けない場所への設置を禁止する。
3. InventoryGate  
   所持不足・容量超過を禁止する。
4. TimeGate  
   採掘・作業時間の短縮を禁止する。
5. NoSpawnGate  
   アイテム直接生成を禁止する。
6. TechGate  
   未研究機能の利用を禁止する。

補足:
- 「離れた場所への瞬間設置」は明示的に禁止。
- 序盤の手掘りは Bot 実体で実行。
- 進行後は機械・ロボット利用に自然遷移する。
- Bot の移動は `spider-vehicle` の経路移動を使い、採掘・設置は Mod 側で距離と時間を検証して実行する。

## 4. 実行トポロジー
### 4.1 主経路（同一 macOS）
- Process A: Factorio headless server
- Process B: Controller（Codex が操作）
- Process C: 人間クライアント（観測）

### 4.2 対応経路（LAN Windows 観測）
- macOS で Process A/B
- Windows でクライアント参加

## 5. Steam 版運用方針
- サーバー専用バイナリの追加ダウンロードは不要。
- 同じ Steam 版実行ファイルを client/server の別プロセスで起動する。
- ただしデータ衝突防止のため server 側は `--config` と `--mod-directory` を分離する。
- Steam 自動更新対策として、起動前にバージョンチェックを必須化する。
- `scripts/verify_modset.sh` は `mod-list.json` を検査し、enabled な mod が `base`, `elevated-rails`, `quality`, `space-age`, `fwai_bridge` のみであることを保証する。

## 6. リポジトリ構成（作成対象）
- `README.md`
- `plan.md`（このファイル）
- `configs/scenario.yaml`
- `configs/server-settings.json`
- `scripts/start_server.sh`
- `scripts/start_client_mac.sh`
- `scripts/run_controller.sh`
- `scripts/verify_modset.sh`
- `mod/fwai_bridge/info.json`
- `mod/fwai_bridge/control.lua`
- `controller/pyproject.toml`
- `controller/src/fwai/main.py`
- `controller/src/fwai/config.py`
- `controller/src/fwai/rcon_client.py`
- `controller/src/fwai/protocol.py`
- `controller/src/fwai/constraints.py`
- `controller/src/fwai/loop.py`
- `controller/src/fwai/policies/mvp_space_policy.py`
- `controller/src/fwai/policies/space_age_policy.py`
- `controller/tests/test_protocol.py`
- `controller/tests/test_constraints.py`
- `controller/tests/test_policy.py`
- `logs/`（git 管理外）

## 7. 公開インターフェース
### 7.1 RCON コマンド
- `/fwai.health`
- `/fwai.observe <base64-json>`
- `/fwai.act <base64-json>`
- `/fwai.bot_state <base64-json>`
- `/fwai.reset <base64-json>`

### 7.2 Protocol v1（JSON）
共通:
- `v`
- `request_id`
- `tick`

`observe.request`:
- `scope` (`local` | `factory` | `space`)
- `center`
- `radius`

`observe.response`:
- `bot`
- `entities`
- `inventories`
- `research`
- `alerts`
- `planet_context`
- `errors`

`act.request`:
- `type` (`move` | `mine` | `place` | `insert` | `take` | `craft` | `wait` | `set_recipe` | `launch_step`)
- `params`

`act.response`:
- `ok`
- `status` (`pending` | `done` | `failed`)
- `reason`
- `inventory_delta`
- `errors`

## 8. 実装フェーズ
### Phase 0: 基盤
- RCON 疎通
- protocol 実装
- ログ基盤（JSONL）
- Mod allowlist 検証
- 同居起動スクリプト雛形

### Phase 1: 可視 Bot 最小実装
- `fwai-bot` (`spider-vehicle`) エンティティ生成
- 移動
- 手掘り
- アイテム移送（チェスト/インベントリ）
- 最小設置

### Phase 2: MVP（軌道到達 + 滞在）
- Nauvis 基盤構築
- 宇宙到達シーケンス
- 軌道上の運用開始まで自動化

### Phase 3: Space Age 中盤
- 惑星間進行
- 生産ボトルネック回復
- エラーハンドリング強化

### Phase 4: クリアフロー
- `solar-system-edge` 到達までに必要な研究・物流・生産チェーンを統合
- 反復実行での再現性確保

## 9. テスト計画
### Unit
- protocol encode/decode 可逆性
- 各 Gate の許可/拒否判定
- policy 状態遷移

### Integration
- FakeRCON で `observe -> act -> verify`
- RCON 再接続・タイムアウト処理
- 制約違反時の拒否とエラー理由

### E2E
- 同一 macOS 同居で 30 分連続稼働
- 観測者同席で制約違反ゼロ
- MVP 達成（軌道到達 + 滞在）
- Windows LAN 観測接続確認
- 最終ゴール達成時に force 勝利状態へ入ることを確認

## 10. 受け入れ基準
1. 制約違反イベント 0 件（ログ監査）
2. 可視 Bot が全工程で存在
3. 人間介入なしで MVP 達成
4. 再実行で主要マイルストーン順序が再現
5. 最終実行で `solar-system-edge` 到達による Space Age 勝利が発火

## 11. リスクと緩和
- リスク: Steam 自動更新で互換崩れ  
  緩和: 起動前バージョンチェック、互換外なら停止
- リスク: 専用 Bot 実装の複雑化  
  緩和: `spider-vehicle` を土台にして移動と可視性を既存機能へ寄せ、採掘/設置のみ段階拡張
- リスク: 観測データ肥大化  
  緩和: scope/radius 制限、必要時のみ詳細取得

## 12. 最初の実装順（実作業）
1. `scripts/start_server.sh`, `configs/server-settings.json`, `scripts/verify_modset.sh`
2. `mod/fwai_bridge` の `health/observe/act` 最小骨格
3. `controller` の protocol + RCON + loop
4. Phase 1 action（move/mine/place/insert）
5. MVP policy 実装と E2E 1本目
