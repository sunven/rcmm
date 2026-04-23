# Finder 扩展旧副本清理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 rcmm 在检测到多份旧 Finder 扩展副本时，能够在恢复面板和设置页里扫描、确认并自动清理白名单范围内的旧副本，然后自动切回当前扩展并重启 Finder。

**Architecture:** 共享层先建立可测试的清理契约和纯规划器，把“哪些路径允许删、哪些进程需要结束、如何生成清理计划”全部下沉到 `RCMMShared`。应用层再基于这些纯数据接上运行时仓库根目录、文件系统扫描、命令执行、AppState 状态流和统一的确认/执行 sheet，保证 UI 与副作用执行解耦。

**Tech Stack:** Swift 6, SwiftUI, Foundation, Swift Testing, AppKit, `swift test`, `xcodebuild`, `plutil`, `find`, `rg`

---

## File Map

- Create: `RCMMShared/Sources/Models/ExtensionCleanupStep.swift` — 定义执行步骤枚举和 UI/结果页共用的文案。
- Create: `RCMMShared/Sources/Models/ExtensionCleanupProcess.swift` — 定义待结束旧进程的纯数据模型。
- Create: `RCMMShared/Sources/Models/ExtensionCleanupCandidate.swift` — 定义待删除或待跳过的旧副本候选模型。
- Create: `RCMMShared/Sources/Models/ExtensionCleanupPlan.swift` — 定义二次确认页和执行层共用的清理计划。
- Create: `RCMMShared/Sources/Models/ExtensionCleanupResult.swift` — 定义清理执行结果与后续建议。
- Create: `RCMMShared/Sources/Services/ExtensionCleanupPlanner.swift` — 实现白名单判断、当前安装版排除、去重和清理计划生成。
- Create: `RCMMShared/Tests/RCMMSharedTests/ExtensionCleanupModelsTests.swift` — 锁定计划摘要、步骤文案和结果归类契约。
- Create: `RCMMShared/Tests/RCMMSharedTests/ExtensionCleanupPlannerTests.swift` — 锁定白名单、当前安装版排除、去重和进程过滤。
- Modify: `RCMMApp/Config/AutoUpdate.xcconfig` — 把 `SRCROOT` 注入 `Info.plist`，供运行中的 app 可靠识别当前仓库根目录。
- Create: `RCMMApp/Services/AppInstallContext.swift` — 从 `Bundle.main` 读取当前 app 路径和注入的仓库根目录。
- Modify: `RCMMApp/Services/PluginKitService.swift` — 暴露当前启用扩展路径，供清理服务直接使用。
- Create: `RCMMApp/Services/SystemCommandRunner.swift` — 统一包装 `Process` 命令执行，返回 stdout/stderr/退出码。
- Create: `RCMMApp/Services/ExtensionCleanupService.swift` — 扫描旧副本、发现旧进程、执行删除、切换扩展、重启 Finder。
- Modify: `RCMMApp/AppState.swift` — 承接清理 sheet 状态、扫描入口、执行入口和完成后健康重检。
- Create: `RCMMApp/Views/ExtensionCleanup/ExtensionCleanupSheet.swift` — 统一展示 planning/review/running/result 四种界面状态。
- Modify: `RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift` — 在多份扩展冲突时提供清理入口和 sheet 挂载点。
- Modify: `RCMMApp/Views/Settings/GeneralTab.swift` — 在设置页增加同样的清理入口和 sheet 挂载点。

## Scope Guards

- 只自动删除 `~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/rcmm.app` 和仓库内 `build/dev-release/.../rcmm.app`。
- 不删除 `/Applications`、`~/Applications`、桌面、下载目录或任何不在白名单内的 `rcmm.app`。
- 不顺手清空整个 `DerivedData/` 或整个 `build/`，只删除命中的 `rcmm.app` 包。
- 不修改 Finder 扩展菜单构建逻辑，不修改脚本同步逻辑。
- 项目当前没有 App 层自动化测试 target。本计划坚持把可判定规则下沉到 `RCMMShared` 做 TDD；App 层改动使用 `xcodebuild` 构建验证和手工验证补足。

### Task 1: 建立共享清理契约模型

**Files:**
- Create: `RCMMShared/Sources/Models/ExtensionCleanupStep.swift`
- Create: `RCMMShared/Sources/Models/ExtensionCleanupProcess.swift`
- Create: `RCMMShared/Sources/Models/ExtensionCleanupCandidate.swift`
- Create: `RCMMShared/Sources/Models/ExtensionCleanupPlan.swift`
- Create: `RCMMShared/Sources/Models/ExtensionCleanupResult.swift`
- Test: `RCMMShared/Tests/RCMMSharedTests/ExtensionCleanupModelsTests.swift`

- [ ] **Step 1: 先写共享层失败测试，锁定步骤文案、计划摘要和结果分类**

Create `RCMMShared/Tests/RCMMSharedTests/ExtensionCleanupModelsTests.swift`:

