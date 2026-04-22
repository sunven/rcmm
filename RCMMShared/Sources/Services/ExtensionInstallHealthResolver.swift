import Foundation

public enum ExtensionInstallHealthResolver {
    public static func resolve(
        currentExtensionPath: String?,
        currentProcessExtensionEnabled: Bool,
        pluginKitOutput: String?
    ) -> ExtensionInstallHealth {
        if currentProcessExtensionEnabled {
            return ExtensionInstallHealth(
                status: .enabled,
                currentExtensionPath: currentExtensionPath,
                enabledExtensionPaths: []
            )
        }

        guard let pluginKitOutput else {
            return ExtensionInstallHealth(
                status: .unknown,
                currentExtensionPath: currentExtensionPath,
                enabledExtensionPaths: []
            )
        }

        let enabledPaths = enabledExtensionPaths(from: pluginKitOutput)

        if let currentExtensionPath, enabledPaths.contains(currentExtensionPath) {
            return ExtensionInstallHealth(
                status: .enabled,
                currentExtensionPath: currentExtensionPath,
                enabledExtensionPaths: enabledPaths
            )
        }

        if !enabledPaths.isEmpty {
            return ExtensionInstallHealth(
                status: .otherInstallationEnabled,
                currentExtensionPath: currentExtensionPath,
                enabledExtensionPaths: enabledPaths
            )
        }

        return ExtensionInstallHealth(
            status: .disabled,
            currentExtensionPath: currentExtensionPath,
            enabledExtensionPaths: []
        )
    }

    public static func enabledExtensionPaths(from pluginKitOutput: String) -> [String] {
        let paths = pluginKitOutput
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine -> String? in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard line.first == "+" else { return nil }
                return line
                    .split(separator: "\t")
                    .last
                    .map(String.init)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

        var deduplicated: [String] = []
        for path in paths where !deduplicated.contains(path) {
            deduplicated.append(path)
        }
        return deduplicated
    }
}
