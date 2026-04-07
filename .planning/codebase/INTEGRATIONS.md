# External Integrations

**Analysis Date:** 2026-04-07

## APIs & External Services

**Apple Platform Services:**
- Finder Sync extension point - Provides Finder context-menu integration for the product runtime.
  - Implementation: `RCMMFinderExtension/Info.plist` declares `com.apple.FinderSync`, and `RCMMFinderExtension/FinderSync.swift` subclasses `FIFinderSync`
  - Auth: macOS extension registration and entitlements, not repo-managed credentials
- Service Management - Registers/unregisters the main app as a login item.
  - Implementation: `RCMMApp/Views/Settings/GeneralTab.swift` and `RCMMApp/Views/Onboarding/OnboardingFlowView.swift`
  - Auth: OS-managed app entitlement and user approval flow
- AppleScript runtime - Generated `.scpt` files are compiled by the app and executed by the Finder extension.
  - Compiler path: `/usr/bin/osacompile` via `RCMMApp/Services/ScriptInstallerService.swift`
  - Executor API: `NSUserAppleScriptTask` in `RCMMFinderExtension/ScriptExecutor.swift`
  - Auth: sandboxed application-scripts access, not API credentials
- AppKit/Finder services - Discovers installed apps and renders system icons.
  - Implementation: `RCMMApp/Services/AppDiscoveryService.swift`, `RCMMApp/Extensions/AppInfo+Icon.swift`, `RCMMFinderExtension/FinderSync.swift`
  - Auth: local filesystem access only

**GitHub Services:**
- GitHub Releases - Development DMGs are published as prereleases.
  - Workflow: `.github/workflows/release.yml`
  - Client: `gh` CLI inside GitHub Actions
  - Auth: `GH_TOKEN` from `${{ github.token }}` in `.github/workflows/release.yml`
- GitHub repository metadata - Release note categories are configured in `.github/release.yml`.
- Remote source dependency hosting - `SettingsAccess` is fetched from GitHub.
  - Source: `https://github.com/orchetect/SettingsAccess`
  - Declared in `rcmm.xcodeproj/project.pbxproj`
  - Pinned in `rcmm.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

## Data Storage

**Databases:**
- None.
  - Persistent app data is stored in shared `UserDefaults`, not a database.
  - Implementation: `RCMMShared/Sources/Services/SharedConfigService.swift` and `RCMMShared/Sources/Services/SharedErrorQueue.swift`

**File Storage:**
- macOS Application Scripts directory.
  - App writes compiled scripts under `~/Library/Application Scripts/com.sunven.rcmm.FinderExtension` in `RCMMApp/Services/ScriptInstallerService.swift`
  - Extension reads scripts from `.applicationScriptsDirectory` in `RCMMFinderExtension/ScriptExecutor.swift`
- Local build artifacts only.
  - CI/local packaging outputs go to `build/` and `dist/` through `.github/workflows/release.yml` and `scripts/build-dev-dmg.sh`

**Caching:**
- None as a dedicated service.
  - GitHub Actions caches Xcode/SPM build state in `.github/workflows/release.yml`

## Authentication & Identity

**Auth Provider:**
- None for end-user accounts or external APIs.
  - Runtime identity is based on Apple bundle IDs and entitlements defined in `rcmm.xcodeproj/project.pbxproj`, `RCMMApp/rcmm.entitlements`, and `RCMMFinderExtension/RCMMFinderExtension.entitlements`

## Monitoring & Observability

**Error Tracking:**
- No external SaaS error tracker detected.
- Runtime error records are persisted locally in the shared error queue via `RCMMShared/Sources/Services/SharedErrorQueue.swift`.

**Logs:**
- Apple Unified Logging via `os.log` / `Logger`.
  - App logging examples: `RCMMApp/AppState.swift`, `RCMMApp/Services/AppDiscoveryService.swift`, `RCMMApp/Services/PluginKitService.swift`
  - Extension logging examples: `RCMMFinderExtension/FinderSync.swift`, `RCMMFinderExtension/ScriptExecutor.swift`
  - Viewing guidance is documented in `README.md`

## CI/CD & Deployment

**Hosting:**
- GitHub Releases for downloadable development DMG artifacts.
  - Release instructions: `README.md`
  - Release automation: `.github/workflows/release.yml`

**CI Pipeline:**
- GitHub Actions on `macos-latest`.
  - Trigger: push tags matching `v*-dev*`
  - Workflow file: `.github/workflows/release.yml`
  - Steps include `xcodebuild archive`, `codesign`, Homebrew `create-dmg`, checksum generation, and `gh release create`

## Environment Configuration

**Required env vars:**
- No application runtime env vars detected.
- CI requires GitHub-provided token context:
  - `GH_TOKEN` in `.github/workflows/release.yml`

**Secrets location:**
- No secrets are stored in tracked repo files.
- CI auth is injected by GitHub Actions in `.github/workflows/release.yml`.
- Local signed packaging relies on developer-local Xcode signing identities referenced operationally by `scripts/build-dev-dmg.sh`, not by checked-in secret material.

## Webhooks & Callbacks

**Incoming:**
- No runtime webhook endpoints detected.
- CI is event-driven by GitHub tag pushes in `.github/workflows/release.yml`.
- In-process callback bridge between app and extension uses Darwin notifications from `RCMMShared/Sources/Services/DarwinNotificationCenter.swift`.

**Outgoing:**
- GitHub release creation/upload from `.github/workflows/release.yml` using `gh release create` and `gh release upload`.
- No runtime outbound HTTP API calls were detected in `RCMMApp/`, `RCMMFinderExtension/`, or `RCMMShared/`.

---

*Integration audit: 2026-04-07*
