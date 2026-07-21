#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$PROJECT_DIR/.build}"
APP_DIR="$BUILD_DIR/VividBrightness.app"
RELEASE_DIR="$BUILD_DIR/release"
STAGING_DIR="$BUILD_DIR/dmg-staging"
PACKAGE_ARCH="${PACKAGE_ARCH:-$(uname -m)}"

if [[ ! -d "$APP_DIR" ]]; then
    echo "App bundle not found at $APP_DIR. Run make build first." >&2
    exit 1
fi

VERSION="${MARKETING_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")}"
DMG_PATH="$RELEASE_DIR/VividBrightness-v${VERSION}-macOS-${PACKAGE_ARCH}.dmg"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$RELEASE_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/VividBrightness.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$PROJECT_DIR/Resources/DMG-README.txt" "$STAGING_DIR/README-First-Run.txt"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "VividBrightness ${VERSION}" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH"

# A detached disk image can also carry an ad hoc signature. This is not notarization.
codesign --force --sign - "$DMG_PATH"
rm -rf "$STAGING_DIR"

echo "$DMG_PATH"
