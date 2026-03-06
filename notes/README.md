# notes 運用

1記事ごとに1ディレクトリを切る。

## 構成

```text
notes/
  001-kickoff/
    article.md
    images/
  templates/
```

## ルール

- 本文は `article.md`
- 画像は `images/` に配置
- 記事内の画像参照は相対パス（例: `![caption](./images/xxx.png)`）
- 見出しレベルは `###` まで
- 記事冒頭の固定構成は「リード文 → `## 固定リンク` → `## 今回の進捗`」
- リード文は短くまとめ、今回やったことと到達点を先に書く
- インラインコードの代替として丸括弧を使わない。丸括弧が自然な文脈では使ってよい
- 新規記事は `scripts/new_note_article.sh --slug ... --title ...` を優先
- Factorio の画面取得は `scripts/capture_factorio_window.sh --article-dir ... --alt ...` を優先
