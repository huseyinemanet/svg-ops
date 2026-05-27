#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/SVG Ops.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/SVGOps" "$MACOS_DIR/SVGOps"
cp "$ROOT_DIR/Scripts/Info.plist" "$CONTENTS_DIR/Info.plist"

if [ -d "$ROOT_DIR/Sources/SVGOpsCore/Resources" ]; then
  cp -R "$ROOT_DIR/Sources/SVGOpsCore/Resources/." "$RESOURCES_DIR/"
fi

chmod +x "$MACOS_DIR/SVGOps"

echo "Built $APP_DIR"
