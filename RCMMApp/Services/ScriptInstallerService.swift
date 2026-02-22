import Foundation
import os.log
import RCMMShared

final class ScriptInstallerService {
    private let logger = Logger(
        subsystem: "com.sunven.rcmm",
        category: "script"
    )

    /// Extension 的 bundle ID，用于定位脚本目录
    private let extensionBundleID = "com.sunven.rcmm.FinderExtension"

    /// Extension 脚本目录
    private var scriptsDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/Application Scripts")
            .appendingPathComponent(extensionBundleID)
    }

    /// 为所有菜单项安装脚本
    func installScripts(for items: [MenuItemConfig]) {
        do {
            try FileManager.default.createDirectory(
                at: scriptsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("创建脚本目录失败: \(error.localizedDescription)")
            return
        }

        for item in items {
            installScript(for: item)
        }
    }

    /// 为单个菜单项安装脚本
    private func installScript(for item: MenuItemConfig) {
        let scriptSource = generateAppleScript(for: item)
        let outputURL = scriptsDirectory
            .appendingPathComponent(item.id.uuidString)
            .appendingPathExtension("scpt")

        do {
            try compileScript(source: scriptSource, outputURL: outputURL)
            logger.info("脚本安装成功: \(item.appName) → \(outputURL.lastPathComponent)")
        } catch {
            logger.error("脚本编译失败: \(item.appName): \(error.localizedDescription)")
        }
    }

    /// 生成 AppleScript 源码
    private func generateAppleScript(for item: MenuItemConfig) -> String {
        let command: String
        if let customCommand = item.customCommand, !customCommand.isEmpty {
            // 优先级 1: 用户自定义命令（支持 {app} 和 {path} 占位符）
            command = CommandTemplateProcessor.buildAppleScriptCommand(
                template: customCommand,
                appPath: item.appPath
            )
        } else if let builtInCommand = CommandMappingService.command(for: item.bundleId) {
            // 优先级 2: 内置命令映射（特殊终端：kitty/Alacritty/WezTerm）
            let parts = builtInCommand.components(separatedBy: "{path}")
            let prefix = CommandTemplateProcessor.escapeForAppleScript(parts[0])
            let suffix = parts.count > 1 ? CommandTemplateProcessor.escapeForAppleScript(parts[1]) : ""
            if suffix.isEmpty {
                command = """
                    do shell script "\(prefix)" & quoted form of thePath
                """
            } else {
                command = """
                    do shell script "\(prefix)" & quoted form of thePath & "\(suffix)"
                """
            }
        } else {
            // 优先级 3: 默认 open -a
            let escapedAppPath = CommandTemplateProcessor.escapeForAppleScript(item.appPath)
            command = """
                do shell script "open -a " & quoted form of "\(escapedAppPath)" & " " & quoted form of thePath
            """
        }

        return """
        on openApp(thePath)
        \(command)
        end openApp
        """
    }

    /// 使用 osacompile 编译 AppleScript 源码为 .scpt
    private func compileScript(source: String, outputURL: URL) throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("applescript")
        try source.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osacompile")
        process.arguments = ["-o", outputURL.path, tempURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()

        // 超时保护：10 秒后终止进程，防止 osacompile 挂起导致无限阻塞
        let timeoutWorkItem = DispatchWorkItem { [weak process] in
            process?.terminate()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeoutWorkItem)

        // 先读取 stderr 再等待进程结束，避免管道缓冲区满时死锁
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        timeoutWorkItem.cancel()

        if process.terminationStatus != 0 {
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "ScriptInstallerService",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorMsg]
            )
        }
    }

    /// 删除指定菜单项的脚本文件
    func removeScript(for itemId: UUID) {
        let scriptURL = scriptsDirectory
            .appendingPathComponent(itemId.uuidString)
            .appendingPathExtension("scpt")
        do {
            try FileManager.default.removeItem(at: scriptURL)
            logger.info("脚本已删除: \(itemId.uuidString)")
        } catch {
            logger.warning("删除脚本失败: \(itemId.uuidString): \(error.localizedDescription)")
        }
    }

    /// 同步脚本文件：删除多余的、安装缺失的、更新变更的
    func syncScripts(with items: [MenuItemConfig]) {
        // 确保目录存在
        do {
            try FileManager.default.createDirectory(
                at: scriptsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("创建脚本目录失败: \(error.localizedDescription)")
            return
        }

        // 获取现有脚本文件
        let existingScripts = (try? FileManager.default.contentsOfDirectory(
            at: scriptsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        let existingIDs = Set(existingScripts
            .filter { $0.pathExtension == "scpt" }
            .map { $0.deletingPathExtension().lastPathComponent })
        let expectedIDs = Set(items.map { $0.id.uuidString })

        // 删除多余脚本
        for id in existingIDs.subtracting(expectedIDs) {
            let url = scriptsDirectory
                .appendingPathComponent(id)
                .appendingPathExtension("scpt")
            try? FileManager.default.removeItem(at: url)
            logger.info("删除多余脚本: \(id)")
        }

        // 安装或更新所有预期脚本（覆盖已有文件确保内容同步）
        for item in items {
            installScript(for: item)
        }
    }
}
