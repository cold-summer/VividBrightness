# Releasing

## Prepare

1. Update `CHANGELOG.md` and the version in `Resources/Info.plist`.
2. Run `make check`.
3. Run `make test-edr` on supported hardware.
4. Review the app with both enhancement enabled and disabled.

## Build a Signed App

```bash
MARKETING_VERSION=1.0.0 \
BUILD_NUMBER=1 \
BUNDLE_IDENTIFIER=io.github.example.VividBrightness \
SIGN_IDENTITY="Developer ID Application: Example" \
make build
```

The default build uses an ad hoc signature for local development. Public binaries should ideally use a Developer ID certificate and be notarized with Apple's `notarytool`. When no Developer ID is available, clearly identify the artifact as ad-hoc signed and not notarized.

## Package the DMG

```bash
MARKETING_VERSION=1.0.0 PACKAGE_ARCH=arm64 make dmg
(cd .build/release && \
  shasum -a 256 VividBrightness-v1.0.0-macOS-arm64.dmg \
    > VividBrightness-v1.0.0-macOS-arm64.dmg.sha256)
hdiutil verify .build/release/VividBrightness-v1.0.0-macOS-arm64.dmg
```

The disk image contains the app, an Applications symlink, and bilingual first-run instructions. `make dmg` ad-hoc signs the disk image; this does not replace Developer ID signing or notarization.

## Publish

1. Mount and verify the artifact on a clean Mac, including the signature of the app inside it.
2. Tag the commit using the version prefixed with `v`, for example `v1.0.0`.
3. Create a GitHub Release from the tag.
4. Attach the DMG and its SHA-256 file, and keep a ZIP fallback when useful.
5. State the signing and notarization status accurately in the release notes. Ad-hoc signed downloads require users to remove the quarantine attribute once after installation.

Never commit certificates, private keys, notarization credentials, or provisioning profiles.
