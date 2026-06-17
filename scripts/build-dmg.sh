#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DIST_DIR="dist"
APP_NAME="RemoteControlAgent"
APP_BUNDLE="${ROOT}/macos-agent/${APP_NAME}.app"
DMG_NAME="RemoteControlAgent.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
STAGING="build/staging"

# Build the .app first
echo "📦 Building macOS agent..."
cd macos-agent
bash build-app.sh
cd "$ROOT"

mkdir -p "$STAGING" "$DIST_DIR"
rm -rf "$STAGING"/*

# Copy app to staging
cp -R "$APP_BUNDLE" "$STAGING/"

# Create Applications symlink
ln -s /Applications "$STAGING/Applications"

# Remove old DMG
rm -f "$DMG_PATH"

# Create DMG
echo "💿 Creating DMG..."
hdiutil create -volname "RemoteControl Agent" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG_PATH"

rm -rf "build/staging"

echo "✅ DMG created: $DMG_PATH"
