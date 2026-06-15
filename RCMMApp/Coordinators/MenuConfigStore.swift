import Foundation
import RCMMShared
import Observation

/// 领域模型：管理菜单配置、发布状态、错误记录
///
/// MenuConfigStore 是纯领域模型，负责菜单项的持久化和状态管理。
/// 它不依赖 UI 框架，不执行脚本编译，不管理窗口生命周期。
///
/// 职责：
/// - 加载和保存菜单配置（menuEntries）
/// - 管理脚本发布状态（scriptPublishStates）
/// - 管理错误队列（errorRecords）
/// - 提供菜单项的增删改查接口
@Observable
@MainActor
final class MenuConfigStore {
    // MARK: - State

    var menuEntries: [MenuEntry] = []
    var menuPresentationMode: MenuPresentationMode = .flat
    var scriptPublishStates: [String: ScriptPublishState] = [:]
    var errorRecords: [ErrorRecord] = []  // 改为可变，支持 Preview

    // MARK: - Dependencies

    private let configService = SharedConfigService()
    private let publishStore = ScriptPublishStore()
    private let errorQueue = SharedErrorQueue()

    // MARK: - Initialization

    init() {
        loadMenuPresentationMode()
        loadMenuEntries()
        loadPublishStates()
        loadErrors()
    }

    // MARK: - Menu Presentation Mode

    func loadMenuPresentationMode() {
        menuPresentationMode = configService.loadMenuPresentationMode()
    }

    func saveMenuPresentationMode(_ mode: MenuPresentationMode) {
        guard menuPresentationMode != mode else { return }
        menuPresentationMode = mode
        configService.saveMenuPresentationMode(mode)
    }

    // MARK: - Menu Entries

    /// 加载菜单配置；首次启动时创建默认 Terminal 配置
    func loadMenuEntries() {
        let loadedEntries = migrateCompositeCommandTemplatesIfNeeded(configService.loadEntries())

        if loadedEntries.isEmpty {
            let terminalConfig = MenuItemConfig(
                appName: "Terminal",
                bundleId: "com.apple.Terminal",
                appPath: "/System/Applications/Utilities/Terminal.app"
            )
            menuEntries = [
                .custom(terminalConfig),
                .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
                .newFile(NewFileMenuConfig()),
            ]
            configService.saveEntries(menuEntries)
        } else {
            menuEntries = ensurePrimaryNewFileMenuIfNeeded(loadedEntries)
        }
    }

    func saveEntries() {
        configService.saveEntries(menuEntries)
    }

    var primaryNewFileMenu: NewFileMenuConfig? {
        NewFileMenuPolicy.primaryNewFileMenu(in: menuEntries)
    }

    @discardableResult
    func ensureNewFileMenu() -> UUID {
        let result = NewFileMenuPolicy.ensurePrimaryNewFileMenu(in: menuEntries)
        guard result.didChange else {
            return result.menuID
        }

        menuEntries = result.entries
        saveEntries()
        return result.menuID
    }

    private func ensurePrimaryNewFileMenuIfNeeded(_ entries: [MenuEntry]) -> [MenuEntry] {
        let result = NewFileMenuPolicy.ensurePrimaryNewFileMenu(in: entries)
        guard result.didChange else {
            return entries
        }

        configService.saveEntries(result.entries)
        return result.entries
    }

    private func migrateCompositeCommandTemplatesIfNeeded(_ entries: [MenuEntry]) -> [MenuEntry] {
        var didChange = false
        let migratedEntries = entries.map { entry -> MenuEntry in
            guard case .composite(var config) = entry else {
                return entry
            }

            for index in config.steps.indices {
                let step = config.steps[index]
                guard step.bundleId == "com.microsoft.VSCode",
                      CompositeCommandTemplates.shouldMigrateVSCodeTemplate(step.commandTemplate) else {
                    continue
                }

                config.steps[index].commandTemplate = CompositeCommandTemplates.vsCodeCLI
                didChange = true
            }

            return .composite(config)
        }

        if didChange {
            configService.saveEntries(migratedEntries)
        }
        return migratedEntries
    }

    // MARK: - Add Menu Items

    @discardableResult
    func addMenuItem(from appInfo: AppInfo) -> UUID? {
        guard !containsCustomMenuItem(matching: appInfo) else { return nil }
        let newItem = MenuItemConfig(
            appName: appInfo.name,
            bundleId: appInfo.bundleId,
            appPath: appInfo.path
        )
        menuEntries.append(.custom(newItem))
        saveEntries()
        return newItem.id
    }

