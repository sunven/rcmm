# Technology Stack

**Analysis Date:** 2026-04-07

## Languages

**Primary:**
- Swift - Main application, Finder Sync extension, and shared library live in `RCMMApp/`, `RCMMFinderExtension/`, and `RCMMShared/Sources/`.

**Secondary:**
- Bash - Local release packaging is scripted in `scripts/build-dev-dmg.sh`.
- YAML - CI/release automation is defined in `.github/workflows/release.yml` and release-note categories in `.github/release.yml`.
- XML property lists - App metadata and entitlements are configured in `RCMMApp/Info.plist`, `RCMMApp/rcmm.entitlements`, `RCMMFinderExtension/Info.plist`, and `RCMMFinderExtension/RCMMFinderExtension.entitlements`.

## Runtime

**Environment:**
- macOS app runtime only. `RCMMShared/Package.swift` declares `platforms: [.macOS(.v15)]`, and `rcmm.xcodeproj/project.pbxproj` sets `MACOSX_DEPLOYMENT_TARGET = 15.0` for both targets.
- The app is a menu bar app because `RCMMApp/Info.plist` sets `LSUIElement`.
- Local inspection environment reports `Xcode 26.2` and `Apple Swift 6.2.3`, while `README.md` documents `Xcode 15.4+` as the minimum supported development setup.

**Package Manager:**
- Swift Package Manager via Xcode.
  - Manifest: `RCMMShared/Package.swift`
  - Project lockfile: `rcmm.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  - Lockfile: present

## Frameworks

**Core:**
- SwiftUI - UI layer for the menu bar app in `RCMMApp/rcmmApp.swift` and `RCMMApp/Views/**`.
- AppKit - macOS-specific app/window/panel behavior in `RCMMApp/Services/ActivationPolicyManager.swift`, `RCMMApp/Services/AppDiscoveryService.swift`, and `RCMMApp/Extensions/AppInfo+Icon.swift`.
- FinderSync - Finder extension host integration in `RCMMFinderExtension/FinderSync.swift` and project linkage in `rcmm.xcodeproj/project.pbxproj`.
- Foundation - Shared models, persistence, notifications, and process launching across `RCMMShared/Sources/**`, `RCMMApp/AppState.swift`, and `RCMMFinderExtension/ScriptExecutor.swift`.
- ServiceManagement - Login item registration in `RCMMApp/Views/Settings/GeneralTab.swift` and `RCMMApp/Views/Onboarding/OnboardingFlowView.swift`.
- UniformTypeIdentifiers - `.app` filtering in `RCMMApp/Services/AppDiscoveryService.swift`.
- Carbon - Apple Event constants for AppleScript execution in `RCMMFinderExtension/ScriptExecutor.swift`.

**Testing:**
- Swift Testing (`import Testing`) - Unit tests for the shared package in `RCMMShared/Tests/RCMMSharedTests/*.swift`.

**Build/Dev:**
- Xcode project build system - Main build entry is `rcmm.xcodeproj/project.pbxproj`.
- `xcodebuild` - Build, archive, and test commands are documented in `README.md` and automated in `.github/workflows/release.yml`.
- `codesign` - Verification and ad-hoc signing are used in `.github/workflows/release.yml` and `scripts/build-dev-dmg.sh`.
- `create-dmg` - DMG packaging is used in `.github/workflows/release.yml` and `scripts/build-dev-dmg.sh`.
- `gh` CLI - GitHub prerelease publishing is used in `.github/workflows/release.yml`.
- `osacompile` - AppleScript compilation is wrapped by `RCMMApp/Services/ScriptInstallerService.swift`.

## Key Dependencies

**Critical:**
- `SettingsAccess` `2.1.0` - Remote Swift package used by the menu bar app for Settings integration in `RCMMApp/rcmmApp.swift`, `RCMMApp/Views/MenuBar/NormalPopoverView.swift`, and `RCMMApp/Views/MenuBar/ErrorBannerView.swift`.
  - Declared in `rcmm.xcodeproj/project.pbxproj`
  - Pinned in `rcmm.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `RCMMShared` local static library - Shared models/services used by both app targets.
  - Package manifest: `RCMMShared/Package.swift`
  - Consumed by `rcmm.xcodeproj/project.pbxproj`

**Infrastructure:**
- FinderSync system framework - Required for the right-click menu extension in `RCMMFinderExtension/FinderSync.swift`.
- ServiceManagement framework - Required for launch-at-login registration in `RCMMApp/Views/Settings/GeneralTab.swift`.
- `create-dmg` Homebrew CLI - Required for local and CI packaging in `README.md`, `.github/workflows/release.yml`, and `scripts/build-dev-dmg.sh`.

## Configuration

**Environment:**
- No runtime `.env` or secret file configuration was detected in the repo root.
- Shared runtime configuration is stored in App Group `UserDefaults`, keyed by constants in `RCMMShared/Sources/Constants/AppGroupConstants.swift` and `RCMMShared/Sources/Constants/SharedKeys.swift`.
- Bundle IDs and target metadata are configured in `rcmm.xcodeproj/project.pbxproj`.
  - App bundle ID: `com.sunven.rcmm`
  - Extension bundle ID: `com.sunven.rcmm.FinderExtension`
- Entitlements are split by target:
  - App group entitlement in `RCMMApp/rcmm.entitlements`
  - Sandbox + app group entitlement in `RCMMFinderExtension/RCMMFinderExtension.entitlements`

**Build:**
- Project file: `rcmm.xcodeproj/project.pbxproj`
- Shared schemes: `rcmm.xcodeproj/xcshareddata/xcschemes/rcmm.xcscheme` and `rcmm.xcodeproj/xcshareddata/xcschemes/RCMMFinderExtension.xcscheme`
- Shared package manifest: `RCMMShared/Package.swift`
- Swift package resolution lockfile: `rcmm.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- CI workflow: `.github/workflows/release.yml`
- Local packaging script: `scripts/build-dev-dmg.sh`

## Platform Requirements

**Development:**
- macOS machine with Xcode and Apple toolchain access.
- `README.md` documents `macOS 15.0+` and `Xcode 15.4+`.
- Local DMG packaging also needs Homebrew `create-dmg`, as documented in `README.md` and enforced by `scripts/build-dev-dmg.sh`.

**Production:**
- macOS desktop distribution only.
- Shipping artifact is a signed or ad-hoc-signed `.app` embedded with `RCMMFinderExtension.appex`, then packaged into a `.dmg` by `.github/workflows/release.yml` or `scripts/build-dev-dmg.sh`.

---

*Stack analysis: 2026-04-07*
