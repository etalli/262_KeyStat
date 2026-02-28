#!/bin/bash
# KeyLens Build Script
#
# Usage:
#   ./build.sh           # Build App Bundle only
#   ./build.sh --run     # Build and launch immediately
#   ./build.sh --install # Build, install to /Applications, and launch (recommended)
#   ./build.sh --dmg     # Build and create a distributable DMG
set -e

APP="KeyLens.app"
DMG="KeyLens.dmg"
VERSION=$(date +"%Y%m%d")

# Language detection: $LANG env var first, fall back to system AppleLocale
if [[ "${LANG:-}" == ja_* ]] || defaults read -g AppleLocale 2>/dev/null | grep -q "^ja"; then
    USE_JA=1
else
    USE_JA=0
fi
msg() { [[ $USE_JA -eq 1 ]] && echo "$2" || echo "$1"; }

echo "=== KeyLens Build ==="
swift build -c release 2>&1

echo ""
echo "=== Building App Bundle ==="
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/KeyLens "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp images/AppIcon.png  "$APP/Contents/Resources/AppIcon.png"

echo "$APP created"

# --dmg: Create a distributable DMG with drag-and-drop installer
if [[ "$1" == "--dmg" ]]; then
    echo ""
    echo "=== Creating DMG ==="

    STAGING=$(mktemp -d)
    cp -r "$APP" "$STAGING/"
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
    msg "Distribution steps:" "配布手順:"
    msg "  1. Share $DMG with the user" "  1. $DMG をユーザーに配布する"
    msg "  2. Double-click the DMG to mount it" "  2. DMG をダブルクリックしてマウント"
    msg "  3. Drag KeyLens.app to the Applications folder" "  3. KeyLens.app を Applications フォルダにドラッグ"
    echo "  4. Launch /Applications/KeyLens.app"

# --install: Install to /Applications with ad-hoc signing and TCC reset (recommended for development)
elif [[ "$1" == "--install" ]]; then
    INSTALL_DIR="/Applications"
    INSTALL_PATH="$INSTALL_DIR/KeyLens.app"

    msg "=== Installing to /Applications ===" "=== /Applications にインストール ==="

    # /Applications requires root; chown back to current user afterwards
    sudo mkdir -p "$INSTALL_DIR"
    sudo rm -rf "$INSTALL_PATH"
    sudo cp -r "$APP" "$INSTALL_PATH"
    sudo chown -R "$(whoami)" "$INSTALL_PATH"

    # Ad-hoc code signing stabilises the Accessibility TCC entry across relaunches
    if command -v codesign &>/dev/null; then
        codesign --force --deep --sign - "$INSTALL_PATH" 2>/dev/null || \
            msg "⚠️  Signing skipped" "⚠️  署名スキップ"
    fi

    # Reset the Accessibility TCC entry for this bundle ID.
    # Each new binary has a different hash; resetting forces a fresh permission request.
    BUNDLE_ID=$(defaults read "$INSTALL_PATH/Contents/Info" CFBundleIdentifier 2>/dev/null)
    [[ -n "$BUNDLE_ID" ]] && tccutil reset Accessibility "$BUNDLE_ID" &>/dev/null || true

    pkill -x KeyLens 2>/dev/null || true
    sleep 0.5
    open "$INSTALL_PATH"

    msg "✅ Installed: $INSTALL_PATH" "✅ インストール完了: $INSTALL_PATH"
    msg "  → System Settings > Privacy & Security > Accessibility — enable KeyLens" \
        "  → システム設定 > プライバシーとセキュリティ > アクセシビリティ — KeyLens を許可"

# --run: Launch the app bundle directly from the project directory (no install)
elif [[ "$1" == "--run" ]]; then
    echo ""
    msg "=== Launching ===" "=== 起動中 ==="
    open "$APP"

else
    echo ""
    msg "Output:  $(pwd)/$APP"           "保存先:       $(pwd)/$APP"
    msg "Launch:  open $APP"             "起動:         open $APP"
    msg "Install: ./build.sh --install"  "インストール: ./build.sh --install"
    msg "DMG:     ./build.sh --dmg"      "DMG を作る:   ./build.sh --dmg"
fi
