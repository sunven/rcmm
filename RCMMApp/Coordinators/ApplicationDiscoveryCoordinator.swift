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
        presetMessage = "正在查找已安装的编辑器和终端…"
        if apps.isEmpty {
            await refresh()
        }

        guard let editor = preferredApp(
            in: .editor,
            preferredBundleIds: ["com.microsoft.VSCode"]
        ),
        let terminal = preferredApp(
            in: .terminal,
            preferredBundleIds: ["com.apple.Terminal"]
        ) else {
            presetMessage = "未找到可用的编辑器和终端，请先安装或通过添加应用确认扫描结果"
            return nil
        }

        let composite = CompositeMenuItemConfig(
            name: "VS Code + Terminal",
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
            ]
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

    private func preferredCommandTemplate(for appInfo: AppInfo) -> String {
        if appInfo.bundleId == "com.microsoft.VSCode" {
            return CompositeCommandTemplates.vsCodeCLI
        }

        return CompositeCommandTemplates.legacyOpenApp
    }
}