    @discardableResult
    func addEmptyCompositeCommand() -> UUID {
        let composite = CompositeMenuItemConfig(
            name: "新组合命令",
            iconName: "rectangle.stack.badge.play",
            steps: []
        )
        menuEntries.append(.composite(composite))
        saveEntries()
        return composite.id
    }

    @discardableResult
    func addGitPullCommand() -> UUID {
        let item = MenuItemConfig(
            appName: "Git Pull",
            appPath: "",
            customCommand: "git pull",
            executionMode: .currentDirectory
        )
        menuEntries.append(.custom(item))
        saveEntries()
        return item.id
    }

    private func containsCustomMenuItem(matching appInfo: AppInfo) -> Bool {
        menuEntries.contains { entry in
            guard case .custom(let config) = entry else { return false }
            return config.bundleId == appInfo.bundleId
        }
    }

    // MARK: - Update Menu Items

    func moveEntry(from source: IndexSet, to destination: Int) {
        menuEntries.move(fromOffsets: source, toOffset: destination)
        saveEntries()
    }

    func removeEntry(at offsets: IndexSet) {
        let removableOffsets = offsets.filter { index in
            switch menuEntries[index] {
            case .custom, .composite:
                return true
            case .builtIn, .newFile:
                return false
            }
        }
        menuEntries.remove(atOffsets: IndexSet(removableOffsets))
        saveEntries()
    }

    func toggleEntry(for entryId: String, isEnabled: Bool) {
        guard let index = menuEntries.firstIndex(where: { $0.id == entryId }) else { return }
        switch menuEntries[index] {
        case .builtIn(var item):
            item.isEnabled = isEnabled
            menuEntries[index] = .builtIn(item)
        case .custom(var config):
            config.isEnabled = isEnabled
            menuEntries[index] = .custom(config)
        case .composite(var config):
            config.isEnabled = isEnabled
            menuEntries[index] = .composite(config)
        case .newFile(var config):
            config.isEnabled = isEnabled
            menuEntries[index] = .newFile(config)
        }
        saveEntries()
    }

    func updateCustomCommand(
        for itemId: UUID,
        name: String? = nil,
        command: String?,
        executionMode: CustomCommandExecutionMode? = nil
    ) {
        guard let index = menuEntries.firstIndex(where: {
            if case .custom(let config) = $0 { return config.id == itemId }
            return false
        }) else { return }
        if case .custom(var config) = menuEntries[index] {
            if let name {
                config.appName = name
            }
            config.customCommand = command
            if let executionMode {
                config.executionMode = executionMode
            }
            menuEntries[index] = .custom(config)
        }
        saveEntries()
    }

    // MARK: - Composite Commands

    func updateCompositeName(for compositeId: UUID, name: String) {
        updateComposite(for: compositeId) { config in
            config.name = name
        }
    }

    func updateCompositeStep(
        compositeId: UUID,
        stepId: UUID,
        name: String,
        commandTemplate: String,
        appPath: String?,
        bundleId: String?,
        isEnabled: Bool
    ) {
        updateComposite(for: compositeId) { config in
            guard let stepIndex = config.steps.firstIndex(where: { $0.id == stepId }) else {
                return
            }
            config.steps[stepIndex].name = name
            config.steps[stepIndex].commandTemplate = commandTemplate
            config.steps[stepIndex].appPath = appPath
            config.steps[stepIndex].bundleId = bundleId
            config.steps[stepIndex].isEnabled = isEnabled
        }
    }

    func addShellStep(to compositeId: UUID) {
        updateComposite(for: compositeId) { config in
            config.steps.append(
                CompositeCommandStep(
                    kind: .shell,
                    name: "Shell",
                    commandTemplate: "open -a Terminal {path}"
                )
            )
        }
    }

    func removeCompositeStep(compositeId: UUID, stepId: UUID) {
        updateComposite(for: compositeId) { config in
            config.steps.removeAll { $0.id == stepId }
        }
    }

    func moveCompositeStep(compositeId: UUID, from source: IndexSet, to destination: Int) {
        updateComposite(for: compositeId) { config in
            config.steps.move(fromOffsets: source, toOffset: destination)
        }
    }

    private func updateComposite(
        for compositeId: UUID,
        mutate: (inout CompositeMenuItemConfig) -> Void
    ) {
        guard let index = menuEntries.firstIndex(where: {
            if case .composite(let config) = $0 { return config.id == compositeId }
            return false
        }) else { return }
        guard case .composite(var config) = menuEntries[index] else { return }
        mutate(&config)
        menuEntries[index] = .composite(config)
        saveEntries()
    }

    // MARK: - New File Menu

