# Codebase Structure

**Analysis Date:** 2026-04-07

## Directory Layout

```text
rcmm/
├── RCMMApp/                  # Menu bar app target: app state, SwiftUI views, app-only services
├── RCMMFinderExtension/      # Finder Sync extension target
├── RCMMShared/               # Local Swift package with shared constants, models, services, and tests
├── rcmm.xcodeproj/           # Xcode project wiring targets, settings, and embedding
├── .github/workflows/        # Release automation
├── scripts/                  # Local build and asset helper scripts
├── docs/plans/               # Design and implementation notes
├── .planning/codebase/       # Generated codebase mapping docs
├── DerivedData/              # Local Xcode build output
├── build/                    # Local build/archive output
└── dist/                     # Generated DMG output
```

## Directory Purposes

**`RCMMApp/`:**
- Purpose: Hold all source for the main menu bar app target.
- Contains: `RCMMApp/rcmmApp.swift`, `RCMMApp/AppState.swift`, app-only services in `RCMMApp/Services/`, and SwiftUI surfaces in `RCMMApp/Views/`.
- Key files: `RCMMApp/rcmmApp.swift`, `RCMMApp/AppState.swift`, `RCMMApp/Services/ScriptInstallerService.swift`, `RCMMApp/Views/Settings/MenuConfigTab.swift`

**`RCMMApp/Views/MenuBar/`:**
- Purpose: Hold the menu bar popover and health/error surfaces.
- Contains: Status icon, popover routing, recovery, and banner views.
- Key files: `RCMMApp/Views/MenuBar/PopoverContainerView.swift`, `RCMMApp/Views/MenuBar/NormalPopoverView.swift`, `RCMMApp/Views/MenuBar/ErrorBannerView.swift`

**`RCMMApp/Views/Settings/`:**
- Purpose: Hold the Settings window tabs and rows for menu editing.
- Contains: `TabView` tabs, list rows, the command editor, and the app-picking sheet.
- Key files: `RCMMApp/Views/Settings/SettingsView.swift`, `RCMMApp/Views/Settings/MenuConfigTab.swift`, `RCMMApp/Views/Settings/AppSelectionSheet.swift`, `RCMMApp/Views/Settings/GeneralTab.swift`

**`RCMMApp/Views/Onboarding/`:**
- Purpose: Hold the first-run flow shown in a dedicated `NSWindow`.
- Contains: Step shell plus one file per onboarding step.
- Key files: `RCMMApp/Views/Onboarding/OnboardingFlowView.swift`, `RCMMApp/Views/Onboarding/EnableExtensionStepView.swift`, `RCMMApp/Views/Onboarding/SelectAppsStepView.swift`, `RCMMApp/Views/Onboarding/VerifyStepView.swift`

**`RCMMApp/Services/`:**
- Purpose: Hold app-process integrations that should not live in views or the shared package.
- Contains: Finder extension health checks, app discovery, activation-policy handling, and AppleScript compilation.
- Key files: `RCMMApp/Services/AppDiscoveryService.swift`, `RCMMApp/Services/PluginKitService.swift`, `RCMMApp/Services/ActivationPolicyManager.swift`, `RCMMApp/Services/ScriptInstallerService.swift`

**`RCMMFinderExtension/`:**
- Purpose: Hold the Finder Sync extension target.
- Contains: The `FIFinderSync` subclass, script execution helper, Info.plist, and entitlements.
- Key files: `RCMMFinderExtension/FinderSync.swift`, `RCMMFinderExtension/ScriptExecutor.swift`, `RCMMFinderExtension/Info.plist`

**`RCMMShared/Sources/`:**
- Purpose: Hold code that both targets can import without UI framework dependencies.
- Contains: Constants, models, and services grouped by concern.
- Key files: `RCMMShared/Sources/Constants/AppGroupConstants.swift`, `RCMMShared/Sources/Models/MenuEntry.swift`, `RCMMShared/Sources/Services/SharedConfigService.swift`, `RCMMShared/Sources/Services/DarwinNotificationCenter.swift`

**`RCMMShared/Tests/RCMMSharedTests/`:**
- Purpose: Hold package tests for shared logic.
- Contains: One test file per shared model or service.
- Key files: `RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift`, `RCMMShared/Tests/RCMMSharedTests/CommandTemplateProcessorTests.swift`

**`rcmm.xcodeproj/`:**
- Purpose: Hold target wiring that cannot live inside the Swift package.
- Contains: The project file, workspace metadata, scheme and target configuration, and embedding rules for the extension.
- Key files: `rcmm.xcodeproj/project.pbxproj`

**`.github/workflows/`:**
- Purpose: Hold CI/CD automation.
- Contains: Tag-triggered release workflow only.
- Key files: `.github/workflows/release.yml`

**`scripts/`:**
- Purpose: Hold local utility scripts that support packaging and assets.
- Contains: Shell and Swift scripts.
- Key files: `scripts/build-dev-dmg.sh`, `scripts/generate-app-icon.swift`

**`docs/plans/`:**
- Purpose: Hold design and implementation notes outside the executable codebase.
- Contains: Dated Markdown documents describing planned or completed changes.
- Key files: `docs/plans/2026-03-11-github-actions-implementation.md`, `docs/plans/2026-03-16-unified-menu-sorting-plan.md`

## Key File Locations

**Entry Points:**
- `RCMMApp/rcmmApp.swift`: `@main` SwiftUI app entry point for the menu bar app.
- `RCMMFinderExtension/FinderSync.swift`: Finder Sync runtime entry point.
- `RCMMShared/Package.swift`: Local package manifest for the shared library and tests.
- `.github/workflows/release.yml`: Automated build-and-release entry point for tagged dev builds.

