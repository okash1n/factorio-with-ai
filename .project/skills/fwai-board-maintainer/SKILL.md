---
name: fwai-board-maintainer
description: Maintain the local Kanban board for this repository. Use when implementation state changes, cards need to move, descriptions need notes, or completed tasks should be split and closed.
metadata:
  scope: repo-local
---

# FWAI Board Maintainer

この skill は、このリポジトリの `board/` を更新するときに使う。

## Trigger

次の依頼で使う。

- Kanban を更新して
- board を整えて
- task を完了にして
- 途中で task の内容が変わったから直して

## Read First

必要な範囲で次を読む。

1. `board/README.md`
2. `board/cards/*.md`
3. `board/server.py`
4. `plan.md`

## Workflow

1. 実装状態を確認する  
   コード、ログ、起動状態、記事、notes を見て、実際にどこまで進んだかを確認する。

2. 関連カードを特定する  
   既存 card で表現できるかを先に見る。足りなければ新しい card を追加する。

3. card を更新する  
   `board/cards/00001.md` 形式で更新する。
   - 状態が変わったら `column` を更新する
   - 完了した card は `done` に移す
   - 残作業は別 card に切り出す
   - task の意味が変わったら description に注記を残す

4. board を refresh する  
   `scripts/refresh_board.sh` を実行して `board/board.json` の `updated_at` を更新する。

5. 検証する  
   card の front matter、列 ID、position、board 表示に問題がないか確認する。

## Rules

- `board/cards/*.md` が source of truth
- card の説明は「何が済んだか」「何が残っているか」を短く明示する
- 完了した task に未完了作業を混ぜない
- card が完了したら `done` に移し、残りは別 card へ切り出す
- 実装が進んだのに board が古いまま、を残さない

## Tools

- refresh: `scripts/refresh_board.sh`
- local board server: `scripts/start_board.sh`
- launchd: `scripts/launchd_board.sh`
