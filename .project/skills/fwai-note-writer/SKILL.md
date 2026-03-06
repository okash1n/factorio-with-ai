---
name: fwai-note-writer
description: Write or update serialized note articles for this repository's Factorio with AI project. Use when the user asks to create, revise, or extend articles under notes/, including screenshots and recurring progress posts.
metadata:
  scope: repo-local
---

# FWAI Note Writer

この skill は、このリポジトリ限定で `notes/` 配下の記事を作るときに使う。

## Trigger

次の依頼で使う。

- note 記事を書いて
- `notes/` に次の記事を追加して
- この記事を修正して
- 画像を撮って記事に差し込んで

## Read First

記事作成の前に、必要な範囲で次を読む。

1. `.git/info/okash1n-article-style.md`
2. `notes/README.md`
3. `plan.md`
4. `README.md`

進捗記事なら、実装状況を確認するために必要なコードやログも読む。

## Workflow

1. 事実確認  
   実装済み機能、起動状況、接続状況、画像の有無を確認する。進んでいないことは書かない。

2. 記事ディレクトリ作成  
   新規記事は `scripts/new_note_article.sh --slug ... --title ...` を使って `notes/NNN-slug/` を作る。

3. 画像取得  
   Factorio の画面を使うなら、先に必要なスクリーンショット一覧を定義する。各画像について次を明示する。
   - 目的
   - 構図
   - 条件
   - 成否条件

   構図の準備はユーザーがゲーム内で行い、その後に `scripts/capture_factorio_window.sh --article-dir ... --alt ...` を使って取得する。

4. 本文作成  
   `article.md` を更新する。画像は `./images/...` の相対パスで参照する。

5. 検証  
   画像パス、記事パス、見出し構成を確認する。

## Writing Rules

- 文体は `okash1n-article-style.md` を優先する
- 連載タイトルは原則 `Factorio Space AgeをCodexにクリアさせたい DayXX` に統一する
- `DayXX` は公開日ではなく連載番号として扱う
- 見出しは `#`, `##`, `###` までに制限し、`####` 以降は使わない
- note 用記事ではインラインコードを使わない
- 丸括弧での強調や疑似インラインコードは使わない
- 技術用語、コマンド名、識別子は太字か『』か [ ] で表記する
- 結論を先に出す
- AI にゲームをやらせたときにどこまで高度な自動化が組めるかを主題にする
- 単なるデモ紹介で終わらせず、制約・設計・実装・観測のノウハウまで書く
- 日付や時点は具体的に書く
- スクリーンショットは「何が確認できる画像か」を本文で説明する
- 撮影前に、エージェント側からユーザーへ構図と条件を具体的に指示する

## Notes Structure

```text
notes/
  001-kickoff/
    article.md
    images/
```

## Tools

- 新規記事: `scripts/new_note_article.sh`
- スクリーンショット: `scripts/capture_factorio_window.sh`
- テンプレート: `notes/templates/`
