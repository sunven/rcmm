import Foundation

public enum ExtensionInstallHealthResolver {
    public static func resolve(
        currentExtensionPath: String?,
        currentProcessExtensionEnabled: Bool,
        pluginKitOutput: String?
    ) -> ExtensionInstallHealth {
        let normalizedCurrentExtensionPath = currentExtensionPath.map(normalizePath(_:))

        if let pluginKitOutput {
            let enabledPaths = enabledExtensionPaths(from: pluginKitOutput)

            if enabledPaths.count > 1 {
                return ExtensionInstallHealth(
                    status: .otherInstallationEnabled,
                    currentExtensionPath: normalizedCurrentExtensionPath,
                    enabledExtensionPaths: enabledPaths
                )
            }

            if let normalizedCurrentExtensionPath,
               enabledPaths.contains(normalizedCurrentExtensionPath) {
                return ExtensionInstallHealth(
                    status: .enabled,
                    currentExtensionPath: normalizedCurrentExtensionPath,
                    enabledExtensionPaths: enabledPaths
                )
            }

            if !enabledPaths.isEmpty {
                return ExtensionInstallHealth(
                    status: .otherInstallationEnabled,
                    currentExtensionPath: normalizedCurrentExtensionPath,
                    enabledExtensionPaths: enabledPaths
                )
            }

            return ExtensionInstallHealth(
                status: .disabled,
                currentExtensionPath: normalizedCurrentExtensionPath,
                enabledExtensionPaths: []
            )
        }

        if currentProcessExtensionEnabled {
            return ExtensionInstallHealth(
                status: .enabled,
                currentExtensionPath: normalizedCurrentExtensionPath,
                enabledExtensionPaths: []
            )
        }

        return ExtensionInstallHealth(
            status: .unknown,
            currentExtensionPath: normalizedCurrentExtensionPath,
            enabledExtensionPaths: []
        )
    }

    public static func enabledExtensionPaths(from pluginKitOutput: String) -> [String] {
        let paths = pluginKitOutput
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine -> String? in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard line.first == "+" else { return nil }
                guard let rawPath = line
                    .split(separator: "\t")
                    .last
                    .map(String.init)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !rawPath.isEmpty
                else {
                    return nil
                }
                return normalizePath(rawPath)
            }

        var deduplicated: [String] = []
        for path in paths where !deduplicated.contains(path) {
            deduplicated.append(path)
        }
        return deduplicated
    }

    private static func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
