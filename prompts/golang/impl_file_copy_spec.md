# Go File and Directory Copier — Codex Implementation Specification

## 1. プロジェクト概要

Goを使用して、ファイルおよびディレクトリの安全なコピー・移動を行うライブラリを実装する。

以下の3種類のオブジェクトを提供する。

1. `FileCopier`：単一ファイルのコピー・移動
2. `DirectoryCopier`：ディレクトリの再帰的なコピー・移動
3. `FilteredDirectoryCopier`：正規表現による除外設定が可能なディレクトリのコピー・移動

各オブジェクトについて、同期版と非同期版のAPIを提供する。

最も重要な要件は、コピー途中でエラーが発生した場合に、既存の出力データと元データを可能な限り維持することである。

### 1.1 基本方針

- Goを使用する。
- Go 1.24以上を想定する。
- Goの標準ライブラリを優先する。
- 外部パッケージは必要最小限にする。
- 同期版と非同期版の両方を提供する。
- 非同期版はgoroutineを利用する。
- 非同期版は `context.Context` によるキャンセルに対応する。
- エラーはGo標準の `error` を使用する。
- エラーの判定には `errors.Is` と `errors.As` を利用できるようにする。
- 実装を1つのGoファイルに集中させず、責務ごとに分割する。
- 公開型・公開関数・公開メソッドにはGoDoc形式のコメントを記述する。
- コメントによる冗長な説明は避け、公開APIの仕様をGoDocに記載する。
- `README.md` に概要、使用方法、サンプルコードを記載する。

## 2. ディレクトリ構成

以下の構成を基本とする。

```text
file-directory-copier/
├── go.mod
├── README.md
├── file_copier.go
├── directory_copier.go
├── filtered_directory_copier.go
├── options.go
├── errors.go
├── sync_file.go
├── sync_directory.go
├── async_file.go
├── async_directory.go
├── internal/
│   ├── path.go
│   ├── temporary.go
│   ├── replace.go
│   ├── symlink.go
│   └── copy.go
└── tests/
    ├── file_copier_test.go
    ├── directory_copier_test.go
    ├── filtered_directory_test.go
    ├── async_test.go
    └── error_test.go
```

必要に応じてファイルを追加してよい。

ただし、公開APIと内部処理を分離すること。

`internal` パッケージには外部から直接利用させる必要のない共通処理を配置する。

## 3. 外部依存

原則としてGo標準ライブラリだけで実装する。

使用する標準パッケージの例：

| パッケージ | 用途 |
|---|---|
| os | ファイル・ディレクトリ操作 |
| io | ファイルコピー |
| io/fs | ファイルシステム情報 |
| path/filepath | パス操作 |
| context | 非同期処理のキャンセル |
| regexp | 正規表現 |
| errors | エラー判定 |
| fmt | エラーメッセージ |
| sync | 必要に応じた並行処理の制御 |
| strings | ファイル名処理 |
| time | 一時パスの一意性補助 |

外部依存を追加する場合は、その必要性を明確にすること。

## 4. 共通仕様

### 4.1 コピー処理の基本原則

すべてのコピー処理は、直接最終出力先に書き込まない。

必ず一時ファイルまたは一時ディレクトリにコピーし、コピーが完了してから最終出力先に反映する。

処理順序は以下とする。

1. コピー元パスの検証。
2. 出力先の親ディレクトリを作成する。
3. 既存の一時ファイル・一時ディレクトリがあれば削除する。
4. 一時ファイル・一時ディレクトリにコピーする。
5. コピーが完全に成功したことを確認する。
6. 既存の出力先があればバックアップパスにリネームする。
7. 一時出力先を正式な出力先にリネームする。
8. リネームに成功した後、バックアップを削除する。
9. 移動処理の場合は、最後に元データを削除する。

### 4.2 既存出力先の保護

既存の出力先は、新しいコピーが完成するまで残しておく。

コピー途中で既存の出力先を削除してはならない。

置き換えにはバックアップ方式を使用する。

```text
1. 既存の出力先をバックアップパスにrename
2. 一時出力先を正式な出力先にrename
3. rename成功後、バックアップを削除
```

