# Codex Implementation Specification
# 非同期 HTTP クライアント（Golang）

## 1. 目的

Go を使用して、汎用的な HTTP クライアントパッケージを実装する。

HTTP 通信には Go 標準ライブラリの `net/http` を使用し、以下の機能を提供する。

- GET / POST / PUT / DELETE による HTTP 通信
- JSON リクエストボディの送信
- JSON レスポンスボディの任意の構造体への変換
- レスポンスボディを必要としない HTTP 通信
- HTTP ステータスコードに応じたエラー処理
- RFC 9457（Problem Details for HTTP APIs）への対応
- Bearer Token による認証
- 任意の HTTP ヘッダーの追加
- タイムアウト設定
- GET リクエストに対するリトライ
- URL の組み立てとクエリパラメータの追加
- context.Context によるキャンセル制御

本パッケージは、他の Go プロジェクトから再利用できる汎用 HTTP クライアントとして実装する。

Go の標準的なパッケージ設計・命名規則・エラー処理に従うこと。

Rust など他言語の実装方法をそのまま持ち込まず、Go で自然かつ保守しやすい設計にすること。

本仕様書に記載された API、引数、戻り値、処理内容、エラー処理、テスト条件を厳守すること。

仕様にない独自機能を追加したり、既存の仕様を独自判断で変更したりしないこと。

---

## 2. 全体共通仕様

### 2.1. 使用技術

| 項目 | 使用技術 |
|---|---|
| 言語 | Go |
| HTTP クライアント | net/http |
| JSON シリアライズ | encoding/json |
| JSON デシリアライズ | encoding/json |
| URL 操作 | net/url |
| コンテキスト管理 | context |
| エラー管理 | errors |

可能な限り Go 標準ライブラリを使用すること。

外部クレートや外部ライブラリに相当する追加依存パッケージは、原則として使用しないこと。

### 2.2. 実装場所

モノレポ構成の以下の場所に実装する。

Go ではパッケージをディレクトリ単位で管理するため、専用の Go モジュールとして実装する。

```text
pjt/
└── creates/
    └── create-name/
        ├── go.mod
        ├── README.md
        ├── client.go
        ├── client_options.go
        ├── headers.go
        ├── url_creator.go
        ├── errors.go
        ├── problem_details.go
        └── ...
```

Go では通常、モジュールルートにパッケージのソースファイルを配置する。

既存のモノレポに Go workspace や共通の go.mod 管理ルールが存在する場合は、それに従うこと。

パッケージ名は `httpclient` とする。

### 2.3. ファイル構成

| ファイル | 責務 |
|---|---|
| client.go | HTTP クライアント本体と HTTP 通信 |
| client_options.go | HTTP クライアントのオプション |
| headers.go | HTTP ヘッダーの管理 |
| url_creator.go | URL の組み立て |
| errors.go | HTTP 通信エラーの定義 |
| problem_details.go | RFC 9457 のデータ構造 |

必要に応じてファイルを追加してもよい。

すべての処理を `client.go` に記述しないこと。

### 2.4. コーディング方針

- Go の標準的な命名規則に従う。
- 公開する構造体、関数、メソッドには GoDoc コメントを記述する。
- コメントアウトによる説明は極力使用しない。
- 関数や構造体は適切な単位で分割する。
- 不要な外部依存を追加しない。
- エラーを握りつぶさない。
- `panic` を通常のエラー処理に使用しない。
- HTTP 通信には `net/http` を使用する。
- JSON 処理には `encoding/json` を使用する。
- タイムアウトとキャンセルには `context.Context` を使用する。
- エラーは独自の `HttpClientError` 型に統一する。
- HTTP クライアントは複数の goroutine から安全に利用できる設計にする。

---

## 3. HttpClientError

### 3.1. 目的

HTTP 通信に関するエラーを一元管理するため、`HttpClientError` を定義する。

HTTP ステータスコードのエラーだけではなく、通信エラー、タイムアウト、JSON 変換エラーなども管理する。

Go ではエラー型を構造体として定義し、`error` インターフェースを実装する。

### 3.2. エラー種別

以下のエラー種別を定義する。

```go
type ErrorKind string

const (
    ErrorKindHTTPStatus ErrorKind = "http_status"
    ErrorKindConnection ErrorKind = "connection"
    ErrorKindTimeout    ErrorKind = "timeout"
    ErrorKindJSON       ErrorKind = "json"
    ErrorKindRequest    ErrorKind = "request"
)
```