```swift
import Testing
@testable import RCMMShared

@Suite("ExtensionCleanup 模型契约测试")
struct ExtensionCleanupModelsTests {
    @Test("步骤标题为确认页和执行态提供固定文案")
    func stepTitles() {
        #expect(ExtensionCleanupStep.terminateProcesses.title == "正在结束旧 rcmm 进程")
        #expect(ExtensionCleanupStep.deleteApps.title == "正在删除旧扩展副本")
        #expect(ExtensionCleanupStep.switchExtension.title == "正在切换到当前扩展")
        #expect(ExtensionCleanupStep.restartFinder.title == "正在重启 Finder")
        #expect(ExtensionCleanupStep.recheckHealth.title == "正在重新检测状态")
    }

    @Test("清理计划摘要汇总副本和进程数量")
    func planSummary() {
        let plan = ExtensionCleanupPlan(
            currentAppPath: "/current/rcmm.app",
            deleteCandidates: [
                ExtensionCleanupCandidate(
                    appPath: "/tmp/old-1/rcmm.app",
                    extensionPath: "/tmp/old-1/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex",
                    source: .derivedData,
                    disposition: .delete,
                    skipReason: nil
                )
            ],
            skippedCandidates: [],
            processesToTerminate: [
                ExtensionCleanupProcess(pid: 42, appPath: "/tmp/old-1/rcmm.app")
            ],
            postCleanupCommands: [
                "pluginkit -e use -i com.sunven.rcmm.FinderExtension",
                "killall Finder"
            ]
        )

        #expect(plan.hasWork == true)
        #expect(plan.summary == "发现 1 个旧副本，会结束 1 个旧 rcmm 进程，并在清理后自动切回当前扩展、重启 Finder。")
    }

    @Test("未执行结果保留建议")
    func noOpResultKeepsAdvice() {
        let result = ExtensionCleanupResult(
            outcome: .noOp,
            completedSteps: [],
            failedStep: nil,
            deletedAppPaths: [],
            terminatedProcessIDs: [],
            message: "未发现可自动清理的旧副本。",
            followUpAdvice: ["当前目录不在自动清理白名单内。"]
        )

        #expect(result.outcome == .noOp)
        #expect(result.followUpAdvice == ["当前目录不在自动清理白名单内。"])
    }
}
```

- [ ] **Step 2: 运行共享层测试，确认它先因为类型不存在而失败**

Run:

```bash
cd RCMMShared && swift test --filter ExtensionCleanupModelsTests
```

Expected: 编译失败，并出现类似 `cannot find 'ExtensionCleanupPlan' in scope` 的报错。

- [ ] **Step 3: 实现共享层清理模型**

Create `RCMMShared/Sources/Models/ExtensionCleanupStep.swift`:

```swift
import Foundation

public enum ExtensionCleanupStep: String, Codable, Sendable, CaseIterable {
    case terminateProcesses
    case deleteApps
    case switchExtension
    case restartFinder
    case recheckHealth

    public var title: String {
        switch self {
        case .terminateProcesses: "正在结束旧 rcmm 进程"
        case .deleteApps: "正在删除旧扩展副本"
        case .switchExtension: "正在切换到当前扩展"
        case .restartFinder: "正在重启 Finder"
        case .recheckHealth: "正在重新检测状态"
        }
    }
}
```

Create `RCMMShared/Sources/Models/ExtensionCleanupProcess.swift`:

```swift
import Foundation

public struct ExtensionCleanupProcess: Equatable, Codable, Identifiable, Sendable {
    public let pid: Int32
    public let appPath: String

    public init(pid: Int32, appPath: String) {
        self.pid = pid
        self.appPath = appPath
    }

    public var id: Int32 { pid }
}
```

Create `RCMMShared/Sources/Models/ExtensionCleanupCandidate.swift`:

```swift
import Foundation

public enum ExtensionCleanupCandidateSource: String, Codable, Sendable {
    case pluginKit
    case derivedData
    case devRelease
    case unsupported
}

public enum ExtensionCleanupCandidateDisposition: String, Codable, Sendable {
    case delete
    case skip
}

public struct ExtensionCleanupCandidate: Equatable, Codable, Identifiable, Sendable {
    public let appPath: String
    public let extensionPath: String
    public let source: ExtensionCleanupCandidateSource
    public let disposition: ExtensionCleanupCandidateDisposition
    public let skipReason: String?

    public init(
        appPath: String,
        extensionPath: String,
        source: ExtensionCleanupCandidateSource,
        disposition: ExtensionCleanupCandidateDisposition,
        skipReason: String?
    ) {
        self.appPath = appPath
        self.extensionPath = extensionPath
        self.source = source
        self.disposition = disposition
        self.skipReason = skipReason
    }

    public var id: String { appPath }
}
```

Create `RCMMShared/Sources/Models/ExtensionCleanupPlan.swift`:

```swift
import Foundation

public struct ExtensionCleanupPlan: Equatable, Codable, Sendable {
    public let currentAppPath: String?
    public let deleteCandidates: [ExtensionCleanupCandidate]
    public let skippedCandidates: [ExtensionCleanupCandidate]
    public let processesToTerminate: [ExtensionCleanupProcess]
    public let postCleanupCommands: [String]

    public init(
        currentAppPath: String?,
        deleteCandidates: [ExtensionCleanupCandidate],
        skippedCandidates: [ExtensionCleanupCandidate],
        processesToTerminate: [ExtensionCleanupProcess],
        postCleanupCommands: [String]
    ) {
        self.currentAppPath = currentAppPath
        self.deleteCandidates = deleteCandidates
        self.skippedCandidates = skippedCandidates
        self.processesToTerminate = processesToTerminate
        self.postCleanupCommands = postCleanupCommands
    }

    public var hasWork: Bool {
        !deleteCandidates.isEmpty || !processesToTerminate.isEmpty
    }

    public var summary: String {
        "发现 \(deleteCandidates.count) 个旧副本，会结束 \(processesToTerminate.count) 个旧 rcmm 进程，并在清理后自动切回当前扩展、重启 Finder。"
    }
}
```

