import AppKit
import SwiftUI

struct SettingsSidebar: View {
    @Binding var selection: SettingsDestination

    private let menuDestinations: [SettingsDestination] = [.finderMenu, .newFile, .compositeCommands]
    private let appDestinations: [SettingsDestination] = [.general, .about]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            productHeader

            navGroup("菜单", destinations: menuDestinations)
                .padding(.top, 18)

            navGroup("应用", destinations: appDestinations)
                .padding(.top, 18)

            Spacer(minLength: 0)
        }
        .frame(width: 192)
        .background(RCMMColor.window)
        .overlay(alignment: .trailing) {
            RCMMDivider(axis: .vertical)
        }
    }

    private var productHeader: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("rcmm")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(RCMMColor.textPrimary)
                Text("Finder 菜单管理")
                    .font(RCMMFont.caption)
                    .foregroundStyle(RCMMColor.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    private func navGroup(_ title: String, destinations: [SettingsDestination]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(RCMMFont.caption)
                .foregroundStyle(RCMMColor.textFaint)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            ForEach(destinations) { destination in
                SidebarNavRow(
                    destination: destination,
                    isSelected: selection == destination
                ) {
                    selection = destination
                }
            }
        }
    }
}

private struct SidebarNavRow: View {
    let destination: SettingsDestination
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)

                Text(destination.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? RCMMColor.accentText : RCMMColor.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var backgroundColor: Color {
        if isSelected {
            return RCMMColor.accentSoft
        }
        if isHovered {
            return Color.primary.opacity(0.05)
        }
        return .clear
    }
}
