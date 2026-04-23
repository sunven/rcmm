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
        let candidate = makeCandidate(
            appPath: "/tmp/old-1/rcmm.app",
            extensionPath: "/tmp/old-1/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex",
            source: .derivedData,
            disposition: .delete,
            skipReason: nil
        )
        let plan = ExtensionCleanupPlan(
            currentAppPath: "/current/rcmm.app",
            deleteCandidates: [
                candidate!
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

        #expect(candidate != nil)
        #expect(plan != nil)
        #expect(plan?.hasWork == true)
        #expect(plan?.summary == "发现 1 个旧副本，会结束 1 个旧 rcmm 进程，并在清理后自动切回当前扩展、重启 Finder。")
    }

    @Test("清理计划无工作时摘要不承诺后续动作")
    func planSummaryNoWork() {
        let plan = ExtensionCleanupPlan(
            currentAppPath: "/current/rcmm.app",
            deleteCandidates: [],
            skippedCandidates: [],
            processesToTerminate: [],
            postCleanupCommands: []
        )

        #expect(plan != nil)
        #expect(plan?.hasWork == false)
        #expect(plan?.summary == "未发现可自动清理的旧副本或旧 rcmm 进程。")
    }

    @Test("清理计划缺少后置命令时摘要不承诺切换扩展")
    func planSummaryWithoutPostCommands() {
        let candidate = makeCandidate(
            appPath: "/tmp/old-1/rcmm.app",
            extensionPath: "/tmp/old-1/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex",
            source: .derivedData,
            disposition: .delete,
            skipReason: nil
        )
        let plan = ExtensionCleanupPlan(
            currentAppPath: "/current/rcmm.app",
            deleteCandidates: [candidate!],
            skippedCandidates: [],
            processesToTerminate: [ExtensionCleanupProcess(pid: 42, appPath: "/tmp/old-1/rcmm.app")],
            postCleanupCommands: []
        )

        #expect(candidate != nil)
        #expect(plan != nil)
        #expect(plan?.summary == "发现 1 个旧副本，会结束 1 个旧 rcmm 进程。")
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

        #expect(result != nil)
        #expect(result?.outcome == .noOp)
        #expect(result?.followUpAdvice == ["当前目录不在自动清理白名单内。"])
    }

    @Test("清理计划拒绝分组与 disposition 不一致的数据")
    func planRejectsInconsistentDispositionBuckets() {
        let skipCandidate = makeCandidate(
            appPath: "/tmp/old-2/rcmm.app",
            extensionPath: "/tmp/old-2/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex",
            source: .derivedData,
            disposition: .skip,
            skipReason: "not allowed"
        )
        let deleteCandidate = makeCandidate(
            appPath: "/tmp/old-3/rcmm.app",
            extensionPath: "/tmp/old-3/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex",
            source: .derivedData,
            disposition: .delete,
            skipReason: nil
        )
        let invalidDeleteBucket = ExtensionCleanupPlan(
            currentAppPath: "/current/rcmm.app",
            deleteCandidates: [
                skipCandidate!
            ],
            skippedCandidates: [],
            processesToTerminate: [],
            postCleanupCommands: []
        )
        let invalidSkippedBucket = ExtensionCleanupPlan(
            currentAppPath: "/current/rcmm.app",
            deleteCandidates: [],
            skippedCandidates: [
                deleteCandidate!
            ],
            processesToTerminate: [],
            postCleanupCommands: []
        )

        #expect(skipCandidate != nil)
        #expect(deleteCandidate != nil)
        #expect(invalidDeleteBucket == nil)
        #expect(invalidSkippedBucket == nil)
    }

    @Test("成功和无操作结果不允许携带失败步骤")
    func resultRejectsFailedStepForSuccessAndNoOp() {
        let invalidSuccess = ExtensionCleanupResult(
            outcome: .success,
            completedSteps: [.terminateProcesses, .deleteApps],
            failedStep: .restartFinder,
            deletedAppPaths: ["/tmp/old-1/rcmm.app"],
            terminatedProcessIDs: [42],
            message: "清理完成。",
            followUpAdvice: []
        )
        let invalidNoOp = ExtensionCleanupResult(
            outcome: .noOp,
            completedSteps: [],
            failedStep: .recheckHealth,
            deletedAppPaths: [],
            terminatedProcessIDs: [],
            message: "无需清理。",
            followUpAdvice: []
        )

        #expect(invalidSuccess == nil)
        #expect(invalidNoOp == nil)
    }

    @Test("noOp 结果不能包含已完成步骤或执行副作用")
    func resultRejectsNoOpWithProgress() {
        let invalidNoOpWithSteps = ExtensionCleanupResult(
            outcome: .noOp,
            completedSteps: [.recheckHealth],
            failedStep: nil,
            deletedAppPaths: [],
            terminatedProcessIDs: [],
            message: "无需清理。",
            followUpAdvice: []
        )
        let invalidNoOpWithEffects = ExtensionCleanupResult(
            outcome: .noOp,
            completedSteps: [],
            failedStep: nil,
            deletedAppPaths: ["/tmp/old-1/rcmm.app"],
            terminatedProcessIDs: [42],
            message: "无需清理。",
            followUpAdvice: []
        )

        #expect(invalidNoOpWithSteps == nil)
        #expect(invalidNoOpWithEffects == nil)
    }

    @Test("partialSuccess 结果必须包含失败步骤")
    func resultRejectsPartialSuccessWithoutFailedStep() {
        let invalidPartial = ExtensionCleanupResult(
            outcome: .partialSuccess,
            completedSteps: [.terminateProcesses],
            failedStep: nil,
            deletedAppPaths: [],
            terminatedProcessIDs: [42],
            message: "部分成功。",
            followUpAdvice: []
        )

        #expect(invalidPartial == nil)
    }

    @Test("候选项拒绝不一致的 disposition/source/skipReason 组合")
    func candidateRejectsInconsistentCombinations() {
        let invalidDeleteWithReason = makeCandidate(
            appPath: "/tmp/old-1/rcmm.app",
            extensionPath: "/tmp/old-1/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex",
            source: .derivedData,
            disposition: .delete,
            skipReason: "should not exist"
        )
        let invalidUnsupportedDelete = makeCandidate(
            appPath: "/tmp/old-2/rcmm.app",
            extensionPath: "/tmp/old-2/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex",
            source: .unsupported,
            disposition: .delete,
            skipReason: nil
        )
        let invalidSkipWithoutReason = makeCandidate(
            appPath: "/tmp/old-3/rcmm.app",
            extensionPath: "/tmp/old-3/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex",
            source: .pluginKit,
            disposition: .skip,
            skipReason: nil
        )

        #expect(invalidDeleteWithReason == nil)
        #expect(invalidUnsupportedDelete == nil)
        #expect(invalidSkipWithoutReason == nil)
    }

    @Test("候选项 id 同时包含 appPath 和 extensionPath")
    func candidateIDIncludesExtensionPath() {
        let candidate = makeCandidate(
            appPath: "/tmp/old-1/rcmm.app",
            extensionPath: "/tmp/old-1/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex",
            source: .derivedData,
            disposition: .delete,
            skipReason: nil
        )

        #expect(candidate != nil)
        #expect(candidate?.id == "/tmp/old-1/rcmm.app#/tmp/old-1/rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex")
    }

    private func makeCandidate(
        appPath: String,
        extensionPath: String,
        source: ExtensionCleanupCandidateSource,
        disposition: ExtensionCleanupCandidateDisposition,
        skipReason: String?
    ) -> ExtensionCleanupCandidate? {
        ExtensionCleanupCandidate(
            appPath: appPath,
            extensionPath: extensionPath,
            source: source,
            disposition: disposition,
            skipReason: skipReason
        )
    }
}
