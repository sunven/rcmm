import SwiftUI

struct UpdatePromptView: View {
    let version: String
    let releaseNotesURL: URL?
    let primaryButtonTitle: String
    let onPrimaryAction: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("发现新版本 \(version)")
                .font(.title3.weight(.semibold))

            Text("rcmm 已检测到新的开发版。你可以现在更新，也可以稍后在“关于”页继续操作。")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let releaseNotesURL {
                Link("查看发布说明", destination: releaseNotesURL)
                    .font(.callout)
            }

            Spacer()

            HStack {
                Button("稍后", action: onLater)
                Spacer()
                Button(primaryButtonTitle, action: onPrimaryAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380, height: 220)
    }
}