一時出力先のrenameに失敗した場合は、バックアップを元の出力先に戻す。

バックアップの復元にも失敗した場合は、元のエラーと復元エラーの両方を保持する。

Go 1.20以降で利用できる `errors.Join` を使用してよい。

バックアップパスは、プロセスID、時刻、ランダム要素などを利用し、衝突しない名前を生成する。

### 4.3 重要：置き換え処理の原子性

ファイルシステム上で複数のrenameを行うため、すべての処理を完全なトランザクションとして保証することはできない。

ただし、以下を必ず実施する。

- コピー完成前に既存出力先を削除しない。
- rename失敗時にバックアップの復元を試みる。
- 復元に失敗した場合はバックアップを削除しない。
- バックアップの削除に失敗した場合は新しい出力先を維持する。
- 失敗した操作と残存ファイルのパスをエラーに含める。

### 4.4 パスの扱い

- パス操作には `filepath` パッケージを使用する。
- ファイル名の連結には `filepath.Join` だけでなく、必要に応じて `filepath.Base` と `filepath.Dir` を使用する。
- 相対パスと絶対パスの両方を扱う。
- コピー元が存在することを確認する。
- コピー元の種類を `os.Lstat` などで確認する。
- コピー元と出力先が同一の場合はエラーとする。
- ディレクトリコピーでは出力先がコピー元ディレクトリの内部にある場合も拒否する。
- パス検証には `filepath.Rel` などを適切に利用する。
- シンボリックリンクを考慮し、単純な文字列比較だけで同一性や包含関係を判定しない。

### 4.5 一時ファイルの命名規則

ファイル名の末尾に `.temp` を追加する。

例：

```text
data.txt       → data.txt.temp
archive.tar.gz → archive.tar.gz.temp
data           → data.temp
```

拡張子を置き換えてはならない。

### 4.6 一時ディレクトリの命名規則

ディレクトリ名の末尾に `_temp` を追加する。

例：

```text
backup  → backup_temp
project → project_temp
```

### 4.7 一時データの削除

コピー開始時に同じ命名規則の一時データが存在する場合は削除する。

- ファイル：`os.Remove`
- ディレクトリ：`os.RemoveAll`

ただし、想定と異なる種類のファイルが存在する場合は、安全性を確認してから削除する。

コピー処理が失敗した場合は、一時データを可能な限り削除する。

後始末に失敗した場合は、元のコピーエラーを必ず保持する。

### 4.8 エラー仕様

Go標準の `error` を使用する。

公開APIでエラーを返す場合は、処理内容と対象パスを含むメッセージを付与する。

例：

```text
failed to open source file: ...
failed to create destination directory: ...
failed to copy file to temporary path: ...
failed to rename temporary file: ...
failed to restore backup destination: ...
failed to remove source file: ...
invalid exclusion regex: ...
```

元のエラーを判定できるように `%w` を使用してラップする。

複数のエラーを保持する必要がある場合は `errors.Join` を使用する。

公開APIでエラーを文字列比較することを前提にしてはならない。

必要に応じて以下のSentinel Errorを定義する。

```go
var (
    ErrInvalidSource       = errors.New("invalid source")
    ErrInvalidDestination  = errors.New("invalid destination")
    ErrSamePath            = errors.New("source and destination are the same")
    ErrDestinationInside   = errors.New("destination is inside source directory")
    ErrUnsupportedFileType = errors.New("unsupported file type")
    ErrInvalidPattern      = errors.New("invalid exclusion pattern")
)
```

Sentinel Errorは `errors.Is` で判定できるようにする。

## 5. FileCopier

### 5.1 責務

指定された単一ファイルを指定された出力先ディレクトリにコピーする。

出力先のファイル名はコピー元と同じにする。

### 5.2 構造体

```go
type FileCopier struct {
    filePath string
    dirPath  string
}
```

### 5.3 コンストラクタ

```go
func NewFileCopier(
    filePath string,
    dirPath string,
) *FileCopier
```

### 5.4 同期API

```go
func (c *FileCopier) Copy() error

func (c *FileCopier) Move() error
```

### 5.5 非同期API

