import FinderSync
import os.log

enum PluginKitService {
    private static let logger = Logger(subsystem: "com.sunven.rcmm", category: "health")

    static var isExtensionEnabled: Bool {
        let enabled = FIFinderSyncController.isExtensionEnabled
        logger.debug("Extension 状态检测: \(enabled ? "已启用" : "未启用")")
        return enabled
    }

    static func showExtensionManagement() {
        logger.info("跳转系统设置 - Extension 管理页面")
        FIFinderSyncController.showExtensionManagementInterface()
    }
}
