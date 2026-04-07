# Codebase Concerns

**Analysis Date:** 2026-04-07

## Tech Debt

**Shared config persistence silently treats corruption as first launch:**
- Issue: `SharedConfigService.loadEntries()` returns `[]` for any decode failure, and `AppState.loadMenuEntries()` treats an empty array as a fresh install and immediately seeds default entries.
- Files: `RCMMShared/Sources/Services/SharedConfigService.swift`, `RCMMApp/AppState.swift`
- Impact: Corrupted or incompatible stored config can erase all custom menu entries without any user-visible recovery path.
- Fix approach: Distinguish `no data` from `decode failure`, surface a repair state in `AppState`, and avoid overwriting persisted data until recovery succeeds.

**Cross-process error storage is intentionally lossy:**
- Issue: `SharedErrorQueue.append()` reads, mutates, and writes `UserDefaults` non-atomically across the app and extension. The implementation comment explicitly accepts dropped writes.
- Files: `RCMMShared/Sources/Services/SharedErrorQueue.swift`
- Impact: The exact failure cases operators need most can disappear when the app and Finder extension emit errors close together.
- Fix approach: Replace the queue with a file-backed append log in the app group container or a single-writer IPC path, then trim in a controlled pass.

**App group access hard-fails through force unwraps:**
- Issue: `SharedConfigService` and `SharedErrorQueue` both force unwrap `UserDefaults(suiteName:)`.
- Files: `RCMMShared/Sources/Services/SharedConfigService.swift`, `RCMMShared/Sources/Services/SharedErrorQueue.swift`
- Impact: Any entitlement drift, test harness mismatch, or app-group provisioning problem becomes an immediate crash instead of a diagnosable failure mode.
- Fix approach: Replace force unwraps with throwing initializers or a typed fallback state that surfaces app-group configuration errors.

**Script syncing recompiles everything on every load/save path:**
- Issue: `AppState.loadMenuEntries()` and every `saveAndSync()` call trigger `syncScriptsInBackground()`, and `ScriptInstallerService.syncScripts()` recompiles every expected script regardless of content changes.
- Files: `RCMMApp/AppState.swift`, `RCMMApp/Services/ScriptInstallerService.swift`
- Impact: Startup and configuration edits scale linearly with menu size and repeatedly invoke `osacompile` even when nothing changed.
- Fix approach: Hash generated AppleScript per item, compile only changed scripts, and separate integrity checks from full recompilation.

**Tooling and docs drift from the actual project setup:**
- Issue: `README.md` tells developers to use `RCMMApp` and `RCMMSharedTests` schemes, but `xcodebuild -project rcmm.xcodeproj -list` exposes `rcmm`, `RCMMFinderExtension`, and `RCMMShared`. On 2026-04-07, `xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test` failed because the scheme does not exist, and `xcodebuild -project rcmm.xcodeproj -scheme RCMMShared test` failed because the scheme has no test action.
- Files: `README.md`, `rcmm.xcodeproj/project.pbxproj`
- Impact: Fresh contributors will fail before reaching a working build/test loop.
- Fix approach: Update `README.md` to the working commands (`swift test` in `RCMMShared/` is currently valid) and add a real test action or shared scheme if Xcode-based testing is expected.

**Language-mode mismatch weakens concurrency rigor:**
- Issue: `README.md` describes the app as Swift 6, and `RCMMShared/Package.swift` uses `swift-tools-version: 6.0`, but the Xcode project compiles the app and extension with `SWIFT_VERSION = 5.0` and `SWIFT_STRICT_CONCURRENCY = targeted`.
- Files: `README.md`, `RCMMShared/Package.swift`, `rcmm.xcodeproj/project.pbxproj`
- Impact: Concurrency diagnostics differ between the shared package and the app targets, which makes `@unchecked Sendable` usage easier to ship without stronger compiler pressure.
- Fix approach: Align the package and Xcode project on one Swift language mode, then remove unnecessary `@unchecked Sendable` annotations under stricter checking.

## Known Bugs

**Duplicate app names can launch the wrong menu item:**
- Symptoms: If two custom entries share the same `appName`, Finder resolves the clicked item by parsing the menu title and taking the first matching config.
- Files: `RCMMFinderExtension/FinderSync.swift`
- Trigger: Add two custom entries with the same display name but different bundle IDs, paths, or commands.
- Workaround: Rename one of the entries so the display names are unique.

**Finder actions ignore multi-selection and only use the first path:**
- Symptoms: Right-clicking multiple selected items copies or opens only the first selected path.
- Files: `RCMMFinderExtension/FinderSync.swift`
- Trigger: Invoke `拷贝路径` or `用 {appName} 打开` with multiple Finder items selected.
- Workaround: Run the action one item at a time.