### 3.3. HttpClientError 構造体

```go
type HttpClientError struct {
    Kind       ErrorKind
    StatusCode int
    Body       string
    Problem    *ProblemDetails
    Err        error
}
```

各フィールドの意味は以下とする。

| フィールド | 説明 |
|---|---|
| Kind | エラー種別 |
| StatusCode | HTTP ステータスコード |
| Body | HTTP レスポンスボディ |
| Problem | RFC 9457 の Problem Details |
| Err | 元のエラー |

`StatusCode` は HTTP ステータスエラー以外では 0 とする。

`Body` は HTTP ステータスエラー以外では空文字列とする。

`Problem` は Problem Details を取得できた場合のみ設定する。

`Err` は原因となった元のエラーを保持する。

### 3.4. error インターフェース

以下のメソッドを実装する。

```go
func (e *HttpClientError) Error() string

func (e *HttpClientError) Unwrap() error
```

`Error()` はエラー内容を文字列として返す。

`Unwrap()` は元のエラー `Err` を返す。

`Err` が nil の場合は nil を返す。

### 3.5. エラー判定メソッド

以下を実装する。

```go
func (e *HttpClientError) IsAuthErr() bool

func (e *HttpClientError) IsConnectionErr() bool

func (e *HttpClientError) IsJSONParseErr() bool

func (e *HttpClientError) IsTimeout() bool

func (e *HttpClientError) IsRateLimitErr() bool

func (e *HttpClientError) StatusCodeValue() int

func (e *HttpClientError) ResponseBody() string

func (e *HttpClientError) ProblemDetails() *ProblemDetails

func (e *HttpClientError) ToErrMsg() string
```

各メソッドの仕様は以下とする。

#### IsAuthErr

HTTP 認証・認可エラーを判定する。

- HTTP 401：true
- HTTP 403：true
- その他：false

#### IsConnectionErr

`ErrorKindConnection` の場合のみ true を返す。

#### IsJSONParseErr

`ErrorKindJSON` の場合のみ true を返す。

JSON のシリアライズ・デシリアライズの両方を対象とする。

#### IsTimeout

`ErrorKindTimeout` の場合のみ true を返す。

#### IsRateLimitErr

HTTP 429 の場合のみ true を返す。

#### StatusCodeValue

HTTP ステータスエラーの場合はステータスコードを返す。

それ以外は 0 を返す。

#### ResponseBody

HTTP ステータスエラーの場合はレスポンスボディを返す。

それ以外は空文字列を返す。

#### ProblemDetails

Problem Details が格納されている場合は、そのポインタを返す。

それ以外は nil を返す。

#### ToErrMsg

エラー内容を簡潔な文字列で取得する。

以下のメッセージを基本とする。

| エラー | メッセージ例 |
|---|---|
| Connection | Cannot connect to server. |
| Timeout | Request timed out. |
| JSON | Failed to parse JSON response. |
| Request | Invalid HTTP request. |
| HTTP 401 | HTTP authentication failed. |
| HTTP 403 | HTTP authorization failed. |
| HTTP 429 | Too many requests. |
| その他 HTTP エラー | HTTP request failed. |

詳細情報は `StatusCodeValue()` や `ResponseBody()` で取得できるようにする。

### 3.6. エラーの分類

HTTP リクエスト実行時に発生したエラーを適切に分類すること。

| 発生原因 | ErrorKind |
|---|---|
| 接続エラー | ErrorKindConnection |
| タイムアウト | ErrorKindTimeout |
| JSON シリアライズエラー | ErrorKindJSON |
| JSON デシリアライズエラー | ErrorKindJSON |
| URL 構築エラー | ErrorKindRequest |
| ヘッダー設定エラー | ErrorKindRequest |
| HTTP 200 番台以外 | ErrorKindHTTPStatus |

タイムアウト判定には `context.DeadlineExceeded` や `net.Error` の `Timeout()` を利用する。

接続エラーの判定には `errors.As` などを利用し、元のエラー情報を保持すること。

利用者がリクエストのキャンセルを行った場合は、通常の接続エラーと区別し、元の context エラーを保持すること。

---

## 4. RFC 9457（Problem Details）

### 4.1. 目的

HTTP API のエラーレスポンスとして RFC 9457 に対応する。

HTTP ステータスコードだけではなく、サーバーが返したエラーの詳細情報を取得できるようにする。

### 4.2. ProblemDetails 構造体

