#!/bin/bash
# KeyCounter ビルドスクリプト
# 使い方: ./build.sh [--run]
set -e

APP="KeyCounter.app"

echo "=== KeyCounter ビルド ==="
swift build -c release 2>&1

echo ""
echo "=== App Bundle 作成 ==="
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/KeyCounter "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

echo "✅ $APP を作成しました"
echo ""
echo "保存先: $(pwd)/$APP"

# --run オプションで即時起動
if [[ "$1" == "--run" ]]; then
    echo ""
    echo "=== 起動 ==="
    open "$APP"
else
    echo ""
    echo "起動するには: open $APP"
fi