**Custom commands lose every `{path}` placeholder after the first one:**
- Symptoms: Commands that need the target path in more than one position are truncated to a single substitution plus an optional trailing suffix.
- Files: `RCMMShared/Sources/Services/CommandTemplateProcessor.swift`, `RCMMApp/Services/ScriptInstallerService.swift`
- Trigger: Save a command template containing two or more `{path}` placeholders.
- Workaround: Rewrite the shell command so the path is only needed once, or wrap the logic in an external script.

**Application discovery misses nested app bundles:**
- Symptoms: Apps stored inside subfolders under `/Applications` or `~/Applications` do not appear in onboarding or settings selection lists.
- Files: `RCMMApp/Services/AppDiscoveryService.swift`, `RCMMApp/Views/Onboarding/SelectAppsStepView.swift`, `RCMMApp/Views/Settings/AppSelectionSheet.swift`
- Trigger: Install an app under a nested directory such as `/Applications/Dev/Tool.app`.
- Workaround: Use the manual picker instead of relying on automatic discovery.

**Invalid custom commands fail late and mostly off-screen:**
- Symptoms: Saving a malformed command template still updates config; compilation errors are only logged, and users discover the failure later from the Finder extension path.
- Files: `RCMMApp/Services/ScriptInstallerService.swift`, `RCMMApp/Views/Settings/CommandEditor.swift`
- Trigger: Save a command that produces invalid AppleScript or an invalid shell fragment.
- Workaround: Inspect logs and remove or rewrite the affected menu item in settings.

## Security Considerations

**User-entered commands execute with no validation boundary beyond AppleScript compilation:**
- Risk: `CommandEditor` accepts arbitrary templates, `CommandTemplateProcessor` converts them into `do shell script`, and `ScriptExecutor` runs the compiled script from the Finder extension path.
- Files: `RCMMApp/Views/Settings/CommandEditor.swift`, `RCMMShared/Sources/Services/CommandTemplateProcessor.swift`, `RCMMApp/Services/ScriptInstallerService.swift`, `RCMMFinderExtension/ScriptExecutor.swift`
- Current mitigation: `{path}` is passed through AppleScript `quoted form of`, which protects path interpolation.
- Recommendations: Add explicit warnings that commands are arbitrary shell execution, validate placeholder usage before save, and consider per-item confirmation for destructive commands.

**Sensitive file paths are written to unified logs:**
- Risk: The extension logs target filesystem paths on copy/open success paths.
- Files: `RCMMFinderExtension/FinderSync.swift`, `RCMMFinderExtension/ScriptExecutor.swift`
- Current mitigation: None beyond standard macOS log access controls.
- Recommendations: Remove raw path logging from info-level events or downgrade it behind a debug-only flag.

**Full-filesystem Finder Sync scope is broader than the product needs:**
- Risk: `FinderSync` registers `directoryURLs = ["/"]`, so the extension is active everywhere in Finder.
- Files: `RCMMFinderExtension/FinderSync.swift`
- Current mitigation: None.
- Recommendations: Narrow the monitored scope if product requirements allow, or document why global monitoring is required and acceptable.

## Performance Bottlenecks

**Repeated `osacompile` invocations on hot configuration paths:**
- Problem: `ScriptInstallerService.syncScripts()` recompiles every script after load, add, delete, reorder, toggle, and command edit operations.
- Files: `RCMMApp/AppState.swift`, `RCMMApp/Services/ScriptInstallerService.swift`
- Cause: Sync is used as both integrity repair and normal persistence propagation.
- Improvement path: Cache generated script content, skip unchanged items, and batch writes when multiple UI actions happen in one session.

**Global Finder monitoring increases extension work surface:**
- Problem: The extension subscribes to root-level Finder coverage instead of a narrower set of directories.
- Files: `RCMMFinderExtension/FinderSync.swift`
- Cause: `FIFinderSyncController.default().directoryURLs` is set to `/`.
- Improvement path: Profile Finder behavior with narrower scopes and keep `/` only if product behavior depends on it.

**App discovery does fresh filesystem scans every time selection UI opens:**
- Problem: Both onboarding and settings launch a new scan instead of reusing a cached snapshot or invalidation strategy.
- Files: `RCMMApp/Services/AppDiscoveryService.swift`, `RCMMApp/Views/Onboarding/SelectAppsStepView.swift`, `RCMMApp/Views/Settings/AppSelectionSheet.swift`
- Cause: Selection views call `scanApplications()` from `.task` each time.
- Improvement path: Cache discovery results in `AppState`, refresh on explicit user request, and rescan incrementally if needed.

## Fragile Areas

**Auto-repair erases evidence before repair success is known:**
- Files: `RCMMApp/AppState.swift`, `RCMMShared/Sources/Services/SharedErrorQueue.swift`
- Why fragile: `loadErrors()` removes script-related errors from both UI state and shared storage before the background resync completes. If repair also fails, the original signals are gone.
- Safe modification: Keep original errors until the installer confirms success, then replace them with a success banner.
- Test coverage: No tests cover this flow; current automated tests stop at the shared queue model layer in `RCMMShared/Tests/RCMMSharedTests`.