    func updateNewFileMenuName(for menuID: UUID, name: String) {
        updateNewFileMenu(for: menuID) { config in
            config.name = uniqueNewFileMenuName(
                preferredName: name,
                excluding: menuID
            )
        }
    }

    func addNewFileTemplate(to menuID: UUID) {
        updateNewFileMenu(for: menuID) { config in
            let displayName = uniqueNewFileTemplateName(
                preferredName: "txt",
                existingTemplates: config.templates
            )
            config.templates.append(
                NewFileTemplateConfig(
                    displayName: displayName,
                    fileExtension: "txt",
                    creationMode: .emptyFile
                )
            )
        }
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
        updateNewFileMenu(for: menuID) { config in
            guard let index = config.templates.firstIndex(where: { $0.id == templateID }) else {
                return
            }
            let normalizedTemplatePath = creationMode == .copyTemplate ? templatePath : nil
            let normalizedInitialContent = creationMode == .textContent ? initialContent : nil
            config.templates[index].displayName = displayName
            config.templates[index].baseName = baseName
            config.templates[index].fileExtension = fileExtension
            config.templates[index].creationMode = creationMode
            config.templates[index].templatePath = normalizedTemplatePath
            config.templates[index].templateFingerprint = NewFileTemplateFingerprint.fileFingerprint(
                at: normalizedTemplatePath
            )
            config.templates[index].initialContent = normalizedInitialContent
            config.templates[index].isEnabled = isEnabled
        }
    }

    func removeNewFileTemplate(menuID: UUID, templateID: UUID) {
        updateNewFileMenu(for: menuID) { config in
            config.templates.removeAll { $0.id == templateID }
        }
    }

    func moveNewFileTemplate(menuID: UUID, from source: IndexSet, to destination: Int) {
        updateNewFileMenu(for: menuID) { config in
            config.templates.move(fromOffsets: source, toOffset: destination)
        }
    }

    private func updateNewFileMenu(
        for menuID: UUID,
        mutate: (inout NewFileMenuConfig) -> Void
    ) {
        guard let index = menuEntries.firstIndex(where: {
            if case .newFile(let config) = $0 { return config.id == menuID }
            return false
        }) else { return }
        guard case .newFile(var config) = menuEntries[index] else { return }
        mutate(&config)
        menuEntries[index] = .newFile(config)
        saveEntries()
    }

    private func uniqueNewFileMenuName(preferredName: String, excluding menuID: UUID) -> String {
        let existingNames = Set(
            menuEntries.compactMap { entry -> String? in
                guard case .newFile(let config) = entry, config.id != menuID else {
                    return nil
                }
                return config.name
            }
        )
        return uniqueName(
            preferredName: preferredName,
            fallbackName: "新建文件",
            existingNames: existingNames
        )
    }

    private func uniqueNewFileTemplateName(
        preferredName: String,
        existingTemplates: [NewFileTemplateConfig]
    ) -> String {
        let existingNames = Set(existingTemplates.map(\.displayName))
        return uniqueName(
            preferredName: preferredName,
            fallbackName: "txt",
            existingNames: existingNames
        )
    }

    private func uniqueName(
        preferredName: String,
        fallbackName: String,
        existingNames: Set<String>
    ) -> String {
        let trimmedPreferredName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedPreferredName.isEmpty ? fallbackName : trimmedPreferredName

        guard existingNames.contains(baseName) else {
            return baseName
        }

        var index = 2
        while true {
            let candidate = "\(baseName) \(index)"
            if !existingNames.contains(candidate) {
                return candidate
            }
            index += 1
        }
    }

    // MARK: - Publish States

    func loadPublishStates() {
        scriptPublishStates = publishStore.loadAll()
    }

    func updatePublishState(_ state: ScriptPublishState) {
        publishStore.upsert(state)
        scriptPublishStates[state.entryID] = state
    }

    // MARK: - Error Queue

    func loadErrors() {
        errorRecords = errorQueue.loadAll()
    }

    var hasScriptFileErrors: Bool {
        errorRecords.contains { record in
            record.message.contains("脚本文件不存在") || record.message.contains("脚本文件无法加载")
        }
    }

    func clearScriptFileErrors(repairedNames: Set<String>) {
        errorQueue.removeAll { record in
            guard let context = record.context else { return false }
            return repairedNames.contains(context)
                && (record.message.contains("脚本文件不存在")
                    || record.message.contains("脚本文件无法加载"))
        }
        errorRecords = errorQueue.loadAll()
    }

    func dismissAllErrors() {
        errorQueue.removeAll()
        errorRecords = []
    }
}