```go
type ProblemDetails struct {
    Type     string `json:"type,omitempty"`
    Title    string `json:"title,omitempty"`
    Status   int    `json:"status,omitempty"`
    Detail   string `json:"detail,omitempty"`
    Instance string `json:"instance,omitempty"`
}
```

各フィールドの意味は以下とする。

| フィールド | 説明 |
|---|---|
| Type | 問題の種類を示す URI |
| Title | 問題の概要 |
| Status | HTTP ステータスコード |
| Detail | 問題の詳細 |
| Instance | 問題が発生した個別の URI |

RFC 9457 で定義されている各フィールドを取得できるようにする。

### 4.3. Problem Details の取得

HTTP ステータスコードが 200 番台以外の場合、レスポンスボディを取得する。

レスポンスの Content-Type が `application/problem+json` の場合、ProblemDetails への変換を試みる。

Content-Type の判定では MIME タイプを解析し、文字コードなどのパラメータが付加されていても判定できるようにする。

変換に成功した場合は `HttpClientError` の `Problem` に格納する。

変換に失敗した場合は nil とする。

どちらの場合でも元のレスポンスボディは `Body` に保持すること。

Problem Details の解析に失敗したことを理由に、元の HTTP エラーを別のエラーに置き換えてはならない。

RFC 9457 の拡張メンバーは、基本的に無視してよい。

---

## 5. Headers

### 5.1. 目的

HTTP リクエストに使用するヘッダーを管理する構造体を実装する。

デフォルトで一般的な JSON API に適したヘッダーを設定する。

### 5.2. 構造体

```go
type Headers struct {
    values http.Header
}
```

内部実装には `net/http` の `http.Header` を使用する。

### 5.3. コンストラクタ

```go
func NewHeaders() *Headers
```

`NewHeaders()` で以下を設定する。

| ヘッダー | デフォルト値 |
|---|---|
| Accept | application/json |
| Content-Type | application/json |

### 5.4. Bearer Token

以下を実装する。

```go
func (h *Headers) SetBearerToken(token string) error

func (h *Headers) ClearBearerToken()
```

`SetBearerToken()` は Authorization ヘッダーを設定する。

設定形式：

```text
Authorization: Bearer your-token
```

すでに Authorization ヘッダーが存在する場合は新しいトークンで上書きする。

トークンが不正なヘッダー値の場合は `HttpClientError` を返す。

`ClearBearerToken()` は Authorization ヘッダーを削除する。

### 5.5. 任意の HTTP ヘッダー

以下を実装する。

```go
func (h *Headers) Add(key string, value string) error
```

任意の HTTP ヘッダーを追加できるようにする。

使用例：

```go
headers := httpclient.NewHeaders()

if err := headers.SetBearerToken("your-token"); err != nil {
    return err
}

if err := headers.Add("X-API-Key", "your-api-key"); err != nil {
    return err
}

if err := headers.Add("X-Custom-Header", "value"); err != nil {
    return err
}
```

同じヘッダー名がすでに存在する場合は上書きする。

ヘッダー名・値が不正な場合は `HttpClientError` を返す。

内部処理には `http.Header.Set()` を使用する。

### 5.6. ヘッダーの管理

HTTP クライアントから内部のヘッダー情報を利用できるようにする。

HTTP リクエストを作成する際は、内部の `http.Header` を直接リクエストに渡さず、コピーしたヘッダーを設定すること。

これにより、リクエストごとにヘッダーが変更されることを防ぐ。

`Headers` の操作自体も、必要に応じて `sync.RWMutex` で保護すること。

---

## 6. ClientOptions

### 6.1. 目的

HTTP クライアントの動作を設定する構造体を実装する。

### 6.2. 構造体

```go
type ClientOptions struct {
    Timeout    time.Duration
    RetryCount int
}
```

### 6.3. デフォルト値

以下の関数を実装する。

```go
func DefaultClientOptions() ClientOptions
```

デフォルト値：

| 設定 | デフォルト |
|---|---|
| Timeout | 30秒 |
| RetryCount | 0回 |

### 6.4. 各設定の仕様

#### Timeout

1 回の HTTP リクエストに対するタイムアウト時間を設定する。

タイムアウトした場合は `ErrorKindTimeout` を返す。

リトライが発生した場合、各試行に対してタイムアウトを適用する。

#### RetryCount

GET リクエストの最大リトライ回数を設定する。

初回リクエストはリトライ回数に含めない。

例えば `RetryCount = 3` の場合、最大4回 HTTP リクエストを実行する。

