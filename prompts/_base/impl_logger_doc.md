
codex（AIエージェント） に実装させるための仕様書を Markdown で出力してください．
パラメータが少ないモデルでも間違いなく作成できるような詳細な仕様書のプロンプトを書いてください．
不明点あればきいてください．
外部クレート使う場合は MITなどのライセンスのもの．

仕様書の素案は下記を参照してください．
---
# 全体
- Rust使用
- Tokio使用
- クレートのsrc階層にはREADME.mdを用意して，簡単なドキュメントとサンプルコードを準備する．
- docstringに仕様書いて，コメントアウトによる説明は極力書かないようにする．
- lib.rs に全部書かずに適切にファイル分割すること

## LogLevel

LogLevel を enum で定義します．
CRITICAL, ERROR, WARNING, INFO, DEBUG 持ち，formatで簡単に str に変換できるように実装します．

## LogRecord
LogRecode を 構造体で定義します．
- 構造体のフィールドには timestamp:String(unix time), level:enum, msg: String, pid: int
- 構造体に critical, error, warning ,info, debug メソッド(以後ログメソッド)を実装します．
    - ログメソッド の引数は msg: str のみです．
    - メソッド呼ばれた時間をISO 8601規格で（example: 2026-11-11T12:13:45.123456） timestamp とします．
- to_logメソッドを実装します．フィールドから `timestamp [level] msg` を生成し Stringの所有権を渡します．

## TextLoggerOptions
ロガーの詳細オプションです．
- フィールドは max_file_num:usize, max_file_size:usize, realtime:bool
- max_file_num は logファイルの出力数です．超えたものは古い順に削除します．デフォルトは 7 です．
- max_file_size は logフィルの最大サイズ数です．

## TextLogger

簡易的な text logger を作ります．
- フィールドは log_path:PathBuf, recodes:LogRecode[], now_size:usize, option: TextLoggerOptions,level: LogLevelです．
    - recodes は LogRecode配列です．
    - log_path は logファイルの出力パスです．(example: logs/name.log)
- new_with メソッドを実装します．
    - 引数は log_path，optionです．
    - log_path の親パスはなければ作ります．
    - log_path が 存在してれば now_size にセットし，なければ now_size は 0 で初期化します．
- new メソッドを実装します．
    - 引数は log_path のみです．
    - option の デフォルトで new_with を呼びます．
- ログメソッドを実装します．
    - 引数は msg: str のみです．
    - メソッドに応じた LogRecode を生成し，LogRecode配列 に追加します．
    - ログメソッド は option.realtime が true なら out を呼びます．
- out メソッドを実装します．
    - LogRecode配列 を logファイルとして書き出し，成功したらLogRecode配列を空にします．
    - LogRecodeを書き出すとき，now_sizeを足し上げます．
    - すべてのLogRecodeを書きだしたあとに，now_size が option.max_file_size を超えていた場合，
        logファイルの拡張子を log.1とします．
    - すでに log.1 が存在した場合は log.1 を log.2へ，log.2 があればlog.3へを繰り返し，
        option.max_file_numに到達したlogファイルは削除します．
- デストラクタでは out メソッドを必ず呼びます．
- メソッドの Result は std::io::Result 使用して，メッセージ内容でエラー表示するのみとします．


## AsyncTextLogger
- SqlLogger の 非同期版を実装してください．
