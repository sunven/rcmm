# Coding Conventions

**Analysis Date:** 2026-04-07

## Naming Patterns

**Files:**
- Use one primary type per file, with the file name matching the type name in UpperCamelCase: `RCMMShared/Sources/Models/MenuItemConfig.swift`, `RCMMShared/Sources/Services/SharedConfigService.swift`, `RCMMApp/Views/MenuBar/ErrorBannerView.swift`.
- Use `Type+Feature.swift` for focused extensions: `RCMMApp/Extensions/AppInfo+Icon.swift`.
- Keep feature folders noun-based and target-local: `RCMMApp/Views/MenuBar/`, `RCMMApp/Views/Onboarding/`, `RCMMApp/Services/`.
- Keep the app entry file aligned to product naming even though the type is lowercased: `RCMMApp/rcmmApp.swift` defines `struct rcmmApp`.

**Functions:**
- Use lowerCamelCase verb phrases for methods and helpers: `loadMenuEntries()` in `RCMMApp/AppState.swift`, `scanApplications()` in `RCMMApp/Services/AppDiscoveryService.swift`, `buildAppleScriptCommand(template:appPath:)` in `RCMMShared/Sources/Services/CommandTemplateProcessor.swift`.
- Use boolean prefixes such as `is`, `has`, and `contains`: `isOnboardingCompleted` in `RCMMApp/AppState.swift`, `isUsingDefault` in `RCMMApp/Views/Settings/CommandEditor.swift`, `containsApp(bundleId:appPath:)` in `RCMMApp/AppState.swift`.
- Name callback parameters with `on...`: `onSave` in `RCMMApp/Views/Settings/CommandEditor.swift`, `onNext` in `RCMMApp/Views/Onboarding/EnableExtensionStepView.swift`.

**Variables:**
- Use lowerCamelCase for stored properties and locals throughout all targets: `menuEntries`, `healthCheckTimer`, `scriptsDirectory`, `selectedAppIds`.
- Prefix transient SwiftUI state with `is` or `show` where it reads as UI state: `isLoading` in `RCMMApp/Views/Onboarding/SelectAppsStepView.swift`, `showAutoRepair` in `RCMMApp/Views/MenuBar/ErrorBannerView.swift`.
- Prefer `let` for injected services and logger instances, and keep them private when they are implementation details: `private let configService = SharedConfigService()` in `RCMMApp/AppState.swift`.

**Types:**
- Use UpperCamelCase for structs, enums, and classes: `AppState`, `PluginKitService`, `MenuEntry`, `AppCategory`.
- Suffix service and manager types with their role: `AppDiscoveryService`, `ScriptInstallerService`, `ActivationPolicyManager`.
- Suffix shared state/value enums with `State` or `Status`: `PopoverState` in `RCMMShared/Sources/Models/PopoverState.swift`, `ExtensionStatus` in `RCMMShared/Sources/Models/ExtensionStatus.swift`.
- Mark cross-target value types as protocol-conforming data models: `Codable`, `Hashable`, `Identifiable`, `Sendable` in `RCMMShared/Sources/Models/AppInfo.swift` and `RCMMShared/Sources/Models/MenuItemConfig.swift`.

## Code Style

**Formatting:**
- No formatter configuration file is present in the repo root; style is established by the source files rather than by `swiftformat` or a checked-in formatter config.
- Use 4-space indentation, braces on the same line, and one declaration per line as seen in `RCMMApp/AppState.swift` and `RCMMShared/Sources/Services/SharedErrorQueue.swift`.
- Prefer multiline initializers and array literals with trailing commas when arguments span lines: `Logger(...)` in `RCMMApp/Services/AppDiscoveryService.swift`, `MenuItemConfig(...)` arrays in `RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift`.
- Use blank lines to separate property groups, lifecycle/setup, and helper sections; long files are segmented with `// MARK:` blocks, especially `RCMMApp/AppState.swift` and `RCMMApp/Views/Onboarding/SelectAppsStepView.swift`.

**Linting:**
- No checked-in lint rule set is detected; there is no `SwiftLint` or `SwiftFormat` config alongside `RCMMShared/Package.swift` or at the repo root.
- Conventions are enforced by consistency in edited files. Match surrounding style exactly instead of introducing a new import sorter, brace style, or comment style in a touched file.

## Import Organization

**Order:**
1. Apple and system frameworks first: `Foundation`, `SwiftUI`, `AppKit`, `FinderSync`, `Carbon`, `ServiceManagement`, `os.log`.
2. Third-party packages next when used: `SettingsAccess` in `RCMMApp/rcmmApp.swift` and `RCMMApp/Views/MenuBar/ErrorBannerView.swift`.
3. Local shared module imports last in most files: `RCMMShared` in `RCMMApp/AppState.swift`, `RCMMFinderExtension/FinderSync.swift`, and `RCMMApp/rcmmApp.swift`.

**Path Aliases:**
- None. Imports use module names only, such as `RCMMShared` and `SettingsAccess`; there are no alias-based imports or generated barrels.

## Error Handling