デフォルトは 0 回とする。

### 6.5. 設定値の検証

以下のルールを適用する。

- Timeout は 0 より大きい値とする。
- RetryCount は 0 以上とする。
- 不正な値の場合は `HttpClientError` を返す。

---

## 7. UrlCreator

### 7.1. 目的

HTTP 通信で使用する URL を組み立てるための構造体を実装する。

ベース URL を設定し、パスとクエリパラメータを追加して完全な URL を生成する。

### 7.2. 構造体

```go
type UrlCreator struct {
    baseURL string
    paths   []string
    queries url.Values
}
```

### 7.3. コンストラクタ

```go
func NewUrlCreator(baseURL string) (*UrlCreator, error)
```

ベース URL を設定してインスタンスを生成する。

不正な URL の場合は `HttpClientError` を返す。

### 7.4. メソッド

以下を実装する。

```go
func (u *UrlCreator) SetBaseURL(baseURL string) error

func (u *UrlCreator) AddPath(path string)

func (u *UrlCreator) AddQueryParam(key string, value string)

func (u *UrlCreator) Build() (string, error)
```

### 7.5. URL の組み立て仕様

使用例：

```go
urlCreator, err := httpclient.NewUrlCreator(
    "https://api.example.com",
)
if err != nil {
    return err
}

urlCreator.AddPath("v1")
urlCreator.AddPath("users")
urlCreator.AddPath("123")

urlCreator.AddQueryParam("include", "profile")
urlCreator.AddQueryParam("lang", "ja")

fullURL, err := urlCreator.Build()
if err != nil {
    return err
}
```

生成結果：

```text
https://api.example.com/v1/users/123?include=profile&lang=ja
```

仕様：

- パスの結合時に `/` が重複しないようにする。
- クエリパラメータは URL エンコードする。
- 日本語、空白、特殊文字を正しくエンコードする。
- 同じキーのクエリパラメータが複数回追加された場合は複数の値として保持する。
- パスの順序は追加された順序を維持する。
- クエリパラメータは `url.Values` を利用して管理する。

### 7.6. URL の検証

ベース URL は以下を満たす必要がある。

- `http://` または `https://` であること。
- URL として正しく解析できること。
- ホスト名が存在すること。

不正な URL の場合は `HttpClientError` を返す。

---

## 8. HttpClient

### 8.1. 目的

非同期 HTTP 通信を行うメインの構造体を実装する。

HTTP クライアントの設定とヘッダーをインスタンス内で保持する。

Go では HTTP 通信に `net/http` を使用する。

### 8.2. 構造体

```go
type HttpClient struct {
    client  *http.Client
    options ClientOptions
    headers *Headers

    mu sync.RWMutex
}
```

内部の `http.Client` は再利用すること。

リクエストごとに `http.Client` を新規生成しないこと。

`http.Client` は複数の goroutine から安全に利用できるようにする。

設定値とヘッダーの変更・参照には適切な排他制御を行う。

### 8.3. コンストラクタ

以下を実装する。

```go
func New() *HttpClient

func NewWith(
    options ClientOptions,
    headers *Headers,
) (*HttpClient, error)
```

`New()` はデフォルト設定で HTTP クライアントを生成する。

`NewWith()` は指定された設定とヘッダーを保持する HTTP クライアントを生成する。

`headers` が nil の場合はデフォルトの Headers を生成する。

不正なオプションの場合は `HttpClientError` を返す。

### 8.4. 設定変更メソッド

以下を実装する。

```go
func (c *HttpClient) SetOptions(
    options ClientOptions,
) error

func (c *HttpClient) SetHeaders(
    headers *Headers,
) error

func (c *HttpClient) Headers() *Headers
```

`SetOptions()` で変更した設定は、以後の HTTP リクエストに反映する。

`SetHeaders()` で変更したヘッダーは、以後の HTTP リクエストに反映する。

`Headers()` はヘッダーを変更するための参照を返す。

nil の Headers は設定できない。

設定変更と HTTP リクエストが同時に実行されても、データ競合が発生しないようにする。

### 8.5. context.Context

すべての HTTP 通信メソッドの第一引数には `context.Context` を指定する。

例：

```go
func (c *HttpClient) Get(
    ctx context.Context,
    url string,
    out any,
) error
```

context.Context は以下の目的で使用する。

- リクエストのキャンセル
- タイムアウト制御
- リクエストの処理中断
- リトライ待機中のキャンセル

