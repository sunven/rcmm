import Foundation
import RCMMShared
import Observation

/// 顶层编排器：组合三个独立的协调器
///
/// AppCoordinator 持有三个协调器并协调它们之间的交互。
/// 采用扁平组合：三个协调器彼此独立，依赖关系只存在于这里。
///
/// 职责：
/// - 持有并初始化三个协调器
/// - 编排自动修复逻辑（观察错误队列，触发脚本同步）
/// - 提供统一的 saveAndSync 接口（供 UI 调用）
@Observable
@MainActor
final class AppCoordinator {
    // MARK: - Coordinators

    let configStore: MenuConfigStore
    let syncCoordinator: ScriptSyncCoordinator
    let windowCoordinator: WindowCoordinator

    // MARK: - Auto-Repair State

    var autoRepairMessage: String? = nil  // 改为可变，支持 Preview
    private var hasTriggeredAutoRepair = false

    // MARK: - Initialization

    init(forPreview: Bool = false) {
        self.configStore = MenuConfigStore()
        self.syncCoordinator = ScriptSyncCoordinator()
        self.windowCoordinator = WindowCoordinator(forPreview: forPreview)

        guard !forPreview else { return }

        // 启动流程（onboarding 和更新检查由 AppState 处理）
        setupAutoRepair()

        // 启动时同步脚本（确保脚本文件与配置一致）
        syncScriptsInBackground()
    }

    // MARK: - Auto-Repair

    private func setupAutoRepair() {
        // 初始检查
        checkAndTriggerAutoRepair()
    }

    private func checkAndTriggerAutoRepair() {
        guard !hasTriggeredAutoRepair else { return }
        guard configStore.hasScriptFileErrors else { return }

        hasTriggeredAutoRepair = true
        autoRepairMessage = "正在自动修复脚本文件…"

        let entries = configStore.menuEntries
        syncCoordinator.syncScriptsInBackground(entries: entries) { [weak self] results in
            guard let self else { return }

            let repairedNames = Set(
                results
                    .filter { $0.status == .current }
                    .map(\.displayName)
            )

            if !repairedNames.isEmpty {
                self.configStore.clearScriptFileErrors(repairedNames: repairedNames)
            }

            // 更新发布状态（从 ScriptPublishStore 重新加载）
            self.configStore.loadPublishStates()

            let didPublishAny = results.contains { $0.status == .current }
            self.autoRepairMessage = didPublishAny ? "已自动修复脚本文件" : "自动修复失败，请打开设置检查"
        }
    }

    // MARK: - Sync Interface

    /// 保存配置并同步脚本（统一接口，供 UI 调用）
    func saveAndSync() {
        configStore.saveEntries()
        syncScriptsInBackground()
    }

    private func syncScriptsInBackground() {
        let entries = configStore.menuEntries
        syncCoordinator.syncScriptsInBackground(entries: entries) { [weak self] results in
            guard let self else { return }

            // 更新发布状态和错误记录
            self.configStore.loadPublishStates()
            self.configStore.loadErrors()

            // 检查是否需要触发自动修复（配置变更后可能产生新错误）
            if !self.hasTriggeredAutoRepair && self.configStore.hasScriptFileErrors {
                self.checkAndTriggerAutoRepair()
            }
        }
    }

    func dismissAllErrors() {
        configStore.dismissAllErrors()
        hasTriggeredAutoRepair = false
        autoRepairMessage = nil
    }

    func clearAutoRepairMessage() {
        autoRepairMessage = nil
    }
}
