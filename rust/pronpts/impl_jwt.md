codex（AIエージェント） に実装させるための仕様書を Markdown で出力してください．
パラメータが少ないモデルでも間違いなく作成できるような詳細な仕様書のプロンプトを書いてください．
不明点あればきいてください．
仕様書の素案は下記を参照してください．

---
Rust使用
uuid4使用

jwt を Serialize, Deserialize を する関数を実装．
jwt の秘密鍵を生成する関数を実装．
    - ランダムな文字列で十分長い
payloadを構造体で定義．
    - jwt でよく使われる属性（有効期限，開始日時，jti など）を設定
    - 有効期限内か調べる関数を実装．
jwt から payload を 読む関数を実装．
    - 秘密鍵まちがいかパース失敗なのかわかるよるようにResultを組む

HS256を使用

## payloadの例
```rs
pub struct JwtPayload {
    pub iss: Option<String>,       // 発行者
    pub sub: Option<String>,       // 主体
    pub aud: Option<String>,       // 対象者
    pub exp: i64,                  // 有効期限
    pub nbf: i64,                  // 有効開始日時
    pub iat: i64,                  // 発行日時
    pub jti: String,               // JWT ID (UUID v4)
    pub data: Option<serde_json::Value>, // 独自データ
}
```

## 有効期限の判定
- 現在時刻が nbf より前なら無効。
- 現在時刻が exp 以上なら無効。
- それ以外なら有効。
- 時刻はUnix Timestamp（秒）で統一。

つまり、nbf <= now < exp の場合のみ有効

## 有効期限の検証タイミング
JWT読み込み時に自動検証 ＋ 個別に検証する関数も用意
