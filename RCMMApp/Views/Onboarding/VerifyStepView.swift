import SwiftUI

struct VerifyStepView: View {
    @Binding var launchAtLogin: Bool

    var body: some View {
        VStack(spacing: 24) {
            // 顶部图标和标题
            VStack(spacing: 12) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text("现在去 Finder 试试右键！")
                    .font(.title2.bold())

                Text("验证右键菜单是否正常工作")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            // 操作指引
            VStack(alignment: .leading, spacing: 8) {
                Text("操作指引：")
                    .font(.subheadline.bold())

                VStack(alignment: .leading, spacing: 4) {
                    Label("在 Finder 中右键一个目录", systemImage: "1.circle.fill")
                        .accessibilityLabel("步骤一：在 Finder 中右键一个目录")
                    Label("点击菜单中的应用", systemImage: "2.circle.fill")
                        .accessibilityLabel("步骤二：点击菜单中的应用")
                    Label("确认应用打开到对应目录", systemImage: "3.circle.fill")
                        .accessibilityLabel("步骤三：确认应用打开到对应目录")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            Spacer()

            // 开机自启 Toggle
            Toggle("开机自动启动", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .padding(.horizontal)
                .accessibilityLabel("开机自动启动")
                .accessibilityHint("开启后应用将在登录时自动启动")
        }
    }
}

#Preview {
    VerifyStepView(launchAtLogin: .constant(true))
        .frame(width: 480, height: 380)
}
