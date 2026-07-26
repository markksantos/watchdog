#!/bin/bash
# Build, archive, and export Watchdog for Mac App Store submission.
#
# Prerequisites (one-time):
#   1. brew install xcodegen
#   2. Apple Developer Program membership, and the App ID com.markstudios.watchdog
#      registered on your team.
#   3. Your Team ID filled into AppSupport/Signing.xcconfig.
#   4. Xcode signed in to that Apple ID (Xcode -> Settings -> Accounts), so automatic
#      signing can mint the "Apple Distribution" cert and the Mac App Store profile.
#
# Output: build/export/Watchdog.pkg — upload with Transporter, or:
#   xcrun altool --upload-app -f build/export/Watchdog.pkg -t macos \
#       --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
set -euo pipefail

cd "$(dirname "$0")/.."

ARCHIVE_PATH="build/Watchdog.xcarchive"
EXPORT_PATH="build/export"

TEAM_ID="$(sed -n 's/^DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*//p' AppSupport/Signing.xcconfig | tr -d '[:space:]')"
if [ -z "$TEAM_ID" ]; then
    echo "error: DEVELOPMENT_TEAM is empty in AppSupport/Signing.xcconfig." >&2
    echo "       Set it to your 10-character Apple Developer Team ID and re-run." >&2
    exit 1
fi

echo "==> Regenerating Xcode project"
scripts/generate-xcodeproj.sh >/dev/null

echo "==> Archiving (Release, team $TEAM_ID)"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
xcodebuild archive \
    -project Watchdog.xcodeproj \
    -scheme Watchdog \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates

echo "==> Exporting for the Mac App Store"
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist build/ExportOptions.plist \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates

echo
echo "==> Verifying the exported bundle"
APP="$ARCHIVE_PATH/Products/Applications/Watchdog.app"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "--- entitlements ---"
codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -p - -
echo
ls -la "$EXPORT_PATH"
echo
echo "Done. Upload $EXPORT_PATH/Watchdog.pkg via Transporter.app or altool."
