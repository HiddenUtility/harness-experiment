codex（AIエージェント） に実装させるための仕様書を Markdown で出力してください．
パラメータが少ないモデルでも間違いなく作成できるような詳細な仕様書のプロンプトを書いてください．
不明点あればきいてください．
仕様書の素案は下記を参照してください．

---
# 全体
- Rust使用
- Tokio使用
- クレートのsrc階層にはREADME.mdを用意して，簡単なドキュメントとサンプルコードを準備する．
- docstringに仕様書いて，コメントアウトによる説明は極力書かないようにする．
- lib.rs に全部書かずに適切にファイル分割すること

## 実装
- camelCase, snake_case, PascalCase, kebab-case の ケーススタイルへ変換する関数
    - to_snake, to_camel, to_pascal, to_kebab など．
    - 引数は文字列
    - 英数字のみで，それ以外は Result エラー