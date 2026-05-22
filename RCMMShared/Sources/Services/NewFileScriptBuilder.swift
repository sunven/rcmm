import Foundation

public enum NewFileScriptBuilderError: LocalizedError, Hashable, Sendable {
    case unsupportedSource
    case templateNotFound

    public var errorDescription: String? {
        switch self {
        case .unsupportedSource:
            return "脚本项不是新建文件模板。"
        case .templateNotFound:
            return "找不到对应的新建文件模板。"
        }
    }
}

public enum NewFileScriptBuilder: Sendable {
    public static func templateResourceName(for scriptID: String, fileExtension: String) -> String {
        let normalizedExtension = fileExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if normalizedExtension.isEmpty {
            return "\(scriptID).template"
        }
        return "\(scriptID).template.\(normalizedExtension)"
    }

    public static func source(
        for menu: NewFileMenuConfig,
        scriptBackedEntry: ScriptBackedMenuEntry
    ) throws -> String {
        guard case .newFileTemplate(_, let templateID) = scriptBackedEntry.source else {
            throw NewFileScriptBuilderError.unsupportedSource
        }
        guard let template = menu.templates.first(where: { $0.id == templateID }) else {
            throw NewFileScriptBuilderError.templateNotFound
        }

        return source(for: template, scriptID: scriptBackedEntry.id)
    }

    public static func source(
        for template: NewFileTemplateConfig,
        scriptID: String
    ) -> String {
        let baseName = escapeForAppleScript(template.baseName.trimmingCharacters(in: .whitespacesAndNewlines))
        let fileExtension = escapeForAppleScript(template.fileExtension.trimmingCharacters(in: .whitespacesAndNewlines))

        let creationCommand: String
        switch template.creationMode {
        case .emptyFile:
            creationCommand = """
            do shell script "/usr/bin/touch " & quoted form of finalPath
            """
        case .textContent:
            let content = Data((template.initialContent ?? "").utf8).base64EncodedString()
            creationCommand = """
            do shell script "/usr/bin/printf %s " & quoted form of "\(content)" & " | /usr/bin/base64 -D > " & quoted form of finalPath
            """
        case .copyTemplate:
            let resourceName = escapeForAppleScript(
                templateResourceName(for: scriptID, fileExtension: template.fileExtension)
            )
            creationCommand = """
            set templatePath to applicationScriptsPath() & "\(resourceName)"
            do shell script "/bin/cp -p " & quoted form of templatePath & " " & quoted form of finalPath
            """
        }

        return """
        on openApp(thePath)
        set destinationDirectory to normalizeDirectory(thePath)
        set finalPath to uniqueFilePath(destinationDirectory, "\(baseName)", "\(fileExtension)")
        \(creationCommand)
        do shell script "/usr/bin/open -R " & quoted form of finalPath
        end openApp

        on normalizeDirectory(thePath)
        set isDirectory to do shell script "/bin/test -d " & quoted form of thePath & " && /bin/echo yes || /bin/echo no"
        if isDirectory is "yes" then
        return thePath
        end if
        return do shell script "/usr/bin/dirname " & quoted form of thePath
        end normalizeDirectory

        on uniqueFilePath(destinationDirectory, baseName, fileExtension)
        if destinationDirectory ends with "/" then
        set directoryPrefix to destinationDirectory
        else
        set directoryPrefix to destinationDirectory & "/"
        end if

        set suffix to "." & fileExtension
        set candidate to directoryPrefix & baseName & suffix
        set indexNumber to 2
        repeat while pathExists(candidate)
        set candidate to directoryPrefix & baseName & " " & indexNumber & suffix
        set indexNumber to indexNumber + 1
        end repeat
        return candidate
        end uniqueFilePath

        on pathExists(candidatePath)
        set resultText to do shell script "/bin/test -e " & quoted form of candidatePath & " && /bin/echo yes || /bin/echo no"
        return resultText is "yes"
        end pathExists

        on applicationScriptsPath()
        set scriptPath to POSIX path of (path to me)
        set scriptDirectory to do shell script "/usr/bin/dirname " & quoted form of scriptPath
        return scriptDirectory & "/"
        end applicationScriptsPath
        """
    }

    private static func escapeForAppleScript(_ value: String) -> String {
        CommandTemplateProcessor.escapeForAppleScript(value)
    }
}
