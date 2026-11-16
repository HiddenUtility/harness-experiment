---
name: git-create-branch
description: >
  mainまたはdevブランチから作業用ブランチを作成する。
  ユーザーにイシュー番号と作業概要を確認し、
  features/<issue-number>-<description> 形式のブランチを作成して
  リモートリポジトリにpushする。
---

# Git Create Branch Skill

## 1. Purpose

mainまたはdevブランチから、新しい作業用ブランチを作成してください。

ユーザーに作業内容とイシュー番号を確認し、適切なブランチ名を生成してください。

ブランチ作成後は、リモートリポジトリにもpushしてください。

## 2. Execution Rules

- Gitコマンドはターミナルから実行してください。
- Git操作の結果を必ず確認してください。
- ユーザーの既存変更を破棄してはいけません。
- 既存ブランチを削除・上書きしてはいけません。
- ブランチ作成後はリモートにpushしてください。
- Git操作に失敗した場合は処理を停止してください。

## 3. Workflow

### Step 1: Check Current Branch

現在のブランチを確認してください。

```bash
git branch --show-current
```

以下のブランチにいる場合のみ処理を続行してください。

- main
- dev

それ以外のブランチにいる場合は、現在のブランチ名を表示して終了してください。

### Step 2: Ask User for Requirements

ユーザーに以下の2点を確認してください。

1. Issue Number
   - GitHub Issueの番号
   - Issueが存在しない場合は `none` を指定可能

2. Task Description
   - これから実施する作業の概要
   - できるだけ具体的な内容

不足している情報がある場合は、追加で質問してください。

### Step 3: Generate Branch Name

以下の形式でブランチ名を生成してください。

```text
features/<issue-number>-<description>
```

Issue Numberが `none` の場合:

```text
features/<description>
```

命名ルール:

- 英語の小文字を使用する。
- 単語の区切りにはハイフン `-` を使用する。
- 空白や特殊文字を使用しない。
- 内容を簡潔に表現する。
- Issue Numberがある場合は先頭に配置する。
- 既存ブランチと重複しないことを確認する。

例:

```text
features/123-add-user-authentication
features/456-fix-login-validation
features/update-logger
```

生成したブランチ名をユーザーに表示してください。

### Step 4: Check Working Tree

現在の作業状態を確認してください。

```bash
git status --short
```

未コミットの変更がある場合は、安全のため処理を停止してください。

変更内容を破棄したり、勝手にstashしたりしてはいけません。

ユーザーにコミットまたはstashなどの操作を依頼してください。

### Step 5: Update Base Branch

現在のブランチを最新状態に更新してください。

```bash
git fetch origin
git pull --ff-only
```

失敗した場合は処理を停止してください。

### Step 6: Create Branch

生成したブランチ名で新しいブランチを作成してください。

```bash
git switch -c <branch-name>
```

作成後、現在のブランチ名を確認してください。

```bash
git branch --show-current
```

### Step 7: Push Remote Branch

作成したブランチをリモートにpushしてください。

```bash
git push -u origin <branch-name>
```

失敗した場合は処理を停止し、ユーザーに必要な操作を依頼してください。

### Step 8: Verify

以下を確認してください。

```bash
git status --short
git branch -vv
```

- 現在のブランチが作成したブランチであること。
- リモートブランチが存在すること。
- upstreamが正しく設定されていること。

## 4. Error Handling

Git操作に失敗した場合:

1. 失敗したコマンドを表示する。
2. エラーメッセージを表示する。
3. 原因が分かる場合は説明する。
4. ユーザーに必要な操作を依頼する。
5. それ以上のGit操作を行わず終了する。

禁止事項:

- `git reset --hard`
- `git checkout --`
- `git restore`
- 強制push
- ユーザーの変更を破棄する操作
- エラーを無視した処理の続行

## 5. Completion Report

正常終了した場合、以下を報告してください。

- 作成したブランチ名
- 作成元のブランチ名
- Issue Number
- リモートpushの結果
- 現在のブランチ名

