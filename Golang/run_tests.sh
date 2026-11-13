#!/bin/bash

# エラーが発生したら即座に終了
set -e

echo "🔍 1. コードのフォーマットと静的解析を実行中..."
# フォーマット崩れがないか確認（修正が必要なファイル名を表示）
UNFORMATTED=$(gofmt -l .)
if [ -n "$UNFORMATTED" ]; then
    echo "⚠️ 以下のファイルがフォーマットされていません:"
    echo "$UNFORMATTED"
    echo "💡 'gofmt -w .' を実行して修正してください。"
    exit 1
fi

# 潜在的なバグや不審なコードを検出
go vet ./...

echo "🧪 2. すべてのテストを実行中..."
# ベレース（-v）付きでテストを実行し、カバレッジも同時に取得
go test -v -race -coverprofile=coverage.out ./...

echo "📊 3. カバレッジレポートを集計中..."
go tool cover -func=coverage.out

echo "✨ すべてのテストと品質チェックが正常に完了しました！"