import SwiftUI

/// PopoverState 路由容器，根据状态枚举显示对应视图
struct PopoverContainerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.popoverState {
            case .normal:
                NormalPopoverView()
            case .healthWarning:
                RecoveryGuidePanel()
            case .onboarding:
                // 占位符 — 当前引导使用独立 NSWindow，不通过 PopoverState 路由
                NormalPopoverView()
            }
        }
        .frame(width: 220)
        .onAppear {
            appState.checkExtensionStatus()
            appState.loadErrors()
        }
    }
}

#Preview {
    PopoverContainerView()
        .environment(AppState(forPreview: true))
}
