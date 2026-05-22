import Foundation

public enum FinderTargetPathResolver {
    public static func executionPath(
        for targetPath: String,
        executionMode: CustomCommandExecutionMode?
    ) -> String {
        executionPath(
            for: targetPath,
            executionMode: executionMode,
            isDirectory: defaultIsDirectory
        )
    }

    public static func executionPath(
        for targetPath: String,
        executionMode: CustomCommandExecutionMode?,
        isDirectory: (String) -> Bool
    ) -> String {
        guard executionMode == .currentDirectory else {
            return targetPath
        }

        return directoryPath(for: targetPath, isDirectory: isDirectory)
    }

    public static func executionPath(
        for targetPath: String,
        targetPolicy: ScriptBackedTargetPolicy
    ) -> String {
        executionPath(
            for: targetPath,
            targetPolicy: targetPolicy,
            isDirectory: defaultIsDirectory
        )
    }

    public static func executionPath(
        for targetPath: String,
        targetPolicy: ScriptBackedTargetPolicy,
        isDirectory: (String) -> Bool
    ) -> String {
        switch targetPolicy {
        case .selectedPath:
            return targetPath
        case .containingDirectory:
            return directoryPath(for: targetPath, isDirectory: isDirectory)
        }
    }

    public static func directoryPath(for targetPath: String) -> String {
        directoryPath(for: targetPath, isDirectory: defaultIsDirectory)
    }

    public static func directoryPath(
        for targetPath: String,
        isDirectory: (String) -> Bool
    ) -> String {
        let url = URL(fileURLWithPath: targetPath).standardizedFileURL
        if isDirectory(url.path) {
            return url.path
        }

        let parent = url.deletingLastPathComponent().path
        return parent.isEmpty ? "/" : parent
    }

    private static func defaultIsDirectory(_ path: String) -> Bool {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }
}
