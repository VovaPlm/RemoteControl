#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ANDROID_DIR="android-app"
DIST_DIR="dist"
APK_NAME="RemoteControl.apk"

echo "📱 Building Android APK..."
cd "$ANDROID_DIR"
./gradlew assembleDebug --quiet
cd "$ROOT"

# Copy APK to dist
cp "${ANDROID_DIR}/app/build/outputs/apk/debug/app-debug.apk" "${DIST_DIR}/${APK_NAME}"

echo "✅ APK created: ${DIST_DIR}/${APK_NAME}"
