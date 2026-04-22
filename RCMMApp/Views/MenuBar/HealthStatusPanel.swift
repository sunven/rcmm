import RCMMShared
import SwiftUI

/// 扩展健康状态面板，展示 Finder 扩展当前状态
///
/// 根据 `ExtensionStatus` 显示四种状态：正常（绿色）/ 其他安装占用（橙色）/
/// 未知（黄色）/ 异常（红色），同时使用图标变体和颜色传达状态信息（色盲友好）。
struct HealthStatusPanel: View {
    let status: ExtensionStatus

    private var statusIcon: String {
        switch status {
        case .enabled: "checkmark.circle.fill"
        case .otherInstallationEnabled: "exclamationmark.circle.fill"
        case .unknown: "exclamationmark.triangle.fill"
        case .disabled: "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .enabled: .green
        case .otherInstallationEnabled: .orange
        case .unknown: .yellow
        case .disabled: .red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.body)
            Text(status.statusDescription)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("扩展状态：\(status.statusDescription)")
        .accessibilityValue(status.statusDescription)
    }
}

#Preview("已启用") {
    HealthStatusPanel(status: .enabled)
        .padding()
}

#Preview("未知") {
    HealthStatusPanel(status: .unknown)
        .padding()
}

#Preview("另一份安装已启用") {
    HealthStatusPanel(status: .otherInstallationEnabled)
        .padding()
}

#Preview("未启用") {
    HealthStatusPanel(status: .disabled)
        .padding()
}

#Preview("已启用 - Dark Mode") {
    HealthStatusPanel(status: .enabled)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("未启用 - Dark Mode") {
    HealthStatusPanel(status: .disabled)
        .padding()
        .preferredColorScheme(.dark)
}
