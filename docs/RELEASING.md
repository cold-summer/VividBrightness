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

The default build uses an ad hoc signature for local development. Public binaries should use a Developer ID certificate and should be notarized with Apple's `notarytool` before distribution.

## Publish

1. Verify the signed and notarized artifact on a clean Mac.
2. Tag the commit using the version prefixed with `v`, for example `v1.0.0`.
3. Create a GitHub Release from the tag.
4. Attach the notarized archive and publish release notes from `CHANGELOG.md`.

Never commit certificates, private keys, notarization credentials, or provisioning profiles.
