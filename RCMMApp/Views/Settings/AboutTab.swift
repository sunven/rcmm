import AppKit
import SwiftUI

struct AboutTab: View {
    @Environment(UpdateCoordinator.self) private var updateCoordinator

    private var appIcon: NSImage {
        NSApp.applicationIconImage
    }

    var body: some View {
        let presentation = updateCoordinator.presentation

        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

            VStack(spacing: 6) {
                Text("rcmm")
                    .font(.title2.weight(.semibold))

                Text("Right Click Menu Manager")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("版本 \(presentation.displayVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                Text(presentation.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    if presentation.canCheck {
                        Button("检查更新") {
                            updateCoordinator.checkForUpdates()
                        }
                    }

                    if let primaryActionTitle = presentation.primaryActionTitle {
                        Button(primaryActionTitle) {
                            updateCoordinator.performPrimaryAction()
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
