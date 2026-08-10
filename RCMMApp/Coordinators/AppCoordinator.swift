import Foundation
import RCMMShared
import Observation

/// 顶层编排器：组合配置和脚本发布模块
///
/// AppCoordinator 持有 MenuConfigStore、ScriptCompilationPipeline，
/// 并协调它们之间的交互。采用扁平组合：模块彼此独立，依赖关系只存在于这里。
///
/// 职责：
/// - 持有并初始化配置、脚本发布模块
/// - 编排自动修复逻辑（观察错误队列，触发脚本发布）
/// - 提供 Menu Entry 配置的写入接口：`edit` / `preview` / `commitPreview` /
///   `updateMenuPresentationMode`。视图读配置直接用 MenuConfigStore。
@Observable
@MainActor
final class AppCoordinator {
    // MARK: - Coordinators

    let configStore: MenuConfigStore
    private let scriptCompilationPipeline: ScriptCompilationPipeline

    // MARK: - Auto-Repair State

    var autoRepairMessage: String? = nil
    private var activePublicationCount = 0
    private var repairFeedbackGeneration = 0

    /// 最近一次脚本发布任务。
    ///
    /// 发布是 fire-and-forget —— `edit` / `commitPreview` 不等待 AppleScript 编译完成就返回，
    /// 与重构前的 `syncScriptsInBackground` 行为一致。测试用它等待发布结束后再断言。
    @ObservationIgnored private(set) var publishTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        configStore: MenuConfigStore,
        scriptCompilationPipeline: ScriptCompilationPipeline,
        startsServices: Bool = true
    ) {
        self.configStore = configStore
        self.scriptCompilationPipeline = scriptCompilationPipeline

        guard startsServices else { return }

        // 启动同步同时承担已有加载错误的修复，避免连续发布两次。
        syncScriptsInBackground()
    }

    convenience init() {
        self.init(
            configStore: MenuConfigStore(),
            scriptCompilationPipeline: ScriptCompilationPipeline()
        )
    }

    convenience init(forPreview: Bool) {
        guard forPreview else {
            self.init()
            return
        }

        let defaults = UserDefaults(suiteName: "rcmm.preview.\(UUID().uuidString)")!
        let configService = SharedConfigService(defaults: defaults)
        let publishStore = ScriptPublishStore(defaults: defaults)
        let errorQueue = SharedErrorQueue(defaults: defaults)
        self.init(
            configStore: MenuConfigStore(
                configService: configService,
                publishStore: publishStore,
                errorQueue: errorQueue
            ),
            scriptCompilationPipeline: ScriptCompilationPipeline(
                configService: configService,
                publishStore: publishStore,
                errorQueue: errorQueue
            ),
            startsServices: false
        )
    }

    // MARK: - Auto-Repair

    private func startAutoRepairIfNeeded() {
        guard activePublicationCount == 0 else { return }
        guard !autoRepairTargets.isEmpty else { return }
        publishCurrentConfigurationInBackground()
    }

    // MARK: - Menu Entry 写入接口
    //
    // 视图对 Menu Entry 配置的写入只经过四个入口：
    //
    // | 入口 | 改内存 | 落盘 | 脚本发布 |
    // |---|---|---|---|
    // | `edit`                       | ✓ | ✓ | ✓ |
    // | `preview`                    | ✓ | — | — |
    // | `commitPreview`              | — | ✓ | ✓ |
    // | `updateMenuPresentationMode` | ✓ | ✓ | 仅 Cross-Process Sync 通知 |
    //
    // 不变量：每一次已提交编辑恰好触发一次发布。

    /// 提交一次 Menu Entry 变更：改内存 → 落盘 → 发布脚本。
    ///
    /// 闭包同步执行，其返回值原样带出（新建条目的 ID 等）。脚本发布在闭包返回后异步进行。
    /// 无论闭包走的是 `MenuConfigStore` 的具名方法还是直接改 `menuEntries`，落盘都由这里保证。
    @discardableResult
    func edit<T>(_ body: (MenuConfigStore) -> T) -> T {
        let result = body(configStore)
        persistAndPublish()
        return result
    }

    /// 临时预览：只改内存态，不落盘、不发布。
    ///
    /// 用于拖拽排序这类过程态。回滚责任在调用方 —— 它同时还持有选中项和动画等视图状态，
    /// 取消时同样走 `preview` 把原顺序写回。提交走 `commitPreview()`。
    func preview(_ body: (MenuConfigStore) -> Void) {
        body(configStore)
    }

    /// 提交此前由 `preview` 累积的内存态：落盘 → 发布脚本。
    func commitPreview() {
        persistAndPublish()
    }

    private func persistAndPublish() {
        configStore.saveEntries()
        syncScriptsInBackground()
    }

    // MARK: - Menu Presentation Mode

    /// 展示方式不影响 `.scpt` 内容，因此不走 `edit` —— 只落盘并发通知，
    /// 避免为一个枚举触发全量 AppleScript 重编译。
    func updateMenuPresentationMode(_ mode: MenuPresentationMode) {
        guard configStore.menuPresentationMode != mode else { return }
        configStore.saveMenuPresentationMode(mode)
        DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
    }

    private func syncScriptsInBackground() {
        publishCurrentConfigurationInBackground()
    }

    private func publishCurrentConfigurationInBackground() {
        let targets = autoRepairTargets
        let feedbackGeneration = repairFeedbackGeneration
        activePublicationCount += 1
        if !targets.isEmpty {
            autoRepairMessage = "正在自动修复脚本文件…"
        }

        publishTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.scriptCompilationPipeline.publishCurrentConfiguration()
            self.completePublication(
                outcome,
                targets: targets,
                feedbackGeneration: feedbackGeneration
            )
        }
    }

    private func completePublication(
        _ outcome: ScriptCompilationOutcome,
        targets: Set<AutoRepairTarget>,
        feedbackGeneration: Int
    ) {
        activePublicationCount -= 1
        configStore.scriptPublishStates = outcome.publishStates
        configStore.loadErrors()

        guard !targets.isEmpty else { return }

        let statusByScriptID = Dictionary(
            outcome.results.map { ($0.entryID, $0.status) },
            uniquingKeysWith: { _, latest in latest }
        )
        let resolvedTargets = targets.filter { target in
            guard let status = statusByScriptID[target.scriptID] else {
                return true
            }
            return status == .current
        }
        configStore.removeErrors(ids: Set(resolvedTargets.map(\.errorID)))

        guard feedbackGeneration == repairFeedbackGeneration else { return }

        if autoRepairTargets.isEmpty {
            autoRepairMessage = "已自动修复脚本文件"
        } else if !resolvedTargets.isEmpty {
            autoRepairMessage = "部分脚本自动修复失败，请打开设置检查"
        } else {
            autoRepairMessage = "自动修复失败，请打开设置检查"
        }
    }

    private var autoRepairTargets: Set<AutoRepairTarget> {
        Set(configStore.errorRecords.compactMap { record in
            guard record.kind == .scriptLoad,
                  let scriptID = record.runtimeScriptID else {
                return nil
            }
            return AutoRepairTarget(errorID: record.id, scriptID: scriptID)
        })
    }

    func loadErrors() {
        configStore.loadErrors()
        startAutoRepairIfNeeded()
    }

    func dismissAllErrors() {
        configStore.dismissAllErrors()
        repairFeedbackGeneration += 1
        autoRepairMessage = nil
    }

    func clearAutoRepairMessage() {
        autoRepairMessage = nil
    }
}

private struct AutoRepairTarget: Hashable {
    let errorID: UUID
    let scriptID: String
}
