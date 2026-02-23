import RCMMShared
import SwiftUI

/// 扩展健康状态面板，展示 Finder 扩展当前状态
///
/// 根据 `ExtensionStatus` 显示三种状态：正常（绿色）/ 未知（黄色）/ 异常（红色），
/// 同时使用图标变体和颜色传达状态信息（色盲友好）。
struct HealthStatusPanel: View {
    let status: ExtensionStatus

    private var statusIcon: String {
        switch status {
        case .enabled: "checkmark.circle.fill"
        case .unknown: "exclamationmark.triangle.fill"
        case .disabled: "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .enabled: .green
        case .unknown: .yellow
        case .disabled: .red
        }
    }

    private var statusText: String {
        switch status {
        case .enabled: "Finder 扩展已启用"
        case .unknown: "扩展状态未知"
        case .disabled: "Finder 扩展未启用"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.body)
            Text(statusText)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("扩展状态：\(statusText)")
        .accessibilityValue(statusText)
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
