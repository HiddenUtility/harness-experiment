# Codex Implementation Specification
# 非同期 HTTP クライアント（Rust / Tokio）

## 1. 目的

Rust と Tokio を使用して、非同期 HTTP 通信を行う汎用 HTTP クライアントライブラリを実装する。

`reqwest` を HTTP 通信に使用し、以下の機能を提供する。

- GET / POST / PUT / DELETE による HTTP 通信
- JSON リクエストボディの送信
- JSON レスポンスボディの任意の Rust 構造体への変換
- レスポンスボディを必要としない HTTP 通信
- HTTP ステータスコードに応じたエラー処理
- RFC 9457（Problem Details for HTTP APIs）への対応
- Bearer Token による認証
- 任意の HTTP ヘッダーの追加
- タイムアウト設定
- GET リクエストに対するリトライ
- URL の組み立てとクエリパラメータの追加

本ライブラリは、他の Rust プロジェクトから利用することを想定した汎用ライブラリとする。

実装にあたっては、本仕様書に記載された API、引数、戻り値、処理内容、エラー処理、テスト条件を厳守すること。

仕様にない独自機能を追加したり、既存の仕様を独自判断で変更したりしないこと。

---

## 2. 全体共通仕様

### 2.1. 使用技術

| 項目 | 使用技術 |
|---|---|
| 言語 | Rust |
| 非同期ランタイム | Tokio |
| HTTP クライアント | reqwest |
| JSON シリアライズ | serde |
| JSON デシリアライズ | serde |
| JSON 操作 | serde_json |
| エラー管理 | thiserror（必要に応じて） |

依存クレートは必要最小限にすること。

外部クレートを追加する場合は、以下を守ること。

- MIT / Apache-2.0 / BSD などの利用可能なライセンスを優先する。
- 可能な限り実績のあるクレートを使用する。
- Pure Rust で実装されたクレートを優先する。
- Pure Rust ではないクレートを使用する場合は、その理由を説明する。
- 不要な依存クレートを追加しない。
- 依存クレートのライセンスを確認する。

### 2.2. 実装場所

モノレポ構成の以下の場所に実装する。

```text
pjt/
└── creates/
    └── create-name/
        ├── Cargo.toml
        └── src/
            ├── lib.rs
            ├── client.rs
            ├── client_options.rs
            ├── headers.rs
            ├── url_creator.rs
            ├── errors.rs
            ├── problem_details.rs
            └── README.md
```

ファイル構成は責務に応じて適切に分割すること。

`lib.rs` にすべての実装を記述しないこと。

各ファイルの責務は以下とする。

| ファイル | 責務 |
|---|---|
| lib.rs | モジュール宣言、公開 API の再エクスポート |
| client.rs | 非同期 HTTP クライアントの実装 |
| client_options.rs | HTTP クライアントのオプション |
| headers.rs | HTTP ヘッダーの管理 |
| url_creator.rs | URL の組み立て |
| errors.rs | HTTP 通信エラーの定義 |
| problem_details.rs | RFC 9457 のデータ構造 |

必要に応じてファイルを追加してもよい。

### 2.3. ドキュメント

`src/README.md` を作成すること。

README.md には以下を記載する。

1. ライブラリの概要
2. 提供機能
3. 依存クレート
4. 基本的な使用方法
5. HTTP クライアントの生成方法
6. GET / POST / PUT / DELETE の使用方法
7. レスポンスボディを取得しないメソッドの使用方法
8. Authorization ヘッダーの設定方法
9. 任意の HTTP ヘッダーの設定方法
10. タイムアウト・リトライ設定
11. URL の組み立て方法
12. エラー処理方法
13. RFC 9457 のエラー情報の取得方法

各機能について、実際にコンパイル可能なサンプルコードを掲載すること。

### 2.4. コーディング方針

- 公開 API には Rust の docstring（`///`）で仕様を記述する。
- コメントアウトによる説明は極力使用しない。
- 実装の意図が docstring で分かるようにする。
- 関数や構造体は適切な単位で分割する。
- 不要な `unwrap()` や `expect()` を使用しない。
- エラーを握りつぶさない。
- 非同期処理には Tokio を使用する。
- 公開 API の戻り値には適切なエラー型を使用する。
- HTTP 通信に関するエラーは `HttpClientError` に統一する。

