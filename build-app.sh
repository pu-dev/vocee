#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-debug}"
APP_NAME="VoiceScribe"
BUNDLE="$APP_NAME.app"

swift build -c "$CONFIG"

BIN_PATH=".build/$CONFIG/$APP_NAME"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$BIN_PATH" "$BUNDLE/Contents/MacOS/$APP_NAME"
cp Info.plist "$BUNDLE/Contents/Info.plist"

# Ad-hoc sign so the mic-permission (TCC) prompt has a stable identity to attach to.
codesign --force --deep --sign - "$BUNDLE"

echo "Built $BUNDLE"
echo "Run with: open $BUNDLE"
