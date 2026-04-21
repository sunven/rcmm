import AppKit
import SwiftUI
import RCMMShared

struct AboutTab: View {
    @Environment(AppState.self) private var appState

    private var appIcon: NSImage {
        NSApp.applicationIconImage
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("rcmm")
                    .font(.title2.weight(.semibold))

                Text("Right Click Menu Manager")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("版本 \(appState.currentDisplayVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                Text(appState.updateStatusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button("检查更新") {
                        appState.checkForUpdatesManually()
                    }

                    if appState.canPerformUpdatePrimaryAction {
                        Button(appState.updatePrimaryActionTitle) {
                            appState.performUpdatePrimaryAction()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