---

## 3. HttpClientError

### 3.1. 目的

HTTP 通信に関するエラーを一元管理するため、`HttpClientError` を定義する。

HTTP ステータスコードのエラーだけではなく、通信エラー、タイムアウト、JSON 変換エラーなども管理する。

### 3.2. エラー型

以下の enum を基本とする。

```rust
pub enum HttpClientError {
    HttpStatus {
        status: u16,
        body: String,
        problem: Option<ProblemDetails>,
    },
    Connection(String),
    Timeout,
    JsonParse(String),
    Request(String),
}
```

各エラーの意味は以下とする。

| エラー | 説明 |
|---|---|
| HttpStatus | HTTP ステータスコードが 200 番台以外 |
| Connection | HTTP サーバーとの通信エラー |
| Timeout | HTTP 通信のタイムアウト |
| JsonParse | JSON のシリアライズ・デシリアライズに関するエラー |
| Request | 不正な URL、ヘッダーなどリクエスト構築時のエラー |

`HttpStatus` の `status` には実際に受信した HTTP ステータスコードを格納する。

`body` には HTTP レスポンスボディの文字列を格納する。

`problem` には RFC 9457 の Problem Details を取得できた場合、その構造体を格納する。

RFC 9457 形式ではない場合や、Problem Details の解析に失敗した場合は `None` とする。

ただし、Problem Details の解析に失敗しても `body` の内容は必ず保持すること。

### 3.3. エラー判定メソッド

以下のメソッドを実装する。

```rust
impl HttpClientError {
    pub fn is_auth_err(&self) -> bool;

    pub fn is_connection_err(&self) -> bool;

    pub fn is_json_parse_err(&self) -> bool;

    pub fn is_timeout(&self) -> bool;

    pub fn is_rate_limit_err(&self) -> bool;

    pub fn status_code(&self) -> Option<u16>;

    pub fn response_body(&self) -> Option<&str>;

    pub fn problem_details(&self) -> Option<&ProblemDetails>;

    pub fn to_err_msg(&self) -> String;
}
```

各メソッドの仕様は以下とする。

#### is_auth_err

HTTP 認証・認可エラーを判定する。

- HTTP 401：true
- HTTP 403：true
- その他：false

#### is_connection_err

`Connection` の場合のみ true を返す。

#### is_json_parse_err

`JsonParse` の場合のみ true を返す。

#### is_timeout

`Timeout` の場合のみ true を返す。

#### is_rate_limit_err

HTTP 429 の場合のみ true を返す。

#### status_code

`HttpStatus` の場合は HTTP ステータスコードを返す。

それ以外は `None` を返す。

#### response_body

`HttpStatus` の場合はレスポンスボディを返す。

それ以外は `None` を返す。

#### problem_details

`HttpStatus` に Problem Details が格納されている場合、その参照を返す。

それ以外は `None` を返す。

#### to_err_msg

エラー内容を文字列で取得する。

以下のような分かりやすいメッセージを返すこと。

| エラー | メッセージ例 |
|---|---|
| Connection | Cannot connect to server. |
| Timeout | Request timed out. |
| JsonParse | Failed to parse JSON response. |
| Request | Invalid HTTP request. |
| HTTP 401 | HTTP authentication failed. |
| HTTP 403 | HTTP authorization failed. |
| HTTP 429 | Too many requests. |
| その他 HTTP エラー | HTTP request failed. |

HTTP ステータスコードなどの詳細情報は、別途 `status_code()` や `response_body()` で取得できるようにする。

### 3.4. エラーの変換

`reqwest::Error` を適切な `HttpClientError` に変換する処理を実装する。

変換の優先順位は以下とする。

1. タイムアウトの場合は `Timeout`
2. 接続エラーの場合は `Connection`
3. その他のリクエスト関連エラーは `Request`

なお、JSON の変換エラーは `serde_json::Error` から `JsonParse` に変換する。

