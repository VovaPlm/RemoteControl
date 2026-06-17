#!/bin/bash
set -euo pipefail

BUILD_DIR=".build"
APP_NAME="RemoteControlAgent"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$CONTENTS/Resources"

cp "$BUILD_DIR/release/Agent" "$MACOS_DIR/$APP_NAME"
cp Info.plist "$CONTENTS/"
cp AppIcon.icns "$CONTENTS/Resources/"

echo "✅ Built $APP_BUNDLE"
