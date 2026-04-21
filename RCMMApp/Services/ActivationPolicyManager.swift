import AppKit
import os.log

/// 集中管理应用激活策略切换（.regular ↔ .accessory）
///
/// 将分散在 rcmmApp 和 AppState 中的激活策略逻辑统一管理，
/// 避免多处手动调用 NSApp.setActivationPolicy 导致的不一致问题。
enum ActivationPolicyManager {
    private static let logger = Logger(subsystem: "com.sunven.rcmm", category: "activationPolicy")

    /// 切换为 .regular 并激活应用（显示 Dock 图标）
    ///
    /// 在打开 Settings 窗口或引导窗口前调用。
    @MainActor
    static func activateAsRegularApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        logger.debug("ActivationPolicy → .regular")
    }

    /// 延迟切换为 .accessory（隐藏 Dock 图标）
    ///
    /// 在 Settings 窗口或引导窗口关闭后调用。使用 DispatchQueue.main.async
    /// 延迟执行，避免窗口关闭动画期间切换 policy 导致的视觉闪烁。
    @MainActor
    static func hideToMenuBar() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
            logger.debug("ActivationPolicy → .accessory")
        }
    }
}
