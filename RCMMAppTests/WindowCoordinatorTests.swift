import AppKit
import SwiftUI
import Testing
@testable import rcmm

@Suite("WindowCoordinator", .serialized)
@MainActor
struct WindowCoordinatorTests {
    @Test("同一 destination 复用窗口并在关闭后执行一次回调")
    func reusesWindowAndClosesOnce() {
        var activationCount = 0
        var hideCount = 0
        var closeCount = 0
        let coordinator = WindowCoordinator(
            activateAsRegularApp: { activationCount += 1 },
            hideToMenuBar: { hideCount += 1 },
            visibleWindows: { [] }
        )

        coordinator.present(.updatePrompt, content: EmptyView()) { _ in
            closeCount += 1
            return true
        }
        coordinator.present(.updatePrompt, content: Text("replacement"))

        #expect(coordinator.hasWindow(.updatePrompt))
        #expect(activationCount == 2)

        coordinator.dismiss(.updatePrompt)

        #expect(!coordinator.hasWindow(.updatePrompt))
        #expect(closeCount == 1)
        #expect(hideCount == 1)

        coordinator.present(.updatePrompt, content: EmptyView())
        #expect(coordinator.hasWindow(.updatePrompt))
        #expect(activationCount == 3)
        coordinator.dismiss(.updatePrompt, performCloseEffects: false)
    }

    @Test("静默替换窗口不执行关闭回调或隐藏应用")
    func silentDismissalSkipsCloseEffects() {
        var hideCount = 0
        var closeCount = 0
        let coordinator = WindowCoordinator(
            activateAsRegularApp: {},
            hideToMenuBar: { hideCount += 1 },
            visibleWindows: { [] }
        )

        coordinator.present(.updatePrompt, content: EmptyView()) { _ in
            closeCount += 1
            return true
        }
        coordinator.dismiss(.updatePrompt, performCloseEffects: false)

        #expect(!coordinator.hasWindow(.updatePrompt))
        #expect(closeCount == 0)
        #expect(hideCount == 0)
    }

    @Test("关闭策略可以保留 regular activation policy")
    func closeHandlerCanSuppressHide() {
        var hideCount = 0
        let coordinator = WindowCoordinator(
            activateAsRegularApp: {},
            hideToMenuBar: { hideCount += 1 },
            visibleWindows: { [] }
        )

        coordinator.present(.updatePrompt, content: EmptyView()) { _ in false }
        coordinator.dismiss(.updatePrompt)

        #expect(hideCount == 0)
    }
}