**Patterns:**
- Use `guard` for invalid preconditions and return early after logging: `RCMMFinderExtension/FinderSync.swift` rejects malformed menu titles and missing target paths this way.
- Use `try?` with safe fallbacks for non-critical persistence or UI timing paths: `RCMMShared/Sources/Services/SharedConfigService.swift` and `RCMMShared/Sources/Services/SharedErrorQueue.swift` fall back to `[]`; `RCMMApp/AppState.swift` and `RCMMApp/Views/MenuBar/ErrorBannerView.swift` use `try? await Task.sleep(...)`.
- Use `do/catch` only around filesystem and process boundaries where an error needs to be surfaced to logs: `RCMMApp/Services/ScriptInstallerService.swift` wraps directory creation, script compilation, and file deletion with `do/catch`.
- Convert system failures into `NSError` only when a callback API expects a concrete error object: `RCMMFinderExtension/ScriptExecutor.swift`.
- Prefer sentinel return values over thrown errors in shared helpers: `loadEntries()` returns `[]` in `RCMMShared/Sources/Services/SharedConfigService.swift`, `command(for:)` returns `nil` in `RCMMShared/Sources/Services/CommandMappingService.swift`, `checkHealth()` returns `.enabled` or `.disabled` in `RCMMApp/Services/PluginKitService.swift`.

## Logging

**Framework:** `Logger` from `os.log`

**Patterns:**
- Define a private logger per app or extension type, with a stable subsystem/category pair: `RCMMApp/AppState.swift`, `RCMMApp/Services/AppDiscoveryService.swift`, `RCMMApp/Services/ScriptInstallerService.swift`, `RCMMFinderExtension/FinderSync.swift`, `RCMMFinderExtension/ScriptExecutor.swift`.
- Log state changes and system boundaries at `info` or `debug`: extension health changes in `RCMMApp/AppState.swift`, application scans in `RCMMApp/Services/AppDiscoveryService.swift`, activation policy transitions in `RCMMApp/Services/ActivationPolicyManager.swift`.
- Log recoverable problems as `warning` and failed operations as `error`: missing menu config in `RCMMFinderExtension/FinderSync.swift`, script compilation failures in `RCMMApp/Services/ScriptInstallerService.swift`, script execution/load failures in `RCMMFinderExtension/ScriptExecutor.swift`.
- Keep pure shared models and pure transformation helpers free of logging: `RCMMShared/Sources/Models/*.swift` and `RCMMShared/Sources/Services/CommandTemplateProcessor.swift`.

## Comments

**When to Comment:**
- Add doc comments for service contracts, concurrency assumptions, and user-visible behavior: `RCMMApp/Services/AppDiscoveryService.swift`, `RCMMShared/Sources/Services/SharedErrorQueue.swift`, `RCMMApp/Services/ActivationPolicyManager.swift`.
- Use inline comments to explain priority order, fallback behavior, or system API constraints rather than restating code: `RCMMApp/Services/ScriptInstallerService.swift`, `RCMMFinderExtension/ScriptExecutor.swift`, `RCMMApp/AppState.swift`.
- Use `// MARK:` to split long files into focused sections. This is the standard organization pattern in `RCMMApp/AppState.swift`, `RCMMFinderExtension/FinderSync.swift`, `RCMMApp/Views/Onboarding/SelectAppsStepView.swift`, and test files such as `RCMMShared/Tests/RCMMSharedTests/CommandTemplateProcessorTests.swift`.

**JSDoc/TSDoc:**
- Not applicable. Swift doc comments (`///`) are used instead, especially in `RCMMApp/Services/ActivationPolicyManager.swift` and `RCMMShared/Sources/Services/CommandTemplateProcessor.swift`.

## Function Design

**Size:** Shared-package functions stay small and mostly pure in `RCMMShared/Sources/Models/` and `RCMMShared/Sources/Services/CommandTemplateProcessor.swift`. App orchestration files are allowed to be larger when they coordinate UI state or system APIs, such as `RCMMApp/AppState.swift` and `RCMMApp/Services/ScriptInstallerService.swift`.

**Parameters:** Inject testable dependencies where it matters, rather than introducing broad protocol abstractions. `RCMMShared/Sources/Services/SharedConfigService.swift` and `RCMMShared/Sources/Services/SharedErrorQueue.swift` accept optional `UserDefaults`. UI callbacks are closure-based and named semantically, such as `onSave` in `RCMMApp/Views/Settings/CommandEditor.swift`.

**Return Values:** Prefer plain values or optionals for queries and helpers. Shared logic returns `[MenuEntry]`, `[ErrorRecord]`, `String`, `Bool`, or optional models in `RCMMShared/Sources/Services/SharedConfigService.swift`, `RCMMShared/Sources/Services/SharedErrorQueue.swift`, and `RCMMApp/Services/AppDiscoveryService.swift`. Commands that mutate state are typically `Void`.

## Module Design

**Exports:** Keep reusable cross-target API in `RCMMShared/Sources/` and mark only those declarations `public`, as in `RCMMShared/Sources/Models/AppInfo.swift` and `RCMMShared/Sources/Services/SharedConfigService.swift`. Keep app and extension implementation types internal by default, often `final` or `private`, as in `RCMMApp/Services/ScriptInstallerService.swift` and `RCMMFinderExtension/ScriptExecutor.swift`.

**Barrel Files:** Not used. Each target imports the concrete module it needs (`RCMMShared`, `SettingsAccess`, Apple frameworks). There are no umbrella export files under `RCMMApp/`, `RCMMFinderExtension/`, or `RCMMShared/Sources/`.

---

*Convention analysis: 2026-04-07*