```go
func (c *FileCopier) CopyAsync(
    ctx context.Context,
) <-chan error

func (c *FileCopier) MoveAsync(
    ctx context.Context,
) <-chan error
```

非同期APIは呼び出し時にgoroutineを起動し、処理結果をチャネルで通知する。

チャネルには結果を1回だけ送信し、処理終了後にcloseする。

呼び出し側はチャネルから結果を1回受け取る。

### 5.6 コピー処理

コピー元のファイル名を取得し、`dirPath` 内に同じ名前で出力する。

出力先ディレクトリが存在しない場合は `os.MkdirAll` で作成する。

コピーには `os.Open`、`os.Create`、`io.Copy` を利用する。

コピー先ファイルを作成した後、必ず `Close` する。

書き込みエラーだけでなく `Close` のエラーも確認する。

### 5.7 同名ファイルの置き換え

既存ファイルは一時コピーが完成するまで残す。

一時ファイル完成後にバックアップ方式で置き換える。

### 5.8 移動処理

`Move` および `MoveAsync` はコピーと最終出力先へのrenameが成功した後に元ファイルを削除する。

元ファイルの削除に失敗した場合はエラーを返す。

この場合、新しい出力先は維持する。

元ファイルがシンボリックリンクの場合はリンクそのものを削除する。

### 5.9 シンボリックリンク

コピー元がシンボリックリンクの場合は、リンク先をたどらずリンクそのものをコピーする。

`os.Readlink` でリンク先のパスを取得し、OSに対応したシンボリックリンク作成処理を使用する。

Windowsではファイル用・ディレクトリ用のシンボリックリンクAPIを使い分ける。

### 5.10 ファイル属性

通常ファイルの内容をコピーすることを必須とする。

ファイルのアクセス権限、所有者、タイムスタンプなどの完全な維持は必須要件ではない。

## 6. DirectoryCopier

### 6.1 責務

指定されたディレクトリを再帰的にコピーする。

サブディレクトリ、空ディレクトリ、ファイルを含むディレクトリ構造を維持する。

### 6.2 構造体

```go
type DirectoryCopier struct {
    dirPath  string
    destPath string
}
```

### 6.3 コンストラクタ

```go
func NewDirectoryCopier(
    dirPath string,
    destPath string,
) *DirectoryCopier
```

### 6.4 同期API

```go
func (c *DirectoryCopier) Copy() error

func (c *DirectoryCopier) Move() error
```

### 6.5 非同期API

```go
func (c *DirectoryCopier) CopyAsync(
    ctx context.Context,
) <-chan error

func (c *DirectoryCopier) MoveAsync(
    ctx context.Context,
) <-chan error
```

### 6.6 出力先

`destPath` はコピー後のディレクトリそのものを指定する。

例：

```text
source/
    a.txt
    sub/
        b.txt
```

出力先が `destination/backup` の場合：

```text
destination/
    backup/
        a.txt
        sub/
            b.txt
```

出力先の親ディレクトリが存在しない場合は作成する。

### 6.7 再帰コピー

以下を必ず実装する。

- サブディレクトリを再帰的にコピーする。
- 空ディレクトリをコピーする。
- ファイル内容をコピーする。
- ディレクトリ構造を維持する。
- ファイル名とディレクトリ名を変更しない。

`filepath.WalkDir` または `os.ReadDir` を使用してよい。

### 6.8 シンボリックリンク

コピー元のシンボリックリンクは、リンク先をたどらずリンクそのものをコピーする。

リンク先がファイルでもディレクトリでも、リンクそのものをコピーする。

`DirEntry.Type` や `os.Lstat` を利用してリンク自体を判定する。

リンク先のディレクトリを再帰走査してはならない。

### 6.9 一時ディレクトリ

コピー中は `destPath` の末尾に `_temp` を追加したディレクトリにコピーする。

コピー完了後に正式な出力先に置き換える。

既存の出力先はコピー完了まで維持する。

### 6.10 移動処理

`Move` および `MoveAsync` は、コピーと出力先へのrenameが成功した後に元ディレクトリを削除する。

削除には `os.RemoveAll` を使用する。

元ディレクトリの削除に失敗した場合はエラーを返す。

コピー済みの出力先は削除しない。

