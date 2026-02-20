#!/bin/bash
# Build Watchdog.app bundle from SPM executable
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Watchdog"
BUILD_DIR="$PROJECT_DIR/.build/arm64-apple-macosx/debug"
APP_BUNDLE="$PROJECT_DIR/build/$APP_NAME.app"

echo "Building $APP_NAME..."
cd "$PROJECT_DIR"
swift build

echo "Assembling $APP_NAME.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Watchdog/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy icon
cp "$PROJECT_DIR/Watchdog/Assets.xcassets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Copy SPM resource bundle if it exists (for programmatic icon loading)
RESOURCE_BUNDLE="$BUILD_DIR/Watchdog_Watchdog.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi

echo "Done: $APP_BUNDLE"
echo ""
echo "To install to Applications:"
echo "  cp -R \"$APP_BUNDLE\" /Applications/"
