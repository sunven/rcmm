# TODOs

## Developer ID signing and notarization for release builds

**What:** Add a signed and notarized release path for the macOS app and Finder Sync extension.

**Why:** Current GitHub Releases intentionally ship an ad-hoc signed DMG, so first launch can hit Gatekeeper friction and require manual override.

**Pros:** Users get a normal macOS install and first-run experience, fewer support notes, and a distribution path suitable for public releases.

**Cons:** Requires Apple Developer Program access, Developer ID certificates, notarization credentials in CI, and maintenance of signing secrets.

**Context:** The current release workflow and README explicitly document that the DMG is not Developer ID signed or notarized. Keep the existing ad-hoc path until credentials exist, then add notarized release as the default path and retain a local unsigned build option for development.

**Depends on / blocked by:** Apple Developer account, Developer ID Application certificate, notarization credentials, and GitHub Actions secrets.