リクエストボディの JSON シリアライズエラーも `JsonParse` に統一する。

---

## 4. RFC 9457（Problem Details）

### 4.1. 目的

HTTP API のエラーレスポンスとして RFC 9457 に対応する。

HTTP ステータスコードだけではなく、サーバーが返したエラーの詳細情報を取得できるようにする。

### 4.2. ProblemDetails 構造体

以下の構造体を実装する。

```rust
#[derive(Debug, Clone, serde::Deserialize)]
pub struct ProblemDetails {
    pub r#type: Option<String>,
    pub title: Option<String>,
    pub status: Option<u16>,
    pub detail: Option<String>,
    pub instance: Option<String>,
}
```

各フィールドは RFC 9457 に準拠する。

| フィールド | 説明 |
|---|---|
| type | 問題の種類を示す URI |
| title | 問題の概要 |
| status | HTTP ステータスコード |
| detail | 問題の詳細 |
| instance | 問題が発生した個別の URI |

すべてのフィールドを省略可能とする。

### 4.3. Problem Details の取得

HTTP ステータスコードが 200 番台以外の場合、レスポンスボディを取得する。

レスポンスの Content-Type が `application/problem+json` の場合、ProblemDetails への変換を試みる。

変換に成功した場合は `HttpClientError::HttpStatus` の `problem` に格納する。

変換に失敗した場合は `problem: None` とする。

どちらの場合でも元のレスポンスボディは `body` に保持すること。

RFC 9457 の解析に失敗したことを理由に、元の HTTP エラーを別のエラーに置き換えてはならない。

---

## 5. Headers

### 5.1. 目的

HTTP リクエストに使用するヘッダーを管理する構造体を実装する。

デフォルトで一般的な JSON API に適したヘッダーを設定する。

### 5.2. 構造体

```rust
pub struct Headers {
    // HTTP ヘッダーを管理する
}
```

内部実装には `reqwest::header::HeaderMap` を使用すること。

### 5.3. デフォルトヘッダー

`Headers::new()` で以下を設定する。

| ヘッダー | デフォルト値 |
|---|---|
| Accept | application/json |
| Content-Type | application/json |

### 5.4. Bearer Token

以下のメソッドを実装する。

```rust
impl Headers {
    pub fn set_bearer_token(
        &mut self,
        token: &str,
    ) -> Result<(), HttpClientError>;

    pub fn clear_bearer_token(&mut self);
}
```

`set_bearer_token()` は Authorization ヘッダーを設定する。

設定形式は以下とする。

```text
Authorization: Bearer your-token
```

すでに Authorization ヘッダーが存在する場合は、新しいトークンで上書きする。

トークンが不正なヘッダー値の場合は `HttpClientError` を返す。

`clear_bearer_token()` は Authorization ヘッダーを削除する。

### 5.5. 任意の HTTP ヘッダー

以下のメソッドを実装する。

```rust
impl Headers {
    pub fn add(
        &mut self,
        key: &str,
        value: &str,
    ) -> Result<(), HttpClientError>;
}
```

任意の HTTP ヘッダーを追加できるようにする。

使用例：

```rust
let mut headers = Headers::new();

headers.set_bearer_token("your-token")?;

headers.add("X-API-Key", "your-api-key")?;
headers.add("X-Custom-Header", "value")?;
```

同じヘッダー名がすでに存在する場合は上書きする。

ヘッダー名・値が不正な場合は `HttpClientError` を返す。

ヘッダー名は HTTP の大文字・小文字を区別しない仕様に従うこと。

### 5.6. その他

HTTP クライアントから内部のヘッダー情報を利用できるようにする。

利用側に `HeaderMap` の直接操作を要求しないこと。

---

## 6. ClientOptions

### 6.1. 目的

HTTP クライアントの動作を設定する構造体を実装する。

### 6.2. 構造体

```rust
pub struct ClientOptions {
    pub timeout: std::time::Duration,
    pub retry_count: usize,
}
```

### 6.3. デフォルト値

`Default` を実装し、以下の値を設定する。