**Configuration:**
- `rcmm.xcodeproj/project.pbxproj`: Target composition, package linkage, and build settings.
- `RCMMApp/Info.plist`: Main app bundle metadata.
- `RCMMFinderExtension/Info.plist`: Extension bundle metadata.
- `RCMMApp/rcmm.entitlements`: Main app entitlements, including shared capabilities.
- `RCMMFinderExtension/RCMMFinderExtension.entitlements`: Extension entitlements and sandbox capabilities.
- `.gitignore`: Generated-output exclusions for `DerivedData/`, `.build/`, `build/`, `.worktrees/`, and `dist/`.

**Core Logic:**
- `RCMMApp/AppState.swift`: Main orchestration and side-effect hub.
- `RCMMApp/Services/ScriptInstallerService.swift`: AppleScript lifecycle management.
- `RCMMFinderExtension/ScriptExecutor.swift`: Extension-side script invocation.
- `RCMMShared/Sources/Services/SharedConfigService.swift`: Shared menu persistence.
- `RCMMShared/Sources/Services/SharedErrorQueue.swift`: Shared error transport.
- `RCMMShared/Sources/Services/DarwinNotificationCenter.swift`: Cross-process invalidation primitive.

**Testing:**
- `RCMMShared/Tests/RCMMSharedTests/`: Package test root.
- `RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift`: Persistence behavior tests.
- `RCMMShared/Tests/RCMMSharedTests/CommandMappingServiceTests.swift`: Built-in command mapping tests.
- `RCMMShared/Tests/RCMMSharedTests/MenuEntryTests.swift`: Shared model behavior tests.

## Naming Conventions

**Files:**
- Use one primary type per file with UpperCamelCase filenames, for example `RCMMApp/Services/PluginKitService.swift` and `RCMMShared/Sources/Models/MenuItemConfig.swift`.
- Use suffix-based names that state the role directly: `*Service.swift`, `*View.swift`, `*Row.swift`, `*Panel.swift`, `*Tests.swift`.
- Use extension-style filenames only for narrow augmentations, as in `RCMMApp/Extensions/AppInfo+Icon.swift`.
- Keep the app entry file as `RCMMApp/rcmmApp.swift`; it is the one intentional lower-camel exception in the source tree.

**Directories:**
- Group by target first: `RCMMApp/`, `RCMMFinderExtension/`, `RCMMShared/`.
- Inside the app target, group by technical role and UI surface: `RCMMApp/Services/`, `RCMMApp/Views/MenuBar/`, `RCMMApp/Views/Settings/`, `RCMMApp/Views/Onboarding/`.
- Inside the shared package, group by domain role: `RCMMShared/Sources/Constants/`, `RCMMShared/Sources/Models/`, `RCMMShared/Sources/Services/`.

## Where to Add New Code

**New Feature:**
- Primary code: Put menu bar app behavior in `RCMMApp/` and keep the surface split aligned with the existing folders.
- Tests: If the logic is shareable or pure, put it in `RCMMShared/Sources/` and add tests in `RCMMShared/Tests/RCMMSharedTests/`.

**New App UI Component:**
- Implementation: Add menu bar views under `RCMMApp/Views/MenuBar/`, settings views under `RCMMApp/Views/Settings/`, and onboarding steps under `RCMMApp/Views/Onboarding/`.

**New App-Only Integration:**
- Implementation: Add the integration in `RCMMApp/Services/` when it touches AppKit, ServiceManagement, FinderSync APIs, filesystem compilation, or other app-process-only capabilities.

**New Finder Extension Behavior:**
- Implementation: Keep Finder-specific code inside `RCMMFinderExtension/`. Route shared policy or value types into `RCMMShared/` instead of duplicating them in the extension target.

**Utilities:**
- Shared helpers: Add cross-process constants, models, and Foundation-only services to `RCMMShared/Sources/`.
- App-only helper extensions: Add small target-local extensions under `RCMMApp/Extensions/`.

## Special Directories

**`.planning/codebase/`:**
- Purpose: Generated reference docs for GSD planning and execution commands.
- Generated: Yes
- Committed: Yes

**`docs/plans/`:**
- Purpose: Human-authored design and implementation notes.
- Generated: No
- Committed: Yes

**`RCMMShared/.build/`:**
- Purpose: Swift Package Manager build cache and intermediate output.
- Generated: Yes
- Committed: No

**`DerivedData/`:**
- Purpose: Xcode derived data, indexes, and build products.
- Generated: Yes
- Committed: No

**`build/`:**
- Purpose: Local archive, signing, and packaging output used by release scripts and workflows.
- Generated: Yes
- Committed: No

**`dist/`:**
- Purpose: Final DMG artifacts created by `scripts/build-dev-dmg.sh`.
- Generated: Yes
- Committed: No

**`.worktrees/`:**
- Purpose: Local GSD worktree management area.
- Generated: Yes
- Committed: No

## Placement Guidance

Use `RCMMShared/` for anything that must be understood identically by the app and the extension: menu schemas, notification names, shared storage keys, and Foundation-only helpers. Use `RCMMApp/` for orchestration, onboarding, settings, and any work that requires unsandboxed capabilities such as compiling AppleScripts or opening system UI. Use `RCMMFinderExtension/` only for Finder entry-point logic and execution adapters that have to run inside the extension sandbox.

Do not add new product code under `build/`, `DerivedData/`, `dist/`, or `RCMMShared/.build/`. Those directories exist in the working tree as generated output, but `.gitignore` marks them as non-source locations.

---

*Structure analysis: 2026-04-07*
