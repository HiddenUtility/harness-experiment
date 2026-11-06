## Rules
- 日本語で会話してください．



## 1. AIエージェントとスキル
codex 前提で skills を 構築します．

### スキル定義形式
```Markdown
---
name: my-awesome-skill
description: |
  このスキルが何をするか、いつ使うかを記述します。
  Use when: 呼び出し条件やトリガーワード
  Accepts args: <required-arg> [--optional-flag]
---


# スキルタイトル

エージェントへの詳細な手順、ルール、出力フォーマットを記述します。
```

必要に応じて補助ファイル作成
```
my-skill/
├── SKILL.md               # 必須：メインの定義ファイル
├── scripts/               # 実行するスクリプト（必要に応じて）
├── references/            # 参照用の資料・ドキュメント
├── assets/                # テンプレートや画像など
└── agents/
    └── openai.yaml        # ツール依存関係や自動呼び出し設定（allow_implicit_invocation 等）
```
### スキルのドライラン
- ドライライン行った際は，必ず評価レポートを作成する．
- 評価結果を `docs/dryrun-reports/` 内にレポートとして出力する
- 評価レポートの出力形式は (`docs/dryrun-reports/eval_report_$(date +%Y%m%d_%H%M%S).md`)


## 2. プロジェクトの構築方針

今回は rust のプロジェクトです．
rust をつかって ほかのプロジェクトで利用可能な utils を作る repo を目指します．
モノレポにして，キャリーを容易にします．

## 3. ツールチェーンと品質ガード
cargo 標準でお願いします．（cargo, clippy, rustfmt）および cargo test 


## 4. CI/CD および 自動化の仕組み

GitHub Actions を想定します．
ただ，util の クレート集なので デプロイはないです．

## 5. Git 運用ルール
基本的にはGitHub Flow を使用しますが， dev リポジトリも使用します．dev から feature を切って 作業し，dev へ マージします．
作業完了後，PR作成し，dev へのプルリクエストを ユーザーへ促してください．

## 6. スキルの配置場所
SKILL.md は @.agents/skills に 配置する．

## 7. 承認フロー
基本的には自動で行ってください．
dev にマージするときだけ人がPR確認します．