## 7. FilteredDirectoryCopier

### 7.1 責務

`DirectoryCopier` と同じコピー・移動機能を提供する。

追加機能として、正規表現に一致するファイル名・ディレクトリ名をコピー対象から除外する。

### 7.2 オプション構造体

```go
type FilteredDirectoryOptions struct {
    excludeFilePatterns []*regexp.Regexp
    excludeDirPatterns  []*regexp.Regexp
}
```

外部から直接フィールドを変更できないようにする。

### 7.3 構造体

```go
type FilteredDirectoryCopier struct {
    dirPath  string
    destPath string
    options  FilteredDirectoryOptions
}
```

### 7.4 コンストラクタ

```go
func NewFilteredDirectoryCopier(
    dirPath string,
    destPath string,
) *FilteredDirectoryCopier

func NewFilteredDirectoryCopierWith(
    dirPath string,
    destPath string,
    options FilteredDirectoryOptions,
) *FilteredDirectoryCopier
```

### 7.5 オプション構造体のコンストラクタ

```go
func NewFilteredDirectoryOptions() FilteredDirectoryOptions
```

デフォルトでは除外パターンを設定しない。

### 7.6 メソッドチェーン

```go
func (c *FilteredDirectoryCopier) ExcludeFile(
    pattern string,
) (*FilteredDirectoryCopier, error)

func (c *FilteredDirectoryCopier) ExcludeDir(
    pattern string,
) (*FilteredDirectoryCopier, error)
```

正規表現は `regexp.Compile` でコンパイルする。

不正な正規表現の場合は `ErrInvalidPattern` を含むエラーを返す。

設定済みのパターンを消さずに追加する。

### 7.7 除外判定

正規表現の対象はパス全体ではなく、ファイル名またはディレクトリ名だけとする。

例：

```text
project/
    src/
        main.go
    target/
        debug/
    logs/
        app.log
        error.log
    .git/
```

設定例：

```go
copier := NewFilteredDirectoryCopier(
    "project",
    "backup/project",
)

var err error

copier, err = copier.ExcludeFile(`\.log$`)
if err != nil {
    return err
}

copier, err = copier.ExcludeDir(`^target$`)
if err != nil {
    return err
}

copier, err = copier.ExcludeDir(`^\.git$`)
if err != nil {
    return err
}

if err := copier.Copy(); err != nil {
    return err
}
```

出力結果：

```text
backup/
    project/
        src/
            main.go
        logs/
```

### 7.8 ファイル除外

- ファイル名だけを正規表現と比較する。
- 一致したファイルはコピーしない。
- 一致したファイルの親ディレクトリはコピーする。
- 複数のパターンがある場合、いずれか1つに一致すれば除外する。

### 7.9 ディレクトリ除外

- ディレクトリ名だけを正規表現と比較する。
- 一致したディレクトリはコピーしない。
- 一致したディレクトリ配下もコピーしない。
- 複数のパターンがある場合、いずれか1つに一致すれば除外する。

### 7.10 シンボリックリンク

シンボリックリンクはリンク先をたどらず、リンク自体の名前を使ってファイル除外パターンを適用する。

### 7.11 非UTF-8ファイル名

Goのファイル名は文字列として取得できるが、OSによってはUTF-8以外のバイト列を含む可能性がある。

正規表現はGoの文字列として評価する。

無効なUTF-8が含まれる場合の照合結果は、Goのregexpパッケージの仕様に従う。

### 7.12 コピー・移動API

```go
func (c *FilteredDirectoryCopier) Copy() error

func (c *FilteredDirectoryCopier) Move() error

func (c *FilteredDirectoryCopier) CopyAsync(
    ctx context.Context,
) <-chan error

func (c *FilteredDirectoryCopier) MoveAsync(
    ctx context.Context,
) <-chan error
```

## 8. 非同期API仕様

### 8.1 基本方針

3種類すべてのオブジェクトに非同期APIを提供する。

Goではgoroutineによる並行実行を利用する。

非同期APIは同期版の処理をgoroutine内で実行し、結果をチャネルで返す方式を基本とする。

### 8.2 非同期APIの契約

