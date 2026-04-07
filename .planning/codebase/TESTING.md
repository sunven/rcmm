# Testing Patterns

**Analysis Date:** 2026-04-07

## Test Framework

**Runner:**
- Swift Testing (`import Testing`) is the active framework for automated tests in `RCMMShared/Tests/RCMMSharedTests/*.swift`.
- Config: `RCMMShared/Package.swift`

**Assertion Library:**
- Swift Testing expectation macros via `#expect(...)`, with occasional custom failure messages in loops, as in `RCMMShared/Tests/RCMMSharedTests/CommandMappingServiceTests.swift` and `RCMMShared/Tests/RCMMSharedTests/AppCategoryTests.swift`.

**Run Commands:**
```bash
cd RCMMShared && swift test
cd RCMMShared && swift test --filter SharedConfigServiceTests
xcodebuild -project rcmm.xcodeproj -scheme RCMMShared test
```

## Test File Organization

**Location:**
- Tests live in the Swift package only, under `RCMMShared/Tests/RCMMSharedTests/`.
- There are no automated tests under `RCMMApp/` or `RCMMFinderExtension/`; those targets are currently covered by manual verification and previews.

**Naming:**
- Name test files after the source type or service under test: `RCMMShared/Tests/RCMMSharedTests/MenuItemConfigTests.swift`, `RCMMShared/Tests/RCMMSharedTests/CommandTemplateProcessorTests.swift`, `RCMMShared/Tests/RCMMSharedTests/SharedErrorQueueTests.swift`.

**Structure:**
```text
RCMMShared/
├── Sources/
│   ├── Models/
│   └── Services/
└── Tests/
    └── RCMMSharedTests/
        ├── AppCategoryTests.swift
        ├── AppInfoTests.swift
        ├── CommandMappingServiceTests.swift
        ├── CommandTemplateProcessorTests.swift
        ├── MenuEntryTests.swift
        ├── MenuItemConfigTests.swift
        ├── SharedConfigServiceTests.swift
        └── SharedErrorQueueTests.swift
```

## Test Structure

**Suite Organization:**
```swift
@Suite("SharedConfigService 读写测试", .serialized)
struct SharedConfigServiceTests {
    let defaults: UserDefaults
    let service: SharedConfigService

    init() {
        let suiteName = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        service = SharedConfigService(defaults: defaults)
    }

    @Test("保存后可正确读取 entries")
    func saveAndLoadEntries() throws {
        // arrange / act / assert inline
    }
}
```

**Patterns:**
- Use one `struct` per suite with `@Suite("...")`, matching the type under test: every file in `RCMMShared/Tests/RCMMSharedTests/`.
- Use Chinese human-readable suite and test names, while Swift method names stay concise and lowerCamelCase: `saveAndLoadEntries`, `categorizeEditors`, `pathPlaceholderNotQuoted`.
- Put setup in the suite `init()` instead of XCTest-style `setUp()`: `RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift`, `RCMMShared/Tests/RCMMSharedTests/SharedErrorQueueTests.swift`.
- Use explicit helper cleanup methods instead of automatic teardown hooks: `cleanup()` in `RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift` and `RCMMShared/Tests/RCMMSharedTests/SharedErrorQueueTests.swift`.
- Mark suites `.serialized` when tests touch shared process state such as `UserDefaults`: `RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift`, `RCMMShared/Tests/RCMMSharedTests/SharedErrorQueueTests.swift`.
- Keep arrange/act/assert inline inside each `@Test`, without helper factories unless the fixture is reused heavily.

## Mocking

**Framework:** None

**Patterns:**
```swift
let suiteName = "test.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suiteName)!
let service = SharedConfigService(defaults: defaults)
```

**What to Mock:**
- Isolate persistence-backed services by injecting a fresh `UserDefaults` suite, as done in `RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift` and `RCMMShared/Tests/RCMMSharedTests/SharedErrorQueueTests.swift`.
- Simulate backward-compatibility inputs with inline JSON strings instead of external fixtures: `RCMMShared/Tests/RCMMSharedTests/MenuItemConfigTests.swift` and `RCMMShared/Tests/RCMMSharedTests/AppInfoTests.swift`.

