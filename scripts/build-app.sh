#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$PROJECT_DIR/.build}"
APP_DIR="$BUILD_DIR/VividBrightness.app"
CONTENTS_DIR="$APP_DIR/Contents"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.vividbrightness.VividBrightness}"
MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

cd "$PROJECT_DIR"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"

clang \
    -fobjc-arc \
    -fmodules \
    -O2 \
    -Wall \
    -Wextra \
    -Werror \
    -framework AppKit \
    -framework MetalKit \
    -framework QuartzCore \
    "$PROJECT_DIR/Sources/VividBrightness/EDRBrightnessManager.m" \
    "$PROJECT_DIR/Sources/VividBrightness/main.m" \
    -I "$PROJECT_DIR/Sources/VividBrightness" \
    -o "$CONTENTS_DIR/MacOS/VividBrightness"

cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING_VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"
chmod +x "$CONTENTS_DIR/MacOS/VividBrightness"

codesign --force --sign "$SIGN_IDENTITY" "$APP_DIR"
echo "$APP_DIR"