| 設定 | デフォルト |
|---|---|
| timeout | 30 秒 |
| retry_count | 0 回 |

### 6.4. 各設定の仕様

#### timeout

1 回の HTTP リクエストに対するタイムアウト時間を設定する。

タイムアウトした場合は `HttpClientError::Timeout` を返す。

リトライが発生した場合、各試行に対してタイムアウトを適用する。

#### retry_count

GET リクエストの最大リトライ回数を設定する。

初回リクエストはリトライ回数に含めない。

例えば `retry_count = 3` の場合、最大4回 HTTP リクエストを実行する。

デフォルトは 0 回とし、リトライを行わない。

### 6.5. 設定値の変更

`HttpClient` から `ClientOptions` を変更できるようにする。

タイムアウトが 0 秒の場合は不正な設定として扱い、設定変更時に `HttpClientError` を返すこと。

---

## 7. UrlCreator

### 7.1. 目的

HTTP 通信で使用する URL を組み立てるための構造体を実装する。

ベース URL を設定し、パスとクエリパラメータを追加して完全な URL を生成する。

### 7.2. 基本仕様

以下の機能を提供する。

- ベース URL の設定
- ベース URL の変更
- パスの追加
- クエリパラメータの追加
- 完全な URL の生成

### 7.3. 構造体

```rust
pub struct UrlCreator {
    // URL の組み立てに必要な情報
}
```

### 7.4. メソッド

以下を実装する。

```rust
impl UrlCreator {
    pub fn new(base_url: &str) -> Result<Self, HttpClientError>;

    pub fn set_base_url(
        &mut self,
        base_url: &str,
    ) -> Result<(), HttpClientError>;

    pub fn add_path(
        &mut self,
        path: &str,
    ) -> Result<(), HttpClientError>;

    pub fn add_query_param(
        &mut self,
        key: &str,
        value: &str,
    );

    pub fn build(&self) -> Result<String, HttpClientError>;
}
```

### 7.5. URL の組み立て仕様

例：

```rust
let mut url = UrlCreator::new("https://api.example.com")?;

url.add_path("v1");
url.add_path("users");
url.add_path("123");

url.add_query_param("include", "profile");
url.add_query_param("lang", "ja");

let full_url = url.build()?;
```

生成結果：

```text
https://api.example.com/v1/users/123?include=profile&lang=ja
```

パスの結合時に `/` が重複しないようにする。

クエリパラメータは URL エンコードすること。

特殊文字、日本語、空白などを含む値が正しくエンコードされること。

同じキーのクエリパラメータが複数回追加された場合は、複数のパラメータとして保持すること。

### 7.6. URL の検証

ベース URL は以下を満たす必要がある。

- `http://` または `https://` で始まること。
- URL として正しく解析できること。
- ホスト名が存在すること。

不正な URL の場合は `HttpClientError::Request` を返す。

---

## 8. HttpClient

### 8.1. 目的

非同期 HTTP 通信を行うメインの構造体を実装する。

HTTP クライアントの設定とヘッダーをインスタンス内で保持する。

### 8.2. 構造体

```rust
pub struct HttpClient {
    client: reqwest::Client,
    options: ClientOptions,
    headers: Headers,
}
```

内部の `reqwest::Client` は再利用すること。

リクエストごとに `reqwest::Client` を新規生成しないこと。

### 8.3. コンストラクタ

以下を実装する。

```rust
impl HttpClient {
    pub fn new() -> Self;

    pub fn new_with(
        options: ClientOptions,
        headers: Headers,
    ) -> Result<Self, HttpClientError>;
}
```

`new()` はデフォルト設定で HTTP クライアントを生成する。

`new_with()` は指定された設定とヘッダーを保持する HTTP クライアントを生成する。

### 8.4. 設定変更メソッド

以下を実装する。

```rust
impl HttpClient {
    pub fn set_options(
        &mut self,
        options: ClientOptions,
    ) -> Result<(), HttpClientError>;

    pub fn set_headers(
        &mut self,
        headers: Headers,
    );

    pub fn headers_mut(&mut self) -> &mut Headers;
}
```