**What NOT to Mock:**
- Do not mock pure shared helpers or codable models. Tests exercise the real `JSONEncoder`, `JSONDecoder`, and pure functions in `RCMMShared/Sources/Models/*.swift`, `RCMMShared/Sources/Services/CommandMappingService.swift`, and `RCMMShared/Sources/Services/CommandTemplateProcessor.swift`.
- There is no mocking layer for `NSWorkspace`, `FinderSync`, `Process`, or `NSUserAppleScriptTask`; app and extension integration code in `RCMMApp/` and `RCMMFinderExtension/` is not covered by automated tests.

## Fixtures and Factories

**Test Data:**
```swift
let entries: [MenuEntry] = [
    .custom(MenuItemConfig(appName: "Terminal", appPath: "/Applications/Utilities/Terminal.app")),
    .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
]
```

**Location:**
- Fixtures are inline inside each test file. There is no shared `Fixtures/` or factory module under `RCMMShared/Tests/`.
- Repeated literals are short and local by design: bundle IDs in `RCMMShared/Tests/RCMMSharedTests/AppCategoryTests.swift`, command templates in `RCMMShared/Tests/RCMMSharedTests/CommandTemplateProcessorTests.swift`, and JSON payloads in `RCMMShared/Tests/RCMMSharedTests/MenuItemConfigTests.swift`.

## CI Signals

**Automation:**
- The only checked-in GitHub Actions workflow is `/.github/workflows/release.yml`. It builds and packages tagged releases, but it does not run `swift test` or fail on test regressions before release packaging.
- `README.md` documents test execution, but the verified working path is `cd RCMMShared && swift test`.

**Observed Behavior:**
- `swift test` in `RCMMShared/` succeeds and runs the Swift Testing suites in `RCMMShared/Tests/RCMMSharedTests/`. On 2026-04-07 it reported 60 tests across 10 suites.
- `swift test` also prints an initial XCTest-style line saying `Executed 0 tests`; treat that as bridge noise and read through to the Swift Testing summary line.
- `xcodebuild -project rcmm.xcodeproj -scheme RCMMShared test` fails because the `RCMMShared` scheme in `rcmm.xcodeproj` is not configured for the test action.

## Coverage

**Requirements:** None enforced. There is no coverage threshold, no coverage upload step in `/.github/workflows/release.yml`, and no dedicated coverage config file next to `RCMMShared/Package.swift`.

**View Coverage:**
```bash
cd RCMMShared && swift test --enable-code-coverage
```

## Test Types

**Unit Tests:**
- Most coverage is pure unit testing of value semantics, enum behavior, Codable round-trips, and string transformation logic in `RCMMShared/Sources/Models/` and `RCMMShared/Sources/Services/`.
- Representative pairs:
  - `RCMMShared/Sources/Models/MenuItemConfig.swift` ↔ `RCMMShared/Tests/RCMMSharedTests/MenuItemConfigTests.swift`
  - `RCMMShared/Sources/Services/CommandTemplateProcessor.swift` ↔ `RCMMShared/Tests/RCMMSharedTests/CommandTemplateProcessorTests.swift`
  - `RCMMShared/Sources/Services/CommandMappingService.swift` ↔ `RCMMShared/Tests/RCMMSharedTests/CommandMappingServiceTests.swift`

**Integration Tests:**
- Lightweight integration exists only where shared services touch `UserDefaults`, using real `UserDefaults` suites rather than mocks: `RCMMShared/Tests/RCMMSharedTests/SharedConfigServiceTests.swift` and `RCMMShared/Tests/RCMMSharedTests/SharedErrorQueueTests.swift`.
- There are no automated integration tests for `RCMMApp/Services/ScriptInstallerService.swift`, `RCMMFinderExtension/ScriptExecutor.swift`, or Finder extension menu behavior in `RCMMFinderExtension/FinderSync.swift`.

**E2E Tests:**
- Not used. No UI test target, snapshot test suite, or Finder-extension automation target exists under `rcmm.xcodeproj`.
- Manual validation guidance lives in `README.md`, especially the Finder extension setup and logging commands.

## Common Patterns

**Async Testing:**
```swift
// No automated async test examples are present under `RCMMShared/Tests/RCMMSharedTests/`.
// Async `Task`-based UI flows in `RCMMApp/AppState.swift` and `RCMMApp/Views/...`
// are currently covered manually, not with test code.
```

**Error Testing:**
```swift
let item = try JSONDecoder().decode(MenuItemConfig.self, from: Data(json.utf8))
#expect(item.isEnabled == true)
#expect(CommandMappingService.command(for: "com.example.unknown") == nil)
```

---

*Testing analysis: 2026-04-07*
