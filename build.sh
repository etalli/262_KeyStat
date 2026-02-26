#!/bin/bash
# KeyLens Build Script
#
# Comments in this file are bilingual: English first, Japanese second (日本語).
#
# Usage / 使い方:
#   ./build.sh           # Build App Bundle only / App Bundle のみ作成
#   ./build.sh --run     # Build and launch immediately / ビルド後に即時起動
#   ./build.sh --install # Build, install to /Applications, and launch (recommended) / /Applications にインストールして起動（推奨）
#   ./build.sh --dmg     # Build and create a distributable DMG / 配布用 DMG を作成
set -e

APP="KeyLens.app"
DMG="KeyLens.dmg"
VERSION=$(date +"%Y%m%d")

echo "=== KeyLens Build ==="
swift build -c release 2>&1

echo ""
echo "=== Building App Bundle ==="
# Create the bundle directory structure / バンドルディレクトリ構造を作成
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/KeyLens "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

echo "✅ $APP created"

# --dmg: Create a distributable DMG with drag-and-drop installer
# --dmg: ドラッグ&ドロップ形式の配布用 DMG を作成
if [[ "$1" == "--dmg" ]]; then
    echo ""
    echo "=== Creating DMG ==="

    # Staging directory for DMG contents / DMG の中身を用意するステージングディレクトリ
    STAGING=$(mktemp -d)
    cp -r "$APP" "$STAGING/"
    # Symlink to /Applications for drag-and-drop installation / ドラッグ&ドロップ用の /Applications シンボリックリンク
    ln -s /Applications "$STAGING/Applications"

    rm -f "$DMG"
    hdiutil create \
        -volname "KeyLens" \
        -srcfolder "$STAGING" \
        -ov \
        -format UDZO \
        -o "$DMG"

    rm -rf "$STAGING"

    echo "✅ DMG created: $(pwd)/$DMG"
    echo ""
    echo "Distribution steps / 配布手順:"
    echo "  1. Share $DMG with the user / $DMG をユーザーに配布する"
    echo "  2. Double-click the DMG to mount it / DMG をダブルクリックしてマウント"
    echo "  3. Drag KeyLens.app to the Applications folder / KeyLens.app を Applications フォルダにドラッグ"
    echo "  4. Launch /Applications/KeyLens.app"

# --install: Install to /Applications with ad-hoc signing and TCC reset (recommended for development)
# --install: /Applications にインストール、ad-hoc 署名、TCC リセット（開発時推奨）
elif [[ "$1" == "--install" ]]; then
    INSTALL_DIR="/Applications"
    INSTALL_PATH="$INSTALL_DIR/KeyLens.app"

    echo "=== Installing to /Applications ==="

    # /Applications requires root; chown back to current user afterwards
    # /Applications への書き込みは root が必要。インストール後に所有権をユーザーに戻す
    sudo mkdir -p "$INSTALL_DIR"
    sudo rm -rf "$INSTALL_PATH"
    sudo cp -r "$APP" "$INSTALL_PATH"
    sudo chown -R "$(whoami)" "$INSTALL_PATH"

    # Ad-hoc code signing stabilises the Accessibility TCC entry across relaunches
    # ad-hoc 署名により、再起動後もアクセシビリティ権限エントリが安定する
    if command -v codesign &>/dev/null; then
        codesign --force --deep --sign - "$INSTALL_PATH" 2>/dev/null && \
            echo "✅ Ad-hoc signing complete / ad-hoc 署名完了" || echo "⚠️  Signing skipped / 署名スキップ"
    fi

    echo "✅ Installed to $INSTALL_PATH"

    # Kill any running instance before relaunching
    # 再起動前に実行中のプロセスを終了する
    pkill -x KeyLens 2>/dev/null || true
    sleep 0.5

    # Reset the Accessibility TCC entry for this bundle ID.
    # Each new binary has a different hash; macOS stores Accessibility permissions per hash,
    # so the old entry becomes stale after a rebuild. Resetting forces a fresh permission request.
    #
    # バイナリが変わるたびに TCC エントリをリセットする。
    # macOS はアクセシビリティ権限をバイナリハッシュ単位で管理するため、
    # 再ビルドのたびに古いエントリが陳腐化する。リセットで再許可を促す。
    BUNDLE_ID=$(defaults read "$INSTALL_PATH/Contents/Info" CFBundleIdentifier 2>/dev/null)
    if [[ -n "$BUNDLE_ID" ]]; then
        tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null && \
            echo "✅ Accessibility TCC entry reset (re-grant required) / アクセシビリティ権限をリセットしました（再許可が必要です）" || true
    fi

    open "$INSTALL_PATH"
    echo "Launched: $INSTALL_PATH"
    echo ""
    echo "Next step / 次の手順:"
    echo "  System Settings > Privacy & Security > Accessibility — enable KeyLens"
    echo "  システム設定 > プライバシーとセキュリティ > アクセシビリティ — KeyLens を許可"
    echo ""
    echo "View logs / ログ確認: tail -f ~/Library/Logs/KeyLens/app.log"

# --run: Launch the app bundle directly from the project directory (no install)
# --run: プロジェクトフォルダから直接起動（インストールなし）
elif [[ "$1" == "--run" ]]; then
    echo ""
    echo "=== Launching ==="
    open "$APP"

else
    echo ""
    echo "Output / 保存先: $(pwd)/$APP"
    echo "Launch / 起動:              open $APP"
    echo "Install (recommended) / 推奨インストール:  ./build.sh --install"
    echo "Create DMG / DMG を作る:    ./build.sh --dmg"
fi
