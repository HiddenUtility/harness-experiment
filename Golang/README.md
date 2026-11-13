# UbuntuでのGo言語（Golang）開発ガイド

本ドキュメントは、Ubuntu環境におけるGo言語のインストールから、標準的なプロジェクト構成の構築、コーディングルール（ベストプラクティス）、テストの実装・自動化、そしてGitHub Actionsを用いたCI環境の構築までの手順をまとめた開発リファレンスです。

---

## 1. Go言語の概要
**Go言語（Golang）**は、Googleが開発したオープンソースのプログラミング言語です。
* **特徴**: シンプルで読みやすい構文、高速なコンパイル、Goroutineによる優れた並行処理性能。
* **主な用途**: WebバックエンドAPI、マイクロサービス、CLIツール、クラウドインフラ開発など。

---

## 2. Ubuntu環境へのインストール（自動セットアップ）

Ubuntuの標準リポジトリ（`apt`）に含まれるGoはバージョンが古いことが多いため、公式サイトから最新のLinux用バイナリを直接ダウンロードしてセットアップします。

以下のコマンドをターミナルに貼り付けて実行すると、最新安定版のダウンロード・展開・環境変数（`PATH`）の設定までが一括で完了します。

```bash
# 1. 公式サイトから最新のGoのバージョンを自動取得してダウンロード
GO_VERSION=$(curl -s https://go.dev/dl/?mode=json | grep -o '"version": "go[^"]*"' | head -n 1 | cut -d'"' -f4)
echo "最新バージョン ${GO_VERSION} をダウンロードしています..."
wget https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz

# 2. 古いバージョンを削除し、/usr/local に展開
echo "Goを展開しています..."
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf ${GO_VERSION}.linux-amd64.tar.gz
rm ${GO_VERSION}.linux-amd64.tar.gz

# 3. パスを通す（~/.bashrc と ~/.profile の両方に安全に追加）
if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
fi
if ! grep -q "/usr/local/go/bin" ~/.profile; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
fi

# 4. 現在のセッションにパスを即座に反映し、バージョンを確認
export PATH=$PATH:/usr/local/go/bin
go version
```

> **補足**: `~/.profile` はログイン時に、`~/.bashrc` は新しいターミナルを開くたびに読み込まれます。両方に安全に追記することで、どの環境からでも確実に `go` コマンドが認識されます。

---

## 3. プロジェクトのディレクトリ構成（ベストプラクティス）

実務やチーム開発でも通用する、標準的なディレクトリ構成（`golang-standards/project-layout` ベース）を採用します。

```text
my-go-project/
├── .github/
│   └── workflows/
│       └── ci.yml           # GitHub Actions ワークフロー定義
├── cmd/
│   └── myapp/
│       └── main.go          # アプリケーションのエントリーポイント
├── internal/                # 外部プロジェクトからのインポートを禁止する内部パッケージ
│   ├── handler/             # HTTPハンドラー / ルーティング層
│   ├── service/             # ビジネスロジック層
│   └── repository/          # データベース・外部APIアクセス層
├── pkg/                     # 外部から再利用可能な公開ライブラリ（必要に応じて）
├── api/                     # OpenAPI/Swagger仕様書、Protocol Buffers定義など
├── configs/                 # 設定ファイルテンプレート
├── go.mod                   # モジュール定義ファイル
├── go.sum                   # 依存関係のチェックサム
├── run_tests.sh             # ローカル・CI兼用のテスト自動実行スクリプト
└── README.md
```

### プロジェクト自動生成スクリプト (`create_go_project.sh`)

以下のスクリプトを実行することで、上記のディレクトリ構造とヘルスチェック用HTTPサーバーの雛形を一瞬で作成できます。

```bash
#!/bin/bash
set -e

PROJECT_NAME=${1:-my-go-project}
echo "🚀 Goプロジェクト '${PROJECT_NAME}' のディレクトリ構成を作成しています..."

mkdir -p "${PROJECT_NAME}"
cd "${PROJECT_NAME}"

go mod init "${PROJECT_NAME}"

mkdir -p cmd/"${PROJECT_NAME}"
mkdir -p internal/handler internal/service internal/repository
mkdir -p pkg api configs .github/workflows

# サンプルの main.go を作成
cat << 'EOF' > cmd/"${PROJECT_NAME}"/main.go
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("OK"))
	})

	port := ":8080"
	fmt.Printf("Server is running on http://localhost%s\n", port)
	if err := http.ListenAndServe(port, mux); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
EOF

# サンプルの .gitignore を作成
cat << 'EOF' > .gitignore
/bin/
/dist/
.env
coverage.out
.DS_Store
EOF

echo "✨ 完了しました！ 'cd ${PROJECT_NAME} && go run cmd/${PROJECT_NAME}/main.go' で起動できます。"
```

**使い方:**
```bash
chmod +x create_go_project.sh
./create_go_project.sh myapp
```

---

## 4. コーディングルール（ベストプラクティス）

Goでは「誰が書いても同じようなコードになること（可読性と一貫性）」が重視されます。公式の「Effective Go」や「Go Code Review Comments」に基づく基本ルールです。

