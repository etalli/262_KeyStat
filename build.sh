#!/bin/bash
# KeyCounter ビルドスクリプト
# 使い方:
#   ./build.sh           # App Bundle のみ作成
#   ./build.sh --run     # ビルド後に即時起動
#   ./build.sh --install # ~/Applications にインストールして起動（推奨）
#   ./build.sh --dmg     # DMG を作成（配布用）
set -e

APP="KeyCounter.app"
DMG="KeyCounter.dmg"
VERSION=$(date +"%Y%m%d")

echo "=== KeyCounter Build ==="
swift build -c release 2>&1

echo ""
echo "=== App Bundle 作成 ==="
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/KeyCounter "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

echo "✅ $APP を作成しました"

# --dmg オプションで DMG を作成
if [[ "$1" == "--dmg" ]]; then
    echo ""
    echo "=== DMG 作成 ==="

    # ステージングディレクトリ（DMGの中身）
    STAGING=$(mktemp -d)
    cp -r "$APP" "$STAGING/"
    # /Applications へのシンボリックリンク（ドラッグ&ドロップ用）
    ln -s /Applications "$STAGING/Applications"

    rm -f "$DMG"
    hdiutil create \
        -volname "KeyCounter" \
        -srcfolder "$STAGING" \
        -ov \
        -format UDZO \
        -o "$DMG"

    rm -rf "$STAGING"

    echo "✅ $DMG を作成しました"
    echo "保存先: $(pwd)/$DMG"
    echo ""
    echo "配布手順:"
    echo "  1. $DMG をユーザーに渡す"
    echo "  2. DMG をダブルクリックしてマウント"
    echo "  3. KeyCounter.app を Applications フォルダにドラッグ"
    echo "  4. /Applications/KeyCounter.app を起動"

# --install: ~/Applications にインストール（アクセシビリティ権限の安定のため推奨）
elif [[ "$1" == "--install" ]]; then
    INSTALL_DIR="$HOME/Applications"
    INSTALL_PATH="$INSTALL_DIR/KeyCounter.app"

    echo ""
    echo "=== ~/Applications にインストール ==="
    mkdir -p "$INSTALL_DIR"
    rm -rf "$INSTALL_PATH"
    cp -r "$APP" "$INSTALL_PATH"

    # ad-hoc コード署名（アクセシビリティ権限の安定化）
    if command -v codesign &>/dev/null; then
        codesign --force --deep --sign - "$INSTALL_PATH" 2>/dev/null && \
            echo "✅ ad-hoc 署名完了" || echo "⚠️  署名スキップ"
    fi

    echo "✅ $INSTALL_PATH にインストールしました"
    echo ""

    # 起動中のプロセスを終了してから再起動
    pkill -x KeyCounter 2>/dev/null || true
    sleep 0.5
    open "$INSTALL_PATH"
    echo "起動しました: $INSTALL_PATH"
    echo ""
    echo "【初回のみ】システム設定 → プライバシーとセキュリティ → アクセシビリティ"
    echo "  で $INSTALL_PATH を許可してください。"
    echo ""
    echo "ログ確認: tail -f ~/Library/Logs/KeyCounter/app.log"

# --run オプションで即時起動
elif [[ "$1" == "--run" ]]; then
    echo ""
    echo "=== 起動 ==="
    open "$APP"

else
    echo ""
    echo "保存先: $(pwd)/$APP"
    echo "起動するには:       open $APP"
    echo "推奨インストール:   ./build.sh --install"
    echo "DMG を作るには:     ./build.sh --dmg"
fi
