import AppKit
import SwiftUI

struct SettingsSidebar: View {
    @Binding var selection: SettingsDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("rcmm")
                    .font(.headline.weight(.semibold))
                Text("Finder 扩展控制台")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 4)

            ForEach(SettingsDestination.allCases) { destination in
                Button {
                    selection = destination
                } label: {
                    sidebarLabel(for: destination)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == destination ? .primary : .secondary)
                .accessibilityLabel(destination.title)
                .accessibilityAddTraits(selection == destination ? [.isSelected] : [])
                .padding(.horizontal, 8)
            }

            Spacer()
        }
        .frame(width: 188)
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
        .overlay(alignment: .leading) {
            if selection == destination {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 18)
                    .padding(.leading, 2)
            }
        }
    }
}
