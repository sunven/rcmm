import Darwin
import Foundation
import os.log
import RCMMShared

enum ExtensionCleanupServiceError: Error {
    case terminateFailed(Int32, String)
    case deleteFailed(String, String)
    case commandFailed(ExtensionCleanupStep, String)
}

final class ExtensionCleanupService {
    private static let extensionBundleID = "com.sunven.rcmm.FinderExtension"
    private static let extensionRelativePath = "Contents/PlugIns/RCMMFinderExtension.appex"
    private static let executableSuffix = "/Contents/MacOS/rcmm"

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
        let runningProcesses = discoverRunningProcesses(currentAppPath: installContext.currentAppPath)

        return ExtensionCleanupPlanner.buildPlan(
            currentAppPath: installContext.currentAppPath,
            pluginKitExtensionPaths: PluginKitService.enabledExtensionPaths(),
            discoveredAppPaths: discoveredApps,
            runningProcesses: runningProcesses,
            repositoryRoot: installContext.repositoryRoot
        )
    }

    func execute(
        plan: ExtensionCleanupPlan,
        progress: @escaping @Sendable (ExtensionCleanupStep) -> Void
    ) -> ExtensionCleanupResult {
        guard plan.hasWork else {
            if let result = ExtensionCleanupResult(
                outcome: .noOp,
                completedSteps: [],
                failedStep: nil,
                deletedAppPaths: [],
                terminatedProcessIDs: [],
                message: "未发现可自动清理的旧副本。",
                followUpAdvice: ["当前目录不在自动清理白名单内。"]
            ) {
                return result
            }

            logger.error("构建 noOp 清理结果失败，回退为保守 partialSuccess 结果。")
            return makeResult(
                outcome: .partialSuccess,
                completedSteps: [],
                failedStep: .recheckHealth,
                deletedAppPaths: [],
                terminatedProcessIDs: [],
                message: "未发现可自动清理的旧副本。",
                followUpAdvice: ["当前目录不在自动清理白名单内。"]
            )
        }

        var completedSteps: [ExtensionCleanupStep] = []
        var deletedPaths: [String] = []
        var terminatedPIDs: [Int32] = []
        var currentStep: ExtensionCleanupStep?
        let runtimeContext = AppInstallContext.current()

        do {
            currentStep = .terminateProcesses
            progress(.terminateProcesses)
            for process in plan.processesToTerminate {
                try terminate(process: process)
                terminatedPIDs.append(process.pid)
            }
            completedSteps.append(.terminateProcesses)

            currentStep = .deleteApps
            progress(.deleteApps)
            for candidate in plan.deleteCandidates {
                guard isDeletePathAllowed(candidate.appPath, installContext: runtimeContext) else {
                    throw ExtensionCleanupServiceError.deleteFailed(
                        candidate.appPath,
                        "路径不在自动清理白名单内。"
                    )
                }
                guard fileManager.fileExists(atPath: candidate.appPath) else { continue }
                do {
                    try fileManager.removeItem(atPath: candidate.appPath)
                    deletedPaths.append(candidate.appPath)
                } catch {
                    throw ExtensionCleanupServiceError.deleteFailed(candidate.appPath, error.localizedDescription)
                }
            }
            completedSteps.append(.deleteApps)

            currentStep = .switchExtension
            progress(.switchExtension)
            try run(
                step: .switchExtension,
                executable: URL(fileURLWithPath: "/usr/bin/pluginkit"),
                arguments: ["-e", "use", "-i", Self.extensionBundleID]
            )
            completedSteps.append(.switchExtension)

            currentStep = .restartFinder
            progress(.restartFinder)
            try run(
                step: .restartFinder,
                executable: URL(fileURLWithPath: "/usr/bin/killall"),
                arguments: ["Finder"]
            )
            completedSteps.append(.restartFinder)

            currentStep = .recheckHealth
            progress(.recheckHealth)
            completedSteps.append(.recheckHealth)
            currentStep = nil

            return makeResult(
                outcome: .success,
                completedSteps: completedSteps,
                failedStep: nil,
                deletedAppPaths: deletedPaths,
                terminatedProcessIDs: terminatedPIDs,
                message: "旧扩展副本清理完成。",
                followUpAdvice: []
            )
        } catch let serviceError as ExtensionCleanupServiceError {
            let hasCompletedWork = !completedSteps.isEmpty || !deletedPaths.isEmpty || !terminatedPIDs.isEmpty
            if !hasCompletedWork {
                return makeNoOpResult(
                    message: failureMessage(for: serviceError),
                    followUpAdvice: followUpAdvice(for: serviceError)
                )
            }

            let failedStep = failedStep(for: serviceError) ?? currentStep ?? .recheckHealth
            return makeResult(
                outcome: .partialSuccess,
                completedSteps: completedSteps,
                failedStep: failedStep,
                deletedAppPaths: deletedPaths,
                terminatedProcessIDs: terminatedPIDs,
                message: failureMessage(for: serviceError),
                followUpAdvice: followUpAdvice(for: serviceError)
            )
        } catch {
            let hasCompletedWork = !completedSteps.isEmpty || !deletedPaths.isEmpty || !terminatedPIDs.isEmpty
            if !hasCompletedWork {
                return makeNoOpResult(
                    message: "清理过程中发生未知错误：\(error.localizedDescription)",
                    followUpAdvice: ["请重新打开 rcmm 后重试。"]
                )
            }

            let failedStep = currentStep ?? .recheckHealth
            return makeResult(
                outcome: .partialSuccess,
                completedSteps: completedSteps,
                failedStep: failedStep,
                deletedAppPaths: deletedPaths,
                terminatedProcessIDs: terminatedPIDs,
                message: "清理过程中发生未知错误：\(error.localizedDescription)",
                followUpAdvice: ["请重新打开 rcmm 后重试。"]
            )
        }
    }

    private func discoverDerivedDataApps() -> [String] {
        let root = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("Xcode", isDirectory: true)
            .appendingPathComponent("DerivedData", isDirectory: true)
        return discoverRcmmApps(under: root)
    }

    private func discoverDevReleaseApps(repositoryRoot: String?) -> [String] {
        guard let repositoryRoot else { return [] }
        let root = URL(fileURLWithPath: repositoryRoot, isDirectory: true)
            .appendingPathComponent("build", isDirectory: true)
            .appendingPathComponent("dev-release", isDirectory: true)
        return discoverRcmmApps(under: root)
    }

    private func discoverRcmmApps(under root: URL) -> [String] {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var paths = Set<String>()
        while let url = enumerator?.nextObject() as? URL {
            guard url.lastPathComponent == "rcmm.app" else { continue }

            let extensionURL = url.appendingPathComponent(Self.extensionRelativePath, isDirectory: true)
            guard fileManager.fileExists(atPath: extensionURL.path) else { continue }

            paths.insert(normalizePath(url.path))
            enumerator?.skipDescendants()
        }

        return paths.sorted()
    }

    private func isDeletePathAllowed(
        _ appPath: String,
        installContext: AppInstallContext
    ) -> Bool {
        let normalizedAppPath = normalizePath(appPath)
        let validationPlan = ExtensionCleanupPlanner.buildPlan(
            currentAppPath: installContext.currentAppPath,
            pluginKitExtensionPaths: [],
            discoveredAppPaths: [normalizedAppPath],
            runningProcesses: [],
            repositoryRoot: installContext.repositoryRoot
        )

        return validationPlan.deleteCandidates.contains { candidate in
            candidate.appPath == normalizedAppPath
        }
    }

    private func discoverRunningProcesses(currentAppPath: String) -> [ExtensionCleanupProcess] {
        let normalizedCurrentAppPath = normalizePath(currentAppPath)
        let result: SystemCommandResult
        do {
            result = try commandRunner.run(
                executable: URL(fileURLWithPath: "/bin/ps"),
                arguments: ["-axo", "pid=,comm="]
            )
        } catch {
            logger.error("读取进程列表失败: \(error.localizedDescription)")
            return []
        }

        guard result.terminationStatus == 0 else {
            logger.error("读取进程列表失败，退出码: \(result.terminationStatus)")
            return []
        }

        var seenKeys = Set<String>()
        var processes: [ExtensionCleanupProcess] = []
        for line in result.stdout.split(whereSeparator: \.isNewline) {
            guard let process = parseProcess(line: line) else { continue }
            guard process.appPath != normalizedCurrentAppPath else { continue }
            let key = "\(process.pid)#\(process.appPath)"
            guard seenKeys.insert(key).inserted else { continue }
            processes.append(process)
        }

        return processes.sorted { lhs, rhs in
            if lhs.pid == rhs.pid {
                return lhs.appPath < rhs.appPath
            }
            return lhs.pid < rhs.pid
        }
    }

    private func parseProcess(line: Substring) -> ExtensionCleanupProcess? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else { return nil }

        let parts = trimmedLine.split(maxSplits: 1, whereSeparator: \.isWhitespace)
        guard parts.count == 2 else { return nil }
        guard let pid = Int32(parts[0]), pid > 0 else { return nil }

        let executablePath = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard executablePath.hasSuffix(Self.executableSuffix) else { return nil }

        let appPath = String(executablePath.dropLast(Self.executableSuffix.count))
        return ExtensionCleanupProcess(
            pid: pid,
            appPath: normalizePath(appPath)
        )
    }

    private func terminate(process: ExtensionCleanupProcess) throws {
        logger.info("结束旧进程: pid=\(process.pid), app=\(process.appPath)")

        if kill(process.pid, SIGTERM) == -1, errno != ESRCH {
            throw ExtensionCleanupServiceError.terminateFailed(process.pid, strerrorDescription())
        }

        usleep(300_000)

        guard isProcessAlive(process.pid) else { return }

        if kill(process.pid, SIGKILL) == -1, errno != ESRCH {
            throw ExtensionCleanupServiceError.terminateFailed(process.pid, strerrorDescription())
        }

        usleep(150_000)

        if isProcessAlive(process.pid) {
            throw ExtensionCleanupServiceError.terminateFailed(process.pid, "发送 SIGKILL 后进程仍在运行")
        }
    }

    private func run(
        step: ExtensionCleanupStep,
        executable: URL,
        arguments: [String]
    ) throws {
        let result: SystemCommandResult
        do {
            result = try commandRunner.run(executable: executable, arguments: arguments)
        } catch {
            throw ExtensionCleanupServiceError.commandFailed(step, error.localizedDescription)
        }

        guard result.terminationStatus == 0 else {
            let output = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackOutput = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = output.isEmpty
                ? (fallbackOutput.isEmpty ? "命令返回退出码 \(result.terminationStatus)。" : fallbackOutput)
                : output
            throw ExtensionCleanupServiceError.commandFailed(step, detail)
        }
    }

    private func failedStep(for error: ExtensionCleanupServiceError) -> ExtensionCleanupStep? {
        switch error {
        case .terminateFailed:
            return .terminateProcesses
        case .deleteFailed:
            return .deleteApps
        case .commandFailed(let step, _):
            return step
        }
    }

    private func failureMessage(for error: ExtensionCleanupServiceError) -> String {
        switch error {
        case .terminateFailed(let pid, let detail):
            return "结束旧进程失败：pid \(pid) — \(detail)"
        case .deleteFailed(let path, let detail):
            return "删除旧副本失败：\(path) — \(detail)"
        case .commandFailed(_, let detail):
            return "自动清理未完全完成：\(detail)"
        }
    }

    private func followUpAdvice(for error: ExtensionCleanupServiceError) -> [String] {
        switch error {
        case .commandFailed(.switchExtension, _):
            return ["请手动执行 `pluginkit -e use -i com.sunven.rcmm.FinderExtension` 后重新检测。"]
        case .commandFailed(.restartFinder, _):
            return ["请手动执行 `killall Finder` 后重新检测。"]
        case .terminateFailed:
            return ["请手动结束残留 rcmm 进程后重试。"]
        case .deleteFailed:
            return ["请确认旧 rcmm 已退出，或手动删除仍残留的路径后重试。"]
        case .commandFailed:
            return ["请重新打开 rcmm 后重试。"]
        }
    }

    private func makeNoOpResult(message: String, followUpAdvice: [String]) -> ExtensionCleanupResult {
        if let result = ExtensionCleanupResult(
            outcome: .noOp,
            completedSteps: [],
            failedStep: nil,
            deletedAppPaths: [],
            terminatedProcessIDs: [],
            message: message,
            followUpAdvice: followUpAdvice
        ) {
            return result
        }

        logger.error("构建 noOp 清理结果失败，回退为保守 partialSuccess 结果。")
        return makeResult(
            outcome: .partialSuccess,
            completedSteps: [],
            failedStep: .recheckHealth,
            deletedAppPaths: [],
            terminatedProcessIDs: [],
            message: message,
            followUpAdvice: followUpAdvice
        )
    }

    private func makeResult(
        outcome: ExtensionCleanupOutcome,
        completedSteps: [ExtensionCleanupStep],
        failedStep: ExtensionCleanupStep?,
        deletedAppPaths: [String],
        terminatedProcessIDs: [Int32],
        message: String,
        followUpAdvice: [String]
    ) -> ExtensionCleanupResult {
        if let result = ExtensionCleanupResult(
            outcome: outcome,
            completedSteps: completedSteps,
            failedStep: failedStep,
            deletedAppPaths: deletedAppPaths,
            terminatedProcessIDs: terminatedProcessIDs,
            message: message,
            followUpAdvice: followUpAdvice
        ) {
            return result
        }

        logger.error("构建清理结果失败，回退为保守 partialSuccess 结果。")
        if let fallback = ExtensionCleanupResult(
            outcome: .partialSuccess,
            completedSteps: completedSteps,
            failedStep: failedStep ?? .recheckHealth,
            deletedAppPaths: deletedAppPaths,
            terminatedProcessIDs: terminatedProcessIDs,
            message: message,
            followUpAdvice: followUpAdvice
        ) {
            return fallback
        }

        return makeNoOpResult(
            message: message,
            followUpAdvice: followUpAdvice
        )
    }

    private func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private func isProcessAlive(_ pid: Int32) -> Bool {
        if kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM
    }

    private func strerrorDescription() -> String {
        let code = errno
        return String(cString: strerror(code))
    }
}
