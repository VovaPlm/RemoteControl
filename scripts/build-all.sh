#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "================================="
echo "  RemoteControl — Full Build"
echo "================================="
echo ""

bash scripts/build-apk.sh
echo ""
bash scripts/build-dmg.sh

echo ""
echo "================================="
echo "  ✅ All artifacts in dist/"
echo "================================="
ls -lh dist/
