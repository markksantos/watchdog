#!/bin/bash
# Regenerate Watchdog.xcodeproj from project.yml.
#
# The project file is generated, not checked in, so the source of truth is project.yml and
# there are no pbxproj merge conflicts. Signing settings live in AppSupport/Signing.xcconfig
# and survive regeneration.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen not found. Install it with:  brew install xcodegen" >&2
    exit 1
fi

xcodegen generate --spec project.yml

echo
echo "Generated Watchdog.xcodeproj"
echo "  open Watchdog.xcodeproj        # then set your team in AppSupport/Signing.xcconfig"
echo "  scripts/archive-appstore.sh    # build + export a Mac App Store .pkg"
