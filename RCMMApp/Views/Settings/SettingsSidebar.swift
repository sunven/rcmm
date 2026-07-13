import AppKit
import SwiftUI

struct SettingsSidebar: View {
    @Binding var selection: SettingsDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("rcmm")
                        .font(.headline.weight(.semibold))
                    Text("Finder 扩展控制台")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 22)
            .padding(.bottom, 20)

            ForEach(SettingsDestination.allCases) { destination in
                Button {
                    selection = destination
                } label: {
                    sidebarLabel(for: destination)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == destination ? Color.accentColor : .secondary)
                .accessibilityLabel(destination.title)
                .accessibilityAddTraits(selection == destination ? [.isSelected] : [])
                .padding(.horizontal, 8)
            }

            Spacer()
        }
        .frame(width: 160)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func sidebarLabel(for destination: SettingsDestination) -> some View {
        HStack(spacing: 9) {
            Image(systemName: destination.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 18)

            Text(destination.title)
                .font(.callout.weight(.medium))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selection == destination ? Color.accentColor.opacity(0.14) : Color.clear)
        )
    }
}
