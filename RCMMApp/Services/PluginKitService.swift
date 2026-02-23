import FinderSync
import os.log
import RCMMShared

enum PluginKitService {
    private static let logger = Logger(subsystem: "com.sunven.rcmm", category: "health")

    static var isExtensionEnabled: Bool {
        let enabled = FIFinderSyncController.isExtensionEnabled
        logger.debug("Extension 状态检测: \(enabled ? "已启用" : "未启用")")
        return enabled
    }

    /// 健康检测：查询 Finder Extension 注册状态，返回 ExtensionStatus 枚举值
    ///
    /// `FIFinderSyncController.isExtensionEnabled` 是非抛出的同步 Bool 属性，
    /// 始终返回 `.enabled` 或 `.disabled`。`.unknown` 作为 `AppState.extensionStatus` 的初始默认值，
    /// 表示应用启动后尚未执行首次检测的状态。
    static func checkHealth() -> ExtensionStatus {
        let enabled = FIFinderSyncController.isExtensionEnabled
        let status: ExtensionStatus = enabled ? .enabled : .disabled
        logger.info("健康检测: Extension 状态 = \(status.rawValue)")
        return status
    }

    static func showExtensionManagement() {
        logger.info("跳转系统设置 - Extension 管理页面")
        FIFinderSyncController.showExtensionManagementInterface()
    }
}