Create `RCMMShared/Sources/Models/ExtensionCleanupResult.swift`:

```swift
import Foundation

public enum ExtensionCleanupOutcome: String, Codable, Sendable {
    case success
    case partialSuccess
    case noOp
}

public struct ExtensionCleanupResult: Equatable, Codable, Sendable {
    public let outcome: ExtensionCleanupOutcome
    public let completedSteps: [ExtensionCleanupStep]
    public let failedStep: ExtensionCleanupStep?
    public let deletedAppPaths: [String]
    public let terminatedProcessIDs: [Int32]
    public let message: String
    public let followUpAdvice: [String]

    public init(
        outcome: ExtensionCleanupOutcome,
        completedSteps: [ExtensionCleanupStep],
        failedStep: ExtensionCleanupStep?,
        deletedAppPaths: [String],
        terminatedProcessIDs: [Int32],
        message: String,
        followUpAdvice: [String]
    ) {
        self.outcome = outcome
        self.completedSteps = completedSteps
        self.failedStep = failedStep
        self.deletedAppPaths = deletedAppPaths
        self.terminatedProcessIDs = terminatedProcessIDs
        self.message = message
        self.followUpAdvice = followUpAdvice
    }
}
```

- [ ] **Step 4: 重新运行共享层测试，确认模型契约通过**

Run:

```bash
cd RCMMShared && swift test --filter ExtensionCleanupModelsTests
```

Expected: `ExtensionCleanupModelsTests` 全部通过。

- [ ] **Step 5: 提交共享层清理契约**

```bash
git add RCMMShared/Sources/Models/ExtensionCleanupStep.swift \
        RCMMShared/Sources/Models/ExtensionCleanupProcess.swift \
        RCMMShared/Sources/Models/ExtensionCleanupCandidate.swift \
        RCMMShared/Sources/Models/ExtensionCleanupPlan.swift \
        RCMMShared/Sources/Models/ExtensionCleanupResult.swift \
        RCMMShared/Tests/RCMMSharedTests/ExtensionCleanupModelsTests.swift
git commit -m "feat(shared): add extension cleanup contract models"
```

### Task 2: 用 TDD 实现共享层清理规划器

**Files:**
- Create: `RCMMShared/Sources/Services/ExtensionCleanupPlanner.swift`
- Test: `RCMMShared/Tests/RCMMSharedTests/ExtensionCleanupPlannerTests.swift`

- [ ] **Step 1: 先写失败测试，锁定白名单、当前安装版排除、去重和进程过滤**

Create `RCMMShared/Tests/RCMMSharedTests/ExtensionCleanupPlannerTests.swift`:

```swift
import Testing
@testable import RCMMShared

@Suite("ExtensionCleanupPlanner 测试")
struct ExtensionCleanupPlannerTests {
    private let currentApp = "/Users/test/Library/Developer/Xcode/DerivedData/rcmm-current/Build/Products/Debug/rcmm.app"
    private let oldDerivedDataApp = "/Users/test/Library/Developer/Xcode/DerivedData/rcmm-old/Build/Products/Debug/rcmm.app"
    private let oldDevReleaseApp = "/Users/test/work/rcmm/build/dev-release/dmg-root/rcmm.app"
    private let installedApp = "/Applications/rcmm.app"

    @Test("只计划删除白名单内的旧副本并过滤当前安装版")
    func buildPlanFiltersCandidates() {
        let plan = ExtensionCleanupPlanner.buildPlan(
            currentAppPath: currentApp,
            pluginKitExtensionPaths: [
                oldDerivedDataApp + "/Contents/PlugIns/RCMMFinderExtension.appex",
                installedApp + "/Contents/PlugIns/RCMMFinderExtension.appex",
            ],
            discoveredAppPaths: [
                oldDerivedDataApp,
                oldDevReleaseApp,
                installedApp,
                currentApp,
            ],
            runningProcesses: [
                ExtensionCleanupProcess(pid: 41, appPath: oldDerivedDataApp),
                ExtensionCleanupProcess(pid: 42, appPath: currentApp),
            ],
            repositoryRoot: "/Users/test/work/rcmm"
        )

        #expect(plan.deleteCandidates.map(\.appPath) == [oldDerivedDataApp, oldDevReleaseApp])
        #expect(plan.skippedCandidates.map(\.appPath) == [installedApp])
        #expect(plan.processesToTerminate.map(\.pid) == [41])
    }

    @Test("仓库根目录缺失时跳过 dev-release 清理")
    func skipsDevReleaseWhenRepositoryRootMissing() {
        let plan = ExtensionCleanupPlanner.buildPlan(
            currentAppPath: currentApp,
            pluginKitExtensionPaths: [],
            discoveredAppPaths: [oldDevReleaseApp],
            runningProcesses: [],
            repositoryRoot: nil
        )

        #expect(plan.deleteCandidates.isEmpty)
        #expect(plan.skippedCandidates.first?.skipReason == "当前运行环境无法可靠识别仓库根目录。")
    }
}
```

- [ ] **Step 2: 运行共享层测试，确认它先因为缺少规划器而失败**

Run:

```bash
cd RCMMShared && swift test --filter ExtensionCleanupPlannerTests
```

Expected: 编译失败，并出现类似 `cannot find 'ExtensionCleanupPlanner' in scope` 的报错。

- [ ] **Step 3: 实现纯规划器**

Create `RCMMShared/Sources/Services/ExtensionCleanupPlanner.swift`:

