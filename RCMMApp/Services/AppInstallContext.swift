import Foundation

struct AppInstallContext: Sendable {
    let currentAppPath: String
    let repositoryRoot: String?

    static func current(bundle: Bundle = .main) -> AppInstallContext {
        let repositoryRootValue = bundle.object(
            forInfoDictionaryKey: "RCMMRepositoryRoot"
        ) as? String

        let repositoryRoot = validatedRepositoryRoot(
            repositoryRootValue,
            bundle: bundle
        )

        return AppInstallContext(
            currentAppPath: bundle.bundleURL.path,
            repositoryRoot: repositoryRoot
        )
    }

    private static func validatedRepositoryRoot(
        _ value: String?,
        bundle: Bundle
    ) -> String? {
        guard isDevBuild(bundle: bundle) else {
            return nil
        }

        guard let path = value?.nilIfBlank else {
            return nil
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        let normalizedPath = (expandedPath as NSString).standardizingPath
        guard (normalizedPath as NSString).isAbsolutePath,
              FileManager.default.directoryExists(atPath: normalizedPath) else {
            return nil
        }

        return normalizedPath
    }

    private static func isDevBuild(bundle: Bundle) -> Bool {
        guard
            let displayVersion = bundle.object(
                forInfoDictionaryKey: "RCMMDisplayVersion"
            ) as? String
        else {
            return false
        }

        return displayVersion.localizedCaseInsensitiveContains("dev")
    }
}

private extension FileManager {
    func directoryExists(atPath path: String) -> Bool {
        var isDirectory = ObjCBool(false)
        guard fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }

        return isDirectory.boolValue
    }
}