**Finder click dispatch depends on display text instead of stable identifiers:**
- Files: `RCMMFinderExtension/FinderSync.swift`
- Why fragile: Menu generation stores `config.id` in `representedObject`, but execution ignores it and reparses the localized title string.
- Safe modification: Resolve the clicked item by UUID from `representedObject`, and keep title parsing out of control flow.
- Test coverage: No extension-level tests exist for menu creation or dispatch.

**Shared state propagation depends on several weakly-coupled mechanisms:**
- Files: `RCMMApp/AppState.swift`, `RCMMShared/Sources/Services/DarwinNotificationCenter.swift`, `RCMMShared/Sources/Services/SharedConfigService.swift`, `RCMMApp/Services/ScriptInstallerService.swift`, `RCMMFinderExtension/ScriptExecutor.swift`
- Why fragile: Correct behavior depends on `UserDefaults` app-group writes, Darwin notifications, script compilation, and the extension reading the expected scripts directory. Failures in one layer often surface later in another layer.
- Safe modification: Change one boundary at a time and verify end-to-end from settings save through Finder execution.
- Test coverage: Shared unit tests exist, but there are no integration tests spanning app-group persistence, script install, and extension execution.

## Scaling Limits

**Error retention is capped and lossy:**
- Current capacity: `SharedErrorQueue` keeps at most 20 records.
- Limit: Higher-frequency failures overwrite older records and can also drop concurrent writes.
- Scaling path: Move to append-only storage with timestamps and prune separately for UI display.

**Menu update cost grows with menu size:**
- Current capacity: Every custom entry generates one compiled `.scpt` file and is recompiled during each sync.
- Limit: Large menus increase startup latency, settings latency, and the cost of automatic repair.
- Scaling path: Compile lazily, diff script contents, and decouple reorder/toggle events from full script regeneration.

**Execution model assumes one target path per invocation:**
- Current capacity: One selected path from `selectedItemURLs()[0]` or `targetedURL()`.
- Limit: Bulk actions and multi-selection workflows do not scale past a single Finder item.
- Scaling path: Extend the script/event contract to pass multiple targets or explicitly disable the action for multi-selection.

## Dependencies at Risk

**`SettingsAccess` is a small but critical UI dependency for settings routing:**
- Risk: The menu bar app depends on `SettingsAccess` for `SettingsLink` behavior, but there is no app-level automated coverage around settings presentation or recovery flows.
- Impact: Dependency or API changes will break a user-visible path with only manual detection.
- Migration plan: Keep the package version pinned and maintain a fallback route using native SwiftUI/AppKit settings presentation if needed.

## Missing Critical Features

**No automated integration coverage for the actual product behavior:**
- Problem: Test files exist only under `RCMMShared/Tests/RCMMSharedTests`; there are no tests for `RCMMApp` or `RCMMFinderExtension`.
- Blocks: Safe refactoring of Finder menu generation, AppleScript installation, onboarding flow, extension health recovery, and app-group integration.

**No pre-save validation for custom command safety and compileability:**
- Problem: The settings UI warns only when `{path}` is missing; it does not validate that the command compiles or behaves as intended before persisting it.
- Blocks: Confident support for advanced custom commands without runtime trial-and-error.

## Test Coverage Gaps

**Finder extension runtime:**
- What's not tested: Menu rendering, stable dispatch by menu item ID, target-path resolution, copy-path behavior, and script execution error handling.
- Files: `RCMMFinderExtension/FinderSync.swift`, `RCMMFinderExtension/ScriptExecutor.swift`
- Risk: Core user-facing behavior can regress without any automated signal.
- Priority: High

**App-side script lifecycle and recovery:**
- What's not tested: Background sync sequencing, auto-repair behavior, compile failures, and interaction between `AppState` and `ScriptInstallerService`.
- Files: `RCMMApp/AppState.swift`, `RCMMApp/Services/ScriptInstallerService.swift`
- Risk: Startup repair, persistence, and runtime recovery can fail in ways the shared tests never exercise.
- Priority: High

**Discovery and selection UI:**
- What's not tested: Filesystem scanning coverage, nested app omissions, de-duplication edge cases, and onboarding/settings selection state.
- Files: `RCMMApp/Services/AppDiscoveryService.swift`, `RCMMApp/Views/Onboarding/SelectAppsStepView.swift`, `RCMMApp/Views/Settings/AppSelectionSheet.swift`
- Risk: App availability bugs show up directly in first-run and configuration flows.
- Priority: Medium

**Developer workflow verification:**
- What's not tested: README build/test commands and CI preflight behavior for non-release changes.
- Files: `README.md`, `.github/workflows/release.yml`
- Risk: Documentation and automation can drift unnoticed, which already blocks straightforward local verification.
- Priority: Medium

---

*Concerns audit: 2026-04-07*