- 呼び出し時にgoroutineを起動する。
- `context.Context` を必須引数とする。
- 結果を `chan error` で通知する。
- 処理結果は必ず1回通知する。
- 結果通知後にチャネルをcloseする。
- 呼び出し側が結果を受け取らなくてもgoroutineがチャネル送信で永久に停止しないようにする。
- 同じコピー先に対する並列実行はサポート対象外とする。

実装例：

```go
func (c *FileCopier) CopyAsync(
    ctx context.Context,
) <-chan error {
    result := make(chan error, 1)

    go func() {
        defer close(result)

        result <- c.copyWithContext(ctx)
    }()

    return result
}
```

この例は設計の参考とし、実際の処理は内部関数に分割する。

### 8.3 context対応

非同期処理では、ファイルコピー中およびディレクトリ走査中に `ctx.Err()` を確認する。

キャンセルが検出された場合は処理を中断する。

キャンセル時には以下を実施する。

1. 新しいファイルコピーを開始しない。
2. 現在のファイルコピーを可能な範囲で中断する。
3. 一時ファイル・一時ディレクトリを可能な限り削除する。
4. 既存の出力先を維持する。
5. 元データを削除しない。
6. `context.Canceled` または `context.DeadlineExceeded` を `errors.Is` で判定できる形で返す。

`io.Copy` はcontextを直接受け取らないため、非同期版ではcontextを確認するReaderラッパーなどを実装する。

ただし、OSのファイルI/Oそのものを即座にキャンセルできるとは限らない。

### 8.4 同期版との共通化

同期版と非同期版で、コピー処理のロジックを重複させない。

内部処理を共通化する。

同期版はcontextなしで実行する。

非同期版はcontext付きの内部処理をgoroutineで実行する。

### 8.5 注意事項

この非同期APIはgoroutineによる非同期実行を提供するものであり、OSのネイティブ非同期ファイルI/Oを保証するものではない。

Goの標準的なファイル操作を利用し、goroutineによって呼び出し元の処理とコピー処理を分離する。

## 9. コピー対象の種類と制約

### 9.1 対応対象

- 通常ファイル
- ディレクトリ
- 空ディレクトリ
- シンボリックリンク

### 9.2 非対応対象

ソケット、FIFO、デバイスファイルなどの特殊ファイルはコピー対象外とする。

検出した場合は `ErrUnsupportedFileType` を含むエラーを返す。

### 9.3 シンボリックリンクの循環

リンク先をたどらないため、リンクの循環による無限再帰は発生させない。

## 10. テスト仕様

標準の `testing` パッケージを利用する。

テストには `os.MkdirTemp` を利用し、テスト終了時に `os.RemoveAll` で後始末する。

同期版・非同期版の両方をテストする。

### 10.1 FileCopier

| No. | テスト内容 | 期待結果 |
|---|---|---|
| 1 | 通常ファイルのコピー | 内容が一致する |
| 2 | 出力先ディレクトリが存在しない | 自動作成される |
| 3 | 同名ファイルが存在する | 新しい内容に置き換わる |
| 4 | コピー元ファイルが存在しない | エラーになる |
| 5 | 一時ファイルが存在する | 古い一時ファイルが削除される |
| 6 | コピー失敗 | 一時ファイルが可能な限り削除される |
| 7 | コピー処理 | 元ファイルが残る |
| 8 | 移動処理 | コピー完了後に元ファイルが削除される |
| 9 | コピー先作成失敗 | 元ファイルが残る |
| 10 | 同一パスへのコピー | エラーになる |
| 11 | シンボリックリンク | リンクそのものがコピーされる |
| 12 | 元ファイル削除失敗 | 出力先が維持される |

### 10.2 DirectoryCopier

| No. | テスト内容 | 期待結果 |
|---|---|---|
| 1 | 通常ディレクトリ | 正常にコピーされる |
| 2 | 多階層ディレクトリ | 構造が維持される |
| 3 | 空ディレクトリ | コピーされる |
| 4 | 同名ディレクトリ | 新しい内容に置き換わる |
| 5 | 一時ディレクトリ | 古い一時ディレクトリが削除される |
| 6 | コピー失敗 | 一時ディレクトリが可能な限り削除される |
| 7 | コピー処理 | 元ディレクトリが残る |
| 8 | 移動処理 | コピー完了後に元ディレクトリが削除される |
| 9 | コピー元が存在しない | エラーになる |
| 10 | 出力先がコピー元の内部 | エラーになる |
| 11 | シンボリックリンク | リンクそのものがコピーされる |
| 12 | シンボリックリンクの循環 | 無限再帰しない |
| 13 | 特殊ファイル | エラーになる |