利用者がキャンセルしたリクエストは、リトライせずに終了する。

### 8.6. タイムアウト制御

HTTP リクエストごとに `context.WithTimeout()` を使用してタイムアウトを設定する。

タイムアウト時間は `ClientOptions.Timeout` を使用する。

リトライ時は各リクエストに対してタイムアウトを設定する。

元の context がキャンセルされた場合は、そのキャンセルを優先する。

HTTP クライアント全体のタイムアウト設定に依存せず、リクエスト単位でタイムアウトを管理すること。

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

Go ではメソッドに独自の型パラメータを宣言できないため、レスポンスの変換先は `out any` で受け取る。

JSON の変換先には、必ずポインタを渡すこと。

通常のレスポンス取得メソッドの戻り値は `error` とする。

レスポンスボディを取得しないメソッドも `error` を返す。

### 9.2. GET

```go
func (c *HttpClient) Get(
    ctx context.Context,
    url string,
    out any,
) error
```

仕様：

1. GET リクエストを送信する。
2. インスタンスが保持するヘッダーを付与する。
3. タイムアウトを適用する。
4. 必要に応じてリトライする。
5. HTTP ステータスコードを確認する。
6. 200 番台の場合はレスポンスボディを JSON として解析する。
7. JSON を `out` が指す構造体に変換する。
8. エラーの場合は `HttpClientError` を返す。

`out` は nil ではないポインタでなければならない。

不正な `out` が渡された場合は `HttpClientError` を返す。

### 9.3. POST

```go
func (c *HttpClient) Post(
    ctx context.Context,
    url string,
    requestBody any,
    responseBody any,
) error
```

仕様：

1. POST リクエストを送信する。
2. `requestBody` を JSON に変換して送信する。
3. インスタンスが保持するヘッダーを付与する。
4. タイムアウトを適用する。
5. HTTP ステータスコードを確認する。
6. 200 番台の場合はレスポンスボディを JSON として解析する。
7. JSON を `responseBody` が指す構造体に変換する。
8. エラーの場合は `HttpClientError` を返す。

POST はリトライしないこと。

`requestBody` は JSON に変換可能な値とする。

`responseBody` は nil ではないポインタとする。

### 9.4. PUT

```go
func (c *HttpClient) Put(
    ctx context.Context,
    url string,
    requestBody any,
    responseBody any,
) error
```

仕様：

1. PUT リクエストを送信する。
2. `requestBody` を JSON に変換して送信する。
3. インスタンスが保持するヘッダーを付与する。
4. タイムアウトを適用する。
5. HTTP ステータスコードを確認する。
6. 200 番台の場合はレスポンスボディを JSON として解析する。
7. JSON を `responseBody` が指す構造体に変換する。
8. エラーの場合は `HttpClientError` を返す。

PUT はリトライしないこと。

### 9.5. DELETE

```go
func (c *HttpClient) Delete(
    ctx context.Context,
    url string,
    out any,
) error
```

仕様：

1. DELETE リクエストを送信する。
2. リクエストボディは付与しない。
3. インスタンスが保持するヘッダーを付与する。
4. タイムアウトを適用する。
5. HTTP ステータスコードを確認する。
6. 200 番台の場合はレスポンスボディを JSON として解析する。
7. JSON を `out` が指す構造体に変換する。
8. エラーの場合は `HttpClientError` を返す。

DELETE はリトライしないこと。

---

## 10. レスポンスボディを取得しない HTTP メソッド

### 10.1. 目的

HTTP 204 No Content など、レスポンスボディが存在しない API に対応する。

通常の HTTP メソッドとは別に、レスポンスボディを JSON 変換しないメソッドを用意する。

### 10.2. 提供メソッド

以下の4種類を実装する。

```go
func (c *HttpClient) GetEmpty(
    ctx context.Context,
    url string,
) error

func (c *HttpClient) PostEmpty(
    ctx context.Context,
    url string,
    requestBody any,
) error

func (c *HttpClient) PutEmpty(
    ctx context.Context,
    url string,
    requestBody any,
) error

func (c *HttpClient) DeleteEmpty(
    ctx context.Context,
    url string,
) error
```

### 10.3. 各メソッドの仕様

| メソッド | HTTP メソッド | リクエストボディ | レスポンス JSON 変換 |
|---|---|---|---|
| GetEmpty | GET | なし | なし |
| PostEmpty | POST | JSON | なし |
| PutEmpty | PUT | JSON | なし |
| DeleteEmpty | DELETE | なし | なし |