```swift
import Foundation

public enum ExtensionCleanupPlanner {
    public static func buildPlan(
        currentAppPath: String?,
        pluginKitExtensionPaths: [String],
        discoveredAppPaths: [String],
        runningProcesses: [ExtensionCleanupProcess],
        repositoryRoot: String?
    ) -> ExtensionCleanupPlan {
        let pluginKitApps = pluginKitExtensionPaths.compactMap(appPath(forExtensionPath:))
        let allAppPaths = Array(Set(pluginKitApps + discoveredAppPaths)).sorted()

        var deleteCandidates: [ExtensionCleanupCandidate] = []
        var skippedCandidates: [ExtensionCleanupCandidate] = []

        for appPath in allAppPaths {
            guard appPath != currentAppPath else { continue }

            let extensionPath = appPath + "/Contents/PlugIns/RCMMFinderExtension.appex"
            let source = cleanupSource(forAppPath: appPath, repositoryRoot: repositoryRoot)

            switch source {
            case .derivedData, .devRelease:
                deleteCandidates.append(
                    ExtensionCleanupCandidate(
                        appPath: appPath,
                        extensionPath: extensionPath,
                        source: source,
                        disposition: .delete,
                        skipReason: nil
                    )
                )
            case .unsupported:
                skippedCandidates.append(
                    ExtensionCleanupCandidate(
                        appPath: appPath,
                        extensionPath: extensionPath,
                        source: .unsupported,
                        disposition: .skip,
                        skipReason: skipReason(forAppPath: appPath, repositoryRoot: repositoryRoot)
                    )
                )
            case .pluginKit:
                break
            }
        }

        let deletablePaths = Set(deleteCandidates.map(\.appPath))
        let processesToTerminate = runningProcesses
            .filter { deletablePaths.contains($0.appPath) }
            .sorted { $0.pid < $1.pid }

        return ExtensionCleanupPlan(
            currentAppPath: currentAppPath,
            deleteCandidates: deleteCandidates,
            skippedCandidates: skippedCandidates,
            processesToTerminate: processesToTerminate,
            postCleanupCommands: [
                "pluginkit -e use -i com.sunven.rcmm.FinderExtension",
                "killall Finder",
            ]
        )
    }

    static func appPath(forExtensionPath extensionPath: String) -> String? {
        let suffix = "/Contents/PlugIns/RCMMFinderExtension.appex"
        guard extensionPath.hasSuffix(suffix) else { return nil }
        return String(extensionPath.dropLast(suffix.count))
    }

    static func cleanupSource(
        forAppPath appPath: String,
        repositoryRoot: String?
    ) -> ExtensionCleanupCandidateSource {
        if appPath.contains("/Library/Developer/Xcode/DerivedData/") {
            return .derivedData
        }

        if let repositoryRoot,
           appPath.hasPrefix(repositoryRoot + "/build/dev-release/") {
            return .devRelease
        }

        return .unsupported
    }

    static func skipReason(forAppPath appPath: String, repositoryRoot: String?) -> String {
        if appPath.contains("/build/dev-release/"), repositoryRoot == nil {
            return "当前运行环境无法可靠识别仓库根目录。"
        }

        return "该路径不在自动清理白名单内。"
    }
}
```

- [ ] **Step 4: 运行共享层测试，确认规划规则通过**

Run:

```bash
cd RCMMShared && swift test --filter ExtensionCleanup
```

Expected: `ExtensionCleanupModelsTests` 和 `ExtensionCleanupPlannerTests` 全部通过。

- [ ] **Step 5: 提交共享层规划器**

```bash
git add RCMMShared/Sources/Services/ExtensionCleanupPlanner.swift \
        RCMMShared/Tests/RCMMSharedTests/ExtensionCleanupPlannerTests.swift
git commit -m "feat(shared): add extension cleanup planner"
```

### Task 3: 注入运行时仓库根目录并暴露扩展路径读取接口

**Files:**
- Modify: `RCMMApp/Config/AutoUpdate.xcconfig`
- Create: `RCMMApp/Services/AppInstallContext.swift`
- Modify: `RCMMApp/Services/PluginKitService.swift`

- [ ] **Step 1: 把 `SRCROOT` 注入 Info.plist，供运行中的 app 可靠识别仓库根目录**

在 `RCMMApp/Config/AutoUpdate.xcconfig` 末尾追加：

```xcconfig
INFOPLIST_KEY_RCMMRepositoryRoot = $(SRCROOT)
```

- [ ] **Step 2: 新建运行时安装上下文读取器**

Create `RCMMApp/Services/AppInstallContext.swift`:

```swift
import Foundation

struct AppInstallContext: Sendable {
    let currentAppPath: String
    let repositoryRoot: String?

    static func current(bundle: Bundle = .main) -> AppInstallContext {
        let repositoryRootValue = bundle.object(
            forInfoDictionaryKey: "RCMMRepositoryRoot"
        ) as? String

        let repositoryRoot = repositoryRootValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        return AppInstallContext(
            currentAppPath: bundle.bundleURL.path,
            repositoryRoot: repositoryRoot
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
```

- [ ] **Step 3: 让 `PluginKitService` 暴露当前启用扩展路径列表**

在 `RCMMApp/Services/PluginKitService.swift` 中，把 `healthReport()` 前面插入下面这个辅助方法：

```swift
    static func enabledExtensionPaths() -> [String] {
        guard let output = pluginKitMatchOutput() else {
            return []
        }

        return ExtensionInstallHealthResolver.enabledExtensionPaths(from: output)
    }
```

并把 `currentExtensionPath()` 访问级别从 `private` 调整为默认 internal，供清理服务复用：

