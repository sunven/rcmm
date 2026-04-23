import Foundation

public enum ExtensionCleanupPlanner {
    private static let finderExtensionSuffix = "/Contents/PlugIns/RCMMFinderExtension.appex"
    private static let devReleaseSegment = "/build/dev-release/"
    private static let devReleaseComponents = ["build", "dev-release"]
    private static let derivedDataComponents = ["Library", "Developer", "Xcode", "DerivedData"]
    private static let derivedDataDebugTailComponents = ["Build", "Products", "Debug", "rcmm.app"]
    private static let unsupportedReason = "该路径不在自动清理白名单内。"
    private static let missingRepositoryRootReason = "当前运行环境无法可靠识别仓库根目录。"

    public static func buildPlan(
        currentAppPath: String?,
        pluginKitExtensionPaths: [String],
        discoveredAppPaths: [String],
        runningProcesses: [ExtensionCleanupProcess],
        repositoryRoot: String?
    ) -> ExtensionCleanupPlan {
        let normalizedCurrentAppPath = currentAppPath.map(normalizePath(_:))
        let normalizedRepositoryRoot = repositoryRoot.map(normalizePath(_:))
        let normalizedRunningProcesses = runningProcesses.compactMap(normalizedProcess(_:))

        let pluginKitAppPaths = pluginKitExtensionPaths.compactMap(appPath(fromExtensionPath:))
        let discoveredNormalized = discoveredAppPaths.map(normalizePath(_:))
        let allAppPaths = sortedDeduplicatedPaths(pluginKitAppPaths + discoveredNormalized)
        let filteredAppPaths = allAppPaths.filter { path in
            guard let normalizedCurrentAppPath else { return true }
            return path != normalizedCurrentAppPath
        }

        var deleteCandidates: [ExtensionCleanupCandidate] = []
        var skippedCandidates: [ExtensionCleanupCandidate] = []
        var deletableAppPaths = Set<String>()

        for appPath in filteredAppPaths {
            switch classify(appPath: appPath, repositoryRoot: normalizedRepositoryRoot) {
            case .derivedData:
                if let candidate = makeCandidate(
                    appPath: appPath,
                    source: .derivedData,
                    disposition: .delete,
                    skipReason: nil
                ) {
                    deleteCandidates.append(candidate)
                    deletableAppPaths.insert(appPath)
                }
            case .devRelease:
                if let candidate = makeCandidate(
                    appPath: appPath,
                    source: .devRelease,
                    disposition: .delete,
                    skipReason: nil
                ) {
                    deleteCandidates.append(candidate)
                    deletableAppPaths.insert(appPath)
                }
            case .unsupported:
                let reason = skipReason(for: appPath, repositoryRoot: normalizedRepositoryRoot)
                if let candidate = makeCandidate(
                    appPath: appPath,
                    source: .unsupported,
                    disposition: .skip,
                    skipReason: reason
                ) {
                    skippedCandidates.append(candidate)
                }
            }
        }

        let processesToTerminate = normalizedRunningProcesses
            .filter { deletableAppPaths.contains($0.appPath) }
            .sorted { lhs, rhs in
                if lhs.pid == rhs.pid {
                    return lhs.appPath < rhs.appPath
                }
                return lhs.pid < rhs.pid
            }

        return makePlanOrSafeFallback(
            currentAppPath: normalizedCurrentAppPath,
            deleteCandidates: deleteCandidates,
            skippedCandidates: skippedCandidates,
            processesToTerminate: processesToTerminate
        )
    }

    private static let postCleanupCommands: [String] = [
        "pluginkit -e use -i com.sunven.rcmm.FinderExtension",
        "killall Finder"
    ]

    private enum AppClassification {
        case derivedData
        case devRelease
        case unsupported
    }

    private static func appPath(fromExtensionPath extensionPath: String) -> String? {
        let normalizedExtensionPath = normalizePath(extensionPath)
        guard normalizedExtensionPath.hasSuffix(finderExtensionSuffix) else {
            return nil
        }
        return String(normalizedExtensionPath.dropLast(finderExtensionSuffix.count))
    }

    private static func sortedDeduplicatedPaths(_ paths: [String]) -> [String] {
        Array(Set(paths)).sorted()
    }

    private static func classify(appPath: String, repositoryRoot: String?) -> AppClassification {
        if isAllowedDerivedDataDebugApp(appPath) {
            return .derivedData
        }

        if let repositoryRoot,
           isAllowedDevReleaseApp(appPath, repositoryRoot: repositoryRoot) {
            return .devRelease
        }

        return .unsupported
    }

    private static func skipReason(for appPath: String, repositoryRoot: String?) -> String {
        if repositoryRoot == nil, appPath.contains(devReleaseSegment) {
            return missingRepositoryRootReason
        }
        return unsupportedReason
    }

    private static func makeCandidate(
        appPath: String,
        source: ExtensionCleanupCandidateSource,
        disposition: ExtensionCleanupCandidateDisposition,
        skipReason: String?
    ) -> ExtensionCleanupCandidate? {
        ExtensionCleanupCandidate(
            appPath: appPath,
            extensionPath: appPath + finderExtensionSuffix,
            source: source,
            disposition: disposition,
            skipReason: skipReason
        )
    }