共通仕様：

1. HTTP リクエストを送信する。
2. HTTP ステータスコードを確認する。
3. 200 番台の場合は nil を返す。
4. 200 番台以外の場合は `HttpClientError` を返す。
5. レスポンスボディの JSON 変換を行わない。
6. レスポンスボディが存在しなくてもエラーにしない。
7. HTTP レスポンスボディは必ず読み取り・クローズすること。

`GetEmpty()` は GET のリトライ仕様を適用する。

POST / PUT / DELETE の各メソッドはリトライしない。

### 10.4. 使用例

```go
err := client.DeleteEmpty(
    ctx,
    "https://api.example.com/v1/users/123",
)

if err != nil {
    return err
}
```

レスポンスボディを必要としない API を簡単に利用できるようにする。

---

## 11. リトライ仕様

### 11.1. 基本方針

リトライは GET リクエストのみを対象とする。

POST / PUT / DELETE は絶対にリトライしないこと。

`RetryCount` は初回リクエストを含まない追加リトライ回数とする。

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
| context のキャンセル | 対象外 |

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

| リトライ回数 | 待機時間 |
|---|---|
| 1回目 | 100ms |
| 2回目 | 200ms |
| 3回目 | 400ms |
| 4回目 | 800ms |
| 5回目 | 1600ms |
| 6回目以降 | 最大2000ms |

待機には `time.NewTimer()` などを使用する。

待機中に context がキャンセルされた場合は、待機を中断して処理を終了すること。

HTTP 429 のレスポンスもリトライ対象とする。

最終的にリトライ上限に達した場合は、最後に発生したエラーを返すこと。

### 11.4. リトライ回数の具体例

`RetryCount = 2` の場合：

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

### 11.5. リトライ対象メソッド

以下のメソッドにリトライを適用する。

- Get
- GetEmpty

それ以外のメソッドには適用しない。

---

## 12. HTTP ステータスコードの処理

### 12.1. 成功判定

HTTP ステータスコードが 200 番台の場合のみ成功とする。

200〜299 以外はすべて `ErrorKindHTTPStatus` とする。

### 12.2. エラー処理

HTTP エラーの場合は以下を保持する。

- HTTP ステータスコード
- レスポンスボディ
- RFC 9457 の Problem Details（取得できた場合）

### 12.3. 注意事項

HTTP エラーのレスポンスボディを破棄してはならない。

JSON 形式でないエラーレスポンスであっても、文字列として保持すること。

Problem Details の解析に失敗しても、HTTP エラーとして正常に返すこと。

レスポンスボディの読み取りに失敗した場合は、読み取りエラーを適切に処理し、可能な限り元の HTTP ステータスコードと取得済みの情報を保持すること。

---

## 13. JSON 処理

### 13.1. リクエスト

POST / PUT では `encoding/json` を利用して JSON に変換する。

シリアライズに失敗した場合は `ErrorKindJSON` を返す。

JSON の変換には `json.Marshal()` を使用する。

### 13.2. レスポンス

GET / POST / PUT / DELETE の通常メソッドでは `encoding/json` を利用する。

JSON のデシリアライズには `json.Unmarshal()` を使用する。

デシリアライズに失敗した場合は `ErrorKindJSON` を返す。

### 13.3. 出力先の検証

レスポンスの変換先 `out` は nil ではないポインタとする。

以下のような指定は不正とする。

```go
var user User

err := client.Get(ctx, url, user)
```

正しい使用方法：

```go
var user User

err := client.Get(ctx, url, &user)
```

不正な出力先の場合は `ErrorKindRequest` を返す。

### 13.4. 空のレスポンス

通常メソッドではレスポンスボディを JSON として解析する。

レスポンスボディが空の場合、JSON 変換エラーとする。

レスポンスボディが空でも正常終了させたい場合は、必ず `Empty` メソッドを使用する。

---

## 14. HTTP リクエストの共通処理

GET / POST / PUT / DELETE の共通処理を適切に分離すること。

ただし、各 HTTP メソッドの仕様が分かりにくくなるほど過度に汎用化しないこと。

共通処理では以下を管理する。

1. URL の検証
2. リクエストの作成
3. HTTP ヘッダーの設定
4. context の設定
5. タイムアウトの設定
6. HTTP リクエストの実行
7. HTTP ステータスコードの確認
8. HTTP エラーの生成
9. レスポンスボディの読み取り
10. レスポンスボディのクローズ
11. JSON 変換

