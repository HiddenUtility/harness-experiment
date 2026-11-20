codex（AIエージェント） に実装させるための仕様書を Markdown で出力してください．
パラメータが少ないモデルでも間違いなく作成できるような詳細な仕様書のプロンプトを書いてください．
不明点あればきいてください．
仕様書の素案は下記を参照してください．

---
# 全体
- Rust使用
- Tokio使用
- モノレポ構成で pjt/creates/create-name/src に実装する
- クレートのsrc階層には README.md を用意して，簡単なドキュメントとサンプルコードを準備する．
- 基本的に docstring に仕様書いて，コメントアウトによる説明は極力書かないようにする．
- lib.rs に全部書かずに適切にファイル分割すること
- fetch の 戻り値には Result<T, HttpClientError> で統一する

## HttpClientError を定義する
- ステーコード以外にもエラー通信エラーなどひとまとめにする
- rcf9457 対応できるように エラーの body もとれるようにする
- 401 は 認証エラーなど，特定できる関数あると助かる (is_auth_errとか?)
- 通信エラーも区別する関数も実装  (is_connection_err とか?)
- JSON の変換エラーも区別する関数も実装  (is_json_parse_err とか?)
- タイムアウトはエラーも区別する関数も実装 (is_timeout とか?)
- to_err_msg のように ただ文字列のみで得る関数も実装 (通信エラーなら Can not connect. みたいな？)

## Headers 構造体を定義
- 一般的な json レスポンスの ヘッダーを デフォルトでセットする
- Authorizationヘッダーに認証トークンを変更できるように設計．
- Authorization 以外の任意の HTTP ヘッダーも追加するメソッドを実装する．

## Clientオプション
- タイムアウト デフォ 30 秒
- リトライ回数 デフォ 0 回

## UrlCreator 
- フルの http の url を作る
- ベースをセットして，パスを付け足す方式
- クエリパラメータを追加する関数も用意する

## 非同期の http client (handler)
- インスタンスにClientオプション, Headers 構造体を保持する方式
- Clientオプション, Headers 構造体 を 変更するメソッドも実装する．
- GET, POST, PUT, DELETE を別々の関数で実装．
    - 引数は完全な URL を渡す設計
    - レスポンスボディは ジェネリック型を使用 して任意の構造体に変換
    - Result<T, HttpClientError> で統一する