### 10.3 FilteredDirectoryCopier

| No. | テスト内容 | 期待結果 |
|---|---|---|
| 1 | ファイル除外 | 一致ファイルが除外される |
| 2 | ディレクトリ除外 | 一致ディレクトリが除外される |
| 3 | 除外ディレクトリ配下 | すべて除外される |
| 4 | 複数パターン | すべて適用される |
| 5 | 不正な正規表現 | 設定時にエラーになる |
| 6 | メソッドチェーン | 複数設定できる |
| 7 | 空ディレクトリ | 除外されていなければコピーされる |
| 8 | ファイル名とディレクトリ名が同じ | 独立して判定される |
| 9 | ファイル除外 | 親ディレクトリは残る |
| 10 | シンボリックリンク | リンク自体の名前で除外判定する |

### 10.4 非同期テスト

すべての非同期APIについて以下を確認する。

- 正常終了。
- コピーエラー。
- キャンセル。
- タイムアウト。
- キャンセル後の一時データ削除。
- 元データが維持されること。
- 出力先の既存データが維持されること。
- 結果チャネルがcloseされること。

### 10.5 異常系テスト

以下を必ずテストする。

- コピー元が存在しない。
- 出力先の親ディレクトリを作成できない。
- 既存出力先のバックアップrenameに失敗する。
- 一時出力先のrenameに失敗する。
- バックアップ復元に失敗する。
- 一時データの削除に失敗する。
- 元データの削除に失敗する。
- 正規表現が不正である。
- コピー元と出力先が同一である。
- ディレクトリコピーで出力先がコピー元内部にある。

OS依存のエラーについては、可能な範囲でテストする。

必要に応じて内部処理にファイルシステム操作の差し替えポイントを設けてもよいが、テスト専用の公開APIを追加してはならない。

## 11. README仕様

ルートの `README.md` に以下を記載する。

- ライブラリの概要
- 提供する3種類のオブジェクト
- 同期APIと非同期APIの違い
- インストール方法
- 基本的な使用例
- ファイルコピー例
- ディレクトリコピー例
- 除外設定例
- contextによるキャンセル例
- コピーと移動の違い
- 一時ファイル・一時ディレクトリの動作
- ライセンス

サンプルコードはコピーして利用できる状態にする。

## 12. GoDoc仕様

公開する型、関数、メソッドにはGoDoc形式のコメントを必ず記述する。

特に以下を説明する。

- 引数の意味
- 戻り値
- エラーが発生する条件
- コピーと移動の違い
- 一時データの扱い
- 除外パターンの適用対象
- 非同期APIの使用方法
- contextによるキャンセルの動作

公開APIのコメントは、Goの命名規則に従い、対象の型・関数・メソッド名から始める。

## 13. 実装上の禁止事項

以下は禁止する。

1. すべての処理を1つのGoファイルに書くこと。
2. コピー途中で既存の出力先を削除すること。
3. コピー失敗時に元データを削除すること。
4. 非同期APIでcontextを無視すること。
5. 非同期APIでgoroutineを終了できない設計にすること。
6. ディレクトリコピーでシンボリックリンクを無条件にたどること。
7. 除外正規表現をコピー処理中に毎回コンパイルすること。
8. ディレクトリ除外後に配下を走査すること。
9. エラー発生時に一時データの後始末を行わないこと。
10. 後始末のエラーによって元のエラーを隠すこと。
11. `panic` を通常のファイル操作エラー処理に使用すること。
12. 不要な外部パッケージを追加すること。
13. 仕様にないメタデータ維持を必須要件として実装すること。
14. 同じ出力先への並列実行を安全にサポートすると誤って保証すること。

## 14. 実装手順

### Step 1：プロジェクト準備