HTTP レスポンスボディは、成功・失敗にかかわらず必ず Close すること。

リクエストボディはリクエストごとに生成し、リトライ時にも再生成できるようにすること。

---

## 15. 並行実行とスレッドセーフ

### 15.1. 基本方針

`HttpClient` は複数の goroutine から同時に利用できるようにする。

### 15.2. 設定の読み取り

HTTP リクエスト開始時に以下の情報をスナップショットとして取得する。

- ClientOptions
- Headers

取得時には適切なロックを使用する。

HTTP 通信中は設定の読み取りロックを保持し続けないこと。

### 15.3. 設定変更

`SetOptions()` や `SetHeaders()` が HTTP 通信中に呼び出されてもデータ競合を発生させないこと。

設定変更後に開始したリクエストから新しい設定を適用する。

すでに開始済みのリクエストは、開始時に取得した設定を使用する。

### 15.4. 注意事項

HTTP 通信中に共有されている `http.Header` を直接変更してはならない。

各リクエスト用にヘッダーをコピーすること。

---

## 16. README.md

パッケージルートに `README.md` を作成する。

以下を記載する。

1. パッケージの概要
2. 提供機能
3. 必要な Go バージョン
4. インストール・利用方法
5. HTTP クライアントの生成方法
6. GET / POST / PUT / DELETE の使用方法
7. レスポンスボディを取得しないメソッドの使用方法
8. Authorization ヘッダーの設定方法
9. 任意の HTTP ヘッダーの設定方法
10. タイムアウト・リトライ設定
11. context.Context の利用方法
12. URL の組み立て方法
13. エラー処理方法
14. RFC 9457 のエラー情報の取得方法
15. 並行利用時の注意事項

実際にコンパイル可能なサンプルコードを掲載すること。

### 16.1. 基本的な使用例

```go
package main

import (
    "context"
    "fmt"

    "your-module-path"
)

type User struct {
    ID   int    `json:"id"`
    Name string `json:"name"`
}

func main() {
    client := httpclient.New()

    ctx := context.Background()

    var user User

    err := client.Get(
        ctx,
        "https://api.example.com/v1/users/123",
        &user,
    )

    if err != nil {
        fmt.Println(err)
        return
    }

    fmt.Println(user.Name)
}
```

README に掲載する import パスは、実際の go.mod の module 宣言に合わせること。

### 16.2. Bearer Token の使用例

```go
headers := httpclient.NewHeaders()

if err := headers.SetBearerToken("your-token"); err != nil {
    return err
}

if err := headers.Add("X-API-Key", "your-api-key"); err != nil {
    return err
}

client, err := httpclient.NewWith(
    httpclient.DefaultClientOptions(),
    headers,
)
if err != nil {
    return err
}
```

### 16.3. 空のレスポンスの使用例

```go
err := client.DeleteEmpty(
    ctx,
    "https://api.example.com/v1/users/123",
)

if err != nil {
    return err
}
```

---

## 17. ユニットテスト

実装後、各機能に対してユニットテストを作成すること。

外部の実際の API サーバーに依存しないテストを基本とする。

`net/http/httptest` を使用し、ローカル HTTP サーバーでレスポンスを制御すること。

### 17.1. HttpClientError

以下をテストする。

- HTTP 401 の場合 `IsAuthErr()` が true
- HTTP 403 の場合 `IsAuthErr()` が true
- HTTP 200 の場合 `IsAuthErr()` が false
- Connection の場合 `IsConnectionErr()` が true
- JSON の場合 `IsJSONParseErr()` が true
- Timeout の場合 `IsTimeout()` が true
- HTTP 429 の場合 `IsRateLimitErr()` が true
- `StatusCodeValue()` が正しい値を返す
- `ResponseBody()` が正しい値を返す
- `ProblemDetails()` が正しい値を返す
- `ToErrMsg()` がエラー種別に応じた文字列を返す
- `Unwrap()` で元のエラーを取得できる

### 17.2. ProblemDetails

以下をテストする。

- RFC 9457 の JSON を正しく解析できる。
- 各フィールドを正しく取得できる。
- 省略されたフィールドがゼロ値になる。
- 不正な JSON の場合に解析に失敗する。
- 解析に失敗しても元のレスポンスボディを保持できる。

### 17.3. Headers

以下をテストする。

