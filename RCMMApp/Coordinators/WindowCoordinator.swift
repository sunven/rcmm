import AppKit
import Foundation
import Observation
import SwiftUI

enum AppWindowDestination: Hashable {
    case onboarding
    case updatePrompt
    case extensionCleanup

    var contentRect: NSRect {
        switch self {
        case .onboarding:
            return NSRect(x: 0, y: 0, width: 480, height: 500)
        case .updatePrompt:
            return NSRect(x: 0, y: 0, width: 380, height: 220)
        case .extensionCleanup:
            return NSRect(x: 0, y: 0, width: 560, height: 460)
        }
    }

    var styleMask: NSWindow.StyleMask {
        switch self {
        case .extensionCleanup:
            return [.titled]
        case .onboarding, .updatePrompt:
            return [.titled, .closable]
        }
    }

    var title: String {
        switch self {
        case .onboarding:
            return "欢迎使用 rcmm"
        case .updatePrompt:
            return "发现新版本"
        case .extensionCleanup:
            return "清理旧扩展副本"
        }
    }

    var minSize: NSSize? {
        switch self {
        case .onboarding:
            return NSSize(width: 480, height: 500)
        case .extensionCleanup:
            return NSSize(width: 540, height: 360)
        case .updatePrompt:
            return nil
        }
    }

    var maxSize: NSSize? {
        switch self {
        case .onboarding:
            return NSSize(width: 480, height: 500)
        case .extensionCleanup, .updatePrompt:
            return nil
        }
    }
}

/// 统一管理独立 NSWindow 的生命周期和应用激活策略。
@Observable
@MainActor
final class WindowCoordinator {
    private var windows: [AppWindowDestination: NSWindow] = [:]
    private var closeObservers: [AppWindowDestination: NSObjectProtocol] = [:]
    private var closeHandlers: [AppWindowDestination: (NSWindow) -> Bool] = [:]
    private let activateAsRegularApp: @MainActor () -> Void
    private let hideToMenuBar: @MainActor () -> Void
    private let visibleWindows: @MainActor () -> [NSWindow]

    init(
        activateAsRegularApp: @escaping @MainActor () -> Void = { ActivationPolicyManager.activateAsRegularApp() },
        hideToMenuBar: @escaping @MainActor () -> Void = { ActivationPolicyManager.hideToMenuBar() },
        visibleWindows: @escaping @MainActor () -> [NSWindow] = { NSApp.windows }
    ) {
        self.activateAsRegularApp = activateAsRegularApp
        self.hideToMenuBar = hideToMenuBar
        self.visibleWindows = visibleWindows
    }

    func hasWindow(_ destination: AppWindowDestination) -> Bool {
        windows[destination] != nil
    }

    func present<V: View>(
        _ destination: AppWindowDestination,
        content: V,
        onClose: @escaping (NSWindow) -> Bool = { _ in true }
    ) {
        if let window = windows[destination] {
            activateAsRegularApp()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let window = NSWindow(
            contentRect: destination.contentRect,
            styleMask: destination.styleMask,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content)
        window.title = destination.title
        window.center()
        if let minSize = destination.minSize {
            window.minSize = minSize
        }
        if let maxSize = destination.maxSize {
            window.maxSize = maxSize
        }

        closeObservers[destination] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            MainActor.assumeIsolated {
                guard let self, let window else { return }
                self.handleWindowClosed(destination, window: window)
            }
        }
        closeHandlers[destination] = onClose
        windows[destination] = window

        activateAsRegularApp()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func dismiss(_ destination: AppWindowDestination, performCloseEffects: Bool = true) {
        guard let window = windows[destination] else { return }
        if !performCloseEffects {
            removeTracking(for: destination)
        }
        window.close()
    }

    func hasVisibleWindow(excluding excludedWindow: NSWindow) -> Bool {
        visibleWindows().contains { window in
            window !== excludedWindow && window.isVisible
        }
    }

    private func handleWindowClosed(_ destination: AppWindowDestination, window: NSWindow) {
        let handler = closeHandlers[destination]
        guard windows[destination] === window else { return }
        removeTracking(for: destination)
        let shouldHideToMenuBar = handler?(window) ?? true
        guard shouldHideToMenuBar else { return }
        guard !hasVisibleWindow(excluding: window) else { return }
        hideToMenuBar()
    }

    private func removeTracking(for destination: AppWindowDestination) {
        if let observer = closeObservers.removeValue(forKey: destination) {
            NotificationCenter.default.removeObserver(observer)
        }
        closeHandlers.removeValue(forKey: destination)
        windows.removeValue(forKey: destination)
    }
}
