# ハーネス駆動開発のための自己進化スキル構築

AIが勝手に改善して，自己開発できるのが 2026年の主流
手綱は人が握るといういみで，ハーネスを設計して，その中で，AIに自由に動き回ってもらう必要がある．

## 1. はじめに

1. repo を構築する．
1. AGENTS.md を参考に AGENTS.md を repo に配置する．
1. codex を repo で起動する．
1. first_ask.md を参考に プロンプトを投げ，ハーネス駆動開発に必要な環境構築をさせる．


## 2. スキルファースト
スキルをトリガーにして，ループを回す
skill -> dry run -> act -> qc guard -> memory -> eval -> skill 改善 -> dry run 

| スキル名 | 役割 |
|---|---|
| <業務スキル> | 例: 不具合修正を標準化する業務スキル |
| retro | 業務スキル実行後の振り返りを行うスキル |
| eval-skill | スキルの品質を評価するスキル |
| improve-skill | 振り返りをもとにスキルを改善するスキル |

バグ修正の例
```
以下の不具合修正のスキルを作って下さい。
- スキルの形式は bugfix を参考にしてくだい．
- スキルの要件については AskUserQuestion で質問して下さい。
- スキル自体は、再現性をドライランで評価して下さい。
- ドライラン評価結果を `docs/dryrun-reports/` 内にレポートとして出力してください。
- 評価レポートの出力形式は (`docs/dryrun-reports/eval_report_$(date +%Y%m%d_%H%M%S).md`)

<依頼内容>

```

## 環境

Windows11 pro
wsl ubuntu.H26.4

codex

ollama
gemma4:26b
qwen3.8:27b

