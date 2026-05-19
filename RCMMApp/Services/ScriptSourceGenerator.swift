import Foundation
import RCMMShared

enum ScriptSourceGenerationError: LocalizedError {
    case unsupportedEntry
    case noExecutableCompositeSteps
    case missingAppPath(stepName: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedEntry:
            return "此菜单项不需要脚本"
        case .noExecutableCompositeSteps:
            return "组合命令没有可执行步骤"
        case .missingAppPath(let stepName):
            return "步骤缺少应用路径: \(stepName)"
        }
    }
}

struct ScriptSourceGenerator {
    func generate(
        for entry: MenuEntry,
        scriptBackedEntry: ScriptBackedMenuEntry
    ) throws -> String {
        switch entry {
        case .builtIn:
            throw ScriptSourceGenerationError.unsupportedEntry
        case .custom(let item):
            return generate(for: item)
        case .composite(let config):
            return try generate(
                for: config,
                executableStepIDs: scriptBackedEntry.executableStepIDs
            )
        }
    }

    private func generate(for item: MenuItemConfig) -> String {
        if item.executionMode == .currentDirectory {
            return generateCurrentDirectoryCommand(for: item)
        }

        let command: String
        if let customCommand = item.customCommand, !customCommand.isEmpty {
            command = CommandTemplateProcessor.buildAppleScriptCommand(
                template: customCommand,
                appPath: item.appPath,
                bundleId: item.bundleId
            )
        } else if let builtInCommand = CommandMappingService.command(for: item.bundleId) {
            command = CommandTemplateProcessor.buildAppleScriptCommand(
                template: builtInCommand,
                appPath: item.appPath,
                bundleId: item.bundleId
            )
        } else {
            let escapedAppPath = CommandTemplateProcessor.escapeForAppleScript(item.appPath)
            command = """
                do shell script "open -a " & quoted form of "\(escapedAppPath)" & " " & quoted form of thePath
            """
        }

        return wrap(commands: [command])
    }

    private func generateCurrentDirectoryCommand(for item: MenuItemConfig) -> String {
        let command = item.customCommand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return wrap(commands: [
            CommandTemplateProcessor.buildCurrentDirectoryAppleScriptCommand(
                command: command
            ),
        ])
    }

    private func generate(
        for config: CompositeMenuItemConfig,
        executableStepIDs: Set<UUID>
    ) throws -> String {
        var postSuccessCommands: [CompositeScriptCommand] = []
        let commands = try config.steps.compactMap { step -> CompositeScriptCommand? in
            guard executableStepIDs.contains(step.id) else { return nil }

            let command: String
            switch step.kind {
            case .app:
                guard let appPath = step.appPath, !appPath.isEmpty else {
                    throw ScriptSourceGenerationError.missingAppPath(stepName: step.name)
                }
                command = CommandTemplateProcessor.buildAppleScriptCommand(
                    template: effectiveCommandTemplate(for: step),
                    appPath: appPath,
                    bundleId: step.bundleId,
                    quoteAppPlaceholder: true
                )
                if step.bundleId == "com.microsoft.VSCode" {
                    postSuccessCommands.append(
                        CompositeScriptCommand(
                            stepName: step.name,
                            command: vsCodeActivationCommand(appPath: appPath)
                        )
                    )
                }
            case .shell:
                command = CommandTemplateProcessor.buildAppleScriptCommand(
                    template: step.commandTemplate,
                    appPath: ""
                )
            }

            return CompositeScriptCommand(stepName: step.name, command: command)
        }

        guard !commands.isEmpty else {
            throw ScriptSourceGenerationError.noExecutableCompositeSteps
        }

        return wrapComposite(commands: commands, postSuccessCommands: postSuccessCommands)
    }

    private func wrap(commands: [String]) -> String {
        """
        on openApp(thePath)
        \(commands.joined(separator: "\n"))
        end openApp
        """
    }

    private func wrapComposite(
        commands: [CompositeScriptCommand],
        postSuccessCommands: [CompositeScriptCommand]
    ) -> String {
        let commandBlocks = commands.map { scriptCommand in
            let escapedStepName = CommandTemplateProcessor.escapeForAppleScript(scriptCommand.stepName)
            return """
            try
            \(scriptCommand.command)
            on error errorMessage number errorNumber
            copy "\(escapedStepName): " & errorMessage to end of stepFailures
            end try
            """
        }
        let postSuccessBlocks = postSuccessCommands.map { scriptCommand in
            let escapedStepName = CommandTemplateProcessor.escapeForAppleScript(scriptCommand.stepName)
            return """
            try
            delay 0.2
            \(scriptCommand.command)
            on error errorMessage number errorNumber
            copy "\(escapedStepName): " & errorMessage to end of stepFailures
            end try
            """
        }

        return """
        on openApp(thePath)
        set stepFailures to {}
        \(commandBlocks.joined(separator: "\n"))
        if (count of stepFailures) > 0 then
        set AppleScript's text item delimiters to "\\n"
        set combinedFailures to stepFailures as text
        set AppleScript's text item delimiters to ""
        error combinedFailures
        end if
        \(postSuccessBlocks.joined(separator: "\n"))
        if (count of stepFailures) > 0 then
        set AppleScript's text item delimiters to "\\n"
        set combinedFailures to stepFailures as text
        set AppleScript's text item delimiters to ""
        error combinedFailures
        end if
        end openApp
        """
    }

    private func effectiveCommandTemplate(for step: CompositeCommandStep) -> String {
        guard step.bundleId == "com.microsoft.VSCode",
              CompositeCommandTemplates.shouldMigrateVSCodeTemplate(step.commandTemplate) else {
            return step.commandTemplate
        }

        return CompositeCommandTemplates.vsCodeCLI
    }

    private func vsCodeActivationCommand(appPath: String) -> String {
        let escapedAppPath = CommandTemplateProcessor.escapeForAppleScript(appPath)
        return """
        do shell script "open -a " & quoted form of "\(escapedAppPath)"
        """
    }
}

private struct CompositeScriptCommand {
    let stepName: String
    let command: String
}

enum CompositeCommandTemplates {
    static let legacyOpenApp = "open -a {app} {path}"
    static let legacyVSCodeCLI = "{app}/Contents/Resources/app/bin/code -r {path}"
    static let vsCodeCLI = "{app}/Contents/Resources/app/bin/code -n {path}"
    static let openBundle = "open -b {bundle} {path}"

    static func vsCodeCLIPath(appPath: String) -> String {
        (appPath as NSString)
            .appendingPathComponent("Contents/Resources/app/bin/code")
    }

    static func isLegacyOpenAppTemplate(_ template: String) -> Bool {
        template
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            == legacyOpenApp
    }

    static func shouldMigrateVSCodeTemplate(_ template: String) -> Bool {
        let normalized = template
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return normalized == legacyOpenApp
            || normalized == legacyVSCodeCLI
            || normalized == openBundle
    }
}
