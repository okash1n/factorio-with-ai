# factorio-with-ai project instructions

このファイルは、このリポジトリ限定の追加指示です。

## 基本

- 応答は日本語
- 記事作成や `notes/` 更新の依頼では、まず `.project/skills/fwai-note-writer/SKILL.md` を読む
- 実装進捗を書く前に、必ず現状のコード・設定・起動状態を確認する

## note 記事運用

- 記事は `notes/NNN-slug/article.md`
- 画像は `notes/NNN-slug/images/`
- 新規記事は `scripts/new_note_article.sh` を使って作る
- Factorio の画面取得は `scripts/capture_factorio_window.sh` を優先する
- 記事用スクリーンショットを撮る前に、必ず「目的 / 構図 / 条件 / 成否条件」をユーザーへ提示する
- ゲーム内の構図調整はユーザーが行い、その状態になってから画面取得する
- 記事本文では画像を相対パスで参照する
- 連載タイトルは原則 `Factorio Space AgeをCodexにクリアさせたい DayXX` を使い、`DayXX` は連載番号として扱う
- 記事の見出しレベルは `###` までに制限する
- note 用記事ではインラインコードを使わず、丸括弧も避ける。技術用語は太字か『』か [ ] で表記する
- リード文の直後に `## 固定リンク` を置き、少なくともリポジトリと記事まとめを載せる
- 記事の主題は「AI にゲームをやらせたときにどこまで高度な自動化が組めるか」とし、技術ノウハウも併せて書く
- 文体は `.git/info/okash1n-article-style.md` を優先する

## 禁止

- 実際に確認していない進捗を記事に書かない
- 画像ファイルが存在しないのに Markdown 参照だけを置かない
