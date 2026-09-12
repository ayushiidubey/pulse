#!/usr/bin/env bash
# Builds Pulse.app into ./build. Usage: scripts/build.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

# The Liquid Glass APIs need the macOS 26 SDK, which ships with Xcode 26, not the Command Line Tools.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

CONFIG="${1:-release}"
swift build -c "$CONFIG" --arch arm64
BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)"

APP="build/Pulse.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Pulse" "$APP/Contents/MacOS/Pulse"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --timestamp=none "$APP" >/dev/null

echo "Built $APP"
