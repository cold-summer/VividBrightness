# VividBrightness

[简体中文](README.zh-CN.md)

VividBrightness is a native macOS menu bar app that increases the physical light output of compatible XDR/EDR displays. It uses a 16-bit floating-point Metal overlay and the macOS Extended Dynamic Range compositor. It does not modify the display Gamma curve.

## Features

- Continuous brightness boost from 1.0x to 2.0x
- Presets for +25%, +50%, +75%, and +100%
- Automatic detection of compatible XDR/EDR displays
- Global `Command + Shift + B` shortcut to increase the boost
- Automatic restoration after system wake
- Immediate overlay removal when the app is disabled or quit
- Menu bar operation without a Dock icon

## Requirements

- macOS 13.0 or later
- Xcode Command Line Tools
- A Metal-capable Mac
- A Liquid Retina XDR, Pro Display XDR, or another display that exposes EDR headroom to macOS

Standard SDR displays are detected but are not modified.

## Download and Install

Download the Apple Silicon `.dmg` from the [latest GitHub Release](https://github.com/cold-summer/vividBrightness/releases/latest), open it, and drag `VividBrightness.app` to Applications.

The current binary is ad-hoc signed and is not Apple-notarized. After copying the app, run this once in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/VividBrightness.app
open /Applications/VividBrightness.app
```

The `.zip` release asset is also available as a fallback. Verify either download with its accompanying `.sha256` file using `shasum -a 256 -c <filename>.sha256`.

## Build

```bash
cd VividBrightness
make check
make build
open .build/VividBrightness.app
```

`make check` is safe to run on a GitHub-hosted macOS runner. It validates shell scripts and the property list, builds and signs the app ad hoc, and compiles the EDR diagnostic probe.

Build metadata can be overridden without editing tracked files:

```bash
BUNDLE_IDENTIFIER=io.github.example.VividBrightness \
MARKETING_VERSION=1.0.0 \
BUILD_NUMBER=1 \
SIGN_IDENTITY="Developer ID Application: Example" \
make build
```

## Hardware Test

The real EDR integration test must run on an unlocked Mac connected to a compatible XDR/EDR display:

```bash
make test-edr
```

The test creates the same Metal overlay used by the app, confirms that frames are rendered, and requires macOS to report EDR headroom greater than `1.05`.

To inspect the current and potential EDR values without enabling the overlay:

```bash
make diagnose
```

## How It Works

VividBrightness renders an extended-linear Display P3 Metal surface with `RGBA16Float` pixels and opts the layer into EDR. A click-through full-screen window applies that surface with multiply compositing, allowing pixel values above SDR white to use brightness headroom managed by macOS.

See [Architecture](docs/ARCHITECTURE.md) for implementation details and system constraints.

## Limitations and Safety

- macOS may reduce EDR headroom while the screen is locked, on battery power, or under thermal pressure.
- Sustained high brightness increases power consumption and display temperature.
- The reported EDR headroom is system capacity, not the selected brightness multiplier.
- Long sessions should use conservative boost levels such as +25% or +50%.
- The global shortcut may require Input Monitoring permission on some macOS configurations; menu bar controls do not.

## Privacy

VividBrightness makes no network requests and includes no analytics or telemetry. It stores only the selected boost level in macOS user defaults.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Security issues should follow [SECURITY.md](SECURITY.md), not the public issue tracker.

## License

VividBrightness is available under the [MIT License](LICENSE).
