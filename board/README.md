# board

ローカル Kanban の board 定義です。

## 構成

- `board/board.json`
  - ボード名と列定義
- `board/cards/00001.md`
  - 各タスクの実体

## カードファイル

ファイル名は 5 桁固定です。

- `00001.md`
- `00012.md`
- `12345.md`

意味付きキーはファイル名に使いません。  
`key:` は空欄でも構いません。保存時にサーバー側で埋めます。

```md
---
id: 12
key:
column: next
position: 0
title: 新しいタスク
tags:
  - policy
links:
  - plan.md
---

ここに説明を書く。
```

## 列ID

- `backlog`
- `next`
- `in-progress`
- `blocked`
- `done`
