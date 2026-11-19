# Go よく使うコマンド一覧

日常の開発やワークスペース管理で頻繁に使用する `go` コマンドおよび周辺ツールのチートシートです。

## 1. ワークスペース（Workspace）の操作

複数の Go モジュール（`go.mod`）を1つのリポジトリやローカル環境でまとめて開発する際のコマンドです（Go 1.18 以降）。

### ワークスペースの初期化

ワークスペースのルートディレクトリで `go.work` ファイルを生成します。

```bash
mkdir my-workspace && cd my-workspace
go work init
```

### ワークスペースにモジュールを追加

既存のモジュール、または新規作成したモジュールをワークスペースに登録します（`go.work` に追記されます）。

* **新規モジュールを作成して追加する例:**
  ```bash
  mkdir -p services/my-app
  (cd services/my-app && go mod init example.com/my-app)
  go work use ./services/my-app
  ```
* **サブディレクトリ内の全モジュールを一括で追加:**
  ```bash
  go work use -r .
  ```

### ワークスペース内のモジュール同士を依存関係に追加

`go.work` に両方のモジュールが登録されていれば、**`go.mod` を書き換えずに**そのまま `import` してローカルの変更をリアルタイムに参照できます。

```go
// services/my-app/main.go
import "example.com/my-lib"
```

※ `go.work` を使わず単一モジュール間でローカル参照したい場合は `go mod edit -replace` を使用します。

### 特定のモジュールを指定してビルド・実行

```bash
# 特定のモジュール（パッケージ）をビルド
go build ./services/my-app/...

# 特定のアプリケーションを実行
go run ./services/my-app/cmd/server

# ワークスペース内の全モジュールをビルド（Go 1.21+）
go build work
```

## 2. ビルド・実行・依存関係管理

| コマンド | 説明 |
| :--- | :--- |
| `go mod init <モジュール名>` | 新しいモジュールを初期化（`go.mod` を生成） |
| `go mod tidy` | 未使用の依存を削除し、不足している依存を `go.mod` / `go.sum` に追加・整理 |
| `go get <パッケージ名>` | 依存パッケージを追加・更新（例: `go get github.com/gin-gonic/gin@latest`） |
| `go build ./...` | カレントディレクトリ配下の全パッケージをビルド |
| `go build -o bin/app ./cmd/app` | 出力先ファイル名を指定してビルド |
| `go run main.go` | コンパイルしてそのまま実行 |
| `go clean -cache` | ビルドキャッシュをクリア（テストキャッシュは `-testcache`） |

## 3. テスト（Test）

### 全体テスト

* **カレントモジュール配下の全テストを実行:**
  ```bash
  go test ./...
  ```
* **ワークスペース全体の全テストを実行:**
  ```bash
  go test work
  ```

### 個別テスト・絞り込み実行

* **特定のパッケージのテストのみ実行:**
  ```bash
  go test ./pkg/calculator
  ```
* **特定のテスト関数名（正規表現）に一致するテストを実行:**
  ```bash
  # 名前に "TestAdd" を含むテストを実行
  go test -run TestAdd ./...

  # 完全一致で実行する場合
  go test -run '^TestAdd$' ./...

  # サブテスト（t.Run）を指定して実行する場合
  go test -run 'TestAdd/negative_numbers' ./...
  ```

### テスト時の便利なオプション

```bash
# 詳細なログ（t.Log や fmt.Println）をすべて表示する（キャッシュも無効化される）
go test -v ./...

# テストキャッシュを使わずに強制再実行する
go test -count=1 ./...

# データ競合（Race Condition）の検出を有効にしてテスト（並行処理のテストに必須）
go test -race ./...

# テストカバレッジ率を表示する
go test -cover ./...

# カバレッジ結果をファイルに出力し、ブラウザで視覚的に確認する
go test -coverprofile=coverage.out ./... && go tool cover -html=coverage.out
```

## 4. Linter & Formatter

Go は公式のフォーマッタが標準搭載されており、Linter は標準の `go vet` とサードパーティの `golangci-lint` を併用するのが一般的です。

### Formatter (`gofmt` / `go fmt`)

Go のフォーマットスタイルは公式で完全に統一されており、設定ファイルは存在しません。

* **コードの自動整形を実行:**
  ```bash
  go fmt ./...
  # または gofmt を直接使う場合（-w でファイル上書き、-s でコード簡略化）
  gofmt -s -w .
  ```
* **整形が必要かどうか差分を表示・チェックのみ行う（CI などで便利）:**
  ```bash
  gofmt -d .
  # 差分があればエラー終了させたい場合
  test -z "$(gofmt -l .)"
  ```

### Linter (`go vet` / `golangci-lint`)

* **公式標準の静的解析を実行:**
  ```bash
  go vet ./...
  ```
* **デファクトスタンダードの統合 Linter（`golangci-lint`）を実行:**
  ※ 別途インストールが必要（`go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest`）
  ```bash
  # プロジェクト全体をリント
  golangci-lint run

  # 自動修正可能な箇所を修正
  golangci-lint run --fix
  ```

## 5. ドキュメント確認

Go ではコード内のコメントがそのままドキュメントになります。

* **ターミナル上でパッケージや関数のドキュメントを確認:**
  ```bash
  go doc fmt.Println
  go doc ./pkg/calculator
  ```
* **ローカルでドキュメントサーバーを起動（要 `pkgsite` インストール）:**
  ```bash
  # インストール: go install golang.org/x/pkgsite/cmd/pkgsite@latest
  pkgsite -open .
  ```