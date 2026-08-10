import SwiftUI

/// PopoverState 路由容器，根据状态枚举显示对应视图
struct PopoverContainerView: View {
    @Environment(ExtensionHealthMonitor.self) private var healthMonitor
    @Environment(AppCoordinator.self) private var appCoordinator

    var body: some View {
        Group {
            switch healthMonitor.popoverState {
            case .normal:
                NormalPopoverView()
            case .healthWarning:
                RecoveryGuidePanel()
            case .onboarding:
                // 占位符 — 当前引导使用独立 NSWindow，不通过 PopoverState 路由
                NormalPopoverView()
            }
        }
        .frame(width: healthMonitor.popoverState.preferredPopoverWidth)
        .onAppear {
            healthMonitor.refresh()
            appCoordinator.loadErrors()
        }
    }
}

#Preview {
    let appModel = AppModel(forPreview: true)

    PopoverContainerView()
        .environment(appModel.appCoordinator)
        .environment(appModel.appCoordinator.configStore)
        .environment(appModel.extensionHealthMonitor)
        .environment(appModel.appFlowCoordinator)
}
