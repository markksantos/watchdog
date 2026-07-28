#!/bin/bash
# Build Watchdog.app bundle from SPM executable
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Watchdog"
APP_BUNDLE="$PROJECT_DIR/build/$APP_NAME.app"

echo "Building $APP_NAME..."
cd "$PROJECT_DIR"
swift build

# Ask SwiftPM where it put the binary rather than hardcoding a path.
#
# This used to be a literal ".build/arm64-apple-macosx/debug", which newer toolchains no
# longer write to — they emit ".build/out/Products/Debug" instead. The old directory keeps
# whatever binary was last built there, so the script went on cheerfully packaging a
# days-old executable and reporting success. Nothing failed; the .app was simply stale,
# which is a far worse failure than an error.
BUILD_DIR="$(swift build --show-bin-path)"

if [ ! -x "$BUILD_DIR/$APP_NAME" ]; then
    echo "error: no $APP_NAME binary at $BUILD_DIR — swift build --show-bin-path returned a path this script cannot use." >&2
    exit 1
fi

# The binary must be newer than the newest source file, or we are bundling something stale.
NEWEST_SOURCE="$(find "$PROJECT_DIR/Watchdog" -name '*.swift' -newer "$BUILD_DIR/$APP_NAME" -print -quit)"
if [ -n "$NEWEST_SOURCE" ]; then
    echo "error: $NEWEST_SOURCE is newer than the built binary — refusing to bundle a stale build." >&2
    exit 1
fi

echo "Assembling $APP_NAME.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Watchdog/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy icon
cp "$PROJECT_DIR/Watchdog/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Copy privacy manifest — App Store submissions require it at the top level of Resources
cp "$PROJECT_DIR/Watchdog/Resources/PrivacyInfo.xcprivacy" "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"

# Copy SPM resource bundle if it exists (for programmatic icon loading)
RESOURCE_BUNDLE="$BUILD_DIR/Watchdog_Watchdog.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi

echo "Done: $APP_BUNDLE"
echo ""
echo "To install to Applications:"
echo "  cp -R \"$APP_BUNDLE\" /Applications/"
