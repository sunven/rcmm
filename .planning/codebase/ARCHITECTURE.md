# Architecture

**Analysis Date:** 2026-04-07

## Pattern Overview

**Overall:** Multi-target macOS desktop application with a process-local UI app, a sandboxed Finder Sync extension, and a shared Swift package that acts as the domain and IPC contract.

**Key Characteristics:**
- Keep all cross-process types, constants, and persistence helpers in `RCMMShared/Sources/` so both `RCMMApp/` and `RCMMFinderExtension/` import the same contract.
- Treat `RCMMApp/` as the orchestration process: it owns authoring, onboarding, script compilation, extension health checks, and recovery UI.
- Treat `RCMMFinderExtension/` as a thin execution adapter: it rebuilds menus from shared state on demand and delegates script execution to `RCMMFinderExtension/ScriptExecutor.swift`.

## Layers

**Project Configuration Layer:**
- Purpose: Define targets, embedding, entitlements, release automation, and package composition.
- Location: `rcmm.xcodeproj/project.pbxproj`, `RCMMApp/Info.plist`, `RCMMFinderExtension/Info.plist`, `RCMMApp/rcmm.entitlements`, `RCMMFinderExtension/RCMMFinderExtension.entitlements`, `RCMMShared/Package.swift`, `.github/workflows/release.yml`
- Contains: Xcode targets, the embedded extension relationship, app metadata, App Group capability wiring, SPM package definition, and CI packaging steps.
- Depends on: Xcode build settings, local Swift package reference `RCMMShared/`, and GitHub Actions.
- Used by: Local Xcode builds, `xcodebuild`, and release packaging.

**Shared Domain Layer:**
- Purpose: Provide the stable model and storage contract shared between the main app and the Finder extension.
- Location: `RCMMShared/Sources/Constants/`, `RCMMShared/Sources/Models/`, `RCMMShared/Sources/Services/`
- Contains: Shared constants like `AppGroupConstants.appGroupID` in `RCMMShared/Sources/Constants/AppGroupConstants.swift`, menu models like `MenuEntry` in `RCMMShared/Sources/Models/MenuEntry.swift`, and shared persistence/IPC helpers like `SharedConfigService` in `RCMMShared/Sources/Services/SharedConfigService.swift`.
- Depends on: `Foundation` only, per `RCMMShared/Package.swift`.
- Used by: `RCMMApp/AppState.swift`, app services under `RCMMApp/Services/`, and extension files `RCMMFinderExtension/FinderSync.swift` and `RCMMFinderExtension/ScriptExecutor.swift`.

**App Process Layer:**
- Purpose: Run the menu bar app, manage UI state, author menu configuration, compile scripts, and repair broken runtime state.
- Location: `RCMMApp/`
- Contains: `@main` app entry in `RCMMApp/rcmmApp.swift`, central state in `RCMMApp/AppState.swift`, services in `RCMMApp/Services/`, SwiftUI views in `RCMMApp/Views/`, and small app-only extensions in `RCMMApp/Extensions/`.
- Depends on: `RCMMShared`, `SwiftUI`, `AppKit`, `ServiceManagement`, `FinderSync`, and `os.log`.
- Used by: End users configuring rcmm through the menu bar popover, Settings window, and onboarding flow.

**Extension Process Layer:**
- Purpose: Translate persisted configuration into Finder context menu items and execute the selected action in the extension sandbox.
- Location: `RCMMFinderExtension/`
- Contains: Finder Sync entry point in `RCMMFinderExtension/FinderSync.swift` and AppleScript task runner in `RCMMFinderExtension/ScriptExecutor.swift`.
- Depends on: `FinderSync`, `Cocoa`, `Carbon`, `RCMMShared`, and `os.log`.
- Used by: Finder when the user right-clicks a file system target.

