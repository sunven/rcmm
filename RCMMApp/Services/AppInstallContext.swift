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
