# Architecture

## Overview

VividBrightness is a dependency-free AppKit menu bar application. The production path consists of two components:

- `main.m` owns the application lifecycle, menu bar item, controls, keyboard shortcut, and wake notifications.
- `EDRBrightnessManager` owns display discovery, Metal surfaces, overlay windows, rendering, and cleanup.

## EDR Rendering Pipeline

For each screen whose `maximumPotentialExtendedDynamicRangeColorComponentValue` is greater than `1.05`, the manager creates a borderless, click-through window and an `MTKView` configured with:

- `MTLPixelFormatRGBA16Float`
- `kCGColorSpaceExtendedLinearDisplayP3`
- `CAMetalLayer.wantsExtendedDynamicRangeContent = YES`

The Metal clear color uses the selected multiplier for all RGB components. The overlay content view applies `multiplyBlendMode`, so underlying desktop pixels are multiplied while black remains black. Values above `1.0` can enter the EDR region instead of being limited to SDR white.

macOS remains responsible for mapping those values to physical luminance. Battery state, screen temperature, system brightness, and active content can all reduce available headroom.

## Overlay Lifecycle

Overlay windows ignore mouse events, join all Spaces, and are kept above ordinary application windows. Existing windows are reused when the boost changes. A low-frequency watchdog requests fresh Metal frames and refreshes status without rebuilding the windows.

Screen-parameter notifications only refresh reported EDR state while enhancement is active. Rebuilding on every such notification causes a compositor feedback loop because EDR activation itself may emit a screen-parameter notification.

Overlays are rebuilt after system wake and are always removed when enhancement is disabled or the application terminates.

## Testing Strategy

`make check` performs deterministic checks suitable for continuous integration:

- Shell syntax validation
- Property-list validation
- Warning-clean application build
- Ad hoc code-sign verification
- Diagnostic probe compilation

`make test-edr` is a hardware integration test. It requires an unlocked interactive macOS session and an XDR/EDR display, so it is intentionally excluded from GitHub Actions.

## Non-Goals

- Modifying display Gamma tables
- Bypassing macOS thermal or luminance limits
- Applying enhancement to displays that do not expose EDR support
- Persisting an enabled overlay across application termination
