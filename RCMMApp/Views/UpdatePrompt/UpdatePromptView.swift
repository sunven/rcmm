import AppKit
import SwiftUI

struct UpdatePromptView: View {
    let version: String
    let releaseNotesURL: URL?
    let primaryButtonTitle: String
    let onPrimaryAction: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text("发现新版本 \(version)")
                        .font(RCMMFont.sheetTitle)
                        .foregroundStyle(RCMMColor.textPrimary)
                    Text("rcmm 开发版更新")
                        .font(RCMMFont.caption)
                        .foregroundStyle(RCMMColor.textMuted)
                }
            }

            Text("rcmm 已检测到新的开发版。你可以现在更新，也可以稍后在“关于”页继续操作。")
                .font(RCMMFont.secondary)
                .foregroundStyle(RCMMColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            if let releaseNotesURL {
                Link("查看发布说明", destination: releaseNotesURL)
                    .font(RCMMFont.secondary)
            }

            Spacer()

            HStack {
                Button("稍后", action: onLater)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: onPrimaryAction) {
                    Text(primaryButtonTitle)
                        .frame(minWidth: 96)
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380, height: 220)
        .background(RCMMColor.window)
    }
}
