import Foundation
import RCMMShared

/// 编排脚本编译管线、Darwin 通知、后台任务队列
///
/// ScriptSyncCoordinator 负责将菜单配置编译为可执行脚本，并通知扩展重新加载。
/// 它不持有 MenuConfigStore 引用，通过参数接收数据，保持独立性。
///
/// 职责：
/// - 执行脚本编译管线（生成 AppleScript、编译、安装）
/// - 发送 Darwin 通知通知扩展
/// - 管理后台同步队列（串行执行，避免竞态）
@MainActor
final class ScriptSyncCoordinator {
    // MARK: - Dependencies

    private let installer = ScriptInstallerService()

    /// 串行队列确保脚本同步任务不会并发执行，避免竞态导致孤立脚本文件
    private static let syncQueue = DispatchQueue(
        label: "com.sunven.rcmm.scriptSync",
        qos: .userInitiated
    )

    // MARK: - Synchronization

    /// 同步脚本：编译、安装、发送通知
    ///
    /// - Parameter entries: 当前菜单配置
    /// - Returns: 编译结果（ScriptSyncResult 列表）
    func syncScripts(entries: [MenuEntry]) async -> [ScriptSyncResult] {
        await withCheckedContinuation { continuation in
            Self.syncQueue.async {
                let results = self.installer.syncScripts(with: entries)
                DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
                continuation.resume(returning: results)
            }
        }
    }

    /// 后台同步脚本（不阻塞主线程）
    ///
    /// - Parameters:
    ///   - entries: 当前菜单配置
    ///   - onComplete: 完成回调（在主线程调用）
    func syncScriptsInBackground(
        entries: [MenuEntry],
        onComplete: @escaping ([ScriptSyncResult]) -> Void
    ) {
        Self.syncQueue.async { [weak self] in
            guard let self else { return }
            let results = self.installer.syncScripts(with: entries)
            DarwinNotificationCenter.shared.post(NotificationNames.configChanged)

            Task { @MainActor in
                onComplete(results)
            }
        }
    }
}
