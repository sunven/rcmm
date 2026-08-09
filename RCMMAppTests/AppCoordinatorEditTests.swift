import Foundation
import RCMMShared
import Testing
@testable import rcmm

/// Menu Entry 写入接口的语义：`edit` / `preview` / `commitPreview` /
/// `updateMenuPresentationMode` 四个入口各自改内存、落盘、发布的组合。
@Suite("AppCoordinator Menu Entry 写入接口", .serialized)
@MainActor
struct AppCoordinatorEditTests {
    @Test("edit 落盘并恰好发布一次")
    func editPersistsAndPublishesOnce() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = harness.makeCoordinator()
        let countBefore = coordinator.configStore.menuEntries.count

        coordinator.edit { $0.addGitPullCommand() }
        await coordinator.publishTask?.value

        #expect(coordinator.configStore.menuEntries.count == countBefore + 1)
        #expect(harness.configService.loadEntries().count == countBefore + 1)
        #expect(harness.notifier.postedConfigChangedCount == 1)
    }

    @Test("edit 原样带出闭包的返回值")
    func editReturnsClosureResult() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = harness.makeCoordinator()

        let newID = coordinator.edit { $0.addEmptyCompositeCommand() }
        await coordinator.publishTask?.value

        let persistedIDs = harness.configService.loadEntries().compactMap { entry -> UUID? in
            guard case .composite(let config) = entry else { return nil }
            return config.id
        }
        #expect(persistedIDs == [newID])
    }

    @Test("edit 对直接改 menuEntries 同样保证落盘")
    func editPersistsRawMutation() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = harness.makeCoordinator()
        let reversed = coordinator.configStore.menuEntries.reversed().map { $0 }

        coordinator.edit { $0.menuEntries = reversed }
        await coordinator.publishTask?.value

        #expect(harness.configService.loadEntries().map(\.id) == reversed.map(\.id))
    }

    @Test("preview 只改内存，不落盘也不发布")
    func previewMutatesMemoryOnly() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = harness.makeCoordinator()
        let originalIDs = harness.configService.loadEntries().map(\.id)
        let reversed = coordinator.configStore.menuEntries.reversed().map { $0 }

        coordinator.preview { $0.menuEntries = reversed }

        #expect(coordinator.configStore.menuEntries.map(\.id) == reversed.map(\.id))
        #expect(harness.configService.loadEntries().map(\.id) == originalIDs)
        #expect(coordinator.publishTask == nil)
        #expect(harness.notifier.postedConfigChangedCount == 0)
    }

    @Test("commitPreview 落盘并发布当前内存态")
    func commitPreviewPersistsAccumulatedMemoryState() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = harness.makeCoordinator()
        let reversed = coordinator.configStore.menuEntries.reversed().map { $0 }

        coordinator.preview { $0.menuEntries = reversed }
        coordinator.commitPreview()
        await coordinator.publishTask?.value

        #expect(harness.configService.loadEntries().map(\.id) == reversed.map(\.id))
        #expect(harness.notifier.postedConfigChangedCount == 1)
    }

    @Test("preview 取消后 commitPreview 之外不留下任何持久化痕迹")
    func cancelledPreviewLeavesStorageUntouched() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = harness.makeCoordinator()
        let original = coordinator.configStore.menuEntries

        coordinator.preview { $0.menuEntries = original.reversed().map { $0 } }
        coordinator.preview { $0.menuEntries = original }

        #expect(coordinator.configStore.menuEntries.map(\.id) == original.map(\.id))
        #expect(harness.configService.loadEntries().map(\.id) == original.map(\.id))
        #expect(harness.notifier.postedConfigChangedCount == 0)
    }

    @Test("updateMenuPresentationMode 落盘但不触发脚本编译")
    func presentationModeDoesNotRecompileScripts() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = harness.makeCoordinator()

        coordinator.updateMenuPresentationMode(.nestedUnderRCMM)

        #expect(coordinator.configStore.menuPresentationMode == .nestedUnderRCMM)
        #expect(harness.configService.loadMenuPresentationMode() == .nestedUnderRCMM)
        #expect(coordinator.publishTask == nil)
        #expect(harness.compiler.compiledSources.isEmpty)
    }
}
