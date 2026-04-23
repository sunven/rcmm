import Foundation

public enum ExtensionCleanupPlanner {
    private static let finderExtensionSuffix = "/Contents/PlugIns/RCMMFinderExtension.appex"
    private static let devReleaseSegment = "/build/dev-release/"
    private static let unsupportedReason = "该路径不在自动清理白名单内。"
    private static let missingRepositoryRootReason = "当前运行环境无法可靠识别仓库根目录。"

    public static func buildPlan(
        currentAppPath: String?,
        pluginKitExtensionPaths: [String],
        discoveredAppPaths: [String],
        runningProcesses: [ExtensionCleanupProcess],
        repositoryRoot: String?
    ) -> ExtensionCleanupPlan {
        let pluginKitAppPaths = pluginKitExtensionPaths.compactMap(appPath(fromExtensionPath:))
        let allAppPaths = sortedDeduplicatedPaths(pluginKitAppPaths + discoveredAppPaths)
        let filteredAppPaths = allAppPaths.filter { path in
            guard let currentAppPath else { return true }
            return path != currentAppPath
        }

        var deleteCandidates: [ExtensionCleanupCandidate] = []
        var skippedCandidates: [ExtensionCleanupCandidate] = []
        var deletableAppPaths = Set<String>()

        for appPath in filteredAppPaths {
            switch classify(appPath: appPath, repositoryRoot: repositoryRoot) {
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
                let reason = skipReason(for: appPath, repositoryRoot: repositoryRoot)
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

        let processesToTerminate = runningProcesses
            .filter { deletableAppPaths.contains($0.appPath) }
            .sorted { lhs, rhs in
                if lhs.pid == rhs.pid {
                    return lhs.appPath < rhs.appPath
                }
                return lhs.pid < rhs.pid
            }

        return makePlanOrSafeFallback(
            currentAppPath: currentAppPath,
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
        guard extensionPath.hasSuffix(finderExtensionSuffix) else {
            return nil
        }
        return String(extensionPath.dropLast(finderExtensionSuffix.count))
    }

    private static func sortedDeduplicatedPaths(_ paths: [String]) -> [String] {
        Array(Set(paths)).sorted()
    }

    private static func classify(appPath: String, repositoryRoot: String?) -> AppClassification {
        if appPath.contains("/Library/Developer/Xcode/DerivedData/") {
            return .derivedData
        }

        if let repositoryRoot,
           appPath.hasPrefix(repositoryRoot + devReleaseSegment) {
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
        if let plan = ExtensionCleanupPlan(
            currentAppPath: currentAppPath,
            deleteCandidates: deleteCandidates,
            skippedCandidates: skippedCandidates,
            processesToTerminate: processesToTerminate,
            postCleanupCommands: postCleanupCommands
        ) {
            return plan
        }

        let sanitizedDelete = deleteCandidates.filter { $0.disposition == .delete }
        let sanitizedSkipped = skippedCandidates.filter { $0.disposition == .skip }
        if let sanitizedPlan = ExtensionCleanupPlan(
            currentAppPath: currentAppPath,
            deleteCandidates: sanitizedDelete,
            skippedCandidates: sanitizedSkipped,
            processesToTerminate: processesToTerminate,
            postCleanupCommands: postCleanupCommands
        ) {
            return sanitizedPlan
        }

        return ExtensionCleanupPlan(
            uncheckedCurrentAppPath: currentAppPath,
            deleteCandidates: [],
            skippedCandidates: [],
            processesToTerminate: [],
            postCleanupCommands: postCleanupCommands
        )
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