```swift
    static func currentExtensionPath() -> String? {
```

- [ ] **Step 4: 构建主应用，并确认 `Info.plist` 已包含 `RCMMRepositoryRoot`**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build
app_plist="$(find ~/Library/Developer/Xcode/DerivedData -path '*Build/Products/Debug/rcmm.app/Contents/Info.plist' -print -quit)"
plutil -p "$app_plist" | rg "RCMMRepositoryRoot"
```

Expected: 构建成功，`plutil` 输出包含 `RCMMRepositoryRoot` 且值是当前仓库根目录。

- [ ] **Step 5: 提交运行时上下文和 PluginKit 辅助接口**

```bash
git add RCMMApp/Config/AutoUpdate.xcconfig \
        RCMMApp/Services/AppInstallContext.swift \
        RCMMApp/Services/PluginKitService.swift
git commit -m "feat(app): expose install context for cleanup flow"
```

### Task 4: 实现旧副本扫描和执行服务

**Files:**
- Create: `RCMMApp/Services/SystemCommandRunner.swift`
- Create: `RCMMApp/Services/ExtensionCleanupService.swift`

- [ ] **Step 1: 添加命令执行包装**

Create `RCMMApp/Services/SystemCommandRunner.swift`:

```swift
import Foundation

struct SystemCommandResult: Sendable {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32
}

protocol SystemCommandRunning: Sendable {
    func run(executable: URL, arguments: [String]) throws -> SystemCommandResult
}

struct SystemCommandRunner: SystemCommandRunning {
    func run(executable: URL, arguments: [String]) throws -> SystemCommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        return SystemCommandResult(
            stdout: String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            terminationStatus: process.terminationStatus
        )
    }
}
```

- [ ] **Step 2: 添加清理执行服务**

Create `RCMMApp/Services/ExtensionCleanupService.swift`:

```swift
import Darwin
import Foundation
import os.log
import RCMMShared

enum ExtensionCleanupServiceError: Error {
    case commandFailed(ExtensionCleanupStep, String)
    case deleteFailed(String, String)
}

final class ExtensionCleanupService {
    private let fileManager: FileManager
    private let commandRunner: SystemCommandRunning
    private let logger = Logger(subsystem: "com.sunven.rcmm", category: "cleanup")

    init(
        fileManager: FileManager = .default,
        commandRunner: SystemCommandRunning = SystemCommandRunner()
    ) {
        self.fileManager = fileManager
        self.commandRunner = commandRunner
    }

    func preparePlan(bundle: Bundle = .main) -> ExtensionCleanupPlan {
        let installContext = AppInstallContext.current(bundle: bundle)
        let discoveredApps = discoverDerivedDataApps()
            + discoverDevReleaseApps(repositoryRoot: installContext.repositoryRoot)
        let processes = discoverRunningProcesses(currentAppPath: installContext.currentAppPath)

        return ExtensionCleanupPlanner.buildPlan(
            currentAppPath: installContext.currentAppPath,
            pluginKitExtensionPaths: PluginKitService.enabledExtensionPaths(),
            discoveredAppPaths: discoveredApps,
            runningProcesses: processes,
            repositoryRoot: installContext.repositoryRoot
        )
    }

    func execute(
        plan: ExtensionCleanupPlan,
        progress: @escaping @Sendable (ExtensionCleanupStep) -> Void
    ) -> ExtensionCleanupResult {
        guard plan.hasWork else {
            return ExtensionCleanupResult(
                outcome: .noOp,
                completedSteps: [],
                failedStep: nil,
                deletedAppPaths: [],
                terminatedProcessIDs: [],
                message: "未发现可自动清理的旧副本。",
                followUpAdvice: ["当前目录不在自动清理白名单内。"]
            )
        }

        var completedSteps: [ExtensionCleanupStep] = []
        var deletedPaths: [String] = []
        var terminatedPIDs: [Int32] = []

        do {
            progress(.terminateProcesses)
            for process in plan.processesToTerminate {
                terminate(process: process)
                terminatedPIDs.append(process.pid)
            }
            completedSteps.append(.terminateProcesses)

            progress(.deleteApps)
            for candidate in plan.deleteCandidates {
                do {
                    try fileManager.removeItem(atPath: candidate.appPath)
                    deletedPaths.append(candidate.appPath)
                } catch {
                    throw ExtensionCleanupServiceError.deleteFailed(candidate.appPath, error.localizedDescription)
                }
            }
            completedSteps.append(.deleteApps)

            try run(step: .switchExtension, executable: "/usr/bin/pluginkit", arguments: ["-e", "use", "-i", "com.sunven.rcmm.FinderExtension"])
            completedSteps.append(.switchExtension)

            try run(step: .restartFinder, executable: "/usr/bin/killall", arguments: ["Finder"])
            completedSteps.append(.restartFinder)

            progress(.recheckHealth)
            completedSteps.append(.recheckHealth)

            return ExtensionCleanupResult(
                outcome: .success,
                completedSteps: completedSteps,
                failedStep: nil,
                deletedAppPaths: deletedPaths,
                terminatedProcessIDs: terminatedPIDs,
                message: "旧扩展副本清理完成。",
                followUpAdvice: []
            )
        } catch let error as ExtensionCleanupServiceError {
            return ExtensionCleanupResult(
                outcome: deletedPaths.isEmpty && terminatedPIDs.isEmpty ? .noOp : .partialSuccess,
                completedSteps: completedSteps,
                failedStep: failedStep(for: error),
                deletedAppPaths: deletedPaths,
                terminatedProcessIDs: terminatedPIDs,
                message: failureMessage(for: error),
                followUpAdvice: followUpAdvice(for: error)
            )
        } catch {
            return ExtensionCleanupResult(
                outcome: deletedPaths.isEmpty && terminatedPIDs.isEmpty ? .noOp : .partialSuccess,
                completedSteps: completedSteps,
                failedStep: completedSteps.last,
                deletedAppPaths: deletedPaths,
                terminatedProcessIDs: terminatedPIDs,
                message: "清理过程中发生未知错误：\(error.localizedDescription)",
                followUpAdvice: ["请重新打开 rcmm 后重试。"]
            )
        }
    }

