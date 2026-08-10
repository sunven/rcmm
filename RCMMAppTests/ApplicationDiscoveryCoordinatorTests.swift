import Foundation
import RCMMShared
import Testing
@testable import rcmm

@Suite("ApplicationDiscoveryCoordinator", .serialized)
@MainActor
struct ApplicationDiscoveryCoordinatorTests {
    @Test("扫描结果缓存并按偏好创建 VS Code + Terminal 预设")
    func refreshAndCreatePreset() async {
        let editor = AppInfo(
            name: "Other Editor",
            bundleId: "com.example.editor",
            path: "/Applications/Other Editor.app",
            category: .editor
        )
        let vscode = AppInfo(
            name: "Visual Studio Code",
            bundleId: "com.microsoft.VSCode",
            path: "/Applications/Visual Studio Code.app",
            category: .editor
        )
        let terminal = AppInfo(
            name: "Terminal",
            bundleId: "com.apple.Terminal",
            path: "/System/Applications/Utilities/Terminal.app",
            category: .terminal
        )
        var addedComposite: CompositeMenuItemConfig?
        let coordinator = ApplicationDiscoveryCoordinator(
            scanApplications: { [editor, vscode, terminal] },
            addComposite: { composite in
                addedComposite = composite
                return composite.id
            }
        )

        await coordinator.refresh()
        #expect(coordinator.apps == [editor, vscode, terminal])
        #expect(!coordinator.isScanning)

        let id = await coordinator.addEditorTerminalPreset()

        #expect(id == addedComposite?.id)
        #expect(addedComposite?.steps.first?.bundleId == "com.microsoft.VSCode")
        #expect(addedComposite?.steps.first?.commandTemplate == CompositeCommandTemplates.vsCodeCLI)
        #expect(addedComposite?.steps.last?.bundleId == "com.apple.Terminal")
        #expect(coordinator.presetMessage == nil)
    }

    @Test("缺少编辑器或终端时保留可操作的提示")
    func missingPresetAppsShowsMessage() async {
        let coordinator = ApplicationDiscoveryCoordinator(
            scanApplications: {
                [AppInfo(
                    name: "Terminal",
                    bundleId: "com.apple.Terminal",
                    path: "/System/Applications/Utilities/Terminal.app",
                    category: .terminal
                )]
            },
            addComposite: { _ in UUID() }
        )

        let id = await coordinator.addEditorTerminalPreset()

        #expect(id == nil)
        #expect(coordinator.presetMessage?.contains("未找到可用") == true)
    }

    @Test("并发刷新共享同一次扫描")
    func concurrentRefreshesShareScan() async {
        let app = AppInfo(
            name: "Terminal",
            bundleId: "com.apple.Terminal",
            path: "/System/Applications/Utilities/Terminal.app",
            category: .terminal
        )
        let scan = SuspendedApplicationScan()
        var scanCount = 0
        let coordinator = ApplicationDiscoveryCoordinator(
            scanApplications: {
                scanCount += 1
                return await scan.value()
            },
            addComposite: { $0.id }
        )

        let firstRefresh = Task { await coordinator.refresh() }
        await scan.waitUntilRequested()
        let secondRefresh = Task { await coordinator.refresh() }
        await Task.yield()
        scan.resume(returning: [app])
        await firstRefresh.value
        await secondRefresh.value

        #expect(scanCount == 1)
        #expect(coordinator.apps == [app])
        #expect(!coordinator.isScanning)
    }
}

@MainActor
private final class SuspendedApplicationScan {
    private var continuation: CheckedContinuation<[AppInfo], Never>?

    func value() async -> [AppInfo] {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilRequested() async {
        while continuation == nil {
            await Task.yield()
        }
    }

    func resume(returning apps: [AppInfo]) {
        continuation?.resume(returning: apps)
        continuation = nil
    }
}