- デフォルトヘッダーが設定される。
- Bearer Token を設定できる。
- Bearer Token を変更できる。
- Authorization ヘッダーを削除できる。
- 任意の HTTP ヘッダーを追加できる。
- 同じヘッダーを追加した場合に上書きされる。
- 不正なヘッダー値を指定した場合にエラーになる。

### 17.4. ClientOptions

以下をテストする。

- デフォルトタイムアウトが30秒である。
- デフォルトリトライ回数が0回である。
- オプションを変更できる。
- 0秒のタイムアウトを拒否する。
- 負のリトライ回数を拒否する。

### 17.5. UrlCreator

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

### 17.6. HttpClient

以下をテストする。

| テスト項目 | 期待結果 |
|---|---|
| GET 200 | JSON を構造体に変換できる |
| GET 204 | 通常メソッドでは JSON 変換エラー |
| GET Empty 204 | 正常終了 |
| GET 400 | HttpClientError |
| GET 401 | HttpClientError |
| GET 500 | HttpClientError |
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
| 不正な JSON | JSON |
| 不正な出力先 | Request |
| Authorization | 正しい Bearer Token が送信される |
| 任意ヘッダー | 正しいヘッダーが送信される |
| context キャンセル | リクエストが中断される |

### 17.7. リトライ

以下をテストする。

- RetryCount が0の場合、リトライしない。
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
- GetEmpty にもリトライ仕様が適用される。
- リトライ待機中の context キャンセルで中断する。

テストでは実際の HTTP リクエスト回数を確認すること。

### 17.8. 並行実行

以下をテストする。

- 複数の goroutine から同時に HTTP リクエストを実行できる。
- 同時に Headers を参照してもデータ競合が発生しない。
- 同時に Options を変更してもデータ競合が発生しない。
- HTTP リクエスト中に Headers を変更しても既存リクエストに影響しない。

`go test -race ./...` を実行してデータ競合がないことを確認する。

---

## 18. 品質チェック

以下を実行すること。

### 18.1. フォーマット

```bash
gofmt -w .
```

Go の標準フォーマッターで整形する。

### 18.2. テスト

```bash
go test ./...
```

すべてのテストが成功すること。

### 18.3. データ競合チェック

```bash
go test -race ./...
```

データ競合が検出されないこと。

### 18.4. 静的解析

```bash
go vet ./...
```

問題がないこと。

### 18.5. ビルド

```bash
go build ./...
```

正常にビルドできること。

---

## 19. 完了条件

### 実装

- [ ] net/http を使用している。
- [ ] context.Context に対応している。
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
- [ ] GetEmpty を実装している。
- [ ] PostEmpty を実装している。
- [ ] PutEmpty を実装している。
- [ ] DeleteEmpty を実装している。
- [ ] GET のリトライを実装している。
- [ ] タイムアウトに対応している。
- [ ] HTTP ステータスコードを適切に処理している。
- [ ] 並行利用に対応している。

### 品質

- [ ] gofmt が成功する。
- [ ] go test ./... が成功する。
- [ ] go test -race ./... が成功する。
- [ ] go vet ./... が成功する。
- [ ] go build ./... が成功する。
- [ ] 公開 API に GoDoc コメントがある。
- [ ] README.md が作成されている。
- [ ] README.md のサンプルコードがコンパイル可能である。

---

## 20. Codex への実装指示

以下の手順で作業すること。

1. 既存のモノレポ構成を確認する。
2. 既存の Go workspace と go.mod の構成を確認する。
3. 既存のパッケージ命名規則を確認する。
4. 既存のコーディング規約を確認する。
5. 本仕様書に従ってディレクトリ・ファイルを作成する。
6. 各構造体とメソッドを実装する。
7. ユニットテストを作成する。
8. README.md を作成する。
9. gofmt を実行する。
10. go test ./... を実行する。
11. go test -race ./... を実行する。
12. go vet ./... を実行する。
13. go build ./... を実行する。
14. エラーや警告があれば修正する。
15. 最終的な実装内容とテスト結果を報告する。

既存の go.mod や go.work が存在する場合は、既存設定を不用意に上書きしないこと。

既存コードや他のパッケージに影響を与えないようにすること。

仕様に記載されていない事項で実装判断が必要になった場合は、既存コードとの整合性と Go の標準的な設計を優先すること。

仕様の解釈に重大な曖昧さがある場合は、独自判断で実装を進めず、ユーザーに確認すること。

**最終的には、他の Go プロジェクトからパッケージとして利用できる、テスト済みの HTTP クライアントを完成させること。**