**UI Surface Layer:**
- Purpose: Split app-facing UX by surface so routing stays shallow and file placement is obvious.
- Location: `RCMMApp/Views/MenuBar/`, `RCMMApp/Views/Settings/`, `RCMMApp/Views/Onboarding/`
- Contains: Popover UI such as `RCMMApp/Views/MenuBar/PopoverContainerView.swift`, settings tabs such as `RCMMApp/Views/Settings/MenuConfigTab.swift`, and onboarding steps such as `RCMMApp/Views/Onboarding/OnboardingFlowView.swift`.
- Depends on: `AppState` from `RCMMApp/AppState.swift` and shared models from `RCMMShared`.
- Used by: `RCMMApp/rcmmApp.swift` scenes and `RCMMApp/AppState.swift` when showing onboarding in a separate `NSWindow`.

## Data Flow

**Configuration Authoring Flow:**

1. `RCMMApp/rcmmApp.swift` injects a single `AppState` instance into `PopoverContainerView` and `SettingsView`.
2. Settings and onboarding views such as `RCMMApp/Views/Settings/MenuConfigTab.swift` and `RCMMApp/Views/Onboarding/OnboardingFlowView.swift` call mutation methods on `RCMMApp/AppState.swift`.
3. `AppState.saveAndSync()` persists `[MenuEntry]` through `RCMMShared/Sources/Services/SharedConfigService.swift`.
4. `AppState.syncScriptsInBackground()` dispatches work to the serial queue in `RCMMApp/AppState.swift`, then `RCMMApp/Services/ScriptInstallerService.swift` recompiles `.scpt` files for every custom menu item.
5. After script sync, `RCMMShared/Sources/Services/DarwinNotificationCenter.swift` posts `NotificationNames.configChanged` so the extension process refreshes on the next invocation.

**Finder Menu Execution Flow:**

1. Finder instantiates `RCMMFinderExtension/FinderSync.swift`.
2. `menu(for:)` loads entries through `RCMMShared/Sources/Services/SharedConfigService.swift` and filters disabled items using `MenuEntry.isEnabled` from `RCMMShared/Sources/Models/MenuEntry.swift`.
3. Built-in actions map directly to selectors in `RCMMFinderExtension/FinderSync.swift`; custom actions serialize the target script id via `NSMenuItem.representedObject`.
4. `openWithApp(_:)` resolves the clicked target path and calls `RCMMFinderExtension/ScriptExecutor.swift`.
5. `ScriptExecutor.execute(...)` loads the corresponding `.scpt` file from the Application Scripts directory, builds an Apple Event, and runs `NSUserAppleScriptTask`.

**Error and Recovery Flow:**

1. Extension-side failures in `RCMMFinderExtension/ScriptExecutor.swift` append `ErrorRecord` values through `RCMMShared/Sources/Services/SharedErrorQueue.swift`.
2. Popover presentation in `RCMMApp/Views/MenuBar/PopoverContainerView.swift` triggers `AppState.loadErrors()`.
3. `RCMMApp/AppState.swift` reads the shared queue, exposes `errorRecords` to `RCMMApp/Views/MenuBar/ErrorBannerView.swift`, and auto-repairs missing script-file failures by re-running `ScriptInstallerService.syncScripts(with:)`.
4. The repaired state is written back to shared storage and broadcast again via Darwin notification.

**State Management:**
- Use one process-local observable object, `AppState` in `RCMMApp/AppState.swift`, for app UI state.
- Use SwiftUI-local `@State` only for view-scoped interaction state such as disclosure expansion in `RCMMApp/Views/Settings/MenuConfigTab.swift` or step selection in `RCMMApp/Views/Onboarding/OnboardingFlowView.swift`.
- Use App Group `UserDefaults` for cross-process persistence via `RCMMShared/Sources/Services/SharedConfigService.swift` and `RCMMShared/Sources/Services/SharedErrorQueue.swift`.
- Use Darwin notifications from `RCMMShared/Sources/Services/DarwinNotificationCenter.swift` for cross-process invalidation, not for payload transport.

## Key Abstractions

**Menu Configuration Contract:**
- Purpose: Represent everything that can appear in the Finder context menu.
- Examples: `RCMMShared/Sources/Models/MenuEntry.swift`, `RCMMShared/Sources/Models/MenuItemConfig.swift`, `RCMMShared/Sources/Models/BuiltInMenuItem.swift`
- Pattern: Model custom and built-in entries as enum-backed value types, then persist the whole ordered array.