    private func discoverDerivedDataApps() -> [String] {
        let root = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")
        return discoverRcmmApps(under: root)
    }

    private func discoverDevReleaseApps(repositoryRoot: String?) -> [String] {
        guard let repositoryRoot else { return [] }
        return discoverRcmmApps(under: URL(fileURLWithPath: repositoryRoot).appendingPathComponent("build/dev-release"))
    }

    private func discoverRcmmApps(under root: URL) -> [String] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }

        let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var matches: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.lastPathComponent == "rcmm.app" else { continue }
            let extensionURL = url.appendingPathComponent("Contents/PlugIns/RCMMFinderExtension.appex")
            if fileManager.fileExists(atPath: extensionURL.path) {
                matches.append(url.path)
                enumerator?.skipDescendants()
            }
        }

        return matches.sorted()
    }

    private func discoverRunningProcesses(currentAppPath: String) -> [ExtensionCleanupProcess] {
        guard let result = try? commandRunner.run(
            executable: URL(fileURLWithPath: "/bin/ps"),
            arguments: ["-axo", "pid=,comm="]
        ) else {
            return []
        }

        return result.stdout
            .split(whereSeparator: \.isNewline)
            .compactMap(parseProcess)
            .filter { $0.appPath != currentAppPath }
            .sorted { $0.pid < $1.pid }
    }

    private func parseProcess(line: Substring) -> ExtensionCleanupProcess? {
        let parts = line.trimmingCharacters(in: .whitespaces).split(maxSplits: 1, whereSeparator: \.isWhitespace)
        guard parts.count == 2, let pid = Int32(parts[0]) else { return nil }

        let executablePath = String(parts[1])
        let suffix = "/Contents/MacOS/rcmm"
        guard executablePath.hasSuffix(suffix) else { return nil }

        return ExtensionCleanupProcess(
            pid: pid,
            appPath: String(executablePath.dropLast(suffix.count))
        )
    }

    private func terminate(process: ExtensionCleanupProcess) {
        logger.info("结束旧进程: pid=\(process.pid), app=\(process.appPath)")
        kill(process.pid, SIGTERM)
        usleep(300_000)
        if kill(process.pid, 0) == 0 {
            kill(process.pid, SIGKILL)
        }
    }

    private func run(step: ExtensionCleanupStep, executable: String, arguments: [String]) throws {
        let result = try commandRunner.run(
            executable: URL(fileURLWithPath: executable),
            arguments: arguments
        )

        guard result.terminationStatus == 0 else {
            throw ExtensionCleanupServiceError.commandFailed(step, result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    private func failedStep(for error: ExtensionCleanupServiceError) -> ExtensionCleanupStep? {
        switch error {
        case .commandFailed(let step, _):
            return step
        case .deleteFailed:
            return .deleteApps
        }
    }

    private func failureMessage(for error: ExtensionCleanupServiceError) -> String {
        switch error {
        case .commandFailed(_, let message):
            return "自动清理未完全完成：\(message)"
        case .deleteFailed(let path, let message):
            return "删除旧副本失败：\(path) — \(message)"
        }
    }

    private func followUpAdvice(for error: ExtensionCleanupServiceError) -> [String] {
        switch error {
        case .commandFailed(.restartFinder, _):
            return ["请手动执行 `killall Finder` 后重新检测。"]
        case .commandFailed(.switchExtension, _):
            return ["请手动执行 `pluginkit -e use -i com.sunven.rcmm.FinderExtension` 后重新检测。"]
        case .deleteFailed:
            return ["请确认旧 rcmm 已退出，或手动删除仍残留的路径后重试。"]
        default:
            return ["请重新打开 rcmm 并重试。"]
        }
    }
}
```

- [ ] **Step 3: 构建主应用，确认执行服务可编译**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build | rg "BUILD SUCCEEDED|error:"
```

Expected: 输出 `BUILD SUCCEEDED`，没有 `error:`。

- [ ] **Step 4: 用真实命令观察 `preparePlan()` 的输入是否完整**

Run:

```bash
pluginkit -m -ADv -i com.sunven.rcmm.FinderExtension
ps -axo pid=,comm= | rg "rcmm(.app)?/Contents/MacOS/rcmm"
find ~/Library/Developer/Xcode/DerivedData -path '*Build/Products/Debug/rcmm.app' -maxdepth 6
```

Expected: 能看到旧扩展路径、旧 `rcmm` 进程和至少一个 `DerivedData` 下的 `rcmm.app`，说明 `ExtensionCleanupService` 所依赖的数据源都可在本机提供。

- [ ] **Step 5: 提交扫描与执行服务**

```bash
git add RCMMApp/Services/SystemCommandRunner.swift \
        RCMMApp/Services/ExtensionCleanupService.swift
git commit -m "feat(app): add finder extension cleanup service"
```

### Task 5: 接入 AppState 和统一清理 sheet

**Files:**
- Modify: `RCMMApp/AppState.swift`
- Create: `RCMMApp/Views/ExtensionCleanup/ExtensionCleanupSheet.swift`
- Modify: `RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift`
- Modify: `RCMMApp/Views/Settings/GeneralTab.swift`

- [ ] **Step 1: 在 `AppState` 中新增清理流程状态和入口方法**

在 `RCMMApp/AppState.swift` 中：

- 把下面这个枚举放到 `AppUpdateState` 后面
- 把属性插入 `AppState` 现有存储属性区域
- 把方法插入 `AppState` 现有实例方法区域

```swift
enum ExtensionCleanupFlowState: Equatable {
    case idle
    case planning
    case review(ExtensionCleanupPlan)
    case running(ExtensionCleanupStep)
    case finished(ExtensionCleanupResult)
}
```

```swift
    var isShowingExtensionCleanupSheet = false
    var extensionCleanupFlowState: ExtensionCleanupFlowState = .idle

    @ObservationIgnored private let extensionCleanupService = ExtensionCleanupService()

    func beginExtensionCleanup() {
        isShowingExtensionCleanupSheet = true
        extensionCleanupFlowState = .planning

        Task {
            let plan = extensionCleanupService.preparePlan()
            await MainActor.run {
                extensionCleanupFlowState = .review(plan)
            }
        }
    }

    func confirmExtensionCleanup(plan: ExtensionCleanupPlan) {
        extensionCleanupFlowState = .running(.terminateProcesses)

        Task {
            let result = extensionCleanupService.execute(plan: plan) { step in
                Task { @MainActor in
                    self.extensionCleanupFlowState = .running(step)
                }
            }

            await MainActor.run {
                self.extensionCleanupFlowState = .finished(result)
                self.checkExtensionStatus()
            }
        }
    }

    func dismissExtensionCleanupSheet() {
        isShowingExtensionCleanupSheet = false
        extensionCleanupFlowState = .idle
    }
```

- [ ] **Step 2: 新建统一的确认/执行 sheet**

Create `RCMMApp/Views/ExtensionCleanup/ExtensionCleanupSheet.swift`:

```swift
import RCMMShared
import SwiftUI

struct ExtensionCleanupSheet: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch appState.extensionCleanupFlowState {
            case .idle:
                Text("未开始清理。")
            case .planning:
                ProgressView("正在扫描旧扩展副本…")
            case .review(let plan):
                reviewView(plan: plan)
            case .running(let step):
                ProgressView(step.title)
            case .finished(let result):
                resultView(result: result)
            }
        }
        .padding(16)
        .frame(width: 460)
    }

    private func reviewView(plan: ExtensionCleanupPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.summary)
                .font(.headline)

            GroupBox("将删除的副本") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plan.deleteCandidates) { candidate in
                        Text(candidate.appPath)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            GroupBox("将结束的旧进程") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plan.processesToTerminate) { process in
                        Text("pid \(process.pid) — \(process.appPath)")
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            GroupBox("后续自动执行") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plan.postCleanupCommands, id: \.self) { command in
                        Text(command)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Text("不会处理 /Applications 中的正式安装版。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("取消") {
                    appState.dismissExtensionCleanupSheet()
                }
                Spacer()
                Button("确认清理") {
                    appState.confirmExtensionCleanup(plan: plan)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!plan.hasWork)
            }
        }
    }

    private func resultView(result: ExtensionCleanupResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.message)
                .font(.headline)

            if !result.followUpAdvice.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.followUpAdvice, id: \.self) { advice in
                        Text("• \(advice)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Button("完成") {
                appState.dismissExtensionCleanupSheet()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
```

- [ ] **Step 3: 在恢复面板里接入口和 sheet**

把 `RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift` 中按钮区域改成下面这样：

```swift
            if appState.extensionStatus == .otherInstallationEnabled {
                Button {
                    appState.beginExtensionCleanup()
                } label: {
                    Text("清理旧扩展副本…")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                PluginKitService.showExtensionManagement()
            } label: {
                Text("修复")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("前往系统设置修复扩展")
```

并在最外层 `VStack` 后追加：

```swift
        .sheet(isPresented: Binding(
            get: { appState.isShowingExtensionCleanupSheet },
            set: { isPresented in
                if !isPresented {
                    appState.dismissExtensionCleanupSheet()
                }
            }
        )) {
            ExtensionCleanupSheet()
                .environment(appState)
        }
```

- [ ] **Step 4: 在设置页 `GeneralTab` 增加相同入口和 sheet**

把 `RCMMApp/Views/Settings/GeneralTab.swift` 改成下面这样：

```swift
import SwiftUI
import ServiceManagement
import os.log

struct GeneralTab: View {
    @Environment(AppState.self) private var appState
    @State private var isLoginItemEnabled = false
    @State private var isUpdating = false
    @State private var errorMessage: String? = nil

    private let logger = Logger(subsystem: "com.sunven.rcmm", category: "system")

    var body: some View {
        Form {
            Section("开机自启") {
                Toggle("开机时自动启动 rcmm", isOn: $isLoginItemEnabled)
                    .accessibilityLabel("开机自动启动")
                    .accessibilityValue(isLoginItemEnabled ? "已启用" : "未启用")

                Text(isLoginItemEnabled ? "已启用 — rcmm 将在开机时自动启动" : "未启用")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("扩展维护") {
                Button("清理旧扩展副本…") {
                    appState.beginExtensionCleanup()
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: Binding(
            get: { appState.isShowingExtensionCleanupSheet },
            set: { isPresented in
                if !isPresented {
                    appState.dismissExtensionCleanupSheet()
                }
            }
        )) {
            ExtensionCleanupSheet()
                .environment(appState)
        }
        .onAppear {
            isUpdating = true
            isLoginItemEnabled = SMAppService.mainApp.status == .enabled
            errorMessage = nil
        }
        .onChange(of: isLoginItemEnabled) { _, newValue in
            if isUpdating {
                isUpdating = false
                return
            }
            isUpdating = true

            do {
                if newValue {
                    try SMAppService.mainApp.register()
                    logger.info("开机自启已启用")
                } else {
                    try SMAppService.mainApp.unregister()
                    logger.info("开机自启已关闭")
                }
                errorMessage = nil
                isUpdating = false
            } catch {
                isLoginItemEnabled = !newValue
                errorMessage = "操作失败：\(error.localizedDescription)"
                logger.error("开机自启操作失败: \(error.localizedDescription)")
            }
        }
    }
}
```

- [ ] **Step 5: 构建主应用，并确认 UI 接线可编译**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build | rg "BUILD SUCCEEDED|error:"
```

Expected: 输出 `BUILD SUCCEEDED`，没有 `error:`。

- [ ] **Step 6: 提交 AppState 和 UI 接线**

```bash
git add RCMMApp/AppState.swift \
        RCMMApp/Views/ExtensionCleanup/ExtensionCleanupSheet.swift \
        RCMMApp/Views/MenuBar/RecoveryGuidePanel.swift \
        RCMMApp/Views/Settings/GeneralTab.swift
git commit -m "feat(ui): add extension cleanup confirmation flow"
```

### Task 6: 做端到端手工验证并补充执行记录

**Files:**
- Modify: `docs/superpowers/specs/2026-04-23-finder-extension-cleanup-design.md`（仅当实际验证暴露需要回写的设计差异时）

- [ ] **Step 1: 准备本机复现场景**

Run:

```bash
pluginkit -m -ADv -i com.sunven.rcmm.FinderExtension
find ~/Library/Developer/Xcode/DerivedData -path '*Build/Products/Debug/rcmm.app' -maxdepth 6
find "$PWD/build/dev-release" -path '*rcmm.app' 2>/dev/null
```

Expected: 至少存在一个当前副本和一个旧副本；`pluginkit` 能看到多份 `+ com.sunven.rcmm.FinderExtension ...`。

- [ ] **Step 2: 在恢复面板里验证确认 sheet 信息完整**

手工检查：

1. 打开 rcmm 菜单栏弹层，确保当前处于扩展冲突恢复面板。
2. 点击 `清理旧扩展副本…`。
3. 确认 sheet 展示：
   - 待删除旧副本路径
   - 待结束旧进程
   - `pluginkit -e use -i com.sunven.rcmm.FinderExtension`
   - `killall Finder`
4. 确认 `/Applications/rcmm.app` 不在待删除列表中。

Expected: 二次确认内容完整，白名单限制文案清楚。

- [ ] **Step 3: 执行清理并验证结果页与健康状态**

手工检查：

1. 在确认页点击 `确认清理`。
2. 观察执行态是否按步骤推进。
3. 等待完成后确认结果页显示成功或部分成功信息。
4. 关闭 sheet 后再次打开菜单栏弹层。
5. 确认冲突提示消失，或至少详细文案与结果页一致。

Run:

```bash
pluginkit -m -ADv -i com.sunven.rcmm.FinderExtension
```

Expected: 只剩当前目标扩展路径处于启用状态，或在部分成功场景下明确能看出哪条旧路径仍然残留。

- [ ] **Step 4: 回看 spec 与实现，若无偏差则不改 spec；若有偏差则最小回写**

如果手工验证结果与 spec 一致，不做任何文档改动。

如果发现必须调整的实现边界，只回写被验证推翻的那一小段 spec，例如：

```markdown
- `build/dev-release` 仅在 `RCMMRepositoryRoot` 可用时扫描；正式安装包不注入该 key，因此发布版默认只处理 `DerivedData` 副本。
```

- [ ] **Step 5: 提交最终验证记录或 spec 小修**

如果没有文档改动，这一步只提交代码工作树的最终状态：

```bash
git status --short
```

Expected: 工作树干净。

如果有 spec 小修，再提交：

```bash
git add docs/superpowers/specs/2026-04-23-finder-extension-cleanup-design.md
git commit -m "docs: align cleanup spec with verified behavior"
```

## Self-Review

- Spec coverage: Task 1 和 Task 2 覆盖共享层契约、白名单、当前安装版排除、去重和结果建模；Task 3 覆盖运行时仓库根目录识别与扩展路径暴露；Task 4 覆盖扫描、旧进程结束、删除、`pluginkit` 和 `killall Finder` 执行；Task 5 覆盖恢复面板与设置页双入口、二次确认和执行结果页；Task 6 覆盖手工验收与 spec 回看，没有遗漏 spec 中的核心要求。
- Placeholder scan: 全文没有 `TODO`、`TBD`、`implement later`、`类似 Task N` 之类的占位内容。每个代码步骤都给了明确代码块，每个验证步骤都给了精确命令。
- Type consistency: 全文统一使用 `ExtensionCleanupPlan`、`ExtensionCleanupResult`、`ExtensionCleanupStep`、`ExtensionCleanupService`、`beginExtensionCleanup()`、`confirmExtensionCleanup(plan:)` 这些命名，没有前后漂移。
