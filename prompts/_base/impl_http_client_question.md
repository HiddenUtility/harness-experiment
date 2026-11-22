

## **1. 使用する HTTP クレート**

HTTP 通信には `reqwest` を使用してください。


## **2. HTTP ステータスコードの扱い**

HTTP ステータスコードが 200 番台以外の場合、- A. すべて `HttpClientError` として返してください。

A の場合、例えば次のような設計を考えています。

```
pub enum HttpClientError {
    HttpStatus {
        status: u16,
        body: String,
    },
    Connection(String),
    Timeout,
    JsonParse(String),
    Request(String),
}
```

RFC 9457 のレスポンスについては、`HttpStatus` の中で Problem Details の各フィールド（`type`, `title`, `status`, `detail`, `instance`）も取得できる設計にできます。

## **3. リクエストボディ**

下記でお願いします．

| メソッド   | リクエストボディ   |
| ------ | ---------- |
| GET    | なし         |
| POST   | JSON       |
| PUT    | JSON       |
| DELETE | なし |

リクエストボディはジェネリック型を受け取り、`serde::Serialize` で JSON に変換する方式を想定しています。

## **4. レスポンスボディ**

レスポンスは `serde::de::DeserializeOwned` を利用して、任意の構造体に変換する方式でお願いします。

```rs
pub async fn get<T>(
    &self,
    url: &str,
) -> Result<T, HttpClientError>
where
    T: DeserializeOwned;
```

なお、HTTP 204 No Content のようにレスポンスボディがない場合は、通常の `T` への変換ができません。

そのため、以下のどちらがよいでしょうか？

- A. 通常の `T` への変換だけをサポートする
- B. `get` などの通常メソッドに加えて、ボディを取得しない `get_empty` なども用意する

## **5. リトライ仕様**

リトライ回数のデフォルトは 0 回とのことですが、リトライ対象を決めたいです。

GETのみで下記で大丈夫です。

| エラー        | リトライ |
| ---------- | ---- |
| 接続エラー      | 対象   |
| タイムアウト     | 対象   |
| HTTP 429   | 対象   |
| HTTP 5xx   | 対象外   |
| HTTP 4xx   | 対象外  |
| JSON 変換エラー | 対象外  |



## **6. Authorization ヘッダー**

Authorization は Bearer Token を標準サポートしてください。

下記でお願いします．

```
headers.set_bearer_token("your-token");

headers.add("X-API-Key", "your-api-key");
headers.add("X-Custom-Header", "value");
```


## レスポンスボディがない場合
HTTP 204 No Content など、レスポンスボディが存在しないケースの扱いです。
- B. 通常の get<T>() などに加えて、ボディを取得しない get_empty()、post_empty()、put_empty()、delete_empty() なども実装する。
