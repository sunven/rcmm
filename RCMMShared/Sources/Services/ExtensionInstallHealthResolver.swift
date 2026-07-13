import Foundation

public enum ExtensionInstallHealthResolver {
    public static func resolve(
        currentExtensionPath: String?,
        currentProcessExtensionEnabled: Bool,
        pluginKitOutput: String?,
        siblingPluginKitOutput: String? = nil
    ) -> ExtensionInstallHealth {
        let normalizedCurrentExtensionPath = currentExtensionPath.map(normalizePath(_:))
        let siblingEnabledPaths = siblingPluginKitOutput.map(enabledExtensionPaths(from:)) ?? []

        if !siblingEnabledPaths.isEmpty {
            let currentEnabledPaths = pluginKitOutput.map(enabledExtensionPaths(from:)) ?? []
            return ExtensionInstallHealth(
                status: .otherBuildEnabled,
                currentExtensionPath: normalizedCurrentExtensionPath,
                enabledExtensionPaths: deduplicatedPaths(currentEnabledPaths + siblingEnabledPaths)
            )
        }

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

        return deduplicatedPaths(paths)
    }

    private static func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func deduplicatedPaths(_ paths: [String]) -> [String] {
        var result: [String] = []
        for path in paths where !result.contains(path) {
            result.append(path)
        }
        return result
    }
}
