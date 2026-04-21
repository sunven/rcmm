import FinderSync
import Foundation
import os.log
import RCMMShared

enum PluginKitService {
    private static let logger = Logger(subsystem: "com.sunven.rcmm", category: "health")
    private static let extensionBundleID = "com.sunven.rcmm.FinderExtension"
    private static let pluginKitExecutable = URL(fileURLWithPath: "/usr/bin/pluginkit")

    static var isExtensionEnabled: Bool {
        let enabled = resolveEnabledState()
        logger.debug("Extension 状态检测: \(enabled ? "已启用" : "未启用")")
        return enabled
    }

    /// 健康检测：查询 Finder Extension 注册状态，返回 ExtensionStatus 枚举值
    ///
    /// 优先使用 `FIFinderSyncController.isExtensionEnabled` 判断当前运行中的 app 所附带扩展。
    /// 若当前调试包未被系统标记为启用，再回退到 `pluginkit` 查询同 bundle ID 的任意已启用实例，
    /// 以兼容“Xcode 运行调试包，但系统里已有 /Applications 安装版扩展在工作”的场景。
    ///
    /// `.unknown` 作为 `AppState.extensionStatus` 的初始默认值，表示应用启动后尚未执行首次检测的状态。
    static func checkHealth() -> ExtensionStatus {
        let enabled = resolveEnabledState()
        let status: ExtensionStatus = enabled ? .enabled : .disabled
        logger.info("健康检测: Extension 状态 = \(status.rawValue)")
        return status
    }

    static func showExtensionManagement() {
        logger.info("跳转系统设置 - Extension 管理页面")
        FIFinderSyncController.showExtensionManagementInterface()
    }

    private static func resolveEnabledState() -> Bool {
        if FIFinderSyncController.isExtensionEnabled {
            logger.debug("FinderSync API 检测到当前扩展实例已启用")
            return true
        }

        let globallyEnabledPaths = enabledRegisteredExtensionPaths()
        if !globallyEnabledPaths.isEmpty {
            logger.info("当前运行实例未启用，但系统中存在 \(globallyEnabledPaths.count) 个已启用的 Finder 扩展实例")
            return true
        }

        logger.debug("FinderSync API 与 pluginkit 均未检测到已启用扩展")
        return false
    }

    private static func enabledRegisteredExtensionPaths() -> [String] {
        guard let output = pluginKitMatchOutput() else {
            return []
        }

        let paths = output
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine -> String? in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard line.first == "+" else { return nil }

                let path = line
                    .split(separator: "\t")
                    .last
                    .map(String.init)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard let path, FileManager.default.fileExists(atPath: path) else {
                    return nil
                }
                return path
            }

        return paths
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
