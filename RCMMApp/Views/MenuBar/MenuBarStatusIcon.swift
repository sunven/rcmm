import RCMMShared
import SwiftUI

/// 菜单栏状态图标，根据 ExtensionStatus 显示不同的 SF Symbol 和颜色
///
/// 四种状态使用不同的 SF Symbol 形状和颜色传达（色盲友好）：
/// - `.enabled` → `contextualmenu.and.cursorarrow`（模板渲染，跟随系统菜单栏色）
/// - `.otherInstallationEnabled` → `exclamationmark.circle.fill`（橙色警告）
/// - `.unknown` → `exclamationmark.triangle.fill`（黄色警告）
/// - `.disabled` → `xmark.circle.fill`（红色异常）
struct MenuBarStatusIcon: View {
    let status: ExtensionStatus

    var body: some View {
        statusImage
            .accessibilityLabel("rcmm")
            .accessibilityValue(status.statusDescription)
    }

    @ViewBuilder
    private var statusImage: some View {
        switch status {
        case .enabled:
            Image(systemName: "contextualmenu.and.cursorarrow")
        case .otherInstallationEnabled:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        case .unknown:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .disabled:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

#Preview("已启用") {
    MenuBarStatusIcon(status: .enabled)
        .padding()
}

#Preview("未知") {
    MenuBarStatusIcon(status: .unknown)
        .padding()
}

#Preview("另一份安装已启用") {
    MenuBarStatusIcon(status: .otherInstallationEnabled)
        .padding()
}

#Preview("未启用") {
    MenuBarStatusIcon(status: .disabled)
        .padding()
}

#Preview("已启用 - Dark Mode") {
    MenuBarStatusIcon(status: .enabled)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("未启用 - Dark Mode") {
    MenuBarStatusIcon(status: .disabled)
        .padding()
        .preferredColorScheme(.dark)
}
