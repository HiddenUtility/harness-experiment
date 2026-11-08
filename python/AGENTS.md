## Rules
- 日本語で会話してください．

## Project Overview
本プロジェクトは、Pythonを用いて社内ナレッジを活用し、分析や不具合解析、改善提案を行うAIエージェントを開発するためのものです。
オフライン環境での運用を想定し、LLMの実行には Ollama を使用します。
また、拡張性を確保するため、ローカルツールやダミーのMCP（Model Context Protocol）の実装を想定した設計を行います。

## Technical Stack
- **Language**: Python
- **LLM Engine**: Ollama (Local/Offline)
- **Linting/Formatting**: ruff (PEP8準拠)
- **Testing**: pytest

## Directory Structure
- `src/`: ソースコードのメインディレクトリ
- `tests/`: pytest によるテストコードのディレクトリ
- `scripts/`: 補助的なスクリプト

## Development Rules
- **Code Style**: PEP8を厳守し、`ruff` を使用して品質を維持してください。
- **Type Hinting**: 型ヒントを積極的に使用し、コードの可読性と安全性を高めてください。
- **Documentation**: 関数やクラスには、内容を説明するDocstringを記述してください。

## Git Workflow
- **Flow**: GitHub Flow をベースとし、`dev` ブランチを介した運用を行います。
- **Branching Strategy**:
  - `dev` ブランチから `feature/` ブランチを切って作業を行います。
  - `feature/` から `dev` へのマージは、AIエージェントのみで完結（自動化）させます。
  - `dev` から `main` へのマージは、人間によるレビューと承認が必要です。

## CI/CD & Automation
- **Automated Testing**: `pytest` を使用し、関数レベルの単体テストは CI で自動実行します。
- **Manual Testing**: Ollama との通信を伴う統合テストや、LLMの挙動確認は手動で行います。
- **Approval**: 可能な限りプロセスを自動化し、AIエージェントが自律的に作業を進められるようにします。

## Agent Capabilities & Skills
- **Knowledge Access**: 社内ナレッジにアクセスするためのツール（Tools）を実装します。
- **Analysis & Debugging**: ログやデータを分析し、不具合の原因特定および改善案を提示する能力を目指します。
- **Extensibility**: MCP (Model Context Protocol) を用いた外部連携や、ローカルツールの追加を容易な構造にします。
