import AppKit
import SwiftUI

struct AboutTab: View {
    @Environment(UpdateCoordinator.self) private var updateCoordinator

    private var appIcon: NSImage {
        NSApp.applicationIconImage
    }

    var body: some View {
        let presentation = updateCoordinator.presentation

        VStack(spacing: 0) {
            Spacer()

            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("rcmm")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(RCMMColor.textPrimary)
                .padding(.top, 14)

            Text("Right Click Menu Manager")
                .font(RCMMFont.secondary)
                .foregroundStyle(RCMMColor.textMuted)
                .padding(.top, 2)

            Text("版本 \(presentation.displayVersion)")
                .font(RCMMFont.caption)
                .foregroundStyle(RCMMColor.textFaint)
                .padding(.top, 1)

            VStack(spacing: 10) {
                Text(presentation.statusText)
                    .font(RCMMFont.secondary)
                    .foregroundStyle(RCMMColor.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                HStack(spacing: 8) {
                    if presentation.canCheck {
                        Button("检查更新") {
                            updateCoordinator.checkForUpdates()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if let primaryActionTitle = presentation.primaryActionTitle {
                        Button(primaryActionTitle) {
                            updateCoordinator.performPrimaryAction()
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .controlSize(.small)
                    }
                }
            }
            .padding(.top, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(RCMMColor.window)
    }
}
