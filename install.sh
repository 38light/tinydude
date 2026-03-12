#!/bin/bash
set -e

PROJECT="/Users/nazmul/Documents/Claude 2/TinyNMC/TinyNMC/TinyDude.xcodeproj"
BUILD_DIR="/tmp/TinyDude_build"
APP_NAME="Tiny Dude"

echo "🔨 Building $APP_NAME..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" || true

echo "📦 Installing to /Applications..."
pkill -x "$APP_NAME" 2>/dev/null || true; sleep 0.3
rm -rf "/Applications/$APP_NAME.app" && cp -R "$BUILD_DIR/Build/Products/Release/$APP_NAME.app" "/Applications/$APP_NAME.app"

echo "🚀 Launching $APP_NAME..."
open "/Applications/$APP_NAME.app"
echo "✅ Done"