`set_options()` で変更した設定は、以後の HTTP リクエストに反映する。

`set_headers()` で変更したヘッダーは、以後の HTTP リクエストに反映する。

`headers_mut()` は内部の Headers を変更するための可変参照を返す。

タイムアウトは各リクエストに対して設定すること。

### 8.5. HTTP 通信の共通仕様

HTTP 通信はすべて非同期処理とする。

HTTP リクエストには以下を適用する。

- インスタンスが保持する HTTP ヘッダー
- インスタンスが保持するタイムアウト
- GET の場合のみリトライ設定

HTTP ステータスコードが 200 番台以外の場合は、すべて `HttpClientError::HttpStatus` とする。

200 番台の場合は成功として扱う。

HTTP リダイレクトについては reqwest のデフォルト動作を使用する。

---

## 9. HTTP メソッド

### 9.1. 共通仕様

以下の4種類を実装する。

- GET
- POST
- PUT
- DELETE

すべてのメソッドは完全な URL を引数として受け取る。

`UrlCreator` は HTTP クライアント内部では使用せず、利用側で URL を生成する。

レスポンスボディは `serde::de::DeserializeOwned` を使用して任意の構造体に変換する。

通常のレスポンス取得メソッドの戻り値は以下に統一する。

```rust
Result<T, HttpClientError>
```

レスポンスボディを取得しないメソッドの戻り値は以下とする。

```rust
Result<(), HttpClientError>
```

### 9.2. GET

```rust
pub async fn get<T>(
    &self,
    url: &str,
) -> Result<T, HttpClientError>
where
    T: serde::de::DeserializeOwned;
```

仕様：

1. GET リクエストを送信する。
2. インスタンスが保持するヘッダーを付与する。
3. タイムアウトを適用する。
4. 必要に応じてリトライする。
5. HTTP ステータスコードを確認する。
6. 200 番台の場合はレスポンスボディを JSON として解析する。
7. JSON を `T` に変換する。
8. エラーの場合は `HttpClientError` を返す。

### 9.3. POST

```rust
pub async fn post<B, T>(
    &self,
    url: &str,
    body: &B,
) -> Result<T, HttpClientError>
where
    B: serde::Serialize + ?Sized,
    T: serde::de::DeserializeOwned;
```

仕様：

1. POST リクエストを送信する。
2. `body` を JSON に変換して送信する。
3. インスタンスが保持するヘッダーを付与する。
4. タイムアウトを適用する。
5. HTTP ステータスコードを確認する。
6. 200 番台の場合はレスポンスボディを JSON として解析する。
7. JSON を `T` に変換する。
8. エラーの場合は `HttpClientError` を返す。

POST はリトライしないこと。

### 9.4. PUT

```rust
pub async fn put<B, T>(
    &self,
    url: &str,
    body: &B,
) -> Result<T, HttpClientError>
where
    B: serde::Serialize + ?Sized,
    T: serde::de::DeserializeOwned;
```

仕様：

1. PUT リクエストを送信する。
2. `body` を JSON に変換して送信する。
3. インスタンスが保持するヘッダーを付与する。
4. タイムアウトを適用する。
5. HTTP ステータスコードを確認する。
6. 200 番台の場合はレスポンスボディを JSON として解析する。
7. JSON を `T` に変換する。
8. エラーの場合は `HttpClientError` を返す。

PUT はリトライしないこと。

### 9.5. DELETE

```rust
pub async fn delete<T>(
    &self,
    url: &str,
) -> Result<T, HttpClientError>
where
    T: serde::de::DeserializeOwned;
```

仕様：

1. DELETE リクエストを送信する。
2. リクエストボディは付与しない。
3. インスタンスが保持するヘッダーを付与する。
4. タイムアウトを適用する。
5. HTTP ステータスコードを確認する。
6. 200 番台の場合はレスポンスボディを JSON として解析する。
7. JSON を `T` に変換する。
8. エラーの場合は `HttpClientError` を返す。

DELETE はリトライしないこと。

---

## 10. レスポンスボディを取得しない HTTP メソッド

### 10.1. 目的