### ① フォーマットと静的解析の徹底
* **`gofmt` / `goimports` の強制**: インデント（タブ文字を使用）やスペースの入れ方は議論せず、必ず `gofmt`（または保存時に自動フォーマットするエディタ設定）に従います。
* **Linterの活用**: 標準の `go vet` に加え、実務では `golangci-lint` を導入して静的解析を行うのが一般的です。

### ② 命名規則（Naming Conventions）
* **キャメルケース（CamelCase）を使用**: スネークケース（`user_name`）は使わず、キャメルケースを使います。
* **公開（Exported）と非公開（Unexported）**:
  * 先頭が**大文字**（例: `GetUser`）：外部パッケージからアクセス可能（Public）。
  * 先頭が**小文字**（例: `parseToken`）：同じパッケージ内のみアクセス可能（Private）。
* **頭字語（Acronyms）は大文字を揃える**: `userId` や `httpUrl` ではなく、`userID`、`HTTPURL`、`JSONData` のように大文字・小文字を統一します。
* **変数名は短く簡潔に**: スコープが狭い変数（ループカウンタやレシーバなど）は `i`, `v`, `r`, `ctx` のように短く命名し、パッケージ名と重複する命名（例: `user` パッケージ内の `UserService`）は避けて `Service` とします。
* **パッケージ名**: すべて小文字の単語1語（`handler`, `service` など）にし、アンダースコアや複数形は避けます。

### ③ エラーハンドリング（Error Handling）
* **エラーは値として明示的に処理する**: 例外（try-catch）はないため、関数の最後の戻り値として `error` を返し、呼び出し元で必ずチェックします。`_`（ブランク識別子）でエラーを握りつぶさないようにします。
* **エラーのラップ（文脈の付与）**: エラーを上位層へ返す際は、`fmt.Errorf("failed to fetch user: %w", err)` のように `%w` を使って原因となるエラーをラップします。
* **早期リターン（Guard Clauses）**: ネストを深くせず、エラーや異常系は `if err != nil { return err }` で早めに処理して正常系の見通しを良くします。

### ④ インターフェースとコンテキストの設計
* **インターフェースは利用側（Consumer）で定義する**: 実装側（`repository` など）ではなく、それを利用する側（`service` など）で「必要なメソッドだけを持つ小さなインターフェース」を定義すると、テスト時のモック化や疎結合な設計が容易になります。
* **`context.Context` の伝播**: タイムアウト制御、キャンセル処理、リクエストスコープの値を扱うため、I/Oや外部通信を伴う関数の第1引数には慣例として `ctx context.Context` を渡します。

---

## 5. テストの書き方と運用・自動実行

Goには標準で `testing` パッケージが備わっており、外部フレームワークなしで高品質なテストを記述できます。

### テストの基本ルールとテーブル駆動テストの例
* **ファイル名**: `*_test.go`（例: `calculator_test.go`）
* **関数名**: `TestXxx(t *testing.T)`

```go
package service

import "testing"

func Add(a, b int) int {
	return a + b
}

// テーブル駆動テスト（Goのベストプラクティス）
func TestAddTableDriven(t *testing.T) {
	tests := []struct {
		name     string
		a, b     int
		expected int
	}{
		{"positive numbers", 2, 3, 5},
		{"negative numbers", -1, -1, -2},
		{"with zero", 5, 0, 5},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Add(tt.a, tt.b); got != tt.expected {
				t.Errorf("Add(%d, %d) = %d, expected %d", tt.a, tt.b, got, tt.expected)
			}
		})
	}
}
```

### 品質チェック＆テスト一括実行スクリプト (`run_tests.sh`)

フォーマット検証（`gofmt`）、静的解析（`go vet`）、競合状態検出付きテスト（`-race`）、カバレッジ計測をまとめて実行するスクリプトをプロジェクトルートに配置します。

```bash
#!/bin/bash
set -e

echo "🔍 1. コードのフォーマットと静的解析を実行中..."
UNFORMATTED=$(gofmt -l .)
if [ -n "$UNFORMATTED" ]; then
    echo "⚠️ 以下のファイルがフォーマットされていません:"
    echo "$UNFORMATTED"
    echo "💡 'gofmt -w .' を実行して修正してください。"
    exit 1
fi

go vet ./...

echo "🧪 2. すべてのテストを実行中..."
go test -v -race -coverprofile=coverage.out ./...

echo "📊 3. カバレッジレポートを集計中..."
go tool cover -func=coverage.out

echo "✨ すべてのテストと品質チェックが正常に完了しました！"
```

**実行方法:**
```bash
chmod +x run_tests.sh
./run_tests.sh
```

---

## 6. GitHub Actions によるCI（継続的インテグレーション）

ローカル環境で使用している `run_tests.sh` をGitHub Actions上でもそのまま実行させることで、開発環境とCI環境の挙動を完全に一致させます。

### `.github/workflows/ci.yml`

```yaml
name: Go CI

on:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]

jobs:
  test:
    name: Run Tests & Linters
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: 'stable'
          cache: true

      - name: Install dependencies
        run: go mod download

      - name: Run test script
        run: |
          chmod +x run_tests.sh
          ./run_tests.sh
```

このファイルをリポジトリにプッシュすると、以降 `main` ブランチへのプッシュやプルリクエスト作成時に自動でテストとコード品質チェックが実行されます。