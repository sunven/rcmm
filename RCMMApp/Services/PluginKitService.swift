import FinderSync
import Foundation
import os.log
import RCMMShared

enum PluginKitService {
    private static let logger = Logger(subsystem: "com.sunven.rcmm", category: "health")
    private static let extensionBundleID = "com.sunven.rcmm.FinderExtension"
    private static let pluginKitExecutable = URL(fileURLWithPath: "/usr/bin/pluginkit")
    private static let killAllExecutable = URL(fileURLWithPath: "/usr/bin/killall")

    static var isExtensionEnabled: Bool {
        let report = healthReport()
        let enabled = report.status == .enabled
        logger.debug("Extension 状态检测: \(enabled ? "已启用" : "未启用")")
        return enabled
    }

    /// 健康检测：查询 Finder Extension 注册状态，返回 ExtensionStatus 枚举值
    ///
    /// 优先使用 `pluginkit` 判断系统当前真正接管的是哪一份 Finder 扩展。
    /// 只有在 `pluginkit` 不可用时，才回退到 `FIFinderSyncController.isExtensionEnabled`。
    ///
    /// `.unknown` 作为 `AppState.extensionStatus` 的初始默认值，表示应用启动后尚未执行首次检测的状态。
    static func checkHealth() -> ExtensionStatus {
        let report = healthReport()
        logger.info("健康检测: Extension 状态 = \(report.status.rawValue)")
        return report.status
    }

    static func showExtensionManagement() {
        logger.info("跳转系统设置 - Extension 管理页面")
        FIFinderSyncController.showExtensionManagementInterface()
    }

    static func restartFinder(
        commandRunner: SystemCommandRunning = SystemCommandRunner()
    ) throws {
        logger.info("手动重启 Finder")

        let result = try commandRunner.run(
            executable: killAllExecutable,
            arguments: ["Finder"]
        )

        guard result.terminationStatus == 0 else {
            let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let failureReason = stderr.isEmpty
                ? "killall Finder 退出码：\(result.terminationStatus)"
                : stderr
            logger.error("重启 Finder 失败：\(failureReason, privacy: .public)")
            throw NSError(
                domain: "PluginKitService",
                code: Int(result.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: failureReason]
            )
        }
    }

    static func enabledExtensionPaths() -> [String] {
        guard let output = pluginKitMatchOutput() else {
            return []
        }

        return ExtensionInstallHealthResolver.enabledExtensionPaths(from: output)
    }

    static func healthReport() -> ExtensionInstallHealth {
        let currentProcessEnabled = FIFinderSyncController.isExtensionEnabled
        if currentProcessEnabled {
            logger.debug("FinderSync API 检测到当前扩展实例已启用")
        }

        let currentExtensionPath = currentExtensionPath()
        let pluginKitOutput = pluginKitMatchOutput()
        let report = ExtensionInstallHealthResolver.resolve(
            currentExtensionPath: currentExtensionPath,
            currentProcessExtensionEnabled: currentProcessEnabled,
            pluginKitOutput: pluginKitOutput
        )

        logger.debug(
            """
            健康检测详情:
            currentProcessEnabled=\(currentProcessEnabled, privacy: .public)
            currentExtensionPath=\(currentExtensionPath ?? "nil", privacy: .public)
            enabledExtensionPaths=\(report.enabledExtensionPaths.joined(separator: ", "), privacy: .public)
            """
        )

        if report.status == .otherInstallationEnabled {
            logger.warning("当前安装版扩展未启用，系统正在使用其他 rcmm 扩展路径: \(report.enabledExtensionPaths.joined(separator: ", "))")
        }

        return report
    }

    static func detailMessage(for report: ExtensionInstallHealth) -> String? {
        switch report.status {
        case .enabled:
            return nil
        case .disabled:
            if let currentPath = report.currentExtensionPath {
                return """
                当前安装版扩展尚未启用。
                期望路径：
                \(currentPath)
                """
            }
            return "当前安装版扩展尚未启用。"
        case .otherInstallationEnabled:
            let currentPath = report.currentExtensionPath ?? "未知路径"
            let activePaths = report.enabledExtensionPaths.joined(separator: "\n")
            let conflictHint = """
            这通常发生在 Xcode 调试副本或旧安装副本仍被系统记录为启用时。
            Finder 可能不会显示当前这份 rcmm 的右键菜单。请点击“清理旧扩展副本…”后重试。
            """
            if report.enabledExtensionPaths.count > 1 {
                return """
                检测到多份 rcmm Finder 扩展同时处于启用状态。
                当前安装路径：
                \(currentPath)

                系统记录的启用路径：
                \(activePaths)

                \(conflictHint)
                """
            }
            return """
            当前安装版扩展没有被系统接管。
            当前安装路径：
            \(currentPath)

            系统当前启用的 rcmm 扩展路径：
            \(activePaths)

            \(conflictHint)
            """
        case .unknown:
            return "暂时无法读取系统扩展注册状态。"
        }
    }

    static func currentExtensionPath() -> String? {
        let appPath = AppInstallContext.current().currentAppPath
        let path = URL(fileURLWithPath: appPath, isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("PlugIns", isDirectory: true)
            .appendingPathComponent("RCMMFinderExtension.appex")
            .path

        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        return path
    }

    private static func pluginKitMatchOutput() -> String? {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = pluginKitExecutable
        process.arguments = ["-m", "-ADv", "-i", extensionBundleID]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            logger.error("执行 pluginkit 查询失败: \(error.localizedDescription)")
            return nil
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(decoding: stdoutData, as: UTF8.self)
        let stderrOutput = String(decoding: stderrData, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            logger.error("pluginkit 查询失败，退出码: \(process.terminationStatus), stderr: \(stderrOutput)")
            return nil
        }

        return output
    }
}