HTTP 204 No Content など、レスポンスボディが存在しない API に対応する。

通常の HTTP メソッドとは別に、レスポンスボディを JSON 変換しないメソッドを用意する。

これらのメソッドはレスポンスボディを必要としない。

### 10.2. 提供メソッド

以下の4種類を実装する。

```rust
pub async fn get_empty(
    &self,
    url: &str,
) -> Result<(), HttpClientError>;

pub async fn post_empty<B>(
    &self,
    url: &str,
    body: &B,
) -> Result<(), HttpClientError>
where
    B: serde::Serialize + ?Sized;

pub async fn put_empty<B>(
    &self,
    url: &str,
    body: &B,
) -> Result<(), HttpClientError>
where
    B: serde::Serialize + ?Sized;

pub async fn delete_empty(
    &self,
    url: &str,
) -> Result<(), HttpClientError>;
```

### 10.3. 各メソッドの仕様

| メソッド | HTTP メソッド | リクエストボディ | レスポンス JSON 変換 |
|---|---|---|---|
| get_empty | GET | なし | なし |
| post_empty | POST | JSON | なし |
| put_empty | PUT | JSON | なし |
| delete_empty | DELETE | なし | なし |

共通仕様：

1. HTTP リクエストを送信する。
2. HTTP ステータスコードを確認する。
3. 200 番台の場合は `Ok(())` を返す。
4. 200 番台以外の場合は `HttpClientError::HttpStatus` を返す。
5. レスポンスボディの JSON 変換を行わない。
6. レスポンスボディが存在しなくてもエラーにしない。

`get_empty()` は GET のリトライ仕様を適用する。

POST / PUT / DELETE の各メソッドはリトライしない。

### 10.4. 使用例

```rust
client.delete_empty(
    "https://api.example.com/v1/users/123"
).await?;
```

上記のように、レスポンスボディを必要としない API を簡単に利用できるようにする。

---

## 11. リトライ仕様

### 11.1. 基本方針

リトライは GET リクエストのみを対象とする。

POST / PUT / DELETE は絶対にリトライしないこと。

`retry_count` は初回リクエストを含まない追加リトライ回数とする。

### 11.2. リトライ対象

| エラー | リトライ |
|---|---|
| 接続エラー | 対象 |
| タイムアウト | 対象 |
| HTTP 429 | 対象 |
| HTTP 5xx | 対象外 |
| HTTP 4xx | 対象外 |
| JSON 変換エラー | 対象外 |
| その他のリクエストエラー | 対象外 |

### 11.3. リトライ処理

以下の順序で処理する。

1. HTTP リクエストを実行する。
2. 成功した場合はレスポンスを返す。
3. エラーの場合、リトライ対象か確認する。
4. リトライ対象外の場合はエラーを返す。
5. リトライ回数が上限に達している場合はエラーを返す。
6. リトライ可能な場合は待機する。
7. 再度 HTTP リクエストを実行する。

待機時間は指数バックオフとする。

- 1回目のリトライ：100ms
- 2回目のリトライ：200ms
- 3回目のリトライ：400ms
- 以降は2倍ずつ増加
- 最大待機時間は2秒

待機には `tokio::time::sleep()` を使用する。

HTTP 429 のレスポンスもリトライ対象とする。

最終的にリトライ上限に達した場合は、最後に発生したエラーを返すこと。

### 11.4. リトライ回数の具体例

`retry_count = 2` の場合：

```text
初回リクエスト
    |
    +-- 成功 --> 終了
    |
    +-- 接続エラー
            |
            +-- 1回目リトライ
                    |
                    +-- 成功 --> 終了
                    |
                    +-- HTTP 429
                            |
                            +-- 2回目リトライ
                                    |
                                    +-- 成功 --> 終了
                                    |
                                    +-- エラー --> 最終エラーを返す
```

最大3回 HTTP リクエストを実行する。

---

## 12. HTTP ステータスコードの処理

### 12.1. 成功判定

HTTP ステータスコードが 200 番台の場合のみ成功とする。

それ以外はすべて `HttpClientError::HttpStatus` とする。

### 12.2. エラー処理

