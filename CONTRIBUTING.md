# Contributing

Thank you for helping improve VividBrightness.

## Before You Start

- Search existing issues before opening a new one.
- Use a bug report for reproducible behavior and a feature request for proposed changes.
- Discuss large architectural changes in an issue before implementation.
- Do not report security vulnerabilities in a public issue. Follow [SECURITY.md](SECURITY.md).

## Development Setup

VividBrightness requires macOS 13 or later and Xcode Command Line Tools.

```bash
xcode-select --install
make check
```

The project intentionally uses AppKit, MetalKit, and Objective-C without third-party dependencies. Please avoid adding a dependency when the platform SDK provides a suitable implementation.

## Tests

Every pull request should pass:

```bash
make check
```

Changes to EDR rendering, overlay lifecycle, display detection, or wake handling should also be tested on compatible hardware:

```bash
make test-edr
```

Include the Mac model, macOS version, display model, and test output in the pull request. Do not treat Gamma-table changes or visual contrast changes as proof of increased physical brightness.

## Code Style

- Use four spaces for Objective-C and shell indentation.
- Keep warnings clean under `-Wall -Wextra -Werror`.
- Prefer platform APIs and existing project patterns.
- Keep display mutations reversible and remove overlays on every shutdown path.
- Add comments only where lifecycle or compositor behavior is not self-evident.

## Pull Requests

- Keep each pull request focused on one concern.
- Explain observable behavior and verification steps.
- Update documentation when user-facing behavior changes.
- Add an entry to `CHANGELOG.md` for notable changes.
- Do not commit `.build`, signing certificates, provisioning profiles, or user-specific settings.
