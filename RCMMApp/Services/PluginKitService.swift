import FinderSync
import Foundation
import os.log
import RCMMShared

enum PluginKitService {
    private static let logger = Logger(subsystem: "com.sunven.rcmm", category: "health")
    private static let extensionBundleID = "com.sunven.rcmm.FinderExtension"
    private static let pluginKitExecutable = URL(fileURLWithPath: "/usr/bin/pluginkit")

    static var isExtensionEnabled: Bool {
        let report = healthReport()
        let enabled = report.status == .enabled
        logger.debug("Extension 状态检测: \(enabled ? "已启用" : "未启用")")
        return enabled
    }

    /// 健康检测：查询 Finder Extension 注册状态，返回 ExtensionStatus 枚举值
    ///
    /// 优先使用 `FIFinderSyncController.isExtensionEnabled` 判断当前运行中的 app 所附带扩展。
    /// 若当前进程未被系统标记为启用，再回退到 `pluginkit` 查询当前安装路径是否真正被系统接管。
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

        let report = ExtensionInstallHealthResolver.resolve(
            currentExtensionPath: currentExtensionPath(),
            currentProcessExtensionEnabled: currentProcessEnabled,
            pluginKitOutput: pluginKitMatchOutput()
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
            if report.enabledExtensionPaths.count > 1 {
                return """
                检测到多份 rcmm Finder 扩展同时处于启用状态。
                当前安装路径：
                \(currentPath)

                系统记录的启用路径：
                \(activePaths)
                """
            }
            return """
            当前安装版扩展没有被系统接管。
            当前安装路径：
            \(currentPath)

            系统当前启用的 rcmm 扩展路径：
            \(activePaths)
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
        let outputPipe = Pipe()

        process.executableURL = pluginKitExecutable
        process.arguments = ["-m", "-ADv", "-i", extensionBundleID]
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.error("执行 pluginkit 查询失败: \(error.localizedDescription)")
            return nil
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            logger.error("pluginkit 查询失败，退出码: \(process.terminationStatus)")
            return nil
        }

        return output
    }
}
