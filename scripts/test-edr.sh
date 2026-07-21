#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_BINARY="$PROJECT_DIR/.build/native/edr-manager-probe"

mkdir -p "$PROJECT_DIR/.build/native"

clang \
    -fobjc-arc \
    -fmodules \
    -Wall \
    -Wextra \
    -Werror \
    -framework AppKit \
    -framework MetalKit \
    -framework QuartzCore \
    "$PROJECT_DIR/Sources/VividBrightness/EDRBrightnessManager.m" \
    "$PROJECT_DIR/Tests/Integration/EDRManagerProbe.m" \
    -I "$PROJECT_DIR/Sources/VividBrightness" \
    -o "$TEST_BINARY"

"$TEST_BINARY"
