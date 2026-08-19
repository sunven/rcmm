import Foundation
import Observation
import RCMMShared

/// 缓存应用扫描结果，并负责从扫描结果创建常用组合菜单预设。
@Observable
@MainActor
final class ApplicationDiscoveryCoordinator {
    private(set) var apps: [AppInfo] = []
    private(set) var isScanning = false
    private(set) var presetMessage: String?

    var editorTerminalPresetAvailable: Bool {
        preferredApp(in: .editor, preferredBundleIds: ["com.microsoft.VSCode"]) != nil
            && preferredTerminal() != nil
    }

    var terminalPresetAvailable: Bool {
        preferredTerminal() != nil
    }

    private let scanApplications: @MainActor () async -> [AppInfo]
    private let addComposite: @MainActor (CompositeMenuItemConfig) -> UUID
    @ObservationIgnored private var scanTask: Task<[AppInfo], Never>?

    convenience init(
        service: AppDiscoveryService = AppDiscoveryService(),
        addComposite: @escaping @MainActor (CompositeMenuItemConfig) -> UUID
    ) {
        self.init(
            scanApplications: {
                await Task.detached(priority: .userInitiated) {
                    service.scanApplications()
                }.value
            },
            addComposite: addComposite
        )
    }

    init(
        scanApplications: @escaping @MainActor () async -> [AppInfo],
        addComposite: @escaping @MainActor (CompositeMenuItemConfig) -> UUID
    ) {
        self.scanApplications = scanApplications
        self.addComposite = addComposite
    }

    func refresh() async {
        if let scanTask {
            apps = await scanTask.value
            return
        }

        let scanApplications = self.scanApplications
        isScanning = true
        let task = Task { await scanApplications() }
        scanTask = task
        apps = await task.value
        scanTask = nil
        isScanning = false
    }

    func addEditorTerminalPreset() async -> UUID? {
        await addEditorTerminalPreset(
            name: "VS Code + Terminal",
            includeShellStep: false
        )
    }

    func addEditorTerminalShellPreset() async -> UUID? {
        await addEditorTerminalPreset(
            name: "编辑器 + Terminal + Shell",
            includeShellStep: true
        )
    }

    func addAppTerminalPreset(appInfo: AppInfo) -> UUID? {
        guard let terminal = preferredTerminal() else {
            presetMessage = "未找到可用的 Terminal"
            return nil
        }

        let composite = CompositeMenuItemConfig(
            name: "\(appInfo.name) + Terminal",
            iconName: "rectangle.split.2x1",
            steps: [
                CompositeCommandStep(
                    kind: .app,
                    name: appInfo.name,
                    commandTemplate: preferredCommandTemplate(for: appInfo),
                    appPath: appInfo.path,
                    bundleId: appInfo.bundleId
                ),
                CompositeCommandStep(
                    kind: .app,
                    name: terminal.name,
                    commandTemplate: CompositeCommandTemplates.legacyOpenApp,
                    appPath: terminal.path,
                    bundleId: terminal.bundleId
                ),
            ]
        )
        let id = addComposite(composite)
        presetMessage = nil
        return id
    }

    private func addEditorTerminalPreset(
        name: String,
        includeShellStep: Bool
    ) async -> UUID? {
        presetMessage = "正在查找已安装的编辑器和终端…"
        if apps.isEmpty {
            await refresh()
        }

        guard let editor = preferredApp(
            in: .editor,
            preferredBundleIds: ["com.microsoft.VSCode"]
        ),
        let terminal = preferredTerminal() else {
            presetMessage = "未找到可用的编辑器和终端，请先安装或通过添加应用确认扫描结果"
            return nil
        }

        let composite = CompositeMenuItemConfig(
            name: name,
            iconName: "rectangle.split.2x1",
            steps: [
                CompositeCommandStep(
                    kind: .app,
                    name: editor.name,
                    commandTemplate: preferredCommandTemplate(for: editor),
                    appPath: editor.path,
                    bundleId: editor.bundleId
                ),
                CompositeCommandStep(
                    kind: .app,
                    name: terminal.name,
                    commandTemplate: "open -a {app} {path}",
                    appPath: terminal.path,
                    bundleId: terminal.bundleId
                ),
            ] + (includeShellStep ? [
                CompositeCommandStep(
                    kind: .shell,
                    name: "Shell",
                    commandTemplate: "echo \"当前目标：{path}\""
                )
            ] : [])
        )
        let id = addComposite(composite)
        presetMessage = nil
        return id
    }

    private func preferredApp(
        in category: AppCategory,
        preferredBundleIds: [String]
    ) -> AppInfo? {
        for bundleId in preferredBundleIds {
            if let match = apps.first(where: { $0.category == category && $0.bundleId == bundleId }) {
                return match
            }
        }
        return apps.first { $0.category == category }
    }

    private func preferredTerminal() -> AppInfo? {
        if let terminal = preferredApp(
            in: .terminal,
            preferredBundleIds: ["com.apple.Terminal"]
        ) {
            return terminal
        }

        let terminalPath = "/System/Applications/Utilities/Terminal.app"
        guard FileManager.default.fileExists(atPath: terminalPath) else { return nil }
        return AppInfo(
            name: "Terminal",
            bundleId: "com.apple.Terminal",
            path: terminalPath,
            category: .terminal
        )
    }

    private func preferredCommandTemplate(for appInfo: AppInfo) -> String {
        if appInfo.bundleId == "com.microsoft.VSCode" {
            return CompositeCommandTemplates.vsCodeCLI
        }

        return CompositeCommandTemplates.legacyOpenApp
    }
}