HTTP エラーの場合は以下を保持する。

- HTTP ステータスコード
- レスポンスボディ
- RFC 9457 の Problem Details（取得できた場合）

### 12.3. 注意事項

HTTP エラーのレスポンスボディを破棄してはならない。

JSON 形式でないエラーレスポンスであっても、文字列として保持すること。

Problem Details の解析に失敗しても、HTTP エラーとして正常に返すこと。

---

## 13. JSON 処理

### 13.1. リクエスト

POST / PUT では `serde::Serialize` を利用して JSON に変換する。

シリアライズに失敗した場合は `HttpClientError::JsonParse` を返す。

### 13.2. レスポンス

GET / POST / PUT / DELETE の通常メソッドでは `serde::de::DeserializeOwned` を利用する。

JSON のデシリアライズに失敗した場合は `HttpClientError::JsonParse` を返す。

### 13.3. 空のレスポンス

通常メソッドではレスポンスボディを JSON として解析する。

レスポンスボディが空の場合、JSON 変換エラーとする。

レスポンスボディが空でも正常終了させたい場合は、必ず `_empty` メソッドを使用する。

---

## 14. 非同期処理

HTTP 通信はすべて Tokio による非同期処理とする。

以下を守ること。

- HTTP 通信に同期 API を使用しない。
- リトライの待機には `tokio::time::sleep()` を使用する。
- 不要な `spawn_blocking()` を使用しない。
- HTTP 通信の完了を待つために同期的なブロッキング処理を行わない。
- `reqwest::Client` をインスタンス内で再利用する。

---

## 15. ユニットテスト

実装後、各機能に対してユニットテストを作成すること。

外部の実際の API サーバーに依存しないテストを基本とする。

ローカル HTTP モックサーバーなどを利用し、HTTP のレスポンスを制御できるようにする。

### 15.1. HttpClientError

以下をテストする。

- HTTP 401 の場合 `is_auth_err()` が true
- HTTP 403 の場合 `is_auth_err()` が true
- HTTP 200 の場合 `is_auth_err()` が false
- Connection の場合 `is_connection_err()` が true
- JsonParse の場合 `is_json_parse_err()` が true
- Timeout の場合 `is_timeout()` が true
- HTTP 429 の場合 `is_rate_limit_err()` が true
- `status_code()` が正しい値を返す
- `response_body()` が正しい値を返す
- `problem_details()` が正しい値を返す
- `to_err_msg()` がエラー種別に応じた文字列を返す

### 15.2. ProblemDetails

以下をテストする。

- RFC 9457 の JSON を正しく解析できる。
- 各フィールドを正しく取得できる。
- 省略されたフィールドが None になる。
- 不正な JSON の場合に解析に失敗する。
- 解析に失敗しても元のレスポンスボディを保持できる。

### 15.3. Headers

以下をテストする。

- デフォルトヘッダーが設定される。
- Bearer Token を設定できる。
- Bearer Token を変更できる。
- Authorization ヘッダーを削除できる。
- 任意の HTTP ヘッダーを追加できる。
- 同じヘッダーを追加した場合に上書きされる。
- 不正なヘッダー値を指定した場合にエラーになる。

### 15.4. ClientOptions

以下をテストする。

- デフォルトタイムアウトが30秒である。
- デフォルトリトライ回数が0回である。
- オプションを変更できる。
- 0秒のタイムアウトを拒否する。

### 15.5. UrlCreator

以下をテストする。

- ベース URL を設定できる。
- ベース URL を変更できる。
- パスを追加できる。
- 複数のパスを追加できる。
- `/` が重複しない。
- クエリパラメータを追加できる。
- 複数のクエリパラメータを追加できる。
- 同じキーを複数回追加できる。
- 日本語を正しく URL エンコードできる。
- 空白や特殊文字を正しく URL エンコードできる。
- 不正な URL の場合にエラーになる。

### 15.6. HttpClient

以下をテストする。