- go.modを作成する。
- モジュール名を適切に設定する。
- Goバージョンを設定する。
- ディレクトリ構成を作成する。

### Step 2：共通処理

- パス検証を実装する。
- 一時ファイル名の生成を実装する。
- 一時ディレクトリ名の生成を実装する。
- バックアップパスの生成を実装する。
- 既存出力先の置き換え処理を実装する。
- エラー処理を共通化する。

### Step 3：FileCopier

- コンストラクタを実装する。
- 同期コピーを実装する。
- 同期移動を実装する。
- 非同期コピーを実装する。
- 非同期移動を実装する。
- シンボリックリンク対応を実装する。
- テストする。

### Step 4：DirectoryCopier

- コンストラクタを実装する。
- 再帰コピーを実装する。
- 空ディレクトリ対応を実装する。
- シンボリックリンク対応を実装する。
- 同期移動を実装する。
- 非同期処理を実装する。
- テストする。

### Step 5：FilteredDirectoryCopier

- オプション構造体を実装する。
- 正規表現のコンパイル処理を実装する。
- メソッドチェーンを実装する。
- ファイル除外を実装する。
- ディレクトリ除外を実装する。
- 同期版と非同期版を実装する。
- テストする。

### Step 6：ドキュメント

- GoDocを記述する。
- README.mdを作成する。
- 使用例を追加する。

### Step 7：最終検証

以下を実行する。

```bash
gofmt -w .
go vet ./...
go test ./...
go test -race ./...
go test -cover ./...
```

すべて成功することを確認する。

## 15. 完了条件

- [ ] FileCopierの同期コピーが動作する。
- [ ] FileCopierの同期移動が動作する。
- [ ] FileCopierの非同期コピーが動作する。
- [ ] FileCopierの非同期移動が動作する。
- [ ] DirectoryCopierの同期コピーが動作する。
- [ ] DirectoryCopierの同期移動が動作する。
- [ ] DirectoryCopierの非同期コピーが動作する。
- [ ] DirectoryCopierの非同期移動が動作する。
- [ ] FilteredDirectoryCopierの同期コピーが動作する。
- [ ] FilteredDirectoryCopierの同期移動が動作する。
- [ ] FilteredDirectoryCopierの非同期コピーが動作する。
- [ ] FilteredDirectoryCopierの非同期移動が動作する。
- [ ] ファイル除外が動作する。
- [ ] ディレクトリ除外が動作する。
- [ ] 空ディレクトリがコピーされる。
- [ ] シンボリックリンクそのものがコピーされる。
- [ ] 既存出力先がコピー完成まで維持される。
- [ ] コピー失敗時に元データが維持される。
- [ ] コピー失敗時に一時データが可能な限り削除される。
- [ ] 移動処理では出力先確定後に元データが削除される。
- [ ] 非同期APIがcontextによるキャンセルに対応する。
- [ ] 非同期APIの結果チャネルが適切にcloseされる。
- [ ] 同期版と非同期版の動作が一致する。
- [ ] すべてのテストが成功する。
- [ ] go vetで問題がない。
- [ ] race detectorでデータ競合が検出されない。
- [ ] README.mdが作成されている。
- [ ] GoDocが適切に記述されている。

## 16. Codexへの最終指示

この仕様書に従って、実際にGoライブラリを実装すること。

実装開始前に既存プロジェクトの構成とコードを確認すること。

既存のコードやファイルを理由なく削除・変更してはならない。

Goの標準的な設計と慣習を尊重し、Rustなど他言語の設計を無理に持ち込まないこと。

仕様に矛盾や実装上の重大な問題が見つかった場合は、独自判断で仕様を変更せず、問題点と対応案を提示すること。

実装後は必ずフォーマット、vet、テスト、race detectorを実行すること。

失敗した項目がある場合は、成功したように報告してはならない。

最終報告には以下を含めること。

1. 実装した機能
2. 作成・変更したファイル
3. 追加した外部依存
4. 実施したテストと結果
5. go vetの実行結果
6. race detectorの実行結果
7. 未実装項目や既知の制約

仕様に記載された機能を省略せず、同期版・非同期版の両方を完成させること。