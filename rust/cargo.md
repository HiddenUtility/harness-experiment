# Rust `cargo` よく使うコマンド一覧

日常の開発やワークスペース管理で頻繁に使用する `cargo` コマンドのチートシートです。

---

## 1. ワークスペース（Workspace）の操作

複数のクレート（パッケージ）を1つのリポジトリで管理する際の基本コマンドです。

### ワークスペースの初期化
ワークスペースのルートディレクトリを作成し、ルートの `Cargo.toml` を用意します。

```bash
mkdir my-workspace && cd my-workspace
# ルート用の Cargo.toml を手動で作成し、以下を記述します
```

**ルートの `Cargo.toml` の記述例:**
```toml
[workspace]
resolver = "2"
members = [
    # ここにクレートが追加されていきます
]
```

### ワークスペースにクレートを追加
ルートの `Cargo.toml` が存在するディレクトリで実行すると、自動的に `members` に追記されます。

* **バイナリクレート（実行ファイル）の追加:**
  ```bash
  cargo new crates/my-app
  ```
* **ライブラリクレートの追加:**
  ```bash
  cargo new --lib crates/my-lib
  ```

### ワークスペース内のクレート同士を依存関係に追加
`my-app` から `my-lib` を利用したい場合：

```bash
cargo add -p my-app --path crates/my-lib
```

### 特定のクレートを指定してビルド・実行
```bash
# 特定のクレートをビルド
cargo build -p my-app

# 特定のクレートを実行
cargo run -p my-app

# ワークスペース全体をビルド
cargo build --workspace
```

---

## 2. ビルド・実行・依存関係管理

| コマンド | 説明 |
| :--- | :--- |
| `cargo check` | コンパイルが通るか高速にチェック（バイナリは生成しない） |
| `cargo build` | デバッグビルドを実行 |
| `cargo build --release` | 最適化を有効にしたリリースビルドを実行 |
| `cargo run` | ビルドして実行（`--release` も併用可能） |
| `cargo add <クレート名>` | `Cargo.toml` に依存クレートを追加（例: `cargo add serde -F derive`） |
| `cargo remove <クレート名>` | 依存クレートを削除 |
| `cargo update` | `Cargo.lock` を更新し、依存クレートを最新バージョンにアップデート |
| `cargo clean` | `target/` ディレクトリを削除してビルドキャッシュをクリア |

---

## 3. テスト（Test）

### 全体テスト
* **単一クレートの全テストを実行:**
  ```bash
  cargo test
  ```
* **ワークスペース全体の全テストを実行:**
  ```bash
  cargo test --workspace
  ```

### 個別テスト・絞り込み実行
* **特定のクレートのテストのみ実行:**
  ```bash
  cargo test -p my-lib
  ```
* **特定のテスト関数（またはモジュール）名を含むテストを実行:**
  ```bash
  # 名前に "test_add" を含むテストを実行
  cargo test test_add

  # 完全一致で実行する場合
  cargo test test_add -- --exact
  ```
* **結合テスト（`tests/` ディレクトリ内の特定ファイル）のみ実行:**
  ```bash
  cargo test --test integration_test_name
  ```
* **ドキュメンテーションテスト（Doc-tests）のみ実行:**
  ```bash
  cargo test --doc
  ```

### テスト時の便利なオプション
`--` の後ろにテストバイナリ自体へのオプションを渡せます。

```bash
# テスト内の println! の標準出力を常に表示する
cargo test -- --nocapture

# テストを並列実行せず1スレッドずつ順番に実行する（DBアクセスや環境変数を使うテストに有効）
cargo test -- --test-threads=1

# #[ignore] アトリビュートがついたテストも含めてすべて実行
cargo test -- --include-ignored
```

---

## 4. Linter（Clippy） & Formatter（rustfmt）

コードの品質維持やフォーマット統一のためのコマンドです。

### Formatter (`cargo fmt`)
* **コードの自動整形を実行:**
  ```bash
  cargo fmt
  # ワークスペース全体の場合
  cargo fmt --all
  ```
* **整形が必要かどうかチェックのみ行う（CI などで便利）:**
  ```bash
  cargo fmt --all -- --check
  ```

### Linter (`cargo clippy`)
* **静的解析を実行して改善提案を表示:**
  ```bash
  cargo clippy
  # ワークスペース全体（テストコード含む）をチェック
  cargo clippy --workspace --all-targets
  ```
* **警告（Warning）をエラーとして扱う（CI などで厳格にチェックしたい場合）:**
  ```bash
  cargo clippy --workspace --all-targets -- -D warnings
  ```
* **Clippy の提案に従ってコードを自動修正:**
  ```bash
  cargo clippy --fix
  ```

---

## 5. ドキュメント生成

* **依存クレートも含めたドキュメントを生成してブラウザで開く:**
  ```bash
  cargo doc --open
  ```
* **自分のクレートのみのドキュメントを生成（ビルド時間短縮）:**
  ```bash
  cargo doc --no-deps --open
  ```