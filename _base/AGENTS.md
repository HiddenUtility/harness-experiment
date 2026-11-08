## Rules
- 日本語で会話してください．


## FQA
### Q1. AIエージェントとスキル定義形式
codex 前提で構築する

### Q2. プロジェクトの構築方針

今回は rust のプロジェクトです．

### Q3. ツールチェーンと品質ガード

- Rust の標準的なツール（cargo, clippy, rustfmt）および cargo test を使用する想定でよろしいでしょうか？
- その他、導入を希望される静的解析ツールやセキュリティチェックツールはありますか？

cargo 標準 cargo, clippy, rustfmt および cargo test でお願いします．

### Q4. CI/CD および 自動化の仕組み

GitHub Actions を想定します．
util集なので単体テストを書き，それをCIでテストするのみとします．

### Q5. Git 運用ルール

基本的にはGitHub Flow を使用しますが， dev リポジトリも使用します．dev から featureを切って 作業し，dev へ マージします．
dev への merge は AIエージェントのみで完結してください．


### Q6. スキルの配置場所
codex を 使用するので .agents/skills/ に配置してください．

### Q7. 承認フロー


基本すべて自動でお願いします．

