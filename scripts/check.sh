#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$PROJECT_DIR/.build}"
PROBE_BINARY="$BUILD_DIR/native/edr-probe"

for script in "$PROJECT_DIR"/scripts/*.sh; do
    bash -n "$script"
done

plutil -lint "$PROJECT_DIR/Resources/Info.plist"
"$PROJECT_DIR/scripts/build-app.sh"
codesign --verify --deep --strict "$BUILD_DIR/VividBrightness.app"

mkdir -p "$BUILD_DIR/native"
clang \
    -fobjc-arc \
    -fmodules \
    -Wall \
    -Wextra \
    -Werror \
    -framework AppKit \
    "$PROJECT_DIR/Tools/EDRProbe.m" \
    -o "$PROBE_BINARY"

echo "All build checks passed."