    private static func makePlanOrSafeFallback(
        currentAppPath: String?,
        deleteCandidates: [ExtensionCleanupCandidate],
        skippedCandidates: [ExtensionCleanupCandidate],
        processesToTerminate: [ExtensionCleanupProcess]
    ) -> ExtensionCleanupPlan {
        makePlanOrSafeFallback(
            currentAppPath: currentAppPath,
            deleteCandidates: deleteCandidates,
            skippedCandidates: skippedCandidates,
            processesToTerminate: processesToTerminate,
            emitDebugSignal: true
        )
    }

    private static func makePlanOrSafeFallback(
        currentAppPath: String?,
        deleteCandidates: [ExtensionCleanupCandidate],
        skippedCandidates: [ExtensionCleanupCandidate],
        processesToTerminate: [ExtensionCleanupProcess],
        emitDebugSignal: Bool
    ) -> ExtensionCleanupPlan {
        if let plan = ExtensionCleanupPlan(
            currentAppPath: currentAppPath,
            deleteCandidates: deleteCandidates,
            skippedCandidates: skippedCandidates,
            processesToTerminate: processesToTerminate,
            postCleanupCommands: postCleanupCommands
        ) {
            return plan
        }

        if emitDebugSignal {
            assertionFailure("Unexpected cleanup plan invariant failure. Returning conservative fallback plan.")
        }

        let sanitizedDelete = deleteCandidates.filter { $0.disposition == .delete }
        let sanitizedSkipped = skippedCandidates.filter { $0.disposition == .skip }
        if let sanitizedPlan = ExtensionCleanupPlan(
            currentAppPath: currentAppPath,
            deleteCandidates: sanitizedDelete,
            skippedCandidates: sanitizedSkipped,
            processesToTerminate: processesToTerminate,
            postCleanupCommands: []
        ) {
            return sanitizedPlan
        }

        return ExtensionCleanupPlan(
            uncheckedCurrentAppPath: currentAppPath,
            deleteCandidates: [],
            skippedCandidates: [],
            processesToTerminate: [],
            postCleanupCommands: []
        )
    }

    static func makePlanOrSafeFallbackForTesting(
        currentAppPath: String?,
        deleteCandidates: [ExtensionCleanupCandidate],
        skippedCandidates: [ExtensionCleanupCandidate],
        processesToTerminate: [ExtensionCleanupProcess]
    ) -> ExtensionCleanupPlan {
        makePlanOrSafeFallback(
            currentAppPath: currentAppPath,
            deleteCandidates: deleteCandidates,
            skippedCandidates: skippedCandidates,
            processesToTerminate: processesToTerminate,
            emitDebugSignal: false
        )
    }

    private static func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func normalizedProcess(_ process: ExtensionCleanupProcess) -> ExtensionCleanupProcess? {
        ExtensionCleanupProcess(pid: process.pid, appPath: normalizePath(process.appPath))
    }

    private static func isAllowedDerivedDataDebugApp(_ appPath: String) -> Bool {
        let components = appPath.split(separator: "/").map(String.init)
        let prefixCount = derivedDataComponents.count
        let tailCount = derivedDataDebugTailComponents.count
        let minimumCount = prefixCount + 1 + tailCount // +1 for DerivedData build folder name
        guard components.count >= minimumCount else { return false }

        let lastPrefixStart = components.count - (prefixCount + 1 + tailCount)
        for startIndex in 0...lastPrefixStart {
            let prefixEnd = startIndex + prefixCount
            if Array(components[startIndex..<prefixEnd]) != derivedDataComponents {
                continue
            }

            let tailStart = prefixEnd + 1
            let tailEnd = tailStart + tailCount
            if tailEnd == components.count,
               Array(components[tailStart..<tailEnd]) == derivedDataDebugTailComponents {
                return true
            }
        }

        return false
    }

    private static func isAllowedDevReleaseApp(_ appPath: String, repositoryRoot: String) -> Bool {
        let appComponents = appPath.split(separator: "/").map(String.init)
        let rootComponents = repositoryRoot.split(separator: "/").map(String.init)
        let prefix = rootComponents + devReleaseComponents
        guard appComponents.count >= prefix.count + 2 else { return false }
        guard Array(appComponents.prefix(prefix.count)) == prefix else { return false }
        guard appComponents.last == "rcmm.app" else { return false }
        return true
    }
}

private extension ExtensionCleanupPlan {
    init(
        uncheckedCurrentAppPath: String?,
        deleteCandidates: [ExtensionCleanupCandidate],
        skippedCandidates: [ExtensionCleanupCandidate],
        processesToTerminate: [ExtensionCleanupProcess],
        postCleanupCommands: [String]
    ) {
        self.currentAppPath = uncheckedCurrentAppPath
        self.deleteCandidates = deleteCandidates
        self.skippedCandidates = skippedCandidates
        self.processesToTerminate = processesToTerminate
        self.postCleanupCommands = postCleanupCommands
    }
}
