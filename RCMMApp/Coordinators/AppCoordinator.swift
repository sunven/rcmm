import Foundation
import RCMMShared
import Observation

/// 顶层编排器：组合配置和脚本发布模块
///
/// AppCoordinator 持有 MenuConfigStore、ScriptCompilationPipeline，
/// 并协调它们之间的交互。采用扁平组合：三个模块彼此独立，依赖关系只存在于这里。
///
/// 职责：
/// - 持有并初始化配置、脚本发布模块
/// - 编排自动修复逻辑（观察错误队列，触发脚本发布）
/// - 提供统一的 saveAndSync 接口（供 UI 调用）
@Observable
@MainActor
final class AppCoordinator {
    // MARK: - Coordinators

    let configStore: MenuConfigStore
    private let scriptCompilationPipeline: ScriptCompilationPipeline

    // MARK: - Auto-Repair State

    var autoRepairMessage: String? = nil  // 改为可变，支持 Preview
    private var hasTriggeredAutoRepair = false

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

        // 启动流程（onboarding 和更新检查由 AppState 处理）
        setupAutoRepair()

        // 启动时同步脚本（确保脚本文件与配置一致）
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

    private func setupAutoRepair() {
        // 初始检查
        checkAndTriggerAutoRepair()
    }

    private func checkAndTriggerAutoRepair() {
        guard !hasTriggeredAutoRepair else { return }
        guard configStore.hasScriptFileErrors else { return }

        hasTriggeredAutoRepair = true
        autoRepairMessage = "正在自动修复脚本文件…"

        publishCurrentConfigurationInBackground { [weak self] outcome in
            guard let self else { return }

            let repairedNames = Set(
                outcome.results
                    .filter { $0.status == .current }
                    .map(\.displayName)
            )

            if !repairedNames.isEmpty {
                self.configStore.clearScriptFileErrors(repairedNames: repairedNames)
            }

            let didPublishAny = outcome.results.contains { $0.status == .current }
            self.autoRepairMessage = didPublishAny ? "已自动修复脚本文件" : "自动修复失败，请打开设置检查"
        }
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

    // MARK: - Sync Interface

    /// 保存配置并同步脚本（统一接口，供 UI 调用）
    func saveAndSync() {
        configStore.saveEntries()
        syncScriptsInBackground()
    }

    @discardableResult
    func addMenuItem(from appInfo: AppInfo) -> UUID? {
        let id = configStore.addMenuItem(from: appInfo)
        if id != nil {
            syncScriptsInBackground()
        }
        return id
    }

    @discardableResult
    func addMenuItems(from appInfos: [AppInfo]) -> [UUID] {
        let ids = configStore.addMenuItems(from: appInfos)
        if !ids.isEmpty {
            syncScriptsInBackground()
        }
        return ids
    }

    @discardableResult
    func addEmptyCompositeCommand() -> UUID {
        let id = configStore.addEmptyCompositeCommand()
        syncScriptsInBackground()
        return id
    }

    @discardableResult
    func addGitPullCommand() -> UUID {
        let id = configStore.addGitPullCommand()
        syncScriptsInBackground()
        return id
    }

    @discardableResult
    func addCompositeCommand(_ composite: CompositeMenuItemConfig) -> UUID {
        let id = configStore.addCompositeCommand(composite)
        syncScriptsInBackground()
        return id
    }

    func moveEntry(from source: IndexSet, to destination: Int) {
        configStore.moveEntry(from: source, to: destination)
        syncScriptsInBackground()
    }

    func removeEntry(at offsets: IndexSet) {
        configStore.removeEntry(at: offsets)
        syncScriptsInBackground()
    }

    func toggleEntry(for entryID: String, isEnabled: Bool) {
        configStore.toggleEntry(for: entryID, isEnabled: isEnabled)
        syncScriptsInBackground()
    }

    func updateCustomCommand(
        for itemID: UUID,
        name: String? = nil,
        command: String?,
        executionMode: CustomCommandExecutionMode? = nil
    ) {
        configStore.updateCustomCommand(
            for: itemID,
            name: name,
            command: command,
            executionMode: executionMode
        )
        syncScriptsInBackground()
    }

    func updateCompositeName(for compositeID: UUID, name: String) {
        configStore.updateCompositeName(for: compositeID, name: name)
        syncScriptsInBackground()
    }

    func updateCompositeStep(
        compositeID: UUID,
        stepID: UUID,
        name: String,
        commandTemplate: String,
        appPath: String?,
        bundleID: String?,
        isEnabled: Bool
    ) {
        configStore.updateCompositeStep(
            compositeId: compositeID,
            stepId: stepID,
            name: name,
            commandTemplate: commandTemplate,
            appPath: appPath,
            bundleId: bundleID,
            isEnabled: isEnabled
        )
        syncScriptsInBackground()
    }

    func addShellStep(to compositeID: UUID) {
        configStore.addShellStep(to: compositeID)
        syncScriptsInBackground()
    }

    func removeCompositeStep(compositeID: UUID, stepID: UUID) {
        configStore.removeCompositeStep(compositeId: compositeID, stepId: stepID)
        syncScriptsInBackground()
    }

    func moveCompositeStep(compositeID: UUID, from source: IndexSet, to destination: Int) {
        configStore.moveCompositeStep(compositeId: compositeID, from: source, to: destination)
        syncScriptsInBackground()
    }

    func updateNewFileMenuName(for menuID: UUID, name: String) {
        configStore.updateNewFileMenuName(for: menuID, name: name)
        syncScriptsInBackground()
    }

    func addNewFileTemplate(to menuID: UUID) {
        configStore.addNewFileTemplate(to: menuID)
        syncScriptsInBackground()
    }

    func updateNewFileTemplate(
        menuID: UUID,
        templateID: UUID,
        displayName: String,
        baseName: String,
        fileExtension: String,
        creationMode: NewFileCreationMode,
        templatePath: String?,
        initialContent: String?,
        isEnabled: Bool
    ) {
        configStore.updateNewFileTemplate(
            menuID: menuID,
            templateID: templateID,
            displayName: displayName,
            baseName: baseName,
            fileExtension: fileExtension,
            creationMode: creationMode,
            templatePath: templatePath,
            initialContent: initialContent,
            isEnabled: isEnabled
        )
        syncScriptsInBackground()
    }

    func removeNewFileTemplate(menuID: UUID, templateID: UUID) {
        configStore.removeNewFileTemplate(menuID: menuID, templateID: templateID)
        syncScriptsInBackground()
    }

    func moveNewFileTemplate(menuID: UUID, from source: IndexSet, to destination: Int) {
        configStore.moveNewFileTemplate(menuID: menuID, from: source, to: destination)
        syncScriptsInBackground()
    }

    func updateMenuPresentationMode(_ mode: MenuPresentationMode) {
        guard configStore.menuPresentationMode != mode else { return }
        configStore.saveMenuPresentationMode(mode)
        DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
    }

    private func syncScriptsInBackground() {
        publishCurrentConfigurationInBackground { [weak self] _ in
            guard let self else { return }

            // 检查是否需要触发自动修复（配置变更后可能产生新错误）
            if !self.hasTriggeredAutoRepair && self.configStore.hasScriptFileErrors {
                self.checkAndTriggerAutoRepair()
            }
        }
    }

    private func publishCurrentConfigurationInBackground(
        onComplete: @escaping (ScriptCompilationOutcome) -> Void
    ) {
        publishTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.scriptCompilationPipeline.publishCurrentConfiguration()
            self.configStore.scriptPublishStates = outcome.publishStates
            self.configStore.errorRecords = outcome.errorRecords
            onComplete(outcome)
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