**Shared Persistence Services:**
- Purpose: Hide raw `UserDefaults` and JSON coding details behind stable helpers.
- Examples: `RCMMShared/Sources/Services/SharedConfigService.swift`, `RCMMShared/Sources/Services/SharedErrorQueue.swift`
- Pattern: Keep persistence logic in `RCMMShared` whenever both processes need the same storage key or schema.

**Process Bridge:**
- Purpose: Signal that shared configuration changed without creating a direct dependency between processes.
- Examples: `RCMMShared/Sources/Services/DarwinNotificationCenter.swift`, `RCMMShared/Sources/Constants/NotificationNames.swift`
- Pattern: Persist first, then post a lightweight Darwin notification keyed by constants from `RCMMShared/Sources/Constants/`.

**Script Lifecycle Manager:**
- Purpose: Convert menu configuration into executable AppleScript files that the extension can load inside its sandbox.
- Examples: `RCMMApp/Services/ScriptInstallerService.swift`, `RCMMShared/Sources/Services/CommandTemplateProcessor.swift`, `RCMMShared/Sources/Services/CommandMappingService.swift`
- Pattern: Compile scripts only in the main app process, store them under the extension bundle id, and reference them by `MenuItemConfig.id`.

**UI State Coordinator:**
- Purpose: Centralize app-facing orchestration instead of scattering persistence and process-control code through views.
- Examples: `RCMMApp/AppState.swift`
- Pattern: Keep mutation methods and side effects on the `@MainActor` state object; views call intent methods instead of touching shared services directly.

## Entry Points

**Menu Bar App Entry Point:**
- Location: `RCMMApp/rcmmApp.swift`
- Triggers: Launching the app or opening the built app bundle.
- Responsibilities: Create the single `AppState`, expose `MenuBarExtra`, and host `SettingsView`.

**Finder Extension Entry Point:**
- Location: `RCMMFinderExtension/FinderSync.swift`
- Triggers: Finder loading the extension and requesting a context menu.
- Responsibilities: Register for config-change notifications, rebuild menu items, resolve target paths, and route execution.

**Shared Package Entry Point:**
- Location: `RCMMShared/Package.swift`
- Triggers: Xcode resolving the local Swift package dependency and building the shared target plus tests.
- Responsibilities: Define the `RCMMShared` static library and the `RCMMSharedTests` target.

**Release Automation Entry Point:**
- Location: `.github/workflows/release.yml`
- Triggers: Pushing a tag matching `v*-dev*`.
- Responsibilities: Build the `rcmm` scheme, extract and ad-hoc sign the app bundle, package a DMG, and publish a GitHub prerelease.

## Error Handling

**Strategy:** Fail soft at process edges, log through `Logger`, and surface only user-actionable issues back to the menu bar app.

**Patterns:**
- Return empty collections on shared-state decode failure in `RCMMShared/Sources/Services/SharedConfigService.swift` instead of crashing the extension.
- Record extension runtime failures into the shared queue in `RCMMFinderExtension/ScriptExecutor.swift` so the UI process can show them later.
- Guard platform interactions with early returns and logs in files such as `RCMMFinderExtension/FinderSync.swift`, `RCMMApp/Services/AppDiscoveryService.swift`, and `RCMMApp/Services/ScriptInstallerService.swift`.
- Keep compile and filesystem work outside the extension process; the extension only loads precompiled scripts.

## Cross-Cutting Concerns

**Logging:** Use `Logger` from `os.log` in app services, app state, onboarding, and extension runtime files such as `RCMMApp/AppState.swift`, `RCMMApp/Services/AppDiscoveryService.swift`, and `RCMMFinderExtension/FinderSync.swift`.

**Validation:** Validate external state at the edge: app existence in `RCMMApp/Services/ScriptInstallerService.swift`, selected path resolution in `RCMMFinderExtension/FinderSync.swift`, and login-item operations in `RCMMApp/Views/Settings/GeneralTab.swift`.

**Authentication:** Not applicable. The architecture relies on macOS entitlements and App Group access rather than user-facing auth.

---

*Architecture analysis: 2026-04-07*