| テスト項目 | 期待結果 |
|---|---|
| GET 200 | JSON を構造体に変換できる |
| GET 204 | 通常メソッドでは JSON 変換エラー |
| GET Empty 204 | 正常終了 |
| GET 400 | HttpStatus |
| GET 401 | HttpStatus |
| GET 500 | HttpStatus |
| GET Problem Details | ProblemDetails を取得できる |
| POST 200 | JSON を送信しレスポンスを変換できる |
| POST Empty 204 | 正常終了 |
| PUT 200 | JSON を送信しレスポンスを変換できる |
| PUT Empty 204 | 正常終了 |
| DELETE 200 | JSON レスポンスを取得できる |
| DELETE Empty 204 | 正常終了 |
| DELETE 204 | 通常メソッドでは JSON 変換エラー |
| 接続エラー | Connection |
| タイムアウト | Timeout |
| 不正な JSON | JsonParse |
| Authorization | 正しい Bearer Token が送信される |
| 任意ヘッダー | 正しいヘッダーが送信される |

### 15.7. リトライ

リトライについては以下をテストする。

- retry_count が0の場合、リトライしない。
- 接続エラーの場合、リトライする。
- タイムアウトの場合、リトライする。
- HTTP 429 の場合、リトライする。
- HTTP 500 の場合、リトライしない。
- HTTP 400 の場合、リトライしない。
- JSON 変換エラーの場合、リトライしない。
- リトライ上限を超えて実行しない。
- 最後に発生したエラーを返す。
- POST はリトライしない。
- PUT はリトライしない。
- DELETE はリトライしない。
- GET Empty にもリトライ仕様が適用される。

テストでは実際の HTTP リクエスト回数を確認すること。

---

## 16. 完了条件

以下をすべて満たした場合に実装完了とする。

### 実装

- [ ] reqwest を使用している。
- [ ] Tokio による非同期 HTTP 通信を実装している。
- [ ] HttpClientError を実装している。
- [ ] RFC 9457 に対応している。
- [ ] Headers を実装している。
- [ ] Bearer Token に対応している。
- [ ] 任意の HTTP ヘッダーに対応している。
- [ ] ClientOptions を実装している。
- [ ] UrlCreator を実装している。
- [ ] GET を実装している。
- [ ] POST を実装している。
- [ ] PUT を実装している。
- [ ] DELETE を実装している。
- [ ] get_empty を実装している。
- [ ] post_empty を実装している。
- [ ] put_empty を実装している。
- [ ] delete_empty を実装している。
- [ ] GET のリトライを実装している。
- [ ] タイムアウトに対応している。
- [ ] HTTP ステータスコードを適切に処理している。

### 品質

- [ ] `cargo fmt` が成功する。
- [ ] `cargo check` が成功する。
- [ ] `cargo test` が成功する。
- [ ] `cargo clippy` で警告がないことを確認する。
- [ ] 公開 API に docstring がある。
- [ ] `src/README.md` が作成されている。
- [ ] README.md のサンプルコードがコンパイル可能である。

---

## 17. Codex への実装指示

以下の手順で作業すること。

1. 既存のモノレポ構成を確認する。
2. 既存の Cargo workspace 設定を確認する。
3. 既存のコーディング規約を確認する。
4. 必要な依存クレートとライセンスを確認する。
5. 本仕様書に従ってディレクトリ・ファイルを作成する。
6. 各構造体とメソッドを実装する。
7. ユニットテストを作成する。
8. README.md を作成する。
9. `cargo fmt` を実行する。
10. `cargo check` を実行する。
11. `cargo test` を実行する。
12. `cargo clippy` を実行する。
13. エラーや警告があれば修正する。
14. 最終的な実装内容とテスト結果を報告する。

既存の Cargo.toml や workspace 設定が存在する場合は、既存設定を不用意に上書きしないこと。

既存コードや他のクレートに影響を与えないようにすること。

仕様に記載されていない事項で実装判断が必要になった場合は、既存コードとの整合性を優先すること。

仕様の解釈に重大な曖昧さがある場合は、独自判断で実装を進めず、ユーザーに確認すること。

**最終的には、他の Rust プロジェクトから依存クレートとして利用できる、テスト済みの非同期 HTTP クライアントライブラリを完成させること。**