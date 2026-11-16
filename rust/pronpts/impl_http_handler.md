codex（AIエージェント） に実装させるための仕様書を Markdown で出力してください．
パラメータが少ないモデルでも間違いなく作成できるような詳細な仕様書のプロンプトを書いてください．
不明点あればきいてください．
仕様書の素案は下記を参照してください．

---
Rust使用
reqwest使用

簡易的な 非同期の http client (handler) を作成．
GET, POST, PUT, DELETE を別々の関数で実装．
json使うAPIを想定
Authorizationヘッダーに認証トークンを入れれるように設計．
