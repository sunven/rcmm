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
        let oldProcess = ExtensionCleanupProcess(pid: 41, appPath: oldDerivedDataApp)
        let currentProcess = ExtensionCleanupProcess(pid: 42, appPath: currentApp)
        #expect(oldProcess != nil)
        #expect(currentProcess != nil)
        guard let oldProcess, let currentProcess else { return }

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
                oldProcess,
                currentProcess,
            ],
            repositoryRoot: "/Users/test/work/rcmm"
        )

        #expect(plan.deleteCandidates.map(\.appPath) == [oldDerivedDataApp, oldDevReleaseApp])
        #expect(plan.skippedCandidates.map(\.appPath) == [installedApp])
        #expect(plan.processesToTerminate.map(\.pid) == [41])
        #expect(plan.postCleanupCommands == [
            "pluginkit -e use -i com.sunven.rcmm.FinderExtension",
            "killall Finder"
        ])
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

    @Test("规范化路径后过滤当前副本并命中旧进程")
    func normalizesPathsForFilteringAndProcessMatching() {
        let oldProcess = ExtensionCleanupProcess(
            pid: 41,
            appPath: "/Users/test/Library/Developer/Xcode/DerivedData/rcmm-old/Build/Products/Debug/./rcmm.app/"
        )
        let currentProcess = ExtensionCleanupProcess(pid: 42, appPath: currentApp + "/")
        #expect(oldProcess != nil)
        #expect(currentProcess != nil)
        guard let oldProcess, let currentProcess else { return }

        let plan = ExtensionCleanupPlanner.buildPlan(
            currentAppPath: currentApp + "/",
            pluginKitExtensionPaths: [],
            discoveredAppPaths: [
                "/Users/test/Library/Developer/Xcode/DerivedData/rcmm-old/Build/Products/Debug/./rcmm.app/",
                currentApp + "/",
            ],
            runningProcesses: [oldProcess, currentProcess],
            repositoryRoot: nil
        )

        #expect(plan.deleteCandidates.map(\.appPath) == [oldDerivedDataApp])
        #expect(plan.processesToTerminate.map(\.pid) == [41])
    }

    @Test("DerivedData 分类使用边界安全匹配")
    func derivedDataClassificationIsBoundarySafe() {
        let disguisedPath = "/Users/test/Library/Developer/Xcode/DerivedData/../NotDerived/rcmm.app"
        let plan = ExtensionCleanupPlanner.buildPlan(
            currentAppPath: currentApp,
            pluginKitExtensionPaths: [],
            discoveredAppPaths: [disguisedPath],
            runningProcesses: [],
            repositoryRoot: nil
        )

        #expect(plan.deleteCandidates.isEmpty)
        #expect(plan.skippedCandidates.map(\.appPath) == ["/Users/test/Library/Developer/Xcode/NotDerived/rcmm.app"])
        #expect(plan.skippedCandidates.map(\.skipReason) == ["该路径不在自动清理白名单内。"])
    }

    @Test("同一路径来自 pluginKit 和发现列表时只保留一个候选")
    func deduplicatesSameAppPathFromMultipleSources() {
        let plan = ExtensionCleanupPlanner.buildPlan(
            currentAppPath: currentApp,
            pluginKitExtensionPaths: [
                oldDerivedDataApp + "/Contents/PlugIns/RCMMFinderExtension.appex"
            ],
            discoveredAppPaths: [oldDerivedDataApp],
            runningProcesses: [],
            repositoryRoot: nil
        )

        #expect(plan.deleteCandidates.map(\.appPath) == [oldDerivedDataApp])
    }

    @Test("无效 extension 后缀不会产生候选")
    func ignoresInvalidExtensionSuffix() {
        let plan = ExtensionCleanupPlanner.buildPlan(
            currentAppPath: currentApp,
            pluginKitExtensionPaths: [
                oldDerivedDataApp + "/Contents/PlugIns/OtherExtension.appex"
            ],
            discoveredAppPaths: [],
            runningProcesses: [],
            repositoryRoot: nil
        )

        #expect(plan.deleteCandidates.isEmpty)
        #expect(plan.skippedCandidates.isEmpty)
    }

    @Test("DerivedData 中非 Debug rcmm.app 路径不会进入删除候选")
    func doesNotDeleteDerivedDataOutsideDebugRCMMApp() {
        let releaseApp = "/Users/test/Library/Developer/Xcode/DerivedData/rcmm-old/Build/Products/Release/rcmm.app"
        let plan = ExtensionCleanupPlanner.buildPlan(
            currentAppPath: currentApp,
            pluginKitExtensionPaths: [],
            discoveredAppPaths: [releaseApp],
            runningProcesses: [],
            repositoryRoot: nil
        )

        #expect(plan.deleteCandidates.isEmpty)
        #expect(plan.skippedCandidates.map(\.appPath) == [releaseApp])
        #expect(plan.skippedCandidates.map(\.skipReason) == ["该路径不在自动清理白名单内。"])
    }

    @Test("dev-release 目录下非 rcmm.app 目标不会进入删除候选")
    func doesNotDeleteDevReleaseDescendantsOutsideRCMMApp() {
        let nonAppPath = "/Users/test/work/rcmm/build/dev-release/dmg-root/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex"
        let plan = ExtensionCleanupPlanner.buildPlan(
            currentAppPath: currentApp,
            pluginKitExtensionPaths: [],
            discoveredAppPaths: [nonAppPath],
            runningProcesses: [],
            repositoryRoot: "/Users/test/work/rcmm"
        )

        #expect(plan.deleteCandidates.isEmpty)
        #expect(plan.skippedCandidates.map(\.appPath) == [nonAppPath])
        #expect(plan.skippedCandidates.map(\.skipReason) == ["该路径不在自动清理白名单内。"])
    }

    @Test("保守 fallback 不携带后置副作用命令")
    func conservativeFallbackHasNoPostCleanupCommands() {
        let misplacedSkip = ExtensionCleanupCandidate(
            appPath: oldDerivedDataApp,
            extensionPath: oldDerivedDataApp + "/Contents/PlugIns/RCMMFinderExtension.appex",
            source: .unsupported,
            disposition: .skip,
            skipReason: "skip"
        )
        let misplacedDelete = ExtensionCleanupCandidate(
            appPath: oldDevReleaseApp,
            extensionPath: oldDevReleaseApp + "/Contents/PlugIns/RCMMFinderExtension.appex",
            source: .devRelease,
            disposition: .delete,
            skipReason: nil
        )
        #expect(misplacedSkip != nil)
        #expect(misplacedDelete != nil)
        guard let misplacedSkip, let misplacedDelete else { return }

        let plan = ExtensionCleanupPlanner.makePlanOrSafeFallbackForTesting(
            currentAppPath: currentApp,
            deleteCandidates: [misplacedSkip],
            skippedCandidates: [misplacedDelete],
            processesToTerminate: []
        )

        #expect(plan.postCleanupCommands.isEmpty)
    }
}
