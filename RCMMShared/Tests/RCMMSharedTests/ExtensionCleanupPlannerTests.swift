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
